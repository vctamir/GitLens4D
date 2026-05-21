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
  LType, LEndpoint, LKey, LModel, LLang: string;
  LTemp                                : Double;
  LMaxTokens                           : Integer;
begin
  Result := False;
  if Assigned(FSettings) then
  begin
    FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LTemp, LMaxTokens);
    Result := LEndpoint.Trim <> '';
  end;
end;

function TAIService.NormalizeResponse(const AResponse: string): string;
var
  LRes: string;
begin
  // Limpeza de segurança e normalização de quebras de linha (LF -> CRLF)
  LRes := StringReplace(AResponse, '```', '', [rfReplaceAll]);
  LRes := StringReplace(LRes, '`', '', [rfReplaceAll]);
  
  // Converte LF ou CR isolados para CRLF (padrão Windows/TMemo)
  LRes := StringReplace(LRes, #13#10, #10, [rfReplaceAll]);
  LRes := StringReplace(LRes, #13, #10, [rfReplaceAll]);
  LRes := StringReplace(LRes, #10, sLineBreak, [rfReplaceAll]);
  
  Result := LRes.Trim;
end;

function TAIService.GenerateCommitMessage(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
var
  LType, LEndpoint, LKey, LModel, LLang: string;
  LTemp                                : Double;
  LMaxTokens                           : Integer;
  LSystem, LUser                       : string;
  LResponse                            : string;
begin
  Result := '';
  if not Assigned(FSettings) then
    Exit;

  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LTemp, LMaxTokens);

  if LEndpoint.Trim = '' then
  begin
    Result := 'Erro: Endpoint da IA não configurado.';
    Exit;
  end;

  LSystem := 'Você é uma ferramenta técnica de automação Git.' + sLineBreak +
    'PROJETO ATUAL: ' + AProjName + sLineBreak +
    'VERSÃO: ' + AProjVer + sLineBreak +
    'IDIOMA OBRIGATÓRIO: ' + LLang + sLineBreak +
    sLineBreak +
    'REGRAS DE OURO:' + sLineBreak +
    '1. Responda APENAS o texto do commit e o resumo técnico.' + sLineBreak +
    '2. PROIBIDO qualquer introdução, explicação ou Markdown de bloco (```).' + sLineBreak +
    '3. Substitua [tipo] por um dos seguintes: feat, fix, docs, refactor, style, test, perf, chore.'+
    'Exemplo de como você deve responder:' +
    '[FEAT]:[#' + ATaskNum + ' - ' + ATaskDesc + '] - Adicionado novo sistema de logs' + sLineBreak ;

  LUser := 'DADOS PARA GERAÇÃO:' + sLineBreak +
    '- Task Number: ' + ATaskNum + sLineBreak +
    '- Task Description: ' + ATaskDesc + sLineBreak +
    '- Diff: ' + ADiff + sLineBreak + sLineBreak +
    'ESTRUTURA OBRIGATÓRIA DA RESPOSTA:' + sLineBreak +
    '## [FEAT][#' + ATaskNum + ' - ' + ATaskDesc + '] - Resumo geral do commit' + sLineBreak +
    '### [VERSAO]' +AProjName +' v. '+ AProjVer + sLineBreak +
    sLineBreak +
    '### Detalhamento por arquivo' + sLineBreak +
    '* **nome_arquivo.pas**: breve descrição em ' + LLang + sLineBreak +
    sLineBreak +
    'Gere a resposta agora baseada nos DADOS PARA GERAÇÃO fornecidos:';

  try
    if SameText(LType, 'Local') and LEndpoint.Contains('11434') then
      LResponse := CallOllamaLegacy(LEndpoint, LModel, LSystem + sLineBreak + LUser, LTemp, LMaxTokens)
    else
      LResponse := CallChatAPI(LEndpoint, LKey, LModel, LSystem, LUser, LTemp, LMaxTokens);

    Result := NormalizeResponse(LResponse);
  except
    on E: Exception do
      Result := Format('Erro de Conexão: %s' + sLineBreak + 'URL: %s', [E.Message, LEndpoint]);
  end;
end;

function TAIService.GeneratePRDescription(const ATaskNum, ATaskDesc, ADiff, AProjName, AProjVer: string): string;
var
  LType, LEndpoint, LKey, LModel, LLang: string;
  LTemp                                : Double;
  LMaxTokens                           : Integer;
  LSystem, LUser                       : string;
  LResponse                            : string;
begin
  Result := '';
  if not Assigned(FSettings) then Exit;
  FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LTemp, LMaxTokens);

  LSystem := 'Você é um Engenheiro de Software Senior especializado em Pull Requests.' + sLineBreak +
    'IDIOMA: ' + LLang + sLineBreak +
    'OBJETIVO: Gerar uma descrição de PR profissional seguindo os padrões do GitHub.' + sLineBreak +
    'REGRAS:' + sLineBreak +
    '1. Use Markdown completo.' + sLineBreak +
    '2. Inclua uma seção de checklist com - [x] para o que foi feito e - [ ] para pendências.' + sLineBreak +
    '3. Seja técnico e conciso.' + sLineBreak +
    '4. NÃO use blocos de código (```) na resposta principal.';

  LUser := 'CONTEXTO DO PR:' + sLineBreak +
    '- Projeto: ' + AProjName + sLineBreak +
    '- Versão: ' + AProjVer + sLineBreak +
    '- Task: #' + ATaskNum + ' - ' + ATaskDesc + sLineBreak +
    '- Diff das mudanças: ' + ADiff + sLineBreak + sLineBreak +
    'ESTRUTURA SUGERIDA:' + sLineBreak +
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
