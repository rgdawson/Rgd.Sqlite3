Unit Demo.MainForm;

Interface

uses
  System.Classes,
  System.SysUtils,
  System.Diagnostics,
  System.StrUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Rgd.Sqlite3,
  Demo.SqliteInfoForm;

type
  TMainForm = class(TForm)
    btnClose   : TButton;
    btnInfo    : TButton;
    cbxCountry : TComboBox;
    cbxSizeCat : TComboBox;
    Image1     : TImage;
    Label1     : TLabel;
    Label2     : TLabel;
    Label3     : TLabel;
    Label4     : TLabel;
    Label5     : TLabel;
    ListView1  : TListView;
    Memo1      : TMemo;
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnInfoClick(Sender: TObject);
    procedure cbxCountryClick(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnCloseClick(Sender: TObject);
  private
    StmtDescription: ISqlite3Statement;
    StmtData: ISqlite3Statement;
    procedure CreateDatabase;
    procedure FillCountryCombo;
    procedure LoadListView;
    procedure ReadCsvIntoDatabase;
    procedure ResizeColumns;
  public
  end;

var
  MainForm: TMainForm;

Implementation

{$R *.dfm}

const
  ALL_COUNTRIES = '-- All Countries --';
  ALL_SIZES     = '-- All Size Categories --';

var
  USE_MEM_DB    : Boolean = TRUE;
  WITHOUT_ROWID : Boolean = TRUE;
  TEST_BLOB     : Boolean = TRUE;
  TEST_ADF      : Boolean = TRUE;

{$REGION ' Events '}

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
  Close
end;

procedure TMainForm.btnInfoClick(Sender: TObject);
const
  CRLF = #13#10;
  TempStoreStr:    array[0..2] of string = ('Default', 'File', 'Memory');
  SynchrounousStr: array[0..2] of string = ('Off', 'Normal', 'Full');
begin
  SqliteInfoForm.Memo1.Text :=
    'Library: ' + TSqlite3.LibPath    + CRLF +
    'Version: ' + TSqlite3.VersionStr + CRLF +
    'Compiled Options:'               + CRLF +
    Trim(TSqlite3.CompileOptions);

  {Database settings...}
  var Mode := 'n/a';
  var Temp_Store := 'n/a';
  var Synchronous := 'n/a';
  if Assigned(DB) and Assigned(DB.Handle) then
  begin
    with DB.Prepare('pragma journal_mode') do Fetch(procedure
    begin
      Mode := SqlColumn[0].AsText;
    end);

    with DB.Prepare('pragma temp_store') do Fetch(procedure
    begin
      Temp_Store := SqlColumn[0].AsText;
    end);

    with DB.Prepare('pragma synchronous') do Fetch(procedure
    begin
      Synchronous := SqlColumn[0].AsText;
    end);

    SqliteInfoForm.Memo1.Text := SqliteInfoForm.Memo1.Text + CRLF + CRLF +
      'DB Settings: ' +  CRLF +
      '    Journal Mode: ' + UpperCase(Mode) + CRLF +
      '    Temp_Store: '   + Temp_Store  + ' (' + TempStoreStr[Temp_Store.ToInteger] + ')' + CRLF +
      '    Synchronous: '  + Synchronous + ' (' + SynchrounousStr[Synchronous.ToInteger] + ')';
  end;
  SqliteInfoForm.ShowModal;
end;

procedure TMainForm.cbxCountryClick(Sender: TObject);
begin
  LoadListView;
end;

procedure TMainForm.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  StmtDescription.BindAndStep([Item.Caption]);
  Memo1.Lines.Text := StmtDescription.SqlColumn[0].AsText;

  if TEST_BLOB then
  begin
    with StmtData do
    begin
      BindAndStep([Item.Caption]);
      var BytesStream := TBytesStream.Create(SqlColumn[0].AsBlob);
      try
        if Length(BytesStream.Bytes) > 0 then
          Image1.Picture.LoadFromStream(BytesStream);
      finally
         BytesStream.Free;
      end;
    end;
  end;
end;

{$ENDREGION}

procedure SqlAdf_SizeCategory(Context: PSqlite3Context; ArgCount: integer; Args: PPSQLite3ValueArray); {$IFDEF SQLITE_WIN}stdcall;{$ELSE}cdecl;{$ENDIF}
{Application Defined Function Example (TSQLite3RegularFunction) }
var
  Count: integer;
  AdfResult: string;
begin
  Count := TSqlite3.AdfValueInt(Args[0]);
  case Count of
       0..500:    AdfResult := 'Small';
     501..5000:   AdfResult := 'Medium';
    5001..MaxInt: AdfResult := 'Large';
  end;
  TSqlite3.AdfResultText(Context, AdfResult);
end;

procedure TMainForm.CreateDatabase;
const
  DbName = 'DemoData.db';
begin
  {Create Database...}
  if USE_MEM_DB then
    DB := TSqlite3.OpenDatabase(MEMORY)
  else
  begin
    DeleteFile(DbName);
    DB := TSqlite3.OpenDatabase(DbName);
  end;

  {Create Table...}
  if TEST_ADF then
  begin
    {This is faster for mem DBs (2x)}
    if WITHOUT_ROWID then
    begin
      {This seems a touch faster for file DBs}
      DB.Execute('''
        CREATE TABLE Organizations (
          OrgID        TEXT NOT NULL,
          Name         TEXT,
          Website      TEXT,
          Country      TEXT,
          Description  TEXT,
          Founded      TEXT,
          Industry     TEXT,
          HeadCount    INTEGER,
        PRIMARY KEY (OrgID ASC))
        WITHOUT ROWID
        ''');
      if TEST_BLOB then
      begin
        DB.Execute('''
          CREATE TABLE BlobData (
            OrgID  TEXT NOT NULL,
            Data   BLOB,
          PRIMARY KEY (OrgID ASC))
          WITHOUT ROWID
          ''');
      end;
    end
    else
    begin
      DB.Execute('''
        CREATE TABLE Organizations (
          OrgID        TEXT,
          Name         TEXT,
          Website      TEXT,
          Country      TEXT,
          Description  TEXT,
          Founded      TEXT,
          Industry     TEXT,
          HeadCount    INTEGER)
        ''');
      if TEST_BLOB then
      begin
        DB.Execute('''
          CREATE TABLE BlobData (
            OrgID  TEXT,
            Data   BLOB)
          ''');
      end;
    end;
    DB.AdfCreateFunction('SizeCategory', 1, @SqlAdf_SizeCategory);
  end
  else
  begin
    if WITHOUT_ROWID then
    begin
      DB.Execute('''
        CREATE TABLE Organizations (
          OrgID        TEXT NOT NULL,
          Name         TEXT,
          Website      TEXT,
          Country      TEXT,
          Description  TEXT,
          Founded      TEXT,
          Industry     TEXT,
          HeadCount    INTEGER,
          EmployeeCategory TEXT GENERATED ALWAYS AS (
            CASE
              WHEN (HeadCount >= 0)   AND (HeadCount <= 500)  THEN 'Small'
              WHEN (HeadCount >= 501) AND (HeadCount <= 5000) THEN 'Medium'
              ELSE 'Large'
            END),
        PRIMARY KEY (OrgID ASC))
        WITHOUT ROWID
        ''');
    end
    else
    begin
      DB.Execute('''
        CREATE TABLE Organizations (
          OrgID        TEXT NOT NULL,
          Name         TEXT,
          Website      TEXT,
          Country      TEXT,
          Description  TEXT,
          Founded      TEXT,
          Industry     TEXT,
          HeadCount    INTEGER,
          EmployeeCategory TEXT GENERATED ALWAYS AS (
            CASE
              WHEN (HeadCount >= 0)   AND (HeadCount <= 500)  THEN 'Small'
              WHEN (HeadCount >= 501) AND (HeadCount <= 5000) THEN 'Medium'
              ELSE 'Large'
            END)
          )
        ''');
    end;
  end;
end;

procedure TMainForm.FillCountryCombo;
begin
  cbxCountry.Items.BeginUpdate;
  cbxCountry.Items.Clear;
  cbxCountry.Items.Add(ALL_COUNTRIES);

  with DB.Prepare('''
    SELECT DISTINCT Country
      FROM Organizations
     ORDER BY 1
    ''') do Fetch(procedure
  begin
    cbxCountry.Items.Add(SqlColumn[0].AsText);
  end);

  cbxCountry.Items.EndUpdate;
end;

procedure TMainForm.LoadListView;
var
  SW: TStopwatch;
  S0: string;
  FCountry: string;
  FSizeCat: string;
  Stmt: ISqlite3Statement;
begin
  ListView1.Items.BeginUpdate;
  try
    ListView1.Clear;
    FCountry := IfThen(cbxCountry.Text = ALL_COUNTRIES, '%', cbxCountry.Text);
    FSizeCat := IfThen(cbxSizeCat.Text = ALL_SIZES, '%', cbxSizeCat.Text);

    SW := TStopWatch.StartNew;

    if TEST_ADF then
    begin
      Stmt := DB.Prepare('''
        SELECT OrgID, Name, Website, Country, Industry, Founded, HeadCount, SizeCategory(HeadCount) AS EmployeeCategory
          FROM Organizations
         WHERE Country LIKE ?
           AND EmployeeCategory LIKE ?
         ORDER BY 2
        ''');
    end
    else
    begin
      Stmt := DB.Prepare('''
        SELECT OrgID, Name, Website, Country, Industry, Founded, HeadCount, EmployeeCategory
          FROM Organizations
         WHERE Country LIKE ?
           AND EmployeeCategory LIKE ?
         ORDER BY 2
        ''');
    end;

    with Stmt do BindAndFetch([FCountry, FSizeCat], procedure
    begin
      SW.Start;
      S0 := SqlColumn[0].AsText;
      SW.Stop;
      var Item := ListView1.Items.Add;
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
    Label1.Caption := Format('Query: %0.2fms', [SW.Elapsed.TotalMilliseconds]);
  finally
    ListView1.Items.EndUpdate;
  end;
  ResizeColumns;
end;

procedure TMainForm.ReadCsvIntoDatabase;
var
  Lines, Values: TStringlist;
  ByteArray: TBytes;
  SW: TStopWatch;
begin
  Lines := TStringlist.Create;
  Values := TStringlist.Create;
  Values.StrictDelimiter := True;
  SW := TStopWatch.StartNew;
  CreateDatabase;
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

      if TEST_BLOB then
      begin
        {Get Blob Data (demo purposes)}
        var Blob := TFileStream.Create('CarrPilot.jpg', fmOpenRead);
        try
          SetLength(ByteArray, Blob.Size);
          Blob.ReadData(ByteArray, Blob.Size);
        finally
          Blob.Free;
        end;

        {Insert BLOB Data...}
        with DB.Prepare('INSERT INTO BlobData VALUES (?, ?)') do
        begin
          for var S in Lines do
          begin
            Values.CommaText := S;
            SqlParam[1].BindText(Values[1]); {Ignore first column in our sample .csv}
            SqlParam[2].BindBlob(ByteArray);
            StepAndReset;
          end;
        end;
      end;
    end);
  finally
    Values.Free;
    Lines.Free;
  end;

  StmtDescription := DB.Prepare('SELECT Description FROM Organizations WHERE OrgID = ?');

  if TEST_BLOB then
    StmtData := DB.Prepare('SELECT Data FROM BlobData WHERE OrgID = ?');

  SW.Stop;
  Label4.Caption := Format('Import CSV: %0.2fms', [SW.Elapsed.TotalMilliseconds]);
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

