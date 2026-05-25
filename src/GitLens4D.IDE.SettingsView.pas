unit GitLens4D.IDE.SettingsView;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, GitLens4D.Interfaces, ToolsAPI;

type
  TGitSettingsView = class(TForm)
    pnlBottom: TPanel;
    btnSave: TButton;
    btnCancel: TButton;
    pcSettings: TPageControl;
    tsGeneral: TTabSheet;
    tsAI: TTabSheet;
    grpShortcuts: TGroupBox;
    lblHist: TLabel;
    lblChanges: TLabel;
    edtShortcutHist: TEdit;
    edtShortcutChanges: TEdit;
    grpCommit: TGroupBox;
    lblTag: TLabel;
    edtCommitTag: TEdit;
    lblTagHint: TLabel;
    lblType: TLabel;
    cbType: TComboBox;
    lblEndpoint: TLabel;
    edtEndpoint: TEdit;
    lblKey: TLabel;
    edtKey: TEdit;
    lblModel: TLabel;
    edtModel: TEdit;
    lblTemp: TLabel;
    edtTemp: TEdit;
    lblMaxTokens: TLabel;
    edtMaxTokens: TEdit;
    lblLang: TLabel;
    cbLang: TComboBox;
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

procedure ShowSettings(ASettings: ISettingsRepository; ADefaultAI: Boolean = False);

implementation

{$R *.dfm}

procedure ShowSettings(ASettings: ISettingsRepository; ADefaultAI: Boolean = False);
var
  LForm: TGitSettingsView;
begin
  LForm := TGitSettingsView.Create(nil, ASettings);
  try
    if ADefaultAI then
      LForm.pcSettings.ActivePage := LForm.tsAI
    else
      LForm.pcSettings.ActivePage := LForm.tsGeneral;

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
  LType, LEndpoint, LKey, LModel, LLang: string;
  LTemp: Double;
  LMaxTokens: Integer;
begin
  if Assigned(FSettings) then
  begin
    // Geral
    FSettings.LoadGeneralConfig(LHist, LChanges, LTag);
    edtShortcutHist.Text    := LHist;
    edtShortcutChanges.Text := LChanges;
    edtCommitTag.Text       := LTag;

    // IA
    FSettings.LoadAIConfig(LType, LEndpoint, LKey, LModel, LLang, LTemp, LMaxTokens);
    cbType.ItemIndex := cbType.Items.IndexOf(LType);
    if cbType.ItemIndex = -1 then cbType.ItemIndex := 0;

    cbLang.ItemIndex := cbLang.Items.IndexOf(LLang);
    if cbLang.ItemIndex = -1 then cbLang.ItemIndex := 0;

    edtEndpoint.Text := LEndpoint;
    edtKey.Text := LKey;
    edtModel.Text := LModel;
    edtTemp.Text := FloatToStr(LTemp);
    edtMaxTokens.Text := IntToStr(LMaxTokens);
  end;
end;

procedure TGitSettingsView.btnSaveClick(Sender: TObject);
var
  LType, LLang: string;
begin
  if Assigned(FSettings) then
  begin
    // Salvar Geral
    FSettings.SaveGeneralConfig(
      edtShortcutHist.Text,
      edtShortcutChanges.Text,
      edtCommitTag.Text
    );

    // Salvar IA
    LType := 'Local';
    if cbType.ItemIndex <> -1 then LType := cbType.Items[cbType.ItemIndex];

    LLang := 'pt-BR';
    if cbLang.ItemIndex <> -1 then LLang := cbLang.Items[cbLang.ItemIndex];

    FSettings.SaveAIConfig(LType, edtEndpoint.Text, edtKey.Text, edtModel.Text, LLang,
      StrToFloatDef(edtTemp.Text, 0.7), StrToIntDef(edtMaxTokens.Text, 2048));

    ShowMessage(UTF8ToString('Configurações salvas! Reinicie o Delphi para aplicar os novos atalhos de teclado.'));
    ModalResult := mrOk;
  end;
end;

procedure TGitSettingsView.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
