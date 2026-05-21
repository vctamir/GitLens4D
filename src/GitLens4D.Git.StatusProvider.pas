unit GitLens4D.Git.StatusProvider;

{ ============================================================================
  GitLens4D - Provedor de Status do Repositório
  Princípio: Dependency Inversion (DIP)

  Responsabilidade: Orquestrar o Runner e o Parser para fornecer a lista
  de arquivos alterados de um diretório base.
  ============================================================================ }

interface

uses
  GitLens4D.Interfaces;

type
  TGitStatusProvider = class(TInterfacedObject, IGitStatusProvider)
  private
    FGitPath: string;
    FRunner: IGitRunner;
    FParser: IStatusParser;
  public
    constructor Create(const AGitPath: string; ARunner: IGitRunner; AParser: IStatusParser);
    function GetStatus(const ABaseDir: string): TGitFileStatusArray;
  end;

implementation

uses
  System.SysUtils;

{ TGitStatusProvider }

constructor TGitStatusProvider.Create(const AGitPath: string; ARunner: IGitRunner; AParser: IStatusParser);
begin
  inherited Create;
  FGitPath := AGitPath;
  FRunner  := ARunner;
  FParser  := AParser;
end;

function TGitStatusProvider.GetStatus(const ABaseDir: string): TGitFileStatusArray;
var
  Command: string;
  RawOutput: string;
begin
  Command := Format('"%s" status --porcelain', [FGitPath]);
  RawOutput := FRunner.Execute(Command, ABaseDir);
  Result := FParser.Parse(RawOutput);
end;

end.
