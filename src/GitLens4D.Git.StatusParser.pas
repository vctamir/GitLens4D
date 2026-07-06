unit GitLens4D.Git.StatusParser;

{ ============================================================================
  GitLens4D - Parser para "git status --porcelain"
  Princípio: Single Responsibility (SRP)

  Responsabilidade: Converter a saída tabular e compacta do Git Status
  em um array de registros tipados (TGitFileStatusArray).
  ============================================================================ }

interface

uses
  GitLens4D.Interfaces;

type
  TStatusParser = class(TInterfacedObject, IStatusParser)
  public
    function Parse(const ARawOutput: string): TGitFileStatusArray;
  end;

implementation

uses
  System.Classes,
  System.SysUtils;

{ TStatusParser }

function TStatusParser.Parse(const ARawOutput: string): TGitFileStatusArray;
var
  Lines           : TStringList;
  I               : Integer;
  Line            : string;
  StatusX, StatusY: Char;
  FileName        : string;
begin
  SetLength(Result, 0);
  if ARawOutput.Trim = '' then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := ARawOutput;
    for I      := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if Line.Length < 4 then
        Continue;

      StatusX  := Line[1]; // Index status
      StatusY  := Line[2]; // Worktree status
      FileName := Copy(Line, 4, MaxInt);

      // Simplificação para este exemplo: Prioriza Worktree se ambos existirem,
      // ou marca como Staged se estiver apenas no Index.

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].FileName := FileName;
      Result[High(Result)].Staged   := (StatusX <> ' ') and (StatusX <> '?');

      case StatusY of
        'M': Result[High(Result)].Status := skModified;
        'D': Result[High(Result)].Status := skDeleted;
        'A': Result[High(Result)].Status := skAdded;
        '?': Result[High(Result)].Status := skUntracked;
      else
        case StatusX of
          'M': Result[High(Result)].Status := skModified;
          'A': Result[High(Result)].Status := skAdded;
          'D': Result[High(Result)].Status := skDeleted;
          'R': Result[High(Result)].Status := skRenamed;
        else
            Result[High(Result)].Status := skUnknown;
        end;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

end.
