unit obNXPasTokenStream;

{$mode objfpc}{$H+}

interface

uses
  obNXPasLexer,
  tpNXPasTokens;

type
  TNXPasTokenStream = class
  private
    FLexer: TNXPasLexer;
    FCurrent: TNXPasToken;
    FLookahead: array of TNXPasToken;
    FOwnsLexer: Boolean;
    function ReadNextSignificantToken: TNXPasToken;
    procedure ReadNextToken;
  public
    constructor Create(ALexer: TNXPasLexer; AOwnsLexer: Boolean = True);
    destructor Destroy; override;

    procedure Next;
    function Check(AKind: TNXPasTokenKind; const AText: string = ''): Boolean;
    function CheckPeek(AOffset: Integer; AKind: TNXPasTokenKind;
      const AText: string = ''): Boolean;
    function Match(AKind: TNXPasTokenKind; const AText: string = ''): Boolean;
    function MatchKeyword(const AText: string): Boolean;
    function MatchSymbol(const AText: string): Boolean;
    function Peek(AOffset: Integer = 1): TNXPasToken;
    function ExpectIdentifier(out AName: string): Boolean;
    function ExpectIdentifierToken(out AToken: TNXPasToken): Boolean;

    property Current: TNXPasToken read FCurrent;
  end;

implementation

uses
  SysUtils;

constructor TNXPasTokenStream.Create(ALexer: TNXPasLexer; AOwnsLexer: Boolean);
begin
  inherited Create;
  FLexer := ALexer;
  FOwnsLexer := AOwnsLexer;
  ReadNextToken;
end;

destructor TNXPasTokenStream.Destroy;
begin
  if FOwnsLexer then
    FreeAndNil(FLexer);
  inherited Destroy;
end;

function TNXPasTokenStream.ReadNextSignificantToken: TNXPasToken;
begin
  repeat
    Result := FLexer.NextToken;
  until not (Result.Kind in [ptkWhitespace, ptkComment]);
end;

procedure TNXPasTokenStream.ReadNextToken;
var
  lIdx: Integer;
begin
  if Length(FLookahead) = 0 then
  begin
    FCurrent := ReadNextSignificantToken;
    Exit;
  end;

  FCurrent := FLookahead[0];
  for lIdx := 1 to High(FLookahead) do
    FLookahead[lIdx - 1] := FLookahead[lIdx];
  SetLength(FLookahead, Length(FLookahead) - 1);
end;

procedure TNXPasTokenStream.Next;
begin
  if FCurrent.Kind <> ptkEndOfFile then
    ReadNextToken;
end;

function TNXPasTokenStream.Check(AKind: TNXPasTokenKind;
  const AText: string): Boolean;
begin
  Result := FCurrent.Kind = AKind;
  if Result and (AText <> '') then
    Result := SameText(FCurrent.Text, AText);
end;

function TNXPasTokenStream.CheckPeek(AOffset: Integer;
  AKind: TNXPasTokenKind; const AText: string): Boolean;
var
  lToken: TNXPasToken;
begin
  lToken := Peek(AOffset);
  Result := lToken.Kind = AKind;
  if Result and (AText <> '') then
    Result := SameText(lToken.Text, AText);
end;

function TNXPasTokenStream.Match(AKind: TNXPasTokenKind;
  const AText: string): Boolean;
begin
  Result := Check(AKind, AText);
  if Result then
    Next;
end;

function TNXPasTokenStream.MatchKeyword(const AText: string): Boolean;
begin
  Result := Match(ptkKeyword, AText);
end;

function TNXPasTokenStream.MatchSymbol(const AText: string): Boolean;
begin
  Result := Match(ptkSymbol, AText);
end;

function TNXPasTokenStream.Peek(AOffset: Integer): TNXPasToken;
var
  lIdx: Integer;
begin
  if AOffset <= 0 then
  begin
    Result := FCurrent;
    Exit;
  end;

  while Length(FLookahead) < AOffset do
  begin
    lIdx := Length(FLookahead);
    SetLength(FLookahead, lIdx + 1);
    FLookahead[lIdx] := ReadNextSignificantToken;
  end;

  Result := FLookahead[AOffset - 1];
end;

function TNXPasTokenStream.ExpectIdentifier(out AName: string): Boolean;
begin
  Result := FCurrent.Kind = ptkIdentifier;
  if Result then
  begin
    AName := FCurrent.Text;
    Next;
  end
  else
    AName := '';
end;

function TNXPasTokenStream.ExpectIdentifierToken(
  out AToken: TNXPasToken): Boolean;
begin
  Result := FCurrent.Kind = ptkIdentifier;
  if Result then
  begin
    AToken := FCurrent;
    Next;
  end
  else
  begin
    AToken.Kind := ptkUnknown;
    AToken.Text := '';
    AToken.StartPos.Offset := 0;
    AToken.StartPos.Line := 0;
    AToken.StartPos.Column := 0;
    AToken.EndPos := AToken.StartPos;
  end;
end;

end.
