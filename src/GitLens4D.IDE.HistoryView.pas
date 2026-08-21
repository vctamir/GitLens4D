unit GitLens4D.IDE.HistoryView;

{ ============================================================================
  GitLens4D - Evolução da linha (histórico)

  Master-detail: os commits que tocaram a linha em cima, o patch do commit
  selecionado embaixo. Desenhado em ui\history.html, no mesmo host das outras
  telas (TGitWebHost), e usando o MESMO renderizador de diff da tela de Diff
  (ui\diff-render.js) -- duas pinturas separadas divergiriam no primeiro ajuste
  de cor.

  Todo o histórico (inclusive os patches) é empurrado de uma vez: são poucos
  commits por linha, e assim trocar de commit na lista não custa ida e volta
  pelo pipe.
  ============================================================================ }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.JSON,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  GitLens4D.Interfaces,
  GitLens4D.IDE.WebHost,
  ToolsAPI;

type
  TGitHistoryView = class(TForm)
  private
    FHost    : TGitWebHost;
    FHistory : TGitHistoryArray;
    FWhere   : string;
    procedure ApplyTheme;
    procedure HandleAction(AAction: TJSONObject);
    procedure HostDocumentReady(ASender: TObject);
    procedure PushHistory;
  public
    constructor Create(AOwner: TComponent; const AFileName: string; ALine: Integer;
      AHistory: TGitHistoryArray); reintroduce;
  end;

procedure ShowHistoryWindow(const AFileName: string; ALine: Integer; AHistory: TGitHistoryArray);

implementation

{$R *.dfm}

procedure ShowHistoryWindow(const AFileName: string; ALine: Integer; AHistory: TGitHistoryArray);
var
  LForm: TGitHistoryView;
begin
  LForm := TGitHistoryView.Create(nil, AFileName, ALine, AHistory);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

{ TGitHistoryView }

constructor TGitHistoryView.Create(AOwner: TComponent; const AFileName: string; ALine: Integer;
  AHistory: TGitHistoryArray);
begin
  inherited Create(AOwner);
  FHistory := AHistory;
  FWhere   := Format('%s:%d', [ExtractFileName(AFileName), ALine]);
  Caption  := Format('Line Evolution: %s (Line %d)', [ExtractFileName(AFileName), ALine]);
  ApplyTheme;

  FHost                 := TGitWebHost.Create(Self, Self, 'history.html');
  FHost.OnAction        := HandleAction;
  FHost.OnDocumentReady := HostDocumentReady;
end;

procedure TGitHistoryView.ApplyTheme;
var
  LThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingSvc) then
    if LThemingSvc.IDEThemingEnabled then
      LThemingSvc.ApplyTheme(Self);
end;

procedure TGitHistoryView.HostDocumentReady(ASender: TObject);
begin
  PushHistory;
end;

procedure TGitHistoryView.PushHistory;
var
  LRoot   : TJSONObject;
  LCommits: TJSONArray;
  LItem   : TJSONObject;
  I       : Integer;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('where', FWhere);

    LCommits := TJSONArray.Create;
    for I := 0 to High(FHistory) do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('hash', FHistory[I].Hash);
      LItem.AddPair('author', FHistory[I].Author);
      LItem.AddPair('date', FHistory[I].Date);
      LItem.AddPair('message', FHistory[I].Message);
      LItem.AddPair('patch', FHistory[I].Patch);
      LCommits.AddElement(LItem);
    end;
    LRoot.AddPair('commits', LCommits);

    FHost.CallJs('gitHistory', LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

procedure TGitHistoryView.HandleAction(AAction: TJSONObject);
var
  LType : string;
  LValue: TJSONValue;
begin
  LType  := '';
  LValue := AAction.GetValue('type');
  if Assigned(LValue) then
    LType := LValue.Value;

  if LType = 'close' then
    Close
  else if LType = 'copy' then
    FHost.CallJs('gitCopySelection', '{}');
end;

end.
