# Rgd.Sqlite3
Simple, effective Sqlite3 interface unit

  Rgd.SQLite3 for Delphi - A light-weight Sqlite3 interface

Credits:

This unit borrows ideas from Yury Plashenkov in https://github.com/plashenkov/SQLite3-Delphi-FPC,
which I have always admired for its genius simplicity and clarity.  With Yuri's concepts in mind,
Rgd.Sqlite3 for Delphi is implemented using interfaced objects and anonomous methods, the ideas
for which I got by reading "Coding in Delphi" by Nick Hodges, plus some flexible goodies for
binding and fetching data, and performing transactions.

Query Patterns:

    {Example Pattern 1 - Stmt := DB.Prepare() and while Stmt.Step...}
    var
      Stmt: ISqlite3Statement;
    begin
      Stmt := DB.Prepare(
        'SELECT Name,' +
        '       ID' +
        '  FROM Tasks');
      while Stmt.Step = SQLITE_ROW do
      being
        S0 := Stmt.SqlColumn[0].AsText;
        ID := Stmt.SqlColumn[1].AsInt;
        {...}
      end);
    end;

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

    {Pattern 3 - DB.Fetch(SQL, procedure(const Stmt: ISQlite3Statement)...}
    DB.Fetch(
      'SELECT Name,' +
      '       ID'    +
      '  FROM Tasks', procedure(const Stmt: ISQlite3Statement)
    begin
      S0 := Stmt.SqlColumn[0].AsText;
      ID := Stmt.SqlColumn[1].AsInt;
      {...}
    end;
  
Create Datatabase pattern...
    
    procedure TMainForm.CreateDatabase;
    begin
      DB := TSqlite3Database.Create;
      DB.Open(':memory:');
      
      {Create Table...}
      DB.Execute(
        ' CREATE TABLE Organizations ( ' +
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
        ' WHERE Name = ?', SQLITE_PREPARE_PERSISTENT);
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
