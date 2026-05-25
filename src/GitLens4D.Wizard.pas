unit GitLens4D.Wizard;

{ ============================================================================
  GitLens4D - Wizard Principal (Orquestrador)
  Princípio: Open/Closed + Dependency Inversion (DIP)

  Este é o único arquivo que conhece TODAS as abstrações. Ele orquestra
  o fluxo sem implementar nenhuma regra de negócio diretamente.
  ============================================================================ }

interface

uses
  GitLens4D.Interfaces,
  GitLens4D.IDE.Menu,
  GitLens4D.IDE.CursorTracker,
  ToolsAPI;

type
  TGitLens4D = class(TNotifierObject, IOTAWizard)
  private
    FGitPath      : string;
    FEnabledEditor: Boolean;
    FEnabledDebug : Boolean;
    FLastFile     : string;
    FLastLine     : Integer;
    FKeyBindIdx   : Integer;

    // Abstrações injetadas no construtor (DIP)
    FSettings   : ISettingsRepository;
    FRunner     : IGitRunner;
    FBlameParser: IBlameParser;
    FHistParser : IHistoryParser;
    FStatusProv : IGitStatusProvider;
    FAIService   : IAIService;
    FMessenger  : IIDEMessenger;

    // Componentes visuais/IDE (owned, não são interfaces)
    FMenu   : TGitLensMenu;
    FTracker: TGitLensCursorTracker;

    // ── Callbacks injetados nos componentes filhos ─────────────────────
    procedure OnEditorToggle(ANewState: Boolean);
    procedure OnDebugToggle(ANewState: Boolean);
    procedure OnHistoryAction;
    procedure OnStatusAction;
    procedure OnSettingsAction;
    procedure OnCursorChanged(const AFile: string; ALine: Integer);
    function OnIsActive: Boolean;
    procedure OnKeyShortcut;

    // ── Helpers internos ──────────────────────────────────────────────
    function IsDebugging: Boolean;
    function GetCurrentCursorInfo(out AFile: string; out ALine: Integer): Boolean;
    procedure ShowGitBlame(const AFile: string; ALine: Integer);
    procedure ReloadShortcuts;
  public
    constructor Create;
    destructor Destroy; override;

    // IOTAWizard
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;

    // Público para uso externo (ex: testes)
    procedure ShowGitHistory(const AFile: string; ALine: Integer);
  end;

procedure Register;

implementation

uses
  System.Classes,
  System.SysUtils,
  Vcl.Dialogs,
  GitLens4D.Git.PathResolver,
  GitLens4D.Git.Runner,
  GitLens4D.Git.BlameParser,
  GitLens4D.Git.HistoryParser,
  GitLens4D.Git.StatusParser,
  GitLens4D.Git.StatusProvider,
  GitLens4D.Git.AIService,
  GitLens4D.Settings,
  GitLens4D.IDE.Messenger,
  GitLens4D.IDE.KeyBinding,
  GitLens4D.IDE.StatusDock,
  GitLens4D.IDE.HistoryView,
  GitLens4D.IDE.SettingsView;

{ TGitLens4D }

constructor TGitLens4D.Create;
var
  PathResolver: IGitPathResolver;
begin
  inherited Create;
  FLastLine   := -1;
  FLastFile   := '';
  FKeyBindIdx := -1;

  // ── Injeção de dependências (DIP) ────────────────────────────────────
  FSettings    := TGitLensSettings.Create;
  FRunner      := TGitRunner.Create;
  FBlameParser := TBlameParser.Create;
  FHistParser  := THistoryParser.Create;
  FMessenger   := TIDEMessenger.Create;

  FSettings.Load(FEnabledEditor, FEnabledDebug);

  PathResolver := TGitPathResolver.Create;
  FGitPath     := PathResolver.Resolve;

  FStatusProv  := TGitStatusProvider.Create(FGitPath, FRunner, TStatusParser.Create);
  FAIService    := TAIService.Create(FSettings);
  RegisterStatusWindow(FStatusProv, FRunner, FSettings, FAIService);

  // ── Componentes do IDE ───────────────────────────────────────────────
  FMenu := TGitLensMenu.Create(FEnabledEditor, FEnabledDebug,
    OnEditorToggle,
    OnDebugToggle,
    OnHistoryAction,
    OnStatusAction,
    OnSettingsAction);

  FTracker := TGitLensCursorTracker.Create(OnCursorChanged, OnIsActive);

  ReloadShortcuts;
end;

destructor TGitLens4D.Destroy;
var
  KeySvc: IOTAKeyboardServices;
begin
  FTracker.Free;
  FMenu.Free;

  if FKeyBindIdx > 0 then
    if Supports(BorlandIDEServices, IOTAKeyboardServices, KeySvc) then
      KeySvc.RemoveKeyboardBinding(FKeyBindIdx);

  inherited Destroy;
end;

procedure TGitLens4D.ReloadShortcuts;
var
  KeySvc: IOTAKeyboardServices;
  LHist, LChanges, LTag: string;
begin
  if Supports(BorlandIDEServices, IOTAKeyboardServices, KeySvc) then
  begin
    if FKeyBindIdx > 0 then
    begin
      KeySvc.RemoveKeyboardBinding(FKeyBindIdx);
      FKeyBindIdx := -1;
    end;

    FSettings.LoadGeneralConfig(LHist, LChanges, LTag);
    FKeyBindIdx := KeySvc.AddKeyboardBinding(
      TGitLensKeyboardBinding.Create(OnHistoryAction, OnStatusAction, LHist, LChanges));
  end;
end;

// ── IOTAWizard ────────────────────────────────────────────────────────────

function TGitLens4D.GetIDString: string;
begin
  Result := 'vctamir.GitLens4D';
end;

function TGitLens4D.GetName: string;
begin
  Result := 'QSGitLens4D para Delphi';
end;

function TGitLens4D.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TGitLens4D.Execute;
begin
end;

// ── Helpers internos ──────────────────────────────────────────────────────

function TGitLens4D.IsDebugging: Boolean;
var
  DbgSvc: IOTADebuggerServices;
begin
  Result := False;
  if Supports(BorlandIDEServices, IOTADebuggerServices, DbgSvc) then
    Result := Assigned(DbgSvc.CurrentProcess);
end;

function TGitLens4D.GetCurrentCursorInfo(out AFile: string;
  out ALine: Integer): Boolean;
var
  EditorSvc : IOTAEditorServices;
  EditBuffer: IOTAEditBuffer;
  View      : IOTAEditView;
begin
  Result := False;
  try
    if not Supports(BorlandIDEServices, IOTAEditorServices, EditorSvc) then
      Exit;
    EditBuffer := EditorSvc.TopBuffer;
    if not Assigned(EditBuffer) then
      Exit;
    AFile := EditBuffer.FileName;
    View  := EditBuffer.TopView;
    if Assigned(View) then
    begin
      ALine  := View.CursorPos.Line;
      Result := True;
    end;
  except
  end;
end;

// ── Callbacks dos componentes filhos ──────────────────────────────────────

function TGitLens4D.OnIsActive: Boolean;
begin
  if IsDebugging then
    Result := FEnabledDebug
  else
    Result := FEnabledEditor;

  if not Result then
    FMessenger.Hide;
end;

procedure TGitLens4D.OnCursorChanged(const AFile: string; ALine: Integer);
begin
  FLastFile := AFile;
  FLastLine := ALine;
  ShowGitBlame(AFile, ALine);
end;

procedure TGitLens4D.OnEditorToggle(ANewState: Boolean);
begin
  FEnabledEditor := ANewState;
  FSettings.Save(FEnabledEditor, FEnabledDebug);
  if FEnabledEditor then
    FTracker.Reset
  else if not IsDebugging then
    FMessenger.Hide;
end;

procedure TGitLens4D.OnDebugToggle(ANewState: Boolean);
begin
  FEnabledDebug := ANewState;
  FSettings.Save(FEnabledEditor, FEnabledDebug);
  if FEnabledDebug then
    FTracker.Reset
  else if IsDebugging then
    FMessenger.Hide;
end;

procedure TGitLens4D.OnHistoryAction;
begin
  if (FLastFile <> '') and (FLastLine > 0) then
    ShowGitHistory(FLastFile, FLastLine);
end;

procedure TGitLens4D.OnStatusAction;
begin
  ShowStatusWindow;
end;

procedure TGitLens4D.OnSettingsAction;
begin
  ShowSettings(FSettings);
  ReloadShortcuts;
end;

procedure TGitShortcutSyncProc(const AMessenger: IIDEMessenger; const AMsg: string);
begin
  AMessenger.ShowMessage(AMsg);
end;

procedure TGitLens4D.OnKeyShortcut;
var
  AFile: string;
  ALine: Integer;
begin
  if GetCurrentCursorInfo(AFile, ALine) then
    ShowGitHistory(AFile, ALine);
end;

// ── Lógica principal: Blame em tempo real ────────────────────────────────

procedure TGitLens4D.ShowGitBlame(const AFile: string; ALine: Integer);
var
  Comando  : string;
  DirBase  : string;
  Runner   : IGitRunner;
  Parser   : IBlameParser;
  Messenger: IIDEMessenger;
begin
  if (AFile = '') or (ALine <= 0) or not FileExists(AFile) then
    Exit;

  DirBase   := ExtractFilePath(AFile);
  Runner    := FRunner;
  Parser    := FBlameParser;
  Messenger := FMessenger;
  Comando   := Format('"%s" blame -p -L %d,%d -- "%s"',
    [FGitPath, ALine, ALine, AFile]);

  TThread.CreateAnonymousThread(
    procedure
    var
      Raw: string;
      Mensagem: string;
    begin
      Raw := Runner.Execute(Comando, DirBase);
      Mensagem := Parser.Parse(Trim(Raw), ALine);

      TThread.Synchronize(nil,
        procedure
        begin
          Messenger.ShowMessage(Mensagem);
        end);
    end).Start;
end;

// ── Lógica principal: Histórico da linha ─────────────────────────────────

procedure TGitLens4D.ShowGitHistory(const AFile: string; ALine: Integer);
var
  Comando  : string;
  DirBase  : string;
  Runner   : IGitRunner;
  Parser   : IHistoryParser;
  LStart, LEnd: Integer;
begin
  if not FileExists(AFile) then
    Exit;

  DirBase   := ExtractFilePath(AFile);
  Runner    := FRunner;
  Parser    := FHistParser;
  
  LStart := ALine - 2;
  if LStart < 1 then LStart := 1;
  LEnd := ALine + 2;

  Comando   := Format(
    '"%s" log -n 10 -L %d,%d:"%s" ' +
    '--pretty=format:"#LOG#|%%h|%%an|%%ad|%%s" ' +
    '--date=format:"%%d/%%m/%%Y %%H:%%M:%%S"',
    [FGitPath, LStart, LEnd, AFile]);

  TThread.CreateAnonymousThread(
    procedure
    var
      Raw: string;
      LHistory: TGitHistoryArray;
      LFile: string;
      LLine: Integer;
    begin
      Raw := Runner.Execute(Comando, DirBase);
      LHistory := Parser.Parse(Trim(Raw), ALine);
      LFile := AFile;
      LLine := ALine;

      TThread.Synchronize(nil,
        procedure
        begin
          if Length(LHistory) > 0 then
            ShowHistoryWindow(LFile, LLine, LHistory)
          else
            ShowMessage(UTF8ToString('Nenhum histórico encontrado para esta linha.'));
        end);
    end).Start;
end;

procedure Register;
begin
  RegisterPackageWizard(TGitLens4D.Create);
end;

end.
