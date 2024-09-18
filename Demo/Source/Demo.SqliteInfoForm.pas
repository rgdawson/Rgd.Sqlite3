Unit Demo.SqliteInfoForm;

Interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls;

type
  TSqliteInfoForm = class(TForm)
    Memo1: TMemo;
    btnClose: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SqliteInfoForm: TSqliteInfoForm;

Implementation

{$R *.dfm}

End.
