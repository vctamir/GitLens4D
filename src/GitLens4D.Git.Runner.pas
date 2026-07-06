unit GitLens4D.Git.Runner;

{ ============================================================================
  GitLens4D - Executor de Comandos Git
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: criar um processo filho (cmd.exe), capturar
  seu stdout/stderr via pipe anônimo e retornar o resultado como string.
  Não conhece a semântica de nenhum comando Git específico.
  ============================================================================ }

interface

uses
  System.Classes,
  GitLens4D.Interfaces;

type
  TGitRunner = class(TInterfacedObject, IGitRunner)
  public
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

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  GitLens4D.Git.PathResolver;

function TGitRunner.GetCurrentBranch(const ABaseDir: string): string;
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" rev-parse --abbrev-ref HEAD', [PathSvc.Resolve]);
  Result  := Execute(Command, ABaseDir).Trim;
end;

function TGitRunner.GetBranches(const ABaseDir: string): TStringList;
var
  Command: string;
  PathSvc: IGitPathResolver;
  Raw    : string;
begin
  Result      := TStringList.Create;
  PathSvc     := TGitPathResolver.Create;
  Command     := Format('"%s" branch --format="%%(refname:short)"', [PathSvc.Resolve]);
  Raw         := Execute(Command, ABaseDir);
  Result.Text := Raw.Trim;
end;

procedure TGitRunner.CreateBranch(const ABranchName, ABaseDir: string);
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" checkout -b "%s"', [PathSvc.Resolve, ABranchName]);
  Execute(Command, ABaseDir);
end;

procedure TGitRunner.CheckoutBranch(const ABranchName, ABaseDir: string);
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" checkout "%s"', [PathSvc.Resolve, ABranchName]);
  Execute(Command, ABaseDir);
end;

procedure TGitRunner.Push(const ABaseDir: string);
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" push', [PathSvc.Resolve]);
  Execute(Command, ABaseDir);
end;

procedure TGitRunner.Pull(const ABaseDir: string);
var
  Command: string;
  PathSvc: IGitPathResolver;
  LOutput: string;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" pull', [PathSvc.Resolve]);
  LOutput := Execute(Command, ABaseDir);

  if (Pos('CONFLICT', LOutput) > 0) or (Pos('Automatic merge failed', LOutput) > 0) then
  begin
    Execute(Format('"%s" merge --abort', [PathSvc.Resolve]), ABaseDir);
    raise Exception.Create('Conflito detectado durante o Pull!' + sLineBreak +
      'A operação foi abortada automaticamente para evitar inconsistências no seu código.');
  end;
end;

procedure TGitRunner.AddFile(const AFile, ABaseDir: string);
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" add "%s"', [PathSvc.Resolve, AFile]);
  Execute(Command, ABaseDir);
end;

procedure TGitRunner.DiscardChanges(const AFile, ABaseDir: string);
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  // Desfaz alterações no arquivo (tracked)
  Command := Format('"%s" checkout -- "%s"', [PathSvc.Resolve, AFile]);
  Execute(Command, ABaseDir);
end;

function TGitRunner.GetRemoteUrl(const ABaseDir: string): string;
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" config --get remote.origin.url', [PathSvc.Resolve]);
  Result  := Execute(Command, ABaseDir).Trim;
end;

function TGitRunner.GetAheadCount(const ABaseDir: string): Integer;
var
  Command: string;
  PathSvc: IGitPathResolver;
  LOutput: string;
begin
  Result  := 0;
  PathSvc := TGitPathResolver.Create;
  // Conta commits que estão no HEAD mas não estão no upstream (@{u})
  Command := Format('"%s" rev-list --count @{u}..HEAD', [PathSvc.Resolve]);
  LOutput := Execute(Command, ABaseDir).Trim;

  if LOutput <> '' then
    Result := StrToIntDef(LOutput, 0);
end;

function TGitRunner.GetRepoRoot(const ABaseDir: string): string;
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" rev-parse --show-toplevel', [PathSvc.Resolve]);
  Result  := Execute(Command, ABaseDir).Trim;
end;

function TGitRunner.GetFileContent(const ARevision, AFile, ABaseDir: string): string;
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  Command := Format('"%s" show %s:"%s"', [PathSvc.Resolve, ARevision, AFile]);
  Result  := Execute(Command, ABaseDir);
end;

function TGitRunner.GetDiff(const AFile, ABaseDir: string): string;
var
  Command: string;
  PathSvc: IGitPathResolver;
begin
  PathSvc := TGitPathResolver.Create;
  // git diff HEAD -- <file> mostra as mudanças atuais em relação ao último commit
  Command := Format('"%s" diff HEAD -- "%s"', [PathSvc.Resolve, AFile]);
  Result  := Execute(Command, ABaseDir);
end;

function TGitRunner.Execute(const ACommand, ABaseDir: string): string;
var
  SA                             : TSecurityAttributes;
  SI                             : TStartupInfo;
  PI                             : TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK                          : Boolean;
  Buffer                         : array [0 .. 1024] of Byte;
  BytesRead                      : Cardinal;
  TempStr                        : UTF8String;
  CmdLine                        : string;
begin
  Result                  := '';
  SA.nLength              := SizeOf(SA);
  SA.bInheritHandle       := True;
  SA.lpSecurityDescriptor := nil;

  if not CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SA, 0) then
    Exit;

  try
    SetHandleInformation(StdOutPipeRead, HANDLE_FLAG_INHERIT, 0);

    FillChar(SI, SizeOf(SI), 0);
    SI.cb          := SizeOf(SI);
    SI.dwFlags     := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    SI.wShowWindow := SW_HIDE;
    SI.hStdInput   := GetStdHandle(STD_INPUT_HANDLE);
    SI.hStdOutput  := StdOutPipeWrite;
    SI.hStdError   := StdOutPipeWrite;

    CmdLine := 'cmd.exe /s /c "' + ACommand + '"';
    UniqueString(CmdLine);

    WasOK := CreateProcess(nil, PChar(CmdLine), nil, nil, True, 0,
      nil, PChar(ABaseDir), SI, PI);
    CloseHandle(StdOutPipeWrite);

    if WasOK then
    begin
      try
        while ReadFile(StdOutPipeRead, Buffer, 1024, BytesRead, nil) do
        begin
          if BytesRead > 0 then
          begin
            SetString(TempStr, PAnsiChar(@Buffer[0]), BytesRead);
            Result := Result + string(TempStr);
          end;
        end;
        WaitForSingleObject(PI.hProcess, INFINITE);
      finally
        CloseHandle(PI.hThread);
        CloseHandle(PI.hProcess);
      end;
    end;
  finally
    CloseHandle(StdOutPipeRead);
  end;
end;

end.
