unit obNXPasAST;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  obNXPasSource;

type
  TNXPasNodeKind = (
    pnkUnknown,
    pnkCompilationUnit,
    pnkHeader,
    pnkUnitHeader,
    pnkProgramHeader,
    pnkLibraryHeader,
    pnkInterfaceSection,
    pnkImplementationSection,
    pnkUsesClause,
    pnkUsesUnit,
    pnkTypeSection,
    pnkConstSection,
    pnkConstDecl,
    pnkVarSection,
    pnkVarDecl,
    pnkRoutineDecl,
    pnkTypeDecl,
    pnkClassDecl,
    pnkRecordDecl,
    pnkObjectDecl,
    pnkInterfaceDecl,
    pnkFieldDecl,
    pnkPropertyDecl,
    pnkVisibilitySection
  );

  TNXPasASTNode = class
  private
    FChildren: TObjectList;
    FKind: TNXPasNodeKind;
    FName: string;
    FRange: TNXPasSourceRange;
    function GetChild(AIndex: Integer): TNXPasASTNode;
  public
    constructor Create(AKind: TNXPasNodeKind; const AName: string = '');
    destructor Destroy; override;

    function AddChild(AKind: TNXPasNodeKind; const AName: string = ''): TNXPasASTNode;
    function ChildCount: Integer;
    property Children[AIndex: Integer]: TNXPasASTNode read GetChild;
    property Kind: TNXPasNodeKind read FKind write FKind;
    property Name: string read FName write FName;
    property Range: TNXPasSourceRange read FRange write FRange;
  end;

  TNXPasSyntaxTree = class
  private
    FInactiveRegions: TNXPasInactiveRegionList;
    FRoot: TNXPasASTNode;
    FSource: TNXPasSourceFile;
  public
    constructor Create(ASource: TNXPasSourceFile);
    destructor Destroy; override;
    property InactiveRegions: TNXPasInactiveRegionList read FInactiveRegions;
    property Root: TNXPasASTNode read FRoot;
    property Source: TNXPasSourceFile read FSource;
  end;

function NXPasNodeKindName(AKind: TNXPasNodeKind): string;

implementation

uses
  SysUtils;

constructor TNXPasASTNode.Create(AKind: TNXPasNodeKind; const AName: string);
begin
  inherited Create;
  FKind := AKind;
  FName := AName;
  FChildren := TObjectList.Create(True);
end;

destructor TNXPasASTNode.Destroy;
begin
  FreeAndNil(FChildren);
  inherited Destroy;
end;

function TNXPasASTNode.GetChild(AIndex: Integer): TNXPasASTNode;
begin
  Result := TNXPasASTNode(FChildren[AIndex]);
end;

function TNXPasASTNode.AddChild(AKind: TNXPasNodeKind;
  const AName: string): TNXPasASTNode;
begin
  Result := TNXPasASTNode.Create(AKind, AName);
  FChildren.Add(Result);
end;

function TNXPasASTNode.ChildCount: Integer;
begin
  Result := FChildren.Count;
end;

constructor TNXPasSyntaxTree.Create(ASource: TNXPasSourceFile);
begin
  inherited Create;
  FSource := ASource;
  FInactiveRegions := TNXPasInactiveRegionList.Create(True);
  FRoot := TNXPasASTNode.Create(pnkCompilationUnit);
end;

destructor TNXPasSyntaxTree.Destroy;
begin
  FreeAndNil(FRoot);
  FreeAndNil(FInactiveRegions);
  inherited Destroy;
end;

function NXPasNodeKindName(AKind: TNXPasNodeKind): string;
begin
  case AKind of
    pnkUnknown:
      Result := 'Unknown';
    pnkCompilationUnit:
      Result := 'CompilationUnit';
    pnkHeader:
      Result := 'Header';
    pnkUnitHeader:
      Result := 'UnitHeader';
    pnkProgramHeader:
      Result := 'ProgramHeader';
    pnkLibraryHeader:
      Result := 'LibraryHeader';
    pnkInterfaceSection:
      Result := 'InterfaceSection';
    pnkImplementationSection:
      Result := 'ImplementationSection';
    pnkUsesClause:
      Result := 'UsesClause';
    pnkUsesUnit:
      Result := 'UsesUnit';
    pnkTypeSection:
      Result := 'TypeSection';
    pnkConstSection:
      Result := 'ConstSection';
    pnkConstDecl:
      Result := 'ConstDecl';
    pnkVarSection:
      Result := 'VarSection';
    pnkVarDecl:
      Result := 'VarDecl';
    pnkRoutineDecl:
      Result := 'RoutineDecl';
    pnkTypeDecl:
      Result := 'TypeDecl';
    pnkClassDecl:
      Result := 'ClassDecl';
    pnkRecordDecl:
      Result := 'RecordDecl';
    pnkObjectDecl:
      Result := 'ObjectDecl';
    pnkInterfaceDecl:
      Result := 'InterfaceDecl';
    pnkFieldDecl:
      Result := 'FieldDecl';
    pnkPropertyDecl:
      Result := 'PropertyDecl';
    pnkVisibilitySection:
      Result := 'VisibilitySection';
  else
    Result := '';
  end;
end;

end.
