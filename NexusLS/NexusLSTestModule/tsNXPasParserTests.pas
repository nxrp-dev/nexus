unit tsNXPasParserTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasParserTests(ARegistry: TNXTestRegistry);

implementation

uses
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasParser,
  obNXPasProject,
  obNXPasSource,
  obNXPasSymbols,
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
end;

end.
