unit GitLens4D.IDE.StatusView;

{ ============================================================================
  GitLens4D - Janela de Status (View)
  Princípio: Single Responsibility (SRP)

  Esta unidade contém o formulário que será exibido como uma Tool Window
  no Delphi IDE. Ela é responsável apenas pela exibição e interação visual.
  ============================================================================ }

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
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Menus,
  Vcl.StdCtrls,
  Vcl.Clipbrd,
  GitLens4D.Interfaces,
  ToolsAPI,
  System.IOUtils, System.ImageList, Vcl.ImgList;

type
  TGitStatusView = class(TForm)
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
    chkSelectAll: TCheckBox;
    ImageList1: TImageList;
    lblBranch: TLabel;
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
  private
    FProvider  : IGitStatusProvider;
    FRunner    : IGitRunner;
    FSettings  : ISettingsRepository;
    FAIService : IAIService;
    FProjectDir: string;
    FRepoRoot  : string;

    procedure ApplyTheme;
    procedure RefreshStatus;
    procedure RefreshBranches;
    procedure CheckUnsavedFiles;
    procedure CheckPendingChanges;
    function GetStatusIcon(AKind: TGitStatusKind): Integer;
    procedure LoadSettings;
    procedure SaveSettings;
    function GetSelectedRelativeFile: string;
    procedure UpdateCommitMsg(const AText: string);
    procedure EnableSuggest(AEnabled: Boolean);
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent; AProvider: IGitStatusProvider; ARunner: IGitRunner;
      ASettings: ISettingsRepository; AAIService: IAIService; const AProjectDir: string); reintroduce;
    procedure UpdateList(const AFiles: TGitFileStatusArray);
  end;

var
  GitStatusView: TGitStatusView;

implementation

uses
  GitLens4D.IDE.AIConfigView,
  GitLens4D.IDE.DiffView;

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

  Self.PopupMode  := pmAuto;
  Self.KeyPreview := True;

  LoadSettings;
  RefreshStatus;
  RefreshBranches;
end;

procedure TGitStatusView.DoShow;
begin
  inherited;
  ApplyTheme;
end;

procedure TGitStatusView.ApplyTheme;
var
  LThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingSvc) then
  begin
    if LThemingSvc.IDEThemingEnabled then
    begin
      LThemingSvc.ApplyTheme(Self);
      pnlCommit.ParentBackground     := False;
      pnlCommit.Color                := Self.Color;
      pnlTopMessage.ParentBackground := False;
      pnlTopMessage.Color            := Self.Color;
      Panel1.ParentBackground        := False;
      Panel1.Color                   := Self.Color;
      pnlBranch.ParentBackground     := False;
      pnlBranch.Color                := Self.Color;
    end;
  end;
end;

procedure TGitStatusView.CheckUnsavedFiles;
var
  ModSvc: IOTAModuleServices;
begin
  if Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
  begin
    if MessageDlg('Deseja salvar todas as alterações pendentes no IDE antes de prosseguir?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      ModSvc.SaveAll;
    end;
  end;
end;

procedure TGitStatusView.CheckPendingChanges;
var
  AFiles: TGitFileStatusArray;
  I: Integer;
  HasChanges: Boolean;
begin
  if not Assigned(FProvider) then Exit;
  
  AFiles := FProvider.GetStatus(FProjectDir);
  HasChanges := False;
  for I := 0 to High(AFiles) do
  begin
    if AFiles[I].Status in [skModified, skAdded, skDeleted, skRenamed] then
    begin
      HasChanges := True;
      Break;
    end;
  end;

  if HasChanges then
  begin
    if MessageDlg('Existem arquivos com mudanças não comitadas (Modified/Deleted).' + sLineBreak + 
                  'Deseja fazer o commit antes de prosseguir?', mtWarning, [mbYes, mbNo], 0) = mrYes then
    begin
      Abort; 
    end;
  end;
end;

procedure TGitStatusView.RefreshBranches;
var
  BranchList: TStringList;
  Current   : string;
begin
  if not Assigned(FRunner) then
    Exit;

  BranchList := FRunner.GetBranches(FProjectDir);
  try
    cbBranches.Items.Assign(BranchList);
    Current              := FRunner.GetCurrentBranch(FProjectDir);
    cbBranches.ItemIndex := cbBranches.Items.IndexOf(Current);
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
  end;
end;

procedure TGitStatusView.btnPushClick(Sender: TObject);
begin
  CheckUnsavedFiles;
  FRunner.Push(FProjectDir);
  ShowMessage('Push realizado!');
end;

procedure TGitStatusView.btnPullClick(Sender: TObject);
begin
  CheckUnsavedFiles;
  FRunner.Pull(FProjectDir);
  RefreshStatus;
  ShowMessage('Pull realizado!');
end;

procedure TGitStatusView.chkSelectAllClick(Sender: TObject);
var
  I: Integer;
begin
  lstFiles.Items.BeginUpdate;
  try
    for I := 0 to lstFiles.Items.Count - 1 do
      lstFiles.Items[I].Checked := chkSelectAll.Checked;
  finally
    lstFiles.Items.EndUpdate;
  end;
end;

procedure TGitStatusView.btnConfigClick(Sender: TObject);
begin
  ShowAIConfig(FSettings);
end;

procedure TGitStatusView.LoadSettings;
var
  LTaskNum, LTaskDesc: string;
  LDraft: string;
begin
  if Assigned(FSettings) then
  begin
    FSettings.LoadTaskInfo(LTaskNum, LTaskDesc);
    edtTaskNum.Text  := LTaskNum;
    edtTaskDesc.Text := LTaskDesc;
    
    FSettings.LoadCommitDraft(LDraft);
    if LDraft <> '' then
      memCommitMsg.Text := LDraft;
  end;
end;

procedure TGitStatusView.SaveSettings;
begin
  if Assigned(FSettings) then
  begin
    FSettings.SaveTaskInfo(edtTaskNum.Text, edtTaskDesc.Text);
    FSettings.SaveCommitDraft(memCommitMsg.Text);
  end;
end;

procedure TGitStatusView.btnCommitClick(Sender: TObject);
var
  Msg: string;
  I: Integer;
  FilePath: string;
begin
  CheckUnsavedFiles;
  
  // 1. Limpa o stage atual (git reset) para garantir commit seletivo
  FRunner.Execute('git reset', FProjectDir);
  
  // 2. Adiciona apenas o que o usuário marcou
  for I := 0 to lstFiles.Items.Count - 1 do
  begin
    if lstFiles.Items[I].Checked then
    begin
      FilePath := lstFiles.Items[I].SubItems[0].Replace('.\', '', [rfReplaceAll]) + lstFiles.Items[I].Caption;
      FRunner.AddFile(FilePath, FProjectDir);
    end;
  end;

  Msg := Trim(memCommitMsg.Text);
  if Msg = '' then
  begin
    ShowMessage('Por favor, informe uma mensagem de commit.');
    Exit;
  end;

  // 3. Comita apenas o que foi adicionado (sem o -a)
  FRunner.Execute(Format('git commit -m "%s"', [Msg]), FProjectDir);
  
  memCommitMsg.Clear;
  if Assigned(FSettings) then
  begin
    FSettings.SaveTaskInfo(edtTaskNum.Text, edtTaskDesc.Text);
    FSettings.SaveCommitDraft(''); // Limpa rascunho após commit
  end;
  
  RefreshStatus;
  ShowMessage('Commit realizado com sucesso!');
end;

function TGitStatusView.GetSelectedRelativeFile: string;
var
  LPath: string;
begin
  Result := '';
  if lstFiles.Selected = nil then
    Exit;

  LPath := lstFiles.Selected.SubItems[0];
  if (LPath = '.\') or (LPath = './') then
    LPath := '';

  Result := LPath + lstFiles.Selected.Caption;
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
  LProjName, LProjVer: string;
  LModSvc            : IOTAModuleServices;
  LProject           : IOTAProject;
  LView              : TGitStatusView;
begin
  SaveSettings;
  if not Assigned(FAIService) then
  begin
    ShowMessage('AI Service not initialized.');
    Exit;
  end;

  LProjName := 'Unknown Project';
  LProjVer  := '1.0.0.0';

  if Supports(BorlandIDEServices, IOTAModuleServices, LModSvc) then
  begin
    LProject := LModSvc.GetActiveProject;
    if Assigned(LProject) then
    begin
      LProjName := ExtractFileName(LProject.FileName).Replace(ExtractFileExt(LProject.FileName),emptystr,[rfIgnoreCase]);
      if Assigned(LProject.ProjectOptions) then
      begin
        try
          LProjVer := VarToStrDef(LProject.ProjectOptions.Values['FileVersion'], '');
          if LProjVer = '' then
          begin
            LProjVer := VarToStrDef(LProject.ProjectOptions.Values['MajorVersion'], '1') + '.' +
              VarToStrDef(LProject.ProjectOptions.Values['MinorVersion'], '0') + '.' +
              VarToStrDef(LProject.ProjectOptions.Values['Release'], '0') + '.' +
              VarToStrDef(LProject.ProjectOptions.Values['Build'], '0');
          end;
        except
        end;
      end;
    end;
  end;

  LTaskNum  := edtTaskNum.Text;
  LTaskDesc := edtTaskDesc.Text;

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
        LSuggestion := FAIService.GenerateCommitMessage(LTaskNum, LTaskDesc, LDiff, LProjName, LProjVer);

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
                LView.UpdateCommitMsg('Erro: ' + LSuggestion);
                LView.EnableSuggest(True);
              end;
            end);
        end;
      end;

    end).Start;
end;

procedure TGitStatusView.RefreshStatus;
begin
  if Assigned(FProvider) and (FProjectDir <> '') then
    UpdateList(FProvider.GetStatus(FProjectDir));
end;

procedure TGitStatusView.UpdateList(const AFiles: TGitFileStatusArray);
var
  I        : Integer;
  Item     : TListItem;
  LPath    : string;
  LFileName: string;
begin
  lstFiles.Items.BeginUpdate;
  try
    lstFiles.Items.Clear;
    for I := 0 to High(AFiles) do
    begin
      Item         := lstFiles.Items.Add;
      LFileName    := FProjectDir + AFiles[I].FileName.Replace('/', '\', [rfReplaceAll]);
      Item.Caption := ExtractFileName(LFileName);
      LPath        := ExtractFilePath(LFileName).Replace(FProjectDir, '.\', [rfIgnoreCase]).Trim(['\']);
      if LPath = '' then
        LPath := '.\';
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

      if AFiles[I].Staged then
        Item.SubItems[Item.SubItems.Count - 1] := Item.SubItems[Item.SubItems.Count - 1] + ' (Staged)';
    end;
  finally
    lstFiles.Items.EndUpdate;
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
begin
  LRelativeFile := GetSelectedRelativeFile;
  if LRelativeFile = '' then
    Exit;

  LDiffText := FRunner.GetDiff(LRelativeFile, FProjectDir);
  if LDiffText.Trim = '' then
  begin
    ShowMessage('Nenhuma diferença textual detectada.');
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

  if MessageDlg('Deseja realmente DESCARTAR todas as alterações do arquivo:' + sLineBreak + LFile + '?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FRunner.DiscardChanges(LFile, FProjectDir);
    RefreshStatus;
  end;
end;

function TGitStatusView.GetStatusIcon(AKind: TGitStatusKind): Integer;
begin
  Result := -1;
end;

end.
