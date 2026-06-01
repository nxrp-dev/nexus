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
    function IsKeyword(const AText: string): Boolean;
    procedure Advance;
    procedure AddDiagnostic(const ACode, AMessage: string;
      const AStartPos, AEndPos: TNXPasSourcePosition);
    procedure CaptureToken(AKind: TNXPasTokenKind; const AStart: TNXPasSourcePosition;
      AStartOffset: Integer; out AToken: TNXPasToken);
    function ReadBraceComment(out AToken: TNXPasToken): Boolean;
    function ReadParenComment(out AToken: TNXPasToken): Boolean;
    function ReadSlashComment(out AToken: TNXPasToken): Boolean;
    function ReadIdentifier(out AToken: TNXPasToken): Boolean;
    function ReadNumber(out AToken: TNXPasToken): Boolean;
    function ReadString(out AToken: TNXPasToken): Boolean;
    function ReadSymbol(out AToken: TNXPasToken): Boolean;
    function ReadWhitespace(out AToken: TNXPasToken): Boolean;
  public
    constructor Create(const ASource: string;
      ADiagnostics: TNXPasDiagnosticList = nil);
    function NextToken: TNXPasToken;
  end;

implementation

uses
  SysUtils;

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

function TNXPasLexer.IsKeyword(const AText: string): Boolean;
var
  lText: string;
begin
  lText := LowerCase(AText);
  Result := (lText = 'absolute') or (lText = 'and') or (lText = 'array') or (lText = 'as') or
    (lText = 'asm') or (lText = 'begin') or (lText = 'case') or
    (lText = 'class') or (lText = 'const') or (lText = 'constructor') or
    (lText = 'destructor') or (lText = 'dispinterface') or
    (lText = 'div') or (lText = 'do') or (lText = 'downto') or
    (lText = 'else') or (lText = 'end') or (lText = 'except') or
    (lText = 'exports') or (lText = 'file') or
    (lText = 'finalization') or (lText = 'finally') or (lText = 'for') or
    (lText = 'function') or (lText = 'generic') or (lText = 'goto') or (lText = 'if') or
    (lText = 'implementation') or (lText = 'in') or
    (lText = 'inherited') or (lText = 'initialization') or
    (lText = 'inline') or (lText = 'interface') or (lText = 'is') or
    (lText = 'label') or (lText = 'library') or (lText = 'mod') or
    (lText = 'nil') or (lText = 'not') or (lText = 'object') or
    (lText = 'of') or (lText = 'operator') or (lText = 'or') or
    (lText = 'out') or (lText = 'package') or (lText = 'packed') or (lText = 'private') or
    (lText = 'procedure') or (lText = 'program') or
    (lText = 'property') or (lText = 'protected') or
    (lText = 'public') or (lText = 'published') or (lText = 'raise') or
    (lText = 'record') or (lText = 'repeat') or
    (lText = 'resourcestring') or (lText = 'set') or (lText = 'shl') or
    (lText = 'shr') or (lText = 'string') or (lText = 'then') or
    (lText = 'threadvar') or (lText = 'to') or (lText = 'try') or
    (lText = 'type') or (lText = 'unit') or (lText = 'until') or
    (lText = 'uses') or (lText = 'var') or (lText = 'while') or
    (lText = 'with') or (lText = 'xor');
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
  out AToken: TNXPasToken);
begin
  AToken.Kind := AKind;
  AToken.Text := Copy(FSource, AStartOffset, FOffset - AStartOffset);
  AToken.StartPos := AStart;
  AToken.EndPos := CurrentPosition;
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

function TNXPasLexer.ReadIdentifier(out AToken: TNXPasToken): Boolean;
var
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

  if IsKeyword(Copy(FSource, lStartOffset, FOffset - lStartOffset)) then
    CaptureToken(ptkKeyword, lStart, lStartOffset, AToken)
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

  Advance;
  while (not IsAtEnd) and (CurrentChar <> '}') do
    Advance;
  if CurrentChar = '}' then
  begin
    lTerminated := True;
    Advance;
  end;

  CaptureToken(lKind, lStart, lStartOffset, AToken);
  if not lTerminated then
    AddDiagnostic('nxpas.unterminatedBraceComment',
      'Unterminated brace comment.', lStart, AToken.EndPos);
end;

function TNXPasLexer.ReadParenComment(out AToken: TNXPasToken): Boolean;
var
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

  Advance;
  Advance;
  while not IsAtEnd do
  begin
    if (CurrentChar = '*') and (PeekChar(1) = ')') then
    begin
      Advance;
      Advance;
      lTerminated := True;
      Break;
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

function TNXPasLexer.ReadSymbol(out AToken: TNXPasToken): Boolean;
var
  lStart: TNXPasSourcePosition;
  lStartOffset: Integer;
begin
  Result := not IsAtEnd;
  if not Result then
    Exit;

  lStart := CurrentPosition;
  lStartOffset := FOffset;

  case CurrentChar of
    ':':
      begin
        Advance;
        if CurrentChar = '=' then
          Advance;
      end;
    '.', '<', '>', '+', '-', '*', '/':
      begin
        Advance;
        if CurrentChar in ['=', '.', '>', '<', '*'] then
          Advance;
      end;
  else
    Advance;
  end;

  CaptureToken(ptkSymbol, lStart, lStartOffset, AToken);
end;

function TNXPasLexer.NextToken: TNXPasToken;
var
  lStart: TNXPasSourcePosition;
begin
  if IsAtEnd then
  begin
    lStart := CurrentPosition;
    Result.Kind := ptkEndOfFile;
    Result.Text := '';
    Result.StartPos := lStart;
    Result.EndPos := lStart;
    Exit;
  end;

  if ReadWhitespace(Result) then
    Exit;
  if ReadSlashComment(Result) then
    Exit;
  if ReadBraceComment(Result) then
    Exit;
  if ReadParenComment(Result) then
    Exit;
  if ReadIdentifier(Result) then
    Exit;
  if ReadNumber(Result) then
    Exit;
  if ReadString(Result) then
    Exit;
  ReadSymbol(Result);
end;

end.
