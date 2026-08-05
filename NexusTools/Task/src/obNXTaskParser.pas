unit obNXTaskParser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, obNXTaskModel, tpNXTask;

type
  TNXTaskTokenKind = (ttEOF, ttIdentifier, ttString, ttInteger, ttFloat,
    ttBoolean, ttLBrace, ttRBrace, ttLParen, ttRParen, ttLBracket, ttRBracket,
    ttLAngle, ttRAngle, ttColon, ttDot, ttComma);

  TNXTaskToken = record
    Kind: TNXTaskTokenKind;
    Text: string;
    Line: Integer;
    Column: Integer;
  end;

  TNXTaskParser = class
  private
    FFileName: string;
    FText: string;
    FIndex: Integer;
    FLine: Integer;
    FColumn: Integer;
    FToken: TNXTaskToken;
    FDocument: TNXTaskDocument;
    function CurrentChar: Char;
    function PeekChar: Char;
    function IsEOF: Boolean;
    procedure AdvanceChar;
    procedure SkipWhitespaceAndComments;
    function ReadIdentifier: TNXTaskToken;
    function ReadNumber: TNXTaskToken;
    function ReadString: TNXTaskToken;
    procedure NextToken;
    function RangeForToken(const AToken: TNXTaskToken): TNXTaskSourceRange;
    procedure AddError(const ACode, AMessage: string; const AToken: TNXTaskToken);
    function Accept(AKind: TNXTaskTokenKind): Boolean;
    function Expect(AKind: TNXTaskTokenKind; const AMessage: string): Boolean;
    function ParseNode: TNXTaskNode;
    procedure ParseTargets(ANode: TNXTaskNode);
    procedure ParseNodeBody(ANode: TNXTaskNode);
    function ParsePropertyOrChild(ANode: TNXTaskNode): Boolean;
    function ParseValue: TNXTaskValue;
    function ParseScalarReference(const AStartToken: TNXTaskToken): TNXTaskValue;
    function ParseNodeReference(const AStartToken: TNXTaskToken): TNXTaskNodeReference;
    function ParsePathUntil(AStop: TNXTaskTokenKind): string;
    function ParsePathAndProperty(AStop: TNXTaskTokenKind; out APath,
      APropertyName: string): Boolean;
  public
    function ParseFile(const AFileName: string): TNXTaskDocument;
    function ParseText(const AFileName, AText: string): TNXTaskDocument;
  end;

implementation

function TNXTaskParser.CurrentChar: Char;
begin
  if FIndex > Length(FText) then
    Result := #0
  else
    Result := FText[FIndex];
end;

function TNXTaskParser.PeekChar: Char;
begin
  if FIndex + 1 > Length(FText) then
    Result := #0
  else
    Result := FText[FIndex + 1];
end;

function TNXTaskParser.IsEOF: Boolean;
begin
  Result := FIndex > Length(FText);
end;

procedure TNXTaskParser.AdvanceChar;
begin
  if CurrentChar = #10 then
  begin
    Inc(FLine);
    FColumn := 1;
  end
  else
    Inc(FColumn);
  Inc(FIndex);
end;

procedure TNXTaskParser.SkipWhitespaceAndComments;
begin
  while not IsEOF do
  begin
    if CurrentChar in [' ', #9, #13, #10] then
      AdvanceChar
    else if (CurrentChar = '/') and (PeekChar = '/') then
    begin
      while (not IsEOF) and (CurrentChar <> #10) do
        AdvanceChar;
    end
    else
      Exit;
  end;
end;

function TNXTaskParser.ReadIdentifier: TNXTaskToken;
begin
  Result.Kind := ttIdentifier;
  Result.Line := FLine;
  Result.Column := FColumn;
  Result.Text := '';
  while CurrentChar in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-'] do
  begin
    Result.Text := Result.Text + CurrentChar;
    AdvanceChar;
  end;
  if (Result.Text = 'true') or (Result.Text = 'false') then
    Result.Kind := ttBoolean;
end;

function TNXTaskParser.ReadNumber: TNXTaskToken;
var
  lHasDot: Boolean;
begin
  Result.Kind := ttInteger;
  Result.Line := FLine;
  Result.Column := FColumn;
  Result.Text := '';
  lHasDot := False;
  if CurrentChar = '-' then
  begin
    Result.Text := Result.Text + CurrentChar;
    AdvanceChar;
  end;
  while CurrentChar in ['0'..'9', '.'] do
  begin
    if CurrentChar = '.' then
    begin
      if lHasDot then
        Break;
      lHasDot := True;
      Result.Kind := ttFloat;
    end;
    Result.Text := Result.Text + CurrentChar;
    AdvanceChar;
  end;
end;

function TNXTaskParser.ReadString: TNXTaskToken;
var
  lEscaped: Boolean;
begin
  Result.Kind := ttString;
  Result.Line := FLine;
  Result.Column := FColumn;
  Result.Text := '';
  lEscaped := False;
  AdvanceChar;
  while not IsEOF do
  begin
    if lEscaped then
    begin
      case CurrentChar of
        '"': Result.Text := Result.Text + '"';
        '\': Result.Text := Result.Text + '\';
        'n': Result.Text := Result.Text + LineEnding;
        't': Result.Text := Result.Text + #9;
      else
        Result.Text := Result.Text + '\' + CurrentChar;
      end;
      lEscaped := False;
    end
    else if CurrentChar = '\' then
      lEscaped := True
    else if CurrentChar = '"' then
    begin
      AdvanceChar;
      Exit;
    end
    else
      Result.Text := Result.Text + CurrentChar;
    AdvanceChar;
  end;
  AddError('NXTask.Parse.UnterminatedString', 'Unterminated string literal.', Result);
end;

procedure TNXTaskParser.NextToken;
begin
  SkipWhitespaceAndComments;
  FToken.Line := FLine;
  FToken.Column := FColumn;
  FToken.Text := CurrentChar;
  if IsEOF then
  begin
    FToken.Kind := ttEOF;
    FToken.Text := '';
    Exit;
  end;
  case CurrentChar of
    '{': begin FToken.Kind := ttLBrace; AdvanceChar; end;
    '}': begin FToken.Kind := ttRBrace; AdvanceChar; end;
    '(': begin FToken.Kind := ttLParen; AdvanceChar; end;
    ')': begin FToken.Kind := ttRParen; AdvanceChar; end;
    '[': begin FToken.Kind := ttLBracket; AdvanceChar; end;
    ']': begin FToken.Kind := ttRBracket; AdvanceChar; end;
    '<': begin FToken.Kind := ttLAngle; AdvanceChar; end;
    '>': begin FToken.Kind := ttRAngle; AdvanceChar; end;
    ':': begin FToken.Kind := ttColon; AdvanceChar; end;
    '.': begin FToken.Kind := ttDot; AdvanceChar; end;
    ',': begin FToken.Kind := ttComma; AdvanceChar; end;
    '"': FToken := ReadString;
    '-',
    '0'..'9': FToken := ReadNumber;
    'A'..'Z',
    'a'..'z',
    '_': FToken := ReadIdentifier;
  else
    AddError('NXTask.Parse.UnexpectedCharacter',
      'Unexpected character "' + CurrentChar + '".', FToken);
    AdvanceChar;
    NextToken;
  end;
end;

function TNXTaskParser.RangeForToken(const AToken: TNXTaskToken): TNXTaskSourceRange;
begin
  Result := TNXTaskSourceRange.Create(FFileName, AToken.Line, AToken.Column);
end;

procedure TNXTaskParser.AddError(const ACode, AMessage: string;
  const AToken: TNXTaskToken);
begin
  FDocument.Diagnostics.Add(tdsError, ACode, AMessage, RangeForToken(AToken));
end;

function TNXTaskParser.Accept(AKind: TNXTaskTokenKind): Boolean;
begin
  Result := FToken.Kind = AKind;
  if Result then
    NextToken;
end;

function TNXTaskParser.Expect(AKind: TNXTaskTokenKind; const AMessage: string): Boolean;
begin
  Result := Accept(AKind);
  if not Result then
    AddError('NXTask.Parse.ExpectedToken', AMessage, FToken);
end;

function TNXTaskParser.ParsePathUntil(AStop: TNXTaskTokenKind): string;
begin
  Result := '';
  while (FToken.Kind <> AStop) and (FToken.Kind <> ttEOF) do
  begin
    if not (FToken.Kind in [ttIdentifier, ttDot]) then
    begin
      AddError('NXTask.Parse.InvalidReferencePath', 'Invalid reference path.', FToken);
      Break;
    end;
    Result := Result + FToken.Text;
    NextToken;
  end;
end;

function TNXTaskParser.ParsePathAndProperty(AStop: TNXTaskTokenKind; out APath,
  APropertyName: string): Boolean;
var
  lFullPath: string;
  lDot: Integer;
begin
  lFullPath := ParsePathUntil(AStop);
  lDot := RPos('.', lFullPath);
  Result := lDot > 0;
  if Result then
  begin
    APath := Copy(lFullPath, 1, lDot - 1);
    APropertyName := Copy(lFullPath, lDot + 1, MaxInt);
  end
  else
  begin
    APath := lFullPath;
    APropertyName := '';
    AddError('NXTask.Parse.InvalidScalarReference',
      'Scalar reference must include a node path and property name.', FToken);
  end;
end;

function TNXTaskParser.ParseScalarReference(const AStartToken: TNXTaskToken): TNXTaskValue;
var
  lExternalFile: string;
  lPath: string;
  lPropertyName: string;
  lReference: TNXTaskReference;
begin
  lExternalFile := '';
  if FToken.Kind = ttString then
  begin
    lExternalFile := FToken.Text;
    NextToken;
    Expect(ttColon, 'Expected ":" after external filename.');
  end;
  ParsePathAndProperty(ttRBracket, lPath, lPropertyName);
  Expect(ttRBracket, 'Expected "]" after scalar reference.');
  lReference := TNXTaskReference.Create(lExternalFile, lPath, lPropertyName,
    RangeForToken(AStartToken), FFileName);
  Result := TNXTaskValue.CreateReference(lReference, RangeForToken(AStartToken));
end;

function TNXTaskParser.ParseNodeReference(const AStartToken: TNXTaskToken): TNXTaskNodeReference;
var
  lExternalFile: string;
  lPath: string;
  lReference: TNXTaskReference;
begin
  lExternalFile := '';
  if FToken.Kind = ttString then
  begin
    lExternalFile := FToken.Text;
    NextToken;
    Expect(ttColon, 'Expected ":" after external filename.');
  end;
  lPath := ParsePathUntil(ttRAngle);
  Expect(ttRAngle, 'Expected ">" after node reference.');
  lReference := TNXTaskReference.Create(lExternalFile, lPath, '',
    RangeForToken(AStartToken), FFileName);
  Result := TNXTaskNodeReference.Create(lReference);
end;

function TNXTaskParser.ParseValue: TNXTaskValue;
var
  lToken: TNXTaskToken;
  lInt: Int64;
  lFloat: Double;
  lSettings: TFormatSettings;
begin
  lToken := FToken;
  lSettings := DefaultFormatSettings;
  lSettings.DecimalSeparator := '.';
  case FToken.Kind of
    ttString,
    ttIdentifier:
      begin
        Result := TNXTaskValue.CreateString(FToken.Text, RangeForToken(lToken));
        NextToken;
      end;
    ttBoolean:
      begin
        Result := TNXTaskValue.CreateBoolean(FToken.Text = 'true', RangeForToken(lToken));
        NextToken;
      end;
    ttInteger:
      begin
        if not TryStrToInt64(FToken.Text, lInt) then
          AddError('NXTask.Parse.IntegerOverflow', 'Invalid or overflowing integer literal.', FToken);
        Result := TNXTaskValue.CreateInteger(lInt, RangeForToken(lToken));
        NextToken;
      end;
    ttFloat:
      begin
        if not TryStrToFloat(FToken.Text, lFloat, lSettings) then
          AddError('NXTask.Parse.InvalidFloat', 'Invalid floating-point literal.', FToken);
        Result := TNXTaskValue.CreateFloat(lFloat, RangeForToken(lToken));
        NextToken;
      end;
    ttLBracket:
      begin
        NextToken;
        Result := ParseScalarReference(lToken);
      end;
  else
    AddError('NXTask.Parse.ExpectedValue', 'Expected scalar value.', FToken);
    Result := TNXTaskValue.CreateString('', RangeForToken(lToken));
    NextToken;
  end;
end;

procedure TNXTaskParser.ParseTargets(ANode: TNXTaskNode);
begin
  if not Accept(ttLParen) then
    Exit;
  while (FToken.Kind <> ttRParen) and (FToken.Kind <> ttEOF) do
  begin
    if FToken.Kind <> ttIdentifier then
    begin
      AddError('NXTask.Parse.InvalidTarget', 'Expected target name.', FToken);
      Break;
    end;
    ANode.Targets.Add(FToken.Text);
    NextToken;
    if not Accept(ttComma) then
      Break;
  end;
  Expect(ttRParen, 'Expected ")" after target list.');
end;

function TNXTaskParser.ParsePropertyOrChild(ANode: TNXTaskNode): Boolean;
var
  lName: TNXTaskToken;
  lAction: TNXTaskToken;
  lNode: TNXTaskNode;
  lProperty: TNXTaskProperty;
begin
  Result := False;
  if FToken.Kind = ttLAngle then
  begin
    lName := FToken;
    NextToken;
    ANode.AddExpansion(ParseNodeReference(lName));
    Exit(True);
  end;
  if FToken.Kind <> ttIdentifier then
  begin
    AddError('NXTask.Parse.ExpectedDeclaration', 'Expected property or task declaration.', FToken);
    NextToken;
    Exit(False);
  end;
  lName := FToken;
  NextToken;
  if Accept(ttColon) then
  begin
    lProperty := TNXTaskProperty.Create(lName.Text, ParseValue, RangeForToken(lName), FFileName);
    ANode.AddProperty(lProperty);
    Exit(True);
  end;
  if FToken.Kind <> ttIdentifier then
  begin
    AddError('NXTask.Parse.ExpectedAction', 'Expected task action.', FToken);
    Exit(False);
  end;
  lAction := FToken;
  NextToken;
  lNode := TNXTaskNode.Create(lName.Text, lAction.Text, RangeForToken(lName), FFileName);
  ParseTargets(lNode);
  Expect(ttLBrace, 'Expected "{" to begin task body.');
  ParseNodeBody(lNode);
  ANode.AddChild(lNode);
  Result := True;
end;

procedure TNXTaskParser.ParseNodeBody(ANode: TNXTaskNode);
begin
  while (FToken.Kind <> ttRBrace) and (FToken.Kind <> ttEOF) do
    ParsePropertyOrChild(ANode);
  Expect(ttRBrace, 'Expected "}" to close task body.');
end;

function TNXTaskParser.ParseNode: TNXTaskNode;
var
  lName: TNXTaskToken;
  lAction: TNXTaskToken;
begin
  Result := nil;
  if FToken.Kind <> ttIdentifier then
  begin
    AddError('NXTask.Parse.ExpectedTaskName', 'Expected task name.', FToken);
    NextToken;
    Exit;
  end;
  lName := FToken;
  NextToken;
  if FToken.Kind <> ttIdentifier then
  begin
    AddError('NXTask.Parse.ExpectedTaskAction', 'Expected task action.', FToken);
    Exit;
  end;
  lAction := FToken;
  NextToken;
  Result := TNXTaskNode.Create(lName.Text, lAction.Text, RangeForToken(lName), FFileName);
  ParseTargets(Result);
  Expect(ttLBrace, 'Expected "{" to begin task body.');
  ParseNodeBody(Result);
end;

function TNXTaskParser.ParseFile(const AFileName: string): TNXTaskDocument;
var
  lText: TStringList;
begin
  lText := TStringList.Create;
  try
    lText.LoadFromFile(AFileName);
    Result := ParseText(ExpandFileName(AFileName), lText.Text);
  finally
    lText.Free;
  end;
end;

function TNXTaskParser.ParseText(const AFileName, AText: string): TNXTaskDocument;
var
  lNode: TNXTaskNode;
begin
  FFileName := ExpandFileName(AFileName);
  FText := AText;
  FIndex := 1;
  FLine := 1;
  FColumn := 1;
  FDocument := TNXTaskDocument.Create(FFileName);
  NextToken;
  while FToken.Kind <> ttEOF do
  begin
    lNode := ParseNode;
    if lNode <> nil then
      FDocument.Roots.Add(lNode);
  end;
  Result := FDocument;
end;

end.
