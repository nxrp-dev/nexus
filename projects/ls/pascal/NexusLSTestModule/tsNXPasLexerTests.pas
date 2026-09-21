unit tsNXPasLexerTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasLexerTests(ARegistry: TNXTestRegistry);

implementation

uses
  obNXFastPascal,
  obNXPasDiagnostics,
  obNXPasLexer,
  obNXPasTokenStream,
  obNXTestContext,
  obNXTestSuite,
  tpNXPasTokens;

function NXPasNextNonWhitespace(ALexer: TNXPasLexer): TNXPasToken;
begin
  repeat
    Result := ALexer.NextToken;
  until Result.Kind <> ptkWhitespace;
end;

function NXPasLexerHasDiagnostic(ADiagnostics: TNXPasDiagnosticList;
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

procedure NXPasDrainLexer(ALexer: TNXPasLexer);
var
  lToken: TNXPasToken;
begin
  repeat
    lToken := ALexer.NextToken;
  until lToken.Kind = ptkEndOfFile;
end;

procedure TestLexesUnitHeader(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('unit Sample;' + LineEnding + 'interface');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'unit should lex as a keyword.');
    AContext.AssertEquals(Ord(pkwUnit), Ord(lToken.Keyword),
      'unit should carry the unit keyword classification.');
    AContext.AssertEquals('unit', lToken.Text(lLexer.SourceText), 'First token text should match.');
    AContext.AssertEquals(1, lToken.StartOffset,
      'Token should capture its starting source offset.');
    AContext.AssertEquals(5, lToken.EndOffset,
      'Token should capture its ending source offset.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkIdentifier), Ord(lToken.Kind),
      'Sample should lex as an identifier.');
    AContext.AssertEquals('Sample', lToken.Text(lLexer.SourceText),
      'Identifier token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkSymbol), Ord(lToken.Kind),
      'Semicolon should lex as a symbol.');
    AContext.AssertEquals(Ord(psySemicolon), Ord(lToken.Symbol),
      'Semicolon should carry the semicolon symbol classification.');
    AContext.AssertEquals(';', lToken.Text(lLexer.SourceText), 'Symbol token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'interface should lex as a keyword.');
    AContext.AssertEquals(1, lToken.StartPos.Line,
      'Line should advance across line endings.');
  finally
    lLexer.Free;
  end;
end;

procedure TestKeywordClassificationPreservesSourceSpelling(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('ImPlEmEnTaTiOn');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'Mixed-case implementation should lex as a keyword.');
    AContext.AssertEquals(Ord(pkwImplementation), Ord(lToken.Keyword),
      'Mixed-case implementation should have normalized keyword identity.');
    AContext.AssertEquals('ImPlEmEnTaTiOn', lToken.Text(lLexer.SourceText),
      'Token text materialization should preserve source spelling.');
  finally
    lLexer.Free;
  end;
end;

procedure TestLexesOnlyKnownMultiCharacterSymbols(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create(':= .. <= >= <>');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyAssign), Ord(lToken.Symbol),
      'Assignment should be a classified two-character symbol.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyDotDot), Ord(lToken.Symbol),
      'Range should be a classified two-character symbol.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyLessEqual), Ord(lToken.Symbol),
      'Less-equal should be a classified two-character symbol.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyGreaterEqual), Ord(lToken.Symbol),
      'Greater-equal should be a classified two-character symbol.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyNotEqual), Ord(lToken.Symbol),
      'Not-equal should be a classified two-character symbol.');
  finally
    lLexer.Free;
  end;
end;

procedure TestInvalidSymbolPairsDoNotSwallowNextToken(
  AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('+. .*');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyPlus), Ord(lToken.Symbol),
      'Plus should remain a single symbol before dot.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyDot), Ord(lToken.Symbol),
      'Dot should not be swallowed by the preceding plus.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyDot), Ord(lToken.Symbol),
      'Dot should remain a single symbol before star.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(psyStar), Ord(lToken.Symbol),
      'Star should not be swallowed by the preceding dot.');
  finally
    lLexer.Free;
  end;
end;

procedure TestFastPascalContextualSetsReturnMirroredKinds(
  AContext: TNXTestContext);
var
  lDeclarationTailKind: TNXPasDeclarationTailKind;
  lDirectiveKind: TNXPasRoutineDirectiveKind;
  lIndex: Integer;
  lKeywordKind: TNXPasKeywordKind;
  lParameterModifierKind: TNXPasParameterModifierKind;
  lPropertySpecifierKind: TNXPasPropertySpecifierKind;
begin
  AContext.AssertTrue(TNXPascalKeywordSet.TryIndexOf('IMPLEMENTATION',
    lIndex), 'Keyword set lookup should be case-insensitive.');
  AContext.AssertEquals(30, lIndex,
    'Keyword index should return the original word-array position.');
  AContext.AssertTrue(TNXPascalKeywordSet.TryKindOf('IMPLEMENTATION',
    lKeywordKind), 'Keyword set should return a mirrored keyword kind.');
  AContext.AssertEquals(Ord(pkwImplementation), Ord(lKeywordKind),
    'Keyword kind should mirror the keyword word array.');

  AContext.AssertTrue(TNXPascalRoutineDirectiveSet.TryKindOf('STATIC',
    lDirectiveKind), 'Routine directive lookup should be case-insensitive.');
  AContext.AssertEquals(Ord(prdStatic), Ord(lDirectiveKind),
    'Routine directive kind should mirror the directive word array.');

  AContext.AssertTrue(TNXPascalDeclarationTailKeywordSet.TryKindOf('external',
    lDeclarationTailKind),
    'Declaration-tail lookup should return a mirrored kind.');
  AContext.AssertEquals(Ord(pdtExternal), Ord(lDeclarationTailKind),
    'Declaration-tail kind should mirror the tail word array.');

  AContext.AssertTrue(TNXPascalPropertySpecifierSet.TryKindOf('Nodefault',
    lPropertySpecifierKind),
    'Property specifier lookup should be case-insensitive.');
  AContext.AssertEquals(Ord(ppsNodefault), Ord(lPropertySpecifierKind),
    'Property specifier kind should mirror the specifier word array.');

  AContext.AssertTrue(TNXPascalParameterModifierSet.TryKindOf('CONSTREF',
    lParameterModifierKind),
    'Parameter modifier lookup should be case-insensitive.');
  AContext.AssertEquals(Ord(ppmConstref), Ord(lParameterModifierKind),
    'Parameter modifier kind should mirror the modifier word array.');
end;

procedure TestIdentifierBoundaryBeforeEOF(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('unit Sample;');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'unit should lex as a keyword.');
    AContext.AssertEquals('unit', lToken.Text(lLexer.SourceText),
      'Keyword token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkIdentifier), Ord(lToken.Kind),
      'Sample should lex as an identifier.');
    AContext.AssertEquals('Sample', lToken.Text(lLexer.SourceText),
      'Identifier token text should not lose its first character.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkSymbol), Ord(lToken.Kind),
      'Semicolon should be preserved as its own token.');
    AContext.AssertEquals(';', lToken.Text(lLexer.SourceText),
      'Semicolon token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkEndOfFile), Ord(lToken.Kind),
      'Lexer should reach EOF after the semicolon.');
  finally
    lLexer.Free;
  end;
end;

procedure TestProcedureIdentifierBoundary(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('procedure Test;');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'procedure should lex as a keyword.');
    AContext.AssertEquals('procedure', lToken.Text(lLexer.SourceText),
      'Keyword token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkIdentifier), Ord(lToken.Kind),
      'Test should lex as an identifier.');
    AContext.AssertEquals('Test', lToken.Text(lLexer.SourceText),
      'Identifier token text should not consume adjacent punctuation.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkSymbol), Ord(lToken.Kind),
      'Semicolon should be preserved as its own token.');
    AContext.AssertEquals(';', lToken.Text(lLexer.SourceText),
      'Semicolon token text should match.');
  finally
    lLexer.Free;
  end;
end;

procedure TestLexesCommentsAndDirectives(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('{$mode objfpc}{$H+} // tail' + LineEnding +
    '(* block *)');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkDirective), Ord(lToken.Kind),
      'Compiler directive should have a distinct token kind.');
    AContext.AssertEquals('{$mode objfpc}', lToken.Text(lLexer.SourceText),
      'Directive text should include braces.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkDirective), Ord(lToken.Kind),
      'Second directive should be recognized.');
    AContext.AssertEquals('{$H+}', lToken.Text(lLexer.SourceText),
      'Second directive text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkComment), Ord(lToken.Kind),
      'Line comment should be a comment token.');
    AContext.AssertEquals('// tail', lToken.Text(lLexer.SourceText),
      'Line comment should stop before line ending.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkComment), Ord(lToken.Kind),
      'Paren-star comment should be a comment token.');
    AContext.AssertEquals('(* block *)', lToken.Text(lLexer.SourceText),
      'Paren-star comment text should match.');
  finally
    lLexer.Free;
  end;
end;

procedure TestLexesStringsNumbersAndOperators(AContext: TNXTestContext);
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  lLexer := TNXPasLexer.Create('Name := ''don''''t''; Value := $2A..100');
  try
    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkIdentifier), Ord(lToken.Kind),
      'Name should be an identifier.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(':=', lToken.Text(lLexer.SourceText),
      'Assignment operator should be one token.');
    AContext.AssertEquals(Ord(psyAssign), Ord(lToken.Symbol),
      'Assignment operator should carry assignment symbol classification.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkString), Ord(lToken.Kind),
      'Quoted literal should be a string token.');
    AContext.AssertEquals('''don''''t''', lToken.Text(lLexer.SourceText),
      'String token should preserve doubled quotes.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(';', lToken.Text(lLexer.SourceText), 'Semicolon should be separate.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals('Value', lToken.Text(lLexer.SourceText), 'Next identifier should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(':=', lToken.Text(lLexer.SourceText),
      'Second assignment operator should be one token.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkNumber), Ord(lToken.Kind),
      'Hex literal should be a number token.');
    AContext.AssertEquals('$2A', lToken.Text(lLexer.SourceText), 'Hex literal text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals('..', lToken.Text(lLexer.SourceText), 'Range operator should be one token.');
    AContext.AssertEquals(Ord(psyDotDot), Ord(lToken.Symbol),
      'Range operator should carry dot-dot symbol classification.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkNumber), Ord(lToken.Kind),
      'Decimal literal should be a number token.');
    AContext.AssertEquals('100', lToken.Text(lLexer.SourceText),
      'Decimal literal text should match.');
  finally
    lLexer.Free;
  end;
end;

procedure TestUnterminatedStringDiagnostic(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lLexer: TNXPasLexer;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lLexer := TNXPasLexer.Create('Name := ''broken', lDiagnostics);
  try
    NXPasDrainLexer(lLexer);
    AContext.AssertTrue(NXPasLexerHasDiagnostic(lDiagnostics,
      'nxpas.unterminatedString'),
      'Lexer should diagnose unterminated string literals.');
    AContext.AssertEquals(0, lDiagnostics.DiagnosticAt(0).Range.StartPos.Line,
      'String diagnostic should point near the malformed literal.');
  finally
    lLexer.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestUnterminatedBraceCommentDiagnostic(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lLexer: TNXPasLexer;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lLexer := TNXPasLexer.Create('{ broken', lDiagnostics);
  try
    NXPasDrainLexer(lLexer);
    AContext.AssertTrue(NXPasLexerHasDiagnostic(lDiagnostics,
      'nxpas.unterminatedBraceComment'),
      'Lexer should diagnose unterminated brace comments.');
    AContext.AssertEquals(0, lDiagnostics.DiagnosticAt(0).Range.StartPos.Line,
      'Brace comment diagnostic should point near the malformed comment.');
  finally
    lLexer.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestUnterminatedParenStarCommentDiagnostic(AContext: TNXTestContext);
var
  lDiagnostics: TNXPasDiagnosticList;
  lLexer: TNXPasLexer;
begin
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lLexer := TNXPasLexer.Create('(* broken', lDiagnostics);
  try
    NXPasDrainLexer(lLexer);
    AContext.AssertTrue(NXPasLexerHasDiagnostic(lDiagnostics,
      'nxpas.unterminatedParenStarComment'),
      'Lexer should diagnose unterminated paren-star comments.');
    AContext.AssertEquals(0, lDiagnostics.DiagnosticAt(0).Range.StartPos.Line,
      'Paren-star comment diagnostic should point near the malformed comment.');
  finally
    lLexer.Free;
    lDiagnostics.Free;
  end;
end;

procedure TestTokenStreamPeekDoesNotAdvance(AContext: TNXTestContext);
var
  lStream: TNXPasTokenStream;
  lToken: TNXPasToken;
begin
  lStream := TNXPasTokenStream.Create(TNXPasLexer.Create(
    'unit Sample;' + LineEnding + 'interface'), True);
  try
    AContext.AssertEquals('unit', lStream.CurrentText,
      'Current token should start at unit.');

    lToken := lStream.Peek(1);
    AContext.AssertEquals('Sample', lStream.TokenText(lToken),
      'Peek(1) should return the next significant token.');

    lToken := lStream.Peek(2);
    AContext.AssertEquals(';', lStream.TokenText(lToken),
      'Peek(2) should return the second significant token.');

    AContext.AssertEquals('unit', lStream.CurrentText,
      'Peek should not advance Current.');

    lStream.Next;
    AContext.AssertEquals('Sample', lStream.CurrentText,
      'Next should consume the buffered first peek token.');

    lStream.Next;
    AContext.AssertEquals(';', lStream.CurrentText,
      'Next should consume the buffered second peek token.');

    AContext.AssertTrue(lStream.CheckPeekKeyword(1, pkwInterface),
      'CheckPeek should inspect the next significant token.');
    AContext.AssertEquals(';', lStream.CurrentText,
      'CheckPeek should not advance Current.');
  finally
    lStream.Free;
  end;
end;

procedure RegisterNXPasLexerTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusPas.Lexer');
  lSuite.AddTest('LexesUnitHeader', @TestLexesUnitHeader);
  lSuite.AddTest('KeywordClassificationPreservesSourceSpelling',
    @TestKeywordClassificationPreservesSourceSpelling);
  lSuite.AddTest('LexesOnlyKnownMultiCharacterSymbols',
    @TestLexesOnlyKnownMultiCharacterSymbols);
  lSuite.AddTest('InvalidSymbolPairsDoNotSwallowNextToken',
    @TestInvalidSymbolPairsDoNotSwallowNextToken);
  lSuite.AddTest('FastPascalContextualSetsReturnMirroredKinds',
    @TestFastPascalContextualSetsReturnMirroredKinds);
  lSuite.AddTest('IdentifierBoundaryBeforeEOF',
    @TestIdentifierBoundaryBeforeEOF);
  lSuite.AddTest('ProcedureIdentifierBoundary',
    @TestProcedureIdentifierBoundary);
  lSuite.AddTest('LexesCommentsAndDirectives', @TestLexesCommentsAndDirectives);
  lSuite.AddTest('LexesStringsNumbersAndOperators',
    @TestLexesStringsNumbersAndOperators);
  lSuite.AddTest('UnterminatedStringDiagnostic',
    @TestUnterminatedStringDiagnostic);
  lSuite.AddTest('UnterminatedBraceCommentDiagnostic',
    @TestUnterminatedBraceCommentDiagnostic);
  lSuite.AddTest('UnterminatedParenStarCommentDiagnostic',
    @TestUnterminatedParenStarCommentDiagnostic);
  lSuite.AddTest('TokenStreamPeekDoesNotAdvance',
    @TestTokenStreamPeekDoesNotAdvance);
end;

end.

