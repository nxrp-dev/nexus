unit tsNXPasLexerTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasLexerTests(ARegistry: TNXTestRegistry);

implementation

uses
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
    AContext.AssertEquals('unit', lToken.Text, 'First token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkIdentifier), Ord(lToken.Kind),
      'Sample should lex as an identifier.');
    AContext.AssertEquals('Sample', lToken.Text,
      'Identifier token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkSymbol), Ord(lToken.Kind),
      'Semicolon should lex as a symbol.');
    AContext.AssertEquals(';', lToken.Text, 'Symbol token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkKeyword), Ord(lToken.Kind),
      'interface should lex as a keyword.');
    AContext.AssertEquals(1, lToken.StartPos.Line,
      'Line should advance across line endings.');
  finally
    lLexer.Free;
  end;
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
    AContext.AssertEquals('unit', lToken.Text,
      'Keyword token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkIdentifier), Ord(lToken.Kind),
      'Sample should lex as an identifier.');
    AContext.AssertEquals('Sample', lToken.Text,
      'Identifier token text should not lose its first character.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkSymbol), Ord(lToken.Kind),
      'Semicolon should be preserved as its own token.');
    AContext.AssertEquals(';', lToken.Text,
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
    AContext.AssertEquals('procedure', lToken.Text,
      'Keyword token text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkIdentifier), Ord(lToken.Kind),
      'Test should lex as an identifier.');
    AContext.AssertEquals('Test', lToken.Text,
      'Identifier token text should not consume adjacent punctuation.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkSymbol), Ord(lToken.Kind),
      'Semicolon should be preserved as its own token.');
    AContext.AssertEquals(';', lToken.Text,
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
    AContext.AssertEquals('{$mode objfpc}', lToken.Text,
      'Directive text should include braces.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkDirective), Ord(lToken.Kind),
      'Second directive should be recognized.');
    AContext.AssertEquals('{$H+}', lToken.Text,
      'Second directive text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkComment), Ord(lToken.Kind),
      'Line comment should be a comment token.');
    AContext.AssertEquals('// tail', lToken.Text,
      'Line comment should stop before line ending.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkComment), Ord(lToken.Kind),
      'Paren-star comment should be a comment token.');
    AContext.AssertEquals('(* block *)', lToken.Text,
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
    AContext.AssertEquals(':=', lToken.Text,
      'Assignment operator should be one token.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkString), Ord(lToken.Kind),
      'Quoted literal should be a string token.');
    AContext.AssertEquals('''don''''t''', lToken.Text,
      'String token should preserve doubled quotes.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(';', lToken.Text, 'Semicolon should be separate.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals('Value', lToken.Text, 'Next identifier should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(':=', lToken.Text,
      'Second assignment operator should be one token.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkNumber), Ord(lToken.Kind),
      'Hex literal should be a number token.');
    AContext.AssertEquals('$2A', lToken.Text, 'Hex literal text should match.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals('..', lToken.Text, 'Range operator should be one token.');

    lToken := NXPasNextNonWhitespace(lLexer);
    AContext.AssertEquals(Ord(ptkNumber), Ord(lToken.Kind),
      'Decimal literal should be a number token.');
    AContext.AssertEquals('100', lToken.Text,
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
    AContext.AssertEquals('unit', lStream.Current.Text,
      'Current token should start at unit.');

    lToken := lStream.Peek(1);
    AContext.AssertEquals('Sample', lToken.Text,
      'Peek(1) should return the next significant token.');

    lToken := lStream.Peek(2);
    AContext.AssertEquals(';', lToken.Text,
      'Peek(2) should return the second significant token.');

    AContext.AssertEquals('unit', lStream.Current.Text,
      'Peek should not advance Current.');

    lStream.Next;
    AContext.AssertEquals('Sample', lStream.Current.Text,
      'Next should consume the buffered first peek token.');

    lStream.Next;
    AContext.AssertEquals(';', lStream.Current.Text,
      'Next should consume the buffered second peek token.');

    AContext.AssertTrue(lStream.CheckPeek(1, ptkKeyword, 'interface'),
      'CheckPeek should inspect the next significant token.');
    AContext.AssertEquals(';', lStream.Current.Text,
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
