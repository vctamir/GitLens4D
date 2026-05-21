unit GitLens4D.IDE.StatusDock;

{ ============================================================================
  GitLens4D - Gerenciador de Janela de Status (Dockable)
  Princípio: Single Responsibility (SRP)

  Responsabilidade: Gerenciar o ciclo de vida da janela Git Changes no IDE.
  Implementa o suporte a docking nativo do IDE.
  ============================================================================ }

interface

uses
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, ToolsAPI,
  GitLens4D.Interfaces, GitLens4D.IDE.StatusView;

type
  TStatusDockManager = class(TNotifierObject)
  private
    FForm: TGitStatusView;
    FProvider: IGitStatusProvider;
    FRunner: IGitRunner;
    FSettings: ISettingsRepository;
    FAIService: IAIService;
    function GetActiveProjectDir: string;
  public
    constructor Create(AProvider: IGitStatusProvider; ARunner: IGitRunner; 
      ASettings: ISettingsRepository; AAIService: IAIService);
    destructor Destroy; override;
    procedure Show;
  end;

procedure RegisterStatusWindow(AProvider: IGitStatusProvider; ARunner: IGitRunner; 
  ASettings: ISettingsRepository; AAIService: IAIService);
procedure ShowStatusWindow;

implementation

uses
  System.SysUtils;

var
  InternalManager: TStatusDockManager;

procedure RegisterStatusWindow(AProvider: IGitStatusProvider; ARunner: IGitRunner; 
  ASettings: ISettingsRepository; AAIService: IAIService);
begin
  if InternalManager = nil then
    InternalManager := TStatusDockManager.Create(AProvider, ARunner, ASettings, AAIService);
end;

procedure ShowStatusWindow;
begin
  if InternalManager <> nil then
    InternalManager.Show;
end;

{ TStatusDockManager }

constructor TStatusDockManager.Create(AProvider: IGitStatusProvider; ARunner: IGitRunner; 
  ASettings: ISettingsRepository; AAIService: IAIService);
begin
  inherited Create;
  FProvider := AProvider;
  FRunner := ARunner;
  FSettings := ASettings;
  FAIService := AAIService;
end;

destructor TStatusDockManager.Destroy;
begin
  if FForm <> nil then
    FForm.Free;
  inherited Destroy;
end;

function TStatusDockManager.GetActiveProjectDir: string;
var
  ModSvc: IOTAModuleServices;
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

procedure TStatusDockManager.Show;
begin
  if FForm = nil then
  begin
    FForm := TGitStatusView.Create(nil, FProvider, FRunner, FSettings, FAIService, GetActiveProjectDir);
    FForm.FormStyle := fsStayOnTop;
  end;

  if not FForm.Visible then
    FForm.Show;
    
  FForm.BringToFront;
end;

initialization

finalization
  if InternalManager <> nil then
    InternalManager.Free;

end.
