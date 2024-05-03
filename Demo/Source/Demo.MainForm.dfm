object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Rgd.Sqlite3 Demo'
  ClientHeight = 558
  ClientWidth = 922
  Color = clBtnFace
  Constraints.MinHeight = 400
  Constraints.MinWidth = 800
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnResize = FormResize
  OnShow = FormShow
  DesignSize = (
    922
    558)
  TextHeight = 15
  object Label2: TLabel
    Left = 8
    Top = 479
    Width = 63
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Description:'
    ExplicitTop = 267
  end
  object Label3: TLabel
    Left = 8
    Top = 11
    Width = 43
    Height = 15
    Caption = 'Country'
  end
  object Label1: TLabel
    Left = 792
    Top = 479
    Width = 120
    Height = 15
    Alignment = taRightJustify
    Anchors = [akRight, akBottom]
    AutoSize = False
  end
  object ListView1: TListView
    Left = 8
    Top = 39
    Width = 904
    Height = 434
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <
      item
        Caption = 'Org ID'
        Width = 0
      end
      item
        Caption = 'Name'
        Width = 150
      end
      item
        Caption = 'Website'
        Width = 150
      end
      item
        Caption = 'Country'
        Width = 150
      end
      item
        Caption = 'Industry'
        Width = 150
      end
      item
        Alignment = taCenter
        Caption = 'Founded'
        Width = 60
      end
      item
        Alignment = taRightJustify
        Caption = 'Employees'
        Width = 70
      end>
    DoubleBuffered = True
    RowSelect = True
    ParentDoubleBuffered = False
    TabOrder = 0
    ViewStyle = vsReport
    OnSelectItem = ListView1SelectItem
  end
  object Memo1: TMemo
    Left = 8
    Top = 500
    Width = 329
    Height = 49
    Anchors = [akLeft, akBottom]
    TabOrder = 1
  end
  object btnClose: TButton
    Left = 816
    Top = 504
    Width = 96
    Height = 29
    Anchors = [akRight, akBottom]
    Caption = 'Close'
    TabOrder = 2
    OnClick = btnCloseClick
  end
  object cbxCountry: TComboBox
    Left = 57
    Top = 8
    Width = 213
    Height = 23
    Style = csDropDownList
    DropDownCount = 12
    TabOrder = 3
    OnClick = cbxCountryClick
  end
  object Button1: TButton
    Left = 681
    Top = 504
    Width = 129
    Height = 29
    Caption = 'Sqlite3.dll Info'
    TabOrder = 4
    OnClick = Button1Click
  end
end
