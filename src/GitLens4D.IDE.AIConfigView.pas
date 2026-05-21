unit GitLens4D.IDE.AIConfigView;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  GitLens4D.Interfaces, ToolsAPI;

type
  TGitAIConfigView = class(TForm)
    pnlMain: TPanel;
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
    pnlBottom: TPanel;
    btnSave: TButton;
    btnCancel: TButton;
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FSettings: ISettingsRepository;
    procedure LoadConfigs;
    procedure ApplyTheme;
  public
    constructor Create(AOwner: TComponent; ASettings: ISettingsRepository); reintroduce;
  end;

procedure ShowAIConfig(ASettings: ISettingsRepository);

implementation

{$R *.dfm}

procedure ShowAIConfig(ASettings: ISettingsRepository);
var
  Frm: TGitAIConfigView;
begin
  Frm := TGitAIConfigView.Create(nil, ASettings);
  try
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

{ TGitAIConfigView }

constructor TGitAIConfigView.Create(AOwner: TComponent; ASettings: ISettingsRepository);
begin
  inherited Create(AOwner);
  FSettings := ASettings;
  LoadConfigs;
  ApplyTheme;
end;

procedure TGitAIConfigView.LoadConfigs;
var
  LType, LEndpoint, LKey, LModel, LLang: string;
  LTemp: Double;
  LMaxTokens: Integer;
begin
  if Assigned(FSettings) then
  begin
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

procedure TGitAIConfigView.ApplyTheme;
var
  ThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingSvc) then
    if ThemingSvc.IDEThemingEnabled then
      ThemingSvc.ApplyTheme(Self);
end;

procedure TGitAIConfigView.btnSaveClick(Sender: TObject);
var
  LType, LLang: string;
begin
  if Assigned(FSettings) then
  begin
    LType := 'Local';
    if cbType.ItemIndex <> -1 then LType := cbType.Items[cbType.ItemIndex];

    LLang := 'pt-BR';
    if cbLang.ItemIndex <> -1 then LLang := cbLang.Items[cbLang.ItemIndex];

    FSettings.SaveAIConfig(LType, edtEndpoint.Text, edtKey.Text, edtModel.Text, LLang,
      StrToFloatDef(edtTemp.Text, 0.7), StrToIntDef(edtMaxTokens.Text, 2048));
    ModalResult := mrOk;
  end;
end;

procedure TGitAIConfigView.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
