unit GitLens4D.IDE.DiffView;

{ ============================================================================
  GitLens4D - Visualizador de Diferenças (Diff)
  Princípio: Single Responsibility (SRP)

  Responsabilidade: Exibir o Diff do arquivo com as cores clássicas do Git.

  A pintura é feita em ui\diff.html, dentro do TWebBrowser hospedado por
  TGitWebHost -- o mesmo host das outras telas do plugin. O TRichEdit anterior
  era o pior lugar possível para um diff: cada linha exigia um EM_SETCHARFORMAT
  na mão, o fundo colorido não cobria a linha inteira e não havia número de
  linha. Em HTML isso é CSS, e ainda sobra a numeração pelo arquivo novo.
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
  GitLens4D.IDE.WebHost,
  ToolsAPI;

type
  TGitDiffView = class(TForm)
  private
    FHost    : TGitWebHost;
    FFileName: string;
    FDiffText: string;
    procedure ApplyTheme;
    procedure HandleAction(AAction: TJSONObject);
    procedure HostDocumentReady(ASender: TObject);
    procedure PushDiff;
  public
    constructor Create(AOwner: TComponent; const AFileName, ADiffText: string); reintroduce;
  end;

procedure ShowDiff(const AFileName, ADiffText: string);

implementation

{$R *.dfm}

procedure ShowDiff(const AFileName, ADiffText: string);
var
  Frm: TGitDiffView;
begin
  Frm := TGitDiffView.Create(nil, AFileName, ADiffText);
  try
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

{ TGitDiffView }

constructor TGitDiffView.Create(AOwner: TComponent; const AFileName, ADiffText: string);
begin
  inherited Create(AOwner);
  FFileName := AFileName;
  FDiffText := ADiffText;

  Caption := 'Diff: ' + AFileName;
  ApplyTheme;

  { O diff só é empurrado quando o documento avisa que está pronto -- a
    navegação é assíncrona e neste ponto não há DOM nenhum. }
  FHost                 := TGitWebHost.Create(Self, Self, 'diff.html');
  FHost.OnAction        := HandleAction;
  FHost.OnDocumentReady := HostDocumentReady;
end;

procedure TGitDiffView.ApplyTheme;
var
  ThemingSvc: IOTAIDEThemingServices;
begin
  { Continua valendo para a moldura da janela (título, borda); o miolo é a
    página. }
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingSvc) then
    if ThemingSvc.IDEThemingEnabled then
      ThemingSvc.ApplyTheme(Self);
end;

procedure TGitDiffView.HostDocumentReady(ASender: TObject);
begin
  PushDiff;
end;

procedure TGitDiffView.PushDiff;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('file', FFileName);
    LJson.AddPair('diff', FDiffText);
    FHost.CallJs('gitDiff', LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TGitDiffView.HandleAction(AAction: TJSONObject);
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
  begin
    { Botão "Copiar": o JS decide o que vai (seleção, ou o diff inteiro quando
      não há seleção) e deposita em #copyBuffer. }
    FHost.CallJs('gitCopySelection', '{}');
  end;
end;

end.
