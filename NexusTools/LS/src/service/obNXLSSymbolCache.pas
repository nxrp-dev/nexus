unit obNXLSSymbolCache;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Contnrs;

type
  TNXLSSymbolCacheSymbol = class
  private
    FName: string;
    FKind: Integer;
    FURI: string;
    FRangeStartLine: Integer;
    FRangeStartCharacter: Integer;
    FRangeEndLine: Integer;
    FRangeEndCharacter: Integer;
    FSelectionStartLine: Integer;
    FSelectionStartCharacter: Integer;
    FSelectionEndLine: Integer;
    FSelectionEndCharacter: Integer;
    FContainerName: string;
  public
    property Name: string read FName write FName;
    property Kind: Integer read FKind write FKind;
    property URI: string read FURI write FURI;
    property RangeStartLine: Integer read FRangeStartLine write FRangeStartLine;
    property RangeStartCharacter: Integer read FRangeStartCharacter write FRangeStartCharacter;
    property RangeEndLine: Integer read FRangeEndLine write FRangeEndLine;
    property RangeEndCharacter: Integer read FRangeEndCharacter write FRangeEndCharacter;
    property SelectionStartLine: Integer read FSelectionStartLine write FSelectionStartLine;
    property SelectionStartCharacter: Integer read FSelectionStartCharacter write FSelectionStartCharacter;
    property SelectionEndLine: Integer read FSelectionEndLine write FSelectionEndLine;
    property SelectionEndCharacter: Integer read FSelectionEndCharacter write FSelectionEndCharacter;
    property ContainerName: string read FContainerName write FContainerName;
  end;

  TNXLSSymbolCacheFile = class
  private
    FFileName: string;
    FURI: string;
    FFileStamp: LongInt;
    FFileSize: Int64;
    FScannerVersion: Integer;
    FSymbols: TObjectList;
  public
    constructor Create;
    destructor Destroy; override;

    procedure ClearSymbols;
    property FileName: string read FFileName write FFileName;
    property URI: string read FURI write FURI;
    property FileStamp: LongInt read FFileStamp write FFileStamp;
    property FileSize: Int64 read FFileSize write FFileSize;
    property ScannerVersion: Integer read FScannerVersion write FScannerVersion;
    property Symbols: TObjectList read FSymbols;
  end;

  TNXLSSymbolCache = class
  private
    FFiles: TObjectList;
    FCacheVersion: Integer;
    FScannerVersion: Integer;
    FDirty: Boolean;
    FStoreFileName: string;
    FStoreAvailable: Boolean;
    function FindFileIndexByURI(const AURI: string): Integer;
    function AddFileFromQuery(AQuery: TObject): TNXLSSymbolCacheFile;
    procedure LoadSymbolsForFile(AConnection: TObject; ATransaction: TObject; AFileID: Int64;
      AFile: TNXLSSymbolCacheFile);
    procedure ExecuteSQL(AConnection: TObject; const ASQL: string);
    procedure CreateSchema(AConnection: TObject);
    procedure DeleteFileRows(AConnection: TObject; const AURI: string);
    procedure InsertFileRows(AConnection: TObject; AFile: TNXLSSymbolCacheFile);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure Load(const AFileName: string);
    procedure Save(const AFileName: string);
    function FileByURI(const AURI: string): TNXLSSymbolCacheFile;
    function IsFresh(const AFileName, AURI: string): Boolean;
    function ReplaceFile(const AFileName, AURI: string): TNXLSSymbolCacheFile;
    procedure RemoveFile(const AURI: string);
    class function FileStamp(const AFileName: string): LongInt; static;
    class function FileSize(const AFileName: string): Int64; static;
    property CacheVersion: Integer read FCacheVersion;
    property ScannerVersion: Integer read FScannerVersion write FScannerVersion;
    property Dirty: Boolean read FDirty write FDirty;
    property StoreAvailable: Boolean read FStoreAvailable;
  end;

implementation

uses
  SysUtils,
  DB,
  SQLDB,
  SQLite3Conn;

const
  cNXLSSymbolCacheVersion = 1;
  cNXLSSymbolScannerVersion = 1;

function NXLSSQLText(const AValue: string): string;
begin
  Result := QuotedStr(AValue);
end;

constructor TNXLSSymbolCacheFile.Create;
begin
  inherited Create;
  FSymbols := TObjectList.Create(True);
end;

destructor TNXLSSymbolCacheFile.Destroy;
begin
  FreeAndNil(FSymbols);
  inherited Destroy;
end;

procedure TNXLSSymbolCacheFile.ClearSymbols;
begin
  FSymbols.Clear;
end;

constructor TNXLSSymbolCache.Create;
begin
  inherited Create;
  FFiles := TObjectList.Create(True);
  FCacheVersion := cNXLSSymbolCacheVersion;
  FScannerVersion := cNXLSSymbolScannerVersion;
  FStoreAvailable := True;
end;

destructor TNXLSSymbolCache.Destroy;
begin
  FreeAndNil(FFiles);
  inherited Destroy;
end;

procedure TNXLSSymbolCache.Clear;
begin
  FFiles.Clear;
  FDirty := False;
end;

function TNXLSSymbolCache.FindFileIndexByURI(const AURI: string): Integer;
var
  lIdx: Integer;
begin
  Result := -1;
  for lIdx := 0 to FFiles.Count - 1 do
    if SameText(TNXLSSymbolCacheFile(FFiles[lIdx]).URI, AURI) then
      Exit(lIdx);
end;

procedure TNXLSSymbolCache.ExecuteSQL(AConnection: TObject; const ASQL: string);
begin
  TSQLite3Connection(AConnection).ExecuteDirect(ASQL);
end;

procedure TNXLSSymbolCache.CreateSchema(AConnection: TObject);
begin
  ExecuteSQL(AConnection,
    'create table if not exists cache_meta (' +
    'key text primary key, ' +
    'value text not null)');
  ExecuteSQL(AConnection,
    'create table if not exists cache_file (' +
    'id integer primary key, ' +
    'file_name text not null, ' +
    'uri text not null unique, ' +
    'file_stamp integer not null, ' +
    'file_size integer not null, ' +
    'scanner_version integer not null)');
  ExecuteSQL(AConnection,
    'create table if not exists cache_symbol (' +
    'id integer primary key, ' +
    'file_id integer not null, ' +
    'name text not null, ' +
    'lower_name text not null, ' +
    'kind integer not null, ' +
    'range_start_line integer not null, ' +
    'range_start_character integer not null, ' +
    'range_end_line integer not null, ' +
    'range_end_character integer not null, ' +
    'selection_start_line integer not null, ' +
    'selection_start_character integer not null, ' +
    'selection_end_line integer not null, ' +
    'selection_end_character integer not null, ' +
    'container_name text not null, ' +
    'foreign key(file_id) references cache_file(id) on delete cascade)');
  ExecuteSQL(AConnection,
    'create index if not exists idx_cache_symbol_file_id on cache_symbol(file_id)');
  ExecuteSQL(AConnection,
    'create index if not exists idx_cache_symbol_lower_name on cache_symbol(lower_name)');
  ExecuteSQL(AConnection,
    'insert or replace into cache_meta(key, value) values(' +
    NXLSSQLText('cache_version') + ', ' + NXLSSQLText(IntToStr(FCacheVersion)) + ')');
  ExecuteSQL(AConnection,
    'insert or replace into cache_meta(key, value) values(' +
    NXLSSQLText('scanner_version') + ', ' + NXLSSQLText(IntToStr(FScannerVersion)) + ')');
end;

function TNXLSSymbolCache.AddFileFromQuery(AQuery: TObject): TNXLSSymbolCacheFile;
var
  lQuery: TSQLQuery;
begin
  lQuery := TSQLQuery(AQuery);
  Result := TNXLSSymbolCacheFile.Create;
  try
    Result.FileName := lQuery.FieldByName('file_name').AsString;
    Result.URI := lQuery.FieldByName('uri').AsString;
    Result.FileStamp := lQuery.FieldByName('file_stamp').AsInteger;
    Result.FileSize := StrToInt64Def(lQuery.FieldByName('file_size').AsString, -1);
    Result.ScannerVersion := lQuery.FieldByName('scanner_version').AsInteger;

    if (Result.FileName = '') or (Result.URI = '') or (not FileExists(Result.FileName)) then
      Exit;

    FFiles.Add(Result);
    Result := nil;
  finally
    Result.Free;
  end;

  Result := TNXLSSymbolCacheFile(FFiles[FFiles.Count - 1]);
end;

procedure TNXLSSymbolCache.LoadSymbolsForFile(AConnection: TObject; ATransaction: TObject;
  AFileID: Int64; AFile: TNXLSSymbolCacheFile);
var
  lQuery: TSQLQuery;
  lSymbol: TNXLSSymbolCacheSymbol;
begin
  if AFile = nil then
    Exit;

  lQuery := TSQLQuery.Create(nil);
  try
    lQuery.DataBase := TSQLite3Connection(AConnection);
    lQuery.Transaction := TSQLTransaction(ATransaction);
    lQuery.SQL.Text :=
      'select name, kind, range_start_line, range_start_character, ' +
      'range_end_line, range_end_character, selection_start_line, ' +
      'selection_start_character, selection_end_line, selection_end_character, ' +
      'container_name from cache_symbol where file_id = ' + IntToStr(AFileID) +
      ' order by id';
    lQuery.Open;
    while not lQuery.EOF do
    begin
      lSymbol := TNXLSSymbolCacheSymbol.Create;
      AFile.Symbols.Add(lSymbol);
      lSymbol.Name := lQuery.FieldByName('name').AsString;
      lSymbol.Kind := lQuery.FieldByName('kind').AsInteger;
      lSymbol.URI := AFile.URI;
      lSymbol.RangeStartLine := lQuery.FieldByName('range_start_line').AsInteger;
      lSymbol.RangeStartCharacter := lQuery.FieldByName('range_start_character').AsInteger;
      lSymbol.RangeEndLine := lQuery.FieldByName('range_end_line').AsInteger;
      lSymbol.RangeEndCharacter := lQuery.FieldByName('range_end_character').AsInteger;
      lSymbol.SelectionStartLine := lQuery.FieldByName('selection_start_line').AsInteger;
      lSymbol.SelectionStartCharacter := lQuery.FieldByName('selection_start_character').AsInteger;
      lSymbol.SelectionEndLine := lQuery.FieldByName('selection_end_line').AsInteger;
      lSymbol.SelectionEndCharacter := lQuery.FieldByName('selection_end_character').AsInteger;
      lSymbol.ContainerName := lQuery.FieldByName('container_name').AsString;
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TNXLSSymbolCache.Load(const AFileName: string);
var
  lDir: string;
  lConnection: TSQLite3Connection;
  lTransaction: TSQLTransaction;
  lQuery: TSQLQuery;
  lFile: TNXLSSymbolCacheFile;
  lFileID: Int64;
begin
  Clear;
  FStoreFileName := AFileName;
  if AFileName = '' then
    Exit;

  lDir := ExtractFileDir(AFileName);
  if (lDir <> '') and (not DirectoryExists(lDir)) then
    ForceDirectories(lDir);

  lConnection := TSQLite3Connection.Create(nil);
  lTransaction := TSQLTransaction.Create(nil);
  try
    lConnection.DatabaseName := AFileName;
    lConnection.Transaction := lTransaction;
    lTransaction.DataBase := lConnection;
    lConnection.Open;
    lTransaction.StartTransaction;
    try
      ExecuteSQL(lConnection, 'pragma foreign_keys = on');
      CreateSchema(lConnection);

      lQuery := TSQLQuery.Create(nil);
      try
        lQuery.DataBase := lConnection;
        lQuery.Transaction := lTransaction;
        lQuery.SQL.Text :=
          'select id, file_name, uri, file_stamp, file_size, scanner_version ' +
          'from cache_file where scanner_version = ' + IntToStr(FScannerVersion) +
          ' order by id';
        lQuery.Open;
        while not lQuery.EOF do
        begin
          lFileID := StrToInt64Def(lQuery.FieldByName('id').AsString, -1);
          lFile := AddFileFromQuery(lQuery);
          if lFile <> nil then
            LoadSymbolsForFile(lConnection, lTransaction, lFileID, lFile);
          lQuery.Next;
        end;
      finally
        lQuery.Free;
      end;
      lTransaction.Commit;
      FDirty := False;
      FStoreAvailable := True;
    except
      on Exception do
      begin
        if lTransaction.Active then
          lTransaction.Rollback;
        FStoreAvailable := False;
        Clear;
      end;
    end;
  finally
    lTransaction.Free;
    lConnection.Free;
  end;
end;

procedure TNXLSSymbolCache.DeleteFileRows(AConnection: TObject; const AURI: string);
begin
  ExecuteSQL(AConnection,
    'delete from cache_symbol where file_id in ' +
    '(select id from cache_file where uri = ' + NXLSSQLText(AURI) + ')');
  ExecuteSQL(AConnection,
    'delete from cache_file where uri = ' + NXLSSQLText(AURI));
end;

procedure TNXLSSymbolCache.InsertFileRows(AConnection: TObject; AFile: TNXLSSymbolCacheFile);
var
  lFileID: Int64;
  lSymbol: TNXLSSymbolCacheSymbol;
  lIdx: Integer;
begin
  if AFile = nil then
    Exit;

  ExecuteSQL(AConnection,
    'insert into cache_file(file_name, uri, file_stamp, file_size, scanner_version) values(' +
    NXLSSQLText(AFile.FileName) + ', ' +
    NXLSSQLText(AFile.URI) + ', ' +
    IntToStr(AFile.FileStamp) + ', ' +
    IntToStr(AFile.FileSize) + ', ' +
    IntToStr(AFile.ScannerVersion) + ')');
  lFileID := -1;
  with TSQLQuery.Create(nil) do
  try
    DataBase := TSQLite3Connection(AConnection);
    Transaction := TSQLite3Connection(AConnection).Transaction;
    SQL.Text := 'select last_insert_rowid() as id';
    Open;
    if not EOF then
      lFileID := StrToInt64Def(FieldByName('id').AsString, -1);
  finally
    Free;
  end;

  if lFileID < 0 then
    Exit;

  for lIdx := 0 to AFile.Symbols.Count - 1 do
  begin
    lSymbol := TNXLSSymbolCacheSymbol(AFile.Symbols[lIdx]);
    ExecuteSQL(AConnection,
      'insert into cache_symbol(file_id, name, lower_name, kind, ' +
      'range_start_line, range_start_character, range_end_line, range_end_character, ' +
      'selection_start_line, selection_start_character, selection_end_line, ' +
      'selection_end_character, container_name) values(' +
      IntToStr(lFileID) + ', ' +
      NXLSSQLText(lSymbol.Name) + ', ' +
      NXLSSQLText(LowerCase(lSymbol.Name)) + ', ' +
      IntToStr(lSymbol.Kind) + ', ' +
      IntToStr(lSymbol.RangeStartLine) + ', ' +
      IntToStr(lSymbol.RangeStartCharacter) + ', ' +
      IntToStr(lSymbol.RangeEndLine) + ', ' +
      IntToStr(lSymbol.RangeEndCharacter) + ', ' +
      IntToStr(lSymbol.SelectionStartLine) + ', ' +
      IntToStr(lSymbol.SelectionStartCharacter) + ', ' +
      IntToStr(lSymbol.SelectionEndLine) + ', ' +
      IntToStr(lSymbol.SelectionEndCharacter) + ', ' +
      NXLSSQLText(lSymbol.ContainerName) + ')');
  end;
end;

procedure TNXLSSymbolCache.Save(const AFileName: string);
var
  lDir: string;
  lConnection: TSQLite3Connection;
  lTransaction: TSQLTransaction;
  lIdx: Integer;
begin
  if (AFileName = '') or (not FStoreAvailable) then
    Exit;

  lDir := ExtractFileDir(AFileName);
  if (lDir <> '') and (not DirectoryExists(lDir)) then
    ForceDirectories(lDir);

  lConnection := TSQLite3Connection.Create(nil);
  lTransaction := TSQLTransaction.Create(nil);
  try
    lConnection.DatabaseName := AFileName;
    lConnection.Transaction := lTransaction;
    lTransaction.DataBase := lConnection;
    lConnection.Open;
    lTransaction.StartTransaction;
    try
      ExecuteSQL(lConnection, 'pragma foreign_keys = on');
      CreateSchema(lConnection);
      ExecuteSQL(lConnection, 'delete from cache_symbol');
      ExecuteSQL(lConnection, 'delete from cache_file');
      for lIdx := 0 to FFiles.Count - 1 do
        InsertFileRows(lConnection, TNXLSSymbolCacheFile(FFiles[lIdx]));
      lTransaction.Commit;
      FDirty := False;
      FStoreAvailable := True;
    except
      on Exception do
      begin
        if lTransaction.Active then
          lTransaction.Rollback;
        FStoreAvailable := False;
      end;
    end;
  finally
    lTransaction.Free;
    lConnection.Free;
  end;
end;

function TNXLSSymbolCache.FileByURI(const AURI: string): TNXLSSymbolCacheFile;
var
  lIdx: Integer;
begin
  Result := nil;
  lIdx := FindFileIndexByURI(AURI);
  if lIdx >= 0 then
    Result := TNXLSSymbolCacheFile(FFiles[lIdx]);
end;

function TNXLSSymbolCache.IsFresh(const AFileName, AURI: string): Boolean;
var
  lFile: TNXLSSymbolCacheFile;
begin
  Result := False;
  lFile := FileByURI(AURI);
  if lFile = nil then
    Exit;

  Result := SameText(ExpandFileName(AFileName), ExpandFileName(lFile.FileName)) and
    (lFile.ScannerVersion = FScannerVersion) and
    (lFile.FileStamp = FileStamp(AFileName)) and
    (lFile.FileSize = FileSize(AFileName));
end;

function TNXLSSymbolCache.ReplaceFile(const AFileName, AURI: string): TNXLSSymbolCacheFile;
var
  lIdx: Integer;
begin
  lIdx := FindFileIndexByURI(AURI);
  if lIdx >= 0 then
    Result := TNXLSSymbolCacheFile(FFiles[lIdx])
  else
  begin
    Result := TNXLSSymbolCacheFile.Create;
    FFiles.Add(Result);
  end;

  Result.FileName := ExpandFileName(AFileName);
  Result.URI := AURI;
  Result.FileStamp := FileStamp(AFileName);
  Result.FileSize := FileSize(AFileName);
  Result.ScannerVersion := FScannerVersion;
  Result.ClearSymbols;
  FDirty := True;
end;

procedure TNXLSSymbolCache.RemoveFile(const AURI: string);
var
  lIdx: Integer;
begin
  lIdx := FindFileIndexByURI(AURI);
  if lIdx >= 0 then
  begin
    FFiles.Delete(lIdx);
    FDirty := True;
  end;
end;

class function TNXLSSymbolCache.FileStamp(const AFileName: string): LongInt;
begin
  Result := SysUtils.FileAge(AFileName);
end;

class function TNXLSSymbolCache.FileSize(const AFileName: string): Int64;
var
  lSearch: TSearchRec;
begin
  Result := -1;
  if FindFirst(AFileName, faAnyFile, lSearch) = 0 then
  try
    Result := lSearch.Size;
  finally
    FindClose(lSearch);
  end;
end;

end.
