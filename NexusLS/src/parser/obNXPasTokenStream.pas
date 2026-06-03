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
    function Check(AKind: TNXPasTokenKind): Boolean;
    function CheckKeyword(AKeyword: TNXPasKeywordKind): Boolean;
    function CheckSymbol(ASymbol: TNXPasTokenSymbolKind): Boolean;
    function CheckPeek(AOffset: Integer; AKind: TNXPasTokenKind): Boolean;
    function CheckPeekKeyword(AOffset: Integer;
      AKeyword: TNXPasKeywordKind): Boolean;
    function CheckPeekSymbol(AOffset: Integer;
      ASymbol: TNXPasTokenSymbolKind): Boolean;
    function Match(AKind: TNXPasTokenKind): Boolean;
    function MatchKeyword(AKeyword: TNXPasKeywordKind): Boolean;
    function MatchSymbol(ASymbol: TNXPasTokenSymbolKind): Boolean;
    function Peek(AOffset: Integer = 1): TNXPasToken;
    function ExpectIdentifier(out AName: string): Boolean;
    function ExpectIdentifierToken(out AToken: TNXPasToken): Boolean;
    function TokenText(const AToken: TNXPasToken): string;
    function CurrentText: string;

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

function TNXPasTokenStream.TokenText(const AToken: TNXPasToken): string;
begin
  Result := '';
  if FLexer <> nil then
    Result := AToken.Text(FLexer.SourceText);
end;

function TNXPasTokenStream.CurrentText: string;
begin
  Result := TokenText(FCurrent);
end;

function TNXPasTokenStream.Check(AKind: TNXPasTokenKind): Boolean;
begin
  Result := FCurrent.Kind = AKind;
end;

function TNXPasTokenStream.CheckKeyword(
  AKeyword: TNXPasKeywordKind): Boolean;
begin
  Result := (FCurrent.Kind = ptkKeyword) and (FCurrent.Keyword = AKeyword);
end;

function TNXPasTokenStream.CheckSymbol(ASymbol: TNXPasTokenSymbolKind): Boolean;
begin
  Result := (FCurrent.Kind = ptkSymbol) and (FCurrent.Symbol = ASymbol);
end;

function TNXPasTokenStream.CheckPeek(AOffset: Integer;
  AKind: TNXPasTokenKind): Boolean;
var
  lToken: TNXPasToken;
begin
  lToken := Peek(AOffset);
  Result := lToken.Kind = AKind;
end;

function TNXPasTokenStream.CheckPeekKeyword(AOffset: Integer;
  AKeyword: TNXPasKeywordKind): Boolean;
var
  lToken: TNXPasToken;
begin
  lToken := Peek(AOffset);
  Result := (lToken.Kind = ptkKeyword) and (lToken.Keyword = AKeyword);
end;

function TNXPasTokenStream.CheckPeekSymbol(AOffset: Integer;
  ASymbol: TNXPasTokenSymbolKind): Boolean;
var
  lToken: TNXPasToken;
begin
  lToken := Peek(AOffset);
  Result := (lToken.Kind = ptkSymbol) and (lToken.Symbol = ASymbol);
end;

function TNXPasTokenStream.Match(AKind: TNXPasTokenKind): Boolean;
begin
  Result := Check(AKind);
  if Result then
    Next;
end;

function TNXPasTokenStream.MatchKeyword(AKeyword: TNXPasKeywordKind): Boolean;
begin
  Result := CheckKeyword(AKeyword);
  if Result then
    Next;
end;

function TNXPasTokenStream.MatchSymbol(ASymbol: TNXPasTokenSymbolKind): Boolean;
begin
  Result := CheckSymbol(ASymbol);
  if Result then
    Next;
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
    AName := CurrentText;
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
    NXPasClearToken(AToken);
end;

end.

