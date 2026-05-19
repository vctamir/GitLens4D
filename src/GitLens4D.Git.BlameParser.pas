unit GitLens4D.Git.BlameParser;

{ ============================================================================
  GitLens4D - Parser da saída do "git blame -p"
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: receber o texto bruto do blame porcelain e
  extrair as informações de autoria, data e mensagem de commit, retornando
  uma string formatada para exibição na aba do IDE.
  ============================================================================ }

interface

uses
  GitLens4D.Interfaces;

type
  TBlameParser = class(TInterfacedObject, IBlameParser)
  public
    function Parse(const ARawOutput: string; ALine: Integer): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils;

function TBlameParser.Parse(const ARawOutput: string; ALine: Integer): string;
var
  Linhas    : TStringList;
  LinhaAtual: string;
  Autor     : string;
  Resumo    : string;
  Timestamp : Int64;
  DataCommit: TDateTime;
  I         : Integer;
begin
  // ── Tratamento dos casos de erro antes de parsear ────────────────────────
  if ARawOutput = '' then
  begin
    Result := Format('Linha %d: Sem retorno do Git (arquivo não versionado?)', [ALine]);
    Exit;
  end;

  if Pos('fatal: not a git repository', LowerCase(ARawOutput)) > 0 then
  begin
    Result := Format('Linha %d: Fora do repositório Git', [ALine]);
    Exit;
  end;

  if Pos('não é reconhecido', LowerCase(ARawOutput)) > 0 then
  begin
    Result := Format('Linha %d: Git não encontrado no sistema', [ALine]);
    Exit;
  end;

  // ── Extração dos campos do formato porcelain ─────────────────────────────
  Autor     := '';
  Resumo    := '';
  Timestamp := 0;

  Linhas := TStringList.Create;
  try
    Linhas.Text := ARawOutput;
    for I       := 0 to Linhas.Count - 1 do
    begin
      LinhaAtual := Linhas[I];

      if Copy(LinhaAtual, 1, 7) = 'author ' then
        Autor := Copy(LinhaAtual, 8, MaxInt)
      else if Copy(LinhaAtual, 1, 12) = 'author-time ' then
        Timestamp := StrToInt64Def(Copy(LinhaAtual, 13, MaxInt), 0)
      else if Copy(LinhaAtual, 1, 8) = 'summary ' then
        Resumo := Copy(LinhaAtual, 9, MaxInt);
    end;
  finally
    Linhas.Free;
  end;

  // ── Formatação do resultado ───────────────────────────────────────────────
  if Autor = 'Not Committed Yet' then
    Result := Format('Linha %d: Alteração local não commitada', [ALine])
  else if Autor = '' then
    Result := Format('Linha %d: Retorno inesperado: %s', [ALine, Copy(ARawOutput, 1, 150)])
  else
  begin
    DataCommit := UnixToDateTime(Timestamp, False);
    Result     := Format('Linha %d: %s - %s às %s - %s',
      [ALine,
      Autor,
      FormatDateTime('dd/MM/yyyy', DataCommit),
      FormatDateTime('HH:mm:ss', DataCommit),
      Resumo]);
  end;
end;

end.
