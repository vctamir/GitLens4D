; ============================================================================
; Instalador do GitLens4D (RAD Studio 10.2.3 Tokyo / BDS 19.0)
;
; Escrito para a sintaxe do Inno Setup 5 (funciona igual no 6): sem {autopf},
; sem WizardStyle -- as duas coisas so existem no 6, e a maquina de referencia
; deste projeto tem o 5 instalado.
;
; ----------------------------------------------------------------------------
; Por que instalacao POR USUARIO (sem admin)
; ----------------------------------------------------------------------------
; O que registra o pacote na IDE e uma chave em HKEY_CURRENT_USER
; (Known Packages). Instalar os arquivos em Program Files exigiria elevacao
; para gravar uma configuracao que, no fim, e por usuario de qualquer jeito --
; pediria senha de administrador sem ganhar nada. Por isso tudo vai para
; %LOCALAPPDATA%\Programs.
;
; ----------------------------------------------------------------------------
; O layout de pastas NAO e arbitrario
; ----------------------------------------------------------------------------
; As telas do plugin sao paginas HTML, e o host as encontra subindo a partir
; da pasta do .bpl:
;
;   GitLens4D.IDE.WebHost.ResolveHtmlSource  procura  <ancestral>\ui\<arquivo>
;
; Com o .bpl em {app}\bin, o primeiro ancestral e {app} -- e por isso que ui\
; fica ao lado de bin\. Mudar esse layout quebra a descoberta SEM ERRO
; NENHUM: cada tela abre com o HTML de emergencia ("ui\... nao encontrado"),
; que e facil de confundir com bug do plugin.
;
; base.css e diff-render.js sao tao obrigatorios quanto os .html: o host
; injeta os dois no lugar dos marcadores de cada pagina. Sem eles as telas
; abrem sem estilo e o diff sai sem cor.
; ============================================================================

#define AppName "GitLens4D"
#define AppPublisher "Quality Sistemas"
#define BplName "GitLens4D.bpl"

; Passados pelo build-installer.ps1 (-D). Os defaults servem para compilar a
; mao a partir desta pasta.
#ifndef AppVersion
  #define AppVersion "1.0.1.3"
#endif
#ifndef SourceRoot
  #define SourceRoot ".."
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif

[Setup]
AppId={{4C8A2E71-6B3D-4F92-A15E-9D7C0B4E2F83}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppComments=Git dentro do editor do Delphi: blame, historico da linha e commits com IA.
DefaultDirName={localappdata}\Programs\GitLens4D
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=GitLens4D-{#AppVersion}-setup
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayName={#AppName} {#AppVersion}
; O .bpl e 32 bits (bds.exe e 32 bits) mesmo em Windows 64.
UninstallDisplayIcon={app}\bin\{#BplName}

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "{#SourceRoot}\bin\{#BplName}"; DestDir: "{app}\bin"; Flags: ignoreversion

; As cinco telas + a base compartilhada. Ver o cabecalho: o layout importa.
Source: "{#SourceRoot}\ui\*.html"; DestDir: "{app}\ui"; Flags: ignoreversion
Source: "{#SourceRoot}\ui\*.css";  DestDir: "{app}\ui"; Flags: ignoreversion
Source: "{#SourceRoot}\ui\*.js";   DestDir: "{app}\ui"; Flags: ignoreversion

Source: "{#SourceRoot}\README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme
Source: "{#SourceRoot}\LICENSE";   DestDir: "{app}"; Flags: ignoreversion

[Registry]
; E ISTO que faz a IDE carregar o pacote. uninsdeletevalue: desinstalar tem de
; tirar o registro, senao a IDE tenta carregar um .bpl que nao existe mais e
; reclama em toda abertura.
Root: HKCU; Subkey: "Software\Embarcadero\BDS\19.0\Known Packages"; \
  ValueType: string; ValueName: "{app}\bin\{#BplName}"; \
  ValueData: "{#AppName} - Git integrado ao editor"; Flags: uninsdeletevalue

[Code]
const
  { Classe da janela principal do RAD Studio. E como detectamos a IDE aberta
    sem depender de nome de processo. }
  IDE_WINDOW_CLASS = 'TAppBuilder';

function IdeIsRunning: Boolean;
begin
  Result := FindWindowByClassName(IDE_WINDOW_CLASS) <> 0;
end;

{ O .bpl fica travado pelo bds.exe enquanto a IDE roda: copiar por cima
  falharia no meio da instalacao, deixando tudo pela metade. Melhor barrar
  antes de comecar.

  O laco de "tentar de novo" NAO pode existir em modo silencioso: com
  /SUPPRESSMSGBOXES o Inno responde os dialogos com o botao PADRAO, e o padrao
  de MB_RETRYCANCEL e Repetir -- uma instalacao automatizada com a IDE aberta
  giraria para sempre, sem tela e sem log. Em silencioso a resposta certa e
  desistir na hora. }
function BlockWhileIdeRunning(const AMessage: string): Boolean;
begin
  Result := True;
  while IdeIsRunning do
  begin
    if WizardSilent then
    begin
      Result := False;
      Exit;
    end;
    if MsgBox(AMessage, mbError, MB_RETRYCANCEL) = IDCANCEL then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function InitializeSetup: Boolean;
begin
  Result := BlockWhileIdeRunning(
    'O RAD Studio esta aberto.'#13#10#13#10 +
    'Feche a IDE antes de continuar -- enquanto ela roda, o arquivo do ' +
    'pacote fica em uso e nao pode ser substituido.'#13#10#13#10 +
    'Tentar de novo?');
end;

function InitializeUninstall: Boolean;
begin
  Result := BlockWhileIdeRunning(
    'O RAD Studio esta aberto.'#13#10#13#10 +
    'Feche a IDE para desinstalar.'#13#10#13#10 +
    'Tentar de novo?');
end;

{ O git da linha de comando e requisito de RUNTIME: o plugin inteiro e uma
  casca em volta dele (ver GitLens4D.Git.Runner). Sem git nao ha blame, nao ha
  status e nao ha commit -- mas nao bloqueamos a instalacao, porque instalar o
  git depois e trivial e barrar aqui obrigaria a repetir o instalador. }
function GitFound: Boolean;
var
  LResultCode: Integer;
begin
  { "where" cobre o PATH inteiro. }
  Result := Exec(ExpandConstant('{cmd}'), '/C where git.exe > nul 2>&1', '',
                 SW_HIDE, ewWaitUntilTerminated, LResultCode) and (LResultCode = 0);
end;

{ A IDE so le Known Packages na inicializacao -- instalar com ela fechada (que
  e o unico caminho possivel aqui) ja garante o carregamento na proxima
  abertura. Estes avisos existem so para o usuario nao descobrir os dois
  problemas pelo caminho ruim. }
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then
    Exit;

  if not RegKeyExists(HKEY_CURRENT_USER, 'Software\Embarcadero\BDS\19.0') then
    MsgBox('Nao encontrei o RAD Studio 10.2.3 (BDS 19.0) neste usuario.'#13#10#13#10 +
           'O pacote foi instalado e registrado mesmo assim, mas so sera carregado ' +
           'por uma instalacao do BDS 19.0. Outras versoes do Delphi exigem ' +
           'recompilar o pacote -- um .bpl serve a uma versao so da IDE.',
           mbInformation, MB_OK);

  if not GitFound then
    MsgBox('O git nao foi encontrado no PATH.'#13#10#13#10 +
           'O GitLens4D e uma interface para o git da linha de comando: sem ele, ' +
           'nenhuma tela do plugin tem o que mostrar.'#13#10#13#10 +
           'Instale o Git for Windows (https://git-scm.com) e reabra a IDE.',
           mbInformation, MB_OK);
end;

{ As configuracoes (IA, atalhos, rascunho de commit por repositorio) ficam em
  HKCU\Software\QSGitLens4D e NAO sao apagadas junto: sao dados do usuario, e
  uma reinstalacao tem de reencontrar tudo onde estava. Quem quiser limpar
  apaga a chave a mao -- e o caminho aparece aqui justamente para isso. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    MsgBox('Pacote removido e desregistrado da IDE.'#13#10#13#10 +
           'As configuracoes continuam no Registro, em:'#13#10 +
           'HKEY_CURRENT_USER\Software\QSGitLens4D' + #13#10#13#10 +
           'Apague essa chave a mao se quiser remover tambem esses dados.',
           mbInformation, MB_OK);
end;
