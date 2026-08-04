unit GitLens4D.IDE.StatusView;

{ ============================================================================
  GitLens4D - Janela de Status (View)
  Princípio: Single Responsibility (SRP)

  Esta unidade contém o frame que será exibido como uma Tool Window
  no Delphi IDE. Ela é responsável apenas pela exibição e interação visual.
  ============================================================================ }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.StrUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Menus,
  Vcl.StdCtrls,
  Vcl.Clipbrd,
  Vcl.AppEvnts,
  GitLens4D.Interfaces,
  ToolsAPI,
  System.IOUtils,
  System.ImageList,
  Vcl.ImgList;

type
  TGitStatusView = class(TFrame)
    lstFiles: TListView;
    pmStatus: TPopupMenu;
    popDiff: TMenuItem;
    popRefresh: TMenuItem;
    popDiscard: TMenuItem;
    pnlCommit: TPanel;
    memCommitMsg: TMemo;
    pnlTopMessage: TPanel;
    lblTask: TLabel;
    lblDesc: TLabel;
    edtTaskNum: TEdit;
    edtTaskDesc: TEdit;
    Panel1: TPanel;
    btnSuggest: TButton;
    btnCommit: TButton;
    btnConfig: TButton;
    pnlBranch: TPanel;
    cbBranches: TComboBox;
    btnNewBranch: TButton;
    btnPush: TButton;
    btnPull: TButton;
    btnCopy: TButton;
    ImageList1: TImageList;
    lblBranch: TLabel;
    btnPR: TButton;
    Splitter1: TSplitter;
    chkSelectAll: TCheckBox;
    lblFormat: TLabel;
    cbFormat: TComboBox;
    procedure cbFormatChange(Sender: TObject);
    procedure popRefreshClick(Sender: TObject);
    procedure popDiffClick(Sender: TObject);
    procedure btnSuggestClick(Sender: TObject);
    procedure btnCommitClick(Sender: TObject);
    procedure btnConfigClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnNewBranchClick(Sender: TObject);
    procedure cbBranchesChange(Sender: TObject);
    procedure btnPushClick(Sender: TObject);
    procedure btnPullClick(Sender: TObject);
    procedure chkSelectAllClick(Sender: TObject);
    procedure popDiscardClick(Sender: TObject);
    procedure btnPRClick(Sender: TObject);
  private
    FProvider  : IGitStatusProvider;
    FRunner    : IGitRunner;
    FSettings  : ISettingsRepository;
    FAIService : IAIService;
    FProjectDir: string;
    FRepoRoot  : string;
    FAppEvents : TApplicationEvents;
    procedure InitClipboardHook;
    procedure HandleAppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure CheckUnsavedFiles;
    procedure CheckPendingChanges;
    function GetStatusIcon(AKind: TGitStatusKind): Integer;
    procedure SaveSettings;
    procedure PersistSelectedFormat;
    function GetProjectKey: string;
    function GetSelectedRelativeFile: string;
    function GetRelativeFile(AItem: TListItem): string;
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

{ TGitStatusView }

constructor TGitStatusView.Create(AOwner: TComponent; AProvider: IGitStatusProvider; ARunner: IGitRunner;
  ASettings: ISettingsRepository; AAIService: IAIService; const AProjectDir: string);
begin
  inherited Create(AOwner);
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

  InitClipboardHook;
  LoadSettings;
  RefreshStatus;
  RefreshBranches;
end;

constructor TGitStatusView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  InitClipboardHook;
end;

procedure TGitStatusView.InitClipboardHook;
begin
  // A IDE intercepta Ctrl+V/C/X/A/Z (atalhos do menu Edit) antes que a
  // mensagem chegue aos controles de janelas dockadas; por isso os edits
  // de task não aceitavam colar. Capturamos a tecla no loop de mensagens
  // e aplicamos a ação diretamente no edit focado deste frame.
  FAppEvents           := TApplicationEvents.Create(Self);
  FAppEvents.OnMessage := HandleAppMessage;
end;

procedure TGitStatusView.HandleAppMessage(var Msg: TMsg; var Handled: Boolean);
var
  LCtrl: TWinControl;
  LEdit: TCustomEdit;
begin
  if Msg.message <> WM_KEYDOWN then
    Exit;
  if (GetKeyState(VK_CONTROL) >= 0) or (GetKeyState(VK_MENU) < 0) then
    Exit;

  LCtrl := FindControl(Msg.hwnd);
  if not (LCtrl is TCustomEdit) or not ContainsControl(LCtrl) then
    Exit;

  LEdit   := TCustomEdit(LCtrl);
  Handled := True;
  case Msg.wParam of
    Ord('V'): LEdit.PasteFromClipboard;
    Ord('C'): LEdit.CopyToClipboard;
    Ord('X'): LEdit.CutToClipboard;
    Ord('A'): LEdit.SelectAll;
    Ord('Z'): LEdit.Undo;
  else
    Handled := False;
  end;
end;

destructor TGitStatusView.Destroy;
begin
  SaveSettings;
  inherited;
end;

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
      UTF8ToString('Deseja fazer o commit antes de prosseguir?'), mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      Abort;
    end;
  end;
end;

procedure TGitStatusView.RefreshBranches;
var
  BranchList: TStringList;
  Current   : string;
  AheadCount: Integer;
begin
  if not Assigned(FRunner) or (FProjectDir = '') then
    Exit;

  BranchList := FRunner.GetBranches(FProjectDir);
  try
    cbBranches.Items.Assign(BranchList);
    Current              := FRunner.GetCurrentBranch(FProjectDir);
    cbBranches.ItemIndex := cbBranches.Items.IndexOf(Current);

    // Atualiza contador de Push
    try
      AheadCount := FRunner.GetAheadCount(FProjectDir);
      if AheadCount > 0 then
        btnPush.Caption := Format('Push (%d)', [AheadCount])
      else
        btnPush.Caption := 'Push';
    except
      btnPush.Caption := 'Push';
    end;
  finally
    BranchList.Free;
  end;
end;

procedure TGitStatusView.btnCopyClick(Sender: TObject);
begin
  Clipboard.AsText := memCommitMsg.Text;
end;

procedure TGitStatusView.btnNewBranchClick(Sender: TObject);
var
  BranchName: string;
begin
  CheckUnsavedFiles;
  CheckPendingChanges;
  BranchName := InputBox('New Branch', 'Name:', '');
  if BranchName <> '' then
  begin
    FRunner.CreateBranch(BranchName, FProjectDir);
    RefreshBranches;
    RefreshStatus;
  end;
end;

procedure TGitStatusView.cbBranchesChange(Sender: TObject);
begin
  CheckUnsavedFiles;
  CheckPendingChanges;
  if cbBranches.ItemIndex <> -1 then
  begin
    FRunner.CheckoutBranch(cbBranches.Items[cbBranches.ItemIndex], FProjectDir);
    RefreshStatus;
    RefreshBranches;
  end;
end;

procedure TGitStatusView.btnPushClick(Sender: TObject);
begin
  CheckUnsavedFiles;
  FRunner.Push(FProjectDir);
  RefreshStatus;
  RefreshBranches;
  ShowMessage('Push realizado!');
end;

procedure TGitStatusView.btnPullClick(Sender: TObject);
begin
  CheckUnsavedFiles;
  try
    FRunner.Pull(FProjectDir);
    RefreshStatus;
    RefreshBranches;
    ShowMessage(UTF8ToString('Pull realizado com sucesso!'));
  except
    on E: Exception do
    begin
      RefreshStatus;
      RefreshBranches;
      ShowMessage(E.Message);
    end;
  end;
end;

procedure TGitStatusView.btnPRClick(Sender: TObject);
var
  LMetadata: TGitProjectMetadata;
begin
  LMetadata := TGitProjectProvider.Create.GetMetadata;
  ShowPRWindow(FRunner, FAIService, FSettings, FProjectDir, edtTaskNum.Text, edtTaskDesc.Text, LMetadata.ProjectName, LMetadata.ProjectVersion);
end;

procedure TGitStatusView.chkSelectAllClick(Sender: TObject);
var
  I: Integer;
begin
  lstFiles.Items.BeginUpdate;
  try
    for I                       := 0 to lstFiles.Items.Count - 1 do
      lstFiles.Items[I].Checked := chkSelectAll.Checked;
  finally
    lstFiles.Items.EndUpdate;
  end;
end;

procedure TGitStatusView.btnConfigClick(Sender: TObject);
begin
  ShowSettings(FSettings, True);
end;

procedure TGitStatusView.LoadSettings;
var
  LTaskNum, LTaskDesc                           : string;
  LDraft                                        : string;
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LProjFormat                                   : string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
begin
  if Assigned(FSettings) then
  begin
    FSettings.LoadTaskInfo(GetProjectKey, LTaskNum, LTaskDesc);
    edtTaskNum.Text  := LTaskNum;
    edtTaskDesc.Text := LTaskDesc;

    // O rascunho e restaurado sempre (inclusive vazio): se viesse so quando
    // preenchido, o texto do projeto anterior continuaria na tela.
    FSettings.LoadCommitDraft(GetProjectKey, LDraft);
    memCommitMsg.Text := LDraft;

    // Seletor de formato: a preferência do projeto atual tem prioridade
    // sobre a configuração global da IA.
    FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);
    FSettings.LoadProjectFormat(GetProjectKey, LProjFormat);
    if LProjFormat <> '' then
      LFormat := LProjFormat;

    cbFormat.ItemIndex := cbFormat.Items.IndexOf(LFormat);
    if cbFormat.ItemIndex = -1 then
      cbFormat.ItemIndex := 0;

    // Alinha a config global (lida pelo AIService) com o formato do projeto.
    PersistSelectedFormat;
  end;
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
  LSelected                                     : string;
begin
  if not Assigned(FSettings) or (cbFormat.ItemIndex = -1) then
    Exit;

  LSelected := cbFormat.Items[cbFormat.ItemIndex];

  // 1. Config global da IA (é a fonte lida pelo AIService ao gerar).
  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);
  FSettings.SaveAIConfig(LType, LEndpoint, LKey, LModel, LLang, LSelected, LTemp, LMaxTokens);

  // 2. Preferência por projeto (restaurada ao reabrir este repositório).
  FSettings.SaveProjectFormat(GetProjectKey, LSelected);
end;

procedure TGitStatusView.cbFormatChange(Sender: TObject);
begin
  PersistSelectedFormat;
end;

procedure TGitStatusView.SaveSettings;
var
  I        : Integer;
  LSelected: TStringList;
begin
  if Assigned(FSettings) then
  begin
    FSettings.SaveTaskInfo(GetProjectKey, edtTaskNum.Text, edtTaskDesc.Text);
    FSettings.SaveCommitDraft(GetProjectKey, memCommitMsg.Text);

    // Salva quais arquivos estão marcados
    LSelected := TStringList.Create;
    try
      for I := 0 to lstFiles.Items.Count - 1 do
      begin
        if lstFiles.Items[I].Checked then
          LSelected.Add(GetRelativeFile(lstFiles.Items[I]));
      end;
      FSettings.SaveSelectedFiles(GetProjectKey, LSelected.CommaText);
    finally
      LSelected.Free;
    end;
  end;
end;

procedure TGitStatusView.btnCommitClick(Sender: TObject);
var
  Msg      : string;
  I        : Integer;
  FilePath : string;
  LOutput  : string;
  LMarcados: Integer;
begin
  CheckUnsavedFiles;

  // A mensagem e validada antes de mexer no stage: assim uma mensagem vazia
  // nao deixa o repositorio com o stage ja limpo pelo reset.
  Msg := Trim(memCommitMsg.Text);
  if Msg = '' then
  begin
    ShowMessage(UTF8ToString('Por favor, informe uma mensagem de commit.'));
    Exit;
  end;

  LMarcados := 0;
  for I := 0 to lstFiles.Items.Count - 1 do
    if lstFiles.Items[I].Checked then
      Inc(LMarcados);

  if LMarcados = 0 then
  begin
    ShowMessage(UTF8ToString('Marque ao menos um arquivo para comitar.'));
    Exit;
  end;

  // 1. Limpa o stage atual para garantir commit seletivo
  FRunner.ResetStage(FProjectDir);

  // 2. Adiciona apenas o que o usuário marcou
  for I := 0 to lstFiles.Items.Count - 1 do
  begin
    if lstFiles.Items[I].Checked then
    begin
      FilePath := GetRelativeFile(lstFiles.Items[I]);
      FRunner.AddFile(FilePath, FProjectDir);
    end;
  end;

  // Se nada entrou no stage o commit nao tem o que gravar: avisa em vez de
  // seguir e exibir um "sucesso" que nao aconteceu.
  if not FRunner.HasStagedChanges(FProjectDir) then
  begin
    ShowMessage(UTF8ToString('Nenhuma alteração foi para o stage. ' +
      'Verifique se os arquivos marcados ainda possuem mudanças.'));
    RefreshStatus;
    Exit;
  end;

  // 3. Comita apenas o que foi adicionado (sem o -a)
  if not FRunner.Commit(Msg, FProjectDir, LOutput) then
  begin
    ShowMessage(UTF8ToString('Erro ao realizar commit:') + sLineBreak + LOutput);
    RefreshStatus;
    Exit;
  end;

  memCommitMsg.Clear;
  if Assigned(FSettings) then
  begin
    FSettings.SaveTaskInfo(GetProjectKey, edtTaskNum.Text, edtTaskDesc.Text);
    FSettings.SaveCommitDraft(GetProjectKey, '');   // Limpa rascunho após commit
    FSettings.SaveSelectedFiles(GetProjectKey, ''); // Limpa seleção após commit
  end;

  RefreshStatus;
  RefreshBranches;
  ShowMessage(UTF8ToString('Commit realizado com sucesso!'));
end;

function TGitStatusView.GetSelectedRelativeFile: string;
begin
  Result := GetRelativeFile(lstFiles.Selected);
end;

function TGitStatusView.GetRelativeFile(AItem: TListItem): string;
var
  LPath: string;
begin
  Result := '';
  if AItem = nil then
    Exit;

  LPath := AItem.SubItems[0];
  // Garante que o path termine com barra antes de concatenar o nome do arquivo
  if (LPath <> '') and (LPath <> '.\') and (LPath <> './') then
  begin
    if not LPath.EndsWith('\') and not LPath.EndsWith('/') then
      LPath := LPath + '\';
  end;

  if (LPath = '.\') or (LPath = './') then
    LPath := '';

  Result := LPath + AItem.Caption;
  Result := StringReplace(Result, '\', '/', [rfReplaceAll]);
end;

procedure TGitStatusView.UpdateCommitMsg(const AText: string);
begin
  memCommitMsg.Text := AText;
  SaveSettings; // Salva no registro ao receber sugestão da IA
end;

procedure TGitStatusView.EnableSuggest(AEnabled: Boolean);
begin
  btnSuggest.Enabled := AEnabled;
  if AEnabled then
    btnSuggest.Caption := 'Suggest AI'
  else
    btnSuggest.Caption := 'Thinking...';
end;

procedure TGitStatusView.btnSuggestClick(Sender: TObject);
var
  LDiff              : string;
  LTaskNum, LTaskDesc: string;
  LView              : TGitStatusView;
  LMetadata          : TGitProjectMetadata;
begin
  SaveSettings;
  PersistSelectedFormat; // garante que a IA use o formato selecionado na tela
  if not Assigned(FAIService) then
  begin
    ShowMessage('AI Service not initialized.');
    Exit;
  end;

  if not FAIService.IsConfigured then
  begin
    ShowMessage(UTF8ToString('IA não configurada! Por favor, clique no botão "IA" para configurar o endpoint e o modelo antes de solicitar sugestões.'));
    Exit;
  end;

  LMetadata := TGitProjectProvider.Create.GetMetadata;

  LTaskNum  := edtTaskNum.Text;
  LTaskDesc := edtTaskDesc.Text;

  EnableSuggest(False);

  LDiff := FRunner.Execute('git diff HEAD', FProjectDir);
  if LDiff.Trim = '' then
  begin
    ShowMessage(UTF8ToString('Não há alterações detectadas para sugerir uma mensagem.'));
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
        LSuggestion := FAIService.GenerateCommitMessage(LTaskNum, LTaskDesc, LDiff, LMetadata.ProjectName, LMetadata.ProjectVersion);

        TThread.Synchronize(nil,
          procedure
          begin
            if Assigned(LView) then
            begin
              LView.UpdateCommitMsg(LSuggestion);
              LView.EnableSuggest(True);
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
                LView.UpdateCommitMsg(UTF8ToString('Erro: ') + LSuggestion);
                LView.EnableSuggest(True);
              end;
            end);
        end;
      end;

    end).Start;
end;

procedure TGitStatusView.RefreshStatus;
begin
  if Assigned(FProvider) and (FRepoRoot <> '') then
    UpdateList(FProvider.GetStatus(FRepoRoot));
end;

procedure TGitStatusView.UpdateList(const AFiles: TGitFileStatusArray);
var
  I        : Integer;
  Item     : TListItem;
  LPath    : string;
  LFileName: string;
  LSelected: TStringList;
  LRelFile : string;
  LSavedStr: string;
begin
  LSelected := TStringList.Create;
  try
    if Assigned(FSettings) then
    begin
      FSettings.LoadSelectedFiles(GetProjectKey, LSavedStr);
      LSelected.CommaText := LSavedStr;
    end;

    lstFiles.Items.BeginUpdate;
    try
      lstFiles.Items.Clear;
      for I := 0 to High(AFiles) do
      begin
        Item         := lstFiles.Items.Add;
        LFileName    := AFiles[I].FileName.Replace('/', '\');
        Item.Caption := ExtractFileName(LFileName);

        LPath := ExtractFilePath(LFileName);
        if LPath = '' then
          LPath := '.\'
        else
          LPath := '.\' + LPath.Trim(['\']);

        Item.SubItems.Add(LPath);

        case AFiles[I].Status of
          skModified: Item.SubItems.Add('Modified');
          skAdded: Item.SubItems.Add('Added');
          skDeleted: Item.SubItems.Add('Deleted');
          skUntracked: Item.SubItems.Add('Untracked');
          skRenamed: Item.SubItems.Add('Renamed');
        else
            Item.SubItems.Add('Unknown');
        end;

        // Armazena o path relativo original (do git) no Data ou em um local seguro
        // Aqui vamos reconstruir no GetRelativeFile baseado no Caption e SubItems[0]

        Item.Data := Pointer(AFiles[I].Status);

        if AFiles[I].Staged then
          Item.SubItems[Item.SubItems.Count - 1] := Item.SubItems[Item.SubItems.Count - 1] + ' (Staged)';

        // Restaura a seleção se o arquivo estava marcado
        LRelFile := GetRelativeFile(Item);
        if LSelected.IndexOf(LRelFile) >= 0 then
          Item.Checked := True;
      end;
    finally
      lstFiles.Items.EndUpdate;
    end;
  finally
    LSelected.Free;
  end;
end;

procedure TGitStatusView.popRefreshClick(Sender: TObject);
begin
  RefreshStatus;
  RefreshBranches;
end;

procedure TGitStatusView.popDiffClick(Sender: TObject);
var
  LRelativeFile: string;
  LDiffText    : string;
  LStatus      : TGitStatusKind;
begin
  if lstFiles.Selected = nil then
    Exit;

  LRelativeFile := GetSelectedRelativeFile;
  if LRelativeFile = '' then
    Exit;

  LStatus := TGitStatusKind(lstFiles.Selected.Data);

  if LStatus = skUntracked then
  begin
    // Para arquivos novos, mostramos o conteúdo inteiro como adicionado (+)
    try
      LDiffText := FRunner.Execute(Format('git diff --no-index -- NUL "%s"', [LRelativeFile]), FRepoRoot);
      // Se falhar ou NUL não funcionar, tenta ler o arquivo e prefixar com +
      if LDiffText.Trim = '' then
      begin
        LDiffText := '--- /dev/null' + sLineBreak +
          '+++ b/' + LRelativeFile + sLineBreak +
          '@@ -0,0 +1 @@' + sLineBreak +
          '+' + StringReplace(TFile.ReadAllText(FRepoRoot + LRelativeFile.Replace('/', '\')), sLineBreak, sLineBreak + '+', [rfReplaceAll]);
      end;
    except
      on E: Exception do
        LDiffText := UTF8ToString('Erro ao ler arquivo untracked: ') + E.Message;
    end;
  end
  else
  begin
    LDiffText := FRunner.GetDiff(LRelativeFile, FRepoRoot);
  end;

  if LDiffText.Trim = '' then
  begin
    ShowMessage(UTF8ToString('Nenhuma diferença textual detectada.'));
    Exit;
  end;

  ShowDiff(LRelativeFile, LDiffText);
end;

procedure TGitStatusView.popDiscardClick(Sender: TObject);
var
  LFile: string;
begin
  LFile := GetSelectedRelativeFile;
  if LFile = '' then
    Exit;

  if MessageDlg(('Deseja realmente DESCARTAR todas as alterações do arquivo:') + sLineBreak + LFile + '?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FRunner.DiscardChanges(LFile, FRepoRoot);
    RefreshStatus;
  end;
end;

function TGitStatusView.GetStatusIcon(AKind: TGitStatusKind): Integer;
begin
  Result := -1;
end;

end.
