unit GitLens4D.Git.HistoryParser;

{ ============================================================================
  GitLens4D - Parser da saída do "git log -L"
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: receber o texto bruto do log de linha e construir
  um array estruturado de registros TGitHistoryEntry.
  ============================================================================ }

interface

uses
  System.Classes,
  GitLens4D.Interfaces;

type
  THistoryParser = class(TInterfacedObject, IHistoryParser)
  public
    function Parse(const ARawOutput: string; ALine: Integer): TGitHistoryArray;
  end;

implementation

uses
  System.SysUtils;

function THistoryParser.Parse(const ARawOutput: string; ALine: Integer): TGitHistoryArray;
var
  Linhas     : TStringList;
  StrAtual   : string;
  CommitIdx  : Integer;
  Partes     : TArray<string>;
  I          : Integer;
  LCurrentPatch: TStringList;
begin
  SetLength(Result, 0);
  if (ARawOutput = '') or (Pos('fatal:', LowerCase(ARawOutput)) > 0) then
    Exit;

  Linhas := TStringList.Create;
  LCurrentPatch := TStringList.Create;
  try
    Linhas.Text := ARawOutput;
    CommitIdx := -1;

    for I := 0 to Linhas.Count - 1 do
    begin
      StrAtual := Linhas[I];

      // ── Cabeçalho do commit (marcador #LOG#) ────────────────────────────
      if StrAtual.StartsWith('#LOG#|') then
      begin
        // Salva o patch do commit anterior se houver
        if (CommitIdx >= 0) then
          Result[CommitIdx].Patch := LCurrentPatch.Text;

        LCurrentPatch.Clear;
        
        Partes := StrAtual.Split(['|']);
        if Length(Partes) >= 5 then
        begin
          SetLength(Result, Length(Result) + 1);
          CommitIdx := High(Result);
          Result[CommitIdx].Hash     := Partes[1];
          Result[CommitIdx].Author    := Partes[2];
          Result[CommitIdx].Date      := Partes[3];
          Result[CommitIdx].Message   := Partes[4];
          Result[CommitIdx].Patch     := '';
        end;
      end
      else if CommitIdx >= 0 then
      begin
        // Ignora linhas inúteis do diff
        if (StrAtual.StartsWith('diff')) or (StrAtual.StartsWith('index')) or
           (StrAtual.StartsWith('---')) or (StrAtual.StartsWith('+++')) then
          Continue;

        LCurrentPatch.Add(StrAtual);
      end;
    end;

    // Salva o último patch
    if (CommitIdx >= 0) then
      Result[CommitIdx].Patch := LCurrentPatch.Text;

  finally
    Linhas.Free;
    LCurrentPatch.Free;
  end;
end;

end.
