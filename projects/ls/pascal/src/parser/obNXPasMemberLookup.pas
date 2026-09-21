unit obNXPasMemberLookup;

{$mode objfpc}{$H+}

interface

uses
  obNXPasSource,
  obNXPasSymbols,
  obNXPasWorkspaceIndex;

type
  TNXPasMemberLookup = class
  private
    class function IsReceiverTokenKind(ASymbolKind: Integer;
      const AText: string): Boolean; static;
    class function PositionInRange(ALine, AColumn: Integer;
      const ARange: TNXPasSourceRange): Boolean; static;
    class function TokenEndsAtOrBeforePosition(ALine, AColumn: Integer;
      const ARange: TNXPasSourceRange): Boolean; static;
    class function TokenStartsAfterPosition(ALine, AColumn: Integer;
      const ARange: TNXPasSourceRange): Boolean; static;
    class function MatchIsVisibleReceiver(AMatch: TNXPasWorkspaceSymbolMatch;
      const AURI: string; ALine, AColumn: Integer): Boolean; static;
  public
    class function DetectCompletion(ASource: TNXPasSourceFile; ALine,
      AColumn: Integer; out AReceiverName, APrefix: string): Boolean; static;
    class function DetectMemberAtPosition(ASource: TNXPasSourceFile; ALine,
      AColumn: Integer; out AReceiverName, AMemberName: string;
      out AMemberRange: TNXPasSourceRange): Boolean; static;
    class function FindDirectMember(ATypeSymbol: TNXPasSymbol;
      const AMemberName: string; out AMember: TNXPasSymbol): Boolean; static;
    class function ResolveReceiverType(AIndex: TNXPasWorkspaceIndex;
      const AURI, AReceiverName: string; ALine, AColumn: Integer;
      out AReceiverMatch, ATypeMatch: TNXPasWorkspaceSymbolMatch): Boolean; static;
  end;

implementation

uses
  SysUtils,
  obNXPasLexer,
  tpNXPasTokens;

class function TNXPasMemberLookup.IsReceiverTokenKind(ASymbolKind: Integer;
  const AText: string): Boolean;
begin
  Result := (TNXPasTokenKind(ASymbolKind) = ptkIdentifier) or
    ((TNXPasTokenKind(ASymbolKind) = ptkKeyword) and SameText(AText, 'self'));
end;

class function TNXPasMemberLookup.PositionInRange(ALine, AColumn: Integer;
  const ARange: TNXPasSourceRange): Boolean;
begin
  Result := False;
  if ALine < ARange.StartPos.Line then
    Exit;
  if ALine > ARange.EndPos.Line then
    Exit;
  if (ALine = ARange.StartPos.Line) and (AColumn < ARange.StartPos.Column) then
    Exit;
  if (ALine = ARange.EndPos.Line) and (AColumn > ARange.EndPos.Column) then
    Exit;
  Result := True;
end;

class function TNXPasMemberLookup.TokenEndsAtOrBeforePosition(ALine,
  AColumn: Integer; const ARange: TNXPasSourceRange): Boolean;
begin
  Result := (ARange.EndPos.Line < ALine) or
    ((ARange.EndPos.Line = ALine) and (ARange.EndPos.Column <= AColumn));
end;

class function TNXPasMemberLookup.TokenStartsAfterPosition(ALine,
  AColumn: Integer; const ARange: TNXPasSourceRange): Boolean;
begin
  Result := (ARange.StartPos.Line > ALine) or
    ((ARange.StartPos.Line = ALine) and (ARange.StartPos.Column > AColumn));
end;

class function TNXPasMemberLookup.MatchIsVisibleReceiver(
  AMatch: TNXPasWorkspaceSymbolMatch; const AURI: string; ALine,
  AColumn: Integer): Boolean;
begin
  Result := False;
  if (AMatch = nil) or (AMatch.FileRef = nil) or (AMatch.Symbol = nil) then
    Exit;

  if NXPasSymbolIsRoutineOwned(AMatch.Symbol) then
    Exit(SameText(AMatch.FileRef.URI, AURI) and
      NXPasSymbolIsVisibleAt(AMatch.Symbol, ALine, AColumn));

  Result := NXPasSymbolIsVisibleAt(AMatch.Symbol, ALine, AColumn);
end;

class function TNXPasMemberLookup.DetectCompletion(ASource: TNXPasSourceFile;
  ALine, AColumn: Integer; out AReceiverName, APrefix: string): Boolean;
var
  lLexer: TNXPasLexer;
  lPrev: TNXPasToken;
  lPrevPrev: TNXPasToken;
  lRange: TNXPasSourceRange;
  lToken: TNXPasToken;
begin
  Result := False;
  AReceiverName := '';
  APrefix := '';
  if ASource = nil then
    Exit;

  NXPasClearToken(lPrev);
  lPrevPrev := lPrev;
  lLexer := TNXPasLexer.Create(ASource.Text);
  try
    repeat
      lToken := lLexer.NextToken;
      lRange := ASource.RangeFromPositions(lToken.StartPos, lToken.EndPos);

      if (lToken.Kind = ptkIdentifier) and PositionInRange(ALine, AColumn,
        lRange) then
      begin
        if (lPrev.Kind = ptkSymbol) and (lPrev.Symbol = psyDot) and
          IsReceiverTokenKind(Ord(lPrevPrev.Kind),
          lPrevPrev.Text(ASource.Text)) then
        begin
          AReceiverName := lPrevPrev.Text(ASource.Text);
          APrefix := Copy(lToken.Text(ASource.Text), 1,
            AColumn - lToken.StartPos.Column);
          Exit(True);
        end;
        Exit(False);
      end;

      if TokenStartsAfterPosition(ALine, AColumn, lRange) then
        Break;

      if TokenEndsAtOrBeforePosition(ALine, AColumn, lRange) and
        not (lToken.Kind in [ptkWhitespace, ptkComment, ptkDirective]) then
      begin
        lPrevPrev := lPrev;
        lPrev := lToken;
      end;
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;

  if (lPrev.Kind = ptkSymbol) and (lPrev.Symbol = psyDot) and
    IsReceiverTokenKind(Ord(lPrevPrev.Kind), lPrevPrev.Text(ASource.Text)) then
  begin
    AReceiverName := lPrevPrev.Text(ASource.Text);
    APrefix := '';
    Result := True;
  end;
end;

class function TNXPasMemberLookup.DetectMemberAtPosition(
  ASource: TNXPasSourceFile; ALine, AColumn: Integer; out AReceiverName,
  AMemberName: string; out AMemberRange: TNXPasSourceRange): Boolean;
var
  lLexer: TNXPasLexer;
  lPrev: TNXPasToken;
  lPrevPrev: TNXPasToken;
  lRange: TNXPasSourceRange;
  lToken: TNXPasToken;
begin
  Result := False;
  AReceiverName := '';
  AMemberName := '';
  if ASource = nil then
    Exit;

  NXPasClearToken(lPrev);
  lPrevPrev := lPrev;
  lLexer := TNXPasLexer.Create(ASource.Text);
  try
    repeat
      lToken := lLexer.NextToken;
      lRange := ASource.RangeFromPositions(lToken.StartPos, lToken.EndPos);
      if (lToken.Kind = ptkIdentifier) and PositionInRange(ALine, AColumn,
        lRange) then
      begin
        if (lPrev.Kind = ptkSymbol) and (lPrev.Symbol = psyDot) and
          IsReceiverTokenKind(Ord(lPrevPrev.Kind),
          lPrevPrev.Text(ASource.Text)) then
        begin
          AReceiverName := lPrevPrev.Text(ASource.Text);
          AMemberName := lToken.Text(ASource.Text);
          AMemberRange := lRange;
          Exit(True);
        end;
        Exit(False);
      end;

      if TokenStartsAfterPosition(ALine, AColumn, lRange) then
        Break;

      if TokenEndsAtOrBeforePosition(ALine, AColumn, lRange) and
        not (lToken.Kind in [ptkWhitespace, ptkComment, ptkDirective]) then
      begin
        lPrevPrev := lPrev;
        lPrev := lToken;
      end;
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;
end;

class function TNXPasMemberLookup.FindDirectMember(ATypeSymbol: TNXPasSymbol;
  const AMemberName: string; out AMember: TNXPasSymbol): Boolean;
var
  lIdx: Integer;
  lSymbol: TNXPasSymbol;
begin
  Result := False;
  AMember := nil;
  if (ATypeSymbol = nil) or (Trim(AMemberName) = '') then
    Exit;

  for lIdx := 0 to ATypeSymbol.ChildCount - 1 do
  begin
    lSymbol := ATypeSymbol.Children[lIdx];
    if (lSymbol.Kind in [pskField, pskProperty, pskRoutine]) and
      SameText(lSymbol.Name, AMemberName) then
    begin
      AMember := lSymbol;
      Exit(True);
    end;
  end;
end;

class function TNXPasMemberLookup.ResolveReceiverType(
  AIndex: TNXPasWorkspaceIndex; const AURI, AReceiverName: string; ALine,
  AColumn: Integer; out AReceiverMatch,
  ATypeMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lIdx: Integer;
  lReceiverMatches: TNXPasWorkspaceSymbolMatchList;
  lTypeMatches: TNXPasWorkspaceSymbolMatchList;
  lReceiver: TNXPasWorkspaceSymbolMatch;
  lType: TNXPasWorkspaceSymbolMatch;
begin
  Result := False;
  AReceiverMatch := nil;
  ATypeMatch := nil;
  if (AIndex = nil) or (Trim(AReceiverName) = '') then
    Exit;

  lReceiverMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  lTypeMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    AIndex.FindSymbolsByName(AReceiverName, AURI, lReceiverMatches);
    for lIdx := 0 to lReceiverMatches.Count - 1 do
    begin
      lReceiver := lReceiverMatches.MatchAt(lIdx);
      if (lReceiver.Symbol = nil) or (lReceiver.Symbol.DeclaredTypeText = '') or
        (not MatchIsVisibleReceiver(lReceiver, AURI, ALine, AColumn)) then
        Continue;

      lTypeMatches.Clear;
      AIndex.FindSymbolsByName(lReceiver.Symbol.DeclaredTypeText, AURI,
        lTypeMatches);
      if lTypeMatches.Count = 0 then
        Continue;

      lType := lTypeMatches.MatchAt(0);
      if (lType.Symbol = nil) or not (lType.Symbol.Kind in [pskType, pskClass,
        pskRecord, pskObject, pskInterface]) then
        Continue;

      AReceiverMatch := lReceiver;
      lReceiverMatches.Extract(AReceiverMatch);
      ATypeMatch := lType;
      lTypeMatches.Extract(ATypeMatch);
      Exit(True);
    end;
  finally
    lTypeMatches.Free;
    lReceiverMatches.Free;
  end;
end;

end.
