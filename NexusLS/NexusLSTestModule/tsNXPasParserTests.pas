unit tsNXPasParserTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasParserTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasLPIProject,
  obNXPasMetadata,
  obNXPasParser,
  obNXPasProject,
  obNXPasSearchPaths,
  obNXPasSource,
  obNXPasSymbols,
  obNXPasUnitLocator,
  obNXPasUnitResolver,
  obNXPasWorkspaceIndex,
  obNXTestContext,
  obNXTestSuite,
  tpNXPasTokens;

const
  cSimpleUnit =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'uses SysUtils, Classes;' + LineEnding +
    'type' + LineEnding +
    '  TSample = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  end;' + LineEnding +
    'const' + LineEnding +
    '  MaxCount = 10;' + LineEnding +
    'var' + LineEnding +
    '  GlobalName: string;' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';

function NXPasFindNode(ANode: TNXPasASTNode; AKind: TNXPasNodeKind;
  const AName: string): TNXPasASTNode;
var
  lIdx: Integer;
begin
  Result := nil;
  if ANode = nil then
    Exit;

  if (ANode.Kind = AKind) and ((AName = '') or (ANode.Name = AName)) then
    Exit(ANode);

  for lIdx := 0 to ANode.ChildCount - 1 do
  begin
    Result := NXPasFindNode(ANode.Children[lIdx], AKind, AName);
    if Result <> nil then
      Exit;
  end;
end;

function NXPasHasSymbol(ASymbols: TNXPasSymbolTable; AKind: TNXPasSymbolKind;
  const AName: string): Boolean;
var
  lIdx: Integer;
  lSymbol: TNXPasSymbol;
begin
  Result := False;
  if ASymbols = nil then
    Exit;

  for lIdx := 0 to ASymbols.Count - 1 do
  begin
    lSymbol := ASymbols.SymbolAt(lIdx);
    if (lSymbol.Kind = AKind) and (lSymbol.Name = AName) then
      Exit(True);
  end;
end;

function NXPasCreateTempDir(const APrefix: string): string;
var
  lTempFile: string;
begin
  lTempFile := GetTempFileName('', APrefix);
  if FileExists(lTempFile) then
    DeleteFile(lTempFile);

  Result := lTempFile + '_dir';
  ForceDirectories(Result);
end;

procedure NXPasWriteTextFile(const AFileName, AText: string);
var
  lText: TStringList;
begin
  ForceDirectories(ExtractFileDir(AFileName));
  lText := TStringList.Create;
  try
    lText.Text := AText;
    lText.SaveToFile(AFileName);
  finally
    lText.Free;
  end;
end;

function NXPasFindSymbol(ASymbols: TNXPasSymbolTable; AKind: TNXPasSymbolKind;
  const AName: string): TNXPasSymbol;
var
  lIdx: Integer;
  lSymbol: TNXPasSymbol;
begin
  Result := nil;
  if ASymbols = nil then
    Exit;

  for lIdx := 0 to ASymbols.Count - 1 do
  begin
    lSymbol := ASymbols.SymbolAt(lIdx);
    if (lSymbol.Kind = AKind) and (lSymbol.Name = AName) then
      Exit(lSymbol);
  end;
end;

function NXPasHasChildSymbol(ASymbol: TNXPasSymbol; AKind: TNXPasSymbolKind;
  const AName: string): Boolean;
var
  lIdx: Integer;
  lChild: TNXPasSymbol;
begin
  Result := False;
  if ASymbol = nil then
    Exit;

  for lIdx := 0 to ASymbol.ChildCount - 1 do
  begin
    lChild := ASymbol.Children[lIdx];
    if (lChild.Kind = AKind) and (lChild.Name = AName) then
      Exit(True);
  end;
end;

function NXPasFindChildSymbol(ASymbol: TNXPasSymbol; AKind: TNXPasSymbolKind;
  const AName: string): TNXPasSymbol;
var
  lChild: TNXPasSymbol;
  lIdx: Integer;
begin
  Result := nil;
  if ASymbol = nil then
    Exit;

  for lIdx := 0 to ASymbol.ChildCount - 1 do
  begin
    lChild := ASymbol.Children[lIdx];
    if (lChild.Kind = AKind) and (lChild.Name = AName) then
      Exit(lChild);
  end;
end;

function NXPasFindNamedSymbolWithChild(ASymbols: TNXPasSymbolTable;
  AKind: TNXPasSymbolKind; const AName: string; AChildKind: TNXPasSymbolKind;
  const AChildName: string): TNXPasSymbol;
var
  lIdx: Integer;
  lSymbol: TNXPasSymbol;
begin
  Result := nil;
  if ASymbols = nil then
    Exit;

  for lIdx := 0 to ASymbols.Count - 1 do
  begin
    lSymbol := ASymbols.SymbolAt(lIdx);
    if (lSymbol.Kind = AKind) and (lSymbol.Name = AName) and
      NXPasHasChildSymbol(lSymbol, AChildKind, AChildName) then
      Exit(lSymbol);
  end;
end;

function NXPasHasDiagnostic(ADiagnostics: TNXPasDiagnosticList;
  const ACode: string): Boolean;
var
  lIdx: Integer;
begin
  Result := False;
  if ADiagnostics = nil then
    Exit;

  for lIdx := 0 to ADiagnostics.Count - 1 do
    if ADiagnostics.DiagnosticAt(lIdx).Code = ACode then
      Exit(True);
end;

function NXPasParseText(const AText: string;
  ADiagnostics: TNXPasDiagnosticList; out ASource: TNXPasSourceFile;
  const ADefine: string = ''): TNXPasSyntaxTree;
var
  lParser: TNXPasParser;
begin
  ASource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    AText);
  if ADefine <> '' then
    ASource.Defines.Add(ADefine);
  lParser := TNXPasParser.Create(ADiagnostics);
  try
    Result := lParser.Parse(ASource);
  finally
    lParser.Free;
  end;
end;

procedure TestSourceRangeCreation(AContext: TNXTestContext);
var
  lEndPos: TNXPasSourcePosition;
  lRange: TNXPasSourceRange;
  lSource: TNXPasSourceFile;
  lStartPos: TNXPasSourcePosition;
begin
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas', 'unit Sample;');
  try
    lStartPos.Offset := 1;
    lStartPos.Line := 0;
    lStartPos.Column := 0;
    lEndPos.Offset := 5;
    lEndPos.Line := 0;
    lEndPos.Column := 4;

    lRange := lSource.RangeFromPositions(lStartPos, lEndPos);
    AContext.AssertEquals(1, lRange.StartPos.Offset,
      'Range start offset should match.');
    AContext.AssertEquals(4, lRange.EndPos.Column,
      'Range end column should match.');
  finally
    lSource.Free;
  end;
end;

procedure TestDiagnosticsCreation(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lRange: TNXPasSourceRange;
begin
  lRange.StartPos.Offset := 0;
  lRange.StartPos.Line := 0;
  lRange.StartPos.Column := 0;
  lRange.EndPos.Offset := 0;
  lRange.EndPos.Line := 0;
  lRange.EndPos.Column := 0;
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  try
    lDiagnostics.AddDiagnostic(pdsError, 'Expected identifier.', lRange);
    AContext.AssertEquals(1, lDiagnostics.Count,
      'Diagnostic list should own added diagnostics.');
    AContext.AssertEquals('Expected identifier.',
      lDiagnostics.DiagnosticAt(0).Message,
      'Diagnostic message should match.');
  finally
    lDiagnostics.Free;
  end;
end;

procedure TestShallowParseSimpleUnit(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    cSimpleUnit);
  lParser := TNXPasParser.Create(lDiagnostics);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    AContext.AssertTrue(NXPasFindNode(lTree.Root, pnkUnitHeader,
      'Sample') <> nil, 'Parser should recognize the unit header.');
    AContext.AssertTrue(NXPasFindNode(lTree.Root, pnkInterfaceSection,
      'interface') <> nil, 'Parser should recognize the interface section.');
    AContext.AssertTrue(NXPasFindNode(lTree.Root, pnkUsesClause,
      'uses') <> nil, 'Parser should recognize uses clauses.');
    AContext.AssertTrue(NXPasFindNode(lTree.Root, pnkTypeDecl,
      'TSample') <> nil, 'Parser should recognize type declarations.');
    AContext.AssertTrue(NXPasFindNode(lTree.Root, pnkClassDecl,
      'TSample') <> nil, 'Parser should recognize shallow class declarations.');
    AContext.AssertTrue(NXPasFindNode(lTree.Root, pnkRoutineDecl,
      'DoWork') <> nil, 'Parser should recognize routine declarations.');
  finally
    lTree.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestSymbolExtraction(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    cSimpleUnit);
  lParser := TNXPasParser.Create(lDiagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskUnit, 'Sample'),
      'Symbols should include the unit header.');
    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskType, 'TSample'),
      'Class declarations should not also emit generic type symbols.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskClass, 'TSample'),
      'Symbols should include class declarations.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskRoutine,
      'DoWork'), 'Symbols should include routine declarations.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestUsesUnitsAreNotTypeSymbols(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    cSimpleUnit);
  lParser := TNXPasParser.Create(lDiagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskUsesUnit, 'SysUtils'),
      'Uses clauses should produce uses-unit symbols.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskUsesUnit, 'Classes'),
      'All uses-clause names should remain uses-unit symbols.');
    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskType, 'SysUtils'),
      'Uses units must not be represented as type symbols.');
    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskClass, 'Classes'),
      'Uses units must not be represented as class symbols.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestStructuredClassBodySymbols(AContext: TNXTestContext);
var
  lClassSymbol: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TSample = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run(A: Integer; const B: string);' + LineEnding +
    '    property Items[Index: Integer; const Name: string]: string read GetItem;' + LineEnding +
    '  private' + LineEnding +
    '    FValue: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'end.');
  lParser := TNXPasParser.Create(lDiagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    lExtractor.Extract(lTree, lSymbols);

    lClassSymbol := NXPasFindSymbol(lSymbols, pskClass, 'TSample');
    AContext.AssertTrue(lClassSymbol <> nil, 'Class symbol should exist.');
    AContext.AssertTrue(NXPasHasChildSymbol(lClassSymbol, pskRoutine, 'Run'),
      'Class method should be nested under the class symbol.');
    AContext.AssertTrue(NXPasHasChildSymbol(lClassSymbol, pskProperty, 'Items'),
      'Indexed class property should be nested under the class symbol.');
    AContext.AssertTrue(NXPasHasChildSymbol(lClassSymbol, pskField, 'FValue'),
      'Class field should be nested under the class symbol.');
    AContext.AssertEquals(9, lClassSymbol.Range.EndPos.Line,
      'Class range should extend through the final end semicolon.');
    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskType, 'TSample'),
      'Structured class should not also emit a generic type symbol.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestForwardClassDeclarationAllowsLaterMembers(
  AContext: TNXTestContext);
var
  lClassSymbol: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lImplementationSymbol: TNXPasSymbol;
  lMethodSymbol: TNXPasSymbol;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TBar = class;' + LineEnding +
      '  TFoo = class;' + LineEnding +
      '  TFoo = class' + LineEnding +
      '  public' + LineEnding +
      '    procedure Run(AValue: TBar); virtual;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding +
      'procedure TFoo.Run(AValue: TBar);' + LineEnding +
      'begin' + LineEnding +
      'end;' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertFalse(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.structuredType.missingEnd'),
      'Forward class declarations should not enter body parsing.');
    lClassSymbol := NXPasFindNamedSymbolWithChild(lSymbols, pskClass, 'TFoo',
      pskRoutine, 'Run');
    AContext.AssertTrue(lClassSymbol <> nil,
      'Real class declaration after a forward declaration should keep members.');
    lMethodSymbol := NXPasFindChildSymbol(lClassSymbol, pskRoutine, 'Run');
    AContext.AssertTrue(lMethodSymbol <> nil,
      'Class-body method should be extracted.');
    lImplementationSymbol := NXPasFindSymbol(lSymbols, pskRoutine,
      'TFoo.Run');
    AContext.AssertTrue(lImplementationSymbol <> nil,
      'Qualified implementation method should be extracted.');
    AContext.AssertEquals(lImplementationSymbol.RoutineIdentity,
      lMethodSymbol.RoutineIdentity,
      'Class-body declaration and qualified implementation should share routine identity.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestClassRoutineRangeIncludesClassPrefix(AContext: TNXTestContext);
var
  lClassSymbol: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lImplementationSymbol: TNXPasSymbol;
  lMethodSymbol: TNXPasSymbol;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TFoo = class' + LineEnding +
      '  public' + LineEnding +
      '    class procedure Info(const AMessage: string); static;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding +
      'class procedure TFoo.Info(const AMessage: string);' + LineEnding +
      'begin' + LineEnding +
      'end;' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    lClassSymbol := NXPasFindNamedSymbolWithChild(lSymbols, pskClass, 'TFoo',
      pskRoutine, 'Info');
    AContext.AssertTrue(lClassSymbol <> nil,
      'Class declaration should be extracted.');
    lMethodSymbol := NXPasFindChildSymbol(lClassSymbol, pskRoutine, 'Info');
    AContext.AssertTrue(lMethodSymbol <> nil,
      'Class-body class procedure should be extracted.');
    lImplementationSymbol := NXPasFindSymbol(lSymbols, pskRoutine,
      'TFoo.Info');
    AContext.AssertTrue(lImplementationSymbol <> nil,
      'Implementation class procedure should be extracted.');

    AContext.AssertEquals(5, lMethodSymbol.Range.StartPos.Line,
      'Class-body class procedure range should start on the class token line.');
    AContext.AssertEquals(4, lMethodSymbol.Range.StartPos.Column,
      'Class-body class procedure range should start at the class token.');
    AContext.AssertEquals(5, lMethodSymbol.Range.EndPos.Line,
      'Class-body class procedure range should end on the static tail line.');
    AContext.AssertEquals(57, lMethodSymbol.Range.EndPos.Column,
      'Class-body class procedure range should end after static semicolon.');
    AContext.AssertEquals(8, lImplementationSymbol.Range.StartPos.Line,
      'Implementation class procedure range should start on the class token line.');
    AContext.AssertEquals(0, lImplementationSymbol.Range.StartPos.Column,
      'Implementation class procedure range should start at the class token.');
    AContext.AssertEquals('procedure', lMethodSymbol.RoutineKindText,
      'Class-body routine kind should stay normalized to the routine keyword.');
    AContext.AssertEquals('procedure', lImplementationSymbol.RoutineKindText,
      'Implementation routine kind should stay normalized to the routine keyword.');
    AContext.AssertEquals(lImplementationSymbol.RoutineIdentity,
      lMethodSymbol.RoutineIdentity,
      'Class-body declaration and implementation should keep matching identity.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestProcedureTypesUseBalancedDeclarationSkipping(
  AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  THandler = procedure(A: Integer; const B: string);' + LineEnding +
    '  TFactory = function(A: Integer; B: string): TObject;' + LineEnding +
    'implementation' + LineEnding +
    'end.');
  lParser := TNXPasParser.Create(lDiagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskType, 'THandler'),
      'Procedure type should remain one complete type declaration.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskType, 'TFactory'),
      'Function type after a procedure type should still be parsed.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestStructuredRecordBodySymbols(AContext: TNXTestContext);
var
  lRecordSymbol: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TPoint = record' + LineEnding +
    '    X, Y: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'end.');
  lParser := TNXPasParser.Create(lDiagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    lExtractor.Extract(lTree, lSymbols);

    lRecordSymbol := NXPasFindSymbol(lSymbols, pskRecord, 'TPoint');
    AContext.AssertTrue(lRecordSymbol <> nil, 'Record symbol should exist.');
    AContext.AssertTrue(NXPasHasChildSymbol(lRecordSymbol, pskField, 'X'),
      'First record field should be nested under the record symbol.');
    AContext.AssertTrue(NXPasHasChildSymbol(lRecordSymbol, pskField, 'Y'),
      'Second record field should be nested under the record symbol.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestStructuredInterfaceBodySymbols(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lInterfaceSymbol: TNXPasSymbol;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  ISample = interface' + LineEnding +
    '    procedure Run(A: Integer; const B: string);' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'end.');
  lParser := TNXPasParser.Create(lDiagnostics);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    lExtractor.Extract(lTree, lSymbols);

    lInterfaceSymbol := NXPasFindSymbol(lSymbols, pskInterface, 'ISample');
    AContext.AssertTrue(lInterfaceSymbol <> nil,
      'Interface symbol should exist.');
    AContext.AssertTrue(NXPasHasChildSymbol(lInterfaceSymbol, pskRoutine,
      'Run'), 'Interface method should be nested under the interface symbol.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestMissingUnitHeaderSemicolonDiagnostic(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertTrue(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.header.missingSemicolon'),
      'Parser should diagnose a missing unit header semicolon.');
    AContext.AssertTrue(lDiagnostics.DiagnosticAt(0).Range.StartPos.Line >= 0,
      'Diagnostic range should point into the source.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestMalformedUsesClauseDiagnostic(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'uses SysUtils' + LineEnding +
      'type' + LineEnding +
      '  TSample = class end;' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertTrue(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.uses.missingSemicolon'),
      'Parser should diagnose a missing uses clause semicolon.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestMissingClassEndRecoversSymbols(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TGood = class end;' + LineEnding +
      '  TBroken = class' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertTrue(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.structuredType.missingEnd'),
      'Parser should diagnose a structured type without end.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskUnit, 'Sample'),
      'Parser should still return the unit symbol.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskClass, 'TGood'),
      'Parser should preserve earlier symbols after recovery.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestMalformedClassMethodAllowsLaterMembers(AContext: TNXTestContext);
var
  lClassSymbol: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TSample = class' + LineEnding +
      '    procedure ;' + LineEnding +
      '    FValue: Integer;' + LineEnding +
      '    procedure Run;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertTrue(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.routine.malformed'),
      'Parser should diagnose the malformed method declaration.');
    lClassSymbol := NXPasFindSymbol(lSymbols, pskClass, 'TSample');
    AContext.AssertTrue(NXPasHasChildSymbol(lClassSymbol, pskField, 'FValue'),
      'Later fields should still parse after malformed method.');
    AContext.AssertTrue(NXPasHasChildSymbol(lClassSymbol, pskRoutine, 'Run'),
      'Later methods should still parse after malformed method.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestConditionalDirectiveMatching(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$IFDEF KNOWN}' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource, 'KNOWN');
    AContext.AssertFalse(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.directive.missingEndIf'),
      'Balanced IFDEF/ENDIF should not produce a mismatch diagnostic.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$IFDEF MISSING}' + LineEnding +
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertTrue(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.directive.missingEndIf'),
      'Missing ENDIF should produce a diagnostic.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$ELSE}' + LineEnding +
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertTrue(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.directive.elseWithoutIf'),
      'ELSE without IFDEF should produce a diagnostic.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestInactiveRegionCalculation(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$IFDEF UNKNOWN}' + LineEnding +
      'unit Hidden;' + LineEnding +
      '{$ELSE}' + LineEnding +
      'unit Sample;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertEquals(1, lTree.InactiveRegions.Count,
      'Undefined IFDEF branch should be marked inactive.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$IFDEF KNOWN}' + LineEnding +
      'unit Sample;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource, 'KNOWN');
    AContext.AssertEquals(0, lTree.InactiveRegions.Count,
      'Defined IFDEF branch should remain active.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$IFNDEF KNOWN}' + LineEnding +
      'unit Hidden;' + LineEnding +
      '{$ELSE}' + LineEnding +
      'unit Sample;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource, 'KNOWN');
    AContext.AssertEquals(1, lTree.InactiveRegions.Count,
      'IFNDEF should behave opposite of IFDEF.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestInactiveTopLevelDeclarationsAreFiltered(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type' + LineEnding +
      '  THidden = class end;' + LineEnding +
      'procedure Hidden;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'type' + LineEnding +
      '  TVisible = class end;' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskClass, 'THidden'),
      'Inactive type declarations should not produce active symbols.');
    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskRoutine, 'Hidden'),
      'Inactive routine declarations should not produce active symbols.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskClass, 'TVisible'),
      'Active declarations after an inactive region should still parse.');
    AContext.AssertEquals(1, lTree.InactiveRegions.Count,
      'Inactive-region metadata should still be preserved.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestConditionalActiveBranches(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$DEFINE OUTER}' + LineEnding +
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF OUTER}' + LineEnding +
      '  {$IFDEF INNER}' + LineEnding +
      'type THidden = class end;' + LineEnding +
      '  {$ELSE}' + LineEnding +
      'type TVisible = class end;' + LineEnding +
      '  {$ENDIF}' + LineEnding +
      '{$ENDIF}' + LineEnding +
      '{$IFNDEF OUTER}' + LineEnding +
      'type TAlsoHidden = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskClass, 'THidden'),
      'Undefined nested IFDEF branch should be inactive.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskClass, 'TVisible'),
      'Nested ELSE branch should become active.');
    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskClass, 'TAlsoHidden'),
      'IFNDEF should behave opposite of IFDEF.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestInactiveMalformedCodeDoesNotEmitSyntaxDiagnostic(
  AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type' + LineEnding +
      '  TBroken = class' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertFalse(NXPasHasDiagnostic(lDiagnostics,
      'nxpas.structuredType.missingEnd'),
      'Inactive malformed declarations should not emit active syntax diagnostics.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestConditionalUnitHeaderUsesActiveBranch(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      '{$IFDEF UNKNOWN}' + LineEnding +
      'unit Hidden;' + LineEnding +
      '{$ELSE}' + LineEnding +
      'unit Sample;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskUnit, 'Hidden'),
      'Inactive unit header should not be selected.');
    AContext.AssertTrue(NXPasHasSymbol(lSymbols, pskUnit, 'Sample'),
      'Parser should select the active unit header.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestWorkspaceIndex(AContext: TNXTestContext);
var
  lIndex: TNXPasWorkspaceIndex;
  lProject: TNXPasProject;
begin
  lProject := TNXPasProject.Create;
  lIndex := TNXPasWorkspaceIndex.Create;
  try
    lProject.Name := 'Sample';
    lProject.AddSourceFile('sample.pas', 'file:///sample.pas', cSimpleUnit);
    AContext.AssertEquals(1, lIndex.AddProject(lProject),
      'Workspace index should index one source file.');
    AContext.AssertEquals(1, lIndex.FileCount,
      'Workspace index should contain one indexed file.');
    AContext.AssertTrue(NXPasHasSymbol(lIndex.Files[0].Symbols, pskClass,
      'TSample'), 'Workspace index should expose extracted symbols.');
  finally
    lIndex.Free;
    lProject.Free;
  end;
end;

procedure TestLPIProjectReadsPathModel(AContext: TNXTestContext);
var
  lLPI: TNXPasLPIProject;
  lLPIFile: string;
  lRoot: string;
begin
  lRoot := NXPasCreateTempDir('nxplpi');
  lLPIFile := IncludeTrailingPathDelimiter(lRoot) + 'sample.lpi';
  NXPasWriteTextFile(lLPIFile,
    '<?xml version="1.0"?>' + LineEnding +
    '<CONFIG>' + LineEnding +
    '  <ProjectOptions>' + LineEnding +
    '    <General><Title Value="Sample"/></General>' + LineEnding +
    '    <Units Count="1"><Unit0><Filename Value="sample.lpr"/></Unit0></Units>' + LineEnding +
    '  </ProjectOptions>' + LineEnding +
    '  <CompilerOptions>' + LineEnding +
    '    <Target><Filename Value="bin/sample"/></Target>' + LineEnding +
    '    <SearchPaths>' + LineEnding +
    '      <OtherUnitFiles Value="src;lib"/>' + LineEnding +
    '      <IncludeFiles Value="include"/>' + LineEnding +
    '      <UnitOutputDirectory Value="units"/>' + LineEnding +
    '    </SearchPaths>' + LineEnding +
    '    <TargetCPU Value="x86_64"/>' + LineEnding +
    '    <TargetOS Value="win64"/>' + LineEnding +
    '  </CompilerOptions>' + LineEnding +
    '</CONFIG>');

  lLPI := TNXPasLPIProject.Create;
  try
    AContext.AssertTrue(lLPI.LoadFromFile(lLPIFile),
      'LPI project should load from XML.');
    AContext.AssertEquals('Sample', lLPI.Title,
      'LPI model should capture the project title.');
    AContext.AssertEquals(2, lLPI.UnitPaths.Count,
      'LPI model should capture semicolon-delimited unit paths.');
    AContext.AssertEquals(1, lLPI.IncludePaths.Count,
      'LPI model should capture include paths.');
    AContext.AssertEquals('x86_64', lLPI.TargetCPU,
      'LPI model should capture target CPU.');
    AContext.AssertEquals('win64', lLPI.TargetOS,
      'LPI model should capture target OS.');
  finally
    lLPI.Free;
    DeleteFile(lLPIFile);
    RemoveDir(lRoot);
  end;
end;

procedure TestSearchPathContextResolvesAndDeduplicates(AContext: TNXTestContext);
var
  lContext: TNXPasSearchPathContext;
  lRoot: string;
  lSrc: string;
begin
  lRoot := NXPasCreateTempDir('nxppath');
  lSrc := IncludeTrailingPathDelimiter(lRoot) + 'src';
  ForceDirectories(lSrc);

  lContext := TNXPasSearchPathContext.Create;
  try
    lContext.ProjectDir := lRoot;
    lContext.WorkspaceDir := lRoot;
    lContext.AddRawPath('src', 'test', pspkUnitPath, lRoot);
    lContext.AddRawPath('src', 'test duplicate', pspkUnitPath, lRoot);
    lContext.AddRawPath('missing', 'test missing', pspkUnitPath, lRoot);

    AContext.AssertEquals(1, lContext.UnitPaths.Count,
      'Resolved unit paths should be deduplicated.');
    AContext.AssertEquals(1, lContext.MissingPaths.Count,
      'Missing paths should be logged but ignored.');
  finally
    lContext.Free;
    RemoveDir(lSrc);
    RemoveDir(lRoot);
  end;
end;

procedure TestSearchPathTemplatesResolveConfiguredRoots(AContext: TNXTestContext);
var
  lContext: TNXPasSearchPathContext;
  lFPCDir: string;
  lLazarusDir: string;
  lRoot: string;
  lTemplates: TNXPasSearchPathTemplateList;
begin
  lRoot := NXPasCreateTempDir('nxproot');
  lLazarusDir := IncludeTrailingPathDelimiter(lRoot) + 'lazarus';
  lFPCDir := IncludeTrailingPathDelimiter(lRoot) + 'fpcsrc';
  ForceDirectories(IncludeTrailingPathDelimiter(lLazarusDir) + 'lcl');
  ForceDirectories(IncludeTrailingPathDelimiter(lFPCDir) + 'rtl');

  lContext := TNXPasSearchPathContext.Create;
  lTemplates := TNXPasSearchPathTemplateList.Create;
  try
    lContext.LazarusDir := lLazarusDir;
    lContext.FPCDir := lFPCDir;
    lTemplates.AddTemplate('Test Lazarus LCL', '$(LazarusDir)\lcl',
      pspkUnitPath);
    lTemplates.AddTemplate('Test FPC RTL', '$(FPCDir)\rtl', pspkUnitPath);
    lContext.AddTemplates(lTemplates);

    AContext.AssertEquals(2, lContext.UnitPaths.Count,
      'Configured Lazarus/FPC roots should resolve template paths.');
    AContext.AssertEquals(0, lContext.MissingPaths.Count,
      'Existing template paths should not be logged as missing.');
  finally
    lTemplates.Free;
    lContext.Free;
    RemoveDir(IncludeTrailingPathDelimiter(lFPCDir) + 'rtl');
    RemoveDir(lFPCDir);
    RemoveDir(IncludeTrailingPathDelimiter(lLazarusDir) + 'lcl');
    RemoveDir(lLazarusDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestSearchPathTemplateStoreCreatesMasterList(AContext: TNXTestContext);
var
  lFileName: string;
  lLoaded: TNXPasSearchPathTemplateList;
  lRoot: string;
  lTemplates: TNXPasSearchPathTemplateList;
begin
  lRoot := NXPasCreateTempDir('nxptpl');
  lFileName := IncludeTrailingPathDelimiter(lRoot) + 'nexuspas-search-paths.json';
  lTemplates := TNXPasSearchPathTemplateList.Create;
  lLoaded := TNXPasSearchPathTemplateList.Create;
  try
    TNXPasSearchPathTemplateStore.LoadOrCreate(lFileName, lTemplates);
    AContext.AssertTrue(FileExists(lFileName),
      'Template store should create a missing path template file.');
    AContext.AssertTrue(lTemplates.Count > 20,
      'Template store should seed the master Lazarus/FPC path list.');

    TNXPasSearchPathTemplateStore.LoadOrCreate(lFileName, lLoaded);
    AContext.AssertEquals(lTemplates.Count, lLoaded.Count,
      'Template store should load the same persisted template count.');
  finally
    lLoaded.Free;
    lTemplates.Free;
    DeleteFile(lFileName);
    RemoveDir(lRoot);
  end;
end;

procedure TestUnitLocatorFindsPasAndPP(AContext: TNXTestContext);
var
  lFileName: string;
  lPaths: TStringList;
  lRoot: string;
begin
  lRoot := NXPasCreateTempDir('nxpunit');
  NXPasWriteTextFile(IncludeTrailingPathDelimiter(lRoot) + 'Foo.pp',
    'unit Foo;' + LineEnding + 'interface' + LineEnding +
    'implementation' + LineEnding + 'end.');

  lPaths := TStringList.Create;
  try
    lPaths.Add(lRoot);
    AContext.AssertTrue(TNXPasUnitLocator.FindUnitFile('Foo', lPaths,
      lFileName), 'Unit locator should find .pp source files.');
    AContext.AssertTrue(SameText(ExtractFileName(lFileName), 'Foo.pp'),
      'Unit locator should return the matching source file.');
  finally
    lPaths.Free;
    DeleteFile(IncludeTrailingPathDelimiter(lRoot) + 'Foo.pp');
    RemoveDir(lRoot);
  end;
end;

procedure TestWorkspaceIndexResolvesUsesViaSearchPath(AContext: TNXTestContext);
var
  lIndex: TNXPasWorkspaceIndex;
  lLibDir: string;
  lRelationships: TNXPasUsesRelationshipList;
  lResolver: TNXPasSearchPathUnitResolver;
  lRoot: string;
  lSearchPaths: TNXPasSearchPathContext;
  lSource: TNXPasSourceFile;
begin
  lRoot := NXPasCreateTempDir('nxpuses');
  lLibDir := IncludeTrailingPathDelimiter(lRoot) + 'lib';
  ForceDirectories(lLibDir);
  NXPasWriteTextFile(IncludeTrailingPathDelimiter(lLibDir) + 'OtherUnit.pas',
    'unit OtherUnit;' + LineEnding +
    'interface' + LineEnding +
    'procedure Ping;' + LineEnding +
    'implementation' + LineEnding +
    'procedure Ping;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.');

  lIndex := TNXPasWorkspaceIndex.Create;
  lRelationships := TNXPasUsesRelationshipList.Create(True);
  lSearchPaths := TNXPasSearchPathContext.Create;
  lResolver := TNXPasSearchPathUnitResolver.Create(lSearchPaths);
  lSource := TNXPasSourceFile.Create(IncludeTrailingPathDelimiter(lRoot) +
    'MainUnit.pas', TNXPasUnitLocator.PathToFileURI(
    IncludeTrailingPathDelimiter(lRoot) + 'MainUnit.pas'),
    'unit MainUnit;' + LineEnding +
    'interface' + LineEnding +
    'uses OtherUnit;' + LineEnding +
    'implementation' + LineEnding +
    'end.');
  try
    lSearchPaths.AddRawPath(lLibDir, 'test', pspkUnitPath);
    lIndex.UnitResolver := lResolver;
    lIndex.UpdateSourceFile(lSource);
    lIndex.ListUsesRelationships(lRelationships);

    AContext.AssertEquals(1, lRelationships.Count,
      'Workspace index should resolve uses units through search paths.');
    AContext.AssertEquals(2, lIndex.FileCount,
      'Workspace index should index the discovered used unit.');
    AContext.AssertTrue(lIndex.FindFileByUnitName('OtherUnit') <> nil,
      'Discovered unit should be available by unit name.');
  finally
    lSource.Free;
    lResolver.Free;
    lSearchPaths.Free;
    lRelationships.Free;
    lIndex.Free;
    DeleteFile(IncludeTrailingPathDelimiter(lLibDir) + 'OtherUnit.pas');
    RemoveDir(lLibDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestUnitMetadataCapturesHeaderAndUses(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'uses SysUtils, Classes;' + LineEnding +
      'implementation' + LineEnding +
      'uses Math;' + LineEnding +
      'end.',
      lDiagnostics, lSource);

    AContext.AssertEquals('Sample', lTree.Metadata.Name,
      'Metadata should capture the unit name.');
    AContext.AssertEquals(Ord(pckUnit), Ord(lTree.Metadata.CompilationKind),
      'Metadata should capture the compilation kind.');
    AContext.AssertEquals(2, lTree.Metadata.InterfaceUses.Count,
      'Metadata should capture interface uses entries.');
    AContext.AssertEquals(1, lTree.Metadata.ImplementationUses.Count,
      'Metadata should capture implementation uses entries.');
    AContext.AssertEquals('SysUtils',
      lTree.Metadata.InterfaceUses.EntryAt(0).UnitName,
      'First interface uses entry should preserve the unit name.');
    AContext.AssertTrue(
      lTree.Metadata.InterfaceUses.EntryAt(0).Range.EndPos.Offset >
      lTree.Metadata.InterfaceUses.EntryAt(0).Range.StartPos.Offset,
      'Uses entry should have a source range.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestUsesInCapturesFilenameAndCandidatePath(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lEntry: TNXPasUsesEntry;
  lParser: TNXPasParser;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lSource := TNXPasSourceFile.Create('C:\workspace\sample.pas',
    'file:///C:/workspace/sample.pas',
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'uses Foo in ''foo.pas'';' + LineEnding +
    'implementation' + LineEnding +
    'end.');
  lParser := TNXPasParser.Create(lDiagnostics);
  lTree := nil;
  try
    lTree := lParser.Parse(lSource);
    AContext.AssertEquals(1, lTree.Metadata.InterfaceUses.Count,
      'Uses in clause should be captured as one entry.');
    lEntry := lTree.Metadata.InterfaceUses.EntryAt(0);
    AContext.AssertEquals('Foo', lEntry.UnitName,
      'Uses in clause should preserve unit name.');
    AContext.AssertEquals('foo.pas', lEntry.InFileName,
      'Uses in clause should preserve filename text.');
    AContext.AssertTrue(Pos('foo.pas', LowerCase(lEntry.CandidatePath)) > 0,
      'Uses in clause should produce a direct candidate path.');
  finally
    lTree.Free;
    lParser.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestInactiveUsesMetadataExcluded(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'uses HiddenUnit;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'uses VisibleUnit;' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertEquals(1, lTree.Metadata.InterfaceUses.Count,
      'Inactive uses entries should not be collected as active metadata.');
    AContext.AssertEquals('VisibleUnit',
      lTree.Metadata.InterfaceUses.EntryAt(0).UnitName,
      'Active uses entry after inactive region should still be captured.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestProjectGraphTracksKnownUnitsAndUses(AContext: TNXTestContext);
var
  lIndex: TNXPasWorkspaceIndex;
  lRelationships: TNXPasUsesRelationshipList;
  lSourceA: TNXPasSourceFile;
  lSourceB: TNXPasSourceFile;
  lUnits: TStringList;
begin
  lIndex := TNXPasWorkspaceIndex.Create;
  lRelationships := TNXPasUsesRelationshipList.Create(True);
  lSourceA := nil;
  lSourceB := nil;
  lUnits := TStringList.Create;
  try
    lSourceA := TNXPasSourceFile.Create('UnitA.pas',
      'file:///UnitA.pas',
      'unit UnitA;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'end.');
    lSourceB := TNXPasSourceFile.Create('UnitB.pas',
      'file:///UnitB.pas',
      'unit UnitB;' + LineEnding +
      'interface' + LineEnding +
      'uses UnitA;' + LineEnding +
      'implementation' + LineEnding +
      'end.');
    lIndex.UpdateSourceFile(lSourceA);
    lIndex.UpdateSourceFile(lSourceB);

    AContext.AssertTrue(lIndex.FindFileByUnitName('UnitA') <> nil,
      'Workspace graph should find known units by unit name.');
    lIndex.ListKnownUnits(lUnits);
    AContext.AssertEquals(2, lUnits.Count,
      'Workspace graph should list known indexed units.');
    lIndex.ListUsesRelationships(lRelationships);
    AContext.AssertEquals(1, lRelationships.Count,
      'Workspace graph should represent uses relationships among known files.');
    AContext.AssertEquals('UnitA',
      lRelationships.RelationshipAt(0).UsesEntry.UnitName,
      'Uses relationship should preserve the used unit name.');
  finally
    lUnits.Free;
    lSourceB.Free;
    lSourceA.Free;
    lRelationships.Free;
    lIndex.Free;
  end;
end;

procedure TestUnresolvedUsesReported(AContext: TNXTestContext);
var
  lIndex: TNXPasWorkspaceIndex;
  lSource: TNXPasSourceFile;
  lUnresolved: TNXPasUnresolvedUsesList;
begin
  lIndex := TNXPasWorkspaceIndex.Create;
  lSource := nil;
  lUnresolved := TNXPasUnresolvedUsesList.Create(True);
  try
    lSource := TNXPasSourceFile.Create('UnitB.pas',
      'file:///UnitB.pas',
      'unit UnitB;' + LineEnding +
      'interface' + LineEnding +
      'uses MissingUnit;' + LineEnding +
      'implementation' + LineEnding +
      'end.');
    lIndex.UpdateSourceFile(lSource);
    lIndex.ListUnresolvedUses(lUnresolved);
    AContext.AssertEquals(1, lUnresolved.Count,
      'Workspace graph should report uses entries whose units are not indexed.');
    AContext.AssertEquals('MissingUnit',
      lUnresolved.UnresolvedAt(0).UsesEntry.UnitName,
      'Unresolved uses entry should preserve the missing unit name.');
  finally
    lSource.Free;
    lUnresolved.Free;
    lIndex.Free;
  end;
end;

procedure TestNXDEPCollection(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$NXDEP sqlite3.dll}' + LineEnding +
      '{$NXDEP SDL2.dll}' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertEquals(2, lTree.Metadata.Dependencies.Count,
      'Parser should collect multiple NXDEP directives.');
    AContext.AssertEquals('sqlite3.dll',
      lTree.Metadata.Dependencies.DependencyAt(0).Value,
      'NXDEP should preserve dependency value.');
    AContext.AssertTrue(lTree.Metadata.Dependencies.DependencyAt(0).Active,
      'Active NXDEP should be marked active.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestNXDEPActiveBranch(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      '{$NXDEP hidden.dll}' + LineEnding +
      '{$ELSE}' + LineEnding +
      '{$NXDEP active.dll}' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    AContext.AssertEquals(2, lTree.Metadata.Dependencies.Count,
      'Parser should preserve NXDEP directives from conditional branches.');
    AContext.AssertFalse(lTree.Metadata.Dependencies.DependencyAt(0).Active,
      'Inactive NXDEP branch should not be active.');
    AContext.AssertTrue(lTree.Metadata.Dependencies.DependencyAt(1).Active,
      'Active NXDEP branch should be active.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestDependencyManifest(AContext: TNXTestContext);
var
  lIndex: TNXPasWorkspaceIndex;
  lManifest: TNXPasDependencyManifest;
  lSource: TNXPasSourceFile;
begin
  lIndex := TNXPasWorkspaceIndex.Create;
  lManifest := TNXPasDependencyManifest.Create(True);
  lSource := nil;
  try
    lSource := TNXPasSourceFile.Create('sqlite3.pas',
      'file:///sqlite3.pas',
      'unit sqlite3;' + LineEnding +
      'interface' + LineEnding +
      '{$NXDEP sqlite3.dll}' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      '{$NXDEP hidden.dll}' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.');
    lIndex.UpdateSourceFile(lSource);
    lIndex.BuildDependencyManifest(lManifest);
    AContext.AssertEquals(1, lManifest.Count,
      'Dependency manifest should include active dependencies only.');
    AContext.AssertEquals('sqlite3.dll', lManifest.EntryAt(0).Dependency,
      'Dependency manifest should preserve dependency value.');
    AContext.AssertEquals('sqlite3', lManifest.EntryAt(0).SourceName,
      'Dependency manifest should preserve declaring source unit.');
  finally
    lSource.Free;
    lManifest.Free;
    lIndex.Free;
  end;
end;

procedure TestDeclaredTypeReferences(AContext: TNXTestContext);
var
  lClassSymbol: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lFunctionSymbol: TNXPasSymbol;
  lParameterSymbol: TNXPasSymbol;
  lPropertySymbol: TNXPasSymbol;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
  lVarSymbol: TNXPasSymbol;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TSample = class' + LineEnding +
      '  private' + LineEnding +
      '    FValue: Integer;' + LineEnding +
      '  public' + LineEnding +
      '    property Name: string read FValue;' + LineEnding +
      '  end;' + LineEnding +
      'var Value: TSample;' + LineEnding +
      'procedure DoWork(AValue: Integer; const AName: string);' + LineEnding +
      'function GetValue: Integer;' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    lVarSymbol := NXPasFindSymbol(lSymbols, pskVariable, 'Value');
    AContext.AssertTrue(lVarSymbol <> nil, 'Variable symbol should exist.');
    AContext.AssertEquals('TSample', lVarSymbol.DeclaredTypeText,
      'Variable symbol should capture declared type.');

    lClassSymbol := NXPasFindSymbol(lSymbols, pskClass, 'TSample');
    AContext.AssertTrue(lClassSymbol <> nil, 'Class symbol should exist.');
    AContext.AssertEquals('Integer',
      NXPasFindChildSymbol(lClassSymbol, pskField, 'FValue').DeclaredTypeText,
      'Field symbol should capture declared type.');
    lPropertySymbol := NXPasFindChildSymbol(lClassSymbol, pskProperty, 'Name');
    AContext.AssertTrue(lPropertySymbol <> nil, 'Property symbol should exist.');
    AContext.AssertEquals('string', lPropertySymbol.DeclaredTypeText,
      'Property symbol should capture declared type.');

    lFunctionSymbol := NXPasFindSymbol(lSymbols, pskRoutine, 'GetValue');
    AContext.AssertTrue(lFunctionSymbol <> nil, 'Function symbol should exist.');
    AContext.AssertEquals('Integer', lFunctionSymbol.DeclaredTypeText,
      'Function symbol should capture return type.');

    lParameterSymbol := NXPasFindChildSymbol(
      NXPasFindSymbol(lSymbols, pskRoutine, 'DoWork'), pskParameter, 'AValue');
    AContext.AssertTrue(lParameterSymbol <> nil,
      'Parameter symbol should be nested under routine.');
    AContext.AssertEquals('Integer', lParameterSymbol.DeclaredTypeText,
      'Parameter symbol should capture declared type.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestDeclaredTypeParsingHardened(AContext: TNXTestContext);
var
  lClassSymbol: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lFunctionSymbol: TNXPasSymbol;
  lParamSymbol: TNXPasSymbol;
  lPropertySymbol: TNXPasSymbol;
  lRoutineSymbol: TNXPasSymbol;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TBar = class end;' + LineEnding +
      '  TFoo<T> = class end;' + LineEnding +
      '  TSample = class' + LineEnding +
      '  private' + LineEnding +
      '    FOne, FTwo: TFoo<TBar>;' + LineEnding +
      '  public' + LineEnding +
      '    property Items[Index: Integer]: TFoo<TBar> read FOne write FTwo;' +
      LineEnding +
      '  end;' + LineEnding +
      'var First, Second: TFoo<TBar>;' + LineEnding +
      'procedure DoWork(AFirst, ASecond: TFoo<TBar>);' + LineEnding +
      'function Build: TFoo<TBar>;' + LineEnding +
      'implementation' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertEquals('TFoo<TBar>',
      NXPasFindSymbol(lSymbols, pskVariable, 'First').DeclaredTypeText,
      'First variable in a shared declaration should capture the type.');
    AContext.AssertEquals('TFoo<TBar>',
      NXPasFindSymbol(lSymbols, pskVariable, 'Second').DeclaredTypeText,
      'Second variable in a shared declaration should capture the type.');

    lClassSymbol := NXPasFindSymbol(lSymbols, pskClass, 'TSample');
    AContext.AssertEquals('TFoo<TBar>',
      NXPasFindChildSymbol(lClassSymbol, pskField, 'FOne').DeclaredTypeText,
      'First field in a shared declaration should capture the type.');
    AContext.AssertEquals('TFoo<TBar>',
      NXPasFindChildSymbol(lClassSymbol, pskField, 'FTwo').DeclaredTypeText,
      'Second field in a shared declaration should capture the type.');

    lPropertySymbol := NXPasFindChildSymbol(lClassSymbol, pskProperty, 'Items');
    AContext.AssertEquals('TFoo<TBar>', lPropertySymbol.DeclaredTypeText,
      'Property type should stop before read/write modifiers.');

    lRoutineSymbol := NXPasFindSymbol(lSymbols, pskRoutine, 'DoWork');
    lParamSymbol := NXPasFindChildSymbol(lRoutineSymbol, pskParameter, 'AFirst');
    AContext.AssertEquals('TFoo<TBar>', lParamSymbol.DeclaredTypeText,
      'First parameter in a shared declaration should capture the type.');
    lParamSymbol := NXPasFindChildSymbol(lRoutineSymbol, pskParameter,
      'ASecond');
    AContext.AssertEquals('TFoo<TBar>', lParamSymbol.DeclaredTypeText,
      'Second parameter in a shared declaration should capture the type.');

    lFunctionSymbol := NXPasFindSymbol(lSymbols, pskRoutine, 'Build');
    AContext.AssertEquals('TFoo<TBar>', lFunctionSymbol.DeclaredTypeText,
      'Function return type should preserve generic-looking text.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestLocalVariableSymbols(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lLocalSymbol: TNXPasSymbol;
  lRoutineSymbol: TNXPasSymbol;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPasParseText(
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type TSample = class end;' + LineEnding +
      'implementation' + LineEnding +
      'procedure Test;' + LineEnding +
      'var' + LineEnding +
      '  Local: TSample;' + LineEnding +
      'begin' + LineEnding +
      'end;' + LineEnding +
      'end.',
      lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    lRoutineSymbol := NXPasFindSymbol(lSymbols, pskRoutine, 'Test');
    AContext.AssertTrue(lRoutineSymbol <> nil, 'Routine symbol should exist.');
    lLocalSymbol := NXPasFindChildSymbol(lRoutineSymbol, pskVariable, 'Local');
    AContext.AssertTrue(lLocalSymbol <> nil,
      'Local variable should be owned by the routine symbol.');
    AContext.AssertEquals('TSample', lLocalSymbol.DeclaredTypeText,
      'Local variable should capture declared type.');
    AContext.AssertFalse(NXPasHasSymbol(lSymbols, pskVariable, 'Local'),
      'Local variable should not appear as a top-level symbol.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure RegisterNXPasParserTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusPas.Parser');
  lSuite.AddTest('SourceRangeCreation', @TestSourceRangeCreation);
  lSuite.AddTest('DiagnosticsCreation', @TestDiagnosticsCreation);
  lSuite.AddTest('ShallowParseSimpleUnit', @TestShallowParseSimpleUnit);
  lSuite.AddTest('SymbolExtraction', @TestSymbolExtraction);
  lSuite.AddTest('UsesUnitsAreNotTypeSymbols',
    @TestUsesUnitsAreNotTypeSymbols);
  lSuite.AddTest('StructuredClassBodySymbols',
    @TestStructuredClassBodySymbols);
  lSuite.AddTest('ForwardClassDeclarationAllowsLaterMembers',
    @TestForwardClassDeclarationAllowsLaterMembers);
  lSuite.AddTest('ClassRoutineRangeIncludesClassPrefix',
    @TestClassRoutineRangeIncludesClassPrefix);
  lSuite.AddTest('ProcedureTypesUseBalancedDeclarationSkipping',
    @TestProcedureTypesUseBalancedDeclarationSkipping);
  lSuite.AddTest('StructuredRecordBodySymbols',
    @TestStructuredRecordBodySymbols);
  lSuite.AddTest('StructuredInterfaceBodySymbols',
    @TestStructuredInterfaceBodySymbols);
  lSuite.AddTest('MissingUnitHeaderSemicolonDiagnostic',
    @TestMissingUnitHeaderSemicolonDiagnostic);
  lSuite.AddTest('MalformedUsesClauseDiagnostic',
    @TestMalformedUsesClauseDiagnostic);
  lSuite.AddTest('MissingClassEndRecoversSymbols',
    @TestMissingClassEndRecoversSymbols);
  lSuite.AddTest('MalformedClassMethodAllowsLaterMembers',
    @TestMalformedClassMethodAllowsLaterMembers);
  lSuite.AddTest('ConditionalDirectiveMatching',
    @TestConditionalDirectiveMatching);
  lSuite.AddTest('InactiveRegionCalculation',
    @TestInactiveRegionCalculation);
  lSuite.AddTest('InactiveTopLevelDeclarationsAreFiltered',
    @TestInactiveTopLevelDeclarationsAreFiltered);
  lSuite.AddTest('ConditionalActiveBranches',
    @TestConditionalActiveBranches);
  lSuite.AddTest('InactiveMalformedCodeDoesNotEmitSyntaxDiagnostic',
    @TestInactiveMalformedCodeDoesNotEmitSyntaxDiagnostic);
  lSuite.AddTest('ConditionalUnitHeaderUsesActiveBranch',
    @TestConditionalUnitHeaderUsesActiveBranch);
  lSuite.AddTest('WorkspaceIndex', @TestWorkspaceIndex);
  lSuite.AddTest('LPIProjectReadsPathModel',
    @TestLPIProjectReadsPathModel);
  lSuite.AddTest('SearchPathContextResolvesAndDeduplicates',
    @TestSearchPathContextResolvesAndDeduplicates);
  lSuite.AddTest('SearchPathTemplatesResolveConfiguredRoots',
    @TestSearchPathTemplatesResolveConfiguredRoots);
  lSuite.AddTest('SearchPathTemplateStoreCreatesMasterList',
    @TestSearchPathTemplateStoreCreatesMasterList);
  lSuite.AddTest('UnitLocatorFindsPasAndPP', @TestUnitLocatorFindsPasAndPP);
  lSuite.AddTest('WorkspaceIndexResolvesUsesViaSearchPath',
    @TestWorkspaceIndexResolvesUsesViaSearchPath);
  lSuite.AddTest('UnitMetadataCapturesHeaderAndUses',
    @TestUnitMetadataCapturesHeaderAndUses);
  lSuite.AddTest('UsesInCapturesFilenameAndCandidatePath',
    @TestUsesInCapturesFilenameAndCandidatePath);
  lSuite.AddTest('InactiveUsesMetadataExcluded',
    @TestInactiveUsesMetadataExcluded);
  lSuite.AddTest('ProjectGraphTracksKnownUnitsAndUses',
    @TestProjectGraphTracksKnownUnitsAndUses);
  lSuite.AddTest('UnresolvedUsesReported', @TestUnresolvedUsesReported);
  lSuite.AddTest('NXDEPCollection', @TestNXDEPCollection);
  lSuite.AddTest('NXDEPActiveBranch', @TestNXDEPActiveBranch);
  lSuite.AddTest('DependencyManifest', @TestDependencyManifest);
  lSuite.AddTest('DeclaredTypeReferences', @TestDeclaredTypeReferences);
  lSuite.AddTest('DeclaredTypeParsingHardened',
    @TestDeclaredTypeParsingHardened);
  lSuite.AddTest('LocalVariableSymbols', @TestLocalVariableSymbols);
end;

end.
