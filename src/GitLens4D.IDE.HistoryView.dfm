object GitHistoryView: TGitHistoryView
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = 'Line History'
  ClientHeight = 400
  ClientWidth = 650
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
    Top = 360
    Width = 650
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnClose: TButton
      Left = 560
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
    Width = 644
    Height = 354
    Align = alClient
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
        Width = 300
      end>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
  end
end
