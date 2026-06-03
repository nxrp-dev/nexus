unit obNXPasSymbols;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  obNXPasAST,
  obNXPasSource;

type
  TNXPasSymbolKind = (
    pskUnknown,
    pskUnit,
    pskProgram,
    pskLibrary,
    pskUsesUnit,
    pskType,
    pskClass,
    pskRecord,
    pskObject,
    pskInterface,
    pskRoutine,
    pskConst,
    pskVariable,
    pskField,
    pskParameter,
    pskProperty,
    pskVisibility
  );

  TNXPasSymbol = class
  private
    FChildren: TObjectList;
    FDeclaredTypeRange: TNXPasSourceRange;
    FDeclaredTypeText: string;
    FKind: TNXPasSymbolKind;
    FName: string;
    FNameRange: TNXPasSourceRange;
    FParent: TNXPasSymbol;
    FRange: TNXPasSourceRange;
    function GetChild(AIndex: Integer): TNXPasSymbol;
  public
    constructor Create;
    destructor Destroy; override;

    function AddChild(AKind: TNXPasSymbolKind; const AName: string;
      const ARange: TNXPasSourceRange): TNXPasSymbol;
    function ChildCount: Integer;
    property Children[AIndex: Integer]: TNXPasSymbol read GetChild;
    property DeclaredTypeRange: TNXPasSourceRange read FDeclaredTypeRange write FDeclaredTypeRange;
    property DeclaredTypeText: string read FDeclaredTypeText write FDeclaredTypeText;
    property Kind: TNXPasSymbolKind read FKind write FKind;
    property Name: string read FName write FName;
    property NameRange: TNXPasSourceRange read FNameRange write FNameRange;
    property Parent: TNXPasSymbol read FParent write FParent;
    property Range: TNXPasSourceRange read FRange write FRange;
  end;

  TNXPasSymbolTable = class(TObjectList)
  public
    function AddSymbol(AKind: TNXPasSymbolKind; const AName: string;
      const ARange: TNXPasSourceRange): TNXPasSymbol;
    function SymbolAt(AIndex: Integer): TNXPasSymbol;
  end;

  TNXPasSymbolExtractor = class
  private
    procedure ExtractNode(ANode: TNXPasASTNode; ASymbols: TNXPasSymbolTable;
      AParent: TNXPasSymbol);
    function HasSpecificTypeChild(ANode: TNXPasASTNode): Boolean;
    function NodeSymbolKind(ANode: TNXPasASTNode): TNXPasSymbolKind;
  public
    procedure Extract(ATree: TNXPasSyntaxTree; ASymbols: TNXPasSymbolTable);
  end;

function NXPasSymbolKindName(AKind: TNXPasSymbolKind): string;
function NXPasRangeContains(const ARange: TNXPasSourceRange; ALine,
  AColumn: Integer): Boolean;
function NXPasSymbolOwnerRoutine(ASymbol: TNXPasSymbol): TNXPasSymbol;
function NXPasSymbolIsRoutineOwned(ASymbol: TNXPasSymbol): Boolean;
function NXPasSymbolIsVisibleAt(ASymbol: TNXPasSymbol; ALine,
  AColumn: Integer): Boolean;
function NXPasSymbolIsWorkspaceVisible(ASymbol: TNXPasSymbol): Boolean;

implementation

uses
  SysUtils;

constructor TNXPasSymbol.Create;
begin
  inherited Create;
  FChildren := TObjectList.Create(True);
end;

destructor TNXPasSymbol.Destroy;
begin
  FreeAndNil(FChildren);
  inherited Destroy;
end;

function TNXPasSymbol.GetChild(AIndex: Integer): TNXPasSymbol;
begin
  Result := TNXPasSymbol(FChildren[AIndex]);
end;

function TNXPasSymbol.AddChild(AKind: TNXPasSymbolKind; const AName: string;
  const ARange: TNXPasSourceRange): TNXPasSymbol;
begin
  Result := TNXPasSymbol.Create;
  Result.Kind := AKind;
  Result.Name := AName;
  Result.Parent := Self;
  Result.Range := ARange;
  FChildren.Add(Result);
end;

function TNXPasSymbol.ChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TNXPasSymbolTable.AddSymbol(AKind: TNXPasSymbolKind;
  const AName: string; const ARange: TNXPasSourceRange): TNXPasSymbol;
begin
  Result := TNXPasSymbol.Create;
  Result.Kind := AKind;
  Result.Name := AName;
  Result.Parent := nil;
  Result.Range := ARange;
  Add(Result);
end;

function TNXPasSymbolTable.SymbolAt(AIndex: Integer): TNXPasSymbol;
begin
  Result := TNXPasSymbol(Items[AIndex]);
end;

function TNXPasSymbolExtractor.NodeSymbolKind(
  ANode: TNXPasASTNode): TNXPasSymbolKind;
begin
  Result := pskUnknown;
  case ANode.Kind of
    pnkUnitHeader:
      Result := pskUnit;
    pnkProgramHeader:
      Result := pskProgram;
    pnkLibraryHeader:
      Result := pskLibrary;
    pnkUsesUnit:
      Result := pskUsesUnit;
    pnkTypeDecl:
      if not HasSpecificTypeChild(ANode) then
        Result := pskType;
    pnkClassDecl:
      Result := pskClass;
    pnkRecordDecl:
      Result := pskRecord;
    pnkObjectDecl:
      Result := pskObject;
    pnkInterfaceDecl:
      Result := pskInterface;
    pnkRoutineDecl:
      Result := pskRoutine;
    pnkConstDecl:
      Result := pskConst;
    pnkVarDecl:
      Result := pskVariable;
    pnkFieldDecl:
      Result := pskField;
    pnkParameterDecl:
      Result := pskParameter;
    pnkPropertyDecl:
      Result := pskProperty;
    pnkVisibilitySection:
      Result := pskVisibility;
  end;
end;

function TNXPasSymbolExtractor.HasSpecificTypeChild(
  ANode: TNXPasASTNode): Boolean;
var
  lIdx: Integer;
begin
  Result := False;
  if ANode = nil then
    Exit;

  for lIdx := 0 to ANode.ChildCount - 1 do
    if ANode.Children[lIdx].Kind in [pnkClassDecl, pnkRecordDecl,
      pnkObjectDecl, pnkInterfaceDecl] then
      Exit(True);
end;

procedure TNXPasSymbolExtractor.ExtractNode(ANode: TNXPasASTNode;
  ASymbols: TNXPasSymbolTable; AParent: TNXPasSymbol);
var
  lKind: TNXPasSymbolKind;
  lIdx: Integer;
  lParent: TNXPasSymbol;
  lSymbol: TNXPasSymbol;
begin
  if (ANode = nil) or (ASymbols = nil) then
    Exit;

  lSymbol := nil;
  lKind := NodeSymbolKind(ANode);
  if (lKind <> pskUnknown) and (ANode.Name <> '') then
  begin
    if AParent <> nil then
      lSymbol := AParent.AddChild(lKind, ANode.Name, ANode.Range)
    else
      lSymbol := ASymbols.AddSymbol(lKind, ANode.Name, ANode.Range);
    lSymbol.DeclaredTypeText := ANode.DeclaredTypeText;
    lSymbol.DeclaredTypeRange := ANode.DeclaredTypeRange;
    lSymbol.NameRange := ANode.NameRange;
  end;

  if lSymbol <> nil then
    lParent := lSymbol
  else
    lParent := AParent;

  for lIdx := 0 to ANode.ChildCount - 1 do
    ExtractNode(ANode.Children[lIdx], ASymbols, lParent);
end;

procedure TNXPasSymbolExtractor.Extract(ATree: TNXPasSyntaxTree;
  ASymbols: TNXPasSymbolTable);
begin
  if (ATree = nil) or (ASymbols = nil) then
    Exit;

  ExtractNode(ATree.Root, ASymbols, nil);
end;

function NXPasSymbolKindName(AKind: TNXPasSymbolKind): string;
begin
  case AKind of
    pskUnknown:
      Result := 'Unknown';
    pskUnit:
      Result := 'Unit';
    pskProgram:
      Result := 'Program';
    pskLibrary:
      Result := 'Library';
    pskUsesUnit:
      Result := 'UsesUnit';
    pskType:
      Result := 'Type';
    pskClass:
      Result := 'Class';
    pskRecord:
      Result := 'Record';
    pskObject:
      Result := 'Object';
    pskInterface:
      Result := 'Interface';
    pskRoutine:
      Result := 'Routine';
    pskConst:
      Result := 'Const';
    pskVariable:
      Result := 'Variable';
    pskField:
      Result := 'Field';
    pskParameter:
      Result := 'Parameter';
    pskProperty:
      Result := 'Property';
    pskVisibility:
      Result := 'Visibility';
  else
    Result := '';
  end;
end;

function NXPasRangeContains(const ARange: TNXPasSourceRange; ALine,
  AColumn: Integer): Boolean;
begin
  Result := False;
  if (ALine < ARange.StartPos.Line) or (ALine > ARange.EndPos.Line) then
    Exit;

  if (ALine = ARange.StartPos.Line) and (AColumn < ARange.StartPos.Column) then
    Exit;

  if (ALine = ARange.EndPos.Line) and (AColumn > ARange.EndPos.Column) then
    Exit;

  Result := True;
end;

function NXPasSymbolOwnerRoutine(ASymbol: TNXPasSymbol): TNXPasSymbol;
begin
  Result := ASymbol;
  while Result <> nil do
  begin
    if Result.Kind = pskRoutine then
      Exit;
    Result := Result.Parent;
  end;
end;

function NXPasSymbolIsRoutineOwned(ASymbol: TNXPasSymbol): Boolean;
var
  lRoutine: TNXPasSymbol;
begin
  lRoutine := NXPasSymbolOwnerRoutine(ASymbol);
  Result := (lRoutine <> nil) and (lRoutine <> ASymbol);
end;

function NXPasSymbolIsVisibleAt(ASymbol: TNXPasSymbol; ALine,
  AColumn: Integer): Boolean;
var
  lRoutine: TNXPasSymbol;
begin
  if ASymbol = nil then
    Exit(False);

  lRoutine := NXPasSymbolOwnerRoutine(ASymbol);
  if (lRoutine = nil) or (lRoutine = ASymbol) then
    Exit(True);

  Result := NXPasRangeContains(lRoutine.Range, ALine, AColumn);
end;

function NXPasSymbolIsWorkspaceVisible(ASymbol: TNXPasSymbol): Boolean;
begin
  Result := False;
  if ASymbol = nil then
    Exit;

  if ASymbol.Kind in [pskUnknown, pskUsesUnit, pskVisibility, pskParameter] then
    Exit;

  if NXPasSymbolIsRoutineOwned(ASymbol) then
    Exit;

  Result := True;
end;

end.
