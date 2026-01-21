Unit Rgd.Sqlite3;

Interface

(**************************************************************************************************************
 *  This unit supports:
 *    WinSqlite3.dll (Windows core component),
 *    Sqlite3.dll    (Precompiled or otherwise)
 *
 *  Define SQLITE_WIN in order to link to the Windows component WinSqlite3.dll
 *
 *  WinSqlite3.dll has been a Windows core component since Windows 10.
 *    - In January 2026, Windows 11 updated WinSqlite3.dll from v3.43.2 to v3.51.1.
 *    - Similar precompiled Sqlite3.dll from Sqlite.org
 *      - Uses stdcall calling convention (only applicable to 32-bit)
 *      - Does NOT include: ENABLE_MATH_FUNCTIONS, ENABLE_PERCENTILE, LOCALTIME, CARRYA
 *      - DOES include: FTS3_PARENTHESIS, FTS4, RBU, STAT4, API_ARMOR
 *
 **************************************************************************************************************)

{$REGION ' Uses '}

uses
  WinApi.Windows,
  System.Types,
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  System.StrUtils,
  {$IFNDEF CONSOLE} Vcl.Dialogs, Vcl.Forms, {$ENDIF}
  System.Math;

{$ENDREGION}

{$REGION ' Sqlite3 DLL Constants and Types '}

const
  {Memory Database Name...}
  MEMORY = ':memory:';

  {Return Values...}
  SQLITE_OK    = 0;
  SQLITE_ERROR = 1;
  SQLITE_ROW   = 100;
  SQLITE_DONE  = 101;

  {Column Types...}
  SQLITE_INTEGER = 1;
  SQLITE_FLOAT   = 2;
  SQLITE_TEXT    = 3;
  SQLITE_BLOB    = 4;
  SQLITE_NULL    = 5;

  {Sqlite Open Flags (for use with sqlite3_open_v2)...}
  SQLITE_OPEN_READONLY     = $00000001;
  SQLITE_OPEN_READWRITE    = $00000002;
  SQLITE_OPEN_CREATE       = $00000004;
  SQLITE_OPEN_URI          = $00000040;
  SQLITE_OPEN_MEMORY       = $00000080;
  SQLITE_OPEN_NOMUTEX      = $00008000;
  SQLITE_OPEN_FULLMUTEX    = $00010000;
  SQLITE_OPEN_SHAREDCACHE  = $00020000;
  SQLITE_OPEN_PRIVATECACHE = $00040000;
  SQLITE_OPEN_NOFOLLOW     = $01000000;
  SQLITE_OPEN_DEFAULT      = (SQLITE_OPEN_READWRITE) or (SQLITE_OPEN_CREATE);

type
  {Sqlite pointer types...}
  PSqlite3 = Pointer;
  PSqlite3Stmt = Pointer;
  PSqlite3Blob = Pointer;
  PSQLite3Context = Pointer;
  PSQLite3Value = Pointer;
  PPSQLite3ValueArray = ^TPSQLite3ValueArray;
  TPSQLite3ValueArray = array[0..MaxInt div SizeOf(PSQLite3Value) - 1] of PSQLite3Value;
  TSQLite3RegularFunction = procedure(Context: PSQLite3Context; ArgCount: Integer; Args: PPSQLite3ValueArray); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF};

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
  ISqlite3Statement   = interface;
  ISqlite3BlobHandler = interface;

 {Column, Parameter Accessors...}

 (*************************************************************************************************
  * TSqlParam, TSqlColumn are not intended to be declared as variables. These are return values
  * for SqlColumn and SqlParam. The intent is to support fluent style, such as SqlColumn[i].AsText.
  *************************************************************************************************)

  TSqlParam = record
    [unsafe] FStmt: ISqlite3Statement;
    FParamIndex: integer;
    procedure BindDouble(const Value: Double);
    procedure BindInt(const Value: integer);
    procedure BindInt64(const Value: Int64);
    procedure BindText(const Value: string);
    procedure BindNull;
    procedure BindBlob(const Data: TBytes);
    procedure BindZeroBlob(const Size: integer);
  end;

  TSqlColumn = record
    [unsafe] FStmt: ISqlite3Statement;
    FColumnIndex : integer;
    function AsBool   : Boolean;
    function AsDouble : Double;
    function AsInt    : integer;
    function AsInt64  : Int64;
    function AsText   : string;
    function AsBlob   : TBytes;
    function ColBytes : integer;
    function ColName  : string;
    function ColType  : integer;
    function IsNull   : Boolean;
  end;

  {Sqlite Interface Definitions...}

  ISqlite3Database = interface
    ['{E6409C03-0409-46D3-99A6-7FCF27D72DF4}']
  {Getters...}
    function GetHandle: PSqlite3;
    function GetFilename: string;
    function GetTransactionOpen: Boolean;
  {Error Checking...}
    function Check(const ErrCode: integer): integer;
    procedure CheckHandle;
  {Open/Close...}
    procedure Open(const Filename: string; OpenFlags: integer = SQLITE_OPEN_DEFAULT);
    procedure OpenIntoMemory(const Filename: string );
    procedure Close;
    procedure Backup(const Filename: string);
  {Prepare...}
    function Prepare(const SQL: string): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const): ISqlite3Statement; overload;
    function PrepareFmt(const SQL: string; const FmtParams: array of const): ISqlite3Statement;
  {Execute...}
    procedure Execute(const SQL: string); overload;
    procedure Execute(const SQL: string; const FmtParams: array of const); overload;
    procedure ExecuteFmt(const SQL: string; const FmtParams: array of const);
    function LastInsertRowID: Int64;
  {FetchCount...}
    function BindAndFetchCount(const Params: array of const; const SQL: string): integer;
    function FetchCount(const SQL: string): integer; overload;
    function FetchCount(const SQL: string; const FmtParams: array of const): integer; overload;
    function FetchCountFmt(const SQL: string; const FmtParams: array of const): integer;
  {Blobs...}
    function BlobOpen(const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean = True): ISqlite3BlobHandler;
  {Transactions...}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    procedure Transaction(const Proc: TProc); overload;
  {Application-Defined Functons...}
    procedure AdfCreateFunction(Name: string; nArg: integer; xFunc: TSQLite3RegularFunction);
  {Properties...}
    property TransactionOpen: Boolean read GetTransactionOpen;
    property Handle: PSqlite3 read GetHandle;
    property Filename: string read GetFilename;
    property _Prepare[const SQL: string]: ISQlite3Statement read Prepare; default;
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
    function  BindAndStep(const Params: array of const): integer; overload;
    function  BindAndStep(const Params: TArray<string>): integer; overload;
    function  Step: integer;
    function  StepAndReset: integer;
  {Fetching, Updating...}
    procedure Reset;
    procedure Fetch(const StepProc: TProc);
    procedure BindAndFetch(const Params: array of const; const StepProc: TProc);
    function  SqlColumnCount: integer;
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
    function BlobBytes: integer;
    procedure Read(ByteArray: TBytes; const Offset, Size: integer);
    procedure Write(ByteArray: TBytes; const Offset: integer; const Size: integer = -1);
  {Properties}
    property Handle: PSqlite3Blob read GetHandle;
    property OwnerDatabase: ISqlite3Database read GetOwnerDatabase;
  end;


  (***********************************************************************************************
   * ISqlite* Implementation classes...
   ***********************************************************************************************)

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
    procedure CheckHandle;
  {Open/Close...}
    procedure Open(const Filename: string; OpenFlags: integer = SQLITE_OPEN_DEFAULT);
    procedure OpenIntoMemory(const Filename: string);
    procedure Close;
    procedure Backup(const Filename: string);
  {Prepare SQL...}
    function Prepare(const SQL: string): ISqlite3Statement; overload;
    function Prepare(const SQL: string; const FmtParams: array of const): ISqlite3Statement; overload;
    function PrepareFmt(const SQL: string; const FmtParams: array of const): ISqlite3Statement;
  {Execute...}
    procedure Execute(const SQL: string); overload;
    procedure Execute(const SQL: string; const FmtParams: array of const); overload;
    procedure ExecuteFmt(const SQL: string; const FmtParams: array of const);
    function LastInsertRowID: Int64;
  {FetchCount...}
    function BindAndFetchCount(const Params: array of const; const SQL: string): integer;
    function FetchCount(const SQL: string): integer; overload;
    function FetchCount(const SQL: string; const FmtParams: array of const): integer; overload;
    function FetchCountFmt(const SQL: string; const FmtParams: array of const): integer;
  {Blobs}
    function BlobOpen(const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean): ISqlite3BlobHandler;
  {Transactions...}
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    procedure Transaction(const Proc: TProc); overload;
  {Application-Defined Functons...}
    procedure AdfCreateFunction(Name: string; ArgCount: integer; xFunc: TSQLite3RegularFunction);
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
    function  BindAndStep(const Params: array of const): integer; overload;
    function  BindAndStep(const Params: TArray<string>): integer; overload;
    function  Step: integer;
    function  StepAndReset: integer;
  {Fetching, Updating}
    procedure Reset;
    procedure Fetch(const FetchProc: TProc);
    procedure BindAndFetch(const Params: array of const; const StepProc: TProc);
    function SqlColumnCount: integer;
  public
    constructor Create(OwnerDatabase: ISqlite3Database; const SQL: string);
    destructor Destroy; override;
  end;

  TSqlite3BlobHandler = class(TInterfacedObject, ISqlite3BlobHandler)
  (***********************************************************************************************
   * FYI: ISqliteBlobHandler is used for very large BLOBs where you want to be read/write directly
   *      or incrementally. I have never used it, as I have not dealt with very large BLOBs.
   *      To get a Blob Handler, you use the DB.BlobOpen method, but you need to kow RowID,
   *      so, you cannot use this on tables that are defined WITHOUT ROWID. It is more common to
   *      use regular TSqlParam.BindBlob() and TSqlColumn.AsBlob methods to set/get BLOBs.
   ***********************************************************************************************)
  private
    FHandle: PSqlite3Blob;
    FOwnerDatabase: ISqlite3Database;
  {Getters...}
    function GetHandle: PSqlite3Blob;
    function GetOwnerDatabase: ISqlite3Database;
  {Read/Write Blob...}
    function BlobBytes: integer;
    procedure Read(ByteArray: TBytes; const Offset, Size: integer);
    procedure Write(ByteArray: TBytes; const Offset: integer; const Size: integer);
  public
    constructor Create(OwnerDatabase: ISqlite3Database; const Table, Column: string; const RowID: Int64; const WriteAccess: Boolean = True);
    destructor Destroy; override;
  end;

  {General Global Sqlite Object/methods...}
  TSqlite3 = class
  private
    class var FSqliteVersion: string;
  public
  {General class functions...}
    class function ThreadSafe: Boolean;
    class function LibPath: string;
    class function VersionStr: string;
    class function CompileOptions: string;
    class function OpenDatabase(const Filename: string; OpenFlags: integer = SQLITE_OPEN_DEFAULT): ISqlite3Database;
    class function OpenDatabaseIntoMemory(const Filename: string): ISqlite3Database;
  {Application Defined function helpers...}
    class function AdfValueText(Value: PSqlite3Value): string;
    class function AdfValueInt(Value: PSqlite3Value): integer;
    class function AdfValueInt64(Value: PSqlite3Value): Int64;
    class function AdfValueDouble(Value: PSqlite3Value): Double;
    class procedure AdfResultText(Context: PSQLite3Context; Result: string);
    class procedure AdfResultInt(Context: PSQLite3Context; Result: integer);
    class procedure AdfResultInt64(Context: PSQLite3Context; Result: Int64);
    class procedure AdfResultDouble(Context: PSQLite3Context; Result: Double);
  end;

var
  DB: ISqlite3Database;

Implementation

{$REGION ' Local Utility '}

function CompareVersions(const S1, S2: string): integer;

  function ParseVersionStr(VerStr: string): TArray<integer>;
  begin
    var StrArray := SplitString(VerStr, '.');
    Result := TArray<integer>.Create(0, 0, 0, 0);
    for var i := 0 to High(StrArray) do
      Result[i] := StrArray[i].ToInteger;
  end;

begin
  var Version1 := ParseVersionStr(S1);
  var Version2 := ParseVersionStr(S2);
  for var i := 0 to 3 do
  begin
    Result := CompareValue(Version1[i], Version2[i]);
    if Result <> 0 then
      break;
  end;
end;

{$ENDREGION}

{$REGION ' Sqlite DLL Api Externals '}

const
  SQL_NTS = -1;
  SQLITE_STATIC    = Pointer(0);
  SQLITE_TRANSIENT = Pointer(-1);
  SQLITE_UTF8 = $00000001;
  SQLITE_DETERMINISTIC = $00000800;

type
  PUtf8           = PAnsiChar;
  PPByte          = ^PByte;
  PSqliteBackup   = Pointer;
  TPAnsiCharArray = array[0..MaxInt div SizeOf(PAnsiChar) - 1] of PAnsiChar;
  PPAnsiCharArray = ^TPAnsiCharArray;
  TSqliteCallback           = function(pArg: Pointer; nCol: Integer; argv: PPAnsiCharArray; colv: PPAnsiCharArray): Integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF};
  TSqlite3_Destroy_Callback = procedure(p: Pointer); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF};
  TSQLite3AggregateStep     = procedure(ctx: PSQLite3Context; n: Integer; apVal: PPSQLite3ValueArray); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF};
  TSQLite3AggregateFinalize = procedure(ctx: PSQLite3Context); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF};
  TSQLite3DestructorType    = procedure(p: Pointer); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF};

(**************************************************************************************************************
 *  This is the subset of sqlite3 function definitions required to support this unit.
 *
 *  I mimic these prototypes as defined in the FireDAC.Phys.SQLiteWrapper.Stat for consistency.
 *  FireDac likes to use PByte for text, so some additional typecasting is needed below.
 *  FireDAC param types:
 *    PByte (System.Types) = System.Byte = ^Byte
 *    PUtf8 (FiresDAC.Phys.SqliteCli) = PFDAnsiString = PAnsiChar
 *    PFDAnsiChar (FireDAC.Stan.Intf) = PAnsiChar
 **************************************************************************************************************)

const SQLITE3_DLL = {$IFDEF SQLITE_WIN}'winsqlite3.dll'{$ELSE}'sqlite3.dll'{$ENDIF};

function sqlite3_config(Option: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_initialize: integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_libversion: PAnsiChar; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_errmsg(DB: PSqlite3): PAnsiChar; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_threadsafe: integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

function sqlite3_open_v2(FileName: PUtf8; out ppDb: PSqlite3; Flags: integer; zVfs: PAnsiChar): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_close_v2(DB: PSqlite3): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_backup_init(pDest: PSqlite3; zDestName: PByte; pSource: PSqlite3; zSourceName: PByte): PSqliteBackup; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_backup_step(p: PSqliteBackup; nPage: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_backup_finish(p: PSqliteBackup): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

function sqlite3_exec(DB: PSqlite3; SQL: PByte; callback: TSqliteCallback; pArg: Pointer; errmsg: PPAnsiChar): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_prepare_v2(DB: PSQLite3; zSql: PByte; nByte: Integer; out ppStmt: PSQLite3Stmt; var pzTail: PByte): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_finalize(pStmt: PSqlite3Stmt): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_reset(pStmt: PSqlite3Stmt): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_last_insert_rowid(DB: PSqlite3): Int64; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

function sqlite3_bind_parameter_count(pStmt: PSqlite3Stmt): Integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_parameter_index(pStmt: PSqlite3Stmt; zName: PAnsiChar): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_blob(pStmt: PSqlite3Stmt; i: integer; zData: Pointer; n: integer; xDel: TSqlite3_Destroy_Callback): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_double(pStmt: PSqlite3Stmt; i: integer; rValue: Double): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: integer; iValue: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_int64(pStmt: PSqlite3Stmt; i: integer; iValue: Int64): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_null(pStmt: PSqlite3Stmt; i: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: integer; zData: PByte; n: integer; xDel: TSqlite3_Destroy_Callback): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_bind_zeroblob(pStmt: PSqlite3Stmt; i: integer; n: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

function sqlite3_clear_bindings(pStmt: PSqlite3Stmt): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_step(pStmt: PSqlite3Stmt): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

function sqlite3_column_blob(pStmt: PSqlite3Stmt; iCol: integer): Pointer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_double(pStmt: PSqlite3Stmt; iCol: integer): Double; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_int64(pStmt: PSqlite3Stmt; iCol: integer): Int64; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: integer): PByte; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_bytes(pStmt: PSqlite3Stmt; iCol: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_type(pStmt: PSqlite3Stmt; iCol: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_count(pStmt: PSqlite3Stmt): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_column_name(pStmt: PSqlite3Stmt; n: integer): PAnsiChar; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

function sqlite3_blob_bytes(pBlob: PSqlite3Blob): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_blob_open(DB: PSqlite3; zDb: PAnsiChar; zTable: PAnsiChar; zColumn: PAnsiChar; iRow: Int64; Flags: integer; var ppBlob: PSqlite3Blob): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_blob_close(pBlob: PSqlite3Blob): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_blob_read(pBlob: PSqlite3Blob; Z: Pointer; n: integer; iOffset: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_blob_write(pBlob: PSqlite3Blob; Z: Pointer; n: integer; iOffset: integer): integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

function sqlite3_create_function(db: PSQLite3; const zFunctionName: PByte; nArg: Integer; eTextRep: Integer; pApp: Pointer; xFunc: TSQLite3RegularFunction; xStep: TSQLite3AggregateStep; xFinal: TSQLite3AggregateFinalize): Integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_value_int(pVal: PSQLite3Value): Integer; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_value_int64(pVal: PSQLite3Value): Int64; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_value_double(pVal: PSQLite3Value): Double; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
function sqlite3_value_text(pVal: PSQLite3Value): PByte; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
procedure sqlite3_result_int(pCtx: PSQLite3Context; iVal: Integer); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
procedure sqlite3_result_int64(pCtx: PSQLite3Context; iVal: Int64); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
procedure sqlite3_result_double(pCtx: PSQLite3Context; rVal: Double); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;
procedure sqlite3_result_text(pCtx: PSQLite3Context; const z: PByte; n: Integer; xDel: TSQLite3DestructorType); {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF}; external SQLITE3_DLL;

procedure sqlite3_shutdown; {$IFDEF SQLITE_WIN}stdcall{$ELSE}cdecl{$ENDIF};  external SQLITE3_DLL;

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
  FStmt.OwnerDatabase.Check(sqlite3_bind_text(FStmt.Handle, FParamIndex, PByte(Utf8Encode(Value)), SQL_NTS, SQLITE_TRANSIENT));
end;

procedure TSqlParam.BindNull;
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_null(FStmt.Handle, FParamIndex));
end;

procedure TSqlParam.BindBlob(const Data: TBytes);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_blob(FStmt.Handle, FParamIndex, Data, Length(Data), SQLITE_TRANSIENT));
end;

procedure TSqlParam.BindZeroBlob(const Size: integer);
begin
  FStmt.OwnerDatabase.Check(sqlite3_bind_zeroblob(FStmt.Handle, FParamIndex, Size));
end;

{$ENDREGION}

{$REGION ' TSqlColumn '}

function TSqlColumn.AsBool: Boolean;
begin
  Result := Boolean(sqlite3_column_int(FStmt.Handle, FColumnIndex));
end;

function TSqlColumn.ColBytes: Integer;
begin
  Result := sqlite3_column_bytes(FStmt.Handle, FColumnIndex);
end;

function TSqlColumn.AsDouble: Double;
begin
  Result := sqlite3_column_double(FStmt.Handle, FColumnIndex);
end;

function TSqlColumn.AsInt: integer;
begin
  Result := sqlite3_column_int(FStmt.Handle, FColumnIndex);
end;

function TSqlColumn.AsInt64: Int64;
begin
  Result := sqlite3_column_int64(FStmt.Handle, FColumnIndex);
end;

function TSqlColumn.AsText: string;
begin
  Result := Utf8ToString(PUtf8(sqlite3_column_text(FStmt.Handle, FColumnIndex)));
end;

function TSqlColumn.AsBlob: TBytes;
var
  Data: Pointer;
begin
  var Size := ColBytes;
  SetLength(Result, Size);
  if Size <> 0 then
  begin
    Data := sqlite3_column_blob(FStmt.Handle, FColumnIndex);
    if Assigned(Data) then
      Move(Data^, Result[0], Size);
  end;
end;

function TSqlColumn.ColName: string;
begin
  Result := Utf8ToString(PUtf8(sqlite3_column_name(FStmt.Handle, FColumnIndex)));
end;

function TSqlColumn.ColType: integer;
begin
  Result := sqlite3_column_type(FStmt.Handle, FColumnIndex);
end;

function TSqlColumn.IsNull: Boolean;
begin
  Result := ColType = SQLITE_NULL;
end;

{$ENDREGION}

{$REGION ' TSqlite3Database '}

constructor TSqlite3Database.Create;
begin
  sqlite3_initialize;
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
    raise ESqliteError.Create(Format(SErrorMessage, [ErrCode, Utf8ToString(PAnsiChar(sqlite3_errmsg(FHandle)))]), ErrCode);
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

procedure TSqlite3Database.Open(const Filename: string; OpenFlags: integer);
begin
  Close;
  FFilename := Filename;

  {Open database...}
  Check(sqlite3_open_v2(PUtf8(Utf8Encode(FFilename)), FHandle, OpenFlags, nil));

  {Always enable foreign keys...}
  Execute('pragma foreign_keys = on');
  {Default journal_mode=memory; synchronous=off}
  Execute('pragma journal_mode = memory; pragma synchronous = off');
end;

procedure TSqlite3Database.OpenIntoMemory(const Filename: string);
var
  TempDB: ISqlite3Database;
  Backup: PSqliteBackup;
begin
  TempDB := TSqlite3Database.Create;
  Open(MEMORY, SQLITE_OPEN_DEFAULT);
  FFilename := Filename;
  TempDB.Open(Filename, SQLITE_OPEN_READONLY);
  Backup := sqlite3_backup_init(Self.Handle, PByte(PAnsiChar('main')), TempDB.Handle, PByte(PAnsiChar('main')));
  sqlite3_backup_step(Backup, -1);
  sqlite3_backup_finish(Backup);
  TempDB.Close;
end;

procedure TSqlite3Database.Close;
begin
  if Assigned(FHandle) then
  begin
    {Rollback if transaction left open (Sqlite should do this automatically, but we are doing it explcitly anyway)...}
    if FTransactionOpen then
      Rollback;

    {Close Database...}
    {Note: FDSTATIC does not include sqlite3_close_v2(), so we must use the older sqlite3_close().
           The older sqlite3_close() will fail if all connection handles are not already closed.
           So, if SQLITE_FDSTATIC is defined, we enable Statement and Blob Handler lists and close
           them ourselves.}
    Check(sqlite3_close_v2(Handle));
    FHandle := nil;
    FFilename := '';
  end;
end;

procedure TSqlite3Database.Backup(const Filename: string);
begin
  DeleteFile(Filename);
  ExecuteFmt('VACUUM INTO %s', [QuotedStr(Filename)])
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

function TSqlite3Database.PrepareFmt(const SQL: string; const FmtParams: array of const): ISqlite3Statement;
begin
  Result := Prepare(Format(SQL, FmtParams));
end;

function TSqlite3Database.BindAndFetchCount(const Params: array of const; const SQL: string): integer;
begin
  Assert(ContainsText(SQL, 'SELECT Count('), SImproperSQL);
  with Prepare(SQL) do
  begin
    BindParams(Params);
    Step;
    Result := SqlColumn[0].AsInt;
  end;
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

function TSqlite3Database.FetchCountFmt(const SQL: string; const FmtParams: array of const): integer;
begin
  Result := FetchCount(Format(SQL, FmtParams));
end;

procedure TSqlite3Database.Execute(const SQL: string);
begin
  CheckHandle;
  Check(sqlite3_exec(Handle, PByte(Utf8Encode(SQL)), nil, nil, nil));
end;

procedure TSqlite3Database.Execute(const SQL: string; const FmtParams: array of const);
begin
  Execute(Format(SQL, FmtParams));
end;

procedure TSqlite3Database.ExecuteFmt(const SQL: string; const FmtParams: array of const);
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

procedure TSqlite3Database.AdfCreateFunction(Name: string; ArgCount: integer; xFunc: TSQLite3RegularFunction);
(**************************************************************************************************
 *  Application Defined Function:
 *
 *  Define and Register your application-defined Sqlite function something like the following:
 *
 *    procedure MyFunction(Context: Pointer; n: integer; Args: PPSQLite3ValueArray); stdcall;
 *    begin
 *      var Arg := TSqlite3.AdfValueText(args[0]); {Get the arument(s)}
 *      var AdfResult := SomeFunction(Arg);        {}
 *      TSqlite3.AdfResultText(Context, AdfResult);
 *    end;
 *
 *    The procedure has to match calling convention of sqlite3 dll, which is stdcall for WinSQlite3.dll.
 *
 *    DB.AdfCreateFunction('MyFunction', 1, @MyFunction);
 *
 *  After that, you can use the function in SQL statements
 *    SELECT MyFunction(MyField) FROM MyTable;
 *
 *  **You can't define an application-defined function anonmously.
 *
 **************************************************************************************************)
begin
  sqlite3_create_function(Handle, PByte(Utf8Encode(Name)), ArgCount, SQLITE_UTF8 or SQLITE_DETERMINISTIC, nil, @xFunc, nil, nil);
end;

{$ENDREGION}

{$REGION ' TSqlite3Statment '}

constructor TSQLite3Statement.Create(OwnerDatabase: ISqlite3Database; const SQL: string);
begin
  FOwnerDatabase := OwnerDatabase;
  FOwnerDatabase.CheckHandle;
  var pzTail:PByte := nil;
  FOwnerDatabase.Check(sqlite3_prepare_v2(FOwnerDatabase.Handle, PByte(Utf8Encode(SQL)), SQL_NTS, FHandle, pzTail));
end;

destructor TSQLite3Statement.Destroy;
begin
  if Assigned(FHandle) then
    sqlite3_finalize(FHandle);
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
  Result.FParamIndex := sqlite3_bind_parameter_index(FHandle, PUtf8(Utf8Encode(ParamName)));
end;

function TSQLite3Statement.GetSqlColumn(const ColumnIndex: integer): TSqlColumn;
begin
  Result.FStmt := Self;
  Result.FColumnIndex := ColumnIndex;
end;

procedure TSQLite3Statement.ClearBindings;
begin
  FOwnerDatabase.Check(sqlite3_clear_bindings(FHandle));
end;

procedure TSQLite3Statement.BindParams(const Params: array of const);
begin
  Assert(High(Params) = sqlite3_bind_parameter_count(FHandle)-1, SParamCountMismatch);
  {Reset and Bind all params...}
  Reset;
  for var i := 0 to High(Params) do
  begin
    var ASqlParam := GetSqlParam(i+1);
    case Params[i].VType of
      vtWideString:    ASqlParam.BindText(string(PWideChar(Params[i].VWideString)));
      vtUnicodeString: ASqlParam.BindText(string(PWideChar(Params[i].VUnicodeString)));
      vtInteger:       ASqlParam.BindInt(Params[i].VInteger);
      vtExtended:      ASqlParam.BindDouble(Double(Params[i].VExtended^));
      vtInt64:         ASqlParam.BindInt64(Params[i].VInt64^);
      vtPointer:       if Params[i].VPointer <> nil then raise Exception.CreateFmt(STypeNotSupported, [Params[i].VType]);
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
  var PTable := PUtf8(Utf8Encode(Table));
  var PColumn := PUtf8(Utf8Encode(Column));
  FOwnerDatabase.Check(sqlite3_blob_open(FOwnerDatabase.Handle, 'main', PTable, PColumn, RowID, Ord(WriteAccess), FHandle));
end;

destructor TSqlite3BlobHandler.Destroy;
begin
  if Assigned(FHandle) then
  begin
    sqlite3_blob_close(FHandle);
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

function TSqlite3BlobHandler.BlobBytes: integer;
begin
  Result := sqlite3_blob_bytes(FHandle);
end;

procedure TSqlite3BlobHandler.Read(ByteArray: TBytes; const Offset, Size: integer);
begin
  SetLength(ByteArray, Size);
  FOwnerDatabase.Check(sqlite3_blob_read(FHandle, ByteArray, Size, Offset));
end;

procedure TSqlite3BlobHandler.Write(ByteArray: TBytes; const Offset: integer; const Size: integer);
var
  LCount: integer;
begin
  if Size = -1 then
    LCount := Length(ByteArray)
  else
    LCount := Size;
  FOwnerDatabase.Check(sqlite3_blob_write(FHandle, ByteArray, LCount, Offset));
end;

{$ENDREGION}

{$REGION ' TSqlite3 Class Functions '}

class function TSqlite3.VersionStr: string;
begin
  if FSqliteVersion = '' then
    FSqliteVersion := Utf8ToString(sqlite3_libversion);
  Result := FSqliteVersion;
end;

class function TSqlite3.CompileOptions: string;
begin
  Result := '';
  with OpenDatabase(MEMORY).Prepare('PRAGMA compile_options') do
    while Step = SQLITE_ROW do
      Result := Result + SqlColumn[0].AsText + #13#10;
end;

class function TSqlite3.LibPath: string;
begin
  var L := MAX_PATH + 1;
  SetLength(Result, L);
  L := GetModuleFilename(GetModuleHandle(SQLITE3_DLL), Pointer(Result), L);
  SetLength(Result, L);
end;

class function TSqlite3.OpenDatabase(const Filename: string; OpenFlags: integer = SQLITE_OPEN_DEFAULT): ISqlite3Database;
begin
  Result := TSqlite3Database.Create;
  Result.Open(Filename, OpenFlags);
end;

class function TSqlite3.OpenDatabaseIntoMemory(const Filename: string): ISqlite3Database;
begin
  Result := TSqlite3Database.Create;
  Result.OpenIntoMemory(Filename);
end;

class function TSqlite3.ThreadSafe: Boolean;
begin
  Result := sqlite3_threadsafe <> 0;
end;

class function TSqlite3.AdfValueText(Value: PSqlite3Value): string;
begin
  Result := Utf8ToString(PUtf8(sqlite3_value_text(Value)));
end;

class function TSqlite3.AdfValueInt(Value: PSqlite3Value): integer;
begin
  Result := sqlite3_value_int(Value);
end;

class function TSqlite3.AdfValueInt64(Value: PSqlite3Value): Int64;
begin
  Result := sqlite3_value_int64(Value);
end;

class function TSqlite3.AdfValueDouble(Value: PSqlite3Value): Double;
begin
  Result := sqlite3_value_double(Value);
end;

class procedure TSqlite3.AdfResultText(Context: PSQLite3Context; Result: string);
begin
  sqlite3_result_text(Context, PByte(Utf8Encode(Result)), SQL_NTS, nil);
end;

class procedure TSqlite3.AdfResultInt(Context: PSQLite3Context; Result: integer);
begin
  sqlite3_result_int(Context, Result);
end;

class procedure TSqlite3.AdfResultInt64(Context: PSQLite3Context; Result: Int64);
begin
  sqlite3_result_int64(Context, Result);
end;

class procedure TSqlite3.AdfResultDouble(Context: PSQLite3Context; Result: Double);
begin
  sqlite3_result_double(Context, Result);
end;

{$ENDREGION}

procedure _Abort(ErrMsg: string);
begin
  {$IFNDEF CONSOLE}
  ShowMessage(ErrMsg);
  Application.Terminate;
  {$ELSE}
  Writeln(ErrMsg);
  ReadLn;
  Halt(1);
  {$ENDIF}
end;

Initialization
begin
  var MinVersion := '3.42.0';
  if CompareVersions(TSqlite3.VersionStr, MinVersion) < 0 then
    _Abort(Format('Sqlite3.dll Version %s or greater not found.  Application will terminate.', [MinVersion]));
end;

{$ENDREGION}

End.
