Unit Rgd.Sqlite3FDE;

(***************************************************************************************************
 * This is a variation of Rgd.Sqlite3.pas that links the Delphi FireDAC Encryption (FDE) version
 * FireDAC.Phys.SQLiteWrapper.FDEStat. This statically linked pre-built version of Sqlite3 is
 * version 3.31.1.  It last version of Sqlite3 to support the Compile Option SQLITE_HAS_CODEC, which
 * is the encryption mechanism that FireDAC uses. It was removed Feb 7, 2020 as part of version 3.32.0.
 *
 * The approach taken here is to use a bit of FireDAC to create the connection (TFDConnection) to the
 * database including the password.  Once that is done we get the native PSqlite3 handle from
 * FireDAC.Phys.SQLiteWrapper.TSqliteDatabase(FFDConnection.CliObj).Handle and proceed as we do
 * in Rgd.Sqlite3.
 *
 * TODO - There is still some work to be done:
 *   (1) (TBD) Facilitate handling incorrect passwords - Maybe have DB.Open return True/False so we can easily
 *       create a retry loop for entering passwords.
 ***************************************************************************************************)

Interface

{$REGION ' Uses '}

uses
  WinApi.Windows,
  System.Types,
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.Diagnostics,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Comp.UI,
  FireDAC.Comp.Client,
  FireDAC.VCLUI.Wait,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper,
  FireDAC.Phys.SQLiteWrapper.FDEStat
  {$IFNDEF CONSOLE},Vcl.Dialogs, Vcl.Forms{$ENDIF};

{$ENDREGION}

{$REGION ' Sqlite3.dll Constants and Types '}

const
  {Return Values...}
  SQLITE_OK         = 0;
  SQLITE_ERROR      = 1;
  SQLITE_INTERNAL   = 2;
  SQLITE_PERM       = 3;
  SQLITE_ABORT      = 4;
  SQLITE_BUSY       = 5;
  SQLITE_LOCKED     = 6;
  SQLITE_NOMEM      = 7;
  SQLITE_READONLY   = 8;
  SQLITE_INTERRUPT  = 9;
  SQLITE_IOERR      = 10;
  SQLITE_CORRUPT    = 11;
  SQLITE_NOTFOUND   = 12;
  SQLITE_FULL       = 13;
  SQLITE_CANTOPEN   = 14;
  SQLITE_PROTOCOL   = 15;
  SQLITE_EMPTY      = 16;
  SQLITE_SCHEMA     = 17;
  SQLITE_TOOBIG     = 18;
  SQLITE_CONSTRAINT = 19;
  SQLITE_MISMATCH   = 20;
  SQLITE_MISUSE     = 21;
  SQLITE_NOLFS      = 22;
  SQLITE_AUTH       = 23;
  SQLITE_FORMAT     = 24;
  SQLITE_RANGE      = 25;
  SQLITE_NOTADB     = 26;
  SQLITE_NOTICE     = 27;
  SQLITE_WARNING    = 28;
  SQLITE_ROW        = 100;
  SQLITE_DONE       = 101;

  {Column Types...}
  SQLITE_INTEGER = 1;
  SQLITE_FLOAT   = 2;
  SQLITE_TEXT    = 3;
  SQLITE_BLOB    = 4;
  SQLITE_NULL    = 5;

  {Sqlite Open Flags...}
  SQLITE_OPEN_READONLY       = $00000001;
  SQLITE_OPEN_READWRITE      = $00000002;
  SQLITE_OPEN_CREATE         = $00000004;
  SQLITE_OPEN_DELETEONCLOSE  = $00000008;
  SQLITE_OPEN_EXCLUSIVE      = $00000010;
  SQLITE_OPEN_AUTOPROXY      = $00000020;
  SQLITE_OPEN_URI            = $00000040;
  SQLITE_OPEN_MEMORY         = $00000080;
  SQLITE_OPEN_MAIN_DB        = $00000100;
  SQLITE_OPEN_TEMP_DB        = $00000200;
  SQLITE_OPEN_TRANSIENT_DB   = $00000400;
  SQLITE_OPEN_MAIN_JOURNAL   = $00000800;
  SQLITE_OPEN_TEMP_JOURNAL   = $00001000;
  SQLITE_OPEN_SUBJOURNAL     = $00002000;
  SQLITE_OPEN_MASTER_JOURNAL = $00004000;
  SQLITE_OPEN_NOMUTEX        = $00008000;
  SQLITE_OPEN_FULLMUTEX      = $00010000;
  SQLITE_OPEN_SHAREDCACHE    = $00020000;
  SQLITE_OPEN_PRIVATECACHE   = $00040000;
  SQLITE_OPEN_WAL            = $00080000;
  SQLITE_OPEN_NOFOLLOW       = $01000000;
  SQLITE_OPEN_DEFAULT        = SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE;

type
  {Sqlite pointer types...}
  PSqlite3 = Pointer;
  PSqlite3Stmt = Pointer;
  PSqlite3Blob = Pointer;
  PSQLite3Context = Pointer;
  PSQLite3Value = Pointer;
  PPSQLite3ValueArray = ^TPSQLite3ValueArray;
  TPSQLite3ValueArray = array[0..MaxInt div SizeOf(PSQLite3Value) - 1] of PSQLite3Value;
  TSQLite3RegularFunction = procedure(ctx: PSQLite3Context; n: Integer; apVal: PPSQLite3ValueArray); cdecl;

{$ENDREGION}

type
  {Exception Object...}
  ESqliteError = class(Exception)
  private
    FErrorCode: integer;
  public
    constructor Create(Msg: string; ErrorCode: integer);
    property ErrorCode: integer read FErrorCode write FErrorCode;
  end;

  {Forwards...}
  ISqlite3Database    = interface;
  ISqlite3Statement   = interface;
  ISqlite3BlobHandler = interface;

  {Procedure References...}
  TProc     = reference to procedure;
  TStmtProc = reference to procedure(const Stmt: ISqlite3Statement);

  {Column, Param Accessors...}

  (*************************************************************************************************
   * TSqlParam and TSqlColumn are not intended to be declared as variables. These types are return
   * values for SqlColumn and SqlParam. The intent is to support fluent style,
   * such as Stmt.SqlColumn[i].AsText.
   *************************************************************************************************)

  TSqlParam = record
    [unsafe] FStmt: ISqlite3Statement;
    FParamIndex: integer;
    procedure BindDouble(const Value: Double);
    procedure BindInt(const Value: integer);
    procedure BindInt64(const Value: Int64);
    procedure BindText(const Value: string);
    procedure BindNull;
    procedure BindBlob(Data: Pointer; const Size: integer);
    procedure BindZeroBlob(const Size: integer);
  end;

  TSqlColumn = record
    [unsafe] FStmt: ISqlite3Statement;
    FColIndex: integer;
    function AsBool   : Boolean;
    function AsBytes  : integer;
    function AsDouble : Double;
    function AsInt    : integer;
    function AsInt64  : Int64;
    function AsText   : string;
    function ColName  : string;
    function ColType  : Integer;
    function IsNull   : Boolean;
  end;

  {ISqlite3* interfaces...}
  ISqlite3Database = interface
    ['{E6409C03-0409-46D3-99A6-7FCF27D72DF4}']
    {Getters...}
    function GetHandle: PSqlite3;
    function GetFilename: string;
    function GetBlobHandlerList: TList;
    function GetStatementList: TList;
    function GetTransactionOpen: Boolean;
    {Error Checking...}
    function Check(const ErrCode: integer): integer;
    procedure CheckHandle;
    {Open/Close...}
    procedure Open(const FileName: string; Password: string = '');
    procedure OpenIntoMemory(const FileName: string; Password: string = '');
    procedure Close;
    procedure Backup(const Filename: string);
    {Prepare...}
    function Prepare(const SQL: string): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const): ISqlite3Statement; overload;
    {Execute...}
    procedure Execute(const SQL: string); overload;
    procedure Execute(const SQL: string; const FmtParams: array of const); overload;
    function LastInsertRowID: Int64;
    {Fetching...}
    procedure Fetch(const SQL: string; const StmtProc: TStmtProc); overload;
    procedure Fetch(const SQL: string; const FmtParams: array of const; const StmtProc: TStmtProc); overload;
    function  FetchCount(const SQL: string): integer; overload;
    function  FetchCount(const SQL: string; const FmtParams: array of const): integer; overload;
    {Blobs...}
    function BlobOpen(const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean = True): ISqlite3BlobHandler;
    {Transactions...}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    procedure Transaction(const Proc: TProc); overload;
    {Application-Defined Functons...}
    procedure CreateFunction(Name: string; nArg: integer; xFunc: TSQLite3RegularFunction);
    {Properties...}
    property StatementList: TList read GetStatementList;
    property BlobHandlerList: TList read GetBlobHandlerList;
    property TransactionOpen: Boolean read GetTransactionOpen;
    property Handle: PSqlite3 read GetHandle;
    property Filename: string read GetFilename;
  end;

  ISqlite3Statement = interface
    ['{71D449C7-29BF-4C00-983E-52CFF11DB2B7}']
    {Getters...}
    function GetHandle: PSqlite3Stmt;
    function GetOwnerDatabase: ISqlite3Database;
    function GetSqlParam(const ParamIndex: integer): TSqlParam;
    function GetSqlParamByName(const ParamName: string): TSqlParam;
    function GetSqlColumn(const ColumnIndex: integer): TSqlColumn;
    {Binding, Stepping...}
    procedure ClearBindings;
    procedure BindParams(const Params: array of const); overload;
    procedure BindParams(const Params: TArray<string>); overload;
    function BindAndStep(const Params: array of const): integer; overload;
    function BindAndStep(const Params: TArray<string>): integer; overload;
    function  Step: integer;
    function  StepAndReset: integer; overload;
    {Fetching, Updating...}
    procedure Reset;
    procedure Fetch(const StepProc: TProc);
    procedure BindAndFetch(const Params: array of const; const StepProc: TProc);
    function SqlColumnCount: integer;
    {Properties...}
    property Handle: PSqlite3Stmt read GetHandle;
    property OwnerDatabase: ISqlite3Database read GetOwnerDatabase;
    property SqlParam[const ParamIndex: integer]: TSqlParam read GetSqlParam;
    property SqlParamByName[const ParamName: string]: TSqlParam read GetSqlParamByName;
    property SqlColumn[const ColumnIndex: integer]: TSqlColumn read GetSqlColumn;
  end;

  ISqlite3BlobHandler = interface
    ['{4C92524F-F899-4095-9127-0DD50927D0C0}']
    {Getters...}
    function GetHandle: PSqlite3Blob;
    function GetOwnerDatabase: ISqlite3Database;
    {Read/Write...}
    function Bytes: integer;
    procedure Read (Buffer: Pointer; const Size, Offset: integer);
    procedure Write(Buffer: Pointer; const Size, Offset: integer);
    {Properties}
    property Handle: PSqlite3Blob read GetHandle;
    property OwnerDatabase: ISqlite3Database read GetOwnerDatabase;
  end;

  {TSqlite3* classes implementing ISqlite3*...}
  TSqlite3Database = class(TInterfacedObject, ISqlite3Database)
    (***********************************************************************************************
     * FYI: The TSqlite3Database object maintains a list of pointers to related ISqlite3Statement
     *      and ISqlite3BlobHandler interfaces in order to close finalize any open Statements prior
     *      to closing the database connection.  This is usually not the case, but sometimes it is
     *      hard to control when an ISqlite3Statement goes out of scope and gets destroyed
     *      due to how anonomous method variable capture and with statements will extend the
     *      life of variables until the end of the current method. In such cases, for example,
     *      calling DB.Close in the same method where a ISqlite3Statement is still in scope would
     *      fail due to having an unfinalized Statement handle. DB.Close will go ahead and conveniently
     *      finalize any unfinalized statement handles prior to closing the database connection to
     *      avoid this situation.
     ***********************************************************************************************)
  private
    FFDConnection: TFDConnection;
    FFilename: string;
    FTransactionOpen: Boolean;
    FStatementList: TList;
    FBlobHandlerList: TList;
    {Getters...}
    function GetHandle: PSqlite3;
    function GetFilename: string;
    function GetStatementList: TList;
    function GetBlobHandlerList: TList;
    function GetTransactionOpen: Boolean;
    {Error Checking...}
    function Check(const ErrCode: integer): integer;
    procedure CheckHandle;
    {Open/Close...}
    procedure Open(const FileName: string; Password: string = '');
    procedure OpenIntoMemory(const FileName: string; Password: string = '');
    procedure Close;
    procedure Backup(const Filename: string);
    {Prepare SQL...}
    function Prepare(const SQL: string): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const): ISqlite3Statement; overload;
    {Execute...}
    procedure Execute(const SQL: string); overload;
    procedure Execute(const SQL: string; const FmtParams: array of const); overload;
    function LastInsertRowID: Int64;
    {Fetch, Updating...}
    procedure Fetch(const SQL: string; const StmtProc: TStmtProc); overload;
    procedure Fetch(const SQL: string; const FmtParams: array of const; const StmtProc: TStmtProc); overload;
    function FetchCount(const SQL: string): integer; overload;
    function FetchCount(const SQL: string; const FmtParams: array of const): integer; overload;
    {Blobs}
    function BlobOpen(const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean): ISqlite3BlobHandler;
    {Transactions...}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    procedure Transaction(const Proc: TProc); overload;
    {Application-Defined Functons...}
    procedure CreateFunction(Name: string; nArg: integer; xFunc: TSQLite3RegularFunction);
    {Properties...}
    property Handle: PSqlite3 read GetHandle;
  public
    {Constructor/Destructor...}
    constructor Create;
    destructor Destroy; override;
  end;

  TSQLite3Statement = class(TInterfacedObject, ISqlite3Statement)
  private
    FHandle: PSqlite3Stmt;
    FOwnerDatabase: ISqlite3Database;
    {Getters}
    function GetHandle: PSqlite3Stmt;
    function GetOwnerDatabase: ISqlite3Database;
    function GetSqlColumn(const ColumnIndex: integer): TSqlColumn;
    function GetSqlParam(const ParamIndex: integer): TSqlParam;
    function GetSqlParamByName(const ParamName: string): TSqlParam;
    {Binding, Stepping...}
    procedure ClearBindings;
    procedure BindParams(const Params: array of const); overload;
    procedure BindParams(const Params: TArray<string>); overload;
    function BindAndStep(const Params: array of const): integer; overload;
    function BindAndStep(const Params: TArray<string>): integer; overload;
    function Step: integer;
    function StepAndReset: integer; overload;
    {Fetching, Updating}
    procedure Reset;
    procedure Fetch(const FetchProc: TProc);
    procedure BindAndFetch(const Params: array of const; const StepProc: TProc);
    function SqlColumnCount: integer;
  public
    {Constructor/Destructor}
    constructor Create(OwnerDatabase: ISqlite3Database; const SQL: string);
    destructor Destroy; override;
  end;

  TSqlite3BlobHandler = class(TInterfacedObject, ISqlite3BlobHandler)
  private
    FHandle: PSqlite3Blob;
    FOwnerDatabase: ISqlite3Database;
    {Getters...}
    function GetHandle: PSqlite3Blob;
    function GetOwnerDatabase: ISqlite3Database;
    {Read/Write Blob...}
    function Bytes: integer;
    procedure Read (Buffer: Pointer; const Size, Offset: integer);
    procedure Write(Buffer: Pointer; const Size, Offset: integer);
  public
    constructor Create(OwnerDatabase: ISqlite3Database; const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean = True);
    destructor Destroy; override;
  end;

  {General Global Sqlite functions...}
  TSqlite3 = class
  private
    class var FSqliteVersion: string;
  public
    class function ThreadSafe: Boolean;
    class function LibPath: string;
    class function VersionStr: string;
    class function CompileOptions: string;
    class function OpenDatabase(const FileName: string; Password: string = ''): ISqlite3Database;
    class function OpenDatabaseIntoMemory(const FileName: string): ISqlite3Database;
    class procedure ChangePassword(DbFilename: string; OldPassword, NewPassword: string);
    {Application Defined function helpers...}
    class function ValueText(Value: PSqlite3Value): string;
    class function ValueInt(Value: PSqlite3Value): integer;
    class function ValueInt64(Value: PSqlite3Value): Int64;
    class function ValueDouble(Value: PSqlite3Value): Double;
    class procedure ResultText(Context: PSQLite3Context; Result: string);
    class procedure ResultInt(Context: PSQLite3Context; Result: integer);
    class procedure ResultInt64(Context: PSQLite3Context; Result: Int64);
    class procedure ResultDouble(Context: PSQLite3Context; Result: Double);
  end;

var
  DB: ISqlite3Database;

Implementation

{$REGION ' Sqlite DLL Api Externals '}

(***********************************************************************
 *  This is the minimum set of sqlite3 definitions
 *  required to support this unit. (from sqlite3.h)
 *
 *  If linking Sqlite3 statically via FireDAC.Phys.SQLiteWrapper.Stat,
 *  then the Sqlite3 functions come from there.  Since I don't
 *  have the source code to FireDAC, I had to figure out the param
 *  types used by using the IDE editor hints.  I have since modified
 *  the dll function prototypes to match FireDAC in order to have a single
 *  unit that can switch between Static/DLL by defining SQLITE_STATIC.
 *  FireDac likes to use PByte instead of PAnsiChar, so some additional
 *  typecasting is needed below.
 *  FireDAC param types:
 *    PByte (System.Types) = System.Byte = ^Byte
 *    PUtf8 (FiresDAC.Phys.SqliteCli) = PFDAnsiString = PAnsiChar
 *    PFDAnsiChar (FireDAC.Stan.Intf) = PAnsiChar
 ***********************************************************************)
const
  SQL_NTS = -1;
  SQLITE_TRANSIENT = Pointer(-1);
  SQLITE_UTF8 = $00000001;
  SQLITE_DETERMINISTIC = $00000800;

type
  PPAnsiCharArray = ^TPAnsiCharArray;
  TPAnsiCharArray = array[0..MaxInt div SizeOf(PAnsiChar) - 1] of PAnsiChar;
  TSqliteCallback = function(pArg: Pointer; nCol: Integer; argv: PPAnsiCharArray; colv: PPAnsiCharArray): Integer; cdecl;
  PSqliteBackup   = Pointer;
  PUtf8           = PAnsiChar;
  TSqlite3_Destroy_Callback = procedure(p: Pointer); cdecl;

{$ENDREGION}

{$REGION ' ESqliteError '}

const
  SErrorMessage           = 'Sqlite error: [%d] %s';
  SDatabaseNotConnected   = 'Sqlite error: database is not connected';
  STransactionAlreadyOpen = 'Transaction is already opened';
  SNoTransactionOpen      = 'No transaction is open';
  SParamCountMismatch     = 'Parameter Count Mismatch in BindParams';
  STypeNotSupported       = 'VType %d not supported in BindParams()';
  SImproperSQL            = 'Incorrect SQL for this function, must be SELECT COUNT()';

constructor ESqliteError.Create(Msg: string; ErrorCode: integer);
begin
  inherited Create(Msg);
  FErrorCode := ErrorCode;
end;

{$ENDREGION}

{$REGION ' TSqlParam '}

procedure TSqlParam.BindDouble(const Value: Double);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_double(FStmt.Handle, FParamIndex, Value));
end;

procedure TSqlParam.BindInt(const Value: integer);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_int(FStmt.Handle, FParamIndex, Value));
end;

procedure TSqlParam.BindInt64(const Value: Int64);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_int64(FStmt.Handle, FParamIndex, Value));
end;

procedure TSqlParam.BindText(const Value: string);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_text(FStmt.Handle, FParamIndex, PByte(PUtf8(UTF8Encode(Value))), SQL_NTS, SQLITE_TRANSIENT));
end;

procedure TSqlParam.BindNull;
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_null(FStmt.Handle, FParamIndex));
end;

procedure TSqlParam.BindBlob(Data: Pointer; const Size: integer);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_blob(FStmt.Handle, FParamIndex, Data, Size, SQLITE_TRANSIENT));
end;

procedure TSqlParam.BindZeroBlob(const Size: integer);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_zeroblob(FStmt.Handle, FParamIndex, Size));
end;

{$ENDREGION}

{$REGION ' TSqlColumn '}

function TSqlColumn.AsBool: Boolean;
begin
  Result := Boolean(sqlite3_column_int(FStmt.Handle, FColIndex));
end;

function TSqlColumn.AsBytes: Integer;
begin
  Result := sqlite3_column_bytes(FStmt.Handle, FColIndex);
end;

function TSqlColumn.AsDouble: Double;
begin
  Result := sqlite3_column_double(FStmt.Handle, FColIndex);
end;

function TSqlColumn.AsInt: integer;
begin
  Result := sqlite3_column_int(FStmt.Handle, FColIndex);
end;

function TSqlColumn.AsInt64: Int64;
begin
  Result := sqlite3_column_int64(FStmt.Handle, FColIndex);
end;

function TSqlColumn.AsText: string;
begin
  Result := UTF8ToString(PUtf8(sqlite3_column_text(FStmt.Handle, FColIndex)));
end;

function TSqlColumn.ColName: string;
begin
  Result := UTF8ToString(PUtf8(sqlite3_column_name(FStmt.Handle, FColIndex)));
end;

function TSqlColumn.ColType: integer;
begin
  Result := sqlite3_column_type(FStmt.Handle, FColIndex);
end;

function TSqlColumn.IsNull: Boolean;
begin
  Result := ColType = SQLITE_NULL;
end;

{$ENDREGION}

{$REGION ' TSqlite3Database '}

constructor TSqlite3Database.Create;
begin
  FFDConnection := TFDConnection.Create(nil);
  FBlobHandlerList := TList.Create;
  FStatementList := TList.Create;
end;

destructor TSqlite3Database.Destroy;
begin
  FFDConnection.Free; {I'm guessing that the TFDConnection.Destroy calls close}
  FBlobHandlerList.Free;
  FStatementList.Free;
  inherited;
end;

function TSqlite3Database.Check(const ErrCode: integer): integer;
begin
  if ErrCode in [SQLITE_OK, SQLITE_ROW, SQLITE_DONE] then
    Result := ErrCode
  else
    raise ESqliteError.Create(Format(SErrorMessage, [ErrCode, UTF8ToString(PAnsiChar(sqlite3_errmsg(Handle)))]), ErrCode);
end;

procedure TSqlite3Database.CheckHandle;
begin
  if Handle = nil then
    raise ESqliteError.Create(SDatabaseNotConnected, -1);
end;

function TSqlite3Database.GetFilename: string;
begin
  Result := FFilename;
end;

function TSqlite3Database.GetHandle: PSqlite3;
begin
  Result := FireDAC.Phys.SQLiteWrapper.TSqliteDatabase(FFDConnection.CliObj).Handle;
end;

function TSqlite3Database.GetTransactionOpen: Boolean;
begin
  Result := FTransactionOpen;
end;

function TSqlite3Database.GetStatementList: TList;
begin
  Result := FStatementList;
end;

function TSqlite3Database.GetBlobHandlerList: TList;
begin
  Result := FBlobHandlerList;
end;

procedure TSqlite3Database.Open(const FileName: string; Password: string = '');
begin
  Close;
  FFilename := FileName;
  FFDConnection.DriverName := 'SQLite';
  FFDConnection.Params.Database := Filename;
  FFDConnection.Params.Password := Password;
  FFDConnection.Open;
  if not SameText(Filename, ':memory:') then
  begin
    Execute('pragma journal_mode=memory');   //delete,truncate,persist,memory,off
    Execute('pragma synchronous=0');         //0=off, 1=normal,2=full,3=extra
  end;
end;

procedure TSqlite3Database.OpenIntoMemory(const FileName: string; Password: string = '');
var
  SqliteDriverLink: TFDPhysSqliteDriverLink;
  SqliteBackup: TFDSqliteBackup;
begin
  Open(':memory:', Password);
  SqliteDriverLink := TFDPhysSqliteDriverLink.Create(nil);
  SqliteDriverLink.EngineLinkage := slFDEStatic;
  SqliteBackup := TFDSqliteBackup.Create(nil);
  try
    SqliteBackup.DriverLink := SqliteDriverLink;
    SqliteBackup.Database := FileName;
    SqliteBackup.Password := Password;
    SqliteBackup.DestMode := smCreate;
    SqliteBackup.DestDatabaseObj := FFDConnection.CliObj;
    SqliteBackup.DestPassword := Password;
    SqliteBackup.Backup;
  finally
    SqliteBackup.Free;
    SqliteDriverLink.Free;
  end;
end;

procedure TSqlite3Database.Backup(const Filename: string);
{Remark: VACUUM INTO was introduced in Sqlite3 version 3.27.0
         VACUUM INTO does uses a few more CPU cycles, but target DB is vaccuumed}
begin
  DeleteFile(Filename);
  Execute('VACUUM INTO %s', [QuotedStr(Filename)]) {introduced in version 3.27.0}
end;

procedure TSqlite3Database.Close;
begin
  if FFDConnection.Connected then
  begin
    {Rollback if transaction left open (sqlite should do this automatically, but we are doing it explcitly anyway)...}
    if FTransactionOpen then
      Rollback;

    {Finalize, if any, remaining open Stmt handles...}
    for var i := FStatementList.Count-1 downto 0 do
    begin
      sqlite3_finalize(TSqlite3Statement(FStatementList[i]).FHandle);
      TSqlite3Statement(FStatementList[i]).FHandle := nil;
      FStatementList.Delete(i);
    end;

    {Close, if  any, remaining open Blob handlers...}
    for var i := 0 to FBlobHandlerList.Count-1 do
    begin
      sqlite3_blob_close(TSqlite3BlobHandler(FBlobHandlerList[i]).FHandle);
      TSqlite3BlobHandler(FBlobHandlerList[i]).FHandle := nil;
      FBlobHandlerList.Delete(i);
    end;

    FFDConnection.Close;
    FFilename := '';
  end;
end;

function TSqlite3Database.Prepare(const SQL: string): ISqlite3Statement;
begin
  CheckHandle;
  Result := TSQLite3Statement.Create(Self, SQL);
end;

function TSqlite3Database.Prepare(const SQL: string; const FmtParams: array of const): ISqlite3Statement;
begin
  Result := Prepare(Format(SQL, FmtParams));
end;

procedure TSqlite3Database.Fetch(const SQL: string; const StmtProc: TStmtProc);
var
  Stmt: ISqlite3Statement;
begin
  Stmt := Prepare(SQL);
  while Stmt.Step = SQLITE_ROW do
    StmtProc(Stmt);
end;

procedure TSqlite3Database.Fetch(const SQL: string; const FmtParams: array of const; const StmtProc: TStmtProc);
begin
  Fetch(Format(SQL, FmtParams), StmtProc);
end;

function TSqlite3Database.FetchCount(const SQL: string): integer;
begin
  Assert(ContainsText(SQL, 'SELECT Count('), SImproperSQL);
  with Prepare(SQL) do
  begin
    Step;
    Result := SqlColumn[0].AsInt;
  end;
end;

function TSqlite3Database.FetchCount(const SQL: string; const FmtParams: array of const): integer;
begin
  Result := FetchCount(Format(SQL, FmtParams));
end;

procedure TSqlite3Database.Execute(const SQL: string);
begin
  CheckHandle;
  Check(sqlite3_exec(Handle, PByte(PUtf8(UTF8Encode(SQL))), nil, nil, nil));
end;

procedure TSqlite3Database.Execute(const SQL: string; const FmtParams: array of const);
begin
  Execute(Format(SQL, FmtParams));
end;

function TSqlite3Database.LastInsertRowID: Int64;
begin
  CheckHandle;
  Result := sqlite3_last_insert_rowid(Handle);
end;

function TSqlite3Database.BlobOpen(const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean): ISqlite3BlobHandler;
begin
  Result := TSqlite3BlobHandler.Create(Self, Table, Column, RowID, WriteAccess);
end;

procedure TSqlite3Database.BeginTransaction;
begin
  if not FTransactionOpen then
  begin
    Execute('BEGIN TRANSACTION');
    FTransactionOpen := True;
  end
  else
    raise ESqliteError.Create(STransactionAlreadyOpen, -1);
end;

procedure TSqlite3Database.Commit;
begin
  if FTransactionOpen then
  begin
    Execute('COMMIT');
    FTransactionOpen := False;
  end
  else
    raise ESqliteError.Create(SNoTransactionOpen, -1);
end;

procedure TSqlite3Database.Rollback;
begin
  if FTransactionOpen then
  begin
    Execute('ROLLBACK');
    FTransactionOpen := False;
  end
  else
    raise ESqliteError.Create(SNoTransactionOpen, -1);
end;

procedure TSqlite3Database.Transaction(const Proc: TProc);
begin
  BeginTransaction;
  try
    Proc;
    Commit;
  finally
    if FTransactionOpen then
      Rollback;
  end;
end;

procedure TSqlite3Database.CreateFunction(Name: string; nArg: integer; xFunc: TSQLite3RegularFunction);
(***************************************************************************************************
 *  Application Defined Functions
 *
 *  Can't define an application-defined function anonmously.  It has to be cdecl.
 *
 *  Anyway, Define your application-defined sqlite function something like the following:
 *
 *    procedure MyFunction(Ctx: Pointer; n: integer; Args: PPSQLite3ValueArray); cdecl;
 *    begin
 *      var Arg := TSqlite3.ValueText(args[0]);
 *      var Result := SomeFunction(Arg);
 *      TSqlite3.ResultText(Context, Result);
 *    end;
 *
 *  To Register the function, call:
 *    DB.CreateFunction('MyFunction', @MyFunction);
 *
 *  After that, you can use the function in SQL statements
 *    SELECT MyFunction(MyField) FROM MyTable;
 ***************************************************************************************************)
begin
  sqlite3_create_function(Handle, PByte(PUtf8(UTF8Encode(Name))), nArg, SQLITE_UTF8 or SQLITE_DETERMINISTIC, nil, @xFunc, nil, nil);
end;

{$ENDREGION}

{$REGION ' TSqlite3Statment '}

constructor TSQLite3Statement.Create(OwnerDatabase: ISqlite3Database; const SQL: string);
begin
  FOwnerDatabase := OwnerDatabase;
  FOwnerDatabase.CheckHandle;
  var pzTail:PByte := nil;
  FOwnerDatabase.Check(sqlite3_prepare_v2(FOwnerDatabase.Handle, PByte(PUtf8(UTF8Encode(SQL))), SQL_NTS, FHandle, pzTail));
  FOwnerDatabase.StatementList.Add(Pointer(Self));
end;

destructor TSQLite3Statement.Destroy;
begin
  if Assigned(FHandle) then
  begin
    FOwnerDatabase.StatementList.Remove(Pointer(Self));
    sqlite3_finalize(FHandle);
  end;
  inherited;
end;

function TSQLite3Statement.GetHandle: PSqlite3Stmt;
begin
  Result := FHandle;
end;

function TSQLite3Statement.GetOwnerDatabase: ISqlite3Database;
begin
  Result := FOwnerDatabase;
end;

function TSQLite3Statement.GetSqlParam(const ParamIndex: integer): TSqlParam;
begin
  Result.FStmt := Self;
  Result.FParamIndex := ParamIndex;
end;

function TSQLite3Statement.GetSqlParamByName(const ParamName: string): TSqlParam;
begin
  Result.FStmt := Self;
  Result.FParamIndex := sqlite3_bind_parameter_index(FHandle, PUtf8(UTF8Encode(ParamName)));
end;

function TSQLite3Statement.GetSqlColumn(const ColumnIndex: integer): TSqlColumn;
begin
  Result.FStmt := Self;
  Result.FColIndex := ColumnIndex;
end;

procedure TSQLite3Statement.ClearBindings;
begin
  FOwnerDatabase.Check(sqlite3_clear_bindings(FHandle));
end;

procedure TSQLite3Statement.BindParams(const Params: array of const);
var
  ParamInt: integer;
  ParamInt64: Int64;
  ParamDouble: Double;
  ParamString: string;
  ASqlParam: TSqlParam;
begin
  Assert(High(Params) = sqlite3_bind_parameter_count(FHandle)-1, SParamCountMismatch);

  {Reset and Bind all params...}
  Reset;
  for var i := 0 to High(Params) do
  begin
    ASqlParam := GetSqlParam(i+1);
    case Params[i].VType of
      vtWideString:
        begin
          ParamString := PWideChar(Params[i].VWideString);
          ASqlParam.BindText(ParamString);
        end;
      vtUnicodeString:
        begin
          ParamString := PWideChar(Params[i].VUnicodeString);
          ASqlParam.BindText(ParamString);
        end;
      vtInteger:
        begin
          ParamInt := Params[i].VInteger;
          ASqlParam.BindInt(ParamInt);
        end;
      vtExtended:
        begin
          ParamDouble := Params[i].VExtended^;
          ASqlParam.BindDouble(ParamDouble);
        end;
      vtInt64:
        begin
          ParamInt64 := Params[i].VInt64^;
          ASqlParam.BindInt64(ParamInt64);
        end;
      vtPointer:
        begin
          if Params[i].VPointer <> nil then
            raise Exception.CreateFmt(STypeNotSupported, [Params[i].VType]);
        end;
    else
      raise Exception.CreateFmt(STypeNotSupported, [Params[i].VType]);
    end;
  end;
end;

procedure TSQLite3Statement.BindParams(const Params: TArray<string>);
begin
  Assert(High(Params)+1 = sqlite3_bind_parameter_count(FHandle), SParamCountMismatch);

  {Reset and BindText all params...}
  Reset;
  for var i := 0 to High(Params) do
    GetSqlParam(i+1).BindText(Params[i]);
end;

function TSQLite3Statement.BindAndStep(const Params: array of const): integer;
begin
  BindParams(Params);
  Result := Step;
end;

function TSQLite3Statement.BindAndStep(const Params: TArray<string>): integer;
begin
  BindParams(Params);
  Result := Step;
end;

function TSQLite3Statement.Step: integer;
begin
  Result := FOwnerDatabase.Check(sqlite3_step(FHandle));
end;

function TSQLite3Statement.StepAndReset: integer;
begin
  Result := FOwnerDatabase.Check(sqlite3_step(FHandle));
  Reset;
end;

procedure TSQLite3Statement.Reset;
begin
  FOwnerDatabase.Check(sqlite3_reset(FHandle));
end;

procedure TSQLite3Statement.Fetch(const FetchProc: TProc);
begin
  while Step = SQLITE_ROW do
    FetchProc;
end;

procedure TSQLite3Statement.BindAndFetch(const Params: array of const; const StepProc: TProc);
begin
  BindParams(Params);
  while Step = SQLITE_ROW do
    StepProc;
end;

function TSQLite3Statement.SqlColumnCount: integer;
begin
  Result := sqlite3_column_count(FHandle);
end;

{$ENDREGION}

{$REGION ' TSqlite3BlobHandler '}

constructor TSqlite3BlobHandler.Create(OwnerDatabase: ISqlite3Database; const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean);
begin
  FOwnerDatabase := OwnerDatabase;
  FOwnerDatabase.CheckHandle;
  FOwnerDatabase.Check(sqlite3_blob_open(FOwnerDatabase.Handle, 'main', PUtf8(UTF8Encode(Table)), PUtf8(UTF8Encode(Column)), RowID, Ord(WriteAccess), FHandle));
  FOwnerDatabase.BlobHandlerList.Add(Self);
end;

destructor TSqlite3BlobHandler.Destroy;
begin
  if Assigned(FHandle) then
  begin
    sqlite3_blob_close(FHandle);
    FOwnerDatabase.BlobHandlerList.Remove(Self);
  end;
  inherited;
end;

function TSqlite3BlobHandler.GetHandle: PSqlite3Blob;
begin
  Result := FHandle;
end;

function TSqlite3BlobHandler.GetOwnerDatabase: ISqlite3Database;
begin
  Result := FOwnerDatabase;
end;

function TSqlite3BlobHandler.Bytes: integer;
begin
  Result := sqlite3_blob_bytes(FHandle);
end;

procedure TSqlite3BlobHandler.Read(Buffer: Pointer; const Size, Offset: integer);
begin
  FOwnerDatabase.Check(sqlite3_blob_read(FHandle, Buffer, Size, Offset));
end;

procedure TSqlite3BlobHandler.Write(Buffer: Pointer; const Size, Offset: integer);
begin
  FOwnerDatabase.Check(sqlite3_blob_write(FHandle, Buffer, Size, Offset));
end;

{$ENDREGION}

{$REGION ' TSqlite3 Class Functions '}

class function TSqlite3.VersionStr: string;
begin
  if FSqliteVersion = '' then
    FSqliteVersion := UTF8ToString(sqlite3_libversion);
  Result := FSqliteVersion;
end;

class function TSqlite3.CompileOptions: string;
begin
  Result := '';
  with OpenDatabase(':memory:', '').Prepare('PRAGMA compile_options') do
    while Step = SQLITE_ROW do
      Result := Result + SqlColumn[0].AsText + #13#10;
end;

class function TSqlite3.LibPath: string;
begin
  Result := 'FireDAC.Phys.SQLiteWrapper.FDEStat';
end;

class function TSqlite3.OpenDatabase(const FileName: string; Password: string = ''): ISqlite3Database;
begin
  Result := TSqlite3Database.Create;
  Result.Open(Filename, Password);
end;

class function TSqlite3.OpenDatabaseIntoMemory(const FileName: string): ISqlite3Database;
begin
  Result := TSqlite3Database.Create;
  Result.OpenIntoMemory(Filename);
end;

class function TSqlite3.ThreadSafe: Boolean;
begin
  Result := TRUE;
end;

class procedure TSqlite3.ChangePassword(DbFilename: string; OldPassword, NewPassword: string);
var
  SqliteDriverLink: TFDPhysSqliteDriverLink;
  Security: TFDSQLiteSecurity;
begin
  SqliteDriverLink := TFDPhysSqliteDriverLink.Create(nil);
  Security := TFDSQLiteSecurity.Create(nil);
  try
    SqliteDriverLink.EngineLinkage := slFDEStatic;
    Security.DriverLink := SqliteDriverLink;
    Security.Database := DbFileName;
    Security.Password := OldPassword;

    if NewPassword <> '' then
    begin
      Security.ToPassword := NewPassword;
      Security.ChangePassword;
    end
    else
    begin
      Security.ToPassword := '';
      Security.RemovePassword;
    end;

  finally
    Security.Free;
    SqliteDriverLink.Free;
  end;
end;

class function TSqlite3.ValueText(Value: PSqlite3Value): string;
begin
  Result := UTF8ToString(PUtf8(sqlite3_value_text(Value)));
end;

class function TSqlite3.ValueInt(Value: PSqlite3Value): integer;
begin
  Result := sqlite3_value_int(Value);
end;

class function TSqlite3.ValueInt64(Value: PSqlite3Value): Int64;
begin
  Result := sqlite3_value_int64(Value);
end;

class function TSqlite3.ValueDouble(Value: PSqlite3Value): Double;
begin
  Result := sqlite3_value_Double(Value);
end;

class procedure TSqlite3.ResultText(Context: PSQLite3Context; Result: string);
begin
  sqlite3_result_text(Context, PByte(PUtf8(UTF8Encode(Result))), SQL_NTS, nil);
end;

class procedure TSqlite3.ResultInt(Context: PSQLite3Context; Result: integer);
begin
  sqlite3_result_int(Context, Result);
end;

class procedure TSqlite3.ResultInt64(Context: PSQLite3Context; Result: Int64);
begin
  sqlite3_result_int64(Context, Result);
end;

class procedure TSqlite3.ResultDouble(Context: PSQLite3Context; Result: Double);
begin
  sqlite3_result_Double(Context, Result);
end;

{$ENDREGION}

Initialization
begin
  FDManager.SilentMode := True;
end;

End.
