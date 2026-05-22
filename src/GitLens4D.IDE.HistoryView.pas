unit GitLens4D.IDE.HistoryView;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls,
  Vcl.ExtCtrls, ToolsAPI;

type
  TGitHistoryView = class(TForm)
    pnlBottom: TPanel;
    btnClose: TButton;
    lstHistory: TListView;
    procedure btnCloseClick(Sender: TObject);
  private
    procedure ApplyTheme;
  public
    constructor Create(AOwner: TComponent; const AFileName: string; ALine: Integer; AHistory: TStringList); reintroduce;
  end;

procedure ShowHistoryWindow(const AFileName: string; ALine: Integer; AHistory: TStringList);

implementation

{$R *.dfm}

procedure ShowHistoryWindow(const AFileName: string; ALine: Integer; AHistory: TStringList);
var
  LForm: TGitHistoryView;
begin
  LForm := TGitHistoryView.Create(nil, AFileName, ALine, AHistory);
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

constructor TGitHistoryView.Create(AOwner: TComponent; const AFileName: string; ALine: Integer; AHistory: TStringList);
var
  I: Integer;
  LItem: TListItem;
  LParts: TArray<string>;
begin
  inherited Create(AOwner);
  Caption := Format('History: %s (Line %d)', [ExtractFileName(AFileName), ALine]);
  ApplyTheme;

  lstHistory.Items.BeginUpdate;
  try
    lstHistory.Items.Clear;
    for I := 0 to AHistory.Count - 1 do
    begin
      // Formato esperado: #LOG#|hash|autor|data|mensagem
      if AHistory[I].StartsWith('#LOG#') then
      begin
        LParts := AHistory[I].Split(['|']);
        if Length(LParts) >= 5 then
        begin
          LItem := lstHistory.Items.Add;
          LItem.Caption := LParts[1]; // Hash
          LItem.SubItems.Add(LParts[2]); // Autor
          LItem.SubItems.Add(LParts[3]); // Data
          LItem.SubItems.Add(LParts[4]); // Mensagem
        end;
      end;
    end;
  finally
    lstHistory.Items.EndUpdate;
  end;
end;

procedure TGitHistoryView.ApplyTheme;
var
  LThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingSvc) then
    if LThemingSvc.IDEThemingEnabled then
      LThemingSvc.ApplyTheme(Self);
end;

procedure TGitHistoryView.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
