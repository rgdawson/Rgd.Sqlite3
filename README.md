# Rgd.Sqlite3
Simple, effective Sqlite3 interface unit

  Rgd.SQLite3 for Delphi - A light-wieght SQlite3 interface

  Credits: This unit borrows ideas from Yury Plashenkov in https://github.com/plashenkov/SQLite3-Delphi-FPC.
           Rgd.Sqlite3 for Delphi is implemented using interfaced objects and anonomous methods, the ideas
           for which I got by reading "Coding in Delphi" by Nick Hodges.

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
        '   Name                      TEXT,' +
        '   Website                   TEXT,' +
        '   Country                   TEXT,' +
        '   Description               TEXT,' +
        '   Founded                   TEXT,' +
        '   Industry                  TEXT,' +
        '   EmployeeCount             INTEGER,' +
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
            with DB.Prepare('INSERT INTO Organizations VALUES (?, ?, ?, ?, ?, ?, ?)') do
            begin
              for S in Lines do
              begin
                Fields.CommaText := S;
                BindAndStep([Fields[2], Fields[3], Fields[4], Fields[5], Fields[6], Fields[7], Fields[8]]);
              end;
            end;
        end);
      finally
        Fields.Free;
        Lines.Free;
      end;
      DB.Execute('ANALYZE');
    end;
