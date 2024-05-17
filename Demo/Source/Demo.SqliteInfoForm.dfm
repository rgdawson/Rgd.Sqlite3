object SqliteInfoForm: TSqliteInfoForm
  Left = 0
  Top = 0
  Caption = 'Sqlite3.dll Information'
  ClientHeight = 563
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  DesignSize = (
    624
    563)
  TextHeight = 15
  object Memo1: TMemo
    Left = 8
    Top = 8
    Width = 608
    Height = 512
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'Memo1')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
    ExplicitHeight = 193
  end
  object btnClose: TButton
    Left = 528
    Top = 526
    Width = 88
    Height = 29
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = 'Close'
    Default = True
    ModalResult = 8
    TabOrder = 0
    ExplicitTop = 207
  end
end
