unit GitLens4D.IDE.DiffView;

{ ============================================================================
  GitLens4D - Visualizador de Diferenças (Diff)
  Princípio: Single Responsibility (SRP)

  Responsabilidade: Exibir o Diff do arquivo com cores (Verde/Vermelho)
  seguindo o estilo clássico do Git.
  ============================================================================ }

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.RichEdit, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.ExtCtrls, ToolsAPI;

type
  TGitDiffView = class(TForm)
    redDiff: TRichEdit;
    pnlBottom: TPanel;
    btnClose: TButton;
    procedure btnCloseClick(Sender: TObject);
  private
    procedure ApplyTheme;
    procedure AddColoredLine(const AText: string; AColor: TColor);
  public
    constructor Create(AOwner: TComponent; const AFileName, ADiffText: string); reintroduce;
  end;

procedure ShowDiff(const AFileName, ADiffText: string);

implementation

{$R *.dfm}

procedure ShowDiff(const AFileName, ADiffText: string);
var
  Frm: TGitDiffView;
begin
  Frm := TGitDiffView.Create(nil, AFileName, ADiffText);
  try
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

{ TGitDiffView }

constructor TGitDiffView.Create(AOwner: TComponent; const AFileName, ADiffText: string);
var
  Lines: TStringList;
  I: Integer;
  Line: string;
begin
  inherited Create(AOwner);
  Caption := 'Diff: ' + AFileName;
  ApplyTheme;

  Lines := TStringList.Create;
  try
    Lines.Text := ADiffText;
    redDiff.Lines.BeginUpdate;
    try
      redDiff.Clear;
      for I := 0 to Lines.Count - 1 do
      begin
        Line := Lines[I];
        if Line.StartsWith('+') and not Line.StartsWith('+++') then
          AddColoredLine(Line, $00D0FFD0) // Verde claro
        else if Line.StartsWith('-') and not Line.StartsWith('---') then
          AddColoredLine(Line, $00D0D0FF) // Vermelho claro
        else if Line.StartsWith('@@') then
          AddColoredLine(Line, $00FFFFE0) // Ciano/Azul claro
        else
          AddColoredLine(Line, clWindowText);
      end;
    finally
      redDiff.Lines.EndUpdate;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TGitDiffView.AddColoredLine(const AText: string; AColor: TColor);
var
  Format: TCharFormat2;
begin
  redDiff.SelStart := Length(redDiff.Text);
  redDiff.SelAttributes.Color := clBlack;
  redDiff.Lines.Add(AText);
  
  if AColor <> clWindowText then
  begin
    redDiff.SelStart := Length(redDiff.Text) - Length(AText) - 2;
    redDiff.SelLength := Length(AText) + 1;
    
    FillChar(Format, SizeOf(Format), 0);
    Format.cbSize := SizeOf(Format);
    Format.dwMask := CFM_BACKCOLOR;
    Format.crBackColor := ColorToRGB(AColor);
    
    SendMessage(redDiff.Handle, EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@Format));
    redDiff.SelAttributes.Style := [fsBold];
  end;
  
  redDiff.SelStart := Length(redDiff.Text);
  redDiff.SelLength := 0;
end;

procedure TGitDiffView.ApplyTheme;
var
  ThemingSvc: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingSvc) then
    if ThemingSvc.IDEThemingEnabled then
      ThemingSvc.ApplyTheme(Self);
end;

procedure TGitDiffView.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
