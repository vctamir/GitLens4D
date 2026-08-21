unit GitLens4D.IDE.PRView;

{ ============================================================================
  GitLens4D - Descrição de Pull Request

  Desenhada em ui\pr.html, no mesmo host das outras telas. A lógica é a mesma
  de antes: gerar a descrição pela IA em thread separada, e depois copiar o
  texto e abrir a página de comparação do remoto no navegador.

  A preferência de formato continua compartilhada com a tela de commit, pela
  MESMA chave de projeto (raiz do repositório em minúsculas, com '\') -- se as
  duas telas montassem a chave de jeitos diferentes, cada uma leria a sua.
  ============================================================================ }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.JSON,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.Clipbrd,
  GitLens4D.Interfaces,
  GitLens4D.IDE.WebHost,
  ToolsAPI;

type
  TGitPRView = class(TForm)
  private
    FHost      : TGitWebHost;
    FRunner    : IGitRunner;
    FAIService : IAIService;
    FSettings  : ISettingsRepository;
    FProjectDir: string;
    FTaskNum   : string;
    FTaskDesc  : string;
    FProjName  : string;
    FProjVer   : string;
    FFormat    : string;
    FBusy      : Boolean;

    procedure ApplyTheme;
    procedure HandleAction(AAction: TJSONObject);
    procedure HostDocumentReady(ASender: TObject);
    procedure PushState;
    procedure UpdatePRBody(const AText: string);
    procedure SetBusy(ABusy: Boolean);
    function BodyFromDocument: string;
    function GetProjectKey: string;
    procedure LoadSelectedFormat;
    procedure PersistSelectedFormat;
    procedure DoSuggest;
    procedure DoCopyAndOpen;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent; ARunner: IGitRunner; AAIService: IAIService;
      ASettings: ISettingsRepository; const AProjectDir, ATaskNum, ATaskDesc, AProjName, AProjVer: string); reintroduce;
  end;

procedure ShowPRWindow(ARunner: IGitRunner; AAIService: IAIService;
  ASettings: ISettingsRepository; const AProjectDir, ATaskNum, ATaskDesc, AProjName, AProjVer: string);

implementation

uses
  System.StrUtils,
  GitLens4D.Git.ProjectProvider;

{$R *.dfm}

const
  ID_PR_BODY = 'prBody';

  FORMAT_MARKDOWN = 'Markdown';
  FORMAT_PLAIN    = 'Texto Puro';

procedure ShowPRWindow(ARunner: IGitRunner; AAIService: IAIService;
  ASettings: ISettingsRepository; const AProjectDir, ATaskNum, ATaskDesc, AProjName, AProjVer: string);
var
  LForm: TGitPRView;
begin
  LForm := TGitPRView.Create(nil, ARunner, AAIService, ASettings, AProjectDir, ATaskNum,
    ATaskDesc, AProjName, AProjVer);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

{ TGitPRView }

constructor TGitPRView.Create(AOwner: TComponent; ARunner: IGitRunner; AAIService: IAIService;
  ASettings: ISettingsRepository; const AProjectDir, ATaskNum, ATaskDesc, AProjName, AProjVer: string);
begin
  inherited Create(AOwner);
  FRunner     := ARunner;
  FAIService  := AAIService;
  FSettings   := ASettings;
  FProjectDir := AProjectDir;
  FTaskNum    := ATaskNum;
  FTaskDesc   := ATaskDesc;
  FProjName   := AProjName;
  FProjVer    := AProjVer;
  FFormat     := FORMAT_MARKDOWN;
  PopupMode   := pmAuto;

  FHost                 := TGitWebHost.Create(Self, Self, 'pr.html');
  FHost.OnAction        := HandleAction;
  FHost.OnDocumentReady := HostDocumentReady;
end;

procedure TGitPRView.DoShow;
begin
  inherited;
  ApplyTheme;
  LoadSelectedFormat;
end;

procedure TGitPRView.ApplyTheme;
var
  LThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingSvc) then
    if LThemingSvc.IDEThemingEnabled then
      LThemingSvc.ApplyTheme(Self);
end;

procedure TGitPRView.HostDocumentReady(ASender: TObject);
begin
  PushState;
end;

procedure TGitPRView.PushState;
var
  LJson   : TJSONObject;
  LFormats: TJSONArray;
  LInfo   : string;
begin
  LJson := TJSONObject.Create;
  try
    LFormats := TJSONArray.Create;
    LFormats.Add(FORMAT_MARKDOWN);
    LFormats.Add(FORMAT_PLAIN);
    LJson.AddPair('formats', LFormats);
    LJson.AddPair('format', FFormat);

    LInfo := Trim(FProjName + ' ' + FProjVer);
    if FTaskNum <> '' then
      LInfo := LInfo + '  ·  tarefa #' + FTaskNum;
    LJson.AddPair('taskInfo', LInfo);
    LJson.AddPair('busy', TJSONBool.Create(FBusy));

    FHost.CallJs('gitPR', LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TGitPRView.BodyFromDocument: string;
begin
  if not FHost.TryReadValue(ID_PR_BODY, Result) then
    Result := '';
end;

function TGitPRView.GetProjectKey: string;
var
  LRoot: string;
begin
  { Mesma chave usada pela tela de commit, para as duas compartilharem a
    preferência de formato do repositório. O git devolve o caminho com '/', e a
    tela de commit normaliza para '\' antes de montar a chave -- sem a mesma
    troca aqui, as duas gravariam em chaves diferentes. }
  LRoot := '';
  if Assigned(FRunner) then
    LRoot := StringReplace(FRunner.GetRepoRoot(FProjectDir), '/', '\', [rfReplaceAll]);

  if LRoot <> '' then
    Result := LowerCase(LRoot)
  else
    Result := LowerCase(FProjectDir);
end;

procedure TGitPRView.LoadSelectedFormat;
var
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
  LProjFormat                                   : string;
begin
  if not Assigned(FSettings) then
    Exit;

  // A preferência do projeto atual tem prioridade sobre a config global.
  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);
  FSettings.LoadProjectFormat(GetProjectKey, LProjFormat);
  if LProjFormat <> '' then
    LFormat := LProjFormat;
  if (LFormat <> FORMAT_MARKDOWN) and (LFormat <> FORMAT_PLAIN) then
    LFormat := FORMAT_MARKDOWN;
  FFormat := LFormat;

  // Alinha a config global (lida pelo AIService) com o formato do projeto.
  PersistSelectedFormat;
  PushState;
end;

procedure TGitPRView.PersistSelectedFormat;
var
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
begin
  if not Assigned(FSettings) or (FFormat = '') then
    Exit;

  // 1. Config global da IA (é a fonte lida pelo AIService ao gerar).
  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);
  FSettings.SaveAIConfig(LType, LEndpoint, LKey, LModel, LLang, FFormat, LTemp, LMaxTokens);

  // 2. Preferência por projeto (restaurada ao reabrir este repositório).
  FSettings.SaveProjectFormat(GetProjectKey, FFormat);
end;

procedure TGitPRView.SetBusy(ABusy: Boolean);
var
  LJson: TJSONObject;
begin
  FBusy := ABusy;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('busy', TJSONBool.Create(FBusy));
    FHost.CallJs('gitBusy', LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TGitPRView.UpdatePRBody(const AText: string);
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('text', AText);
    LJson.AddPair('busy', TJSONBool.Create(FBusy));
    FHost.CallJs('gitPRBody', LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TGitPRView.DoSuggest;
var
  LDiff      : string;
  LView      : TGitPRView;
  LSvc       : IAIService;
  LNum, LDesc: string;
  LMetadata  : TGitProjectMetadata;
begin
  if not Assigned(FAIService) then
    Exit;

  if not FAIService.IsConfigured then
  begin
    ShowMessage('IA não configurada! Por favor, configure o endpoint e o modelo antes de ' +
      'solicitar a elaboração do PR.');
    Exit;
  end;

  SetBusy(True);

  LDiff := FRunner.Execute('git diff HEAD', FProjectDir);
  if LDiff.Trim = '' then
    LDiff := FRunner.Execute('git show --stat HEAD', FProjectDir);

  LMetadata := TGitProjectProvider.Create.GetMetadata;

  LView := Self;
  LSvc  := FAIService;
  LNum  := FTaskNum;
  LDesc := FTaskDesc;

  TThread.CreateAnonymousThread(
    procedure
    var
      LSuggestion: string;
    begin
      try
        LSuggestion := LSvc.GeneratePRDescription(LNum, LDesc, LDiff, LMetadata.ProjectName,
          LMetadata.ProjectVersion);
        TThread.Synchronize(nil,
          procedure
          begin
            if Assigned(LView) then
            begin
              LView.SetBusy(False);
              LView.UpdatePRBody(LSuggestion);
            end;
          end);
      except
        on E: Exception do
        begin
          LSuggestion := E.Message;
          TThread.Synchronize(nil,
            procedure
            begin
              if Assigned(LView) then
              begin
                LView.SetBusy(False);
                ShowMessage('Erro: ' + LSuggestion);
              end;
            end);
        end;
      end;
    end).Start;
end;

procedure TGitPRView.DoCopyAndOpen;
var
  LBody, LUrl, LBranch: string;
begin
  LBody := BodyFromDocument;
  if Trim(LBody) = '' then
  begin
    ShowMessage('O corpo do PR está vazio.');
    Exit;
  end;

  Clipboard.AsText := LBody;

  LUrl := FRunner.GetRemoteUrl(FProjectDir);
  if LUrl = '' then
  begin
    ShowMessage('Texto copiado! Mas não foi possível localizar a URL remota para abrir o navegador.');
    Exit;
  end;

  { git@host:grupo/repo.git -> https://host/grupo/repo }
  if LUrl.StartsWith('git@') then
  begin
    LUrl := StringReplace(LUrl, ':', '/', [rfReplaceAll]);
    LUrl := StringReplace(LUrl, 'git@', 'https://', [rfReplaceAll]);
  end;

  if LUrl.EndsWith('.git') then
    LUrl := Copy(LUrl, 1, Length(LUrl) - 4);

  LBranch := FRunner.GetCurrentBranch(FProjectDir);
  LUrl    := LUrl.Trim(['/']) + '/compare/' + LBranch + '?expand=1';

  ShellExecute(0, 'open', PChar(LUrl), nil, nil, SW_SHOWNORMAL);
  ShowMessage('Descrição copiada e navegador aberto!');
  Close;
end;

procedure TGitPRView.HandleAction(AAction: TJSONObject);
var
  LType, LFormat: string;
  LValue        : TJSONValue;
begin
  LType  := '';
  LValue := AAction.GetValue('type');
  if Assigned(LValue) then
    LType := LValue.Value;

  if LType = 'close' then
    Close
  else if LType = 'suggest' then
    DoSuggest
  else if LType = 'copyOpen' then
    DoCopyAndOpen
  else if LType = 'format.change' then
  begin
    LValue := AAction.GetValue('format');
    if Assigned(LValue) then
      LFormat := LValue.Value
    else
      LFormat := '';
    if LFormat <> '' then
    begin
      FFormat := LFormat;
      PersistSelectedFormat;
    end;
  end;
end;

end.
