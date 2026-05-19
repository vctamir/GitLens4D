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
  GitLens4D.Interfaces;

type
  TGitRunner = class(TInterfacedObject, IGitRunner)
  public
    function Execute(const ACommand, ABaseDir: string): string;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils;

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
