unit GitLens4D.Settings;

{ ============================================================================
  GitLens4D - Repositório de Configurações (Windows Registry)
  Princípio: Single Responsibility (SRP)

  Responsabilidade única: persistir e recuperar as preferências do usuário
  no Registro do Windows sob HKCU\Software\QSGitLens4D.
  ============================================================================ }

interface

uses
  GitLens4D.Interfaces;

type
  TGitLensSettings = class(TInterfacedObject, ISettingsRepository)
  private
    const
    REG_KEY = '\Software\QSGitLens4D';
  public
    procedure Load(out AEnabledEditor, AEnabledDebug: Boolean);
    procedure Save(AEnabledEditor, AEnabledDebug: Boolean);
  end;

implementation

uses
  Winapi.Windows,
  System.Win.Registry;

procedure TGitLensSettings.Load(out AEnabledEditor, AEnabledDebug: Boolean);
var
  Reg: TRegistry;
begin
  // Defaults
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
      Reg.CloseKey;
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
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

end.
