unit GitLens4D.IDE.StatusDock;

{ ============================================================================
  GitLens4D - Gerenciador de Janela de Status (Dockable)
  Responsabilidade: Gerenciar o ciclo de vida da janela Git Changes no IDE.
  ============================================================================ }

interface

uses
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  ToolsAPI,
  DesignIntf,
  GitLens4D.Interfaces,
  GitLens4D.IDE.StatusView,
  System.IniFiles,
  Vcl.ComCtrls,
  Vcl.Menus,
  Vcl.ActnList,
  Vcl.ImgList;

type
  TStatusDockManager = class(TNotifierObject, INTACustomDockableForm)
  private
    FProvider : IGitStatusProvider;
    FRunner   : IGitRunner;
    FSettings : ISettingsRepository;
    FAIService: IAIService;
    function GetActiveProjectDir: string;
  public
    constructor Create(AProvider: IGitStatusProvider; ARunner: IGitRunner;
      ASettings: ISettingsRepository; AAIService: IAIService);
    destructor Destroy; override;

    { INTACustomDockableForm - EXACT ORDER MATTERS }
    function GetCaption: string;
    function GetIdentifier: string;
    function GetFormClass: TCustomFormClass;
    procedure FormCreated(AForm: TCustomForm);
    function GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    function GetMenuActionName: string;
    function GetMenuText: string;
    procedure LoadWindowState(Desktop: TCustomIniFile; const Section: string);
    procedure SaveWindowState(Desktop: TCustomIniFile; const Section: string; IsProject: Boolean);
    function GetEditWindow: INTAEditWindow;
    procedure CustomizeToolBar(ToolBar: TToolBar);
    procedure CustomizePopupMenu(PopupMenu: TPopupMenu);
    function GetMenuActionList: TCustomActionList;
    function GetMenuImageList: TCustomImageList;
    function GetToolbarActionList: TCustomActionList;
    function GetToolbarImageList: TCustomImageList;
    function GetEditState: TEditState;
    function EditAction(Action: TEditAction): Boolean;

    procedure DockFormDestroyed(Sender: TObject);
  end;

procedure RegisterStatusWindow(AProvider: IGitStatusProvider; ARunner: IGitRunner;
  ASettings: ISettingsRepository; AAIService: IAIService);
procedure ShowStatusWindow;

implementation

uses
  System.SysUtils;

const
  DOCK_ID = 'QSGitStatusWindow';

var
  InternalManager      : INTACustomDockableForm;
  GManager             : TStatusDockManager; { referência concreta, só p/ ter um TNotifyEvent válido }
  GDockForm            : TCustomForm;
  GDockFormOldOnDestroy: TNotifyEvent;

procedure RegisterStatusWindow(AProvider: IGitStatusProvider; ARunner: IGitRunner;
  ASettings: ISettingsRepository; AAIService: IAIService);
begin
  { Propositalmente NÃO chama NTAServices.RegisterDockableForm aqui.
    Esse registro faz a IDE tentar restaurar automaticamente o form a
    partir do estado salvo no desktop, ainda durante o carregamento do
    pacote (Register) - é nesse caminho, muito cedo no boot da IDE, que
    vêm ocorrendo os crashes (EAccessViolation / EExternalException).
    O ToolsAPI documenta CreateDockableForm como alternativa suportada
    para quem abre mão da restauração automática entre sessões:
    o form ainda funciona normalmente ao ser aberto pelo menu. }
  if (InternalManager = nil) and Assigned(BorlandIDEServices) then
  begin
    GManager        := TStatusDockManager.Create(AProvider, ARunner, ASettings, AAIService);
    InternalManager := GManager;
  end;
end;

procedure ShowStatusWindow;
var
  NTAServices: INTAServices;
begin
  if not Assigned(InternalManager) then
    Exit;
  if not Supports(BorlandIDEServices, INTAServices, NTAServices) then
    Exit;

  if not Assigned(GDockForm) then
  begin
    GDockForm := NTAServices.CreateDockableForm(InternalManager);
    if Assigned(GDockForm) and (GDockForm is TForm) and Assigned(GManager) then
    begin
      GDockFormOldOnDestroy      := TForm(GDockForm).OnDestroy;
      TForm(GDockForm).OnDestroy := GManager.DockFormDestroyed;
    end;
  end;

  if Assigned(GDockForm) then
  begin
    GDockForm.Show;
    if GDockForm.CanFocus then
      GDockForm.SetFocus;
  end;
end;

{ TStatusDockManager }

constructor TStatusDockManager.Create(AProvider: IGitStatusProvider; ARunner: IGitRunner;
  ASettings: ISettingsRepository; AAIService: IAIService);
begin
  inherited Create;
  FProvider  := AProvider;
  FRunner    := ARunner;
  FSettings  := ASettings;
  FAIService := AAIService;
end;

destructor TStatusDockManager.Destroy;
begin
  inherited Destroy;
end;

function TStatusDockManager.GetActiveProjectDir: string;
var
  ModSvc : IOTAModuleServices;
  Project: IOTAProject;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
  begin
    Project := ModSvc.GetActiveProject;
    if Project <> nil then
      Result := ExtractFilePath(Project.FileName);
  end;
end;

function TStatusDockManager.GetCaption: string;
begin
  Result := 'Git Changes';
end;

function TStatusDockManager.GetIdentifier: string;
begin
  Result := DOCK_ID;
end;

function TStatusDockManager.GetFormClass: TCustomFormClass;
begin
  Result := nil;
end;

procedure TStatusDockManager.FormCreated(AForm: TCustomForm);
begin
end;

function TStatusDockManager.GetFrameClass: TCustomFrameClass;
begin
  Result := TGitStatusView;
end;

procedure TStatusDockManager.FrameCreated(AFrame: TCustomFrame);
var
  LFrame: TGitStatusView;
begin
  { A IDE pode chamar isto muito cedo (restauração do desktop durante o
    carregamento do pacote), antes de haver projeto ativo ou dos serviços
    da IDE estarem totalmente prontos. Qualquer exceção aqui não pode
    escapar: isso derruba o registro do pacote (Register) inteiro. }
  try
    LFrame            := TGitStatusView(AFrame);
    LFrame.Align      := alClient;
    LFrame.Provider   := FProvider;
    LFrame.Runner     := FRunner;
    LFrame.Settings   := FSettings;
    LFrame.AIService  := FAIService;
    LFrame.ProjectDir := GetActiveProjectDir;

    if Assigned(LFrame.Runner) and (LFrame.ProjectDir <> '') then
    begin
      LFrame.RepoRoot := LFrame.Runner.GetRepoRoot(LFrame.ProjectDir);
      LFrame.RepoRoot := StringReplace(LFrame.RepoRoot, '/', '\', [rfReplaceAll]);
    end;

    LFrame.RefreshStatus;
    LFrame.RefreshBranches;
  except
    // Ignorado propositalmente: ver comentário acima.
  end;
end;

function TStatusDockManager.GetMenuActionName: string;
begin
  Result := 'View' + DOCK_ID;
end;

function TStatusDockManager.GetMenuText: string;
begin
  Result := GetCaption;
end;

procedure TStatusDockManager.LoadWindowState(Desktop: TCustomIniFile; const Section: string);
begin
end;

procedure TStatusDockManager.SaveWindowState(Desktop: TCustomIniFile; const Section: string; IsProject: Boolean);
begin
end;

function TStatusDockManager.GetEditWindow: INTAEditWindow;
begin
  Result := nil;
end;

procedure TStatusDockManager.CustomizeToolBar(ToolBar: TToolBar);
begin
end;

procedure TStatusDockManager.CustomizePopupMenu(PopupMenu: TPopupMenu);
begin
end;

function TStatusDockManager.GetMenuActionList: TCustomActionList;
begin
  Result := nil;
end;

function TStatusDockManager.GetMenuImageList: TCustomImageList;
begin
  Result := nil;
end;

function TStatusDockManager.GetToolbarActionList: TCustomActionList;
begin
  Result := nil;
end;

function TStatusDockManager.GetToolbarImageList: TCustomImageList;
begin
  Result := nil;
end;

function TStatusDockManager.GetEditState: TEditState;
begin
  Result := [];
end;

function TStatusDockManager.EditAction(Action: TEditAction): Boolean;
begin
  Result := False;
end;

procedure TStatusDockManager.DockFormDestroyed(Sender: TObject);
begin
  { O host é recriado a cada ShowStatusWindow (não há RegisterDockableForm
    para a IDE controlar instância única - ver comentário em
    RegisterStatusWindow). Sem isto, fechar e reabrir o painel colide com
    "A component named OTADockForm already exists", pois o form antigo
    nunca é esquecido. }
  if Assigned(GDockFormOldOnDestroy) then
    GDockFormOldOnDestroy(Sender);
  GDockForm := nil;
end;

initialization

finalization

InternalManager := nil;
GManager        := nil;

end.
