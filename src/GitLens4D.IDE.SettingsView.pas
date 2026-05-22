unit GitLens4D.IDE.SettingsView;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  GitLens4D.Interfaces, ToolsAPI;

type
  TGitSettingsView = class(TForm)
    pnlBottom: TPanel;
    btnSave: TButton;
    btnCancel: TButton;
    grpShortcuts: TGroupBox;
    lblHist: TLabel;
    lblChanges: TLabel;
    edtShortcutHist: TEdit;
    edtShortcutChanges: TEdit;
    grpCommit: TGroupBox;
    lblTag: TLabel;
    edtCommitTag: TEdit;
    lblTagHint: TLabel;
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FSettings: ISettingsRepository;
    procedure LoadConfigs;
    procedure ApplyTheme;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent; ASettings: ISettingsRepository); reintroduce;
  end;

procedure ShowGeneralSettings(ASettings: ISettingsRepository);

implementation

{$R *.dfm}

procedure ShowGeneralSettings(ASettings: ISettingsRepository);
var
  LForm: TGitSettingsView;
begin
  LForm := TGitSettingsView.Create(nil, ASettings);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

constructor TGitSettingsView.Create(AOwner: TComponent; ASettings: ISettingsRepository);
begin
  inherited Create(AOwner);
  FSettings := ASettings;
  LoadConfigs;
  Self.PopupMode := pmAuto;
end;

procedure TGitSettingsView.DoShow;
begin
  inherited;
  ApplyTheme;
end;

procedure TGitSettingsView.ApplyTheme;
var
  LThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingSvc) then
    if LThemingSvc.IDEThemingEnabled then
      LThemingSvc.ApplyTheme(Self);
end;

procedure TGitSettingsView.LoadConfigs;
var
  LHist, LChanges, LTag: string;
begin
  if Assigned(FSettings) then
  begin
    FSettings.LoadGeneralConfig(LHist, LChanges, LTag);
    edtShortcutHist.Text    := LHist;
    edtShortcutChanges.Text := LChanges;
    edtCommitTag.Text       := LTag;
  end;
end;

procedure TGitSettingsView.btnSaveClick(Sender: TObject);
begin
  if Assigned(FSettings) then
  begin
    FSettings.SaveGeneralConfig(
      edtShortcutHist.Text,
      edtShortcutChanges.Text,
      edtCommitTag.Text
    );
    ShowMessage(UTF8ToString('Configurações salvas! Reinicie o Delphi para aplicar os novos atalhos de teclado.'));
    ModalResult := mrOk;
  end;
end;

procedure TGitSettingsView.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
