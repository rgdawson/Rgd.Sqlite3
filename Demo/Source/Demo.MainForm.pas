Unit Demo.MainForm;

Interface

uses
  System.Classes,
  System.SysUtils,
  System.Diagnostics,
  Rgd.Sqlite3,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
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
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnInfoClick(Sender: TObject);
    procedure cbxCountryClick(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    Stmt_Description: ISqlite3Statement;
    procedure CreateDatabase;
    procedure FillCountryCombo;
    procedure LoadListView; overload;
    procedure LoadListView(Country: string); overload;
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

procedure TMainForm.FormResize(Sender: TObject);
begin
  ResizeColumns;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  ReadCsvIntoDatabase;
  FillCountryCombo;
  LoadListView;
  cbxCountry.ItemIndex := 0;
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
    'Version: ' + TSqlite3.VersionStr + CRLF +
    'Path: ' + TSqlite3.LibPath       + CRLF +
    'Compiled Options:'               + CRLF +
    Trim(TSqlite3.CompileOptions);
  SqliteInfoForm.ShowModal;
end;

procedure TMainForm.cbxCountryClick(Sender: TObject);
begin
  if cbxCountry.Text = ALL_COUNTRIES then
    LoadListView
  else
    LoadListView(cbxCountry.Text);
  Memo1.Lines.Clear;
end;

procedure TMainForm.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  Stmt_Description.BindAndStep([Item.Caption]);
  Memo1.Lines.Text := Stmt_Description.SqlColumn[0].AsText;
end;

{$ENDREGION}

procedure TMainForm.CreateDatabase;
begin
  DB := TSqlite3Database.Create;
  DB.Open(':memory:');

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
begin
  ListView1.Items.BeginUpdate;
  ListView1.Clear;

  with DB.Prepare(
    'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount' +
    '  FROM Organizations' +
    ' ORDER BY 2') do Fetch(procedure
  begin
    var Item := ListView1.Items.Add;
    Item.Caption   := SqlColumn[0].AsText;
    for var i := 1 to 6 do
      Item.SubItems.Add(SqlColumn[i].AsText);
  end);

  ListView1.Items.EndUpdate;
  ResizeColumns;
end;

procedure TMainForm.LoadListView(Country: string);
begin
  ListView1.Items.BeginUpdate;
  ListView1.Clear;

  with DB.Prepare(
    'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount' +
    '  FROM Organizations' +
    ' WHERE Country = ?' +
    ' ORDER BY 2') do BindAndFetch([Country], procedure
  begin
    var Item := ListView1.Items.Add;
    Item.Caption := SqlColumn[0].AsText;
    for var i := 1 to 6 do
      Item.SubItems.Add(SqlColumn[i].AsText);
  end);

  ListView1.Items.EndUpdate;
  ResizeColumns;
end;

procedure TMainForm.ReadCsvIntoDatabase;
var
  Lines, Values: TStringlist;
begin
  Lines := TStringlist.Create;
  Values := TStringlist.Create;
  Values.StrictDelimiter := True;

  try
    CreateDatabase;
    Lines.LoadFromFile('organizations-1000.csv');
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
    ' WHERE OrgID = ?', SQLITE_PREPARE_PERSISTENT);
end;

procedure TMainForm.ResizeColumns;
var
  FixedWidth, AutoWidth : integer;
begin
  FixedWidth := ListView1.Columns[5].Width + ListView1.Columns[6].Width;
  AutoWidth := (ListView1.ClientWidth - FixedWidth) div 4;
  ListView1.Items.BeginUpdate;
  ListView1.Columns[1].Width := AutoWidth;
  ListView1.Columns[2].Width := AutoWidth;
  ListView1.Columns[3].Width := AutoWidth;
  ListView1.Columns[4].Width := ListView1.ClientWidth - FixedWidth - AutoWidth * 3;
  ListView1.Items.EndUpdate;
end;

End.
