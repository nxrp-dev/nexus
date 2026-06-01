unit tsNXPasPassrcPortTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasPassrcPortTests(ARegistry: TNXTestRegistry);

implementation

uses
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasLexer,
  obNXPasMetadata,
  obNXPasParser,
  obNXPasSource,
  obNXPasSymbols,
  obNXPasWorkspaceIndex,
  obNXTestContext,
  obNXTestSuite,
  tpNXPasTokens;

function NXPassrcNextNonWhitespace(ALexer: TNXPasLexer): TNXPasToken;
begin
  repeat
    Result := ALexer.NextToken;
  until Result.Kind <> ptkWhitespace;
end;

function NXPassrcParse(const AText: string;
  ADiagnostics: TNXPasDiagnosticList; out ASource: TNXPasSourceFile):
  TNXPasSyntaxTree;
var
  lParser: TNXPasParser;
begin
  ASource := TNXPasSourceFile.Create('sample.pas', 'file:///sample.pas',
    AText);
  lParser := TNXPasParser.Create(ADiagnostics);
  try
    Result := lParser.Parse(ASource);
  finally
    lParser.Free;
  end;
end;

function NXPassrcFindNode(ANode: TNXPasASTNode; AKind: TNXPasNodeKind;
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
    Result := NXPassrcFindNode(ANode.Children[lIdx], AKind, AName);
    if Result <> nil then
      Exit;
  end;
end;

function NXPassrcFindSymbol(ASymbols: TNXPasSymbolTable;
  AKind: TNXPasSymbolKind; const AName: string): TNXPasSymbol;
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

function NXPassrcFindChildSymbol(ASymbol: TNXPasSymbol;
  AKind: TNXPasSymbolKind; const AName: string): TNXPasSymbol;
var
  lIdx: Integer;
  lSymbol: TNXPasSymbol;
begin
  Result := nil;
  if ASymbol = nil then
    Exit;

  for lIdx := 0 to ASymbol.ChildCount - 1 do
  begin
    lSymbol := ASymbol.Children[lIdx];
    if (lSymbol.Kind = AKind) and (lSymbol.Name = AName) then
      Exit(lSymbol);
  end;
end;

function NXPassrcHasDiagnostic(ADiagnostics: TNXPasDiagnosticList;
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

procedure TestScannerEmptyInputEOF(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('');
  try
    lToken := lLexer.NextToken;
    AContext.AssertEquals(Ord(ptkEndOfFile), Ord(lToken.Kind),
      'Empty input should produce EOF.');
    AContext.AssertEquals(0, lToken.StartPos.Line,
      'EOF position should start on line zero for empty input.');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerLineEndingPositions(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('unit' + #13#10 + 'Sample;');
  try
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('unit', lToken.Text,
      'First token should be unit.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('Sample', lToken.Text,
      'Identifier after CRLF should be preserved.');
    AContext.AssertEquals(1, lToken.StartPos.Line,
      'CRLF should advance to the next line.');
    AContext.AssertEquals(0, lToken.StartPos.Column,
      'First token after CRLF should start at column zero.');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerCommentsStringsAndDirectives(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('{$NXDEP sqlite3.dll} // comment' +
    LineEnding + '''abc''''def''');
  try
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkDirective), Ord(lToken.Kind),
      'Compiler directives should be directive tokens.');
    AContext.AssertEquals('{$NXDEP sqlite3.dll}', lToken.Text,
      'Directive text should be preserved.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkComment), Ord(lToken.Kind),
      'Line comments should be comment tokens.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkString), Ord(lToken.Kind),
      'Quoted strings should be string tokens.');
    AContext.AssertEquals('''abc''''def''', lToken.Text,
      'Doubled quotes should remain in token text.');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerNumbersAndCompoundSymbols(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('$2A..100 := <> <= >=');
  try
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkNumber), Ord(lToken.Kind),
      'Hex literal should be a number token.');
    AContext.AssertEquals('$2A', lToken.Text,
      'Hex literal text should be preserved.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('..', lToken.Text,
      'Range operator should be one token.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('100', lToken.Text,
      'Decimal literal text should be preserved.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(':=', lToken.Text,
      'Assignment operator should be one token.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('<>', lToken.Text,
      'Not-equal operator should be one token.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('<=', lToken.Text,
      'Less-equal operator should be one token.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('>=', lToken.Text,
      'Greater-equal operator should be one token.');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerKeywordTokens(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create(
    'absolute array class function object package record uses');
  try
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'absolute should lex as a keyword.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'array should lex as a keyword.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'class should lex as a keyword.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'function should lex as a keyword.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'object should lex as a keyword.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'package should lex as a keyword.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'record should lex as a keyword.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'uses should lex as a keyword.');
  finally
    lLexer.Free;
  end;
end;

procedure TestModuleUnitProgramLibraryPackageHeaders(
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
    lTree := NXPassrcParse('package Sample;' + LineEnding +
      'interface' + LineEnding + 'implementation' + LineEnding + 'end.',
      lDiagnostics, lSource);
    AContext.AssertEquals('Sample', lTree.Metadata.Name,
      'Package header should produce metadata name.');
    AContext.AssertEquals(Ord(pckPackage), Ord(lTree.Metadata.CompilationKind),
      'Package header should produce package metadata kind.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestModuleProgramHeaderMetadata(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('program Sample;' + LineEnding +
      'begin' + LineEnding + 'end.', lDiagnostics, lSource);
    AContext.AssertEquals('Sample', lTree.Metadata.Name,
      'Program header should produce metadata name.');
    AContext.AssertEquals(Ord(pckProgram), Ord(lTree.Metadata.CompilationKind),
      'Program header should produce program metadata kind.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestModuleLibraryHeaderMetadata(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('library Sample;' + LineEnding +
      'begin' + LineEnding + 'end.', lDiagnostics, lSource);
    AContext.AssertEquals('Sample', lTree.Metadata.Name,
      'Library header should produce metadata name.');
    AContext.AssertEquals(Ord(pckLibrary), Ord(lTree.Metadata.CompilationKind),
      'Library header should produce library metadata kind.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestModuleUsesInClauseMetadata(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lEntry: TNXPasUsesEntry;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'uses SysUtils, Foo in ''foo.pas'';' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    AContext.AssertEquals(2, lTree.Metadata.InterfaceUses.Count,
      'Uses clause should capture both entries.');
    lEntry := lTree.Metadata.InterfaceUses.EntryAt(1);
    AContext.AssertEquals('Foo', lEntry.UnitName,
      'Uses-in entry should capture unit name.');
    AContext.AssertEquals('foo.pas', lEntry.InFileName,
      'Uses-in entry should capture filename text.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestModuleImplementationUsesMetadata(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'uses SysUtils;' + LineEnding +
      'implementation' + LineEnding +
      'uses Classes, Math;' + LineEnding +
      'end.', lDiagnostics, lSource);
    AContext.AssertEquals(1, lTree.Metadata.InterfaceUses.Count,
      'Interface uses should be captured separately.');
    AContext.AssertEquals(2, lTree.Metadata.ImplementationUses.Count,
      'Implementation uses should be captured separately.');
    AContext.AssertEquals('Classes',
      lTree.Metadata.ImplementationUses.EntryAt(0).UnitName,
      'Implementation uses unit name should be preserved.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestTypeClassRecordInterfaceSymbols(AContext: TNXTestContext);
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TSample = class end;' + LineEnding +
      '  TPoint = record X: Integer; end;' + LineEnding +
      '  ISample = interface procedure Run; end;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskClass, 'TSample') <> nil,
      'Class declaration should become a class symbol.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRecord, 'TPoint') <> nil,
      'Record declaration should become a record symbol.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskInterface,
      'ISample') <> nil, 'Interface declaration should become an interface symbol.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestClassMembersAndPropertySymbols(AContext: TNXTestContext);
var
  lClass: TNXPasSymbol;
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TSample = class' + LineEnding +
      '  private' + LineEnding +
      '    FValue: Integer;' + LineEnding +
      '  public' + LineEnding +
      '    procedure Run(AValue: Integer);' + LineEnding +
      '    property Value: Integer read FValue;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lClass := NXPassrcFindSymbol(lSymbols, pskClass, 'TSample');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskField,
      'FValue') <> nil, 'Class field should be nested under class.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskRoutine,
      'Run') <> nil, 'Class method should be nested under class.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskProperty,
      'Value') <> nil, 'Class property should be nested under class.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestObjectRecordInterfaceMemberSymbols(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lInterface: TNXPasSymbol;
  lObject: TNXPasSymbol;
  lRecord: TNXPasSymbol;
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TObj = object' + LineEnding +
      '    procedure Run;' + LineEnding +
      '  end;' + LineEnding +
      '  TRec = record' + LineEnding +
      '    X, Y: Integer;' + LineEnding +
      '  end;' + LineEnding +
      '  IRun = interface' + LineEnding +
      '    procedure Execute;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lObject := NXPassrcFindSymbol(lSymbols, pskObject, 'TObj');
    lRecord := NXPassrcFindSymbol(lSymbols, pskRecord, 'TRec');
    lInterface := NXPassrcFindSymbol(lSymbols, pskInterface, 'IRun');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lObject, pskRoutine,
      'Run') <> nil, 'Object method should be nested under object.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lRecord, pskField,
      'Y') <> nil, 'Record field should be nested under record.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lInterface, pskRoutine,
      'Execute') <> nil, 'Interface method should be nested under interface.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestProcedureFunctionDeclarations(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lFunction: TNXPasSymbol;
  lProcedure: TNXPasSymbol;
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'procedure DoWork(AValue: Integer; const AName: string);' + LineEnding +
      'function Build: Integer;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoWork');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'Build');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lProcedure, pskParameter,
      'AValue') <> nil, 'Procedure parameters should be captured.');
    AContext.AssertEquals('Integer', lFunction.DeclaredTypeText,
      'Function return type should be captured.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestProcedureParameterModes(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lProcedure: TNXPasSymbol;
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'procedure DoWork(var A: Integer; const B: string; out C: TObject);' +
      LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoWork');
    AContext.AssertEquals('Integer',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'A').DeclaredTypeText,
      'var parameter type should be captured.');
    AContext.AssertEquals('string',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'B').DeclaredTypeText,
      'const parameter type should be captured.');
    AContext.AssertEquals('TObject',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'C').DeclaredTypeText,
      'out parameter type should be captured.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestLocalRoutineVarAndConstDeclarations(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lRoutine: TNXPasSymbol;
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'procedure DoWork;' + LineEnding +
      'const LocalConst = 1;' + LineEnding +
      'var LocalVar: Integer;' + LineEnding +
      'begin' + LineEnding +
      'end;' + LineEnding +
      'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lRoutine := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoWork');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lRoutine, pskConst,
      'LocalConst') <> nil, 'Local const should be nested under routine.');
    AContext.AssertEquals('Integer',
      NXPassrcFindChildSymbol(lRoutine, pskVariable,
      'LocalVar').DeclaredTypeText,
      'Local variable type should be captured under routine.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestConstAndVarDeclarations(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lSource: TNXPasSourceFile;
  lSymbols: TNXPasSymbolTable;
  lTree: TNXPasSyntaxTree;
  lVariable: TNXPasSymbol;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'const MaxCount = 10;' + LineEnding +
      'var First, Second: Integer;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'MaxCount') <> nil, 'Const declaration should be captured.');
    lVariable := NXPassrcFindSymbol(lSymbols, pskVariable, 'Second');
    AContext.AssertTrue(lVariable <> nil,
      'Second variable in shared declaration should be captured.');
    AContext.AssertEquals('Integer', lVariable.DeclaredTypeText,
      'Variable declared type should be captured.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestGenericDeclaredTypeText(AContext: TNXTestContext);
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'var Items: TFoo<TBar>;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertEquals('TFoo<TBar>',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'Items').DeclaredTypeText,
      'Generic-looking declared type text should be preserved.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestProcedureTypeDeclarations(AContext: TNXTestContext);
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  THandler = procedure(A: Integer; const B: string);' + LineEnding +
      '  TFactory = function: TObject;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskType,
      'THandler') <> nil, 'Procedure type should be a type symbol.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskType,
      'TFactory') <> nil, 'Function type should be a type symbol.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestDiagnosticsRecoveryForMalformedUses(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lSource: TNXPasSourceFile;
  lTree: TNXPasSyntaxTree;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'uses SysUtils' + LineEnding +
      'type TSample = class end;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    AContext.AssertTrue(NXPassrcHasDiagnostic(lDiagnostics,
      'nxpas.uses.missingSemicolon'),
      'Malformed uses clause should produce a NexusPas diagnostic.');
    AContext.AssertTrue(NXPassrcFindNode(lTree.Root, pnkClassDecl,
      'TSample') <> nil, 'Parser should recover and keep later symbols.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestDiagnosticsMissingClassEndRecovery(AContext: TNXTestContext);
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TGood = class end;' + LineEnding +
      '  TBroken = class' + LineEnding +
      'implementation' + LineEnding +
      'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertTrue(NXPassrcHasDiagnostic(lDiagnostics,
      'nxpas.structuredType.missingEnd'),
      'Missing structured type end should produce a NexusPas diagnostic.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskClass,
      'TGood') <> nil, 'Parser should preserve earlier class symbols.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestInactiveRegionBehavior(AContext: TNXTestContext);
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
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type THidden = class end;' + LineEnding +
      '{$ELSE}' + LineEnding +
      'type TVisible = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertEquals(1, lTree.InactiveRegions.Count,
      'Inactive branch should produce inactive-region metadata.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskClass,
      'TVisible') <> nil, 'Active branch symbol should be present.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskClass,
      'THidden') = nil, 'Inactive branch symbol should be excluded.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestProjectGraphKnownUses(AContext: TNXTestContext);
var
  lIndex: TNXPasWorkspaceIndex;
  lRelationships: TNXPasUsesRelationshipList;
  lSourceA: TNXPasSourceFile;
  lSourceB: TNXPasSourceFile;
begin
  lIndex := TNXPasWorkspaceIndex.Create;
  lRelationships := TNXPasUsesRelationshipList.Create(True);
  lSourceA := TNXPasSourceFile.Create('UnitA.pas', 'file:///UnitA.pas',
    'unit UnitA;' + LineEnding + 'interface' + LineEnding +
    'implementation' + LineEnding + 'end.');
  lSourceB := TNXPasSourceFile.Create('UnitB.pas', 'file:///UnitB.pas',
    'unit UnitB;' + LineEnding + 'interface' + LineEnding +
    'uses UnitA;' + LineEnding + 'implementation' + LineEnding + 'end.');
  try
    lIndex.UpdateSourceFile(lSourceA);
    lIndex.UpdateSourceFile(lSourceB);
    lIndex.ListUsesRelationships(lRelationships);
    AContext.AssertEquals(1, lRelationships.Count,
      'Known indexed uses relation should be represented.');
    AContext.AssertEquals('UnitA',
      lRelationships.RelationshipAt(0).UsesEntry.UnitName,
      'Uses relation should preserve target unit name.');
  finally
    lSourceB.Free;
    lSourceA.Free;
    lRelationships.Free;
    lIndex.Free;
  end;
end;

procedure RegisterNXPasPassrcPortTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusPas.PassrcPort');
  lSuite.AddTest('ScannerEmptyInputEOF', @TestScannerEmptyInputEOF);
  lSuite.AddTest('ScannerLineEndingPositions', @TestScannerLineEndingPositions);
  lSuite.AddTest('ScannerCommentsStringsAndDirectives',
    @TestScannerCommentsStringsAndDirectives);
  lSuite.AddTest('ScannerNumbersAndCompoundSymbols',
    @TestScannerNumbersAndCompoundSymbols);
  lSuite.AddTest('ScannerKeywordTokens', @TestScannerKeywordTokens);
  lSuite.AddTest('ModuleUnitProgramLibraryPackageHeaders',
    @TestModuleUnitProgramLibraryPackageHeaders);
  lSuite.AddTest('ModuleProgramHeaderMetadata',
    @TestModuleProgramHeaderMetadata);
  lSuite.AddTest('ModuleLibraryHeaderMetadata',
    @TestModuleLibraryHeaderMetadata);
  lSuite.AddTest('ModuleUsesInClauseMetadata', @TestModuleUsesInClauseMetadata);
  lSuite.AddTest('ModuleImplementationUsesMetadata',
    @TestModuleImplementationUsesMetadata);
  lSuite.AddTest('TypeClassRecordInterfaceSymbols',
    @TestTypeClassRecordInterfaceSymbols);
  lSuite.AddTest('ClassMembersAndPropertySymbols',
    @TestClassMembersAndPropertySymbols);
  lSuite.AddTest('ObjectRecordInterfaceMemberSymbols',
    @TestObjectRecordInterfaceMemberSymbols);
  lSuite.AddTest('ProcedureFunctionDeclarations',
    @TestProcedureFunctionDeclarations);
  lSuite.AddTest('ProcedureParameterModes', @TestProcedureParameterModes);
  lSuite.AddTest('LocalRoutineVarAndConstDeclarations',
    @TestLocalRoutineVarAndConstDeclarations);
  lSuite.AddTest('ConstAndVarDeclarations', @TestConstAndVarDeclarations);
  lSuite.AddTest('GenericDeclaredTypeText', @TestGenericDeclaredTypeText);
  lSuite.AddTest('ProcedureTypeDeclarations',
    @TestProcedureTypeDeclarations);
  lSuite.AddTest('DiagnosticsRecoveryForMalformedUses',
    @TestDiagnosticsRecoveryForMalformedUses);
  lSuite.AddTest('DiagnosticsMissingClassEndRecovery',
    @TestDiagnosticsMissingClassEndRecovery);
  lSuite.AddTest('InactiveRegionBehavior', @TestInactiveRegionBehavior);
  lSuite.AddTest('ProjectGraphKnownUses', @TestProjectGraphKnownUses);
end;

end.
