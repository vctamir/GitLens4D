object GitSettingsView: TGitSettingsView
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'QSGitLens4D Settings'
  ClientHeight = 350
  ClientWidth = 450
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
    Top = 310
    Width = 450
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnSave: TButton
      Left = 280
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Save'
      Default = True
      TabOrder = 0
      OnClick = btnSaveClick
    end
    object btnCancel: TButton
      Left = 365
      Top = 6
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 1
      OnClick = btnCancelClick
    end
  end
  object pcSettings: TPageControl
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 444
    Height = 304
    ActivePage = tsGeneral
    Align = alClient
    TabOrder = 1
    object tsGeneral: TTabSheet
      Caption = 'Geral'
      object grpShortcuts: TGroupBox
        Left = 10
        Top = 10
        Width = 420
        Height = 100
        Caption = ' Keyboard Shortcuts '
        TabOrder = 0
        object lblHist: TLabel
          Left = 15
          Top = 30
          Width = 60
          Height = 13
          Caption = 'Line History:'
        end
        object lblChanges: TLabel
          Left = 15
          Top = 65
          Width = 103
          Height = 13
          Caption = 'Git Changes Window:'
        end
        object edtShortcutHist: TEdit
          Left = 130
          Top = 27
          Width = 270
          Height = 21
          TabOrder = 0
          Text = 'Ctrl+Shift+H'
        end
        object edtShortcutChanges: TEdit
          Left = 130
          Top = 62
          Width = 270
          Height = 21
          TabOrder = 1
          Text = 'Ctrl+Alt+G'
        end
      end
      object grpCommit: TGroupBox
        Left = 10
        Top = 120
        Width = 420
        Height = 110
        Caption = ' Commit Options '
        TabOrder = 1
        object lblTag: TLabel
          Left = 15
          Top = 30
          Width = 83
          Height = 13
          Caption = 'Global Extra Tag:'
        end
        object lblTagHint: TLabel
          Left = 15
          Top = 80
          Width = 228
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
          Width = 290
          Height = 21
          TabOrder = 0
        end
      end
    end
    object tsAI: TTabSheet
      Caption = 'Intelig'#234'ncia Artificial'
      ImageIndex = 1
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 442
      ExplicitHeight = 282
      object lblType: TLabel
        Left = 16
        Top = 16
        Width = 42
        Height = 13
        Caption = 'AI Type:'
      end
      object lblEndpoint: TLabel
        Left = 16
        Top = 54
        Width = 46
        Height = 13
        Caption = 'Endpoint:'
      end
      object lblKey: TLabel
        Left = 16
        Top = 92
        Width = 42
        Height = 13
        Caption = 'API Key:'
      end
      object lblModel: TLabel
        Left = 16
        Top = 130
        Width = 32
        Height = 13
        Caption = 'Model:'
      end
      object lblTemp: TLabel
        Left = 16
        Top = 168
        Width = 66
        Height = 13
        Caption = 'Temperature:'
      end
      object lblMaxTokens: TLabel
        Left = 16
        Top = 206
        Width = 61
        Height = 13
        Caption = 'Max Tokens:'
      end
      object lblLang: TLabel
        Left = 16
        Top = 244
        Width = 51
        Height = 13
        Caption = 'Language:'
      end
      object cbType: TComboBox
        Left = 85
        Top = 13
        Width = 325
        Height = 21
        Style = csDropDownList
        TabOrder = 0
        Items.Strings = (
          'Local'
          'openAI')
      end
      object edtEndpoint: TEdit
        Left = 85
        Top = 51
        Width = 325
        Height = 21
        TabOrder = 1
        Text = 'http://localhost:11434'
      end
      object edtKey: TEdit
        Left = 85
        Top = 89
        Width = 325
        Height = 21
        PasswordChar = '*'
        TabOrder = 2
      end
      object edtModel: TEdit
        Left = 85
        Top = 127
        Width = 325
        Height = 21
        TabOrder = 3
        Text = 'codellama'
      end
      object edtTemp: TEdit
        Left = 85
        Top = 165
        Width = 80
        Height = 21
        TabOrder = 4
        Text = '0,7'
      end
      object edtMaxTokens: TEdit
        Left = 85
        Top = 203
        Width = 80
        Height = 21
        TabOrder = 5
        Text = '2048'
      end
      object cbLang: TComboBox
        Left = 85
        Top = 241
        Width = 120
        Height = 21
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 6
        Text = 'pt-BR'
        Items.Strings = (
          'pt-BR'
          'en-US')
      end
      object lblFormat: TLabel
        Left = 220
        Top = 244
        Width = 44
        Height = 13
        Caption = 'Formato:'
      end
      object cbFormat: TComboBox
        Left = 290
        Top = 241
        Width = 120
        Height = 21
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 7
        Text = 'Markdown'
        Items.Strings = (
          'Markdown'
          'Texto Puro')
      end
    end
  end
end
