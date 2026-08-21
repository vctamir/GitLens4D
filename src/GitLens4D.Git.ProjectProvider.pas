unit GitLens4D.Git.ProjectProvider;

{ ============================================================================
  GitLens4D - Provedor de Metadados do Projeto Delphi
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: Interagir com a Open Tools API (OTA) para extrair
  informações do projeto ativo (Nome, Versão).

  ----------------------------------------------------------------------------
  Por que ler a CONFIGURAÇÃO ATIVA, e não ProjectOptions.Values[]
  ----------------------------------------------------------------------------
  A versão que vai para o executável não é uma propriedade do projeto: é uma
  propriedade da BUILD CONFIGURATION ativa, e ela herda em cascata
  (Base -> Base_Win32 -> Debug/Release). Um .dproj real tem várias, com valores
  DIFERENTES -- em ARH.dproj, por exemplo, convivem FileVersion=27.0.3.0 na
  Base, 27.0.1.8 numa configuração e 27.0.2026.9999 na de Debug.

  Ler `LProject.ProjectOptions.Values['FileVersion']` (ou 'MajorVersion',
  'Release', 'Build') não resolve nada disso: esses nomes não são as chaves que
  o .dproj usa, então o retorno cai no default e a versão saía sempre 1.0.0.0.
  Os nomes de verdade são VerInfo_Keys (uma lista Chave=Valor, onde mora o
  FileVersion) e VerInfo_MajorVer/MinorVer/Release/Build.

  A API certa é IOTAProjectOptionsConfigurations.ActiveConfiguration, e o
  IOTABuildConfiguration.GetValue já percorre as configurações pai sozinho --
  é exatamente a mesma resolução que o MSBuild faz ao compilar. Assinaturas
  conferidas em Studio\19.0\source\ToolsAPI\ToolsAPI.pas (IOTABuildConfiguration140
  linha ~2714, IOTAProjectOptionsConfigurations140 linha ~2829).

  Quando a plataforma ativa tem configuração própria (Base_Win32 e afins),
  perguntamos a ela: é onde o IDE grava o VerInfo por plataforma.

  Se nada disso responder, o último recurso é ler o .dproj do disco -- o mesmo
  arquivo, sem intermediário.
  ============================================================================ }

interface

uses
  System.SysUtils,
  System.Variants,
  System.StrUtils,
  System.Classes,
  System.IOUtils,
  ToolsAPI,
  GitLens4D.Interfaces;

type
  TGitProjectProvider = class(TInterfacedObject, IGitProjectProvider)
  private
    function VersionFromConfiguration(const AProject: IOTAProject): string;
    function VersionFromDproj(const AProjectFile: string): string;
  public
    function GetMetadata: TGitProjectMetadata;
  end;

implementation

const
  DEFAULT_VERSION = '1.0.0.0';

  KEY_VERINFO       = 'VerInfo_Keys';
  KEY_MAJOR         = 'VerInfo_MajorVer';
  KEY_MINOR         = 'VerInfo_MinorVer';
  KEY_RELEASE       = 'VerInfo_Release';
  KEY_BUILD         = 'VerInfo_Build';
  FILE_VERSION_NAME = 'FileVersion';

{ Extrai FileVersion de uma lista no formato do VerInfo_Keys:
    CompanyName=;FileDescription=...;FileVersion=27.0.3.0;InternalName=...
  Devolve '' quando a chave não está lá ou está vazia. }
function FileVersionFromKeys(const AKeys: string): string;
var
  LParts: TArray<string>;
  LPair : string;
  LPos  : Integer;
  LName : string;
begin
  Result := '';
  if AKeys.Trim = '' then
    Exit;

  LParts := AKeys.Split([';']);
  for LPair in LParts do
  begin
    LPos := Pos('=', LPair);
    if LPos <= 1 then
      Continue;
    LName := Trim(Copy(LPair, 1, LPos - 1));
    if SameText(LName, FILE_VERSION_NAME) then
    begin
      Result := Trim(Copy(LPair, LPos + 1, MaxInt));
      { $(MSBuildProjectName) e afins aparecem em outras chaves; se algum dia
        aparecer aqui, uma macro não expandida não é versão. }
      if Result.Contains('$(') then
        Result := '';
      Exit;
    end;
  end;
end;

{ Uma versão só é útil se disser alguma coisa: nem vazia, nem o default que
  todo projeto novo carrega. }
function IsUsefulVersion(const AVersion: string): Boolean;
begin
  Result := (AVersion.Trim <> '') and
            (AVersion <> DEFAULT_VERSION) and
            (AVersion <> '0.0.0.0');
end;

function JoinParts(const AMajor, AMinor, ARelease, ABuild: string): string;
var
  LMajor, LMinor, LRelease, LBuild: string;
begin
  LMajor   := IfThen(AMajor.Trim = '', '0', AMajor.Trim);
  LMinor   := IfThen(AMinor.Trim = '', '0', AMinor.Trim);
  LRelease := IfThen(ARelease.Trim = '', '0', ARelease.Trim);
  LBuild   := IfThen(ABuild.Trim = '', '0', ABuild.Trim);
  Result   := Format('%s.%s.%s.%s', [LMajor, LMinor, LRelease, LBuild]);
end;

{ TGitProjectProvider }

function TGitProjectProvider.VersionFromConfiguration(const AProject: IOTAProject): string;
var
  LConfigs : IOTAProjectOptionsConfigurations;
  LConfig  : IOTABuildConfiguration;
  LPlatform: IOTABuildConfiguration;
  LName    : string;

  { GetValue já recorre às configurações pai (Base_Win32 -> Base), que é a
    mesma resolução do MSBuild. }
  function Read(const APropName: string): string;
  begin
    Result := '';
    try
      if Assigned(LPlatform) then
        Result := LPlatform.GetValue(APropName, True);
      if Result.Trim = '' then
        Result := LConfig.GetValue(APropName, True);
    except
      Result := '';
    end;
  end;

begin
  Result := '';
  if not Assigned(AProject) or not Assigned(AProject.ProjectOptions) then
    Exit;

  if not Supports(AProject.ProjectOptions, IOTAProjectOptionsConfigurations, LConfigs) then
    Exit;

  LConfig := LConfigs.ActiveConfiguration;
  if not Assigned(LConfig) then
    Exit;

  { Configuração específica da plataforma ativa, quando existir: é onde o IDE
    grava o VerInfo por plataforma (Base_Win32, Base_Win64...). }
  LPlatform := nil;
  try
    LName := LConfigs.ActivePlatformName;
    if LName <> '' then
      LPlatform := LConfig.PlatformConfiguration[LName];
  except
    LPlatform := nil;
  end;

  { 1. FileVersion dentro de VerInfo_Keys -- é literalmente a string que vai
       para o recurso de versão do executável. }
  Result := FileVersionFromKeys(Read(KEY_VERINFO));
  if IsUsefulVersion(Result) then
    Exit;

  { 2. Os quatro números soltos, que é o que a página Version Info edita. }
  Result := JoinParts(Read(KEY_MAJOR), Read(KEY_MINOR), Read(KEY_RELEASE), Read(KEY_BUILD));
  if not IsUsefulVersion(Result) then
    Result := '';
end;

{ Último recurso: o próprio .dproj. Sem saber qual configuração está ativa
  (é justamente o caso em que a OTA não respondeu), fica com o PRIMEIRO
  VerInfo_Keys do arquivo -- que é o da configuração Base, a raiz da cascata e
  o valor que vale para todas as que não sobrescrevem. }
function TGitProjectProvider.VersionFromDproj(const AProjectFile: string): string;
var
  LText          : string;
  LStart, LFinish: Integer;
  LKeys          : string;
begin
  Result := '';
  if (AProjectFile = '') or not TFile.Exists(AProjectFile) then
    Exit;

  try
    LText := TFile.ReadAllText(AProjectFile, TEncoding.UTF8);
  except
    Exit;
  end;

  LStart := Pos('<' + KEY_VERINFO + '>', LText);
  if LStart = 0 then
    Exit;
  Inc(LStart, Length('<' + KEY_VERINFO + '>'));

  LFinish := PosEx('</' + KEY_VERINFO + '>', LText, LStart);
  if LFinish = 0 then
    Exit;

  LKeys  := Copy(LText, LStart, LFinish - LStart);
  Result := FileVersionFromKeys(LKeys);
  if not IsUsefulVersion(Result) then
    Result := '';
end;

function TGitProjectProvider.GetMetadata: TGitProjectMetadata;
var
  LModSvc : IOTAModuleServices;
  LProject: IOTAProject;
begin
  Result.ProjectName    := 'Unknown';
  Result.ProjectVersion := DEFAULT_VERSION;

  if not Supports(BorlandIDEServices, IOTAModuleServices, LModSvc) then
    Exit;

  LProject := LModSvc.GetActiveProject;
  if not Assigned(LProject) then
    Exit;

  Result.ProjectName := ChangeFileExt(ExtractFileName(LProject.FileName), '');

  try
    Result.ProjectVersion := VersionFromConfiguration(LProject);

    if not IsUsefulVersion(Result.ProjectVersion) then
      Result.ProjectVersion := VersionFromDproj(LProject.FileName);

    if not IsUsefulVersion(Result.ProjectVersion) then
      Result.ProjectVersion := DEFAULT_VERSION;
  except
    { Metadado é acessório: nunca pode derrubar a geração da mensagem. }
    Result.ProjectVersion := DEFAULT_VERSION;
  end;
end;

end.
