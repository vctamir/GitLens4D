unit GitLens4D.IDE.SettingsView;

{ ============================================================================
  GitLens4D - Configurações (geral e IA)

  Desenhada em ui\settings.html, no mesmo host das outras telas. As duas abas
  do antigo TPageControl viraram duas seções da página; os TEdit/TComboBox
  viraram campos HTML com os MESMOS valores possíveis de antes (Local/openAI,
  pt-BR/en-US, Markdown/Texto Puro) -- o que é gravado no repositório de
  configurações não mudou nada.

  Não há estado nesta unit: o Pascal escreve os valores no documento ao abrir e
  lê os mesmos ids de volta ao salvar. Um lugar só onde a informação mora.
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
  TGitSettingsView = class(TForm)
  private
    FHost     : TGitWebHost;
    FSettings : ISettingsRepository;
    FStartOnAI: Boolean;
    procedure ApplyTheme;
    procedure HandleAction(AAction: TJSONObject);
    procedure HostDocumentReady(ASender: TObject);
    procedure PushConfigs;
    procedure SaveConfigs;
    function Read(const AElementId, ADefault: string): string;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent; ASettings: ISettingsRepository;
      AStartOnAI: Boolean); reintroduce;
  end;

procedure ShowSettings(ASettings: ISettingsRepository; ADefaultAI: Boolean = False);

implementation

{$R *.dfm}

const
  ID_SHORTCUT_HIST    = 'shortcutHist';
  ID_SHORTCUT_CHANGES = 'shortcutChanges';
  ID_COMMIT_TAG       = 'commitTag';
  ID_AI_TYPE          = 'aiType';
  ID_ENDPOINT         = 'endpoint';
  ID_API_KEY          = 'apiKey';
  ID_MODEL            = 'model';
  ID_LANG             = 'lang';
  ID_FORMAT           = 'format';
  ID_TEMP             = 'temp';
  ID_MAX_TOKENS       = 'maxTokens';

  { Os mesmos defaults que o código VCL usava ao ler ItemIndex = -1. }
  DEFAULT_AI_TYPE    = 'Local';
  DEFAULT_LANG       = 'pt-BR';
  DEFAULT_FORMAT     = 'Markdown';
  DEFAULT_TEMP       = 0.7;
  DEFAULT_MAX_TOKENS = 2048;

procedure ShowSettings(ASettings: ISettingsRepository; ADefaultAI: Boolean = False);
var
  LForm: TGitSettingsView;
begin
  LForm := TGitSettingsView.Create(nil, ASettings, ADefaultAI);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

{ TGitSettingsView }

constructor TGitSettingsView.Create(AOwner: TComponent; ASettings: ISettingsRepository;
  AStartOnAI: Boolean);
begin
  inherited Create(AOwner);
  FSettings  := ASettings;
  FStartOnAI := AStartOnAI;
  PopupMode  := pmAuto;

  FHost                 := TGitWebHost.Create(Self, Self, 'settings.html');
  FHost.OnAction        := HandleAction;
  FHost.OnDocumentReady := HostDocumentReady;
end;

procedure TGitSettingsView.DoShow;
begin
  inherited;
  ApplyTheme;
end;

procedure TGitSettingsView.ApplyTheme;
var
  LThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingSvc) then
    if LThemingSvc.IDEThemingEnabled then
      LThemingSvc.ApplyTheme(Self);
end;

procedure TGitSettingsView.HostDocumentReady(ASender: TObject);
begin
  PushConfigs;
end;

procedure TGitSettingsView.PushConfigs;
var
  LHist, LChanges, LTag                         : string;
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
  LJson                                         : TJSONObject;
begin
  if not Assigned(FSettings) then
    Exit;

  FSettings.LoadGeneralConfig(LHist, LChanges, LTag);
  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('shortcutHist', LHist);
    LJson.AddPair('shortcutChanges', LChanges);
    LJson.AddPair('commitTag', LTag);
    LJson.AddPair('aiType', LType);
    LJson.AddPair('endpoint', LEndpoint);
    LJson.AddPair('apiKey', LKey);
    LJson.AddPair('model', LModel);
    LJson.AddPair('lang', LLang);
    LJson.AddPair('format', LFormat);
    LJson.AddPair('temp', FloatToStr(LTemp));
    LJson.AddPair('maxTokens', IntToStr(LMaxTokens));
    { Abrir direto na aba de IA é o caminho de quem clicou no botão "IA" do
      painel de commit -- ele veio configurar a IA, e não os atalhos. }
    if FStartOnAI then
      LJson.AddPair('tab', 'ai')
    else
      LJson.AddPair('tab', 'general');
    FHost.CallJs('gitSettings', LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

{ Lê um campo do documento, caindo no default quando o elemento sumiu ou veio
  vazio -- mesma proteção que o ItemIndex = -1 dava nos combos. }
function TGitSettingsView.Read(const AElementId, ADefault: string): string;
begin
  if not FHost.TryReadValue(AElementId, Result) or (Result = '') then
    Result := ADefault;
end;

procedure TGitSettingsView.SaveConfigs;
var
  LTemp: Double;
begin
  if not Assigned(FSettings) then
    Exit;

  FSettings.SaveGeneralConfig(
    Read(ID_SHORTCUT_HIST, ''),
    Read(ID_SHORTCUT_CHANGES, ''),
    Read(ID_COMMIT_TAG, ''));

  { StrToFloatDef com o separador da máquina: o campo é digitado pelo usuário e
    tanto 0.7 quanto 0,7 aparecem na prática. }
  LTemp := StrToFloatDef(StringReplace(Read(ID_TEMP, ''), '.', FormatSettings.DecimalSeparator,
    [rfReplaceAll]), DEFAULT_TEMP);

  FSettings.SaveAIConfig(
    Read(ID_AI_TYPE, DEFAULT_AI_TYPE),
    Read(ID_ENDPOINT, ''),
    Read(ID_API_KEY, ''),
    Read(ID_MODEL, ''),
    Read(ID_LANG, DEFAULT_LANG),
    Read(ID_FORMAT, DEFAULT_FORMAT),
    LTemp,
    StrToIntDef(Read(ID_MAX_TOKENS, ''), DEFAULT_MAX_TOKENS));
end;

procedure TGitSettingsView.HandleAction(AAction: TJSONObject);
var
  LType : string;
  LValue: TJSONValue;
begin
  LType  := '';
  LValue := AAction.GetValue('type');
  if Assigned(LValue) then
    LType := LValue.Value;

  if LType = 'save' then
  begin
    SaveConfigs;
    ShowMessage('Configurações salvas! Reinicie o Delphi para aplicar os novos atalhos de teclado.');
    ModalResult := mrOk;
  end
  else if LType = 'cancel' then
    ModalResult := mrCancel;
end;

end.
