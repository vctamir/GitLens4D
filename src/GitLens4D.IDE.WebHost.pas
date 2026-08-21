unit GitLens4D.IDE.WebHost;

{ ============================================================================
  GitLens4D - Host de painel HTML dentro da IDE

  Hospeda um TWebBrowser para que uma view do plugin possa ser escrita em
  HTML/CSS em vez de controles VCL. E so a INFRAESTRUTURA: quem decide o que
  desenhar e a view (ver GitLens4D.IDE.StatusView).

  Portado do painel do agente Claude (E:\Tamir\agenteDelphi,
  plugin\src\ClaudeDelphi.Panel.pas), onde cada um dos cuidados abaixo foi
  descoberto quebrando a IDE de verdade. Nao remova nenhum deles sem ler o
  comentario que o acompanha.

  ----------------------------------------------------------------------------
  Os cinco cuidados que fazem isto funcionar dentro do bds.exe
  ----------------------------------------------------------------------------
  1. FEATURE_BROWSER_EMULATION: sem a chave de registro, o controle roda em
     modo IE7 e o layout moderno simplesmente nao renderiza.
  2. Silent = True + window.onerror: qualquer erro de script viraria um
     MessageBox MODAL na MAIN THREAD da IDE -- a mesma que compila. A IDE
     congela esperando um clique que o usuario nem ve.
  3. Ponte JS->Pascal por URL sentinela: window.external/IDocHostUIHandler nao
     estao disponiveis aqui; a navegacao cancelada no BeforeNavigate2 e o
     canal que sobra. Texto longo NAO vai na URL (o Trident trunca sem avisar)
     -- vai pelo DOM, via TryReadValue.
  4. Vigia do documento: a IDE RECRIA a janela dos forms dockados (troca de
     desktop, redock, restaurar layout). Recriar a janela de um TOleControl
     destroi o controle e o browser renasce vazio, sem disparar
     DocumentComplete. Sem o vigia o painel fica em branco para sempre.
  5. CM_DIALOGCHAR: sem interceptar, letras que casam com acelerador de algum
     controle da IDE ('a', 'v', ...) NAO chegam ao campo de texto HTML.
  6. Ctrl+C/V/X/A: a IDE captura esses atalhos (menu Edit) antes de a mensagem
     chegar a uma janela dockada. Quem executa a acao, entao, e o host: avisa o
     documento por CallJs e, no caso da copia, escreve na area de transferencia
     por aqui -- as APIs de clipboard do JS no Trident hospedado ou nao
     funcionam ou abrem dialogo de permissao, e dialogo modal aqui trava a IDE.
  ============================================================================ }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.SysUtils,
  System.JSON,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.AppEvnts,
  SHDocVw;

type
  { Uma acao vinda do JS, ja parseada. O host continua dono do objeto: quem
    trata apenas LE, e nao libera nem guarda a referencia. }
  TWebHostActionEvent = procedure(AAction: TJSONObject) of object;

  TGitWebHost = class(TPanel)
  strict private
    FBrowser: TWebBrowser;
    FHtmlName: string;
    FTempFile: string;
    FDocumentReady: Boolean;
    FSilenced: Boolean;
    FWatchTimer: TTimer;
    FLastReloadTick: UInt64;
    FDeadTicks: Integer;
    FOnAction: TWebHostActionEvent;
    FOnDocumentReady: TNotifyEvent;
    FAppEvents: TApplicationEvents;
    procedure BrowserBeforeNavigate2(ASender: TObject; const pDisp: IDispatch;
      const URL, Flags, TargetFrameName, PostData, Headers: OleVariant;
      var Cancel: WordBool);
    procedure BrowserDocumentComplete(ASender: TObject; const pDisp: IDispatch;
      const URL: OleVariant);
    procedure WatchTimerTick(ASender: TObject);
    procedure DispatchAction(const AJsonText: string);
    procedure HandleAppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure CopyBufferToClipboard;
    procedure MarkReady;
    function DocumentAlive: Boolean;
    procedure NavigateToHtml;
  protected
    { Ver o cuidado 5 no cabecalho. }
    procedure CMDialogChar(var Message: TCMDialogChar); message CM_DIALOGCHAR;
  public
    { AHtmlName e o nome do arquivo dentro da pasta ui\ ao lado do pacote --
      'status.html', por exemplo. }
    constructor Create(AOwner: TComponent; AParent: TWinControl;
      const AHtmlName: string); reintroduce;
    destructor Destroy; override;

    { Chama AFunctionName(json) no documento. No-op silencioso se o documento
      nao for (mais) o nosso -- o vigia recarrega logo em seguida. }
    procedure CallJs(const AFunctionName, AJsonText: string);

    { Le o value de um <input>/<textarea>/<select> pelo id. E o caminho para
      texto longo, que nao cabe na URL sentinela. }
    function TryReadValue(const AElementId: string; out AValue: string): Boolean;

    property DocumentReady: Boolean read FDocumentReady;
    property OnAction: TWebHostActionEvent read FOnAction write FOnAction;
    { Dispara quando o documento fica pronto -- e quando a view deve empurrar
      o estado inicial. Pode disparar mais de uma vez (recarga do vigia). }
    property OnDocumentReady: TNotifyEvent read FOnDocumentReady write FOnDocumentReady;
  end;

{ Log de diagnostico do painel. Existe pelo mesmo motivo do log do agente: o
  browser engole falha em silencio, e sem isto nao sobra nenhuma pista.
  %LOCALAPPDATA%\GitLens4D\panel-diag.log }
procedure WebHostLog(const AText: string);
procedure WebHostLogFmt(const AMask: string; const AArgs: array of const);

implementation

uses
  System.IOUtils,
  System.StrUtils,
  System.Variants, // VarToStr: a URL chega ao BeforeNavigate2 como OleVariant
  System.NetEncoding,
  Vcl.Clipbrd,
  System.Win.Registry,
  MSHTML;

const
  { Prefixo do arquivo temporario. Tambem e o que DocumentAlive procura na
    LocationURL para saber se o documento carregado ainda e o nosso. }
  TEMP_HTML_PREFIX = 'gitlens4d-panel-';

  { Esquema da URL sentinela. Nao esta registrado no Windows de proposito: a
    navegacao e SEMPRE cancelada, o "endereco" e so o envelope da mensagem. }
  BRIDGE_URL_SCHEME = 'gitlens4d://';

  FEATURE_CONTROL_KEY =
    'Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION';
  IE11_EDGE_EMULATION = 11001;

  WATCH_INTERVAL_MS = 3000;
  { Carencia entre recargas: sem ela um documento que nao carrega vira um laco
    de recarga a cada 3 s. }
  RELOAD_COOLDOWN_MS = 10000;
  { Ticks seguidos "morto" antes de recarregar -- um tick isolado acontece no
    meio da propria navegacao. }
  DEAD_TICKS_BEFORE_RELOAD = 2;

  { Bit 29 do KeyData: 1 quando Alt estava pressionado (lParam de WM_KEYDOWN). }
  ALT_DOWN_KEYDATA = $20000000;

var
  GHtmlSeq: Integer = 0;
  GDialogCharLogged: Boolean = False;

{ ------------------------------------------------------------------- log --- }

function LogPath: string;
begin
  Result := TPath.Combine(
    TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'GitLens4D'),
    'panel-diag.log');
end;

procedure WebHostLog(const AText: string);
var
  LDir: string;
begin
  try
    LDir := TPath.GetDirectoryName(LogPath);
    if not TDirectory.Exists(LDir) then
      TDirectory.CreateDirectory(LDir);
    TFile.AppendAllText(LogPath,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + AText + sLineBreak,
      TEncoding.UTF8);
  except
    { Log que derruba a IDE seria pior que log nenhum. }
  end;
end;

procedure WebHostLogFmt(const AMask: string; const AArgs: array of const);
begin
  try
    WebHostLog(Format(AMask, AArgs));
  except
  end;
end;

{ --------------------------------------------------------------- emulacao --- }

{ Le o valor atual e so escreve se for diferente. Nunca lanca: sem a chave o
  painel fica feio (modo IE7), o que e ruim mas nao fatal. }
procedure EnsureBrowserEmulation;
var
  LReg: TRegistry;
  LExeName: string;
  LCurrent: Integer;
  LHasCurrent: Boolean;
begin
  try
    LExeName := ExtractFileName(GetModuleName(0)); // processo hospedeiro = bds.exe
    if LExeName = '' then
      LExeName := 'bds.exe';

    LReg := TRegistry.Create(KEY_READ or KEY_WRITE);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      if LReg.OpenKey(FEATURE_CONTROL_KEY, True) then
      begin
        LHasCurrent := False;
        LCurrent := 0;
        if LReg.ValueExists(LExeName) then
        begin
          try
            LCurrent := LReg.ReadInteger(LExeName);
            LHasCurrent := True;
          except
            LHasCurrent := False;
          end;
        end;
        if (not LHasCurrent) or (LCurrent <> IE11_EDGE_EMULATION) then
        begin
          LReg.WriteInteger(LExeName, IE11_EDGE_EMULATION);
          WebHostLogFmt('EnsureBrowserEmulation: %s = %d', [LExeName, IE11_EDGE_EMULATION]);
        end;
        LReg.CloseKey;
      end;
    finally
      LReg.Free;
    end;
  except
    on E: Exception do
      WebHostLogFmt('EnsureBrowserEmulation falhou: %s: %s', [E.ClassName, E.Message]);
  end;
end;

{ ------------------------------------------------------------ carga do html --- }

{ Procura ui\<nome> subindo a partir da pasta do .bpl. Cobre tanto o layout do
  repositorio (bin\ ao lado de ui\) quanto uma instalacao em outra pasta. }
function ResolveHtmlSource(const AHtmlName: string): string;
var
  LDir, LPrevDir, LCandidate: string;
  I: Integer;
begin
  Result := '';
  LDir := TPath.GetDirectoryName(GetModuleName(HInstance));
  for I := 0 to 8 do
  begin
    if LDir = '' then
      Break;
    LCandidate := TPath.Combine(TPath.Combine(LDir, 'ui'), AHtmlName);
    if TFile.Exists(LCandidate) then
      Exit(LCandidate);
    LPrevDir := LDir;
    LDir := TPath.GetDirectoryName(LDir);
    if LDir = LPrevDir then
      Break; // chegou na raiz
  end;
end;

{ HTML minimo, usado so quando ui\<nome> nao pode ser lido. Nunca deixa o
  painel simplesmente quebrar: explica o que falta. }
function FallbackHtml(const AHtmlName: string): string;
begin
  Result :=
    '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta http-equiv="X-UA-Compatible" content="IE=edge"><title>GitLens4D</title>' +
    '<style>body{background:#1e1e1e;color:#cccccc;font-family:"Segoe UI",Tahoma,sans-serif;' +
    'padding:16px;font-size:13px;}code{background:#2d2d30;padding:2px 5px;border-radius:3px;}' +
    '</style></head><body><p><strong>ui\' + AHtmlName + '</strong> nao foi encontrado ' +
    'ao lado do pacote.</p><p>Verifique se a pasta <code>ui\</code> foi copiada junto ' +
    'com o <code>.bpl</code>.</p></body></html>';
end;

{ Troca o marcador /*GITLENS_BASE_CSS*/ pelo conteudo de uiase.css.

  Injecao, e nao <link href="base.css">, porque o HTML e gravado num arquivo
  temporario em %TEMP%: qualquer caminho relativo dentro dele apontaria para a
  pasta errada. Com a injecao, as quatro telas do plugin compartilham UMA folha
  de estilo de verdade -- mexer nela muda todas, que e o ponto de "mesmo
  padrao".

  Sem o arquivo, ou sem o marcador, a pagina segue como esta: cada uma tem o
  minimo proprio para nao ficar ilegivel. }
function InjectShared(const AHtml, AMarker, AFileName: string): string;
var
  LPath, LContent: string;
begin
  Result := AHtml;
  if Pos(AMarker, Result) = 0 then
    Exit;

  LPath := ResolveHtmlSource(AFileName);
  if LPath = '' then
  begin
    WebHostLogFmt('InjectShared: ui\%s nao encontrado; a pagina segue sem ele', [AFileName]);
    Exit;
  end;

  try
    LContent := TFile.ReadAllText(LPath, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      WebHostLogFmt('InjectShared: falha lendo %s: %s', [LPath, E.Message]);
      Exit;
    end;
  end;

  Result := StringReplace(Result, AMarker, LContent, [rfReplaceAll]);
end;

function InjectBaseCss(const AHtml: string): string;
begin
  { base.css: a paleta e os controles, compartilhados pelas quatro telas.
    diff-render.js: a pintura de diff, usada pela tela de Diff e pela de
    Historico -- duas copias divergiriam no primeiro ajuste de cor. }
  Result := InjectShared(AHtml, '/*GITLENS_BASE_CSS*/', 'base.css');
  Result := InjectShared(Result, '/*GITLENS_DIFF_JS*/', 'diff-render.js');
end;

{ ------------------------------------------------------------- TGitWebHost --- }

constructor TGitWebHost.Create(AOwner: TComponent; AParent: TWinControl;
  const AHtmlName: string);
begin
  inherited Create(AOwner);
  FHtmlName := AHtmlName;
  FDocumentReady := False;
  FSilenced := False;

  EnsureBrowserEmulation;

  BevelOuter := bvNone;
  Caption := '';
  Parent := AParent;
  Align := alClient;

  FBrowser := TWebBrowser.Create(Self);
  { O cast para TControl NAO e cosmetico: TWebBrowser declara
    "property Parent: IDispatch index 201" (SHDocVw.pas) -- a propriedade de
    automacao window.parent do IE, somente leitura, que SOMBREIA TControl.Parent.
    Sem o cast: E2129 (nao e possivel atribuir a uma propriedade read-only). }
  TControl(FBrowser).Parent := Self;
  FBrowser.Align := alClient;
  FBrowser.OnBeforeNavigate2 := BrowserBeforeNavigate2;
  FBrowser.OnDocumentComplete := BrowserDocumentComplete;

  FWatchTimer := TTimer.Create(Self);
  FWatchTimer.Interval := WATCH_INTERVAL_MS;
  FWatchTimer.OnTimer := WatchTimerTick;
  FWatchTimer.Enabled := True;

  { Ver o cuidado 6 no cabecalho: sem isto Ctrl+C/V/X/A nao chegam ao
    documento, porque a IDE os captura antes (sao atalhos do menu Edit). }
  FAppEvents := TApplicationEvents.Create(Self);
  FAppEvents.OnMessage := HandleAppMessage;

  NavigateToHtml;
end;

destructor TGitWebHost.Destroy;
begin
  if Assigned(FWatchTimer) then
    FWatchTimer.Enabled := False;
  { O arquivo temporario e nosso; sumir com ele evita lixo em %TEMP% a cada
    abertura do painel. Best-effort: o browser pode ainda estar segurando. }
  try
    if (FTempFile <> '') and TFile.Exists(FTempFile) then
      TFile.Delete(FTempFile);
  except
  end;
  inherited Destroy;
end;

procedure TGitWebHost.NavigateToHtml;
var
  LSource, LHtml, LTemp, LUrl: string;
begin
  LSource := ResolveHtmlSource(FHtmlName);
  if LSource <> '' then
  begin
    try
      LHtml := InjectBaseCss(TFile.ReadAllText(LSource, TEncoding.UTF8));
    except
      on E: Exception do
      begin
        WebHostLogFmt('NavigateToHtml: falha lendo %s: %s', [LSource, E.Message]);
        LHtml := FallbackHtml(FHtmlName);
      end;
    end;
  end
  else
  begin
    WebHostLogFmt('NavigateToHtml: ui\%s nao encontrado; usando fallback', [FHtmlName]);
    LHtml := FallbackHtml(FHtmlName);
  end;

  { Arquivo por instancia E por navegacao: duas IDEs abertas, ou o painel
    recarregado pelo vigia, nunca disputam o mesmo arquivo. }
  Inc(GHtmlSeq);
  LTemp := TPath.Combine(TPath.GetTempPath,
    Format('%s%d-%d.html', [TEMP_HTML_PREFIX, GetCurrentProcessId, GHtmlSeq]));
  try
    TFile.WriteAllText(LTemp, LHtml, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      WebHostLogFmt('NavigateToHtml: falha gravando %s: %s', [LTemp, E.Message]);
      Exit;
    end;
  end;

  { Some com o anterior so depois que o novo existe. }
  try
    if (FTempFile <> '') and (FTempFile <> LTemp) and TFile.Exists(FTempFile) then
      TFile.Delete(FTempFile);
  except
  end;
  FTempFile := LTemp;

  FDocumentReady := False;
  LUrl := 'file:///' + StringReplace(LTemp, '\', '/', [rfReplaceAll]);
  WebHostLogFmt('NavigateToHtml: %s (%d bytes)', [LTemp, Length(LHtml)]);
  try
    FBrowser.Navigate(LUrl);
  except
    on E: Exception do
      WebHostLogFmt('NavigateToHtml: Navigate falhou: %s: %s', [E.ClassName, E.Message]);
  end;
end;

procedure TGitWebHost.MarkReady;
begin
  FDeadTicks := 0;
  FDocumentReady := True;
  if Assigned(FOnDocumentReady) then
  begin
    try
      FOnDocumentReady(Self);
    except
      on E: Exception do
        WebHostLogFmt('OnDocumentReady: %s: %s', [E.ClassName, E.Message]);
    end;
  end;
end;

procedure TGitWebHost.BrowserDocumentComplete(ASender: TObject; const pDisp: IDispatch;
  const URL: OleVariant);
begin
  { Dois caminhos levam a "pronto": este evento e a acao 'ready' que o proprio
    JS manda ao terminar de montar o DOM. Os dois sao idempotentes de
    proposito -- se um falhar, o outro cobre. }
  MarkReady;
end;

procedure TGitWebHost.BrowserBeforeNavigate2(ASender: TObject; const pDisp: IDispatch;
  const URL, Flags, TargetFrameName, PostData, Headers: OleVariant; var Cancel: WordBool);
var
  LUrl, LDataEnc: string;
  LMarkPos: Integer;
begin
  { Silent AQUI, e nao no construtor: a propriedade so existe depois que o
    controle OLE nasce, e forcar isso cedo (lendo Handle antes de a IDE
    encaixar o frame) faz o docking recriar a janela e ENGOLIR a navegacao --
    painel em branco, DocumentComplete nunca dispara. Quando este evento roda,
    o controle esta vivo por definicao: e ele quem disparou. }
  if not FSilenced then
  begin
    FSilenced := True; // uma tentativa so, deu ou nao deu
    try
      FBrowser.Silent := True;
    except
      on E: Exception do
        WebHostLogFmt('Silent falhou: %s: %s', [E.ClassName, E.Message]);
    end;
  end;

  try
    LUrl := VarToStr(URL);
    if not StartsText(BRIDGE_URL_SCHEME, LUrl) then
      Exit; // navegacao de verdade (a nossa propria carga do arquivo temp)

    { Cancela SEMPRE, mesmo se o parse abaixo falhar: o esquema nao existe no
      Windows e deixar o IE tentar resolver abriria dialogo de erro. }
    Cancel := True;

    LMarkPos := Pos('data=', LUrl);
    if LMarkPos = 0 then
      Exit;
    LDataEnc := Copy(LUrl, LMarkPos + Length('data='), MaxInt);
    DispatchAction(TNetEncoding.URL.Decode(LDataEnc));
  except
    on E: Exception do
      { BeforeNavigate2 roda de dentro do motor do IE; excecao escapando daqui
        pode deixar o controle inconsistente. Nunca deixa passar. }
      WebHostLogFmt('BeforeNavigate2: %s: %s', [E.ClassName, E.Message]);
  end;
end;

procedure TGitWebHost.DispatchAction(const AJsonText: string);
var
  LValue: TJSONValue;
  LObj: TJSONObject;
  LType: string;
begin
  LValue := TJSONObject.ParseJSONValue(AJsonText);
  if LValue = nil then
  begin
    WebHostLogFmt('DispatchAction: JSON invalido: %s', [Copy(AJsonText, 1, 200)]);
    Exit;
  end;
  try
    if not (LValue is TJSONObject) then
      Exit;
    LObj := TJSONObject(LValue);

    LType := '';
    if LObj.GetValue('type') <> nil then
      LType := LObj.GetValue('type').Value;

    { 'ready' e do host, nao da view: e o aviso de que o DOM esta montado e o
      estado inicial pode ser empurrado. }
    if LType = 'ready' then
    begin
      MarkReady;
      Exit;
    end;

    { 'clipboard.copy' tambem: o id do elemento e uma convencao do host (todas
      as paginas tem o #copyBuffer), e nenhuma view precisa saber disso. }
    if LType = 'clipboard.copy' then
    begin
      CopyBufferToClipboard;
      Exit;
    end;

    if Assigned(FOnAction) then
    begin
      try
        FOnAction(LObj);
      except
        on E: Exception do
          { Uma acao que falha nao pode virar excecao dentro do IE. A view ja
            avisa o usuario quando faz sentido; aqui so registramos. }
          WebHostLogFmt('OnAction(%s): %s: %s', [LType, E.ClassName, E.Message]);
      end;
    end;
  finally
    LValue.Free;
  end;
end;

function TGitWebHost.DocumentAlive: Boolean;
var
  LUrl: string;
begin
  { A pergunta e "o browser ainda tem o NOSSO documento?", e a resposta mais
    barata e a URL: quando a IDE recria a janela do controle, o browser renasce
    vazio e LocationURL fica em branco.

    Perguntar por uma funcao JS via IDispatch.GetIDsOfNames NAO funciona: o
    IDispatch do IHTMLWindow2 so resolve membros da typelib; funcao criada por
    script e expando e exigiria IDispatchEx. }
  LUrl := '';
  try
    LUrl := FBrowser.LocationURL;
  except
    { controle sem documento levanta -- e exatamente o caso "morto" }
  end;
  Result := Pos(TEMP_HTML_PREFIX, LowerCase(LUrl)) > 0;
end;

procedure TGitWebHost.WatchTimerTick(ASender: TObject);
var
  LNow: UInt64;
begin
  { So vigia depois que ja houve um documento nosso: entre o Navigate e o
    primeiro DocumentComplete e normal nao haver nada. }
  if not FDocumentReady then
    Exit;

  if DocumentAlive then
  begin
    FDeadTicks := 0;
    Exit;
  end;

  Inc(FDeadTicks);
  if FDeadTicks < DEAD_TICKS_BEFORE_RELOAD then
    Exit;

  LNow := GetTickCount64;
  if (FLastReloadTick <> 0) and (LNow - FLastReloadTick < RELOAD_COOLDOWN_MS) then
    Exit;

  FLastReloadTick := LNow;
  FDeadTicks := 0;
  WebHostLog('Vigia: documento sumiu (janela recriada pela IDE?); recarregando o painel');
  NavigateToHtml;
end;

procedure TGitWebHost.CallJs(const AFunctionName, AJsonText: string);
var
  LBytes: TBytes;
  LB64, LScript: string;
  LDoc2: IHTMLDocument2;
  LWindow: IHTMLWindow2;
begin
  if not FDocumentReady then
    Exit;
  if not DocumentAlive then
    Exit; // o vigia recarrega; chamar agora daria erro de script

  { Base64 em vez de interpolar o JSON no script: acento, aspas e quebra de
    linha dentro de uma string JS montada por concatenacao e receita de
    documento quebrado. }
  LBytes := TEncoding.UTF8.GetBytes(AJsonText);
  LB64 := TNetEncoding.Base64.EncodeBytesToString(LBytes);
  { TBase64Encoding quebra linha a cada 76 caracteres (RFC 2045); o literal JS
    precisa de uma linha so. }
  LB64 := StringReplace(LB64, #13, '', [rfReplaceAll]);
  LB64 := StringReplace(LB64, #10, '', [rfReplaceAll]);

  { decodeURIComponent(escape(atob(...))) e o truque classico para recuperar
    UTF-8 no Trident, que nao tem TextDecoder. }
  LScript :=
    'try{if(typeof ' + AFunctionName + '===''function''){' +
    AFunctionName + '(decodeURIComponent(escape(window.atob("' + LB64 +
    '"))));}}catch(e){}';

  try
    if Supports(FBrowser.Document, IHTMLDocument2, LDoc2) then
    begin
      LWindow := LDoc2.parentWindow;
      if Assigned(LWindow) then
        LWindow.execScript(LScript, 'javascript');
    end;
  except
    on E: Exception do
      WebHostLogFmt('CallJs(%s): %s: %s', [AFunctionName, E.ClassName, E.Message]);
  end;
end;

function TGitWebHost.TryReadValue(const AElementId: string; out AValue: string): Boolean;
var
  LDoc3: IHTMLDocument3;
  LElement: IHTMLElement;
  LTextArea: IHTMLTextAreaElement;
  LInput: IHTMLInputElement;
  LSelect: IHTMLSelectElement;
begin
  Result := False;
  AValue := '';
  try
    { IHTMLDocument3 e quem tem getElementById -- IHTMLDocument2 nao tem. }
    if not Supports(FBrowser.Document, IHTMLDocument3, LDoc3) then
      Exit;
    LElement := LDoc3.getElementById(AElementId);
    if not Assigned(LElement) then
      Exit;
    if Supports(LElement, IHTMLTextAreaElement, LTextArea) then
    begin
      AValue := LTextArea.value;
      Exit(True);
    end;
    if Supports(LElement, IHTMLInputElement, LInput) then
    begin
      AValue := LInput.value;
      Exit(True);
    end;
    if Supports(LElement, IHTMLSelectElement, LSelect) then
    begin
      AValue := LSelect.value;
      Exit(True);
    end;
  except
    on E: Exception do
      WebHostLogFmt('TryReadValue(%s): %s: %s', [AElementId, E.ClassName, E.Message]);
  end;
end;

{ ============================================================================
  Atalhos de edicao dentro do painel

  TApplicationEvents multiplexa: varias instancias convivem, e o proprio
  GitLens4D ja usava esta rota antes do painel web (la aplicando a acao num
  TCustomEdit). O destino mudou, o motivo nao.

  So agimos quando o foco esta DENTRO deste host -- caso contrario estariamos
  roubando o Ctrl+C do editor de codigo da IDE.

  Ctrl+Z fica de fora de proposito: desfazer dentro de um campo e do proprio
  navegador, e nao ha como reproduzi-lo fielmente daqui.
  ============================================================================ }
procedure TGitWebHost.HandleAppMessage(var Msg: TMsg; var Handled: Boolean);
var
  LText: string;
  LJson: TJSONObject;
begin
  if Msg.message <> WM_KEYDOWN then
    Exit;
  { Ctrl sem Alt: AltGr chega como Ctrl+Alt e nao pode ser confundido com
    atalho (em teclado ABNT2 e ele quem digita ? e /). }
  if (GetKeyState(VK_CONTROL) >= 0) or (GetKeyState(VK_MENU) < 0) then
    Exit;
  if not HandleAllocated then
    Exit;
  if (Msg.hwnd <> Handle) and not IsChild(Handle, Msg.hwnd) then
    Exit;
  if not FDocumentReady then
    Exit;

  case Msg.wParam of
    Ord('C'):
      begin
        Handled := True;
        CallJs('gitCopySelection', '{}');
      end;
    Ord('X'):
      begin
        Handled := True;
        CallJs('gitCutSelection', '{}');
      end;
    Ord('A'):
      begin
        Handled := True;
        CallJs('gitSelectAllInField', '{}');
      end;
    Ord('V'):
      begin
        Handled := True;
        LText   := '';
        try
          if Clipboard.HasFormat(CF_TEXT) then
            LText := Clipboard.AsText;
        except
          on E: Exception do
            WebHostLogFmt('Ctrl+V: clipboard indisponivel: %s', [E.Message]);
        end;
        if LText <> '' then
        begin
          LJson := TJSONObject.Create;
          try
            LJson.AddPair('text', LText);
            CallJs('gitInsertText', LJson.ToJSON);
          finally
            LJson.Free;
          end;
        end;
      end;
  end;
end;

{ O JS deposita a selecao em #copyBuffer e avisa; nos lemos pelo DOM e
  escrevemos no clipboard. O texto NAO passa pela URL sentinela: um bloco de
  codigo selecionado estoura o limite do Trident sem aviso. }
procedure TGitWebHost.CopyBufferToClipboard;
var
  LText: string;
begin
  if not TryReadValue('copyBuffer', LText) or (LText = '') then
    Exit;
  try
    Clipboard.AsText := LText;
    WebHostLogFmt('CopyBufferToClipboard: %d caractere(s)', [Length(LText)]);
  except
    on E: Exception do
      { Clipboard ocupado por outro processo e coisa de todo dia no Windows. }
      WebHostLogFmt('CopyBufferToClipboard: %s: %s', [E.ClassName, E.Message]);
  end;
end;

procedure TGitWebHost.CMDialogChar(var Message: TCMDialogChar);
begin
  { Quem tem o foco de verdade e a janela "Internet Explorer_Server", que nao e
    controle VCL. TApplication.IsKeyMsg nao a acha, sobe pelos pais ate o
    TWebBrowser e manda CN_CHAR; TWinControl.CNChar entao pergunta ao PAI se
    aquela letra e acelerador de alguem (porque o browser nao responde
    DLGC_WANTCHARS ao WM_GETDLGCODE -- ele nao sabe que ha um <input> com foco
    la dentro). A pergunta sobe ate a janela principal da IDE, e qualquer
    botao com '&A'/'&V' no caption responde "e minha": a tecla e engolida e
    nunca chega ao documento.

    Por isso o sintoma aparece POR LETRA: somem so as que casam com algum
    acelerador existente. Responder 0 aqui, sem repassar ao pai, devolve a
    tecla ao caminho normal (TranslateMessage/DispatchMessage).

    Com Alt pressionado o comportamento antigo continua: Alt+F tem de seguir
    abrindo o menu File da IDE com o painel focado. }
  if (Message.KeyData and ALT_DOWN_KEYDATA) <> 0 then
  begin
    inherited;
    Exit;
  end;

  if not GDialogCharLogged then
  begin
    GDialogCharLogged := True;
    WebHostLogFmt('CMDialogChar: caca a acelerador interceptada (1o caractere: #%d); ' +
      'letras voltam a digitar no painel', [Message.CharCode]);
  end;

  Message.Result := 0;
end;

end.
