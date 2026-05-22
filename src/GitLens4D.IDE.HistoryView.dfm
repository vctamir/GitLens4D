object GitHistoryView: TGitHistoryView
  Left = 0
  Top = 0
  Caption = 'Line Evolution'
  ClientHeight = 500
  ClientWidth = 700
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
  object Splitter1: TSplitter
    Left = 0
    Top = 200
    Width = 700
    Height = 5
    Cursor = crVSplit
    Align = alTop
    ExplicitWidth = 650
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 460
    Width = 700
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnClose: TButton
      Left = 610
      Top = 6
      Width = 80
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Close'
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object lstHistory: TListView
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 694
    Height = 194
    Align = alTop
    Columns = <
      item
        Caption = 'Hash'
        Width = 80
      end
      item
        Caption = 'Author'
        Width = 120
      end
      item
        Caption = 'Date'
        Width = 130
      end
      item
        Caption = 'Message'
        Width = 350
      end>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnSelectItem = lstHistorySelectItem
  end
  object redPatch: TRichEdit
    AlignWithMargins = True
    Left = 3
    Top = 208
    Width = 694
    Height = 249
    Align = alClient
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 2
    WordWrap = False
  end
end
