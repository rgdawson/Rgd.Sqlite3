Unit Demo.MainForm;

{.$DEFINE DEMO_FDE}   {Define this to demo the FDE version of SQlite3}

Interface

uses
  System.Classes,
  System.SysUtils,
  System.Diagnostics,
  System.StrUtils,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  {$IFNDEF DEMO_FDE}Rgd.Sqlite3,{$ELSE}Rgd.Sqlite3FDE,{$ENDIF}
  Rgd.StrUtils,
  Demo.SqliteInfoForm;

type
  TMainForm = class(TForm)
    btnClose   : TButton;
    btnInfo: TButton;
    cbxCountry : TComboBox;
    Label2     : TLabel;
    Label3     : TLabel;
    ListView1  : TListView;
    Memo1      : TMemo;
    Label1     : TLabel;
    Label4: TLabel;
    cbxSizeCategory: TComboBox;
    Label5: TLabel;
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnInfoClick(Sender: TObject);
    procedure cbxCountryClick(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    Stmt_Description: ISqlite3Statement;
    procedure CreateDatabase;
    procedure FillCountryCombo;
    procedure LoadListView;
    procedure ReadCsvIntoDatabase;
    procedure ResizeColumns;
  public
    //
  end;

var
  MainForm: TMainForm;

Implementation

{$R *.dfm}

{$REGION ' Events '}

const
  ALL_COUNTRIES = '-- All Countries --';
  ALL_SIZES     = '-- All Size Categories --';

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  DeleteFile('Data.db');
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  ResizeColumns;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  ReadCsvIntoDatabase;
  FillCountryCombo;
  cbxCountry.ItemIndex := 0;
  LoadListView;
end;

procedure TMainForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.btnInfoClick(Sender: TObject);
const
  CRLF = #13#10;
begin
  SqliteInfoForm.Memo1.Text :=
    'Library: ' + TSqlite3.LibPath    + CRLF +
    'Version: ' + TSqlite3.VersionStr + CRLF +
    'Compiled Options:'               + CRLF +
    Trim(TSqlite3.CompileOptions);
  SqliteInfoForm.ShowModal;
end;

procedure TMainForm.cbxCountryClick(Sender: TObject);
begin
  LoadListView;
end;

procedure TMainForm.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  Stmt_Description.BindAndStep([Item.Caption]);
  Memo1.Lines.Text := Stmt_Description.SqlColumn[0].AsText;
end;

{$ENDREGION}

    procedure SqlAdf_SizeCategory(Context: Pointer; n: integer; args: PPSQLite3ValueArray); cdecl;
    var
      Count: integer;
      Result: string;
    begin
      Count := TSqlite3.ValueInt(Args[0]);
      case Count of
        0..500:       Result := 'Small';
        501..5000:    Result := 'Medium';
        5001..MaxInt: Result := 'Large';
      end;
      TSqlite3.ResultText(Context, Result);
    end;

procedure TMainForm.CreateDatabase;
begin
  {Create Database...}
  {$IFNDEF DEMO_FDE}
  DB := TSqlite3.OpenDatabase(':memory:');  //In-Memory database for demo purposes
  {$ELSE}
  DeleteFile('DemoDataEncrypted.db'); //Delete prexisting and re-create for demo purposes
  DB := TSqlite3.OpenDatabase('DemoDataEncrypted.db', 'Password123'); //File database so you can see it is encrypted
  //Db.Execute('pragma journal_mode=OFF');
  {$ENDIF}
  {Create Table...}
  DB.Execute(
    ' CREATE TABLE Organizations ( ' +
    '   OrgID            TEXT NOT NULL,' +
    '   Name             TEXT,' +
    '   Website          TEXT,' +
    '   Country          TEXT,' +
    '   Description      TEXT,' +
    '   Founded          TEXT,' +
    '   Industry         TEXT,' +
    '   EmployeeCount    INTEGER,' +
    ' PRIMARY KEY (OrgID ASC))' +
    ' WITHOUT ROWID');

  DB.CreateFunction('SizeCategory', 1, @SqlAdf_SizeCategory);
end;

procedure TMainForm.FillCountryCombo;
begin
  cbxCountry.Items.BeginUpdate;
  cbxCountry.Items.Clear;
  cbxCountry.Items.Add(ALL_COUNTRIES);
  with DB.Prepare(
    'SELECT DISTINCT Country' +
    '  FROM Organizations' +
    ' ORDER BY 1') do
  while Step = SQLITE_ROW do
    cbxCountry.Items.Add(SqlColumn[0].AsText);
  cbxCountry.Items.EndUpdate;
end;

procedure TMainForm.LoadListView;
var
  SW: TStopwatch;
  S0: string;
  FCountry: string;
  FSizeCat: string;
begin
  SW := TStopWatch.StartNew;
  ListView1.Items.BeginUpdate;
  try
    ListView1.Clear;
    SW := TStopWatch.StartNew;
    FCountry := IfThen(cbxCountry.Text = ALL_COUNTRIES, '%', cbxCountry.Text);
    FSizeCat := IfThen(cbxSizeCategory.Text = ALL_SIZES, '%', cbxSizeCategory.Text);
    with DB.Prepare(
      'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount, SizeCategory(EmployeeCount) as SizeCat' +
      '  FROM Organizations' +
      ' WHERE Country LIKE ?' +
      '   AND SizeCat LIKE ?' +
      ' ORDER BY 2') do BindAndFetch([FCountry, FSizeCat], procedure
    begin
      SW.Stop;
      var Item := ListView1.Items.Add;
      SW.Start;
      S0 := SqlColumn[0].AsText;
      SW.Stop;
      Item.Caption := S0;
      SW.Start;
      for var i := 1 to 7 do
      begin
        S0 := SqlColumn[i].AsText;
        SW.Stop;
        Item.SubItems.Add(S0);
        SW.Start;
      end;
    end);
    SW.Stop;
    Label1.Caption := Format('Query: %0.3fms', [SW.Elapsed.TotalMilliseconds]);
  finally
    ListView1.Items.EndUpdate;
  end;
  ResizeColumns;
end;

procedure TMainForm.ReadCsvIntoDatabase;
var
  Lines, Values: TStringlist;
  SW: TStopWatch;
begin
  SW := TStopWatch.StartNew;

  CreateDatabase;
  Lines := TStringlist.Create;
  Values := TStringlist.Create;
  Values.StrictDelimiter := True;
  try
    Lines.LoadFromFile('organizations-1000.csv', TEncoding.UTF8);
    Lines.Delete(0); {Ignore Header}

    DB.Transaction(procedure
    begin
      with DB.Prepare('INSERT INTO Organizations VALUES (?, ?, ?, ?, ?, ?, ?, ?)') do
      begin
        for var S in Lines do
        begin
          Values.CommaText := S;
          Values.Delete(0); {Ignore first column in our sample .csv}
          BindAndStep(Values.ToStringArray);
        end;
      end;
    end);

  finally
    Values.Free;
    Lines.Free;
  end;
  DB.Execute('ANALYZE');

  Stmt_Description := DB.Prepare(
    'SELECT Description'   +
    '  FROM Organizations' +
    ' WHERE OrgID = ?');
  Label4.Caption := Format('Import CSV: %0.3fms', [SW.Elapsed.TotalMilliseconds]);
end;

procedure TMainForm.ResizeColumns;
var
  FixedWidth, AutoWidth : integer;
begin
  FixedWidth := ListView1.Columns[5].Width + ListView1.Columns[6].Width + ListView1.Columns[7].Width;
  AutoWidth := (ListView1.ClientWidth - FixedWidth) div 4;
  ListView1.Items.BeginUpdate;
  ListView1.Columns[1].Width := AutoWidth;
  ListView1.Columns[2].Width := AutoWidth;
  ListView1.Columns[3].Width := AutoWidth;
  ListView1.Columns[4].Width := ListView1.ClientWidth - FixedWidth - AutoWidth * 3;
  ListView1.Items.EndUpdate;
end;

End.
