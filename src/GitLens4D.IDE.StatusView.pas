unit GitLens4D.IDE.StatusView;

{ ============================================================================
  GitLens4D - Janela de Status (View)
  Princípio: Single Responsibility (SRP)

  Esta unidade contém o frame exibido como Tool Window no Delphi IDE. Ela é
  responsável apenas pela exibição e interação visual.

  ----------------------------------------------------------------------------
  Por que HTML e não controles VCL
  ----------------------------------------------------------------------------
  A tela é desenhada em ui\status.html, dentro de um TWebBrowser hospedado por
  TGitWebHost. A troca foi feita para ter o mesmo visual do painel do agente
  Claude -- que não é um tema VCL, e sim uma página: no Delphi 10.2 não há como
  chegar naquele resultado com TPanel/TListView/TButton sem desenhar cada
  controle na mão.

  A regra que organiza esta unit depois da troca:

    O PASCAL É A FONTE DA VERDADE. O estado (branches, arquivos, rascunho de
    commit) vive aqui em campos e é empurrado para o JS por PushState. O
    documento é só a pintura -- pode ser recarregado a qualquer momento pelo
    vigia do host e volta idêntico, porque nada de essencial mora nele.

  Isso também resolve um problema de ordem: a IDE cria o frame e chama
  RefreshStatus/RefreshBranches (ver TStatusDockManager.FrameCreated) ANTES de
  o documento existir -- a navegação é assíncrona. Guardando o estado aqui, o
  primeiro push acontece quando o host avisa que o documento ficou pronto.

  O que NÃO mudou: toda a lógica de Git, IA e persistência é a mesma de antes,
  chamando as mesmas interfaces (IGitRunner, IGitStatusProvider, IAIService,
  ISettingsRepository).
  ============================================================================ }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.StrUtils,
  System.JSON,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Clipbrd,
  GitLens4D.Interfaces,
  GitLens4D.IDE.WebHost,
  ToolsAPI,
  System.IOUtils;

type
  TGitStatusView = class(TFrame)
  private
    FHost      : TGitWebHost;
    FProvider  : IGitStatusProvider;
    FRunner    : IGitRunner;
    FSettings  : ISettingsRepository;
    FAIService : IAIService;
    FProjectDir: string;
    FRepoRoot  : string;

    { Estado espelhado para o JS -- ver o cabeçalho da unit. }
    FFiles        : TGitFileStatusArray;
    FChecked      : TStringList; // caminhos relativos marcados
    FBranches     : TStringList;
    FCurrentBranch: string;
    FAhead        : Integer;
    FTaskNum      : string;
    FTaskDesc     : string;
    FCommitMsg    : string;
    FFormat       : string;
    FSuggesting   : Boolean;

    procedure HandleAction(AAction: TJSONObject);
    procedure HostDocumentReady(ASender: TObject);
    procedure PushState;
    procedure PullFromDocument;
    function BuildStateJson: string;
    function ActionStr(AAction: TJSONObject; const AName: string): string;

    procedure CheckUnsavedFiles;
    procedure CheckPendingChanges;
    procedure SaveSettings;
    procedure PersistSelectedFormat;
    function GetProjectKey: string;
    function StatusText(AKind: TGitStatusKind): string;
    function RelativeFile(const AFileName: string): string;
    function FindFile(const ARelative: string; out AIndex: Integer): Boolean;
    procedure DoCommit;
    procedure DoSuggest;
    procedure DoDiff(const ARelativeFile: string);
    procedure DoDiscard(const ARelativeFile: string);
    procedure UpdateCommitMsg(const AText: string);
    procedure EnableSuggest(AEnabled: Boolean);
  public
    constructor Create(AOwner: TComponent); overload; override;
    constructor Create(AOwner: TComponent; AProvider: IGitStatusProvider; ARunner: IGitRunner;
      ASettings: ISettingsRepository; AAIService: IAIService; const AProjectDir: string); reintroduce; overload;
    destructor Destroy; override;

    procedure RefreshStatus;
    procedure RefreshBranches;
    procedure LoadSettings;
    procedure UpdateList(const AFiles: TGitFileStatusArray);

    property Provider: IGitStatusProvider read FProvider write FProvider;
    property Runner: IGitRunner read FRunner write FRunner;
    property Settings: ISettingsRepository read FSettings write FSettings;
    property AIService: IAIService read FAIService write FAIService;
    property ProjectDir: string read FProjectDir write FProjectDir;
    property RepoRoot: string read FRepoRoot write FRepoRoot;
  end;

var
  GitStatusView: TGitStatusView;

implementation

uses
  GitLens4D.IDE.SettingsView,
  GitLens4D.IDE.DiffView,
  GitLens4D.IDE.PRView,
  GitLens4D.Git.ProjectProvider;

{$R *.dfm}

const
  { Ids dos elementos que o Pascal lê direto do DOM. Texto longo não cabe na
    URL sentinela (o Trident trunca sem avisar), então a mensagem de commit, os
    campos de tarefa e a lista de marcados viajam por aqui. }
  ID_COMMIT_MSG     = 'commitMsg';
  ID_TASK_NUM       = 'taskNum';
  ID_TASK_DESC      = 'taskDesc';
  ID_FORMAT         = 'formatSelect';
  ID_SELECTED_FILES = 'selectedFiles';
  ID_COPY_BUFFER    = 'copyBuffer';

  { Os mesmos dois formatos que o TComboBox oferecia. }
  FORMAT_MARKDOWN = 'Markdown';
  FORMAT_PLAIN    = 'Texto Puro';

{ TGitStatusView }

constructor TGitStatusView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FChecked  := TStringList.Create;
  FBranches := TStringList.Create;
  FFormat   := FORMAT_MARKDOWN;

  FHost                 := TGitWebHost.Create(Self, Self, 'status.html');
  FHost.OnAction        := HandleAction;
  FHost.OnDocumentReady := HostDocumentReady;
end;

constructor TGitStatusView.Create(AOwner: TComponent; AProvider: IGitStatusProvider; ARunner: IGitRunner;
  ASettings: ISettingsRepository; AAIService: IAIService; const AProjectDir: string);
begin
  Create(AOwner); // constrói host e listas

  FProvider   := AProvider;
  FRunner     := ARunner;
  FSettings   := ASettings;
  FAIService  := AAIService;
  FProjectDir := AProjectDir;

  if Assigned(FRunner) then
  begin
    FRepoRoot := FRunner.GetRepoRoot(FProjectDir);
    FRepoRoot := StringReplace(FRepoRoot, '/', '\', [rfReplaceAll]);
  end;

  LoadSettings;
  RefreshStatus;
  RefreshBranches;
end;

destructor TGitStatusView.Destroy;
begin
  { PullFromDocument antes de salvar: o que o usuário digitou e ainda não
    disparou onchange (foco ainda no campo) só existe no DOM. Sem isto, fechar
    o painel com o cursor no campo perderia o texto. }
  try
    PullFromDocument;
    SaveSettings;
  except
    { Fechamento nunca pode lançar: o frame está sendo destruído pela IDE. }
  end;
  FreeAndNil(FChecked);
  FreeAndNil(FBranches);
  inherited;
end;

{ ============================================================================
  Ponte com o documento
  ============================================================================ }

procedure TGitStatusView.HostDocumentReady(ASender: TObject);
begin
  { O documento acabou de nascer (ou renascer, pelo vigia). Ele não sabe de
    nada: todo o estado vem daqui. }
  PushState;
end;

function TGitStatusView.ActionStr(AAction: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if AAction = nil then
    Exit;
  LValue := AAction.GetValue(AName);
  if Assigned(LValue) then
    Result := LValue.Value;
end;

procedure TGitStatusView.HandleAction(AAction: TJSONObject);
var
  LType, LFile, LName: string;
  LMetadata          : TGitProjectMetadata;
begin
  LType := ActionStr(AAction, 'type');
  WebHostLogFmt('HandleAction: %s', [LType]);

  if LType = 'refresh' then
  begin
    RefreshStatus;
    RefreshBranches;
  end
  else if LType = 'commit' then
    DoCommit
  else if LType = 'suggest' then
    DoSuggest
  else if LType = 'copy' then
  begin
    PullFromDocument;
    Clipboard.AsText := FCommitMsg;
  end
  else if (LType = 'state.save') or (LType = 'selection.changed') then
  begin
    PullFromDocument;
    SaveSettings;
  end
  else if LType = 'format.change' then
  begin
    PullFromDocument;
    PersistSelectedFormat;
  end
  else if LType = 'file.diff' then
  begin
    LFile := ActionStr(AAction, 'file');
    if LFile <> '' then
      DoDiff(LFile);
  end
  else if LType = 'file.discard' then
  begin
    LFile := ActionStr(AAction, 'file');
    if LFile <> '' then
      DoDiscard(LFile);
  end
  else if LType = 'branch.change' then
  begin
    LName := ActionStr(AAction, 'name');
    if (LName <> '') and (LName <> FCurrentBranch) then
    begin
      CheckUnsavedFiles;
      CheckPendingChanges;
      FRunner.CheckoutBranch(LName, FProjectDir);
      RefreshStatus;
      RefreshBranches;
    end;
  end
  else if LType = 'branch.new' then
  begin
    CheckUnsavedFiles;
    CheckPendingChanges;
    LName := InputBox('New Branch', 'Name:', '');
    if LName <> '' then
    begin
      FRunner.CreateBranch(LName, FProjectDir);
      RefreshStatus;
      RefreshBranches;
    end;
  end
  else if LType = 'push' then
  begin
    CheckUnsavedFiles;
    FRunner.Push(FProjectDir);
    RefreshStatus;
    RefreshBranches;
    ShowMessage('Push realizado!');
  end
  else if LType = 'pull' then
  begin
    CheckUnsavedFiles;
    try
      FRunner.Pull(FProjectDir);
      RefreshStatus;
      RefreshBranches;
      ShowMessage('Pull realizado com sucesso!');
    except
      on E: Exception do
      begin
        RefreshStatus;
        RefreshBranches;
        ShowMessage(E.Message);
      end;
    end;
  end
  else if LType = 'pr' then
  begin
    PullFromDocument;
    LMetadata := TGitProjectProvider.Create.GetMetadata;
    ShowPRWindow(FRunner, FAIService, FSettings, FProjectDir, FTaskNum, FTaskDesc,
      LMetadata.ProjectName, LMetadata.ProjectVersion);
  end
  else if LType = 'config' then
    ShowSettings(FSettings, True);
end;

{ Traz do DOM o que o usuário digitou/marcou. Chamado antes de qualquer coisa
  que dependa desses valores -- persistir, comitar, pedir sugestão. }
procedure TGitStatusView.PullFromDocument;
var
  LValue: string;
  LList : TStringList;
  I     : Integer;
begin
  if not Assigned(FHost) or not FHost.DocumentReady then
    Exit;

  if FHost.TryReadValue(ID_COMMIT_MSG, LValue) then
    FCommitMsg := LValue;
  if FHost.TryReadValue(ID_TASK_NUM, LValue) then
    FTaskNum := LValue;
  if FHost.TryReadValue(ID_TASK_DESC, LValue) then
    FTaskDesc := LValue;
  if FHost.TryReadValue(ID_FORMAT, LValue) and (LValue <> '') then
    FFormat := LValue;

  { A lista de marcados chega como um caminho por linha (ver
    syncSelectedFiles() em ui\status.html). }
  if FHost.TryReadValue(ID_SELECTED_FILES, LValue) then
  begin
    LList := TStringList.Create;
    try
      LList.Text := LValue;
      FChecked.Clear;
      for I := 0 to LList.Count - 1 do
        if Trim(LList[I]) <> '' then
          FChecked.Add(Trim(LList[I]));
    finally
      LList.Free;
    end;
  end;
end;

function TGitStatusView.BuildStateJson: string;
var
  LRoot    : TJSONObject;
  LFiles   : TJSONArray;
  LBranches: TJSONArray;
  LFormats : TJSONArray;
  LItem    : TJSONObject;
  I        : Integer;
  LRel     : string;
  LWin     : string;
begin
  LRoot := TJSONObject.Create;
  try
    LBranches := TJSONArray.Create;
    for I := 0 to FBranches.Count - 1 do
      LBranches.Add(FBranches[I]);
    LRoot.AddPair('branches', LBranches);
    LRoot.AddPair('currentBranch', FCurrentBranch);
    LRoot.AddPair('ahead', TJSONNumber.Create(FAhead));

    LFiles := TJSONArray.Create;
    for I := 0 to High(FFiles) do
    begin
      LRel := RelativeFile(FFiles[I].FileName);
      LWin := StringReplace(LRel, '/', '\', [rfReplaceAll]);

      LItem := TJSONObject.Create;
      { 'file' e a chave de tudo (marcacao, commit, diff, discard): e o caminho
        como o git o reporta. 'name'/'path' existem so para a pintura. }
      LItem.AddPair('file', LRel);
      LItem.AddPair('name', ExtractFileName(LWin));
      LItem.AddPair('path', ExtractFilePath(LWin));
      LItem.AddPair('status', StatusText(FFiles[I].Status));
      LItem.AddPair('staged', TJSONBool.Create(FFiles[I].Staged));
      LItem.AddPair('checked', TJSONBool.Create(FChecked.IndexOf(LRel) >= 0));
      LFiles.AddElement(LItem);
    end;
    LRoot.AddPair('files', LFiles);

    LFormats := TJSONArray.Create;
    LFormats.Add(FORMAT_MARKDOWN);
    LFormats.Add(FORMAT_PLAIN);
    LRoot.AddPair('formats', LFormats);
    LRoot.AddPair('format', FFormat);

    LRoot.AddPair('taskNum', FTaskNum);
    LRoot.AddPair('taskDesc', FTaskDesc);
    LRoot.AddPair('commitMsg', FCommitMsg);
    LRoot.AddPair('busy', TJSONBool.Create(FSuggesting));

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TGitStatusView.PushState;
begin
  if Assigned(FHost) then
    FHost.CallJs('gitUpdate', BuildStateJson);
end;

{ ============================================================================
  Dados: status, branches e persistência
  ============================================================================ }

procedure TGitStatusView.RefreshStatus;
begin
  if Assigned(FProvider) and (FRepoRoot <> '') then
    UpdateList(FProvider.GetStatus(FRepoRoot));
end;

procedure TGitStatusView.UpdateList(const AFiles: TGitFileStatusArray);
var
  LSavedStr: string;
begin
  FFiles := AFiles;

  { Restaura a marcação salva -- é o que faz o painel reabrir com os mesmos
    arquivos marcados de antes. Só quando ainda não há marcação em memória:
    depois disso quem manda é o que o usuário marcou nesta sessão. }
  if Assigned(FSettings) and (FChecked.Count = 0) then
  begin
    FSettings.LoadSelectedFiles(GetProjectKey, LSavedStr);
    FChecked.CommaText := LSavedStr;
  end;

  PushState;
end;

procedure TGitStatusView.RefreshBranches;
var
  LBranchList: TStringList;
begin
  if not Assigned(FRunner) or (FProjectDir = '') then
    Exit;

  LBranchList := FRunner.GetBranches(FProjectDir);
  try
    FBranches.Assign(LBranchList);
    FCurrentBranch := FRunner.GetCurrentBranch(FProjectDir);
    { Contador do Push: quantos commits locais ainda não subiram. }
    try
      FAhead := FRunner.GetAheadCount(FProjectDir);
    except
      FAhead := 0;
    end;
  finally
    LBranchList.Free;
  end;

  PushState;
end;

procedure TGitStatusView.LoadSettings;
var
  LTaskNum, LTaskDesc                           : string;
  LDraft                                        : string;
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LProjFormat                                   : string;
  LSelected                                     : string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
begin
  if not Assigned(FSettings) then
    Exit;

  FSettings.LoadTaskInfo(GetProjectKey, LTaskNum, LTaskDesc);
  FTaskNum  := LTaskNum;
  FTaskDesc := LTaskDesc;

  { O rascunho é restaurado sempre (inclusive vazio): se viesse só quando
    preenchido, o texto do projeto anterior continuaria na tela. }
  FSettings.LoadCommitDraft(GetProjectKey, LDraft);
  FCommitMsg := LDraft;

  FSettings.LoadSelectedFiles(GetProjectKey, LSelected);
  FChecked.CommaText := LSelected;

  { Seletor de formato: a preferência do projeto atual tem prioridade sobre a
    configuração global da IA. }
  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);
  FSettings.LoadProjectFormat(GetProjectKey, LProjFormat);
  if LProjFormat <> '' then
    LFormat := LProjFormat;
  if (LFormat <> FORMAT_MARKDOWN) and (LFormat <> FORMAT_PLAIN) then
    LFormat := FORMAT_MARKDOWN;
  FFormat := LFormat;

  { Alinha a config global (lida pelo AIService) com o formato do projeto. }
  PersistSelectedFormat;

  PushState;
end;

function TGitStatusView.GetProjectKey: string;
begin
  if FRepoRoot <> '' then
    Result := LowerCase(FRepoRoot)
  else
    Result := LowerCase(FProjectDir);
end;

procedure TGitStatusView.PersistSelectedFormat;
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

procedure TGitStatusView.SaveSettings;
begin
  if not Assigned(FSettings) then
    Exit;
  FSettings.SaveTaskInfo(GetProjectKey, FTaskNum, FTaskDesc);
  FSettings.SaveCommitDraft(GetProjectKey, FCommitMsg);
  FSettings.SaveSelectedFiles(GetProjectKey, FChecked.CommaText);
end;

{ ============================================================================
  Guardas antes de operações que mexem na árvore
  ============================================================================ }

procedure TGitStatusView.CheckUnsavedFiles;
var
  ModSvc: IOTAModuleServices;
begin
  if Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
  begin
    if MessageDlg(('Deseja salvar todas as alterações pendentes no IDE antes de prosseguir?'),
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      ModSvc.SaveAll;
    end;
  end;
end;

procedure TGitStatusView.CheckPendingChanges;
var
  AFiles    : TGitFileStatusArray;
  I         : Integer;
  HasChanges: Boolean;
begin
  if not Assigned(FProvider) then
    Exit;

  AFiles     := FProvider.GetStatus(FProjectDir);
  HasChanges := False;
  for I      := 0 to High(AFiles) do
  begin
    if AFiles[I].Status in [skModified, skAdded, skDeleted, skRenamed] then
    begin
      HasChanges := True;
      Break;
    end;
  end;

  if HasChanges then
  begin
    if MessageDlg(('Existem arquivos com mudanças não comitadas (Modified/Deleted).') + sLineBreak +
      'Deseja fazer o commit antes de prosseguir?', mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      Abort;
    end;
  end;
end;

{ ============================================================================
  Ações
  ============================================================================ }

function TGitStatusView.StatusText(AKind: TGitStatusKind): string;
begin
  case AKind of
    skModified: Result := 'Modified';
    skAdded: Result := 'Added';
    skDeleted: Result := 'Deleted';
    skUntracked: Result := 'Untracked';
    skRenamed: Result := 'Renamed';
  else
    Result := 'Unknown';
  end;
end;

{ O caminho relativo como o git o reporta, sempre com '/'. É a chave usada na
  marcação, na persistência e nos comandos -- por isso é calculado num lugar só. }
function TGitStatusView.RelativeFile(const AFileName: string): string;
begin
  Result := StringReplace(AFileName, '\', '/', [rfReplaceAll]);
end;

function TGitStatusView.FindFile(const ARelative: string; out AIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  AIndex := -1;
  for I  := 0 to High(FFiles) do
    if SameText(RelativeFile(FFiles[I].FileName), ARelative) then
    begin
      AIndex := I;
      Exit(True);
    end;
end;

procedure TGitStatusView.DoCommit;
var
  I      : Integer;
  LOutput: string;
  LMsg   : string;
begin
  CheckUnsavedFiles;
  PullFromDocument;

  { A mensagem é validada antes de mexer no stage: assim uma mensagem vazia não
    deixa o repositório com o stage já limpo pelo reset. }
  LMsg := Trim(FCommitMsg);
  if LMsg = '' then
  begin
    ShowMessage('Por favor, informe uma mensagem de commit.');
    Exit;
  end;

  if FChecked.Count = 0 then
  begin
    ShowMessage('Marque ao menos um arquivo para comitar.');
    Exit;
  end;

  // 1. Limpa o stage atual para garantir commit seletivo
  FRunner.ResetStage(FProjectDir);

  // 2. Adiciona apenas o que o usuário marcou
  for I := 0 to FChecked.Count - 1 do
    FRunner.AddFile(FChecked[I], FProjectDir);

  { Se nada entrou no stage, o commit não tem o que gravar: avisa em vez de
    seguir e exibir um "sucesso" que não aconteceu. }
  if not FRunner.HasStagedChanges(FProjectDir) then
  begin
    ShowMessage('Nenhuma alteração foi para o stage. ' +
      'Verifique se os arquivos marcados ainda possuem mudanças.');
    RefreshStatus;
    Exit;
  end;

  // 3. Comita apenas o que foi adicionado (sem o -a)
  if not FRunner.Commit(LMsg, FProjectDir, LOutput) then
  begin
    ShowMessage('Erro ao realizar commit:' + sLineBreak + LOutput);
    RefreshStatus;
    Exit;
  end;

  FCommitMsg := '';
  FChecked.Clear;
  if Assigned(FSettings) then
  begin
    FSettings.SaveTaskInfo(GetProjectKey, FTaskNum, FTaskDesc);
    FSettings.SaveCommitDraft(GetProjectKey, '');   // Limpa rascunho após commit
    FSettings.SaveSelectedFiles(GetProjectKey, ''); // Limpa seleção após commit
  end;

  RefreshStatus;
  RefreshBranches;
  ShowMessage('Commit realizado com sucesso!');
end;

procedure TGitStatusView.UpdateCommitMsg(const AText: string);
var
  LJson: TJSONObject;
begin
  FCommitMsg := AText;
  { Só o campo da mensagem, e não um PushState inteiro: a sugestão chega depois
    e não pode redesenhar a lista nem roubar o foco de quem está digitando. }
  if Assigned(FHost) then
  begin
    LJson := TJSONObject.Create;
    try
      LJson.AddPair('text', AText);
      LJson.AddPair('busy', TJSONBool.Create(FSuggesting));
      FHost.CallJs('gitCommitMsg', LJson.ToJSON);
    finally
      LJson.Free;
    end;
  end;
  SaveSettings; // Salva no registro ao receber sugestão da IA
end;

procedure TGitStatusView.EnableSuggest(AEnabled: Boolean);
var
  LJson: TJSONObject;
begin
  FSuggesting := not AEnabled;
  if not Assigned(FHost) then
    Exit;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('busy', TJSONBool.Create(FSuggesting));
    FHost.CallJs('gitBusy', LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TGitStatusView.DoSuggest;
var
  LDiff              : string;
  LView              : TGitStatusView;
  LMetadata          : TGitProjectMetadata;
  LTaskNum, LTaskDesc: string;
begin
  PullFromDocument;
  SaveSettings;
  PersistSelectedFormat; // garante que a IA use o formato selecionado na tela

  if not Assigned(FAIService) then
  begin
    ShowMessage('AI Service not initialized.');
    Exit;
  end;

  if not FAIService.IsConfigured then
  begin
    ShowMessage('IA não configurada! Por favor, clique no botão "IA" para configurar ' +
      'o endpoint e o modelo antes de solicitar sugestões.');
    Exit;
  end;

  LMetadata := TGitProjectProvider.Create.GetMetadata;
  LTaskNum  := FTaskNum;
  LTaskDesc := FTaskDesc;

  EnableSuggest(False);

  LDiff := FRunner.Execute('git diff HEAD', FProjectDir);
  if LDiff.Trim = '' then
  begin
    ShowMessage('Não há alterações detectadas para sugerir uma mensagem.');
    EnableSuggest(True);
    Exit;
  end;

  LView := Self;
  TThread.CreateAnonymousThread(
    procedure
    var
      LSuggestion: string;
    begin
      try
        LSuggestion := FAIService.GenerateCommitMessage(LTaskNum, LTaskDesc, LDiff,
          LMetadata.ProjectName, LMetadata.ProjectVersion);
        TThread.Synchronize(nil,
          procedure
          begin
            if Assigned(LView) then
            begin
              LView.EnableSuggest(True);
              LView.UpdateCommitMsg(LSuggestion);
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
                LView.EnableSuggest(True);
                LView.UpdateCommitMsg('Erro: ' + LSuggestion);
              end;
            end);
        end;
      end;
    end).Start;
end;

procedure TGitStatusView.DoDiff(const ARelativeFile: string);
var
  LDiffText: string;
  LIndex   : Integer;
  LStatus  : TGitStatusKind;
begin
  LStatus := skUnknown;
  if FindFile(ARelativeFile, LIndex) then
    LStatus := FFiles[LIndex].Status;

  if LStatus = skUntracked then
  begin
    // Para arquivos novos, mostramos o conteúdo inteiro como adicionado (+)
    try
      LDiffText := FRunner.Execute(Format('git diff --no-index -- NUL "%s"', [ARelativeFile]), FRepoRoot);
      // Se falhar ou NUL não funcionar, tenta ler o arquivo e prefixar com +
      if LDiffText.Trim = '' then
      begin
        LDiffText := '--- /dev/null' + sLineBreak +
          '+++ b/' + ARelativeFile + sLineBreak +
          '@@ -0,0 +1 @@' + sLineBreak +
          '+' + StringReplace(TFile.ReadAllText(FRepoRoot + ARelativeFile.Replace('/', '\')),
          sLineBreak, sLineBreak + '+', [rfReplaceAll]);
      end;
    except
      on E: Exception do
        LDiffText := 'Erro ao ler arquivo untracked: ' + E.Message;
    end;
  end
  else
    LDiffText := FRunner.GetDiff(ARelativeFile, FRepoRoot);

  if LDiffText.Trim = '' then
  begin
    ShowMessage('Nenhuma diferença textual detectada.');
    Exit;
  end;

  ShowDiff(ARelativeFile, LDiffText);
end;

procedure TGitStatusView.DoDiscard(const ARelativeFile: string);
var
  LIndex: Integer;
begin
  if MessageDlg(('Deseja realmente DESCARTAR todas as alterações do arquivo:') + sLineBreak +
    ARelativeFile + '?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FRunner.DiscardChanges(ARelativeFile, FRepoRoot);
    { Sai também da marcação: o arquivo não tem mais o que comitar, e deixá-lo
      marcado faria o próximo commit tentar adicionar um caminho sem mudança. }
    LIndex := FChecked.IndexOf(ARelativeFile);
    if LIndex >= 0 then
      FChecked.Delete(LIndex);
    RefreshStatus;
  end;
end;

end.
