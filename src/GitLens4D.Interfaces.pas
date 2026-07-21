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
    function GetFileContent(const ARevision, AFile, ABaseDir: string): string;
    function GetDiff(const AFile, ABaseDir: string): string;
    function GetRepoRoot(const ABaseDir: string): string;
    function GetCurrentBranch(const ABaseDir: string): string;
    function GetBranches(const ABaseDir: string): TStringList;
    procedure CreateBranch(const ABranchName, ABaseDir: string);
    procedure CheckoutBranch(const ABranchName, ABaseDir: string);
    procedure Push(const ABaseDir: string);
    procedure Pull(const ABaseDir: string);
    procedure AddFile(const AFile, ABaseDir: string);
    procedure DiscardChanges(const AFile, ABaseDir: string);
    function GetRemoteUrl(const ABaseDir: string): string;
    function GetAheadCount(const ABaseDir: string): Integer;
  end;

  // ── Contrato: Interpretar saída do "git blame -p" ────────────────────────
  IBlameParser = interface
    ['{C3D4E5F6-A7B8-4901-CD23-4567890ABCDE}']
    function Parse(const ARawOutput: string; ALine: Integer): string;
  end;

  // ── Contrato: Interpretar saída do "git log -L" ──────────────────────────
  TGitHistoryEntry = record
    Hash: string;
    Author: string;
    Date: string;
    Message: string;
    Patch: string; // Conteúdo do código alterado
  end;

  TGitHistoryArray = array of TGitHistoryEntry;

  IHistoryParser = interface
    ['{D4E5F6A7-B8C9-4012-DE34-567890ABCDEF}']
    function Parse(const ARawOutput: string; ALine: Integer): TGitHistoryArray;
  end;

  // ── Estruturas para Status de Arquivos ──────────────────────────────────
  TGitStatusKind = (skModified, skAdded, skDeleted, skRenamed, skUntracked, skIgnored, skUnknown);

  TGitFileStatus = record
    FileName: string;
    Status: TGitStatusKind;
    Staged: Boolean;
  end;

  TGitFileStatusArray = array of TGitFileStatus;

  // ── Contrato: Interpretar saída do "git status --porcelain" ──────────────
  IStatusParser = interface
    ['{12345678-ABCD-1234-ABCD-1234567890AB}']
    function Parse(const ARawOutput: string): TGitFileStatusArray;
  end;

  TGitProjectMetadata = record
    ProjectName: string;
    ProjectVersion: string;
  end;

  IGitProjectProvider = interface
    ['{E9F8B7C6-D5E4-4321-A1B2-C3D4E5F67890}']
    function GetMetadata: TGitProjectMetadata;
  end;

  // ── Contrato: Provedor de Status do Repositório ──────────────────────────
  IGitStatusProvider = interface
    ['{87654321-DCBA-4321-DCBA-0987654321BA}']
    function GetStatus(const ABaseDir: string): TGitFileStatusArray;
  end;

  // ── Contrato: Persistência de configurações ──────────────────────────────
  ISettingsRepository = interface
    ['{E5F6A7B8-C9D0-4123-EF45-67890ABCDEF0}']
    procedure Load(out AEnabledEditor, AEnabledDebug: Boolean);
    procedure Save(AEnabledEditor, AEnabledDebug: Boolean);
    procedure LoadTaskInfo(out ATaskNum, ATaskDesc: string);
    procedure SaveTaskInfo(const ATaskNum, ATaskDesc: string);
    procedure LoadCommitDraft(out ADraft: string);
    procedure SaveCommitDraft(const ADraft: string);
    procedure LoadSelectedFiles(out AFiles: string);
    procedure SaveSelectedFiles(const AFiles: string);
    procedure LoadAIConfig(out AType, AEndpoint, AKey, AModel, ALang, AFormat: string; out ATemp: Double; out AMaxTokens: Integer);
    procedure SaveAIConfig(const AType, AEndpoint, AKey, AModel, ALang, AFormat: string; ATemp: Double; AMaxTokens: Integer);
    procedure LoadProjectFormat(const AProjectKey: string; out AFormat: string);
    procedure SaveProjectFormat(const AProjectKey, AFormat: string);
    procedure LoadGeneralConfig(out AShortcutHist, AShortcutChanges, ACommitTag: string);
    procedure SaveGeneralConfig(const AShortcutHist, AShortcutChanges, ACommitTag: string);
  end;

  // ── Contrato: Serviço de IA para mensagens de commit ─────────────────────
  IAIService = interface
    ['{67860509-AFC6-4C93-81FE-681BEF473D5C}']
    function GenerateCommitMessage(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
    function GeneratePRDescription(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
    function IsConfigured: Boolean;
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
