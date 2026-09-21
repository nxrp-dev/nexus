unit obNXPasLexer;

{$mode objfpc}{$H+}

interface

uses
  obNXPasDiagnostics,
  obNXPasSource,
  tpNXPasTokens;

type
  TNXPasLexer = class
  private
    FDiagnostics: TNXPasDiagnosticList;
    FSource: string;
    FOffset: Integer;
    FLine: Integer;
    FColumn: Integer;
    function CurrentChar: Char;
    function PeekChar(AOffset: Integer): Char;
    function CurrentPosition: TNXPasSourcePosition;
    function IsAtEnd: Boolean;
    function IsIdentStart(AChar: Char): Boolean;
    function IsIdentChar(AChar: Char): Boolean;
    function KeywordKindOf(const AText: string): TNXPasKeywordKind;
    procedure Advance;
    procedure AddDiagnostic(const ACode, AMessage: string;
      const AStartPos, AEndPos: TNXPasSourcePosition);
    procedure CaptureToken(AKind: TNXPasTokenKind; const AStart: TNXPasSourcePosition;
      AStartOffset: Integer; out AToken: TNXPasToken;
      AKeyword: TNXPasKeywordKind = pkwNone;
      ASymbol: TNXPasTokenSymbolKind = psyNone);
    function ReadBraceComment(out AToken: TNXPasToken): Boolean;
    function ReadParenComment(out AToken: TNXPasToken): Boolean;
    function ReadSlashComment(out AToken: TNXPasToken): Boolean;
    function ReadCharLiteral(out AToken: TNXPasToken): Boolean;
    function ReadBOM(out AToken: TNXPasToken): Boolean;
    function ReadEscapedIdentifier(out AToken: TNXPasToken): Boolean;
    function ReadIdentifier(out AToken: TNXPasToken): Boolean;
    function ReadNumber(out AToken: TNXPasToken): Boolean;
    function ReadString(out AToken: TNXPasToken): Boolean;
    function ReadSymbol(out AToken: TNXPasToken): Boolean;
    function ReadWhitespace(out AToken: TNXPasToken): Boolean;
  public
    constructor Create(const ASource: string;
      ADiagnostics: TNXPasDiagnosticList = nil);
    function NextToken: TNXPasToken;
    property SourceText: string read FSource;
  end;

implementation

uses
  SysUtils,
  obNXFastPascal;

constructor TNXPasLexer.Create(const ASource: string;
  ADiagnostics: TNXPasDiagnosticList);
begin
  inherited Create;
  FDiagnostics := ADiagnostics;
  FSource := ASource;
  FOffset := 1;
  FLine := 0;
  FColumn := 0;
end;

procedure TNXPasLexer.AddDiagnostic(const ACode, AMessage: string;
  const AStartPos, AEndPos: TNXPasSourcePosition);
var
  lRange: TNXPasSourceRange;
begin
  if FDiagnostics = nil then
    Exit;

  lRange.StartPos := AStartPos;
  lRange.EndPos := AEndPos;
  FDiagnostics.AddDiagnostic(pdsError, AMessage, lRange, ACode);
end;

function TNXPasLexer.CurrentChar: Char;
begin
  Result := PeekChar(0);
end;

function TNXPasLexer.PeekChar(AOffset: Integer): Char;
var
  lOffset: Integer;
begin
  lOffset := FOffset + AOffset;
  if (lOffset < 1) or (lOffset > Length(FSource)) then
    Result := #0
  else
    Result := FSource[lOffset];
end;

function TNXPasLexer.CurrentPosition: TNXPasSourcePosition;
begin
  Result.Offset := FOffset;
  Result.Line := FLine;
  Result.Column := FColumn;
end;

function TNXPasLexer.IsAtEnd: Boolean;
begin
  Result := FOffset > Length(FSource);
end;

function TNXPasLexer.IsIdentStart(AChar: Char): Boolean;
begin
  Result := AChar in ['A'..'Z', 'a'..'z', '_'];
end;

function TNXPasLexer.IsIdentChar(AChar: Char): Boolean;
begin
  Result := IsIdentStart(AChar) or (AChar in ['0'..'9']);
end;

function TNXPasLexer.KeywordKindOf(const AText: string): TNXPasKeywordKind;
begin
  if not TNXPascalKeywordSet.TryKindOf(AText, Result) then
    Result := pkwNone;
end;

procedure TNXPasLexer.Advance;
begin
  if IsAtEnd then
    Exit;

  if FSource[FOffset] = #13 then
  begin
    Inc(FOffset);
    if (FOffset <= Length(FSource)) and (FSource[FOffset] = #10) then
      Inc(FOffset);
    Inc(FLine);
    FColumn := 0;
    Exit;
  end;

  if FSource[FOffset] = #10 then
  begin
    Inc(FOffset);
    Inc(FLine);
    FColumn := 0;
    Exit;
  end;

  Inc(FOffset);
  Inc(FColumn);
end;

procedure TNXPasLexer.CaptureToken(AKind: TNXPasTokenKind;
  const AStart: TNXPasSourcePosition; AStartOffset: Integer;
  out AToken: TNXPasToken; AKeyword: TNXPasKeywordKind;
  ASymbol: TNXPasTokenSymbolKind);
begin
  NXPasClearToken(AToken);
  AToken.Kind := AKind;
  AToken.Keyword := AKeyword;
  AToken.Symbol := ASymbol;
  AToken.StartPos := AStart;
  AToken.EndPos := CurrentPosition;
  AToken.StartOffset := AStartOffset;
  AToken.EndOffset := FOffset;
end;

function TNXPasLexer.ReadWhitespace(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := CurrentChar in [#1..#32];
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  while CurrentChar in [#1..#32] do
    Advance;
  CaptureToken(ptkWhitespace, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.ReadBOM(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := (FOffset = 1) and (PeekChar(0) = #$EF) and
    (PeekChar(1) = #$BB) and (PeekChar(2) = #$BF);
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  Advance;
  Advance;
  Advance;
  CaptureToken(ptkWhitespace, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.ReadEscapedIdentifier(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := (CurrentChar = '&') and IsIdentStart(PeekChar(1));
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  Advance;
  while IsIdentChar(CurrentChar) do
    Advance;
  CaptureToken(ptkIdentifier, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.ReadIdentifier(out AToken: TNXPasToken): Boolean;
var
  lKeyword: TNXPasKeywordKind;
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := IsIdentStart(CurrentChar);
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  while IsIdentChar(CurrentChar) do
    Advance;

  lKeyword := KeywordKindOf(Copy(FSource, lStartOffset, FOffset - lStartOffset));
  if lKeyword <> pkwNone then
    CaptureToken(ptkKeyword, lStart, lStartOffset, AToken, lKeyword)
  else
    CaptureToken(ptkIdentifier, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.ReadNumber(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := (CurrentChar in ['0'..'9']) or
    ((CurrentChar = '$') and (PeekChar(1) in ['0'..'9', 'A'..'F', 'a'..'f']));
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;

  if CurrentChar = '$' then
  begin
    Advance;
    while CurrentChar in ['0'..'9', 'A'..'F', 'a'..'f'] do
      Advance;
  end
  else
  begin
    while CurrentChar in ['0'..'9'] do
      Advance;
    if (CurrentChar = '.') and (PeekChar(1) <> '.') then
    begin
      Advance;
      while CurrentChar in ['0'..'9'] do
        Advance;
    end;
    if CurrentChar in ['E', 'e'] then
    begin
      Advance;
      if CurrentChar in ['+', '-'] then
        Advance;
      while CurrentChar in ['0'..'9'] do
        Advance;
    end;
  end;

  CaptureToken(ptkNumber, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.ReadString(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
  lTerminated: Boolean;
begin
  Result := CurrentChar = '''';
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  lTerminated := False;
  Advance;
  while not IsAtEnd do
  begin
    if CurrentChar <> '''' then
    begin
      Advance;
      Continue;
    end;

    Advance;
    if CurrentChar = '''' then
      Advance
    else
    begin
      lTerminated := True;
      Break;
    end;
  end;

  CaptureToken(ptkString, lStart, lStartOffset, AToken);
  if not lTerminated then
    AddDiagnostic('nxpas.unterminatedString',
      'Unterminated string literal.', lStart, AToken.EndPos);
end;

function TNXPasLexer.ReadBraceComment(out AToken: TNXPasToken): Boolean;
var
  lDepth: Integer;
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
  lKind: TNXPasTokenKind;
  lTerminated: Boolean;
begin
  Result := CurrentChar = '{';
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  if PeekChar(1) = '$' then
    lKind := ptkDirective
  else
    lKind := ptkComment;
  lTerminated := False;
  lDepth := 1;

  Advance;
  while not IsAtEnd do
  begin
    if CurrentChar = '{' then
      Inc(lDepth)
    else if CurrentChar = '}' then
    begin
      Dec(lDepth);
      if lDepth = 0 then
      begin
        lTerminated := True;
        Advance;
        Break;
      end;
    end;
    Advance;
  end;

  CaptureToken(lKind, lStart, lStartOffset, AToken);
  if not lTerminated then
    AddDiagnostic('nxpas.unterminatedBraceComment',
      'Unterminated brace comment.', lStart, AToken.EndPos);
end;

function TNXPasLexer.ReadParenComment(out AToken: TNXPasToken): Boolean;
var
  lDepth: Integer;
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
  lKind: TNXPasTokenKind;
  lTerminated: Boolean;
begin
  Result := (CurrentChar = '(') and (PeekChar(1) = '*');
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  if PeekChar(2) = '$' then
    lKind := ptkDirective
  else
    lKind := ptkComment;
  lTerminated := False;
  lDepth := 1;

  Advance;
  Advance;
  while not IsAtEnd do
  begin
    if (CurrentChar = '(') and (PeekChar(1) = '*') then
    begin
      Advance;
      Advance;
      Inc(lDepth);
      Continue;
    end
    else if (CurrentChar = '*') and (PeekChar(1) = ')') then
    begin
      Advance;
      Advance;
      Dec(lDepth);
      if lDepth = 0 then
      begin
        lTerminated := True;
        Break;
      end;
      Continue;
    end;
    Advance;
  end;

  CaptureToken(lKind, lStart, lStartOffset, AToken);
  if not lTerminated then
    AddDiagnostic('nxpas.unterminatedParenStarComment',
      'Unterminated paren-star comment.', lStart, AToken.EndPos);
end;

function TNXPasLexer.ReadSlashComment(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := (CurrentChar = '/') and (PeekChar(1) = '/');
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  while (not IsAtEnd) and not (CurrentChar in [#10, #13]) do
    Advance;
  CaptureToken(ptkComment, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.ReadCharLiteral(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := CurrentChar = '#';
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;

  while CurrentChar = '#' do
  begin
    Advance;
    if CurrentChar = '$' then
    begin
      Advance;
      while CurrentChar in ['0'..'9', 'A'..'F', 'a'..'f'] do
        Advance;
    end
    else
      while CurrentChar in ['0'..'9'] do
        Advance;
  end;

  CaptureToken(ptkString, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.ReadSymbol(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
  lSymbol: TNXPasTokenSymbolKind;
begin
  Result := not IsAtEnd;
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;
  lSymbol := psyUnknown;

  case CurrentChar of
    ':':
      begin
        Advance;
        if CurrentChar = '=' then
        begin
          Advance;
          lSymbol := psyAssign;
        end
        else
          lSymbol := psyColon;
      end;
    '.':
      begin
        Advance;
        if CurrentChar = '.' then
        begin
          Advance;
          lSymbol := psyDotDot;
        end
        else
          lSymbol := psyDot;
      end;
    '<':
      begin
        Advance;
        if CurrentChar = '=' then
        begin
          Advance;
          lSymbol := psyLessEqual;
        end
        else if CurrentChar = '>' then
        begin
          Advance;
          lSymbol := psyNotEqual;
        end
        else
          lSymbol := psyLess;
      end;
    '>':
      begin
        Advance;
        if CurrentChar = '=' then
        begin
          Advance;
          lSymbol := psyGreaterEqual;
        end
        else
          lSymbol := psyGreater;
      end;
    '+':
      begin
        Advance;
        lSymbol := psyPlus;
      end;
    '-':
      begin
        Advance;
        lSymbol := psyMinus;
      end;
    '*':
      begin
        Advance;
        lSymbol := psyStar;
      end;
    '/':
      begin
        Advance;
        lSymbol := psySlash;
      end;
    '=':
      begin
        Advance;
        lSymbol := psyEquals;
      end;
    ';':
      begin
        Advance;
        lSymbol := psySemicolon;
      end;
    ',':
      begin
        Advance;
        lSymbol := psyComma;
      end;
    '(':
      begin
        Advance;
        lSymbol := psyOpenParen;
      end;
    ')':
      begin
        Advance;
        lSymbol := psyCloseParen;
      end;
    '[':
      begin
        Advance;
        lSymbol := psyOpenBracket;
      end;
    ']':
      begin
        Advance;
        lSymbol := psyCloseBracket;
      end;
    '{':
      begin
        Advance;
        lSymbol := psyOpenBrace;
      end;
    '}':
      begin
        Advance;
        lSymbol := psyCloseBrace;
      end;
    '^':
      begin
        Advance;
        lSymbol := psyCaret;
      end;
    '@':
      begin
        Advance;
        lSymbol := psyAt;
      end;
  else
    Advance;
  end;

  CaptureToken(ptkSymbol, lStart, lStartOffset, AToken, pkwNone, lSymbol);
end;

function TNXPasLexer.NextToken: TNXPasToken;
var
  lStart: TNXPasSourcePosition;
begin
  if IsAtEnd then
  begin
    NXPasClearToken(Result);
    lStart := CurrentPosition;
    Result.Kind := ptkEndOfFile;
    Result.StartPos := lStart;
    Result.EndPos := lStart;
    Result.StartOffset := FOffset;
    Result.EndOffset := FOffset;
    Exit;
  end;

  if ReadWhitespace(Result) then
    Exit;
  if ReadBOM(Result) then
    Exit;
  if ReadSlashComment(Result) then
    Exit;
  if ReadBraceComment(Result) then
    Exit;
  if ReadParenComment(Result) then
    Exit;
  if ReadEscapedIdentifier(Result) then
    Exit;
  if ReadIdentifier(Result) then
    Exit;
  if ReadNumber(Result) then
    Exit;
  if ReadString(Result) then
    Exit;
  if ReadCharLiteral(Result) then
    Exit;
  ReadSymbol(Result);
end;

end.

