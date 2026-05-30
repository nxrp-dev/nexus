unit obNXLSParser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes;

type
  TNXLSIdentifierSortMethod = (
    icsScopedAlphabetic
  );

  TNXLSIdentifierListItem = class
  private
    FIdentifier: string;
  public
    property Identifier: string read FIdentifier write FIdentifier;
  end;

  TNXLSIdentifierList = class
  private
    FPrefix: string;
    FSortForHistory: Boolean;
    FSortMethodForCompletion: TNXLSIdentifierSortMethod;
    function GetFilteredItem(AIndex: Integer): TNXLSIdentifierListItem;
  public
    function GetFilteredCount: Integer;
    property FilteredItems[AIndex: Integer]: TNXLSIdentifierListItem
      read GetFilteredItem;
    property Prefix: string read FPrefix write FPrefix;
    property SortForHistory: Boolean read FSortForHistory write FSortForHistory;
    property SortMethodForCompletion: TNXLSIdentifierSortMethod
      read FSortMethodForCompletion write FSortMethodForCompletion;
  end;

  TNXLSParser = class
  private
    FErrorColumn: Integer;
    FErrorLine: Integer;
    FErrorMessage: string;
    FIdentifierList: TNXLSIdentifierList;
  public
    constructor Create;
    destructor Destroy; override;
    function AddListToTreeOfPCodeXYPosition(AList: TList; ATree: TObject;
      AFreeListItems, AReplaceExisting: Boolean): Boolean;
    function CompleteCode(ACode: TObject; AX, AY, ATopLine,
      ABottomLine: Integer; out ANewCode: TObject): Boolean;
    function CreateFile(const AFilename: string): TObject;
    function CreateTreeOfPCodeXYPosition: TObject;
    function Explore(ACode: TObject; out ATool: TObject;
      AUpdate: Boolean = False): Boolean;
    function ExploreUnitDirectives(ACode: TObject; out AScanner: TObject):
      Boolean;
    function FindBlockCounterPart(ACode: TObject; AX, AY: Integer;
      out ANewCode: TObject; out ANewX, ANewY: Integer): Boolean;
    function FindCodeContext(ACode: TObject; AX, AY: Integer;
      out ATool: TObject): Boolean;
    function FindDeclaration(ACode: TObject; AX, AY: Integer;
      out ANewCode: TObject; out ANewX, ANewY, ANewTopLine,
      ABlockTopLine, ABlockBottomLine: Integer): Boolean;
    function FindDeclarationInInterface(ACode: TObject;
      const AIdentifier: string; out ANewCode: TObject; out ANewX, ANewY,
      ANewTopLine, ABlockTopLine, ABlockBottomLine: Integer): Boolean;
    function FindEmptyMethods(ACode: TObject; const AClassName: string;
      AX, AY: Integer; AList: TStrings): Boolean;
    function FindFile(const AFilename: string): TObject;
    function FindMainDeclaration(ACode: TObject; AX, AY: Integer;
      out ANewCode: TObject; out ANewX, ANewY, ANewTopLine: Integer):
      Boolean;
    function FindReferences(ACode: TObject; AX, AY: Integer; AList: TList):
      Boolean;
    function FindSmartHint(ACode: TObject; AX, AY: Integer): string;
    function FindUnusedUnits(ACode: TObject; AUnits: TStrings): Boolean;
    procedure FreeListOfPCodeXYPosition(AList: TList);
    procedure FreeTreeOfPCodeXYPosition(ATree: TObject);
    function GatherIdentifiers(ACode: TObject; AX, AY: Integer): Boolean;
    function GetIdentifierAt(ACode: TObject; AX, AY: Integer;
      out AIdentifier: string): Boolean;
    procedure Init(AOptions: TObject);
    function JumpToMethod(ACode: TObject; AX, AY: Integer;
      out ANewCode: TObject; out ANewX, ANewY: Integer): Boolean;
    function LoadFile(const AFilename: string; AUseCache: Boolean = False;
      AUpdateFromDisk: Boolean = False): TObject;
    function RemoveEmptyMethods(ACode: TObject; const AClassName: string;
      AX, AY: Integer): Boolean;
    function RemoveUnitFromAllUsesSections(ACode: TObject;
      const AUnitName: string): Boolean;
    property ErrorColumn: Integer read FErrorColumn;
    property ErrorLine: Integer read FErrorLine;
    property ErrorMessage: string read FErrorMessage;
    property IdentifierList: TNXLSIdentifierList read FIdentifierList;
  end;

var
  NXLSParser: TNXLSParser;

implementation

uses
  SysUtils;

function TNXLSIdentifierList.GetFilteredItem(AIndex: Integer):
  TNXLSIdentifierListItem;
begin
  Result := nil;
end;

function TNXLSIdentifierList.GetFilteredCount: Integer;
begin
  Result := 0;
end;

constructor TNXLSParser.Create;
begin
  inherited Create;
  FIdentifierList := TNXLSIdentifierList.Create;
end;

destructor TNXLSParser.Destroy;
begin
  FreeAndNil(FIdentifierList);
  inherited Destroy;
end;

function TNXLSParser.AddListToTreeOfPCodeXYPosition(AList: TList;
  ATree: TObject; AFreeListItems, AReplaceExisting: Boolean): Boolean;
begin
  Result := False;
end;

function TNXLSParser.CompleteCode(ACode: TObject; AX, AY, ATopLine,
  ABottomLine: Integer; out ANewCode: TObject): Boolean;
begin
  ANewCode := nil;
  Result := False;
end;

function TNXLSParser.CreateFile(const AFilename: string): TObject;
begin
  Result := nil;
end;

function TNXLSParser.CreateTreeOfPCodeXYPosition: TObject;
begin
  Result := nil;
end;

function TNXLSParser.Explore(ACode: TObject; out ATool: TObject;
  AUpdate: Boolean): Boolean;
begin
  ATool := nil;
  Result := False;
end;

function TNXLSParser.ExploreUnitDirectives(ACode: TObject;
  out AScanner: TObject): Boolean;
begin
  AScanner := nil;
  Result := False;
end;

function TNXLSParser.FindBlockCounterPart(ACode: TObject; AX, AY: Integer;
  out ANewCode: TObject; out ANewX, ANewY: Integer): Boolean;
begin
  ANewCode := nil;
  ANewX := 0;
  ANewY := 0;
  Result := False;
end;

function TNXLSParser.FindCodeContext(ACode: TObject; AX, AY: Integer;
  out ATool: TObject): Boolean;
begin
  ATool := nil;
  Result := False;
end;

function TNXLSParser.FindDeclaration(ACode: TObject; AX, AY: Integer;
  out ANewCode: TObject; out ANewX, ANewY, ANewTopLine,
  ABlockTopLine, ABlockBottomLine: Integer): Boolean;
begin
  ANewCode := nil;
  ANewX := 0;
  ANewY := 0;
  ANewTopLine := 0;
  ABlockTopLine := 0;
  ABlockBottomLine := 0;
  Result := False;
end;

function TNXLSParser.FindDeclarationInInterface(ACode: TObject;
  const AIdentifier: string; out ANewCode: TObject; out ANewX, ANewY,
  ANewTopLine, ABlockTopLine, ABlockBottomLine: Integer): Boolean;
begin
  ANewCode := nil;
  ANewX := 0;
  ANewY := 0;
  ANewTopLine := 0;
  ABlockTopLine := 0;
  ABlockBottomLine := 0;
  Result := False;
end;

function TNXLSParser.FindEmptyMethods(ACode: TObject;
  const AClassName: string; AX, AY: Integer; AList: TStrings): Boolean;
begin
  Result := False;
end;

function TNXLSParser.FindFile(const AFilename: string): TObject;
begin
  Result := nil;
end;

function TNXLSParser.FindMainDeclaration(ACode: TObject; AX, AY: Integer;
  out ANewCode: TObject; out ANewX, ANewY, ANewTopLine: Integer): Boolean;
begin
  ANewCode := nil;
  ANewX := 0;
  ANewY := 0;
  ANewTopLine := 0;
  Result := False;
end;

function TNXLSParser.FindReferences(ACode: TObject; AX, AY: Integer;
  AList: TList): Boolean;
begin
  Result := False;
end;

function TNXLSParser.FindSmartHint(ACode: TObject; AX, AY: Integer): string;
begin
  Result := '';
end;

function TNXLSParser.FindUnusedUnits(ACode: TObject; AUnits: TStrings):
  Boolean;
begin
  Result := False;
end;

procedure TNXLSParser.FreeListOfPCodeXYPosition(AList: TList);
begin
end;

procedure TNXLSParser.FreeTreeOfPCodeXYPosition(ATree: TObject);
begin
end;

function TNXLSParser.GatherIdentifiers(ACode: TObject; AX, AY: Integer):
  Boolean;
begin
  Result := False;
end;

function TNXLSParser.GetIdentifierAt(ACode: TObject; AX, AY: Integer;
  out AIdentifier: string): Boolean;
begin
  AIdentifier := '';
  Result := False;
end;

procedure TNXLSParser.Init(AOptions: TObject);
begin
end;

function TNXLSParser.JumpToMethod(ACode: TObject; AX, AY: Integer;
  out ANewCode: TObject; out ANewX, ANewY: Integer): Boolean;
begin
  ANewCode := nil;
  ANewX := 0;
  ANewY := 0;
  Result := False;
end;

function TNXLSParser.LoadFile(const AFilename: string; AUseCache: Boolean;
  AUpdateFromDisk: Boolean): TObject;
begin
  Result := nil;
end;

function TNXLSParser.RemoveEmptyMethods(ACode: TObject;
  const AClassName: string; AX, AY: Integer): Boolean;
begin
  Result := False;
end;

function TNXLSParser.RemoveUnitFromAllUsesSections(ACode: TObject;
  const AUnitName: string): Boolean;
begin
  Result := False;
end;

initialization
  NXLSParser := TNXLSParser.Create;

finalization
  FreeAndNil(NXLSParser);

end.
