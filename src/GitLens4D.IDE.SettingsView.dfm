object GitSettingsView: TGitSettingsView
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'QSGitLens4D Settings'
  ClientHeight = 280
  ClientWidth = 400
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
    Top = 240
    Width = 400
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnSave: TButton
      Left = 230
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Save'
      Default = True
      TabOrder = 0
      OnClick = btnSaveClick
    end
    object btnCancel: TButton
      Left = 315
      Top = 6
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 1
      OnClick = btnCancelClick
    end
  end
  object grpShortcuts: TGroupBox
    Left = 10
    Top = 10
    Width = 380
    Height = 100
    Caption = ' Keyboard Shortcuts '
    TabOrder = 1
    object lblHist: TLabel
      Left = 15
      Top = 30
      Width = 100
      Height = 13
      Caption = 'Line History:'
    end
    object lblChanges: TLabel
      Left = 15
      Top = 65
      Width = 100
      Height = 13
      Caption = 'Git Changes Window:'
    end
    object edtShortcutHist: TEdit
      Left = 130
      Top = 27
      Width = 230
      Height = 21
      TabOrder = 0
      Text = 'Ctrl+Shift+H'
    end
    object edtShortcutChanges: TEdit
      Left = 130
      Top = 62
      Width = 230
      Height = 21
      TabOrder = 1
      Text = 'Ctrl+Alt+G'
    end
  end
  object grpCommit: TGroupBox
    Left = 10
    Top = 120
    Width = 380
    Height = 110
    Caption = ' Commit Options '
    TabOrder = 2
    object lblTag: TLabel
      Left = 15
      Top = 30
      Width = 80
      Height = 13
      Caption = 'Global Extra Tag:'
    end
    object lblTagHint: TLabel
      Left = 15
      Top = 80
      Width = 320
      Height = 13
      Caption = 'Ex: [skip ci], [internal]. Leave empty to disable.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsItalic]
      ParentFont = False
    end
    object edtCommitTag: TEdit
      Left = 110
      Top = 27
      Width = 250
      Height = 21
      TabOrder = 0
    end
  end
end
