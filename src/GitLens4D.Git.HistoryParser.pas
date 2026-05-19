unit GitLens4D.Git.HistoryParser;

{ ============================================================================
  GitLens4D - Parser da saída do "git log -L"
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: receber o texto bruto do log de linha e construir
  uma TStringList formatada com o histórico de commits para exibição no IDE.

  ATENÇÃO: O caller é responsável por liberar o TStringList retornado.
  ============================================================================ }

interface

uses
  System.Classes,
  GitLens4D.Interfaces;

type
  THistoryParser = class(TInterfacedObject, IHistoryParser)
  public
    function Parse(const ARawOutput: string; ALine: Integer): TStringList;
  end;

implementation

uses
  System.SysUtils;

function THistoryParser.Parse(const ARawOutput: string; ALine: Integer): TStringList;
var
  Resultado  : TStringList;
  Linhas     : TStringList;
  StrAtual   : string;
  Hash       : string;
  Autor      : string;
  DataHora   : string;
  MsgLog     : string;
  Partes     : TArray<string>;
  CommitCount: Integer;
  InBlock    : Boolean;
  TextoArroba: string;
  LinhaAntiga: string;
  LinhaNova  : string;
  P1, P2     : Integer;
  I          : Integer;
begin
  Resultado := TStringList.Create;
  Resultado.Add(Format('=== SESSÃO DE HISTÓRICO: EVOLUÇÃO DA LINHA %d ===', [ALine]));

  if (ARawOutput = '') or (Pos('fatal:', LowerCase(ARawOutput)) > 0) then
  begin
    Resultado.Add('   Nenhum histórico encontrado para esta linha.');
    Result := Resultado;
    Exit;
  end;

  Linhas := TStringList.Create;
  try
    Linhas.Text := ARawOutput;
    CommitCount := 0;
    InBlock     := False;

    for I := 0 to Linhas.Count - 1 do
    begin
      StrAtual := Linhas[I];

      // ── Cabeçalho do commit (marcador #LOG#) ────────────────────────────
      if Copy(StrAtual, 1, 6) = '#LOG#|' then
      begin
        if InBlock then
          Resultado.Add('   └──────────────────────────────────────────────────────────────');

        Inc(CommitCount);
        if CommitCount > 10 then
          Break;

        Partes := StrAtual.Split(['|']);
        if Length(Partes) >= 5 then
        begin
          Hash     := Partes[1];
          Autor    := Partes[2];
          DataHora := Partes[3];
          MsgLog   := Partes[4];

          Resultado.Add('');
          Resultado.Add(Format('➔ [%s] por %s em %s', [Hash, Autor, DataHora]));
          Resultado.Add(Format('   💬 "%s"', [MsgLog]));
          Resultado.Add('   ┌──────────────────────────────────────────────────────────────');
          InBlock := True;
        end;
      end
      else if InBlock then
      begin
        // ── Linhas de metadados do diff: ignorar ────────────────────────
        if (Copy(StrAtual, 1, 4) = 'diff') or
          (Copy(StrAtual, 1, 5) = 'index') or
          (Copy(StrAtual, 1, 3) = '---') or
          (Copy(StrAtual, 1, 3) = '+++') then
          Continue;

        // ── Cabeçalho de hunk "@@ -X,Y +A,B @@": traduzir para humano ──
        if Copy(StrAtual, 1, 2) = '@@' then
        begin
          TextoArroba := Trim(StringReplace(StrAtual, '@@', '', [rfReplaceAll]));
          Partes      := TextoArroba.Split([' ']);

          if Length(Partes) >= 2 then
          begin
            LinhaAntiga := Partes[0];
            P1          := Pos(',', LinhaAntiga);
            if P1 > 0 then
              LinhaAntiga := Copy(LinhaAntiga, 2, P1 - 2)
            else
              LinhaAntiga := Copy(LinhaAntiga, 2, MaxInt);

            LinhaNova := Partes[1];
            P2        := Pos(',', LinhaNova);
            if P2 > 0 then
              LinhaNova := Copy(LinhaNova, 2, P2 - 2)
            else
              LinhaNova := Copy(LinhaNova, 2, MaxInt);

            Resultado.Add(Format(
              '   │ 📍 [ LINHA %s NO PASSADO ] ➔ EMPURRADA PARA A [ LINHA %s DESTE COMMIT ]',
              [LinhaAntiga, LinhaNova]));
            Resultado.Add('   │ ─────────────────────────────────────────────────────────────');
            Continue;
          end;
        end;

        // ── Linhas de conteúdo do diff (+, - ou contexto) ──────────────
        Resultado.Add('   │ ' + StrAtual);
      end;
    end;

    if InBlock then
      Resultado.Add('   └──────────────────────────────────────────────────────────────');

  finally
    Linhas.Free;
  end;

  Resultado.Add('');
  Resultado.Add('===================================================================');
  Result := Resultado;
end;

end.
