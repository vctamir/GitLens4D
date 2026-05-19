unit GitLens4D.Interfaces;

{ ============================================================================
  GitLens4D - Camada de Contratos (Interfaces)
  Princípio: Interface Segregation (ISP) + Dependency Inversion (DIP)

  Cada interface representa uma responsabilidade atômica e distinta.
  Nenhuma classe concreta é referenciada neste arquivo.
  ============================================================================ }

interface

uses
  System.Classes;

type
  // ── Contrato: Localizar o executável do Git no sistema ──────────────────
  IGitPathResolver = interface
    ['{A1B2C3D4-E5F6-4789-AB01-234567890ABC}']
    function Resolve: string;
  end;

  // ── Contrato: Executar um comando Git e retornar o output bruto ──────────
  IGitRunner = interface
    ['{B2C3D4E5-F6A7-4890-BC12-34567890ABCD}']
    function Execute(const ACommand, ABaseDir: string): string;
  end;

  // ── Contrato: Interpretar saída do "git blame -p" ────────────────────────
  IBlameParser = interface
    ['{C3D4E5F6-A7B8-4901-CD23-4567890ABCDE}']
    function Parse(const ARawOutput: string; ALine: Integer): string;
  end;

  // ── Contrato: Interpretar saída do "git log -L" ──────────────────────────
  // Retorna TStringList (caller é responsável por liberá-la)
  IHistoryParser = interface
    ['{D4E5F6A7-B8C9-4012-DE34-567890ABCDEF}']
    function Parse(const ARawOutput: string; ALine: Integer): TStringList;
  end;

  // ── Contrato: Persistência de configurações ──────────────────────────────
  ISettingsRepository = interface
    ['{E5F6A7B8-C9D0-4123-EF45-67890ABCDEF0}']
    procedure Load(out AEnabledEditor, AEnabledDebug: Boolean);
    procedure Save(AEnabledEditor, AEnabledDebug: Boolean);
  end;

  // ── Contrato: Exibição de mensagens na aba do IDE ────────────────────────
  IIDEMessenger = interface
    ['{F6A7B8C9-D0E1-4234-F056-7890ABCDEF01}']
    procedure ShowMessage(const AMessage: string);
    procedure ShowMessages(const AMessages: TStringList);
    procedure Hide;
  end;

implementation

end.
