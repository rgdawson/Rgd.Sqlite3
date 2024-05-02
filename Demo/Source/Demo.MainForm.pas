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
  Vcl.StdCtrls;

type
  TMainForm = class(TForm)
    btnClose   : TButton;
    cbxCountry : TComboBox;
    Label2     : TLabel;
    Label3     : TLabel;
    ListView1  : TListView;
    Memo1      : TMemo;
    Label1: TLabel;
    procedure ListView1SelectItem (Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnCloseClick       (Sender: TObject);
    procedure FormResize          (Sender: TObject);
    procedure cbxCountryClick     (Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    Stmt_Description: ISqlite3Statement;
    procedure CreateDatabase;
    procedure FillCountryCombo;
    procedure LoadListView; overload;
    procedure LoadListView(Country: string); overload;
    procedure ReadCsvIntoDatabase;
    procedure ResizeColumns;
  public

  end;

var
  MainForm: TMainForm;

Implementation

{$R *.dfm}

{$REGION ' Events '}

const
  ALL_COUNTRIES = '-- All Countries --';

procedure TMainForm.cbxCountryClick(Sender: TObject);
begin
  if cbxCountry.Text = ALL_COUNTRIES then
    LoadListView
  else
    LoadListView(cbxCountry.Text);
end;

procedure TMainForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

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

procedure TMainForm.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  with Stmt_Description do BindAndFetchFirst([Item.Caption], procedure
  begin
    Memo1.Lines.Text := SqlColumn[0].AsText;
  end);
end;

{$ENDREGION}

procedure TMainForm.CreateDatabase;
begin
  DB := TSqlite3Database.Create;
  DB.Open(':memory:');

  {Create Table...}
  DB.Execute(
    ' CREATE TABLE Organizations ( ' +
    '   OrgID                     TEXT,' +
    '   Name                      TEXT,' +
    '   Website                   TEXT,' +
    '   Country                   TEXT,' +
    '   Description               TEXT,' +
    '   Founded                   TEXT,' +
    '   Industry                  TEXT,' +
    '   EmployeeCount             INTEGER,' +
    ' PRIMARY KEY (OrgID ASC))' +
    ' WITHOUT ROWID');
  DB.Execute('CREATE INDEX idx_Name ON Organizations (Name)');

  Stmt_Description := DB.Prepare(
    'SELECT Description' +
    '  FROM Organizations' +
    ' WHERE OrgID = ?', SQLITE_PREPARE_PERSISTENT);
end;

procedure TMainForm.FillCountryCombo;
begin
  cbxCountry.Items.Clear;
  cbxCountry.Items.BeginUpdate;
  cbxCountry.Items.Add(ALL_COUNTRIES);

  with DB.Prepare(
    'SELECT DISTINCT Country' +
    '  FROM Organizations' +
    ' ORDER BY 1') do Fetch(procedure
  begin
    cbxCountry.Items.Add(SqlColumn[0].AsText);
  end);

  cbxCountry.Items.EndUpdate;
end;

procedure TMainForm.LoadListView;
var
  Item: TListItem;
  StopWatch: TStopwatch;
begin
  StopWatch := TStopWatch.StartNew;
  ListView1.Clear;
  ListView1.Items.BeginUpdate;
  with DB.Prepare(
      'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount' +
      '  FROM Organizations' +
      ' ORDER BY 2') do Fetch(procedure
  var i: integer;
  begin
    Item := ListView1.Items.Add;
    Item.Caption := SqlColumn[0].AsText;
    for i := 1 to 7 do
      Item.SubItems.Add(SqlColumn[i].AsText);
  end);
  ListView1.Items.EndUpdate;
  ResizeColumns;
  Label1.Caption := Format(' %d records, %dms', [ListView1.Items.Count, StopWatch.ElapsedMilliseconds]);
end;

procedure TMainForm.LoadListView(Country: string);
var
  Item: TListItem;
  StopWatch: TStopwatch;
begin
  StopWatch := TStopWatch.StartNew;
  ListView1.Clear;
  ListView1.Items.BeginUpdate;
    with DB.Prepare(
      'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount' +
      '  FROM Organizations' +
      ' WHERE Country = ?' +
      ' ORDER BY 2', [QuotedStr(cbxCountry.Text)]) do
    begin
      BindAndFetch([Country], procedure
        var i: integer;
        begin
          Item := ListView1.Items.Add;
          Item.Caption := SqlColumn[0].AsText;
          for i := 1 to 7 do
            Item.SubItems.Add(SqlColumn[i].AsText);
        end);
    end;
  ListView1.Items.EndUpdate;
  ResizeColumns;
  Label1.Caption := Format(' %d records, %dms', [ListView1.Items.Count, StopWatch.ElapsedMilliseconds]);
end;

procedure TMainForm.ReadCsvIntoDatabase;
var
  Lines, Fields: TStringlist;
begin
  Lines := TStringlist.Create;
  Fields := TStringlist.Create;
  try
    CreateDatabase;
    Fields.StrictDelimiter := True;
    Lines.LoadFromFile('organizations-1000.csv');
    Lines.Delete(0); {Ignore Header}

    DB.Transaction(procedure
      var S: string;
      begin
        with DB.Prepare('INSERT INTO Organizations VALUES (?, ?, ?, ?, ?, ?, ?, ?)') do
        begin
          for S in Lines do
          begin
            Fields.CommaText := S;
            BindAndStep([Fields[1], Fields[2], Fields[3], Fields[4], Fields[5], Fields[6], Fields[7], Fields[8]]);  {Ignoreing first column}
          end;
        end;
    end);
  finally
    Fields.Free;
    Lines.Free;
  end;
  DB.Execute('ANALYZE');
end;

procedure TMainForm.ResizeColumns;
var
  FixedColWidth   : integer;
  AutoColumnWidth : integer;
begin
  FixedColWidth := ListView1.Columns[5].Width + ListView1.Columns[6].Width;
  AutoColumnWidth := (ListView1.ClientWidth - FixedColWidth) div 4;

  ListView1.Items.BeginUpdate;
  ListView1.Columns[1].Width := AutoColumnWidth;
  ListView1.Columns[2].Width := AutoColumnWidth;
  ListView1.Columns[3].Width := AutoColumnWidth;
  ListView1.Columns[4].Width := ListView1.ClientWidth - FixedColWidth - AutoColumnWidth * 3;
  ListView1.Items.EndUpdate;
end;

End.
