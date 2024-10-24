Unit Demo.MainForm;

{.$DEFINE DEMO_FDE}   {Define this to demo the FDE version of SQlite3}

Interface

uses
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.Diagnostics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  {$IFNDEF DEMO_FDE}Rgd.Sqlite3,{$ELSE}Rgd.Sqlite3FDE,{$ENDIF}
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
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnInfoClick(Sender: TObject);
    procedure cbxCountryClick(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    Stmt_Description: ISqlite3Statement;
    procedure InitDatabase;
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

const
  ALL_COUNTRIES = '-- All Countries --';

{$REGION ' Events '}

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
    'Library: ' + TSqlite3.LibPath    + CRLF +
    'Version: ' + TSqlite3.VersionStr + CRLF +
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
end;

procedure TMainForm.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  Stmt_Description.BindAndStep([Item.Caption]);
  Memo1.Lines.Text := Stmt_Description.SqlColumn[0].AsText;
end;

{$ENDREGION}

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
  S: TStopWatch;
  S0: string;
begin
  ListView1.Items.BeginUpdate;
  try
    ListView1.Clear;
    S := TStopWatch.StartNew;
    with DB.Prepare(
      'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount' +
      '  FROM Organizations' +
      ' ORDER BY 2') do Fetch(procedure
    begin
      S.Stop;
      var Item := ListView1.Items.Add;
      S.Start;
      S0 := SqlColumn[0].AsText;
      S.Stop;
      Item.Caption := S0;
      S.Start;
      for var i := 1 to 6 do
      begin
        S0 := SqlColumn[i].AsText;
        S.Stop;
        Item.SubItems.Add(S0);
        S.Start;
      end;
    end);
    Label1.Caption := Format('Query: %0.3fms', [S.Elapsed.TotalMilliseconds]);
  finally
    ListView1.Items.EndUpdate;
  end;
  ResizeColumns;
end;

procedure TMainForm.LoadListView(Country: string);
var
  S: TStopwatch;
  S0: string;
begin
  S := TStopWatch.StartNew;
  ListView1.Items.BeginUpdate;
  ListView1.Clear;
  S := TStopWatch.StartNew;
  with DB.Prepare(
    'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount' +
    '  FROM Organizations' +
    ' WHERE Country = ?' +
    ' ORDER BY 2') do BindAndFetch([Country], procedure
  begin
    S.Stop;
    var Item := ListView1.Items.Add;
    S.Start;
    S0 := SqlColumn[0].AsText;
    S.Stop;
    Item.Caption := S0;
    S.Start;
    for var i := 1 to 6 do
    begin
      S0 := SqlColumn[i].AsText;
      S.Stop;
      Item.SubItems.Add(S0);
      S.Start;
    end;
  end);
  S.Stop;
  Label1.Caption := Format('Query: %0.3fms', [S.Elapsed.TotalMilliseconds]);
  ListView1.Items.EndUpdate;
  ResizeColumns;
end;

procedure TMainForm.InitDatabase;
begin
  {Create Database...}
  {$IFNDEF DEMO_FDE}
  DB := TSqlite3.OpenDatabase(':memory:');  //In-Memory database for demo purposes
  {$ELSE}
  DeleteFile('DemoDataEncrypted.db'); //Delete prexisting and re-create for demo purposes
  DB := TSqlite3.OpenDatabase('DemoDataEncrypted.db', 'Password123'); //File database so you can see it is encrypted
  Db.Execute('pragma journal_mode=OFF');
  {$ENDIF}

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

procedure TMainForm.ReadCsvIntoDatabase;
var
  Lines, Values: TStringlist;
  SW: TStopWatch;
begin
  SW := TStopWatch.StartNew;
  {Create the database...}
  InitDatabase;

  {Import CSV Data...}
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
        for var Line in Lines do
        begin
          Values.CommaText := Line; {Parse csv line}
          Values.Delete(0);      {Ignore first column in our sample .csv}
          BindAndStep(Values.ToStringArray);
        end;
      end;
    end);

  finally
    Values.Free;
    Lines.Free;
  end;

  {Prepare Stmt for getting description on ListView item select...}
  DB.Execute('ANALYZE');
  Stmt_Description := DB.Prepare(
    'SELECT Description'   +
    '  FROM Organizations' +
    ' WHERE OrgID = ?');
  Label4.Caption := Format('Import CSV: %0.3fms', [SW.Elapsed.TotalMilliseconds]);
end;

procedure TMainForm.ResizeColumns;
var
  FixedWidth: integer;
  AutoWidth : integer;
begin
  FixedWidth := ListView1.Columns[5].Width + ListView1.Columns[6].Width;
  AutoWidth := (ListView1.ClientWidth - FixedWidth) div 4;

  ListView1.Items.BeginUpdate;
  try
    ListView1.Columns[1].Width := AutoWidth;
    ListView1.Columns[2].Width := AutoWidth;
    ListView1.Columns[3].Width := AutoWidth;
    ListView1.Columns[4].Width := ListView1.ClientWidth - FixedWidth - AutoWidth * 3;
  finally
    ListView1.Items.EndUpdate;
  end;
end;

End.
