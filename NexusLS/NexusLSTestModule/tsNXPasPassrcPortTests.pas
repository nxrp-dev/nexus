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

procedure NXPassrcAssertRawToken(AContext: TNXTestContext; ALexer: TNXPasLexer;
  AKind: TNXPasTokenKind; const AText, AMessage: string);
var
  lToken: TNXPasToken;
begin
  lToken := ALexer.NextToken;
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
  lLexer := TNXPasLexer.Create(#10);
  try
    lToken := lLexer.NextToken;
    AContext.AssertEquals(Ord(ptkWhitespace), Ord(lToken.Kind),
      'Line ending should produce whitespace token.');
    AContext.AssertEquals(#10, lToken.Text,
      'Line ending whitespace text should be preserved.');
  finally
    lLexer.Free;
  end;

  lLexer := TNXPasLexer.Create(#9);
  try
    lToken := lLexer.NextToken;
    AContext.AssertEquals(Ord(ptkWhitespace), Ord(lToken.Kind),
      'Tab should produce whitespace token.');
    AContext.AssertEquals(#9, lToken.Text,
      'Tab whitespace text should be preserved.');
  finally
    lLexer.Free;
  end;

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
  lLexer := TNXPasLexer.Create('{brace {nested}} (* paren (* nested *) star *) // slash');
  try
    NXPassrcAssertToken(AContext, lLexer, ptkComment, '{brace {nested}}',
      'Nested brace comment');
    NXPassrcAssertToken(AContext, lLexer, ptkComment, '(* paren (* nested *) star *)',
      'Nested paren-star comment');
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
  lLexer := TNXPasLexer.Create('Alpha Self &xor #65#$0A#13 ''A''');
  try
    NXPassrcAssertToken(AContext, lLexer, ptkIdentifier, 'Alpha',
      'Identifier');
    NXPassrcAssertToken(AContext, lLexer, ptkIdentifier, 'Self',
      'Self pseudo-variable');
    NXPassrcAssertToken(AContext, lLexer, ptkIdentifier, '&xor',
      'Escaped keyword identifier');
    NXPassrcAssertToken(AContext, lLexer, ptkString, '#65#$0A#13',
      'Character literal sequence');
    NXPassrcAssertToken(AContext, lLexer, ptkString, '''A''',
      'String part after character ordinal');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerTokenSeriesAndDirectives(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
begin
  lLexer := TNXPasLexer.Create('in of then aninteger');
  try
    NXPassrcAssertRawToken(AContext, lLexer, ptkKeyword, 'in',
      'Token series without comments in');
    NXPassrcAssertRawToken(AContext, lLexer, ptkWhitespace, ' ',
      'Token series without comments whitespace 1');
    NXPassrcAssertRawToken(AContext, lLexer, ptkKeyword, 'of',
      'Token series without comments of');
    NXPassrcAssertRawToken(AContext, lLexer, ptkWhitespace, ' ',
      'Token series without comments whitespace 2');
    NXPassrcAssertRawToken(AContext, lLexer, ptkKeyword, 'then',
      'Token series without comments then');
    NXPassrcAssertRawToken(AContext, lLexer, ptkWhitespace, ' ',
      'Token series without comments whitespace 3');
    NXPassrcAssertRawToken(AContext, lLexer, ptkIdentifier, 'aninteger',
      'Token series without comments identifier');
  finally
    lLexer.Free;
  end;

  lLexer := TNXPasLexer.Create('in of then aninteger');
  try
    NXPassrcAssertToken(AContext, lLexer, ptkKeyword, 'in',
      'Token series adjusted skip whitespace in');
    NXPassrcAssertToken(AContext, lLexer, ptkKeyword, 'of',
      'Token series adjusted skip whitespace of');
    NXPassrcAssertToken(AContext, lLexer, ptkKeyword, 'then',
      'Token series adjusted skip whitespace then');
    NXPassrcAssertToken(AContext, lLexer, ptkIdentifier, 'aninteger',
      'Token series adjusted skip whitespace identifier');
  finally
    lLexer.Free;
  end;

  lLexer := TNXPasLexer.Create('in of {then} aninteger');
  try
    NXPassrcAssertRawToken(AContext, lLexer, ptkKeyword, 'in',
      'Token series in');
    NXPassrcAssertRawToken(AContext, lLexer, ptkWhitespace, ' ',
      'Token series whitespace 1');
    NXPassrcAssertRawToken(AContext, lLexer, ptkKeyword, 'of',
      'Token series of');
    NXPassrcAssertRawToken(AContext, lLexer, ptkWhitespace, ' ',
      'Token series whitespace 2');
    NXPassrcAssertRawToken(AContext, lLexer, ptkComment, '{then}',
      'Token series comment');
    NXPassrcAssertRawToken(AContext, lLexer, ptkWhitespace, ' ',
      'Token series whitespace 3');
    NXPassrcAssertRawToken(AContext, lLexer, ptkIdentifier, 'aninteger',
      'Token series identifier');
  finally
    lLexer.Free;
  end;

  lLexer := TNXPasLexer.Create('{$DEFINE NEVER} (*$DEFINE NEVER*) {$IFDEF ALWAYS} of {$ENDIF}');
  try
    NXPassrcAssertToken(AContext, lLexer, ptkDirective, '{$DEFINE NEVER}',
      'Brace DEFINE directive');
    NXPassrcAssertToken(AContext, lLexer, ptkDirective, '(*$DEFINE NEVER*)',
      'Paren-star DEFINE directive');
    NXPassrcAssertToken(AContext, lLexer, ptkDirective, '{$IFDEF ALWAYS}',
      'IFDEF directive');
    NXPassrcAssertToken(AContext, lLexer, ptkKeyword, 'of',
      'Token after directive');
    NXPassrcAssertToken(AContext, lLexer, ptkDirective, '{$ENDIF}',
      'ENDIF directive');
  finally
    lLexer.Free;
  end;

  lLexer := TNXPasLexer.Create('{$DEFINE  NEVER} {$DEFINE NEVER }');
  try
    NXPassrcAssertToken(AContext, lLexer, ptkDirective, '{$DEFINE  NEVER}',
      'Brace DEFINE directive with internal spacing');
    NXPassrcAssertToken(AContext, lLexer, ptkDirective, '{$DEFINE NEVER }',
      'Brace DEFINE directive with trailing spacing');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerBOM(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
begin
  lLexer := TNXPasLexer.Create(#$EF#$BB#$BF'unit Sample;');
  try
    NXPassrcAssertRawToken(AContext, lLexer, ptkWhitespace, #$EF#$BB#$BF,
      'UTF-8 BOM');
    NXPassrcAssertRawToken(AContext, lLexer, ptkKeyword, 'unit',
      'Token after UTF-8 BOM');
  finally
    lLexer.Free;
  end;
end;

procedure TestScannerUnterminatedDiagnostics(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lLexer: TNXPasLexer;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lLexer := TNXPasLexer.Create('{unterminated', lDiagnostics);
  try
    NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertTrue(NXPassrcHasDiagnostic(lDiagnostics,
      'nxpas.unterminatedBraceComment'),
      'Unterminated brace comments should produce a NexusPas diagnostic.');
  finally
    lLexer.Free;
    lDiagnostics.Free;
  end;

  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lLexer := TNXPasLexer.Create('(*unterminated', lDiagnostics);
  try
    NXPassrcNextNonWhitespace(lLexer);
    AContext.AssertTrue(NXPassrcHasDiagnostic(lDiagnostics,
      'nxpas.unterminatedParenStarComment'),
      'Unterminated paren-star comments should produce a NexusPas diagnostic.');
  finally
    lLexer.Free;
    lDiagnostics.Free;
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
  lSymbols: array[0..17] of string;
begin
  lSymbols[0] := '(';
  lSymbols[1] := ')';
  lSymbols[2] := '*';
  lSymbols[3] := '+';
  lSymbols[4] := ',';
  lSymbols[5] := '-';
  lSymbols[6] := '.';
  lSymbols[7] := '/';
  lSymbols[8] := ':';
  lSymbols[9] := ';';
  lSymbols[10] := '<';
  lSymbols[11] := '=';
  lSymbols[12] := '>';
  lSymbols[13] := '@';
  lSymbols[14] := '[';
  lSymbols[15] := ']';
  lSymbols[16] := '^';
  lSymbols[17] := '\';

  lLexer := TNXPasLexer.Create('( ) * + , - . / : ; < = > @ [ ] ^ \');
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
  lSymbols: array[0..7] of string;
begin
  lSymbols[0] := '+=';
  lSymbols[1] := '-=';
  lSymbols[2] := '*=';
  lSymbols[3] := '/=';
  lSymbols[4] := '**';
  lSymbols[5] := '><';
  lSymbols[6] := '<<';
  lSymbols[7] := '>>';

  lLexer := TNXPasLexer.Create('+= -= *= /= ** >< << >>');
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
  lKeywords: array[0..71] of string;
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
  lKeywords[53] := 'bitpacked';
  lKeywords[54] := 'dispinterface';
  lKeywords[55] := 'except';
  lKeywords[56] := 'exports';
  lKeywords[57] := 'false';
  lKeywords[58] := 'file';
  lKeywords[59] := 'finally';
  lKeywords[60] := 'goto';
  lKeywords[61] := 'helper';
  lKeywords[62] := 'is';
  lKeywords[63] := 'label';
  lKeywords[64] := 'mod';
  lKeywords[65] := 'on';
  lKeywords[66] := 'raise';
  lKeywords[67] := 'shl';
  lKeywords[68] := 'shr';
  lKeywords[69] := 'specialize';
  lKeywords[70] := 'threadvar';
  lKeywords[71] := 'true';

  lLexer := TNXPasLexer.Create('and as asm begin case const constructor ' +
    'destructor div do downto else end finalization for generic if ' +
    'implementation in inherited initialization inline interface library nil ' +
    'not of operator or packed procedure program property record repeat ' +
    'resourcestring set then to try type unit until uses var while with xor ' +
    'absolute array class function object bitpacked dispinterface except ' +
    'exports false file finally goto helper is label mod on raise shl shr ' +
    'specialize threadvar true');
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

procedure TestStructuredTypeHeritageConstructorsProperties(
  AContext: TNXTestContext);
var
  lClass: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lProperty: TNXPasSymbol;
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
      '  TSample = class(TBase, IRun, IWalk)' + LineEnding +
      '  private' + LineEnding +
      '    FName: string;' + LineEnding +
      '    FCount: Integer;' + LineEnding +
      '    function GetItem(Index: Integer): string;' + LineEnding +
      '  public' + LineEnding +
      '    constructor Create;' + LineEnding +
      '    destructor Destroy;' + LineEnding +
      '    property Name: string read FName write FName;' + LineEnding +
      '    property Count: Integer read FCount;' + LineEnding +
      '    property Items[Index: Integer]: string read GetItem;' + LineEnding +
      '    property Indexed: string index 1 read GetItem;' + LineEnding +
      '    property Enabled: Boolean read FEnabled write FEnabled default True;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lClass := NXPassrcFindSymbol(lSymbols, pskClass, 'TSample');
    AContext.AssertEquals('TBase, IRun, IWalk', lClass.DeclaredTypeText,
      'Class heritage text should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskRoutine,
      'Create') <> nil, 'Constructor should be a nested routine symbol.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskRoutine,
      'Destroy') <> nil, 'Destructor should be a nested routine symbol.');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'Name');
    AContext.AssertEquals('string', lProperty.DeclaredTypeText,
      'Property declared type should be captured.');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'Items');
    AContext.AssertEquals('string', lProperty.DeclaredTypeText,
      'Indexed property declared type should be captured.');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'Indexed');
    AContext.AssertEquals('string', lProperty.DeclaredTypeText,
      'Property index modifier should not corrupt declared type capture.');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'Enabled');
    AContext.AssertEquals('Boolean', lProperty.DeclaredTypeText,
      'Property modifiers should not corrupt declared type capture.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestClassFieldMethodStructuralVariants(AContext: TNXTestContext);
var
  lClass: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lField: TNXPasSymbol;
  lFunction: TNXPasSymbol;
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
      '    A, B: Integer;' + LineEnding +
      '    helper: string;' + LineEnding +
      '    var C, D: string;' + LineEnding +
      '    class var E: TObject;' + LineEnding +
      '  public' + LineEnding +
      '    procedure Run;' + LineEnding +
      '    class procedure ClassRun;' + LineEnding +
      '    function Build(AValue: Integer): Integer;' + LineEnding +
      '    class function ClassBuild: string;' + LineEnding +
      '    procedure VirtualRun; virtual;' + LineEnding +
      '    procedure AbstractRun; virtual; abstract; final;' + LineEnding +
      '    procedure OverrideRun; override;' + LineEnding +
      '    procedure DynamicRun; dynamic;' + LineEnding +
      '    procedure ReRun; reintroduce;' + LineEnding +
      '    procedure InlineRun; inline;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lClass := NXPassrcFindSymbol(lSymbols, pskClass, 'TSample');
    lField := NXPassrcFindChildSymbol(lClass, pskField, 'A');
    AContext.AssertEquals('Integer', lField.DeclaredTypeText,
      'Grouped class field declared type should be captured.');
    lField := NXPassrcFindChildSymbol(lClass, pskField, 'helper');
    AContext.AssertEquals('string', lField.DeclaredTypeText,
      'Keyword-shaped helper field should remain a field.');
    lField := NXPassrcFindChildSymbol(lClass, pskField, 'D');
    AContext.AssertEquals('string', lField.DeclaredTypeText,
      'Class-body var field section should be parsed as fields.');
    lField := NXPassrcFindChildSymbol(lClass, pskField, 'E');
    AContext.AssertEquals('TObject', lField.DeclaredTypeText,
      'Class var field section should be parsed as fields.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskRoutine,
      'Run') <> nil, 'Plain class procedure should be parsed.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskRoutine,
      'ClassRun') <> nil, 'Class procedure should be parsed.');
    lFunction := NXPassrcFindChildSymbol(lClass, pskRoutine, 'Build');
    AContext.AssertEquals('Integer', lFunction.DeclaredTypeText,
      'Class function return type should be captured.');
    lFunction := NXPassrcFindChildSymbol(lClass, pskRoutine, 'ClassBuild');
    AContext.AssertEquals('string', lFunction.DeclaredTypeText,
      'Class function prefix should not hide the routine declaration.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskRoutine,
      'AbstractRun') <> nil, 'Routine modifiers should not hide methods.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskField,
      'virtual') = nil, 'Routine modifiers should not become fields.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskField,
      'abstract') = nil, 'Routine modifiers should not become fields.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestPropertyInterfaceAndRecordStructuralVariants(
  AContext: TNXTestContext);
var
  lClass: TNXPasSymbol;
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lInterface: TNXPasSymbol;
  lProperty: TNXPasSymbol;
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
      '  TSample = class' + LineEnding +
      '  private' + LineEnding +
      '    FValue: Integer;' + LineEnding +
      '    function GetItem(Index: Integer): string;' + LineEnding +
      '  public' + LineEnding +
      '    property WriteOnly: Integer write FValue;' + LineEnding +
      '    property NoDefault: Integer read FValue nodefault;' + LineEnding +
      '    property StoredValue: Integer read FValue stored CheckStored;' + LineEnding +
      '    property StoredFalse: Boolean read FFlag stored False;' + LineEnding +
      '    property Qualified: UnitA.TypeB read FQualified;' + LineEnding +
      '    property ItemsRW[Index: Integer]: string read GetItem write SetItem;' + LineEnding +
      '    property DefaultItem[Index: Integer]: string read GetItem; default;' + LineEnding +
      '    property Matrix[ACol: Integer; ARow: Integer]: Integer read GetMatrix;' + LineEnding +
      '    property Implemented: UnitA.IThing read FThing implements UnitA.IThing;' + LineEnding +
      '  end;' + LineEnding +
      '  TRec = record' + LineEnding +
      '    X, Y: Integer;' + LineEnding +
      '    constructor Create(AValue: Integer);' + LineEnding +
      '    property Value: Integer read X;' + LineEnding +
      '  end;' + LineEnding +
      '  IRun = interface(IBase)' + LineEnding +
      '    procedure Execute;' + LineEnding +
      '    property Value: Integer read GetValue;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lClass := NXPassrcFindSymbol(lSymbols, pskClass, 'TSample');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'Qualified');
    AContext.AssertEquals('UnitA.TypeB', lProperty.DeclaredTypeText,
      'Fully qualified property type should be captured.');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'Matrix');
    AContext.AssertEquals('Integer', lProperty.DeclaredTypeText,
      'Multi-dimensional indexed property type should be captured.');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'ItemsRW');
    AContext.AssertEquals('string', lProperty.DeclaredTypeText,
      'Indexed read/write property type should be captured.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lClass, pskField,
      'default') = nil, 'Default property directive should not become a field.');
    lProperty := NXPassrcFindChildSymbol(lClass, pskProperty, 'Implemented');
    AContext.AssertEquals('UnitA.IThing', lProperty.DeclaredTypeText,
      'Implements modifier should not corrupt property type capture.');
    lRecord := NXPassrcFindSymbol(lSymbols, pskRecord, 'TRec');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lRecord, pskRoutine,
      'Create') <> nil, 'Record constructor should be parsed structurally.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lRecord, pskProperty,
      'Value') <> nil, 'Record property should be parsed structurally.');
    lInterface := NXPassrcFindSymbol(lSymbols, pskInterface, 'IRun');
    AContext.AssertEquals('IBase', lInterface.DeclaredTypeText,
      'Interface heritage should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lInterface, pskProperty,
      'Value') <> nil, 'Interface property should be parsed structurally.');
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

procedure TestProcedureAdvancedParameterForms(AContext: TNXTestContext);
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
      'procedure DoConstRef(constref A: Integer);' + LineEnding +
      'function MakeConstRef(constref A: Integer): Integer;' + LineEnding +
      'procedure DoUntyped(var A; const B);' + LineEnding +
      'function MakeUntyped(var A, B): Integer;' + LineEnding +
      'procedure DoOpen(A: array of Integer; const B: array of string);' +
      LineEnding +
      'function MakeOpen(A: array of Integer): Integer;' + LineEnding +
      'procedure DoVarOpen(var A: array of Integer);' + LineEnding +
      'function MakeVarOpen(var A: array of Integer): Integer;' + LineEnding +
      'procedure DoArrayOfConst(A: array of const);' + LineEnding +
      'function MakeArrayOfConst(A: array of const): Integer;' + LineEnding +
      'procedure DoDefaultSet(A: TSet = [One, Two]);' + LineEnding +
      'function MakeDefaultExpr(A: Integer = 1 + 2): Integer;' + LineEnding +
      'function MakeEnum(B: TSomeEnum = TSomeEnum.False): Integer;' +
      LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoConstRef');
    AContext.AssertEquals('Integer',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'A').DeclaredTypeText,
      'constref procedure parameter type should be captured.');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeConstRef');
    AContext.AssertEquals('Integer', lFunction.DeclaredTypeText,
      'constref function return type should be captured.');
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoUntyped');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lProcedure, pskParameter,
      'A') <> nil, 'Untyped var parameter should be captured.');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lProcedure, pskParameter,
      'B') <> nil, 'Untyped const parameter should be captured.');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeUntyped');
    AContext.AssertTrue(NXPassrcFindChildSymbol(lFunction, pskParameter,
      'B') <> nil, 'Grouped untyped var parameter should be captured.');
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoOpen');
    AContext.AssertEquals('array of Integer',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'A').DeclaredTypeText,
      'Open array parameter type should be captured.');
    AContext.AssertEquals('array of string',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'B').DeclaredTypeText,
      'Const open array parameter type should be captured.');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeOpen');
    AContext.AssertEquals('array of Integer',
      NXPassrcFindChildSymbol(lFunction, pskParameter, 'A').DeclaredTypeText,
      'Function open array parameter type should be captured.');
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoVarOpen');
    AContext.AssertEquals('array of Integer',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'A').DeclaredTypeText,
      'Var open array parameter type should be captured.');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeVarOpen');
    AContext.AssertEquals('array of Integer',
      NXPassrcFindChildSymbol(lFunction, pskParameter, 'A').DeclaredTypeText,
      'Function var open array parameter type should be captured.');
    lProcedure := NXPassrcFindSymbol(lSymbols, pskRoutine, 'DoArrayOfConst');
    AContext.AssertEquals('array of const',
      NXPassrcFindChildSymbol(lProcedure, pskParameter, 'A').DeclaredTypeText,
      'array of const parameter type should be captured structurally.');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeArrayOfConst');
    AContext.AssertEquals('array of const',
      NXPassrcFindChildSymbol(lFunction, pskParameter, 'A').DeclaredTypeText,
      'Function array of const parameter type should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoDefaultSet') <> nil,
      'Default set parameter expression should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeDefaultExpr') <> nil,
      'Default expression parameter should not corrupt parsing.');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeEnum');
    AContext.AssertEquals('TSomeEnum',
      NXPassrcFindChildSymbol(lFunction, pskParameter, 'B').DeclaredTypeText,
      'Explicit enum default parameter type should be captured.');
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

procedure TestProcedureAdditionalDirectives(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lExtractor: TNXPasSymbolExtractor;
  lFunction: TNXPasSymbol;
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
      'procedure DoDeprecated; deprecated;' + LineEnding +
      'function MakeDeprecated: Integer; deprecated;' + LineEnding +
      'procedure DoPlatform; platform;' + LineEnding +
      'function MakePlatform: Integer; platform;' + LineEnding +
      'procedure DoExperimental; experimental;' + LineEnding +
      'function MakeExperimental: Integer; experimental;' + LineEnding +
      'procedure DoUnimplemented; unimplemented;' + LineEnding +
      'function MakeUnimplemented: Integer; unimplemented;' + LineEnding +
      'procedure DoCdeclDeprecated; cdecl; deprecated;' + LineEnding +
      'function MakeCdeclDeprecated: Integer; cdecl; deprecated;' + LineEnding +
      'procedure DoSafeCall; safecall;' + LineEnding +
      'function MakeSafeCall: Integer; safecall;' + LineEnding +
      'procedure DoPascal; pascal;' + LineEnding +
      'function MakePascal: Integer; pascal;' + LineEnding +
      'procedure DoOldFpcCall; oldfpccall;' + LineEnding +
      'function MakeOldFpcCall: Integer; oldfpccall;' + LineEnding +
      'procedure DoHardFloat; hardfloat;' + LineEnding +
      'procedure DoMSAbiCDecl; ms_abi_cdecl;' + LineEnding +
      'procedure DoMSAbiDefault; ms_abi_default;' + LineEnding +
      'procedure DoMWPascal; mwpascal;' + LineEnding +
      'procedure DoSysVAbiCDecl; sysv_abi_cdecl;' + LineEnding +
      'procedure DoSysVAbiDefault; sysv_abi_default;' + LineEnding +
      'procedure DoVectorCall; vectorcall;' + LineEnding +
      'procedure DoPublic; public name ''myfunc'';' + LineEnding +
      'procedure DoPublicIdent; public name exportname;' + LineEnding +
      'function MakePublic: Integer; public name exportname;' + LineEnding +
      'procedure DoCdeclPublic; cdecl; public name exportname;' + LineEnding +
      'function MakeCdeclPublic: Integer; cdecl; public name exportname;' +
      LineEnding +
      'procedure DoVarargs; varargs;' + LineEnding +
      'function MakeVarargs: Integer; varargs;' + LineEnding +
      'procedure DoCdeclVarargs; cdecl; varargs;' + LineEnding +
      'function MakeCdeclVarargs: Integer; cdecl; varargs;' + LineEnding +
      'procedure DoFar; far;' + LineEnding +
      'function MakeFar: Integer; far;' + LineEnding +
      'procedure DoCompilerProc; compilerproc;' + LineEnding +
      'procedure DoNoReturn; noreturn;' + LineEnding +
      'function MakeCompilerProc: Integer; compilerproc;' + LineEnding +
      'procedure DoCdeclCompilerProc; cdecl; compilerproc;' + LineEnding +
      'function MakeCdeclCompilerProc: Integer; cdecl; compilerproc;' +
      LineEnding +
      'procedure DoAssembler; assembler;' + LineEnding +
      'function MakeAssembler: Integer; assembler;' + LineEnding +
      'procedure DoCdeclAssembler; cdecl; assembler;' + LineEnding +
      'function MakeCdeclAssembler: Integer; cdecl; assembler;' + LineEnding +
      'procedure DoExport; export;' + LineEnding +
      'function MakeExport: Integer; export;' + LineEnding +
      'procedure DoCdeclExport; cdecl; export;' + LineEnding +
      'function MakeCdeclExport: Integer; cdecl; export;' + LineEnding +
      'procedure DoExternalLibNameName; external ''libname'' name ''symbolname'';' +
      LineEnding +
      'function MakeExternalLibNameName: Integer; external ''libname'' name ''symbolname'';' +
      LineEnding +
      'procedure DoExternalName; external name ''symbolname'';' + LineEnding +
      'function MakeExternalName: Integer; external name ''symbolname'';' +
      LineEnding +
      'procedure DoCdeclExternal; cdecl; external;' + LineEnding +
      'function MakeCdeclExternal: Integer; cdecl; external;' + LineEnding +
      'procedure DoCdeclExternalLibName; cdecl; external ''libname'';' +
      LineEnding +
      'function MakeCdeclExternalLibName: Integer; cdecl; external ''libname'';' +
      LineEnding +
      'procedure DoCdeclExternalLibNameName; cdecl; external ''libname'' name ''symbolname'';' +
      LineEnding +
      'function MakeCdeclExternalLibNameName: Integer; cdecl; external ''libname'' name ''symbolname'';' +
      LineEnding +
      'procedure DoCdeclExternalName; cdecl; external name ''symbolname'';' +
      LineEnding +
      'function MakeCdeclExternalName: Integer; cdecl; external name ''symbolname'';' +
      LineEnding +
      'procedure DoAlias; alias: ''myalias'';' + LineEnding +
      'function MakeAlias: Integer; alias: ''myalias'';' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);

    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoDeprecated') <> nil, 'deprecated procedure should parse.');
    lFunction := NXPassrcFindSymbol(lSymbols, pskRoutine, 'MakeDeprecated');
    AContext.AssertEquals('Integer', lFunction.DeclaredTypeText,
      'deprecated function return type should survive directive skipping.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoPlatform') <> nil, 'platform procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakePlatform') <> nil, 'platform function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoExperimental') <> nil, 'experimental procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeExperimental') <> nil, 'experimental function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoUnimplemented') <> nil, 'unimplemented procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeUnimplemented') <> nil, 'unimplemented function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclDeprecated') <> nil, 'cdecl deprecated procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclDeprecated') <> nil, 'cdecl deprecated function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoSafeCall') <> nil, 'safecall procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeSafeCall') <> nil, 'safecall function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoPascal') <> nil, 'pascal procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakePascal') <> nil, 'pascal function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoOldFpcCall') <> nil, 'oldfpccall procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeOldFpcCall') <> nil, 'oldfpccall function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoHardFloat') <> nil, 'hardfloat procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoMSAbiCDecl') <> nil, 'ms_abi_cdecl procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoMSAbiDefault') <> nil, 'ms_abi_default procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoMWPascal') <> nil, 'mwpascal procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoSysVAbiCDecl') <> nil, 'sysv_abi_cdecl procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoSysVAbiDefault') <> nil, 'sysv_abi_default procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoVectorCall') <> nil, 'vectorcall procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoPublic') <> nil, 'public name procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoPublicIdent') <> nil, 'public name identifier procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakePublic') <> nil, 'public name function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclPublic') <> nil, 'cdecl public procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclPublic') <> nil, 'cdecl public function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoVarargs') <> nil, 'varargs procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeVarargs') <> nil, 'varargs function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclVarargs') <> nil, 'cdecl varargs procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclVarargs') <> nil, 'cdecl varargs function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoFar') <> nil, 'far procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeFar') <> nil, 'far function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCompilerProc') <> nil, 'compilerproc procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoNoReturn') <> nil, 'noreturn procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCompilerProc') <> nil, 'compilerproc function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclCompilerProc') <> nil, 'cdecl compilerproc procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclCompilerProc') <> nil, 'cdecl compilerproc function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoAssembler') <> nil, 'assembler procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeAssembler') <> nil, 'assembler function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclAssembler') <> nil, 'cdecl assembler procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclAssembler') <> nil, 'cdecl assembler function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoExport') <> nil, 'export procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeExport') <> nil, 'export function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclExport') <> nil, 'cdecl export procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclExport') <> nil, 'cdecl export function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoExternalLibNameName') <> nil,
      'external library/name procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeExternalLibNameName') <> nil,
      'external library/name function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoExternalName') <> nil, 'external name procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeExternalName') <> nil, 'external name function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclExternal') <> nil, 'cdecl external procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclExternal') <> nil, 'cdecl external function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclExternalLibName') <> nil,
      'cdecl external library procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclExternalLibName') <> nil,
      'cdecl external library function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclExternalLibNameName') <> nil,
      'cdecl external library/name procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclExternalLibNameName') <> nil,
      'cdecl external library/name function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoCdeclExternalName') <> nil,
      'cdecl external name procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeCdeclExternalName') <> nil,
      'cdecl external name function should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'DoAlias') <> nil, 'alias procedure should parse.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskRoutine,
      'MakeAlias') <> nil, 'alias function should parse.');
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

procedure TestConstAdvancedStructuralDeclarations(AContext: TNXTestContext);
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
      '  SetConst = [taLeftJustify, taRightJustify];' + LineEnding +
      '  ExprConst = 1 + 2;' + LineEnding +
      '  DeprecatedConst = 1 deprecated;' + LineEnding +
      '  PlatformConst = ''text'' platform;' + LineEnding +
      '  ExperimentalConst = True experimental;' + LineEnding +
      '  TypedNil: PChar = nil;' + LineEnding +
      '  TypedIdent: TAlign = taCenter;' + LineEnding +
      '  TypedSet: TAligns = [taLeftJustify, taRightJustify];' + LineEnding +
      '  TypedExpr: ShortInt = 1 + 2;' + LineEnding +
      '  RecordConst: TPoint = (x: 1; y: 2);' + LineEnding +
      '  ArrayConst: TMyArray = (1, 2);' + LineEnding +
      '  RangeConst: 0..1 = 1;' + LineEnding +
      '  ArrayOfRange: array[0..7] of 0..1 = (0, 0, 0, 0);' + LineEnding +
      'resourcestring' + LineEnding +
      '  SimpleResource = ''Something'';' + LineEnding +
      '  SumResource = ''Something'' + '' else'' deprecated;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'SetConst') <> nil, 'Set-like const should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'ExprConst') <> nil, 'Expression const should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'DeprecatedConst') <> nil, 'Deprecated const should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'PlatformConst') <> nil, 'Platform const should not corrupt parsing.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'ExperimentalConst') <> nil,
      'Experimental const should not corrupt parsing.');
    lConst := NXPassrcFindSymbol(lSymbols, pskConst, 'TypedNil');
    AContext.AssertEquals('PChar', lConst.DeclaredTypeText,
      'Typed nil const declared type should be captured.');
    AContext.AssertEquals('TAlign',
      NXPassrcFindSymbol(lSymbols, pskConst, 'TypedIdent').DeclaredTypeText,
      'Typed identifier const declared type should be captured.');
    AContext.AssertEquals('TAligns',
      NXPassrcFindSymbol(lSymbols, pskConst, 'TypedSet').DeclaredTypeText,
      'Typed set const declared type should be captured.');
    AContext.AssertEquals('ShortInt',
      NXPassrcFindSymbol(lSymbols, pskConst, 'TypedExpr').DeclaredTypeText,
      'Typed expression const declared type should be captured.');
    AContext.AssertEquals('TPoint',
      NXPassrcFindSymbol(lSymbols, pskConst, 'RecordConst').DeclaredTypeText,
      'Record const declared type should be captured.');
    AContext.AssertEquals('TMyArray',
      NXPassrcFindSymbol(lSymbols, pskConst, 'ArrayConst').DeclaredTypeText,
      'Array const declared type should be captured.');
    AContext.AssertEquals('0..1',
      NXPassrcFindSymbol(lSymbols, pskConst, 'RangeConst').DeclaredTypeText,
      'Range const declared type should be captured structurally.');
    AContext.AssertEquals('array[0..7] of 0..1',
      NXPassrcFindSymbol(lSymbols, pskConst, 'ArrayOfRange').DeclaredTypeText,
      'Array-of-range const declared type should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'SimpleResource') <> nil, 'Resourcestring should be captured structurally.');
    AContext.AssertTrue(NXPassrcFindSymbol(lSymbols, pskConst,
      'SumResource') <> nil, 'Resourcestring expression should be captured structurally.');
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

procedure TestVarModifierStructuralDeclarations(AContext: TNXTestContext);
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
      '  Helper: Integer;' + LineEnding +
      '  HelperType: helper;' + LineEnding +
      '  DeprecatedVar: b deprecated;' + LineEnding +
      '  PlatformVar: b platform;' + LineEnding +
      '  InitializedDeprecated: b = 123 deprecated;' + LineEnding +
      '  InitializedPlatform: b = 123 platform;' + LineEnding +
      '  AbsoluteDot: q absolute v.w;' + LineEnding +
      '  AbsoluteTwoDots: q absolute v.w.x;' + LineEnding +
      '  ProcDeprecated: procedure deprecated;' + LineEnding +
      '  RecordDeprecated: record x, y: integer; end deprecated;' + LineEnding +
      '  RecordPlatform: record x, y: integer; end platform;' + LineEnding +
      '  ArrayDeprecated: array[1..20] of integer deprecated;' + LineEnding +
      '  ExternalNoSemi: integer external;' + LineEnding +
      '  CVarExternal: integer cvar; external;' + LineEnding +
      '  PublicName: integer public name ''ce'';' + LineEnding +
      '  DeprecatedExternalName: integer deprecated; external name ''me'';' + LineEnding +
      '  HintPriorToInit: boolean platform = false;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertEquals('Integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'Helper').DeclaredTypeText,
      'Keyword-shaped helper variable name should be parsed.');
    AContext.AssertEquals('helper',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'HelperType').DeclaredTypeText,
      'Keyword-shaped helper variable type should be captured.');
    AContext.AssertEquals('b',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'DeprecatedVar').DeclaredTypeText,
      'Deprecated variable tail should not enter declared type text.');
    AContext.AssertEquals('b',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'PlatformVar').DeclaredTypeText,
      'Platform variable tail should not enter declared type text.');
    AContext.AssertEquals('q',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'AbsoluteDot').DeclaredTypeText,
      'Absolute variable tail should not enter declared type text.');
    AContext.AssertEquals('procedure',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'ProcDeprecated').DeclaredTypeText,
      'Procedure variable deprecated tail should be skipped structurally.');
    AContext.AssertTrue(Pos('record', NXPassrcFindSymbol(lSymbols, pskVariable,
      'RecordDeprecated').DeclaredTypeText) = 1,
      'Record variable deprecated tail should be skipped structurally.');
    AContext.AssertTrue(Pos('array[1..20] of integer',
      NXPassrcFindSymbol(lSymbols, pskVariable,
      'ArrayDeprecated').DeclaredTypeText) = 1,
      'Array variable deprecated tail should be skipped structurally.');
    AContext.AssertEquals('integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'ExternalNoSemi').DeclaredTypeText,
      'External variable tail without early semicolon should be skipped.');
    AContext.AssertEquals('integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'CVarExternal').DeclaredTypeText,
      'cvar/external variable tails should be skipped.');
    AContext.AssertEquals('integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'PublicName').DeclaredTypeText,
      'public name variable tail should be skipped.');
    AContext.AssertEquals('integer',
      NXPassrcFindSymbol(lSymbols, pskVariable,
      'DeprecatedExternalName').DeclaredTypeText,
      'deprecated/external name variable tails should be skipped.');
    AContext.AssertEquals('boolean',
      NXPassrcFindSymbol(lSymbols, pskVariable,
      'HintPriorToInit').DeclaredTypeText,
      'Hint before initializer should be skipped structurally.');
  finally
    lTree.Free;
    lSymbols.Free;
    lExtractor.Free;
    lSource.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestInlineAnonymousTypeDeclarations(AContext: TNXTestContext);
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
      '  R: record' + LineEnding +
      '    A: Integer;' + LineEnding +
      '    B: string;' + LineEnding +
      '  end;' + LineEnding +
      '  A: array[0..9] of Integer;' + LineEnding +
      '  D: array of string;' + LineEnding +
      '  S: set of Byte;' + LineEnding +
      '  F: file of Byte;' + LineEnding +
      '  P: ^Integer;' + LineEnding +
      '  Callback: procedure(AValue: Integer);' + LineEnding +
      '  Getter: function(const AName: string): Integer;' + LineEnding +
      'implementation' + LineEnding + 'end.', lDiagnostics, lSource);
    lExtractor.Extract(lTree, lSymbols);
    AContext.AssertTrue(Pos('record', NXPassrcFindSymbol(lSymbols,
      pskVariable, 'R').DeclaredTypeText) = 1,
      'Inline record type text should be captured structurally.');
    AContext.AssertEquals('array[0..9] of Integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'A').DeclaredTypeText,
      'Static array type text should be captured.');
    AContext.AssertEquals('array of string',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'D').DeclaredTypeText,
      'Dynamic array type text should be captured.');
    AContext.AssertEquals('set of Byte',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'S').DeclaredTypeText,
      'Set type text should be captured.');
    AContext.AssertEquals('file of Byte',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'F').DeclaredTypeText,
      'File type text should be captured.');
    AContext.AssertEquals('^Integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'P').DeclaredTypeText,
      'Pointer type text should be captured.');
    AContext.AssertEquals('procedure(AValue: Integer)',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'Callback').DeclaredTypeText,
      'Procedure variable type text should be captured.');
    AContext.AssertEquals('function(const AName: string): Integer',
      NXPassrcFindSymbol(lSymbols, pskVariable, 'Getter').DeclaredTypeText,
      'Function variable type text should be captured.');
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
      '  TMethodProc = procedure of object;' + LineEnding +
      '  TMethodProcArg = procedure(A: Integer) of object;' + LineEnding +
      '  TMethodFunc = function: Integer of object;' + LineEnding +
      '  TMethodFuncArg = function(A: Integer): Integer of object;' + LineEnding +
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
    AContext.AssertEquals('procedure of object',
      NXPassrcFindSymbol(lSymbols, pskType, 'TMethodProc').DeclaredTypeText,
      'Procedure of object type declared text should be captured.');
    AContext.AssertEquals('procedure(A: Integer) of object',
      NXPassrcFindSymbol(lSymbols, pskType, 'TMethodProcArg').DeclaredTypeText,
      'Procedure of object type with arguments should be captured.');
    AContext.AssertEquals('function: Integer of object',
      NXPassrcFindSymbol(lSymbols, pskType, 'TMethodFunc').DeclaredTypeText,
      'Function of object type declared text should be captured.');
    AContext.AssertEquals('function(A: Integer): Integer of object',
      NXPassrcFindSymbol(lSymbols, pskType, 'TMethodFuncArg').DeclaredTypeText,
      'Function of object type with arguments should be captured.');
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
  lSuite.AddTest('ScannerTokenSeriesAndDirectives',
    @TestScannerTokenSeriesAndDirectives);
  lSuite.AddTest('ScannerBOM', @TestScannerBOM);
  lSuite.AddTest('ScannerUnterminatedDiagnostics',
    @TestScannerUnterminatedDiagnostics);
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
  lSuite.AddTest('StructuredTypeHeritageConstructorsProperties',
    @TestStructuredTypeHeritageConstructorsProperties);
  lSuite.AddTest('ClassFieldMethodStructuralVariants',
    @TestClassFieldMethodStructuralVariants);
  lSuite.AddTest('PropertyInterfaceAndRecordStructuralVariants',
    @TestPropertyInterfaceAndRecordStructuralVariants);
  lSuite.AddTest('ProcedureFunctionDeclarations',
    @TestProcedureFunctionDeclarations);
  lSuite.AddTest('ProcedureParameterModes', @TestProcedureParameterModes);
  lSuite.AddTest('ProcedureAdvancedParameterForms',
    @TestProcedureAdvancedParameterForms);
  lSuite.AddTest('ProcedureModifiersAndDefaults',
    @TestProcedureModifiersAndDefaults);
  lSuite.AddTest('ProcedureAdditionalDirectives',
    @TestProcedureAdditionalDirectives);
  lSuite.AddTest('LocalRoutineVarAndConstDeclarations',
    @TestLocalRoutineVarAndConstDeclarations);
  lSuite.AddTest('ConstAndVarDeclarations', @TestConstAndVarDeclarations);
  lSuite.AddTest('ConstTypedAndLiteralDeclarations',
    @TestConstTypedAndLiteralDeclarations);
  lSuite.AddTest('ConstAdvancedStructuralDeclarations',
    @TestConstAdvancedStructuralDeclarations);
  lSuite.AddTest('VarStructuralDeclarations', @TestVarStructuralDeclarations);
  lSuite.AddTest('VarModifierStructuralDeclarations',
    @TestVarModifierStructuralDeclarations);
  lSuite.AddTest('InlineAnonymousTypeDeclarations',
    @TestInlineAnonymousTypeDeclarations);
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
