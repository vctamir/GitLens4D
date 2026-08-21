unit GitLens4D.IDE.Menu;

{ ============================================================================
  GitLens4D - Menus do IDE
  Princípio: Single Responsibility (SRP)

  Duas superfícies para as mesmas ações, notificando o wizard por callbacks sem
  conhecer a lógica dele:

    TGitLensMenu       - o menu "QSGitLens4D" em View.
    TGitLensEditorMenu - o submenu "GitLens4D" no botão direito do editor.

  As legendas dos dois trazem o atalho REAL (lido das configurações), e não um
  texto fixo: o atalho é configurável, e uma legenda que mente sobre ele é pior
  que legenda nenhuma.
  ============================================================================ }

interface

uses
  ToolsAPI,
  DockForm, // TDockableForm, exigido pela assinatura de INTAEditServicesNotifier
  System.Classes,
  Vcl.Forms,
  Vcl.Menus;

type
  TMenuToggleEvent = procedure(ANewState: Boolean) of object;
  TMenuActionEvent = procedure of object;

  { ---------------------------------------------------------------------- }

  TGitLensMenu = class
  private
    FMenuRoot    : TMenuItem;
    FMenuEditor  : TMenuItem;
    FMenuDebug   : TMenuItem;
    FMenuStatus  : TMenuItem;
    FMenuHistory : TMenuItem;
    FMenuSettings: TMenuItem;

    FOnEditorToggle  : TMenuToggleEvent;
    FOnDebugToggle   : TMenuToggleEvent;
    FOnHistoryAction : TMenuActionEvent;
    FOnStatusAction  : TMenuActionEvent;
    FOnSettingsAction: TMenuActionEvent;

    procedure MenuEditorClick(Sender: TObject);
    procedure MenuDebugClick(Sender: TObject);
    procedure MenuHistoryClick(Sender: TObject);
    procedure MenuStatusClick(Sender: TObject);
    procedure MenuSettingsClick(Sender: TObject);
  public
    constructor Create(AEnabledEditor, AEnabledDebug: Boolean;
      AOnEditorToggle: TMenuToggleEvent;
      AOnDebugToggle: TMenuToggleEvent;
      AOnHistoryAction: TMenuActionEvent;
      AOnStatusAction: TMenuActionEvent;
      AOnSettingsAction: TMenuActionEvent;
      const AHistShortcut, AChangesShortcut: string);
    destructor Destroy; override;

    procedure SyncEditorState(AEnabled: Boolean);
    procedure SyncDebugState(AEnabled: Boolean);
    procedure SyncShortcuts(const AHist, AChanges: string);
  end;

  { ---------------------------------------------------------------------- }

  TGitLensEditorMenu = class;

  { Notificador que avisa quando uma janela de editor aparece ou é ativada. É o
    gancho necessário: o TPopupMenu do editor só existe depois que a janela
    existe.

    Fica declarado aqui (e não escondido na implementation) por um motivo de
    tempo de vida: quem o mantém vivo é a IDE, através da referência que ela
    guarda no AddNotifier. Se este pacote for descarregado antes de a IDE soltar
    essa referência, o notificador continua existindo -- e chamar o dono já
    liberado seria Access Violation. Por isso o dono precisa conseguir dizer
    "esqueça de mim" (Detach) antes de morrer, e para isso precisa enxergar o
    tipo. }
  TGitLensEditWindowNotifier = class(TNotifierObject, INTAEditServicesNotifier)
  private
    FOwner: TGitLensEditorMenu;
  public
    constructor Create(AOwner: TGitLensEditorMenu);
    { O dono morreu: nao chame mais ninguem. }
    procedure Detach;
    { INTAEditServicesNotifier }
    procedure WindowShow(const EditWindow: INTAEditWindow; Show, LoadedFromDesktop: Boolean);
    procedure WindowNotification(const EditWindow: INTAEditWindow; Operation: TOperation);
    procedure WindowActivated(const EditWindow: INTAEditWindow);
    procedure WindowCommand(const EditWindow: INTAEditWindow; Command, Param: Integer; var Handled: Boolean);
    procedure EditorViewActivated(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure EditorViewModified(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure DockFormVisibleChanged(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormUpdated(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormRefresh(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
  end;

  { Submenu "GitLens4D" dentro do menu de contexto do editor de código.
    TComponent porque precisa de Notification/FreeNotification para não deixar
    ponteiro morto no menu da IDE -- ver o comentário extenso na implementation. }
  TGitLensEditorMenu = class(TComponent)
  private
    FRoot        : TMenuItem;
    FItemEditor  : TMenuItem;
    FInstalledIn : TPopupMenu;
    FNotifierIndex: Integer;
    { Referência forte: mantém o notificador vivo enquanto ele estiver
      registrado, e dá acesso ao objeto para o Detach do destrutor. }
    FNotifier    : INTAEditServicesNotifier;
    FNotifierObj : TGitLensEditWindowNotifier;

    FEnabledEditor   : Boolean;
    FHistShortcut    : string;
    FChangesShortcut : string;

    FOnEditorToggle  : TMenuToggleEvent;
    FOnHistoryAction : TMenuActionEvent;
    FOnStatusAction  : TMenuActionEvent;
    FOnSettingsAction: TMenuActionEvent;

    function FindEditorPopup(AForm: TCustomForm): TPopupMenu;
    procedure BuildItems;
    procedure HistoryClick(Sender: TObject);
    procedure StatusClick(Sender: TObject);
    procedure SettingsClick(Sender: TObject);
    procedure EditorToggleClick(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOnHistoryAction, AOnStatusAction, AOnSettingsAction: TMenuActionEvent;
      AOnEditorToggle: TMenuToggleEvent; AEnabledEditor: Boolean;
      const AHistShortcut, AChangesShortcut: string); reintroduce;
    destructor Destroy; override;

    { Pendura (ou remuda) o submenu no menu de contexto desta janela de editor.
      Idempotente: é chamado a cada ativação de janela. }
    procedure InstallInto(const AEditWindow: INTAEditWindow);

    procedure SyncEditorState(AEnabled: Boolean);
    procedure SyncShortcuts(const AHist, AChanges: string);
  end;

implementation

uses
  System.SysUtils;

const
  { Nome do TPopupMenu do editor na janela do RAD Studio. Se um dia mudar, o
    FindEditorPopup ainda acha o primeiro TPopupMenu da janela. }
  EDITOR_POPUP_NAME = 'EditorLocalMenu';
  ROOT_ITEM_NAME    = 'GitLens4DEditorMenu';

{ Legenda com o atalho de verdade entre parênteses. Sem atalho configurado,
  fica só o texto -- e não um par de parênteses vazio. }
function WithShortcut(const ACaption, AShortcut: string): string;
begin
  if Trim(AShortcut) = '' then
    Result := ACaption
  else
    Result := Format('%s (%s)', [ACaption, Trim(AShortcut)]);
end;

function HistoryCaption(const AShortcut: string): string;
begin
  Result := WithShortcut('Histórico da Linha Atual', AShortcut);
end;

function ChangesCaption(const AShortcut: string): string;
begin
  Result := WithShortcut('Alterações do Git (Git Changes)', AShortcut);
end;

{ ============================================================================
  TGitLensMenu -- View > QSGitLens4D
  ============================================================================ }

constructor TGitLensMenu.Create(AEnabledEditor, AEnabledDebug: Boolean;
  AOnEditorToggle: TMenuToggleEvent;
  AOnDebugToggle: TMenuToggleEvent;
  AOnHistoryAction: TMenuActionEvent;
  AOnStatusAction: TMenuActionEvent;
  AOnSettingsAction: TMenuActionEvent;
  const AHistShortcut, AChangesShortcut: string);
var
  NTAServices: INTAServices;
  Divisor    : TMenuItem;
begin
  inherited Create;

  FOnEditorToggle   := AOnEditorToggle;
  FOnDebugToggle    := AOnDebugToggle;
  FOnHistoryAction  := AOnHistoryAction;
  FOnStatusAction   := AOnStatusAction;
  FOnSettingsAction := AOnSettingsAction;

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

  FMenuStatus         := TMenuItem.Create(nil);
  FMenuStatus.Caption := ChangesCaption(AChangesShortcut);
  FMenuStatus.OnClick := MenuStatusClick;

  FMenuRoot.Add(FMenuEditor);
  FMenuRoot.Add(FMenuDebug);
  FMenuRoot.Add(Divisor);
  FMenuRoot.Add(FMenuStatus);

  Divisor         := TMenuItem.Create(nil);
  Divisor.Caption := '-';
  FMenuRoot.Add(Divisor);

  FMenuHistory         := TMenuItem.Create(nil);
  FMenuHistory.Caption := HistoryCaption(AHistShortcut);
  FMenuHistory.OnClick := MenuHistoryClick;
  FMenuRoot.Add(FMenuHistory);

  Divisor         := TMenuItem.Create(nil);
  Divisor.Caption := '-';
  FMenuRoot.Add(Divisor);

  FMenuSettings         := TMenuItem.Create(nil);
  FMenuSettings.Caption := 'Configurações (Settings)...';
  FMenuSettings.OnClick := MenuSettingsClick;
  FMenuRoot.Add(FMenuSettings);

  NTAServices.AddActionMenu('viewsMenu', nil, FMenuRoot, True, True);
end;

destructor TGitLensMenu.Destroy;
begin
  FMenuRoot.Free;
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

procedure TGitLensMenu.MenuStatusClick(Sender: TObject);
begin
  if Assigned(FOnStatusAction) then
    FOnStatusAction;
end;

procedure TGitLensMenu.MenuSettingsClick(Sender: TObject);
begin
  if Assigned(FOnSettingsAction) then
    FOnSettingsAction;
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

procedure TGitLensMenu.SyncShortcuts(const AHist, AChanges: string);
begin
  if Assigned(FMenuHistory) then
    FMenuHistory.Caption := HistoryCaption(AHist);
  if Assigned(FMenuStatus) then
    FMenuStatus.Caption := ChangesCaption(AChanges);
end;

{ ============================================================================
  Menu de contexto do editor (botão direito)

  As mesmas ações do menu View, no lugar onde elas fazem sentido: em cima da
  linha de código sobre a qual se quer perguntar.

  ----------------------------------------------------------------------------
  Por que isto é feito "na mão", achando o TPopupMenu do editor
  ----------------------------------------------------------------------------
  A ToolsAPI do 10.2 NÃO tem API para o menu de contexto do editor. Ela tem
  IOTAProjectManagerMenu (Project Manager) e MessageViewMenuShown (janela de
  mensagens) -- nada para o editor de código. Conferido em
  Studio\19.0\source\ToolsAPI\ToolsAPI.pas.

  O que existe é INTAEditWindow.Form: a janela do editor é um TCustomForm de
  verdade, e o menu de contexto é um TPopupMenu componente dela. Então achamos
  esse componente e penduramos o submenu nele.

  ----------------------------------------------------------------------------
  Tempo de vida: o cuidado que não pode faltar
  ----------------------------------------------------------------------------
  O item fica pendurado num objeto da IDE, e este pacote pode ser descarregado
  antes dela. Item sobrevivendo ao unload = ponteiro para código que não existe
  mais = Access Violation ao fechar o Delphi.

  Duas defesas, e as duas são necessárias:
    1. os itens nascem com Owner = Self, então morrem junto com este objeto;
    2. Notification() zera as referências se a IDE destruir o menu (ou os itens)
       primeiro -- e por isso pedimos FreeNotification ao TPopupMenu.

  ----------------------------------------------------------------------------
  Um item só, seguindo a janela ativa
  ----------------------------------------------------------------------------
  Quem tem mais de uma janela de editor aberta (raro) vê o submenu na que
  estiver ativa: ao ativar outra, ele se muda para lá. A alternativa -- um item
  por janela -- exigiria uma lista com notificação individual para caçar
  ponteiro morto, e o ganho não paga o risco.
  ============================================================================ }

constructor TGitLensEditWindowNotifier.Create(AOwner: TGitLensEditorMenu);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TGitLensEditWindowNotifier.Detach;
begin
  FOwner := nil;
end;

procedure TGitLensEditWindowNotifier.WindowShow(const EditWindow: INTAEditWindow;
  Show, LoadedFromDesktop: Boolean);
begin
  if Show and Assigned(FOwner) then
    FOwner.InstallInto(EditWindow);
end;

procedure TGitLensEditWindowNotifier.WindowActivated(const EditWindow: INTAEditWindow);
begin
  if Assigned(FOwner) then
    FOwner.InstallInto(EditWindow);
end;

procedure TGitLensEditWindowNotifier.WindowNotification(const EditWindow: INTAEditWindow;
  Operation: TOperation);
begin
  { A janela indo embora leva o TPopupMenu junto; quem zera a referência é o
    Notification do TGitLensEditorMenu, que é quem tem FreeNotification. }
end;

procedure TGitLensEditWindowNotifier.WindowCommand(const EditWindow: INTAEditWindow;
  Command, Param: Integer; var Handled: Boolean);
begin
end;

procedure TGitLensEditWindowNotifier.EditorViewActivated(const EditWindow: INTAEditWindow;
  const EditView: IOTAEditView);
begin
end;

procedure TGitLensEditWindowNotifier.EditorViewModified(const EditWindow: INTAEditWindow;
  const EditView: IOTAEditView);
begin
end;

procedure TGitLensEditWindowNotifier.DockFormVisibleChanged(const EditWindow: INTAEditWindow;
  DockForm: TDockableForm);
begin
end;

procedure TGitLensEditWindowNotifier.DockFormUpdated(const EditWindow: INTAEditWindow;
  DockForm: TDockableForm);
begin
end;

procedure TGitLensEditWindowNotifier.DockFormRefresh(const EditWindow: INTAEditWindow;
  DockForm: TDockableForm);
begin
end;

{ ------------------------------------------------------ TGitLensEditorMenu }

constructor TGitLensEditorMenu.Create(AOnHistoryAction, AOnStatusAction,
  AOnSettingsAction: TMenuActionEvent; AOnEditorToggle: TMenuToggleEvent;
  AEnabledEditor: Boolean; const AHistShortcut, AChangesShortcut: string);
var
  LEditorSvc: IOTAEditorServices;
  LNtaSvc   : INTAEditorServices;
begin
  inherited Create(nil);
  FOnHistoryAction  := AOnHistoryAction;
  FOnStatusAction   := AOnStatusAction;
  FOnSettingsAction := AOnSettingsAction;
  FOnEditorToggle   := AOnEditorToggle;
  FEnabledEditor    := AEnabledEditor;
  FHistShortcut     := AHistShortcut;
  FChangesShortcut  := AChangesShortcut;
  FNotifierIndex    := -1;

  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorSvc) then
  begin
    FNotifierObj   := TGitLensEditWindowNotifier.Create(Self);
    FNotifier      := FNotifierObj;
    FNotifierIndex := LEditorSvc.AddNotifier(FNotifier);
  end;

  { A janela do editor normalmente JÁ existe quando o pacote carrega (desktop
    restaurado). Sem esta chamada, o submenu só apareceria depois de trocar de
    janela pelo menos uma vez. }
  if Supports(BorlandIDEServices, INTAEditorServices, LNtaSvc) then
    InstallInto(LNtaSvc.TopEditWindow);
end;

destructor TGitLensEditorMenu.Destroy;
var
  LEditorSvc: IOTAEditorServices;
begin
  if (FNotifierIndex >= 0) and Supports(BorlandIDEServices, IOTAEditorServices, LEditorSvc) then
  begin
    try
      LEditorSvc.RemoveNotifier(FNotifierIndex);
    except
      { Fechamento da IDE: o serviço pode já ter sumido. Nunca propaga. }
    end;
    FNotifierIndex := -1;
  end;

  { Cinto E suspensório: se o RemoveNotifier acima falhou (ou se a IDE ainda
    segura a referência), o notificador continua vivo. Sem este Detach ele
    chamaria um objeto liberado no próximo clique numa janela de editor. }
  if Assigned(FNotifierObj) then
    FNotifierObj.Detach;
  FNotifierObj := nil;
  FNotifier    := nil;

  { Free (e não só nil): o item precisa se desprender do TPopupMenu da IDE
    ANTES de este pacote ser descarregado. Ver "Tempo de vida" no cabeçalho. }
  FreeAndNil(FRoot);
  FItemEditor  := nil;
  FInstalledIn := nil;

  inherited Destroy;
end;

procedure TGitLensEditorMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then
    Exit;

  { A IDE destruiu o menu (ou os nossos itens junto com ele) antes de nós.
    Zerar aqui é o que impede o destrutor de mexer em memória liberada. }
  if AComponent = FInstalledIn then
  begin
    FInstalledIn := nil;
    FRoot        := nil; // some junto com o menu que o continha
    FItemEditor  := nil;
  end
  else if AComponent = FRoot then
  begin
    FRoot       := nil;
    FItemEditor := nil;
  end
  else if AComponent = FItemEditor then
    FItemEditor := nil;
end;

{ O menu de contexto do editor é um componente da janela do editor. Procuramos
  pelo nome que a IDE usa; se um dia ele mudar, o primeiro TPopupMenu da janela
  é um palpite melhor do que desistir. }
function TGitLensEditorMenu.FindEditorPopup(AForm: TCustomForm): TPopupMenu;
var
  I    : Integer;
  LComp: TComponent;
begin
  Result := nil;
  if not Assigned(AForm) then
    Exit;

  for I := 0 to AForm.ComponentCount - 1 do
  begin
    LComp := AForm.Components[I];
    if not (LComp is TPopupMenu) then
      Continue;
    if SameText(LComp.Name, EDITOR_POPUP_NAME) then
      Exit(TPopupMenu(LComp));
    if Result = nil then
      Result := TPopupMenu(LComp); // guarda o primeiro como reserva
  end;
end;

procedure TGitLensEditorMenu.InstallInto(const AEditWindow: INTAEditWindow);
var
  LPopup: TPopupMenu;
begin
  if not Assigned(AEditWindow) then
    Exit;

  try
    LPopup := FindEditorPopup(AEditWindow.Form);
    if not Assigned(LPopup) then
      Exit;

    { Já está no lugar certo: nada a fazer. É o caso comum, porque este método
      roda a cada ativação de janela. }
    if (LPopup = FInstalledIn) and Assigned(FRoot) then
      Exit;

    { Mudou de janela: leva o submenu junto (ver "Um item só" no cabeçalho). }
    FreeAndNil(FRoot);
    FItemEditor := nil;
    if Assigned(FInstalledIn) then
      FInstalledIn.RemoveFreeNotification(Self);

    FInstalledIn := LPopup;
    FInstalledIn.FreeNotification(Self);

    BuildItems;
    LPopup.Items.Add(FRoot);
  except
    { Um menu de contexto que não aparece é um aborrecimento; uma exceção
      subindo para dentro do notifier da IDE é um problema. }
  end;
end;

procedure TGitLensEditorMenu.BuildItems;

  function NewItem(const ACaption: string; AOnClick: TNotifyEvent): TMenuItem;
  begin
    Result         := TMenuItem.Create(Self); // Owner = Self: morre junto
    Result.Caption := ACaption;
    Result.OnClick := AOnClick;
    FRoot.Add(Result);
  end;

  procedure Separator;
  var
    LItem: TMenuItem;
  begin
    LItem         := TMenuItem.Create(Self);
    LItem.Caption := '-';
    FRoot.Add(LItem);
  end;

begin
  FRoot         := TMenuItem.Create(Self);
  FRoot.Caption := 'GitLens4D';
  FRoot.Name    := ROOT_ITEM_NAME;

  NewItem(HistoryCaption(FHistShortcut), HistoryClick);
  NewItem(ChangesCaption(FChangesShortcut), StatusClick);
  Separator;
  FItemEditor         := NewItem('Blame ativo no editor', EditorToggleClick);
  FItemEditor.Checked := FEnabledEditor;
  Separator;
  NewItem('Configurações...', SettingsClick);
end;

procedure TGitLensEditorMenu.SyncShortcuts(const AHist, AChanges: string);
begin
  FHistShortcut    := AHist;
  FChangesShortcut := AChanges;
  { Só as legendas mudaram: reconstruir o submenu inteiro mexeria no TPopupMenu
    da IDE sem necessidade. }
  if Assigned(FRoot) and (FRoot.Count >= 2) then
  begin
    FRoot.Items[0].Caption := HistoryCaption(AHist);
    FRoot.Items[1].Caption := ChangesCaption(AChanges);
  end;
end;

procedure TGitLensEditorMenu.SyncEditorState(AEnabled: Boolean);
begin
  FEnabledEditor := AEnabled;
  if Assigned(FItemEditor) then
    FItemEditor.Checked := AEnabled;
end;

procedure TGitLensEditorMenu.HistoryClick(Sender: TObject);
begin
  if Assigned(FOnHistoryAction) then
    FOnHistoryAction;
end;

procedure TGitLensEditorMenu.StatusClick(Sender: TObject);
begin
  if Assigned(FOnStatusAction) then
    FOnStatusAction;
end;

procedure TGitLensEditorMenu.SettingsClick(Sender: TObject);
begin
  if Assigned(FOnSettingsAction) then
    FOnSettingsAction;
end;

procedure TGitLensEditorMenu.EditorToggleClick(Sender: TObject);
begin
  FEnabledEditor := not FEnabledEditor;
  if Assigned(FItemEditor) then
    FItemEditor.Checked := FEnabledEditor;
  if Assigned(FOnEditorToggle) then
    FOnEditorToggle(FEnabledEditor);
end;

end.
