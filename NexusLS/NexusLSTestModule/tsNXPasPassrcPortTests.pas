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

procedure NXPassrcAssertToken(AContext: TNXTestContext; ALexer: TNXPasLexer;
  AKind: TNXPasTokenKind; const AText, AMessage: string);
var
  lToken: TNXPasToken;
begin
  lToken := NXPassrcNextNonWhitespace(ALexer);
  AContext.AssertEquals(Ord(AKind), Ord(lToken.Kind), AMessage + ' kind');
  AContext.AssertEquals(AText, lToken.Text, AMessage + ' text');
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

procedure TestScannerLineWhitespaceVariants(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('One' + #13 + 'Two' + #10 + 'Three' +
    #10#13 + 'Four'#9'Five');
  try
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('One', lToken.Text, 'First line token should be kept.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('Two', lToken.Text, 'CR line ending should be handled.');
    AContext.AssertEquals(1, lToken.StartPos.Line,
      'CR should advance one line.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('Three', lToken.Text, 'LF line ending should be handled.');
    AContext.AssertEquals(2, lToken.StartPos.Line,
      'LF should advance one line.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('Four', lToken.Text, 'LFCR line ending should be handled.');
    AContext.AssertEquals(4, lToken.StartPos.Line,
      'LFCR is treated as two line endings by the Nexus lexer.');
    lToken := lLexer.NextToken;
    AContext.AssertEquals(Ord(ptkWhitespace), Ord(lToken.Kind),
      'Tab should produce whitespace token.');
    AContext.AssertEquals(#9, lToken.Text,
      'Tab whitespace text should be preserved.');
    lToken := NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertEquals('Five', lToken.Text,
      'Token after tab whitespace should be preserved.');
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

procedure TestScannerCommentForms(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
begin
  lLexer := TNXPasLexer.Create('{brace} (* paren-star *) // slash');
  try
    NXPassrcAssertToken(AContext, lLexer, ptkComment, '{brace}',
      'Brace comment');
    NXPassrcAssertToken(AContext, lLexer, ptkComment, '(* paren-star *)',
      'Paren-star comment');
    NXPassrcAssertToken(AContext, lLexer, ptkComment, '// slash',
      'Slash comment');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerIdentifierSelfAndCharFragments(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
begin
  lLexer := TNXPasLexer.Create('Alpha Self #65 ''A''');
  try
    NXPassrcAssertToken(AContext, lLexer, ptkIdentifier, 'Alpha',
      'Identifier');
    NXPassrcAssertToken(AContext, lLexer, ptkIdentifier, 'Self',
      'Self pseudo-variable');
    NXPassrcAssertToken(AContext, lLexer, ptkSymbol, '#',
      'Character ordinal marker');
    NXPassrcAssertToken(AContext, lLexer, ptkNumber, '65',
      'Character ordinal value');
    NXPassrcAssertToken(AContext, lLexer, ptkString, '''A''',
      'String part after character ordinal');
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

procedure TestScannerSingleSymbolTokens(AContext: TNXTestContext);
var
  lIdx: Integer;
  lLexer: TNXPasLexer;
  lSymbols: array[0..15] of string;
begin
  lSymbols[0] := '*';
  lSymbols[1] := '+';
  lSymbols[2] := ',';
  lSymbols[3] := '-';
  lSymbols[4] := '.';
  lSymbols[5] := '/';
  lSymbols[6] := ':';
  lSymbols[7] := ';';
  lSymbols[8] := '<';
  lSymbols[9] := '=';
  lSymbols[10] := '>';
  lSymbols[11] := '@';
  lSymbols[12] := '[';
  lSymbols[13] := ']';
  lSymbols[14] := '^';
  lSymbols[15] := '\';

  lLexer := TNXPasLexer.Create('* + , - . / : ; < = > @ [ ] ^ \');
  try
    for lIdx := Low(lSymbols) to High(lSymbols) do
      NXPassrcAssertToken(AContext, lLexer, ptkSymbol, lSymbols[lIdx],
        'Single symbol ' + lSymbols[lIdx]);
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerAssignmentCompoundSymbols(AContext: TNXTestContext);
var
  lIdx: Integer;
  lLexer: TNXPasLexer;
  lSymbols: array[0..5] of string;
begin
  lSymbols[0] := '+=';
  lSymbols[1] := '-=';
  lSymbols[2] := '*=';
  lSymbols[3] := '/=';
  lSymbols[4] := '**';
  lSymbols[5] := '><';

  lLexer := TNXPasLexer.Create('+= -= *= /= ** ><');
  try
    for lIdx := Low(lSymbols) to High(lSymbols) do
      NXPassrcAssertToken(AContext, lLexer, ptkSymbol, lSymbols[lIdx],
        'Compound symbol ' + lSymbols[lIdx]);
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerKeywordTokens(AContext: TNXTestContext);
var
  lIdx: Integer;
  lLexer: TNXPasLexer;
  lKeywords: array[0..52] of string;
begin
  lKeywords[0] := 'and';
  lKeywords[1] := 'as';
  lKeywords[2] := 'asm';
  lKeywords[3] := 'begin';
  lKeywords[4] := 'case';
  lKeywords[5] := 'const';
  lKeywords[6] := 'constructor';
  lKeywords[7] := 'destructor';
  lKeywords[8] := 'div';
  lKeywords[9] := 'do';
  lKeywords[10] := 'downto';
  lKeywords[11] := 'else';
  lKeywords[12] := 'end';
  lKeywords[13] := 'finalization';
  lKeywords[14] := 'for';
  lKeywords[15] := 'generic';
  lKeywords[16] := 'if';
  lKeywords[17] := 'implementation';
  lKeywords[18] := 'in';
  lKeywords[19] := 'inherited';
  lKeywords[20] := 'initialization';
  lKeywords[21] := 'inline';
  lKeywords[22] := 'interface';
  lKeywords[23] := 'library';
  lKeywords[24] := 'nil';
  lKeywords[25] := 'not';
  lKeywords[26] := 'of';
  lKeywords[27] := 'operator';
  lKeywords[28] := 'or';
  lKeywords[29] := 'packed';
  lKeywords[30] := 'procedure';
  lKeywords[31] := 'program';
  lKeywords[32] := 'property';
  lKeywords[33] := 'record';
  lKeywords[34] := 'repeat';
  lKeywords[35] := 'resourcestring';
  lKeywords[36] := 'set';
  lKeywords[37] := 'then';
  lKeywords[38] := 'to';
  lKeywords[39] := 'try';
  lKeywords[40] := 'type';
  lKeywords[41] := 'unit';
  lKeywords[42] := 'until';
  lKeywords[43] := 'uses';
  lKeywords[44] := 'var';
  lKeywords[45] := 'while';
  lKeywords[46] := 'with';
  lKeywords[47] := 'xor';
  lKeywords[48] := 'absolute';
  lKeywords[49] := 'array';
  lKeywords[50] := 'class';
  lKeywords[51] := 'function';
  lKeywords[52] := 'object';

  lLexer := TNXPasLexer.Create('and as asm begin case const constructor ' +
    'destructor div do downto else end finalization for generic if ' +
    'implementation in inherited initialization inline interface library nil ' +
    'not of operator or packed procedure program property record repeat ' +
    'resourcestring set then to try type unit until uses var while with xor ' +
    'absolute array class function object');
  try
    for lIdx := Low(lKeywords) to High(lKeywords) do
      NXPassrcAssertToken(AContext, lLexer, ptkKeyword, lKeywords[lIdx],
        'Keyword ' + lKeywords[lIdx]);
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

procedure TestModuleLifecycleAndProgramLibraryUses(AContext: TNXTestContext);
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
      'implementation' + LineEnding +
      'initialization' + LineEnding +
      'finalization' + LineEnding +
      'end.', lDiagnostics, lSource);
    AContext.AssertEquals(0, lDiagnostics.Count,
      'Unit initialization/finalization sections should parse structurally.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'begin' + LineEnding +
      'end.', lDiagnostics, lSource);
    AContext.AssertEquals(0, lDiagnostics.Count,
      'Unit implementation begin section should parse structurally.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('program Sample;' + LineEnding +
      'uses SysUtils, Classes;' + LineEnding +
      'begin' + LineEnding +
      'end.', lDiagnostics, lSource);
    AContext.AssertEquals(2, lTree.Metadata.InterfaceUses.Count,
      'Program uses should be captured structurally.');
  finally
    lTree.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lTree := nil;
  lSource := nil;
  try
    lTree := NXPassrcParse('library Sample;' + LineEnding +
      'uses SysUtils;' + LineEnding +
      'begin' + LineEnding +
      'end.', lDiagnostics, lSource);
    AContext.AssertEquals(1, lTree.Metadata.InterfaceUses.Count,
      'Library uses should be captured structurally.');
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

procedure TestProcedureModifiersAndDefaults(AContext: TNXTestContext);
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
      'procedure DoDefault(A: Integer = 1; B: string = ''x''); overload;' +
      LineEnding +
      'function MakeDefault(var A: Integer; const B: string = ''x''): TObject; cdecl;' +
      LineEnding +
      'procedure DoStd; stdcall;' + LineEnding +
      'function MakeStd: Integer; stdcall;' + LineEnding +
      'procedure DoForward; forward;' + LineEnding +
      'function MakeForward: Integer; forward;' + LineEnding +
      'procedure DoExternal; external;' + LineEnding +
      'function MakeExternal: Integer; external;' + LineEnding +
      'procedure DoExternalLib; external ''libsample'';' + LineEnding +
      'function MakeExternalLib: Integer; external ''libsample'';' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoDefault');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeDefault');
    AContext.AssertTrue(lProcedure <> nil,
      'Procedure with default parameters and overload directive should parse.');
    AContext.AssertEquals('Integer',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'A').DeclaredTypeText,
      'Defaulted procedure parameter type should be captured.');
    AContext.AssertTrue(lFunction <> nil,
      'Function with var/const/default parameter and cdecl directive should parse.');
    AContext.AssertEquals('TObject', lFunction.DeclaredTypeText,
      'Function return type should survive directive skipping.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoStd') <> nil, 'stdcall procedure should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeStd') <> nil, 'stdcall function should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoForward') <> nil, 'forward procedure should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeForward') <> nil, 'forward function should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoExternal') <> nil, 'external procedure should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeExternal') <> nil, 'external function should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoExternalLib') <> nil, 'external library procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeExternalLib') <> nil, 'external library function should parse.');
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

procedure TestConstTypedAndLiteralDeclarations(AContext: TNXTestContext);
var
  lConst: TNXPasSymbol;
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
      'const' + LineEnding +
      '  FloatConst = 1.5;' + LineEnding +
      '  StringConst = ''text'';' + LineEnding +
      '  NilConst = nil;' + LineEnding +
      '  BoolConst = True;' + LineEnding +
      '  IdentifierConst = OtherValue;' + LineEnding +
      '  TypedInt: Integer = 1;' + LineEnding +
      '  TypedFloat: Double = 1.5;' + LineEnding +
      '  TypedString: string = ''text'';' + LineEnding +
      '  TypedBool: Boolean = True;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'FloatConst') <> nil, 'Float const should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'StringConst') <> nil, 'String const should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'NilConst') <> nil, 'Nil const should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'BoolConst') <> nil, 'Boolean const should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'IdentifierConst') <> nil, 'Identifier const should be captured structurally.');
    lConst := NXPassrcFindSymbol(lSymbols, pskConst, 'TypedInt');
    AContext.AssertEquals('Integer', lConst.DeclaredTypeText,
      'Typed integer const declared type should be captured.');
    AContext.AssertEquals('Double',
      NXPassrcFindSymbol(lSymbols, pskConst, 'TypedFloat').DeclaredTypeText,
      'Typed float const declared type should be captured.');
    AContext.AssertEquals('string',
      NXPassrcFindSymbol(lSymbols, pskConst, 'TypedString').DeclaredTypeText,
      'Typed string const declared type should be captured.');
    AContext.AssertEquals('Boolean',
      NXPassrcFindSymbol(lSymbols, pskConst, 'TypedBool').DeclaredTypeText,
      'Typed bool const declared type should be captured.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestVarStructuralDeclarations(AContext: TNXTestContext);
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
      'var' + LineEnding +
      '  Initialized: Integer = 1;' + LineEnding +
      '  AbsoluteVar: Integer absolute Initialized;' + LineEnding +
      '  ProcVar: procedure(A: Integer);' + LineEnding +
      '  FuncVar: function: Integer = nil;' + LineEnding +
      '  ArrayVar: array[0..2] of Integer;' + LineEnding +
      '  DynArrayVar: array of Integer;' + LineEnding +
      '  ExternalVar: Integer external;' + LineEnding +
      '  ExternalLibVar: Integer external ''libsample'';' + LineEnding +
      '  CVarVar: Integer cvar;' + LineEnding +
      '  PublicVar: Integer public;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertEquals('Integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'Initialized').DeclaredTypeText,
      'Initialized var declared type should be captured.');
    AContext.AssertTrue(Pos('Integer', NXPassrcFindSymbol(lSymbols,
      pskVariable, 'AbsoluteVar').DeclaredTypeText) > 0,
      'Absolute var should preserve structural declared type text.');
    AContext.AssertTrue(Pos('procedure', NXPassrcFindSymbol(lSymbols,
      pskVariable, 'ProcVar').DeclaredTypeText) = 1,
      'Procedure-typed variable should preserve procedure type text.');
    AContext.AssertTrue(Pos('function', NXPassrcFindSymbol(lSymbols,
      pskVariable, 'FuncVar').DeclaredTypeText) = 1,
      'Function-typed variable should preserve function type text.');
    AContext.AssertTrue(Pos('array[0..2] of Integer', NXPassrcFindSymbol(lSymbols,
      pskVariable, 'ArrayVar').DeclaredTypeText) = 1,
      'Static array variable declared type should be captured.');
    AContext.AssertEquals('array of Integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'DynArrayVar').DeclaredTypeText,
      'Dynamic array variable declared type should be captured.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskVariable,
      'ExternalVar') <> nil, 'External var should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskVariable,
      'ExternalLibVar') <> nil, 'External library var should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskVariable,
      'CVarVar') <> nil, 'cvar variable should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskVariable,
      'PublicVar') <> nil, 'public variable should not corrupt parsing.');
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

procedure TestTypeAliasStructuralDeclarations(AContext: TNXTestContext);
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
      '  TByteAlias = Byte;' + LineEnding +
      '  TBooleanAlias = Boolean;' + LineEnding +
      '  TCharAlias = Char;' + LineEnding +
      '  TInt64Alias = Int64;' + LineEnding +
      '  TLongIntAlias = LongInt;' + LineEnding +
      '  TLongWordAlias = LongWord;' + LineEnding +
      '  TDoubleAlias = Double;' + LineEnding +
      '  TShortIntAlias = ShortInt;' + LineEnding +
      '  TSmallIntAlias = SmallInt;' + LineEnding +
      '  TStringAlias = string;' + LineEnding +
      '  TStringSizedAlias = string[20];' + LineEnding +
      '  TWordAlias = Word;' + LineEnding +
      '  TQWordAlias = QWord;' + LineEnding +
      '  TCardinalAlias = Cardinal;' + LineEnding +
      '  TWideCharAlias = WideChar;' + LineEnding +
      '  PIntegerAlias = ^Integer;' + LineEnding +
      '  TStaticArray = array[0..3] of Integer;' + LineEnding +
      '  TPackedArray = packed array[0..3] of Byte;' + LineEnding +
      '  TDynamicArray = array of Integer;' + LineEnding +
      '  TGenericArray = array of TFoo<TBar>;' + LineEnding +
      '  TEnum = (One, Two);' + LineEnding +
      '  TAssignedEnum = (First = 1, Second = 2);' + LineEnding +
      '  TFileType = file of Byte;' + LineEnding +
      '  TSetType = set of Byte;' + LineEnding +
      '  TProcType = procedure(A: Integer);' + LineEnding +
      '  TFuncType = function: Integer;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertEquals('Byte',
      NXPassrcFindSymbol(lSymbols, pskType, 'TByteAlias').DeclaredTypeText,
      'Byte alias declared text should be captured.');
    AContext.AssertEquals('Boolean',
      NXPassrcFindSymbol(lSymbols, pskType, 'TBooleanAlias').DeclaredTypeText,
      'Boolean alias declared text should be captured.');
    AContext.AssertEquals('string[20]',
      NXPassrcFindSymbol(lSymbols, pskType, 'TStringSizedAlias').DeclaredTypeText,
      'Sized string declared text should be captured.');
    AContext.AssertEquals('^Integer',
      NXPassrcFindSymbol(lSymbols, pskType, 'PIntegerAlias').DeclaredTypeText,
      'Pointer declared text should be captured.');
    AContext.AssertEquals('array[0..3] of Integer',
      NXPassrcFindSymbol(lSymbols, pskType, 'TStaticArray').DeclaredTypeText,
      'Static array declared text should be captured.');
    AContext.AssertEquals('packed array[0..3] of Byte',
      NXPassrcFindSymbol(lSymbols, pskType, 'TPackedArray').DeclaredTypeText,
      'Packed static array declared text should be captured.');
    AContext.AssertEquals('array of Integer',
      NXPassrcFindSymbol(lSymbols, pskType, 'TDynamicArray').DeclaredTypeText,
      'Dynamic array declared text should be captured.');
    AContext.AssertEquals('array of TFoo<TBar>',
      NXPassrcFindSymbol(lSymbols, pskType, 'TGenericArray').DeclaredTypeText,
      'Generic array declared text should be captured.');
    AContext.AssertEquals('(One, Two)',
      NXPassrcFindSymbol(lSymbols, pskType, 'TEnum').DeclaredTypeText,
      'Enumeration declared text should be captured.');
    AContext.AssertEquals('(First = 1, Second = 2)',
      NXPassrcFindSymbol(lSymbols, pskType, 'TAssignedEnum').DeclaredTypeText,
      'Assigned enumeration declared text should be captured structurally.');
    AContext.AssertEquals('file of Byte',
      NXPassrcFindSymbol(lSymbols, pskType, 'TFileType').DeclaredTypeText,
      'File type declared text should be captured.');
    AContext.AssertEquals('set of Byte',
      NXPassrcFindSymbol(lSymbols, pskType, 'TSetType').DeclaredTypeText,
      'Set type declared text should be captured.');
    AContext.AssertEquals('procedure(A: Integer)',
      NXPassrcFindSymbol(lSymbols, pskType, 'TProcType').DeclaredTypeText,
      'Procedure type declared text should be captured.');
    AContext.AssertEquals('function: Integer',
      NXPassrcFindSymbol(lSymbols, pskType, 'TFuncType').DeclaredTypeText,
      'Function type declared text should be captured.');
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
  lSuite.AddTest('ScannerLineWhitespaceVariants',
    @TestScannerLineWhitespaceVariants);
  lSuite.AddTest('ScannerCommentsStringsAndDirectives',
    @TestScannerCommentsStringsAndDirectives);
  lSuite.AddTest('ScannerCommentForms', @TestScannerCommentForms);
  lSuite.AddTest('ScannerIdentifierSelfAndCharFragments',
    @TestScannerIdentifierSelfAndCharFragments);
  lSuite.AddTest('ScannerNumbersAndCompoundSymbols',
    @TestScannerNumbersAndCompoundSymbols);
  lSuite.AddTest('ScannerSingleSymbolTokens', @TestScannerSingleSymbolTokens);
  lSuite.AddTest('ScannerAssignmentCompoundSymbols',
    @TestScannerAssignmentCompoundSymbols);
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
  lSuite.AddTest('ModuleLifecycleAndProgramLibraryUses',
    @TestModuleLifecycleAndProgramLibraryUses);
  lSuite.AddTest('TypeClassRecordInterfaceSymbols',
    @TestTypeClassRecordInterfaceSymbols);
  lSuite.AddTest('ClassMembersAndPropertySymbols',
    @TestClassMembersAndPropertySymbols);
  lSuite.AddTest('ObjectRecordInterfaceMemberSymbols',
    @TestObjectRecordInterfaceMemberSymbols);
  lSuite.AddTest('ProcedureFunctionDeclarations',
    @TestProcedureFunctionDeclarations);
  lSuite.AddTest('ProcedureParameterModes', @TestProcedureParameterModes);
  lSuite.AddTest('ProcedureModifiersAndDefaults',
    @TestProcedureModifiersAndDefaults);
  lSuite.AddTest('LocalRoutineVarAndConstDeclarations',
    @TestLocalRoutineVarAndConstDeclarations);
  lSuite.AddTest('ConstAndVarDeclarations', @TestConstAndVarDeclarations);
  lSuite.AddTest('ConstTypedAndLiteralDeclarations',
    @TestConstTypedAndLiteralDeclarations);
  lSuite.AddTest('VarStructuralDeclarations', @TestVarStructuralDeclarations);
  lSuite.AddTest('GenericDeclaredTypeText', @TestGenericDeclaredTypeText);
  lSuite.AddTest('TypeAliasStructuralDeclarations',
    @TestTypeAliasStructuralDeclarations);
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
