unit GitLens4D.IDE.CursorTracker;

{ ============================================================================
  GitLens4D - Rastreador de Posição do Cursor no Editor
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: usar um TTimer para monitorar se o cursor mudou
  de linha ou arquivo, e notificar o wizard apenas quando houver mudança.
  Não conhece Git, mensagens ou configurações.
  ============================================================================ }

interface

uses
  Vcl.ExtCtrls,
  Vcl.Forms,
  ToolsAPI;

type
  TCursorChangedEvent = procedure(const AFile: string; ALine: Integer) of object;
  TIsActiveQuery      = function: Boolean of object;

  TGitLensCursorTracker = class
  private
    FTimer          : TTimer;
    FLastLine       : Integer;
    FLastFile       : string;
    FOnCursorChanged: TCursorChangedEvent;
    FOnIsActive     : TIsActiveQuery;

    procedure OnTimerTick(Sender: TObject);
    function QueryCurrentCursor(out AFile: string; out ALine: Integer): Boolean;
  public
    constructor Create(AOnCursorChanged: TCursorChangedEvent;
      AOnIsActive: TIsActiveQuery);
    destructor Destroy; override;
    procedure Reset;
  end;

implementation

uses
  System.SysUtils;

{ TGitLensCursorTracker }

constructor TGitLensCursorTracker.Create(AOnCursorChanged: TCursorChangedEvent;
  AOnIsActive: TIsActiveQuery);
begin
  inherited Create;
  FLastLine        := -1;
  FLastFile        := '';
  FOnCursorChanged := AOnCursorChanged;
  FOnIsActive      := AOnIsActive;

  FTimer          := TTimer.Create(nil);
  FTimer.Interval := 500;
  FTimer.OnTimer  := OnTimerTick;
  FTimer.Enabled  := True;
end;

destructor TGitLensCursorTracker.Destroy;
begin
  FTimer.Free;
  inherited Destroy;
end;

procedure TGitLensCursorTracker.Reset;
begin
  FLastLine := -1;
  FLastFile := '';
end;

function TGitLensCursorTracker.QueryCurrentCursor(out AFile: string;
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
    // IDE pode estar em estado transicional durante carregamento
  end;
end;

procedure TGitLensCursorTracker.OnTimerTick(Sender: TObject);
var
  CurrentFile: string;
  CurrentLine: Integer;
begin
  if (Application = nil) or (Application.MainForm = nil) then
    Exit;

  try
    // Delega ao wizard a decisão de estar ativo ou não
    if Assigned(FOnIsActive) and not FOnIsActive then
      Exit;

    if QueryCurrentCursor(CurrentFile, CurrentLine) then
    begin
      if (CurrentFile <> FLastFile) or (CurrentLine <> FLastLine) then
      begin
        FLastFile := CurrentFile;
        FLastLine := CurrentLine;
        if Assigned(FOnCursorChanged) then
          FOnCursorChanged(FLastFile, FLastLine);
      end;
    end;
  except
    // Protege o timer de exceções silenciosas do IDE
  end;
end;

end.
