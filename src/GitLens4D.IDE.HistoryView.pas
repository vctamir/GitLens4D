unit GitLens4D.IDE.HistoryView;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.RichEdit,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  GitLens4D.Interfaces,
  ToolsAPI;

type
  TGitHistoryView = class(TForm)
    pnlBottom: TPanel;
    btnClose: TButton;
    lstHistory: TListView;
    redPatch: TRichEdit;
    Splitter1: TSplitter;
    procedure btnCloseClick(Sender: TObject);
    procedure lstHistorySelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    FHistory: TGitHistoryArray;
    procedure ApplyTheme;
    procedure AddColoredLine(const AText: string; AColor: TColor);
  public
    constructor Create(AOwner: TComponent; const AFileName: string; ALine: Integer; AHistory: TGitHistoryArray); reintroduce;
  end;

procedure ShowHistoryWindow(const AFileName: string; ALine: Integer; AHistory: TGitHistoryArray);

implementation

{$R *.dfm}


procedure ShowHistoryWindow(const AFileName: string; ALine: Integer; AHistory: TGitHistoryArray);
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

constructor TGitHistoryView.Create(AOwner: TComponent; const AFileName: string; ALine: Integer; AHistory: TGitHistoryArray);
var
  I    : Integer;
  LItem: TListItem;
begin
  inherited Create(AOwner);
  FHistory := AHistory;
  Caption  := Format('Line Evolution: %s (Line %d)', [ExtractFileName(AFileName), ALine]);
  ApplyTheme;

  lstHistory.Items.BeginUpdate;
  try
    lstHistory.Items.Clear;
    for I := 0 to High(FHistory) do
    begin
      LItem         := lstHistory.Items.Add;
      LItem.Caption := FHistory[I].Hash;
      LItem.SubItems.Add(FHistory[I].Author);
      LItem.SubItems.Add(FHistory[I].Date);
      LItem.SubItems.Add(FHistory[I].Message);
      LItem.Data := Pointer(I); // Guarda o índice original
    end;
  finally
    lstHistory.Items.EndUpdate;
  end;

  if lstHistory.Items.Count > 0 then
    lstHistory.ItemIndex := 0;
end;

procedure TGitHistoryView.lstHistorySelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  LIdx  : Integer;
  LPatch: string;
  Lines : TStringList;
  I     : Integer;
  Line  : string;
begin
  if not Selected then
    Exit;

  LIdx   := Integer(Item.Data);
  LPatch := FHistory[LIdx].Patch;

  redPatch.Lines.BeginUpdate;
  try
    redPatch.Clear;
    Lines := TStringList.Create;
    try
      Lines.Text := LPatch;
      for I      := 0 to Lines.Count - 1 do
      begin
        Line := Lines[I];
        if Line.StartsWith('+') then
          AddColoredLine(Line, $00D0FFD0)
        else if Line.StartsWith('-') then
          AddColoredLine(Line, $00D0D0FF)
        else if Line.StartsWith('@@') then
          AddColoredLine(Line, $00FFFFE0)
        else
          AddColoredLine(Line, clWindowText);
      end;
    finally
      Lines.Free;
    end;
  finally
    redPatch.Lines.EndUpdate;
  end;
end;

procedure TGitHistoryView.AddColoredLine(const AText: string; AColor: TColor);
var
  Format: TCharFormat2;
begin
  redPatch.SelStart            := Length(redPatch.Text);
  redPatch.SelAttributes.Color := clBlack;
  redPatch.Lines.Add(AText);

  if AColor <> clWindowText then
  begin
    redPatch.SelStart  := Length(redPatch.Text) - Length(AText) - 2;
    redPatch.SelLength := Length(AText) + 1;

    FillChar(Format, SizeOf(Format), 0);
    Format.cbSize      := SizeOf(Format);
    Format.dwMask      := CFM_BACKCOLOR;
    Format.crBackColor := ColorToRGB(AColor);

    SendMessage(redPatch.Handle, EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@Format));
  end;

  redPatch.SelStart  := Length(redPatch.Text);
  redPatch.SelLength := 0;
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
