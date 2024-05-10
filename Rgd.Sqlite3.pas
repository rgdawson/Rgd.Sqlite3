Unit Rgd.Sqlite3;

{$IFDEF DEBUG}
  {$ASSERTIONS ON}
{$ELSE}
  {$ASSERTIONS OFF}
{$ENDIF}

{.$DEFINE ENABLE_COLUMNBYNAME}
{^ Define ENABLE_COLUMNBYNAME above to include code that allows you to specify column by name, i.e. SqlColumn['ColName']
   A dictionary is used to quickly look column index by name.  I implemented this, but I never have found a need
   to use column names and since it is slightly slower, I don't use it.}

Interface

{$REGION ' Uses '}

uses
  WinApi.Windows,
  System.Types,
  System.Classes,
  System.SysUtils,
  {$IFDEF ENABLE_COLUMNBYNAME}
  System.Generics.Collections,
  {$ENDIF}
  System.StrUtils;

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

  {Open Flags...}
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

  {SQL PrepFlags}
  SQLITE_PREPARE_PERSISTENT = $01;
  SQLITE_PREPARE_NORMALIZE  = $02; {deprecated, no-op}
  SQLITE_PREPARE_NO_VTAB    = $04;

type
  {Sqlite pointer types...}
  PSqlite3     = type Pointer;
  PSqlite3Stmt = type Pointer;
  PSqlite3Blob = type Pointer;

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
    function GetTransactionOpen: Boolean;
    {Error Checking...}
    function Check(const ErrCode: integer): integer;
    {Open/Close...}
    procedure Open(const FileName: string; Flags: integer = 0);
    procedure OpenIntoMemory(const FileName: string; Flags: integer = 0);
    procedure Close;
    procedure Backup(const Filename: string; Flags: integer = 0);
    {Prepare...}
    function Prepare(const SQL: string; PrepFlags: Cardinal = 0): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const; PrepFlags: Cardinal = 0): ISqlite3Statement; overload;
    {Transactions...}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    {Execute...}
    procedure Execute(const SQL: string); overload;
    procedure Execute(const SQL: string; const FmtParams: array of const); overload;
    function LastInsertRowID: Int64;
    {Fetching, Updating...}
    procedure Fetch(const SQL: string; StmtProc: TStmtProc); overload;
    procedure Fetch(const SQL: string; const FmtParams: array of const; StmtProc: TStmtProc); overload;
    procedure FetchFirst(const SQL: string; StmtProc: TStmtProc);
    function  FetchCount(const SQL: string): integer; overload;
    function  FetchCount(const SQL: string; const FmtParams: array of const): integer; overload;
    procedure Transaction(Proc: TProc); overload;
    procedure Transaction(const SQL: string; StmtProc: TStmtProc); overload;
    procedure Transaction(const SQL: string; const FmtParams: array of const; StmtProc: TStmtProc); overload;
    {Blobs...}
    function BlobOpen(const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean = True): ISqlite3BlobHandler;
    {Properties...}
    property TransactionOpen: Boolean read GetTransactionOpen;
    property Handle: PSqlite3 read GetHandle;
    property Filename: string read GetFilename;
  end;

  ISqlite3Statement = interface
    ['{71D449C7-29BF-4C00-983E-52CFF11DB2B7}']
    {Getters}
    function GetHandle: PSqlite3Stmt;
    function GetOwnerDatabase: ISqlite3Database;
    function GetSqlParam(const ParamIndex: integer): TSqlParam;
    function GetSqlParamByName(const ParamName: string): TSqlParam;
    function GetSqlColumn(const ColumnIndex: integer): TSqlColumn;
    {$IFDEF ENABLE_COLUMNBYNAME}
    function GetSqlColumnByName(const ColumnName: string): TSqlColumn;
    {$ENDIF}
    {Binding, Stepping...}
    procedure ClearBindings;
    procedure BindParams(const Params: array of const); overload;
    procedure BindParams(const Params: TArray<string>); overload;
    procedure BindParams(const Params: TArray<integer>); overload;
    function  BindAndStep(const Params: array of const): integer; overload;
    function  BindAndStep(const Params: TArray<string>): integer; overload;
    function  BindAndStep(const Params: TArray<integer>): integer; overload;
    function  Step: integer;
    function  StepAndReset: integer; overload;
    //function  SqlStep: Boolean;
    {Fetching, Updating...}
    procedure Reset;
    procedure Fetch(StepProc: TProc);
    procedure FetchFirst(StepProc: TProc);
    procedure BindAndFetch(const Params: array of const; StepProc: TProc);
    procedure BindAndFetchFirst(const Params: array of const; StepProc: TProc);
    procedure Transaction(UpdateProc: TProc);
    function SqlColumnCount: integer;
    {Properties...}
    property Handle: PSqlite3Stmt read GetHandle;
    property OwnerDatabase: ISqlite3Database read GetOwnerDatabase;
    property SqlParam[const ParamIndex: integer]:     TSqlParam  read GetSqlParam;
    property SqlParamByName[const ParamName: string]: TSqlParam  read GetSqlParamByName;
    {$IFDEF ENABLE_COLUMNBYNAME}
    property SqlColumn[const ColumnIndex: integer]:   TSqlColumn read GetSqlColumn; default; {Only the default property can be overloaded}
    property SqlColumn[const ColumnName: string]:     TSqlColumn read GetSqlColumnByName; default;
    {$ELSE}
    property SqlColumn[const ColumnIndex: integer]:   TSqlColumn read GetSqlColumn;
    {$ENDIF}
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
    {Getters...}
    function GetHandle: PSqlite3;
    function GetFilename: string;
    function GetTransactionOpen: Boolean;
    {Error Checking...}
    function Check(const ErrCode: integer): integer;
    {Open/Close...}
    procedure Open(const FileName: string; Flags: integer = 0);
    procedure Close;
    procedure OpenIntoMemory(const FileName: string; Flags: integer = 0);
    procedure Backup(const Filename: string; Flags: integer = 0);
    {Prepare SQL...}
    function Prepare(const SQL: string; PrepFlags: Cardinal = 0): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const; PrepFlags: Cardinal = 0): ISqlite3Statement; overload;
    {Transactions}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    {Execute}
    procedure Execute(const SQL: string); overload;
    procedure Execute(const SQL: string; const FmtParams: array of const); overload;
    function LastInsertRowID: Int64;
    {Fetch, Updating}
    procedure Fetch(const SQL: string; StmtProc: TStmtProc); overload;
    procedure Fetch(const SQL: string; const FmtParams: array of const; StmtProc: TStmtProc); overload;
    procedure FetchFirst(const SQL: string; StmtProc: TStmtProc);
    function FetchCount(const SQL: string): integer; overload;
    function FetchCount(const SQL: string; const FmtParams: array of const): integer; overload;
    procedure Transaction(Proc: TProc); overload;
    procedure Transaction(const SQL: string; StmtProc: TStmtProc); overload;
    procedure Transaction(const SQL: string; const FmtParams: array of const; StmtProc: TStmtProc); overload;
    {Blobs}
    function BlobOpen(const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean = True): ISqlite3BlobHandler;
    property Handle: PSqlite3 read GetHandle write FHandle;
  public
    {Constructor/Destructor}
    constructor Create;
    destructor Destroy; override;
  end;

  TSQLite3Statement = class(TInterfacedObject, ISqlite3Statement)
  private
    FHandle: PSqlite3Stmt;
    [unsafe] FOwnerDatabase: ISqlite3Database;
    {$IFDEF ENABLE_COLUMNBYNAME}
    FColumnLookup: TDictionary<string, integer>;
    function GetColumnIndex(Name: string): integer;
    function GetSqlColumnByName(const ColumnName: string): TSqlColumn;
    {$ENDIF}
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
    procedure BindParams(const Params: TArray<integer>); overload;
    function BindAndStep(const Params: array of const): integer; overload;
    function BindAndStep(const Params: TArray<string>): integer; overload;
    function BindAndStep(const Params: TArray<integer>): integer; overload;
    function Step: integer;
    function StepAndReset: integer; overload;
    {Fetching, Updating}
    procedure Reset;
    procedure Fetch(FetchProc: TProc);
    procedure FetchFirst(FetchProc: TProc);
    procedure BindAndFetch(const Params: array of const; StepProc: TProc);
    procedure BindAndFetchFirst(const Params: array of const; StepProc: TProc);
    procedure Transaction(UpdateProc: TProc);
    function SqlColumnCount: integer;
  public
    {Constructor/Destructor}
    constructor Create(OwnerDatabase: ISqlite3Database; const SQL: string; PrepFlags: Cardinal = 0);
    destructor Destroy; override;
  end;

  TSqlite3BlobHandler = class(TInterfacedObject, ISqlite3BlobHandler)
  private
    FHandle: PSqlite3Blob;
    [unsafe] FOwnerDatabase: ISqlite3Database;
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
    class function GetSQLiteVersionStr: string;
    class function GetSQLiteVersion: DWORD;
    class function GetSQLiteCompileOptions: string;
    class function GetSqliteLibPath: string;
    class function OpenDatabase(const FileName: string; Flags: integer = 0): ISqlite3Database;
    class function IsThreadSafe: Boolean;
  end;

var
  DB: ISqlite3Database;

Implementation

{$REGION ' Sqlite DLL Api Externals '}

(***********************************************************************
 *  This is just the minimum set of sqlite3.dll external functions
 *  required to support this unit. (from sqlite3.h)
 ***********************************************************************)
const
  sqlite3_lib = 'Sqlite3.dll';
  SQLITE_TRANSIENT = Pointer(-1);
  SQL_NTS = -1;
var
  SQLITE3_VERSION: DWORD = 0; {Populated on DB.Create, holds Major=Hi(SQLITE3_VERSION), Minor=Lo(SQLITE3_VERSION)}

type
  PPAnsiCharArray = ^TPAnsiCharArray;
  TPAnsiCharArray = array[0..MaxInt div SizeOf(PAnsiChar) - 1] of PAnsiChar;
  TSqliteCallback = function(pArg: Pointer; nCol: Integer; argv: PPAnsiCharArray; colv: PPAnsiCharArray): Integer; cdecl;
  PSqliteBackup   = type Pointer;
  TDestructor     = procedure(p: Pointer); cdecl;

function sqlite3_initialize: Integer; cdecl; external sqlite3_lib delayed;
function sqlite3_libversion: PAnsiChar; cdecl; external sqlite3_lib delayed;
function sqlite3_errmsg(DB: PSqlite3): PAnsiChar; cdecl; external sqlite3_lib delayed;
function sqlite3_threadsafe: Integer; cdecl; external sqlite3_lib delayed;

function sqlite3_open(const FileName: PAnsiChar; var ppDb: PSqlite3): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_open_v2(const FileName: PAnsiChar; var ppDb: PSqlite3; Flags: integer; const zVfs: PAnsiChar): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_close(DB: PSqlite3): integer; cdecl; external sqlite3_lib delayed;

function sqlite3_backup_init(pDest: PSqlite3; const zDestName: PAnsiChar; pSource: PSqlite3; const zSourceName: PAnsiChar): PSqliteBackup; cdecl; external sqlite3_lib delayed;
function sqlite3_backup_step(p: PSqliteBackup; nPage: integer): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_backup_finish(p: PSqliteBackup): integer; cdecl; external sqlite3_lib delayed;

function sqlite3_exec(DB: PSqlite3; const SQL: PAnsiChar; callback: TSqliteCallback; pArg: Pointer; errmsg: PPAnsiChar): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_prepare_v2(DB: PSQLite3; const zSql: PAnsiChar; nByte: Integer; var ppStmt: PSQLite3Stmt; const pzTail: PPAnsiChar): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_prepare_v3(DB: PSQLite3; const zSql: PAnsiChar; nByte: Integer; prepFlags: Cardinal; var ppStmt: PSQLite3Stmt; const pzTail: PPAnsiChar): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_finalize(pStmt: PSqlite3Stmt): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_reset(pStmt: PSqlite3Stmt): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_last_insert_rowid(DB: PSqlite3): Int64; cdecl; external sqlite3_lib delayed;

function sqlite3_bind_parameter_count(pStmt: PSqlite3Stmt): Integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_parameter_index(pStmt: PSqlite3Stmt; const zName: PAnsiChar): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_blob(pStmt: PSqlite3Stmt; i: integer; const zData: Pointer; n: integer; xDel: TDestructor): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_double(pStmt: PSqlite3Stmt; i: integer; rValue: Double): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: integer; iValue: integer): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_int64(pStmt: PSqlite3Stmt; i: integer; iValue: Int64): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_null(pStmt: PSqlite3Stmt; i: integer): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: integer; const zData: PAnsiChar; n: integer; xDel: TDestructor): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_bind_zeroblob(pStmt: PSqlite3Stmt; i: integer; n: integer): integer; cdecl; external sqlite3_lib delayed;

function sqlite3_clear_bindings(pStmt: PSqlite3Stmt): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_step(pStmt: PSqlite3Stmt): integer; cdecl; external sqlite3_lib delayed;

function sqlite3_column_blob(pStmt: PSqlite3Stmt; iCol: integer): Pointer; cdecl; external sqlite3_lib delayed;
function sqlite3_column_double(pStmt: PSqlite3Stmt; iCol: integer): Double; cdecl; external sqlite3_lib delayed;
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: integer): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_column_int64(pStmt: PSqlite3Stmt; iCol: integer): Int64; cdecl; external sqlite3_lib delayed;
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: integer): PAnsiChar; cdecl; external sqlite3_lib delayed;
function sqlite3_column_bytes(pStmt: PSqlite3Stmt; iCol: integer): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_column_type(pStmt: PSqlite3Stmt; iCol: integer): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_column_count(pStmt: PSqlite3Stmt): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_column_name(pStmt: PSqlite3Stmt; n: integer): PAnsiChar; cdecl; external sqlite3_lib delayed;

function sqlite3_blob_bytes(pBlob: PSqlite3Blob): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_blob_open(DB: PSqlite3; const zDb: PAnsiChar; const zTable: PAnsiChar; const zColumn: PAnsiChar; iRow: Int64; Flags: integer; var ppBlob: PSqlite3Blob): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_blob_close(pBlob: PSqlite3Blob): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_blob_read(pBlob: PSqlite3Blob; Z: Pointer; n: integer; iOffset: integer): integer; cdecl; external sqlite3_lib delayed;
function sqlite3_blob_write(pBlob: PSqlite3Blob; const Z: Pointer; n: integer; iOffset: integer): integer; cdecl; external sqlite3_lib delayed;

{$ENDREGION}

{$REGION ' ESqliteError '}

resourcestring
  SErrorMessage           = 'Sqlite error: [%d] %s';
  SDatabaseNotConnected   = 'Sqlite error: database is not connected';
  STransactionAlreadyOpen = 'Transaction is already opened';
  SNoTransactionOpen      = 'No transaction is open';
  SColumnNameNotFound     = 'Column ''%s'' not found in columns:'#13#10'%s';
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
  FStmt.OwnerDatabase.Check(sqlite3_bind_text(FStmt.Handle, FParamIndex, PAnsiChar(UTF8Encode(Value)), SQL_NTS, SQLITE_TRANSIENT));
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
  Result := UTF8ToString(sqlite3_column_text(FStmt.Handle, FColIndex));
end;

function TSqlColumn.ColName: string;
begin
  Result := UTF8ToString(sqlite3_column_name(FStmt.Handle, FColIndex));
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
  FHandle := nil;
  sqlite3_initialize;
  SQLITE3_VERSION := TSqlite3.GetSQLiteVersion;
end;

destructor TSqlite3Database.Destroy;
begin
  Close;
  inherited;
end;

function TSqlite3Database.Check(const ErrCode: integer): integer;
begin
  if ErrCode in [SQLITE_OK, SQLITE_ROW, SQLITE_DONE] then
    Result := ErrCode
  else
    raise ESqliteError.Create(Format(SErrorMessage, [ErrCode, UTF8ToString(sqlite3_errmsg(FHandle))]), ErrCode);
end;

function TSqlite3Database.GetFilename: string;
begin
  Result := FFilename;
end;

function TSqlite3Database.GetHandle: PSqlite3;
begin
  if FHandle = nil then
    raise ESqliteError.Create(SDatabaseNotConnected, -1);
  Result := FHandle;
end;

function TSqlite3Database.GetTransactionOpen: Boolean;
begin
  Result := FTransactionOpen;
end;

procedure TSqlite3Database.Open(const FileName: string; Flags: integer);
begin
  Close;
  if Flags = 0 then
    Check(sqlite3_open(PAnsiChar(UTF8Encode(FileName)), FHandle))
  else
    Check(sqlite3_open_v2(PAnsiChar(UTF8Encode(FileName)), FHandle, Flags, nil));

  if Assigned(FHandle) then
  begin
    FFilename := FileName;
    {PRAGMAs...}
    Self.Execute('PRAGMA foreign_keys = ON');
  end;
end;

procedure TSqlite3Database.OpenIntoMemory(const FileName: string; Flags: integer = 0);
var
  TempDB: ISqlite3Database;
  Backup: PSqliteBackup;
begin
  FFilename := FileName;
  TempDB := TSqlite3Database.Create;
  Open(':memory:');
  TempDB.Open(FileName, Flags);
  Backup := sqlite3_backup_init(Handle, 'main', TempDB.Handle, 'main');
  sqlite3_backup_step(Backup, -1);
  sqlite3_backup_finish(Backup);
  TempDB.Close;
end;

procedure TSqlite3Database.Backup(const Filename: string; Flags: integer = 0);
var
  TempDB: ISqlite3Database;
  Backup: PSqliteBackup;
begin
  TempDB := TSqlite3Database.Create;
  TempDB.Open(FileName, Flags);
  Backup := sqlite3_backup_init(TempDB.Handle, 'main', Handle, 'main');
  sqlite3_backup_step(Backup, -1);
  sqlite3_backup_finish(Backup);
  TempDB.Close;
end;

procedure TSqlite3Database.Close;
begin
  if Assigned(FHandle) then
  begin
    {Rollback if transaction left open (sqlite will do this automatically, but we are doing it explcitly anyway)...}
    if FTransactionOpen then
      Rollback;

    {Close Database...}
    Check(sqlite3_close(Handle)); {Note: close will return SQLITE_BUSY if all statment handles are not aslready destroyed/finalized...}
    FHandle := nil;
    FFilename := '';
  end;
end;

function TSqlite3Database.Prepare(const SQL: string; PrepFlags: Cardinal = 0): ISqlite3Statement;
begin
  Result := TSQLite3Statement.Create(Self, SQL, PrepFlags);
end;

function TSqlite3Database.Prepare(const SQL: string; const FmtParams: array of const; PrepFlags: Cardinal = 0): ISqlite3Statement;
begin
  Result := Prepare(Format(SQL, FmtParams));
end;

procedure TSqlite3Database.Fetch(const SQL: string; StmtProc: TStmtProc);
var
  Stmt: ISqlite3Statement;
begin
  Stmt := Prepare(SQL);
  while Stmt.Step = SQLITE_ROW do
    StmtProc(Stmt);
end;

procedure TSqlite3Database.Fetch(const SQL: string; const FmtParams: array of const; StmtProc: TStmtProc);
begin
  Fetch(Format(SQL, FmtParams), StmtProc);
end;

procedure TSqlite3Database.FetchFirst(const SQL: string; StmtProc: TStmtProc);
var
  Stmt: ISqlite3Statement;
begin
  Stmt := Prepare(SQL);
  if Stmt.Step = SQLITE_ROW then
    StmtProc(Stmt);
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
  Check(sqlite3_exec(Handle, PAnsiChar(UTF8Encode(SQL)), nil, nil, nil));
end;

procedure TSqlite3Database.Execute(const SQL: string; const FmtParams: array of const);
begin
  Execute(Format(SQL, FmtParams));
end;

function TSqlite3Database.LastInsertRowID: Int64;
begin
  Result := sqlite3_last_insert_rowid(Handle);
end;

procedure TSqlite3Database.Transaction(Proc: TProc);
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

procedure TSqlite3Database.Transaction(const SQL: string; StmtProc: TStmtProc);
var
  Stmt: ISqlite3Statement;
begin
  BeginTransaction;
  try
    Stmt := Self.Prepare(SQL);
    StmtProc(Stmt);
    Commit;
  finally
    if FTransactionOpen then
      Rollback;
  end;
end;

procedure TSqlite3Database.Transaction(const SQL: string; const FmtParams: array of const; StmtProc: TStmtProc);
begin
  Transaction(Format(SQL, FmtParams), StmtProc);
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

{$ENDREGION}

{$REGION ' TSqlite3Statment '}

constructor TSQLite3Statement.Create(OwnerDatabase: ISqlite3Database; const SQL: string; PrepFlags: Cardinal = 0);
{Remark: Minimum version of SQlite3 is 3.20 to use sqlite3_prepare_v3}
begin
  FOwnerDatabase := OwnerDatabase;
  if (PrepFlags <> 0) and (LoWord(SQLITE3_VERSION) >= 20) then
    FOwnerDatabase.Check(sqlite3_prepare_v2(FOwnerDatabase.Handle, PAnsiChar(UTF8Encode(SQL)), SQL_NTS, FHandle, nil))
  else
    FOwnerDatabase.Check(sqlite3_prepare_v3(FOwnerDatabase.Handle, PAnsiChar(UTF8Encode(SQL)), SQL_NTS, PrepFlags, FHandle, nil));
end;

destructor TSQLite3Statement.Destroy;
begin
  sqlite3_finalize(FHandle);
  {$IFDEF ENABLE_COLUMNBYNAME}
    FColumnLookup.Free;
  {$ENDIF}
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

{$IFDEF ENABLE_COLUMNBYNAME}
function TSQLite3Statement.GetColumnIndex(Name: string): integer;
var
  i: integer;
  S0: string;
begin
  {Create ColumnIndex lookup dictionary...}
  if not assigned(FColumnLookup) then
  begin
    {$IFDEF UseSpring4D}
    FColumnLookup := TCollections.CreateDictionary<string, integer>;
    {$ELSE}
    FColumnLookup := TDictionary<string, integer>.Create;
    {$ENDIF}
    for i := 0 to SqlColumnCount-1 do
      FColumnLookup.Add(GetSqlColumn(i).ColName, i);
  end;

  {Lookup ColumnIndex by ColumnName...}
  if not FColumnLookup.TryGetValue(Name, Result) then
  begin
    for i := 0 to SqlColumnCount-1 do
      S0 := S0 + '   ' + GetSqlColumn(i).ColName + #13#10;
    raise ESqliteError.Create(Format(SColumnNameNotFound, [Name, S0]), 0);
  end;
end;
{$ENDIF}

function TSQLite3Statement.GetSqlParam(const ParamIndex: integer): TSqlParam;
begin
  Result.FStmt := Self;
  Result.FParamIndex := ParamIndex;
end;

function TSQLite3Statement.GetSqlParamByName(const ParamName: string): TSqlParam;
begin
  Result.FStmt := Self;
  Result.FParamIndex := sqlite3_bind_parameter_index(FHandle, PAnsiChar(UTF8Encode(ParamName)));
end;

{$IFDEF ENABLE_COLUMNBYNAME}
function TSQLite3Statement.GetSqlColumnByName(const ColumnName: string): TSqlColumn;
begin
  Result.FStmt := Self;
  Result.FColIndex := GetColumnIndex(ColumnName);
end;
{$ENDIF}

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
var
  i: integer;
begin
  Assert(High(Params)+1 = sqlite3_bind_parameter_count(FHandle), SParamCountMismatch);

  Reset;
  for i := 0 to High(Params) do
    GetSqlParam(i+1).BindText(Params[i]);
end;

procedure TSQLite3Statement.BindParams(const Params: TArray<integer>);
var
  i: integer;
begin
  Assert(High(Params)+1 = sqlite3_bind_parameter_count(FHandle), SParamCountMismatch);

  Reset;
  for i := 0 to High(Params) do
    GetSqlParam(i+1).BindInt(Params[i]);
end;

function TSQLite3Statement.BindAndStep(const Params: array of const): integer;
begin
  BindParams(Params); {BindParams resets the statement before binding}
  Result := Step;
end;

function TSQLite3Statement.BindAndStep(const Params: TArray<string>): integer;
begin
  BindParams(Params);
  Result := Step;
end;

function TSQLite3Statement.BindAndStep(const Params: TArray<integer>): integer;
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
  Result := Step;
  Reset;
end;

procedure TSQLite3Statement.Reset;
begin
  FOwnerDatabase.Check(sqlite3_reset(FHandle));
end;

procedure TSQLite3Statement.Fetch(FetchProc: TProc);
begin
  while Step = SQLITE_ROW do
    FetchProc;
end;

procedure TSQLite3Statement.FetchFirst(FetchProc: TProc);
begin
  if Step = SQLITE_ROW then
    FetchProc;
end;

procedure TSQLite3Statement.BindAndFetch(const Params: array of const; StepProc: TProc);
begin
  BindParams(Params);
  while Step = SQLITE_ROW do
    StepProc;
end;

procedure TSQLite3Statement.BindAndFetchFirst(const Params: array of const; StepProc: TProc);
begin
  BindParams(Params);
  if Step = SQLITE_ROW then
    StepProc;
end;

procedure TSQLite3Statement.Transaction(UpdateProc: TProc);
begin
  FOwnerDatabase.Transaction(UpdateProc);
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
  FOwnerDatabase.Check(sqlite3_blob_open(FOwnerDatabase.Handle, 'main', PAnsiChar(UTF8Encode(Table)), PAnsiChar(UTF8Encode(Column)), RowID, Ord(WriteAccess), FHandle));
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

class function TSqlite3.GetSQLiteVersionStr: string;
begin
  Result := UTF8ToString(sqlite3_libversion);
end;

class function TSqlite3.GetSQLiteVersion: DWORD;
var
  VerStr: string;
  P1, P2: integer;
  MajorVer: integer;
  MinorVer: integer;
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
    Result := MinorVer and (MajorVer shl 16);
  end;
end;

class function TSqlite3.GetSQLiteCompileOptions: string;
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

class function TSqlite3.GetSqliteLibPath: string;
var
  L: Integer;
begin
  L := MAX_PATH + 1;
  SetLength(Result, L);
  L := GetModuleFileName(GetModuleHandle(sqlite3_lib), Pointer(Result), L);
  SetLength(Result, L);
end;

class function TSqlite3.OpenDatabase(const FileName: string; Flags: integer = 0): ISqlite3Database;
begin
  Result := TSqlite3Database.Create;
  Result.Open(Filename, Flags);
end;

class function TSqlite3.IsThreadSafe: Boolean;
begin
  Result := sqlite3_threadsafe <> 0;
end;

{$ENDREGION}

End.
