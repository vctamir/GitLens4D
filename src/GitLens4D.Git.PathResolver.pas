unit GitLens4D.Git.PathResolver;

{ ============================================================================
  GitLens4D - Localização do Git no Windows
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: descobrir onde o git.exe está instalado,
  consultando o Registro, paths padrão e variáveis de ambiente.
  ============================================================================ }

interface

uses
  GitLens4D.Interfaces;

type
  TGitPathResolver = class(TInterfacedObject, IGitPathResolver)
  public
    function Resolve: string;
  end;

implementation

uses
  Winapi.Windows,
  System.Win.Registry,
  System.SysUtils;

function TGitPathResolver.Resolve: string;
var
  Reg     : TRegistry;
  Path    : string;
  LocalApp: string;
begin
  Result := 'git'; // fallback: espera que esteja no PATH do sistema

  // 1ª tentativa: chave de registro oficial do Git for Windows
  Reg := TRegistry.Create(KEY_READ or $0100);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly('SOFTWARE\GitForWindows') then
    begin
      Path := Reg.ReadString('InstallPath');
      if FileExists(IncludeTrailingPathDelimiter(Path) + 'cmd\git.exe') then
      begin
        Result := IncludeTrailingPathDelimiter(Path) + 'cmd\git.exe';
        Exit;
      end;
    end;
  finally
    Reg.Free;
  end;

  // 2ª tentativa: paths padrão de instalação
  if FileExists('C:\Program Files\Git\cmd\git.exe') then
  begin
    Result := 'C:\Program Files\Git\cmd\git.exe';
    Exit;
  end;

  if FileExists('C:\Program Files (x86)\Git\cmd\git.exe') then
  begin
    Result := 'C:\Program Files (x86)\Git\cmd\git.exe';
    Exit;
  end;

  // 3ª tentativa: instalação por usuário (LOCALAPPDATA)
  LocalApp := GetEnvironmentVariable('LOCALAPPDATA');
  if FileExists(LocalApp + '\Programs\Git\cmd\git.exe') then
    Result := LocalApp + '\Programs\Git\cmd\git.exe';
end;

end.
