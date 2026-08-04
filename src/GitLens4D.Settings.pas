unit GitLens4D.Settings;

{ ============================================================================
  GitLens4D - Repositório de Configurações (Registro)
  Princípio: Interface Segregation (ISP) + Dependency Inversion (DIP)

  Esta unidade implementa a persistência das configurações do plugin
  no Registro do Windows (HKCU\Software\QSGitLens4D).
  ============================================================================ }

interface

uses
  System.Win.Registry,
  Winapi.Windows,
  System.SysUtils,
  GitLens4D.Interfaces;

type
  TGitLensSettings = class(TInterfacedObject, ISettingsRepository)
  private
    const
    REG_KEY = '\Software\QSGitLens4D';
    /// Chave onde ficam os dados de cada repositorio (um subkey por projeto).
    function ProjectKeyPath(const AProjectKey: string): string;
  public
    procedure Load(out AEnabledEditor, AEnabledDebug: Boolean);
    procedure Save(AEnabledEditor, AEnabledDebug: Boolean);
    procedure LoadTaskInfo(const AProjectKey: string; out ATaskNum, ATaskDesc: string);
    procedure SaveTaskInfo(const AProjectKey, ATaskNum, ATaskDesc: string);
    procedure LoadCommitDraft(const AProjectKey: string; out ADraft: string);
    procedure SaveCommitDraft(const AProjectKey, ADraft: string);
    procedure LoadSelectedFiles(const AProjectKey: string; out AFiles: string);
    procedure SaveSelectedFiles(const AProjectKey, AFiles: string);
    procedure LoadAIConfig(out AType, AEndpoint, AKey, AModel, ALang, AFormat: string; out ATemp: Double; out AMaxTokens: Integer);
    procedure SaveAIConfig(const AType, AEndpoint, AKey, AModel, ALang, AFormat: string; ATemp: Double; AMaxTokens: Integer);
    procedure LoadProjectFormat(const AProjectKey: string; out AFormat: string);
    procedure SaveProjectFormat(const AProjectKey, AFormat: string);
    procedure LoadGeneralConfig(out AShortcutHist, AShortcutChanges, ACommitTag: string);
    procedure SaveGeneralConfig(const AShortcutHist, AShortcutChanges, ACommitTag: string);
  end;

implementation

{ TGitLensSettings }

procedure TGitLensSettings.Load(out AEnabledEditor, AEnabledDebug: Boolean);
var
  Reg: TRegistry;
begin
  AEnabledEditor := True;
  AEnabledDebug  := False;
  Reg            := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, False) then
    begin
      if Reg.ValueExists('EnabledEditor') then
        AEnabledEditor := Reg.ReadBool('EnabledEditor');
      if Reg.ValueExists('EnabledDebug') then
        AEnabledDebug := Reg.ReadBool('EnabledDebug');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.Save(AEnabledEditor, AEnabledDebug: Boolean);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteBool('EnabledEditor', AEnabledEditor);
      Reg.WriteBool('EnabledDebug', AEnabledDebug);
    end;
  finally
    Reg.Free;
  end;
end;

function TGitLensSettings.ProjectKeyPath(const AProjectKey: string): string;
var
  LNome: string;
  I    : Integer;
begin
  // O nome de uma chave do registro nao aceita '\', e a chave do projeto e um
  // caminho (ex.: e:\tamir\gitlens4d). Troca os separadores por '_' para virar
  // um nome valido e ainda legivel no regedit.
  LNome := LowerCase(Trim(AProjectKey));
  for I := 1 to Length(LNome) do
    if CharInSet(LNome[I], ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
      LNome[I] := '_';

  if LNome = '' then
    LNome := 'default';

  Result := REG_KEY + '\Projects\' + LNome;
end;

procedure TGitLensSettings.LoadTaskInfo(const AProjectKey: string; out ATaskNum, ATaskDesc: string);
var
  Reg: TRegistry;
begin
  ATaskNum  := '';
  ATaskDesc := '';
  Reg       := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(ProjectKeyPath(AProjectKey), False) then
    begin
      if Reg.ValueExists('LastTaskNum') then
        ATaskNum := Reg.ReadString('LastTaskNum');
      if Reg.ValueExists('LastTaskDesc') then
        ATaskDesc := Reg.ReadString('LastTaskDesc');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveTaskInfo(const AProjectKey, ATaskNum, ATaskDesc: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(ProjectKeyPath(AProjectKey), True) then
    begin
      Reg.WriteString('LastTaskNum', ATaskNum);
      Reg.WriteString('LastTaskDesc', ATaskDesc);
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.LoadCommitDraft(const AProjectKey: string; out ADraft: string);
var
  Reg: TRegistry;
begin
  ADraft := '';
  Reg    := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(ProjectKeyPath(AProjectKey), False) then
    begin
      if Reg.ValueExists('CommitDraft') then
        ADraft := Reg.ReadString('CommitDraft');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveCommitDraft(const AProjectKey, ADraft: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(ProjectKeyPath(AProjectKey), True) then
      Reg.WriteString('CommitDraft', ADraft);
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.LoadSelectedFiles(const AProjectKey: string; out AFiles: string);
var
  Reg: TRegistry;
begin
  AFiles := '';
  Reg    := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(ProjectKeyPath(AProjectKey), False) then
    begin
      if Reg.ValueExists('SelectedFiles') then
        AFiles := Reg.ReadString('SelectedFiles');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveSelectedFiles(const AProjectKey, AFiles: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(ProjectKeyPath(AProjectKey), True) then
      Reg.WriteString('SelectedFiles', AFiles);
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.LoadAIConfig(out AType, AEndpoint, AKey, AModel, ALang, AFormat: string; out ATemp: Double; out AMaxTokens: Integer);
var
  Reg: TRegistry;
begin
  AType      := 'Ollama';
  AEndpoint  := 'http://localhost:11434/v1/chat/completions';
  AKey       := '';
  AModel     := 'codellama';
  ALang      := 'pt-BR';
  AFormat    := 'Markdown';
  ATemp      := 0.7;
  AMaxTokens := 2048;

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, False) then
    begin
      if Reg.ValueExists('AIType') then
        AType := Reg.ReadString('AIType');
      if Reg.ValueExists('AIEndpoint') then
        AEndpoint := Reg.ReadString('AIEndpoint');
      if Reg.ValueExists('AIKey') then
        AKey := Reg.ReadString('AIKey');
      if Reg.ValueExists('AIModel') then
        AModel := Reg.ReadString('AIModel');
      if Reg.ValueExists('AILang') then
        ALang := Reg.ReadString('AILang');
      if Reg.ValueExists('AIFormat') then
        AFormat := Reg.ReadString('AIFormat');
      if Reg.ValueExists('AITemp') then
        ATemp := Reg.ReadFloat('AITemp');
      if Reg.ValueExists('AIMaxTokens') then
        AMaxTokens := Reg.ReadInteger('AIMaxTokens');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveAIConfig(const AType, AEndpoint, AKey, AModel, ALang, AFormat: string; ATemp: Double; AMaxTokens: Integer);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteString('AIType', AType);
      Reg.WriteString('AIEndpoint', AEndpoint);
      Reg.WriteString('AIKey', AKey);
      Reg.WriteString('AIModel', AModel);
      Reg.WriteString('AILang', ALang);
      Reg.WriteString('AIFormat', AFormat);
      Reg.WriteFloat('AITemp', ATemp);
      Reg.WriteInteger('AIMaxTokens', AMaxTokens);
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.LoadProjectFormat(const AProjectKey: string; out AFormat: string);
var
  Reg: TRegistry;
begin
  AFormat := '';
  if AProjectKey.Trim = '' then
    Exit;

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY + '\ProjectFormats', False) then
    begin
      if Reg.ValueExists(AProjectKey) then
        AFormat := Reg.ReadString(AProjectKey);
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveProjectFormat(const AProjectKey, AFormat: string);
var
  Reg: TRegistry;
begin
  if AProjectKey.Trim = '' then
    Exit;

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY + '\ProjectFormats', True) then
      Reg.WriteString(AProjectKey, AFormat);
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.LoadGeneralConfig(out AShortcutHist, AShortcutChanges, ACommitTag: string);
var
  Reg: TRegistry;
begin
  AShortcutHist    := 'Ctrl+Shift+H';
  AShortcutChanges := 'Ctrl+Shift+Alt+G';
  ACommitTag       := '';

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, False) then
    begin
      if Reg.ValueExists('ShortcutHist') then
        AShortcutHist := Reg.ReadString('ShortcutHist');
      if Reg.ValueExists('ShortcutChanges') then
        AShortcutChanges := Reg.ReadString('ShortcutChanges');
      if Reg.ValueExists('CommitExtraTag') then
        ACommitTag := Reg.ReadString('CommitExtraTag');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveGeneralConfig(const AShortcutHist, AShortcutChanges, ACommitTag: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteString('ShortcutHist', AShortcutHist);
      Reg.WriteString('ShortcutChanges', AShortcutChanges);
      Reg.WriteString('CommitExtraTag', ACommitTag);
    end;
  finally
    Reg.Free;
  end;
end;

end.
