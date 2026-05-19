unit GitLens4D.IDE.Menu;

{ ============================================================================
  GitLens4D - Gerenciamento do Menu do IDE
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: criar, configurar e destruir o menu "QSGitLens4D"
  no IDE, notificando o wizard por callbacks (eventos) sem conhecer sua lógica.

  O wizard injeta os callbacks no construtor (Dependency Injection via
  parâmetros de método), eliminando o acoplamento direto.
  ============================================================================ }

interface

uses
  ToolsAPI,
  Vcl.Menus;

type
  TMenuToggleEvent = procedure(ANewState: Boolean) of object;
  TMenuActionEvent = procedure of object;

  TGitLensMenu = class
  private
    FMenuRoot  : TMenuItem;
    FMenuEditor: TMenuItem;
    FMenuDebug : TMenuItem;

    FOnEditorToggle : TMenuToggleEvent;
    FOnDebugToggle  : TMenuToggleEvent;
    FOnHistoryAction: TMenuActionEvent;

    procedure MenuEditorClick(Sender: TObject);
    procedure MenuDebugClick(Sender: TObject);
    procedure MenuHistoryClick(Sender: TObject);
  public
    constructor Create(AEnabledEditor, AEnabledDebug: Boolean;
      AOnEditorToggle: TMenuToggleEvent;
      AOnDebugToggle: TMenuToggleEvent;
      AOnHistoryAction: TMenuActionEvent);
    destructor Destroy; override;

    procedure SyncEditorState(AEnabled: Boolean);
    procedure SyncDebugState(AEnabled: Boolean);
  end;

implementation

uses
  System.SysUtils;

{ TGitLensMenu }

constructor TGitLensMenu.Create(AEnabledEditor, AEnabledDebug: Boolean;
  AOnEditorToggle: TMenuToggleEvent;
  AOnDebugToggle: TMenuToggleEvent;
  AOnHistoryAction: TMenuActionEvent);
var
  NTAServices: INTAServices;
  Divisor    : TMenuItem;
  MenuHistory: TMenuItem;
begin
  inherited Create;

  FOnEditorToggle  := AOnEditorToggle;
  FOnDebugToggle   := AOnDebugToggle;
  FOnHistoryAction := AOnHistoryAction;

  if not Supports(BorlandIDEServices, INTAServices, NTAServices) then
    Exit;

  FMenuRoot         := TMenuItem.Create(nil);
  FMenuRoot.Caption := 'QSGitLens4D';

  FMenuEditor         := TMenuItem.Create(nil);
  FMenuEditor.Caption := 'Ativo no Editor';
  FMenuEditor.Checked := AEnabledEditor;
  FMenuEditor.OnClick := MenuEditorClick;

  FMenuDebug         := TMenuItem.Create(nil);
  FMenuDebug.Caption := 'Ativo no Debug';
  FMenuDebug.Checked := AEnabledDebug;
  FMenuDebug.OnClick := MenuDebugClick;

  Divisor         := TMenuItem.Create(nil);
  Divisor.Caption := '-';

  MenuHistory         := TMenuItem.Create(nil);
  MenuHistory.Caption := 'Explorar Histórico da Linha Atual (Ctrl+Shift+H)';
  MenuHistory.OnClick := MenuHistoryClick;

  FMenuRoot.Add(FMenuEditor);
  FMenuRoot.Add(FMenuDebug);
  FMenuRoot.Add(Divisor);
  FMenuRoot.Add(MenuHistory);

  NTAServices.AddActionMenu('viewsMenu', nil, FMenuRoot, True, True);
end;

destructor TGitLensMenu.Destroy;
begin
  FMenuRoot.Free; // libera todos os filhos (owned pelo parent)
  inherited Destroy;
end;

procedure TGitLensMenu.MenuEditorClick(Sender: TObject);
var
  NewState: Boolean;
begin
  NewState            := not FMenuEditor.Checked;
  FMenuEditor.Checked := NewState;
  if Assigned(FOnEditorToggle) then
    FOnEditorToggle(NewState);
end;

procedure TGitLensMenu.MenuDebugClick(Sender: TObject);
var
  NewState: Boolean;
begin
  NewState           := not FMenuDebug.Checked;
  FMenuDebug.Checked := NewState;
  if Assigned(FOnDebugToggle) then
    FOnDebugToggle(NewState);
end;

procedure TGitLensMenu.MenuHistoryClick(Sender: TObject);
begin
  if Assigned(FOnHistoryAction) then
    FOnHistoryAction;
end;

procedure TGitLensMenu.SyncEditorState(AEnabled: Boolean);
begin
  if Assigned(FMenuEditor) then
    FMenuEditor.Checked := AEnabled;
end;

procedure TGitLensMenu.SyncDebugState(AEnabled: Boolean);
begin
  if Assigned(FMenuDebug) then
    FMenuDebug.Checked := AEnabled;
end;

end.
