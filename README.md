# Rgd.Sqlite3
Rgd.SQLite3 for Delphi - A light-weight, simple, effective Sqlite3 interface unit

Can use sqlite3.dll or winsqlite3.dll (part of Windows 10+).  If you need encryption look at "Sqlite3 Multiple Ciphers" 
(from github.com/utelle/SQLite3MultipleCiphers/).

Credits:

This unit borrows ideas from Yury Plashenkov in https://github.com/plashenkov/SQLite3-Delphi-FPC,
which I have always admired for its genius simplicity and clarity.  With Yuri's concepts in mind,
Rgd.Sqlite3 for Delphi is implemented using interfaced objects and anonymous methods, the ideas
for which I got by reading "Coding in Delphi" by Nick Hodges, plus some flexible goodies for
binding and fetching data, and performing transactions.

Query Patterns: (Take your pick, I tend to use Pattern 1 or 2, but I know some hate 'with' statements, so I have provided alternatives.)

    {Pattern 1 - with DB. Prepare and while Step = SQLITE_ROW...}
    with DB.Prepare(
      'SELECT Name,' +
      '       ID' +
      '  FROM Tasks') do while Step = SQLITE_ROW do
    begin
      S0 := SqlColumn[0].AsText;
      ID := SqlColumn[1].AsInt;
      {...}
    end);

    {Pattern 2 - with DB.Prepare and Fetch(procedure)...}
    with DB.Prepare(
      'SELECT Name,' +
      '       ID' +
      '  FROM Tasks') do Fetch(procedure
    begin
      S0 := SqlColumn[0].AsText;
      ID := SqlColumn[1].AsInt;
      {...}
    end);

    {Pattern 2 - Stmt := DB.Prepare() and while Stmt.Step...}
    var
      Stmt: ISqlite3Statement;
    begin
      Stmt := DB.Prepare(
        'SELECT Name,' +
        '       ID' +
        '  FROM Tasks');
      while Stmt.Step = SQLITE_ROW do
      begin
        S0 := Stmt.SqlColumn[0].AsText;
        ID := Stmt.SqlColumn[1].AsInt;
        {...}
      end;
    end;

Create Datatabase pattern...
    
    procedure TMainForm.CreateDatabase;
    begin
      DB := TSqlite3Database.Create;
      DB.Open(':memory:');
      
      {Create Table...}
      DB.Execute(
        ' CREATE TABLE Organizations ( ' +
        '   OrgID              TEXT,' +        
        '   Name               TEXT,' +
        '   Website            TEXT,' +
        '   Country            TEXT,' +
        '   Description        TEXT,' +
        '   Founded            TEXT,' +
        '   Industry           TEXT,' +
        '   EmployeeCount      INTEGER,' +
        ' PRIMARY KEY (Name ASC))' +
        ' WITHOUT ROWID');
    
      Stmt_Description := DB.Prepare(
        'SELECT Description' +
        '  FROM Organizations' +
        ' WHERE Name = ?');
    end;
  
Example: inserting records from a CSV file...

    procedure TMainForm.ReadCsvIntoDatabase;
    var
      Lines, Values: TStringlist;
    begin
      Lines := TStringlist.Create;
      Values := TStringlist.Create;
      Values.StricDelimiter := True;
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
    end;

Example: Application-Defined Function

    procedure SqlAdf_SizeCategory(Context: Pointer; n: integer; args: PPSQLite3ValueArray); cdecl; {or stdcall if WinSqlite3.ddd} 
    var
      Count: integer;
      Result: string;
    begin
      Count := TSqlite3.AdfValueInt(Args[0]);
      case Count of
        0..500:       Result := 'Small';
        501..5000:    Result := 'Medium';
        5001..MaxInt: Result := 'Large';
      end;
      TSqlite3.AdfResultText(Context, Result);
    end;

    {...}
    
    DB.CreateFunction('SizeCategory', 1, @SqlAdf_SizeCategory);

    {...}
    
    with DB.Prepare(
      'SELECT OrgID, Name, Website, Country, Industry, Founded, EmployeeCount, SizeCategory(EmployeeCount) as SizeCat' +
      '  FROM Organizations' +
      ' WHERE Country LIKE ?' +
      '   AND SizeCat LIKE ?' +
      ' ORDER BY 2') do BindAndFetch([FCountry, FSizeCat], procedure
    begin
      {...}
    end
