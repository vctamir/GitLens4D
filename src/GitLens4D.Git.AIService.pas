unit GitLens4D.Git.AIService;

{ ============================================================================
  GitLens4D - Serviço de Integração com IA
  Princípio: Single Responsibility (SRP)

  Responsabilidade: Enviar prompts para modelos de linguagem (locais ou remotos)
  e retornar sugestões de mensagens de commit baseadas no contexto.
  ============================================================================ }

interface

uses
  System.Classes,
  System.SysUtils,
  System.StrUtils, // ContainsText/EndsText, usados na rede de segurança do tipo
  System.Net.HttpClient,
  System.Net.URLClient,
  System.JSON,
  GitLens4D.Interfaces;

type
  TAIService = class(TInterfacedObject, IAIService)
  private
    FSettings: ISettingsRepository;
    function CallChatAPI(const AEndpoint, AKey, AModel, LSystem, LUser: string; ATemp: Double; AMaxTokens: Integer): string;
    function CallOllamaLegacy(const AEndpoint, AModel, APrompt: string; ATemp: Double; AMaxTokens: Integer): string;
    function NormalizeResponse(const AResponse: string): string;
    { Rede de segurança para o tipo do commit -- ver a implementação. }
    function InferTypeFromDiff(const ADiff: string): string;
    function EnforceCommitType(const AText, ADiff: string): string;
  public
    constructor Create(ASettings: ISettingsRepository);
    function GenerateCommitMessage(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
    function GeneratePRDescription(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
    function IsConfigured: Boolean;
  end;

implementation

{ TAIService }

constructor TAIService.Create(ASettings: ISettingsRepository);
begin
  inherited Create;
  FSettings := ASettings;
end;

function TAIService.IsConfigured: Boolean;
var
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
begin
  Result := False;
  if Assigned(FSettings) then
  begin
    FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);
    Result := LEndpoint.Trim <> '';
  end;
end;

{ ============================================================================
  Rede de segurança do tipo do commit

  Prompt não é contrato: por melhor que seja a instrução, um modelo pequeno
  ainda devolve o placeholder de vez em quando -- foi o que aconteceu, e o
  usuário via '[TIPO]:' no começo da mensagem. Aqui isso é consertado sem
  perguntar nada a ninguém: se o texto ainda tem placeholder, ele é trocado por
  um tipo deduzido do próprio Diff.

  A dedução é grosseira de propósito. Ela não tenta acertar sempre -- tenta
  garantir que o commit NUNCA saia com um placeholder no lugar do tipo, que é o
  único resultado inaceitável.
  ============================================================================ }
function TAIService.InferTypeFromDiff(const ADiff: string): string;
var
  LLines    : TArray<string>;
  LLine     : string;
  LPath     : string;
  LHasNew   : Boolean;
  LTouched  : Integer;
  LDocs     : Integer;
  LTests    : Integer;
begin
  LHasNew  := False;
  LTouched := 0;
  LDocs    := 0;
  LTests   := 0;

  LLines := ADiff.Split([sLineBreak, #10]);
  for LLine in LLines do
  begin
    if LLine.StartsWith('new file mode') then
      LHasNew := True;

    { '+++ b/caminho/arquivo.ext' é a linha que nomeia o arquivo destino. }
    if LLine.StartsWith('+++ b/') then
    begin
      LPath := LowerCase(Copy(LLine, Length('+++ b/') + 1, MaxInt)).Trim;
      if LPath = '' then
        Continue;
      Inc(LTouched);
      if EndsText('.md', LPath) or EndsText('.txt', LPath) or ContainsText(LPath, '/docs/') then
        Inc(LDocs);
      if ContainsText(LPath, 'test') or ContainsText(LPath, 'spec') then
        Inc(LTests);
    end;
  end;

  if (LTouched > 0) and (LDocs = LTouched) then
    Exit('DOCS');
  if (LTouched > 0) and (LTests = LTouched) then
    Exit('TEST');
  if LHasNew then
    Exit('FEAT');
  { Sem pista melhor: mudança em arquivo que já existia é, na dúvida, correção. }
  Result := 'FIX';
end;

{ Troca o placeholder pelo tipo deduzido, cobrindo as formas que já apareceram
  na prática: [TIPO], [TYPE], <TIPO> e o TIPO: solto. Se o modelo escreveu um
  tipo de verdade, nada aqui casa e o texto passa intacto.

  As formas com delimitador são trocadas em qualquer lugar do texto: '[TIPO]'
  não é português, é placeholder. Já o TIPO: sem colchetes só vale na PRIMEIRA
  linha, e só no começo dela -- 'corrige o tipo: integer' no meio do resumo é
  uma frase legítima, e trocar aquilo por 'corrige o FIX: integer' seria
  estragar a mensagem para consertar um problema que não existe ali. }
function TAIService.EnforceCommitType(const AText, ADiff: string): string;
var
  LType     : string;
  LBreak    : Integer;
  LFirst    : string;
  LRest     : string;
  LPrefixLen: Integer;
  LTrimmed  : string;
begin
  Result := AText;
  LType  := '';
  if Result.Trim = '' then
    Exit;

  { Formas com delimitador, em qualquer posição. }
  if ContainsText(Result, '[TIPO]') or ContainsText(Result, '<TIPO>') or
     ContainsText(Result, '[TYPE]') then
  begin
    LType  := InferTypeFromDiff(ADiff);
    Result := StringReplace(Result, '[TIPO]', LType, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '<TIPO>', LType, [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '[TYPE]', LType, [rfReplaceAll, rfIgnoreCase]);
  end;

  { TIPO: solto -- só no início da primeira linha, tolerando o '## ' do
    Markdown e espaços à esquerda. }
  LBreak := Pos(sLineBreak, Result);
  if LBreak > 0 then
  begin
    LFirst := Copy(Result, 1, LBreak - 1);
    LRest  := Copy(Result, LBreak, MaxInt);
  end
  else
  begin
    LFirst := Result;
    LRest  := '';
  end;

  LTrimmed   := TrimLeft(LFirst);
  LPrefixLen := Length(LFirst) - Length(LTrimmed);
  while StartsText('#', LTrimmed) do
  begin
    LTrimmed := Copy(LTrimmed, 2, MaxInt);
    Inc(LPrefixLen);
  end;
  while StartsText(' ', LTrimmed) do
  begin
    LTrimmed := Copy(LTrimmed, 2, MaxInt);
    Inc(LPrefixLen);
  end;

  if StartsText('TIPO:', LTrimmed) then
  begin
    if LType = '' then
      LType := InferTypeFromDiff(ADiff);
    Result := Copy(LFirst, 1, LPrefixLen) + LType +
      Copy(LTrimmed, Length('TIPO') + 1, MaxInt) + LRest;
  end;
end;

function TAIService.NormalizeResponse(const AResponse: string): string;
var
  LRes: string;
begin
  LRes   := StringReplace(AResponse, '```', '', [rfReplaceAll]);
  LRes   := StringReplace(LRes, '`', '', [rfReplaceAll]);
  LRes   := StringReplace(LRes, #13#10, #10, [rfReplaceAll]);
  LRes   := StringReplace(LRes, #13, #10, [rfReplaceAll]);
  LRes   := StringReplace(LRes, #10, sLineBreak, [rfReplaceAll]);
  Result := LRes.Trim;
end;

function TAIService.GenerateCommitMessage(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
var
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
  LSystem, LUser                                : string;
  LResponse                                     : string;
  LSHist, LSChanges, LExtraTag                  : string;
  LMarkdown                                     : Boolean;
  LFormatRule, LH2, LH3, LBullet                : string;
begin
  Result := '';
  if not Assigned(FSettings) then
    Exit;

  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);
  FSettings.LoadGeneralConfig(LSHist, LSChanges, LExtraTag);

  if LEndpoint.Trim = '' then
  begin
    Result := 'Erro: Endpoint da IA não configurado.';
    Exit;
  end;

  LMarkdown := not SameText(LFormat, 'Texto Puro');
  if LMarkdown then
  begin
    LFormatRule := '2. PROIBIDO qualquer introdução, explicação ou Markdown de bloco (```).';
    LH2         := '## ';
    LH3         := '### ';
    LBullet     := '* **nome_arquivo.pas**: ';
  end
  else
  begin
    LFormatRule := '2. PROIBIDO qualquer introdução ou explicação. PROIBIDO qualquer formatação Markdown (#, *, **, ```): a resposta deve ser TEXTO PURO.';
    LH2         := '';
    LH3         := '';
    LBullet     := '- nome_arquivo.pas: ';
  end;

  LSystem := 'Você é uma ferramenta técnica de automação Git.' + sLineBreak +
    'PROJETO ATUAL: ' + AProjName + sLineBreak +
    'VERSÃO: ' + AProjVer + sLineBreak +
    'IDIOMA OBRIGATÓRIO: ' + LLang + sLineBreak +
    sLineBreak +
    'REGRAS DE OURO (cumprimento obrigatório, sem exceção):' + sLineBreak +
    '1. Responda APENAS o texto do commit e o resumo técnico. Nenhum texto antes ou depois.' + sLineBreak +
    LFormatRule + sLineBreak +
    '3. A resposta COMEÇA pelo tipo da mudança, em maiúsculas, colado nos dois-pontos. Use EXATAMENTE um destes: FEAT, FIX, DOCS, REFACTOR, STYLE, TEST, PERF, CHORE. Escolha SOMENTE pelo conteúdo do Diff, nunca pela descrição da task.' + sLineBreak +
    '   NUNCA escreva a palavra TIPO, e NUNCA coloque colchetes em volta do tipo: escreva o tipo escolhido, como em FEAT: ou FIX:.' + sLineBreak +
    '4. O número da task e a descrição da task fornecidos em "DADOS PARA GERAÇÃO" são fixos: copie-os EXATAMENTE como estão. PROIBIDO inventar, alterar, traduzir, resumir ou trocar a ordem desses dois valores.';

  if LExtraTag <> '' then
    LSystem := LSystem + sLineBreak + '5. OBRIGATÓRIO: Inclua a tag ' + LExtraTag;

  LSystem := LSystem + sLineBreak + sLineBreak +
    'Exemplo de FORMATO (é apenas a estrutura; NUNCA copie estes valores de exemplo):' + sLineBreak;
  if LExtraTag <> '' then
    LSystem := LSystem + LExtraTag + sLineBreak;

  { O exemplo vem PREENCHIDO (FEAT) de propósito. Com um placeholder literal no
    lugar -- era '[TIPO]' --, modelos menores copiavam o placeholder para a
    resposta em vez de escolher um tipo, e a mensagem chegava ao usuário com
    '[TIPO]:' no começo. Um valor concreto não tem como ser copiado errado: se
    for copiado, ainda assim é um tipo válido. }
  LSystem := LSystem + LH2 + 'FEAT:[#000 - Descrição de exemplo da task] - Resumo geral do commit';

  LUser := 'DADOS PARA GERAÇÃO (use estes valores exatamente, não invente outros):' + sLineBreak +
    '- Task Number: ' + ATaskNum + sLineBreak +
    '- Task Description: ' + ATaskDesc + sLineBreak +
    '- Diff: ' + ADiff + sLineBreak + sLineBreak +
    'ESTRUTURA OBRIGATÓRIA DA RESPOSTA (comece pelo tipo escolhido no lugar de FEAT; mantenha #' + ATaskNum + ' - ' + ATaskDesc + ' EXATAMENTE como informado acima):' + sLineBreak;
  if LExtraTag <> '' then
    LUser := LUser + LExtraTag + sLineBreak;
  LUser   := LUser + LH2 + 'FEAT:[#' + ATaskNum + ' - ' + ATaskDesc + '] - Resumo geral do commit' + sLineBreak +
    LH3 + '[VERSAO] ' + AProjName + ' v. ' + AProjVer + sLineBreak +
    sLineBreak +
    LH3 + 'Detalhamento por arquivo' + sLineBreak +
    LBullet + 'breve descrição em ' + LLang + sLineBreak +
    sLineBreak +
    'Gere a resposta agora:';

  try
    if SameText(LType, 'Local') and LEndpoint.Contains('11434') then
      LResponse := CallOllamaLegacy(LEndpoint, LModel, LSystem + sLineBreak + LUser, LTemp, LMaxTokens)
    else
      LResponse := CallChatAPI(LEndpoint, LKey, LModel, LSystem, LUser, LTemp, LMaxTokens);

    Result := EnforceCommitType(NormalizeResponse(LResponse), ADiff);
  except
    on E: Exception do
      Result := Format('Erro de Conexão: %s', [E.Message]);
  end;
end;

function TAIService.GeneratePRDescription(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
var
  LType, LEndpoint, LKey, LModel, LLang, LFormat: string;
  LTemp                                         : Double;
  LMaxTokens                                    : Integer;
  LSystem, LUser                                : string;
  LResponse                                     : string;
  LMarkdown                                     : Boolean;
begin
  Result := '';
  if not Assigned(FSettings) then
    Exit;
  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LFormat, LTemp, LMaxTokens);

  LMarkdown := not SameText(LFormat, 'Texto Puro');

  LSystem := 'Você é um Engenheiro de Software Senior especializado em Pull Requests.' + sLineBreak +
    'IDIOMA: ' + LLang + sLineBreak +
    'OBJETIVO: Gerar uma descrição de PR profissional seguindo os padrões do GitHub.' + sLineBreak +
    'REGRAS:' + sLineBreak;

  if LMarkdown then
    LSystem := LSystem +
      '1. Use Markdown completo.' + sLineBreak +
      '2. Inclua uma seção de checklist com - [x] para o que foi feito e - [ ] para pendências.' + sLineBreak +
      '3. Seja técnico e conciso.' + sLineBreak +
      '4. NÃO use blocos de código (```) na resposta principal.'
  else
    LSystem := LSystem +
      '1. PROIBIDO usar qualquer formatação Markdown (#, *, **, ```): a resposta deve ser TEXTO PURO.' + sLineBreak +
      '2. Inclua uma seção de checklist com [x] para o que foi feito e [ ] para pendências.' + sLineBreak +
      '3. Seja técnico e conciso.';

  LUser := 'CONTEXTO DO PR:' + sLineBreak +
    '- Projeto: ' + AProjName + sLineBreak +
    '- Versão: ' + AProjVer + sLineBreak +
    '- Task: #' + ATaskNum + ' - ' + ATaskDesc + sLineBreak +
    '- Diff das mudanças: ' + ADiff + sLineBreak + sLineBreak +
    'ESTRUTURA SUGERIDA:' + sLineBreak;

  if LMarkdown then
    LUser := LUser +
      '# PR: [Título Sugerido]' + sLineBreak +
      '## 📝 Descrição' + sLineBreak +
      '[Breve resumo do que este PR resolve]' + sLineBreak +
      '## 🛠 Alterações Realizadas' + sLineBreak +
      '[Lista de mudanças técnicas]' + sLineBreak +
      '## ✅ Checklist' + sLineBreak +
      '- [x] Implementação concluída' + sLineBreak +
      '- [x] Testes realizados' + sLineBreak +
      '- [ ] Documentação atualizada' + sLineBreak +
      sLineBreak +
      'Gere a descrição do PR agora:'
  else
    LUser := LUser +
      'PR: [Título Sugerido]' + sLineBreak +
      'DESCRIÇÃO' + sLineBreak +
      '[Breve resumo do que este PR resolve]' + sLineBreak +
      'ALTERAÇÕES REALIZADAS' + sLineBreak +
      '[Lista de mudanças técnicas]' + sLineBreak +
      'CHECKLIST' + sLineBreak +
      '[x] Implementação concluída' + sLineBreak +
      '[x] Testes realizados' + sLineBreak +
      '[ ] Documentação atualizada' + sLineBreak +
      sLineBreak +
      'Gere a descrição do PR agora:';

  try
    if SameText(LType, 'Local') and LEndpoint.Contains('11434') then
      LResponse := CallOllamaLegacy(LEndpoint, LModel, LSystem + sLineBreak + LUser, LTemp, LMaxTokens)
    else
      LResponse := CallChatAPI(LEndpoint, LKey, LModel, LSystem, LUser, LTemp, LMaxTokens);

    Result := NormalizeResponse(LResponse);
  except
    on E: Exception do
      Result := 'Erro ao gerar PR: ' + E.Message;
  end;
end;

function TAIService.CallChatAPI(const AEndpoint, AKey, AModel, LSystem, LUser: string; ATemp: Double; AMaxTokens: Integer): string;
var
  Client                  : THTTPClient;
  Response                : IHTTPResponse;
  JSON, MsgSystem, MsgUser: TJSONObject;
  Messages                : TJSONArray;
  Body                    : TStringStream;
  FinalURL                : string;
begin
  Result := '';
  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout := 5000;
    Client.ResponseTimeout   := 60000;

    if AKey.Trim <> '' then
      Client.CustomHeaders['Authorization'] := 'Bearer ' + AKey;
    Client.CustomHeaders['Content-Type']    := 'application/json';

    JSON := TJSONObject.Create;
    try
      JSON.AddPair('model', AModel);
      JSON.AddPair('temperature', TJSONNumber.Create(ATemp));
      JSON.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens));

      Messages := TJSONArray.Create;

      MsgSystem := TJSONObject.Create;
      MsgSystem.AddPair('role', 'system');
      MsgSystem.AddPair('content', LSystem);
      Messages.Add(MsgSystem);

      MsgUser := TJSONObject.Create;
      MsgUser.AddPair('role', 'user');
      MsgUser.AddPair('content', LUser);
      Messages.Add(MsgUser);

      JSON.AddPair('messages', Messages);

      Body := TStringStream.Create(JSON.ToJSON, TEncoding.UTF8);
      try
        FinalURL := AEndpoint.Trim;
        if FinalURL.Contains('api.openai.com') then
          FinalURL := FinalURL.Trim(['/']) + '/v1/chat/completions';

        Response := Client.Post(FinalURL, Body);
        if Response.StatusCode = 200 then
        begin
          JSON.Free;
          JSON := TJSONObject.ParseJSONValue(Response.ContentAsString()) as TJSONObject;
          if Assigned(JSON) then
            Result := (((JSON.GetValue('choices') as TJSONArray).Items[0] as TJSONObject)
              .GetValue('message') as TJSONObject).GetValue('content').Value.Trim;
        end
        else
          Result := Format('Erro HTTP %d: %s', [Response.StatusCode, Response.StatusText]);
      finally
        Body.Free;
      end;
    finally
      JSON.Free;
    end;
  finally
    Client.Free;
  end;
end;

function TAIService.CallOllamaLegacy(const AEndpoint, AModel, APrompt: string; ATemp: Double; AMaxTokens: Integer): string;
var
  Client       : THTTPClient;
  Response     : IHTTPResponse;
  JSON, Options: TJSONObject;
  Body         : TStringStream;
begin
  Result := '';
  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout             := 5000;
    Client.ResponseTimeout               := 60000;
    Client.CustomHeaders['Content-Type'] := 'application/json';

    JSON := TJSONObject.Create;
    try
      JSON.AddPair('model', AModel);
      JSON.AddPair('prompt', APrompt);
      JSON.AddPair('stream', TJSONBool.Create(False));

      Options := TJSONObject.Create;
      Options.AddPair('temperature', TJSONNumber.Create(ATemp));
      Options.AddPair('num_predict', TJSONNumber.Create(AMaxTokens));
      JSON.AddPair('options', Options);

      Body := TStringStream.Create(JSON.ToJSON, TEncoding.UTF8);
      try
        Response := Client.Post(AEndpoint.Trim(['/']) + '/api/generate', Body);
        if Response.StatusCode = 200 then
        begin
          JSON.Free;
          JSON := TJSONObject.ParseJSONValue(Response.ContentAsString()) as TJSONObject;
          if Assigned(JSON) then
            Result := JSON.GetValue('response').Value.Trim;
        end;
      finally
        Body.Free;
      end;
    finally
      JSON.Free;
    end;
  finally
    Client.Free;
  end;
end;

end.
