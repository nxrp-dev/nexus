unit obNXLSServiceContext;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CodeCache,
  fpjson,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams;

type
  TNXLSDocument = class
  private
    FURI: string;
    FLocalPath: string;
    FLanguageID: string;
    FVersion: Int64;
    FText: string;
    FOpen: Boolean;
    FCodeBuffer: TCodeBuffer;
  public
    procedure OpenFrom(AItem: TNXLSTextDocumentItem);
    procedure ApplyFullChange(AVersion: Int64; const AText: string);
    procedure SaveText(const AText: string);
    procedure Close;

    property URI: string read FURI;
    property LocalPath: string read FLocalPath;
    property LanguageID: string read FLanguageID;
    property Version: Int64 read FVersion;
    property Text: string read FText;
    property Open: Boolean read FOpen;
    property CodeBuffer: TCodeBuffer read FCodeBuffer;
  end;

  TNXLSLSPContext = class
  public
    procedure BeginInitialize(AParams: TNXLSInitializeParams); virtual; abstract;
    procedure MarkInitialized; virtual; abstract;
    procedure RequestShutdown; virtual; abstract;
    procedure RequestExit; virtual; abstract;

    function FindDocument(const AURI: string): TNXLSDocument; virtual; abstract;
    function RequireDocument(const AURI: string): TNXLSDocument; virtual; abstract;
    function OpenDocument(AItem: TNXLSTextDocumentItem): TNXLSDocument; virtual; abstract;
    procedure ChangeDocument(AIdentifier: TNXLSVersionedTextDocumentIdentifier; AChanges: TNXLSContentChangeArray); virtual; abstract;
    procedure SaveDocument(AParams: TNXLSDidSaveTextDocumentParams); virtual; abstract;
    procedure CloseDocument(AIdentifier: TNXLSTextDocumentIdentifier); virtual; abstract;
    function DocumentCount: Integer; virtual; abstract;
    function DocumentByIndex(AIndex: Integer): TNXLSDocument; virtual; abstract;
    procedure CheckDocument(ADocument: TNXLSDocument); virtual; abstract;
    procedure ReindexDocument(ADocument: TNXLSDocument); virtual; abstract;
    procedure AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray); virtual; abstract;
    procedure RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray); virtual; abstract;
    procedure RebuildWorkspaceIndex; virtual; abstract;

    procedure SendNotification(const AMethod: string; AParams: TJSONData); virtual; abstract;
  end;

  TNXLSLSPService = class
  protected
    FModel: TNXLSLSPContext;
  public
    constructor Create(AModel: TNXLSLSPContext); virtual;
    property Model: TNXLSLSPContext read FModel;
  end;

function NXLSFileURIToPath(const AURI: string): string;
function NXLSPathToFileURI(const AFileName: string): string;
function NXLSLoadCodeBuffer(const ALocalPath: string): TCodeBuffer;
function NXLSIsPascalSourceFile(const AFileName: string): Boolean;
procedure NXLSSetPosition(APosition: TNXLSPosition; ALine, ACharacter: Integer);

implementation

uses
  SysUtils,
  CodeToolManager;

function NXLSHexValue(AChar: Char): Integer;
begin
  case AChar of
    '0'..'9': Result := Ord(AChar) - Ord('0');
    'A'..'F': Result := Ord(AChar) - Ord('A') + 10;
    'a'..'f': Result := Ord(AChar) - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

function NXLSDecodeURIPath(const AValue: string): string;
var
  lIdx: Integer;
  lHi: Integer;
  lLo: Integer;
begin
  Result := '';
  lIdx := 1;
  while lIdx <= Length(AValue) do
  begin
    if (AValue[lIdx] = '%') and (lIdx + 2 <= Length(AValue)) then
    begin
      lHi := NXLSHexValue(AValue[lIdx + 1]);
      lLo := NXLSHexValue(AValue[lIdx + 2]);
      if (lHi >= 0) and (lLo >= 0) then
      begin
        Result := Result + Chr((lHi shl 4) + lLo);
        Inc(lIdx, 3);
        Continue;
      end;
    end;

    Result := Result + AValue[lIdx];
    Inc(lIdx);
  end;
end;

function NXLSFileURIToPath(const AURI: string): string;
var
  lRest: string;
  lAuthority: string;
  lPath: string;
  lSlashPos: Integer;
begin
  if Copy(AURI, 1, 7) <> 'file://' then
    raise Exception.CreateFmt('Only file URIs are supported for text documents: %s', [AURI]);

  lRest := Copy(AURI, 8, MaxInt);
  lAuthority := '';
  lPath := lRest;

  if (lRest <> '') and (lRest[1] <> '/') then
  begin
    lSlashPos := Pos('/', lRest);
    if lSlashPos = 0 then
    begin
      lAuthority := lRest;
      lPath := '';
    end
    else
    begin
      lAuthority := Copy(lRest, 1, lSlashPos - 1);
      lPath := Copy(lRest, lSlashPos, MaxInt);
    end;
  end;

  lPath := NXLSDecodeURIPath(lPath);

  if (lAuthority <> '') and (not SameText(lAuthority, 'localhost')) then
    Result := '\\' + NXLSDecodeURIPath(lAuthority) + lPath
  else
  begin
    Result := lPath;
    if (Length(Result) >= 3) and (Result[1] = '/') and (Result[3] = ':') then
      Delete(Result, 1, 1);
  end;

  Result := StringReplace(Result, '/', DirectorySeparator, [rfReplaceAll]);
end;

function NXLSPathCharToURI(const AChar: Char): string;
const
  cHex = '0123456789ABCDEF';
var
  lValue: Byte;
begin
  if AChar in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~', '/', ':'] then
    Result := AChar
  else
  begin
    lValue := Ord(AChar);
    Result := '%' + cHex[(lValue shr 4) + 1] + cHex[(lValue and $0F) + 1];
  end;
end;

function NXLSPathToFileURI(const AFileName: string): string;
var
  lPath: string;
  lIdx: Integer;
begin
  lPath := StringReplace(ExpandFileName(AFileName), DirectorySeparator, '/', [rfReplaceAll]);
  Result := 'file:///';
  for lIdx := 1 to Length(lPath) do
    Result := Result + NXLSPathCharToURI(lPath[lIdx]);
end;

function NXLSLoadCodeBuffer(const ALocalPath: string): TCodeBuffer;
begin
  if ALocalPath = '' then
    raise Exception.Create('Document local path is required.');

  Result := CodeToolBoss.FindFile(ALocalPath);
  if Result = nil then
    Result := CodeToolBoss.LoadFile(ALocalPath, False, False);
  if Result = nil then
    Result := CodeToolBoss.CreateFile(ALocalPath);
  if Result = nil then
    raise Exception.CreateFmt('Unable to create CodeTools buffer for %s', [ALocalPath]);
end;

function NXLSIsPascalSourceFile(const AFileName: string): Boolean;
var
  lExt: string;
begin
  lExt := LowerCase(ExtractFileExt(AFileName));
  Result := (lExt = '.pas') or (lExt = '.pp') or (lExt = '.inc') or
    (lExt = '.lpr') or (lExt = '.lpk');
end;

procedure NXLSSetPosition(APosition: TNXLSPosition; ALine, ACharacter: Integer);
begin
  if ALine < 0 then
    ALine := 0;
  if ACharacter < 0 then
    ACharacter := 0;

  APosition.line.Value := ALine;
  APosition.character.Value := ACharacter;
  APosition.Assigned := True;
end;

constructor TNXLSLSPService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create;
  FModel := AModel;
end;

procedure TNXLSDocument.OpenFrom(AItem: TNXLSTextDocumentItem);
begin
  if AItem = nil then
    raise Exception.Create('Text document item is required.');

  FURI := AItem.uri.Value;
  FLocalPath := NXLSFileURIToPath(FURI);
  FLanguageID := AItem.languageId.Value;
  FVersion := AItem.version.Value;
  FText := AItem.text.Value;
  FCodeBuffer := NXLSLoadCodeBuffer(FLocalPath);
  FCodeBuffer.Source := FText;
  FOpen := True;
end;

procedure TNXLSDocument.ApplyFullChange(AVersion: Int64; const AText: string);
begin
  FVersion := AVersion;
  FText := AText;
  if FCodeBuffer = nil then
    FCodeBuffer := NXLSLoadCodeBuffer(FLocalPath);
  FCodeBuffer.Source := FText;
  FOpen := True;
end;

procedure TNXLSDocument.SaveText(const AText: string);
begin
  FText := AText;
  if FCodeBuffer = nil then
    FCodeBuffer := NXLSLoadCodeBuffer(FLocalPath);
  FCodeBuffer.Source := FText;
end;

procedure TNXLSDocument.Close;
begin
  FOpen := False;
end;

end.
