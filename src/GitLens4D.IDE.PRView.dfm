object GitPRView: TGitPRView
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Create Pull Request Description'
  ClientHeight = 500
  ClientWidth = 600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object pnlBottom: TPanel
    Left = 0
    Top = 456
    Width = 600
    Height = 44
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnSuggest: TButton
      Left = 10
      Top = 6
      Width = 140
      Height = 30
      Caption = 'Suggest AI PR'
      TabOrder = 0
      OnClick = btnSuggestClick
    end
    object btnCopyOpen: TButton
      Left = 400
      Top = 6
      Width = 180
      Height = 30
      Caption = ' Copy & Open GitHub'
      Default = True
      TabOrder = 1
      OnClick = btnCopyOpenClick
    end
    object btnClose: TButton
      Left = 160
      Top = 6
      Width = 80
      Height = 30
      Caption = 'Cancel'
      TabOrder = 2
      OnClick = btnCloseClick
    end
  end
  object memPRBody: TMemo
    AlignWithMargins = True
    Left = 3
    Top = 45
    Width = 594
    Height = 408
    Align = alClient
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 42
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object lblTitle: TLabel
      Left = 10
      Top = 13
      Width = 345
      Height = 16
      Caption = 'Elabore a descri'#231#227'o do seu Pull Request (Markdown):'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
end
