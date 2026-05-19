unit GitLens4D.Wizard;

{ ============================================================================
  GitLens4D - Wizard Principal (Orquestrador)
  Princípio: Open/Closed + Dependency Inversion (DIP)

  Este é o único arquivo que conhece TODAS as abstrações. Ele orquestra
  o fluxo sem implementar nenhuma regra de negócio diretamente:
  - Instancia as implementações concretas e as injeta nas interfaces.
  - Conecta os callbacks entre os componentes visuais e os serviços Git.
  - Responde aos eventos do IDE (menu, teclado, timer).

  Para trocar qualquer comportamento (ex: outro parser, outro storage),
  basta criar uma nova classe que implemente a interface correspondente
  e substituir a instância no construtor, sem tocar neste arquivo.
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
    FMessenger  : IIDEMessenger;

    // Componentes visuais/IDE (owned, não são interfaces)
    FMenu   : TGitLensMenu;
    FTracker: TGitLensCursorTracker;

    // ── Callbacks injetados nos componentes filhos ─────────────────────
    procedure OnEditorToggle(ANewState: Boolean);
    procedure OnDebugToggle(ANewState: Boolean);
    procedure OnHistoryAction;
    procedure OnCursorChanged(const AFile: string; ALine: Integer);
    function OnIsActive: Boolean;
    procedure OnKeyShortcut;

    // ── Helpers internos ──────────────────────────────────────────────
    function IsDebugging: Boolean;
    function GetCurrentCursorInfo(out AFile: string; out ALine: Integer): Boolean;
    procedure ShowGitBlame(const AFile: string; ALine: Integer);
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
  GitLens4D.Git.PathResolver,
  GitLens4D.Git.Runner,
  GitLens4D.Git.BlameParser,
  GitLens4D.Git.HistoryParser,
  GitLens4D.Settings,
  GitLens4D.IDE.Messenger,
  GitLens4D.IDE.KeyBinding;

{ TGitLens4D }

constructor TGitLens4D.Create;
var
  KeySvc      : IOTAKeyboardServices;
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

  // ── Componentes do IDE ───────────────────────────────────────────────
  FMenu := TGitLensMenu.Create(FEnabledEditor, FEnabledDebug,
    OnEditorToggle,
    OnDebugToggle,
    OnHistoryAction);

  FTracker := TGitLensCursorTracker.Create(OnCursorChanged, OnIsActive);

  if Supports(BorlandIDEServices, IOTAKeyboardServices, KeySvc) then
    FKeyBindIdx := KeySvc.AddKeyboardBinding(
      TGitLensKeyboardBinding.Create(OnKeyShortcut));
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
  // Ponto de entrada reservado pela interface; funcionalidade via menu/atalho.
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

procedure TGitLens4D.OnKeyShortcut;
var
  AFile: string;
  ALine: Integer;
begin
  // Sempre consulta a posição atual fresca (atalho = intenção explícita)
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

      TThread.Queue(nil,
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
  Messenger: IIDEMessenger;
begin
  if not FileExists(AFile) then
    Exit;

  DirBase   := ExtractFilePath(AFile);
  Runner    := FRunner;
  Parser    := FHistParser;
  Messenger := FMessenger;
  Comando   := Format(
    '"%s" log -n 10 -L %d,%d:"%s" ' +
    '--pretty=format:"#LOG#|%%h|%%an|%%ad|%%s" ' +
    '--date=format:"%%d/%%m/%%Y %%H:%%M:%%S"',
    [FGitPath, ALine, ALine, AFile]);

  TThread.CreateAnonymousThread(
    procedure
    var
      Raw: string;
      Linhas: TStringList;
    begin
      Raw := Runner.Execute(Comando, DirBase);
      Linhas := Parser.Parse(Trim(Raw), ALine);

      TThread.Queue(nil,
        procedure
        begin
          try
            Messenger.ShowMessages(Linhas);
          finally
            Linhas.Free;
          end;
        end);
    end).Start;
end;

// ── Registro do Expert no IDE ────────────────────────────────────────────

procedure Register;
begin
  RegisterPackageWizard(TGitLens4D.Create);
end;

end.
