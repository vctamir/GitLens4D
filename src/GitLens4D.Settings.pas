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
    const REG_KEY = '\Software\QSGitLens4D';
  public
    procedure Load(out AEnabledEditor, AEnabledDebug: Boolean);
    procedure Save(AEnabledEditor, AEnabledDebug: Boolean);
    procedure LoadTaskInfo(out ATaskNum, ATaskDesc: string);
    procedure SaveTaskInfo(const ATaskNum, ATaskDesc: string);
    procedure LoadCommitDraft(out ADraft: string);
    procedure SaveCommitDraft(const ADraft: string);
    procedure LoadAIConfig(out AType, AEndpoint, AKey, AModel, ALang: string; out ATemp: Double; out AMaxTokens: Integer);
    procedure SaveAIConfig(const AType, AEndpoint, AKey, AModel, ALang: string; ATemp: Double; AMaxTokens: Integer);
  end;

implementation

{ TGitLensSettings }

procedure TGitLensSettings.Load(out AEnabledEditor, AEnabledDebug: Boolean);
var
  Reg: TRegistry;
begin
  AEnabledEditor := True;
  AEnabledDebug  := False;
  Reg := TRegistry.Create;
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

procedure TGitLensSettings.LoadTaskInfo(out ATaskNum, ATaskDesc: string);
var
  Reg: TRegistry;
begin
  ATaskNum  := '';
  ATaskDesc := '';
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, False) then
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

procedure TGitLensSettings.SaveTaskInfo(const ATaskNum, ATaskDesc: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteString('LastTaskNum', ATaskNum);
      Reg.WriteString('LastTaskDesc', ATaskDesc);
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.LoadCommitDraft(out ADraft: string);
var
  Reg: TRegistry;
begin
  ADraft := '';
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, False) then
    begin
      if Reg.ValueExists('CommitDraft') then
        ADraft := Reg.ReadString('CommitDraft');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveCommitDraft(const ADraft: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, True) then
      Reg.WriteString('CommitDraft', ADraft);
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.LoadAIConfig(out AType, AEndpoint, AKey, AModel, ALang: string; out ATemp: Double; out AMaxTokens: Integer);
var
  Reg: TRegistry;
begin
  AType      := 'Ollama';
  AEndpoint  := 'http://localhost:11434/v1/chat/completions';
  AKey       := '';
  AModel     := 'codellama';
  ALang      := 'pt-BR';
  ATemp      := 0.7;
  AMaxTokens := 2048;

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, False) then
    begin
      if Reg.ValueExists('AIType') then AType := Reg.ReadString('AIType');
      if Reg.ValueExists('AIEndpoint') then AEndpoint := Reg.ReadString('AIEndpoint');
      if Reg.ValueExists('AIKey') then AKey := Reg.ReadString('AIKey');
      if Reg.ValueExists('AIModel') then AModel := Reg.ReadString('AIModel');
      if Reg.ValueExists('AILang') then ALang := Reg.ReadString('AILang');
      if Reg.ValueExists('AITemp') then ATemp := Reg.ReadFloat('AITemp');
      if Reg.ValueExists('AIMaxTokens') then AMaxTokens := Reg.ReadInteger('AIMaxTokens');
    end;
  finally
    Reg.Free;
  end;
end;

procedure TGitLensSettings.SaveAIConfig(const AType, AEndpoint, AKey, AModel, ALang: string; ATemp: Double; AMaxTokens: Integer);
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
      Reg.WriteFloat('AITemp', ATemp);
      Reg.WriteInteger('AIMaxTokens', AMaxTokens);
    end;
  finally
    Reg.Free;
  end;
end;

end.
