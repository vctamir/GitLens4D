unit GitLens4D.IDE.PRView;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  GitLens4D.Interfaces,
  ToolsAPI,
  Vcl.Clipbrd,
  Winapi.ShellAPI,
  System.ImageList,
  Vcl.ImgList;

type
  TGitPRView = class(TForm)
    pnlBottom: TPanel;
    memPRBody: TMemo;
    btnSuggest: TButton;
    btnCopyOpen: TButton;
    btnClose: TButton;
    pnlTop: TPanel;
    lblTitle: TLabel;
    procedure btnCloseClick(Sender: TObject);
    procedure btnSuggestClick(Sender: TObject);
    procedure btnCopyOpenClick(Sender: TObject);
  private
    FRunner    : IGitRunner;
    FAIService : IAIService;
    FSettings  : ISettingsRepository;
    FProjectDir: string;
    FTaskNum   : string;
    FTaskDesc  : string;
    FProjName  : string;
    FProjVer   : string;

    procedure ApplyTheme;
    procedure UpdatePRBody(const AText: string);
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


procedure ShowPRWindow(ARunner: IGitRunner; AAIService: IAIService;
  ASettings: ISettingsRepository; const AProjectDir, ATaskNum, ATaskDesc, AProjName, AProjVer: string);
var
  LForm: TGitPRView;
begin
  LForm := TGitPRView.Create(nil, ARunner, AAIService, ASettings, AProjectDir, ATaskNum, ATaskDesc, AProjName, AProjVer);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

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

  Self.PopupMode := pmAuto;
end;

procedure TGitPRView.DoShow;
begin
  inherited;
  ApplyTheme;
end;

procedure TGitPRView.ApplyTheme;
var
  LThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingSvc) then
    if LThemingSvc.IDEThemingEnabled then
      LThemingSvc.ApplyTheme(Self);
end;

procedure TGitPRView.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TGitPRView.UpdatePRBody(const AText: string);
begin
  memPRBody.Text := AText;
end;

procedure TGitPRView.btnSuggestClick(Sender: TObject);
var
  LDiff      : string;
  LView      : TGitPRView;
  LSvc       : IAIService;
  LNum, LDesc: string;
  LSuggestion: string;
  LMetadata  : TGitProjectMetadata;
begin
  if not Assigned(FAIService) then
    Exit;

  if not FAIService.IsConfigured then
  begin
    ShowMessage(UTF8ToString('IA não configurada! Por favor, configure o endpoint e o modelo antes de solicitar a elaboração do PR.'));
    Exit;
  end;

  btnSuggest.Enabled := False;
  btnSuggest.Caption := 'Thinking...';

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
    begin
      try
        LSuggestion := LSvc.GeneratePRDescription(LNum, LDesc, LDiff, LMetadata.ProjectName, LMetadata.ProjectVersion);

        TThread.Synchronize(nil,
          procedure
          begin
            if Assigned(LView) then
            begin
              LView.UpdatePRBody(LSuggestion);
              LView.btnSuggest.Enabled := True;
              LView.btnSuggest.Caption := 'Suggest AI PR';
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
                ShowMessage(UTF8ToString('Erro: ') + LSuggestion);
                LView.btnSuggest.Enabled := True;
                LView.btnSuggest.Caption := 'Suggest AI PR';
              end;
            end);
        end;
      end;
    end).Start;
end;

procedure TGitPRView.btnCopyOpenClick(Sender: TObject);
var
  LUrl, LBranch: string;
begin
  if Trim(memPRBody.Text) = '' then
  begin
    ShowMessage(UTF8ToString('O corpo do PR está vazio.'));
    Exit;
  end;

  Clipboard.AsText := memPRBody.Text;

  LUrl := FRunner.GetRemoteUrl(FProjectDir);
  if LUrl = '' then
  begin
    ShowMessage(UTF8ToString('Texto copiado! Mas não foi possível localizar a URL remota para abrir o navegador.'));
    Exit;
  end;

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
  ShowMessage(UTF8ToString('Descrição copiada e navegador aberto!'));
  Close;
end;

end.
