Unit Rgd.Sqlite3;

{$DEFINE SQLITE_STATIC}

{^^^ With SQLITE_STATIC is defined, then the sqlite3 library contained in FireDAC.Phys.SQLiteWrapper.Stat
     will be statically linked into executable and a sqlite3.dll file will not be used/required.  As of
     Delphi Version 12.2, this is Sqlite3 version 3.46.0}

Interface

{$REGION ' Uses '}

uses
  WinApi.Windows,
  System.Types,
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.Diagnostics
  {$IFDEF SQLITE_STATIC},FireDAC.Phys.SQLiteWrapper.Stat{$ENDIF}
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

  {Sqlite Prepare Flags...}
  SQLITE_PREPARE_DEFAULT    = $00;
  SQLITE_PREPARE_PERSISTENT = $01;
  SQLITE_PREPARE_NORMALIZE  = $02; {deprecated, no-op}
  SQLITE_PREPARE_NO_VTAB    = $04;

type
  {Sqlite pointer types...}
  PSqlite3     = Pointer;
  PSqlite3Stmt = Pointer;
  PSqlite3Blob = Pointer;

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

  {Remark: TSqlParam and TSqlColumn are not intended to be declared as variables.
           These types are return values for SqlColumn and SqlParam. The intent
           is to support fluent style, such as Stmt.SqlColumn[i].AsText.}

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
    function GetStatementList: TList;
    function GetTransactionOpen: Boolean;
    {Error Checking...}
    function Check(const ErrCode: integer): integer;
    procedure CheckHandle;
    {Open/Close...}
    procedure Open(const FileName: string; OpenFlags: integer = SQLITE_OPEN_DEFAULT);
    procedure OpenIntoMemory(const FileName: string);
    procedure Close;
    procedure Backup(const Filename: string);
    {Prepare...}
    function Prepare(const SQL: string; PrepFlags: Cardinal = SQLITE_PREPARE_DEFAULT): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const; PrepFlags: Cardinal = SQLITE_PREPARE_DEFAULT): ISqlite3Statement; overload;
    {Transactions...}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    procedure Transaction(const Proc: TProc); overload;
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
    {Properties...}
    property StatementList: TList read GetStatementList;
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
  private
    FHandle: PSqlite3;
    FFilename: string;
    FTransactionOpen: Boolean;
    FStatementList: TList;
    {Getters...}
    function GetHandle: PSqlite3;
    function GetFilename: string;
    function GetStatementList: TList;
    function GetTransactionOpen: Boolean;
    {Error Checking...}
    function Check(const ErrCode: integer): integer;
    procedure CheckHandle;
    {Open/Close...}
    procedure Open(const FileName: string; OpenFlags: integer);
    procedure Close;
    procedure OpenIntoMemory(const FileName: string);
    procedure Backup(const Filename: string);
    {Prepare SQL...}
    function Prepare(const SQL: string; PrepFlags: Cardinal): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const; PrepFlags: Cardinal): ISqlite3Statement; overload;
    {Transactions...}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    procedure Transaction(const Proc: TProc); overload;
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
    property Handle: PSqlite3 read GetHandle;
  public
    {Constructor/Destructor...}
    constructor Create; overload;
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
    constructor Create(OwnerDatabase: ISqlite3Database; const SQL: string; PrepFlags: Cardinal = SQLITE_PREPARE_DEFAULT);
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
    class function ThreadSafe: Boolean; static;
    class function LibPath: string; static;
    class function Version: DWORD; static;
    class function VersionStr: string; static;
    class function CompileOptions: string; static;
    class function OpenDatabase(const FileName: string; OpenFlags: integer = SQLITE_OPEN_DEFAULT): ISqlite3Database; static;
    class function OpenDatabaseIntoMemory(const FileName: string): ISqlite3Database; static;
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
var
  SQLITE3_VERSION: DWORD = 0; {Populated on INITIALIZATION, holds Major=Hi(SQLITE3_VERSION)(alwyays=3), Minor=Lo(SQLITE3_VERSION)}

type
  PPAnsiCharArray = ^TPAnsiCharArray;
  TPAnsiCharArray = array[0..MaxInt div SizeOf(PAnsiChar) - 1] of PAnsiChar;
  TSqliteCallback = function(pArg: Pointer; nCol: Integer; argv: PPAnsiCharArray; colv: PPAnsiCharArray): Integer; cdecl;
  PSqliteBackup   = Pointer;
  PUtf8           = PAnsiChar;
  TSqlite3_Destroy_Callback = procedure(p: Pointer); cdecl;

{$IFNDEF SQLITE_STATIC}
function sqlite3_initialize: integer; cdecl; external 'sqlite3.dll';
function sqlite3_libversion: PAnsiChar; cdecl; external 'sqlite3.dll';
function sqlite3_errmsg(DB: PSqlite3): PAnsiChar; cdecl; external 'sqlite3.dll';
function sqlite3_threadsafe: integer; cdecl; external 'sqlite3.dll';

function sqlite3_open_v2(FileName: PUtf8; out ppDb: PSqlite3; Flags: integer; zVfs: PAnsiChar): integer; cdecl; external 'sqlite3.dll';
function sqlite3_close(DB: PSqlite3): integer; cdecl; external 'sqlite3.dll';
function sqlite3_backup_init(pDest: PSqlite3; zDestName: PByte; pSource: PSqlite3; zSourceName: PByte): PSqliteBackup; cdecl; external 'sqlite3.dll';
function sqlite3_backup_step(p: PSqliteBackup; nPage: integer): integer; cdecl; external 'sqlite3.dll';
function sqlite3_backup_finish(p: PSqliteBackup): integer; cdecl; external 'sqlite3.dll';

function sqlite3_exec(DB: PSqlite3; SQL: PByte; callback: TSqliteCallback; pArg: Pointer; errmsg: PPAnsiChar): integer; cdecl; external 'sqlite3.dll';
function sqlite3_prepare_v3(DB: PSQLite3; zSql: PUtf8; nByte: Integer; prepFlags: Cardinal; out ppStmt: PSQLite3Stmt; var pzTail: PByte): integer; cdecl; external 'sqlite3.dll' delayed;
function sqlite3_finalize(pStmt: PSqlite3Stmt): integer; cdecl; external 'sqlite3.dll';
function sqlite3_reset(pStmt: PSqlite3Stmt): integer; cdecl; external 'sqlite3.dll';
function sqlite3_last_insert_rowid(DB: PSqlite3): Int64; cdecl; external 'sqlite3.dll';

function sqlite3_bind_parameter_count(pStmt: PSqlite3Stmt): Integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_parameter_index(pStmt: PSqlite3Stmt; zName: PAnsiChar): integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_blob(pStmt: PSqlite3Stmt; i: integer; zData: Pointer; n: integer; xDel: TSqlite3_Destroy_Callback): integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_double(pStmt: PSqlite3Stmt; i: integer; rValue: Double): integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: integer; iValue: integer): integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_int64(pStmt: PSqlite3Stmt; i: integer; iValue: Int64): integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_null(pStmt: PSqlite3Stmt; i: integer): integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: integer; zData: PByte; n: integer; xDel: TSqlite3_Destroy_Callback): integer; cdecl; external 'sqlite3.dll';
function sqlite3_bind_zeroblob(pStmt: PSqlite3Stmt; i: integer; n: integer): integer; cdecl; external 'sqlite3.dll';

function sqlite3_clear_bindings(pStmt: PSqlite3Stmt): integer; cdecl; external 'sqlite3.dll';
function sqlite3_step(pStmt: PSqlite3Stmt): integer; cdecl; external 'sqlite3.dll';

function sqlite3_column_blob(pStmt: PSqlite3Stmt; iCol: integer): Pointer; cdecl; external 'sqlite3.dll';
function sqlite3_column_double(pStmt: PSqlite3Stmt; iCol: integer): Double; cdecl; external 'sqlite3.dll';
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: integer): integer; cdecl; external 'sqlite3.dll';
function sqlite3_column_int64(pStmt: PSqlite3Stmt; iCol: integer): Int64; cdecl; external 'sqlite3.dll';
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: integer): PByte; cdecl; external 'sqlite3.dll';
function sqlite3_column_bytes(pStmt: PSqlite3Stmt; iCol: integer): integer; cdecl; external 'sqlite3.dll';
function sqlite3_column_type(pStmt: PSqlite3Stmt; iCol: integer): integer; cdecl; external 'sqlite3.dll';
function sqlite3_column_count(pStmt: PSqlite3Stmt): integer; cdecl; external 'sqlite3.dll';
function sqlite3_column_name(pStmt: PSqlite3Stmt; n: integer): PAnsiChar; cdecl; external 'sqlite3.dll';

function sqlite3_blob_bytes(pBlob: PSqlite3Blob): integer; cdecl; external 'sqlite3.dll';
function sqlite3_blob_open(DB: PSqlite3; zDb: PAnsiChar; zTable: PAnsiChar; zColumn: PAnsiChar; iRow: Int64; Flags: integer; var ppBlob: PSqlite3Blob): integer; cdecl; external 'sqlite3.dll';
function sqlite3_blob_close(pBlob: PSqlite3Blob): integer; cdecl; external 'sqlite3.dll';
function sqlite3_blob_read(pBlob: PSqlite3Blob; Z: Pointer; n: integer; iOffset: integer): integer; cdecl; external 'sqlite3.dll';
function sqlite3_blob_write(pBlob: PSqlite3Blob; Z: Pointer; n: integer; iOffset: integer): integer; cdecl; external 'sqlite3.dll';

{$ENDIF}

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
  FStmt.OwnerDatabase.Check(sqlite3_bind_text(FStmt.Handle, FParamIndex, PByte(UTF8Encode(Value)), SQL_NTS, SQLITE_TRANSIENT));
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
  FStatementList := TList.Create;
  sqlite3_initialize;
end;

destructor TSqlite3Database.Destroy;
begin
  Close;
  FStatementList.Free;
  inherited;
end;

function TSqlite3Database.Check(const ErrCode: integer): integer;
begin
  if ErrCode in [SQLITE_OK, SQLITE_ROW, SQLITE_DONE] then
    Result := ErrCode
  else
    raise ESqliteError.Create(Format(SErrorMessage, [ErrCode, UTF8ToString(PAnsiChar(sqlite3_errmsg(FHandle)))]), ErrCode);
end;

procedure TSqlite3Database.CheckHandle;
begin
  if FHandle = nil then
    raise ESqliteError.Create(SDatabaseNotConnected, -1);
end;

function TSqlite3Database.GetFilename: string;
begin
  Result := FFilename;
end;

function TSqlite3Database.GetHandle: PSqlite3;
begin
  Result := FHandle;
end;

function TSqlite3Database.GetTransactionOpen: Boolean;
begin
  Result := FTransactionOpen;
end;

function TSqlite3Database.GetStatementList: TList;
begin
  Result := FStatementList;
end;

procedure TSqlite3Database.Open(const FileName: string; OpenFlags: integer);
begin
  Close;
  Check(sqlite3_open_v2(PUtf8(UTF8Encode(FileName)), FHandle, OpenFlags, nil));
  FFilename := FileName;
  Execute('PRAGMA foreign_keys = ON');
end;

procedure TSqlite3Database.OpenIntoMemory(const FileName: string);
var
  TempDB: ISqlite3Database;
  Backup: PSqliteBackup;
begin
  TempDB := TSqlite3Database.Create;
  Open(':memory:', SQLITE_OPEN_DEFAULT);
  FFilename := FileName;
  TempDB.Open(FileName, SQLITE_OPEN_DEFAULT);
  Backup := sqlite3_backup_init(Handle, PByte(PAnsiChar('main')), TempDB.Handle, PByte(PAnsiChar('main')));
  sqlite3_backup_step(Backup, -1);
  sqlite3_backup_finish(Backup);
  TempDB.Close;
end;

procedure TSqlite3Database.Backup(const Filename: string);
{Remark: Another way to backup a database is
           ==> Execute('VACUUM INTO %s', [QuotedStr(Filename)]);
         which was introduced in Sqlite3 version 3.27.0
         VACUUM INTO does uses a few more CPU cycles, but target DB is vaccuumed}
var
  TempDB: ISqlite3Database;
  Backup: PSqliteBackup;
begin
  DeleteFile(Filename);
  if LoWord(SQLITE3_VERSION) >= 27 then
    Execute('VACUUM INTO %s', [QuotedStr(Filename)]) {introduced in version 3.27.0}
  else
  begin
    TempDB := TSqlite3Database.Create;
    TempDB.Open(FileName, SQLITE_OPEN_DEFAULT);
    Backup := sqlite3_backup_init(TempDB.Handle, PByte(PAnsiChar('main')), Handle, PByte(PAnsiChar('main')));
    Check(sqlite3_backup_step(Backup, -1));
    Check(sqlite3_backup_finish(Backup));
    TempDB.Close;
  end;
end;

procedure TSqlite3Database.Close;
var
  i: integer;
begin
  if Assigned(FHandle) then
  begin
    {Rollback if transaction left open (sqlite will do this automatically, but we are doing it explcitly anyway)...}
    if FTransactionOpen then
      Rollback;

    {Finalize any remaining open Stmt handles...}
    for i := FStatementList.Count - 1 downto 0 do
    begin
      sqlite3_finalize(TSqlite3Statement(FStatementList[i]).FHandle);
      TSqlite3Statement(FStatementList[i]).FHandle := nil;
      FStatementList.Remove(FStatementList[i]);
    end;

    {Close Database...}
    Check(sqlite3_close(Handle)); {Note: close will return SQLITE_BUSY if all statment handles are not aslready destroyed/finalized...}
    FHandle := nil;
    FFilename := '';
  end;
end;

function TSqlite3Database.Prepare(const SQL: string; PrepFlags: Cardinal): ISqlite3Statement;
begin
  CheckHandle;
  Result := TSQLite3Statement.Create(Self, SQL, PrepFlags);
end;

function TSqlite3Database.Prepare(const SQL: string; const FmtParams: array of const; PrepFlags: Cardinal): ISqlite3Statement;
begin
  Result := Prepare(Format(SQL, FmtParams), PrepFlags);
end;

procedure TSqlite3Database.Fetch(const SQL: string; const StmtProc: TStmtProc);
var Stmt: ISqlite3Statement;
begin
  Stmt := Prepare(SQL, SQLITE_PREPARE_DEFAULT);
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
  with Prepare(SQL, SQLITE_PREPARE_DEFAULT) do
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
  Check(sqlite3_exec(Handle, PByte(UTF8Encode(SQL)), nil, nil, nil));
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

{$ENDREGION}

{$REGION ' TSqlite3Statment '}

constructor TSQLite3Statement.Create(OwnerDatabase: ISqlite3Database; const SQL: string; PrepFlags: Cardinal = 0);
{Remark: Minimum version of SQlite3 is 3.20 to use sqlite3_prepare_v3.  We are using v3 so we can use
         the prep flag SQLITE_PREPARE_PERSISTENT.
         The Statically linked version does not have sqlite3_prepare_v3, so PrepFlags are ignore if present}
var
  pzTail: PByte;
begin
  FOwnerDatabase := OwnerDatabase;
  FOwnerDatabase.CheckHandle;
  pzTail := nil;
  {$IFDEF SQLITE_STATIC}
  FOwnerDatabase.Check(sqlite3_prepare_v2(FOwnerDatabase.Handle, PByte(UTF8Encode(SQL)), SQL_NTS, FHandle, pzTail));
  {$ELSE}
  FOwnerDatabase.Check(sqlite3_prepare_v3(FOwnerDatabase.Handle, PUtf8(UTF8Encode(SQL)), SQL_NTS, PrepFlags, FHandle, pzTail));
  {$ENDIF}
  FOwnerDatabase.StatementList.Add(Pointer(Self));
end;

destructor TSQLite3Statement.Destroy;
begin
  if Assigned(Self.FHandle) then
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
  i: integer;
  ParamInt: integer;
  ParamInt64: Int64;
  ParamDouble: Double;
  ParamString: string;
  ASqlParam: TSqlParam;
begin
  Assert(High(Params) = sqlite3_bind_parameter_count(FHandle)-1, SParamCountMismatch);

  {Reset and Bind all params...}
  Reset;
  for i := 0 to High(Params) do
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
var i: integer;
begin
  Assert(High(Params)+1 = sqlite3_bind_parameter_count(FHandle), SParamCountMismatch);

  {Reset and BindText all params...}
  Reset;
  for i := 0 to High(Params) do
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
  {Remark: We are using sqlite3_prepare_v2/v3, So we will get result code immediately without having to call reset to get it.
           We want to call reset in any case, so we are calling reset before actually checking the result of
           Step and potentially raising an exception. And we are not checking the result of reset because
           that will throw another exception. This way, if we are doing a bunch of StepAndReset inserts and we want to
           ignore a contraint violation and continue, we can. (TBD: Sqlite.org says if in a transaction
           you should rollback the transaction but this approach seems to let subsequent inserts work fine
           and get committed if we handle/ignore the constraint violation. I need to verify this.)}
  Result := sqlite3_step(FHandle);
  sqlite3_reset(FHandle); {Remark: Bypass Check here because we might want to ignore and continue on a constraint violation}
  Result := FOwnerDatabase.Check(Result);
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
end;

destructor TSqlite3BlobHandler.Destroy;
begin
  sqlite3_blob_close(FHandle);
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
  Result := UTF8ToString(sqlite3_libversion);
end;

class function TSqlite3.Version: DWORD;
var
  VerStr: string;
  P1, P2: integer;
  MajorVer: DWORD;
  MinorVer: DWORD;
begin
  if SQLITE3_VERSION <> 0 then
    Result := SQLITE3_VERSION
  else
  begin
    VerStr := UTF8ToString(sqlite3_libversion);
    P1 := PosEx('.', VerStr);
    P2 := PosEx('.', VerStr, P1+1);
    MajorVer := Copy(VerStr, 1, P1-1).ToInteger;
    MinorVer := Copy(VerStr, P1+1, P2-P1-1).ToInteger;
    Result := MinorVer or (MajorVer shl 16);
  end;
end;

class function TSqlite3.CompileOptions: string;
const
  CRLF = #13#10;
var
  TempDB: ISqlite3Database;
begin
  TempDB := TSqlite3.OpenDatabase(':memory:');
  Result := '';
  with TempDB.Prepare('PRAGMA compile_options') do
  while Step = SQLITE_ROW do
    Result := Result + SqlColumn[0].AsText + CRLF;
end;

{$IFDEF SQLITE_STATIC}
class function TSqlite3.LibPath: string;
begin
  Result := 'FireDAC.Phys.SQLiteWrapper.Stat';
end;
{$ELSE}
class function TSqlite3.LibPath: string;
var L: Integer;
begin
  L := MAX_PATH + 1;
  SetLength(Result, L);
  L := GetModuleFileName(GetModuleHandle('sqlite3.dll'), Pointer(Result), L);
  SetLength(Result, L);
end;
{$ENDIF}

class function TSqlite3.OpenDatabase(const FileName: string; OpenFlags: integer = SQLITE_OPEN_DEFAULT): ISqlite3Database;
begin
  Result := TSqlite3Database.Create;
  Result.Open(Filename, OpenFlags);
end;

class function TSqlite3.OpenDatabaseIntoMemory(const FileName: string): ISqlite3Database;
begin
  Result := TSqlite3Database.Create;
  Result.OpenIntoMemory(Filename);
end;

class function TSqlite3.ThreadSafe: Boolean;
begin
  {$IFDEF SQLITE_STATIC}
  Result := TRUE;
  {$ELSE}
  Result := sqlite3_threadsafe <> 0;
  {$ENDIF}
end;

{$ENDREGION}

Initialization
const ErrMsg = 'Sqlite3.dll Version 3.20 or greater not found.  Application will terminate.';
begin
  SQLITE3_VERSION := TSqlite3.Version;
  if LoWord(SQLITE3_VERSION) < 20 then
  begin
    {$IFNDEF CONSOLE}
    ShowMessage(ErrMsg);
    Application.Terminate;
    {$ELSE}
    Writeln(ErrMsg);
    ReadLn;
    Halt;
    {$ENDIF}
  end;
end;

End.
