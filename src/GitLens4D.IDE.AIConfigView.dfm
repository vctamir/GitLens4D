object GitAIConfigView: TGitAIConfigView
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'IA Configuration'
  ClientHeight = 360
  ClientWidth = 350
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
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 350
    Height = 320
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lblType: TLabel
      Left = 16
      Top = 16
      Width = 43
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
      Width = 62
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
      Width = 245
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 0
      Text = 'Local'
      Items.Strings = (
        'Local'
        'Remote')
    end
    object edtEndpoint: TEdit
      Left = 85
      Top = 51
      Width = 245
      Height = 21
      TabOrder = 1
      Text = 'http://localhost:11434'
    end
    object edtKey: TEdit
      Left = 85
      Top = 89
      Width = 245
      Height = 21
      PasswordChar = '*'
      TabOrder = 2
    end
    object edtModel: TEdit
      Left = 85
      Top = 127
      Width = 245
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
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 320
    Width = 350
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnSave: TButton
      Left = 180
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Save'
      TabOrder = 0
      OnClick = btnSaveClick
    end
    object btnCancel: TButton
      Left = 261
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Cancel'
      TabOrder = 1
      OnClick = btnCancelClick
    end
  end
end
