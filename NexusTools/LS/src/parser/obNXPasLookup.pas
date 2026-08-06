unit obNXPasLookup;

{$mode objfpc}{$H+}

interface

uses
  Contnrs,
  obNXPasSource,
  obNXPasWorkspaceIndex;

type
  TNXPasReferenceMatch = class
  private
    FFileRef: TNXPasIndexedFile;
    FRange: TNXPasSourceRange;
  public
    property FileRef: TNXPasIndexedFile read FFileRef write FFileRef;
    property Range: TNXPasSourceRange read FRange write FRange;
  end;

  TNXPasReferenceMatchList = class(TObjectList)
  public
    function AddMatch(AFile: TNXPasIndexedFile;
      const ARange: TNXPasSourceRange): TNXPasReferenceMatch;
    function MatchAt(AIndex: Integer): TNXPasReferenceMatch;
  end;

  TNXPasLookup = class
  private
    class function PositionInRange(ALine, AColumn: Integer;
      const ARange: TNXPasSourceRange): Boolean; static;
    class function TokenIsInactive(const ARange: TNXPasSourceRange;
      AInactiveRegions: TNXPasInactiveRegionList): Boolean; static;
    class function RangesEqual(const ALeft,
      ARight: TNXPasSourceRange): Boolean; static;
    class function TokenIsDeclaration(const ARange: TNXPasSourceRange;
      AFile: TNXPasIndexedFile;
      ADeclarations: TNXPasWorkspaceSymbolMatchList): Boolean; static;
  public
    class function IdentifierAtPosition(ASource: TNXPasSourceFile;
      ALine, AColumn: Integer; out AName: string;
      out ARange: TNXPasSourceRange): Boolean; static;
    class function FindSymbolIdentifierRange(AFile: TNXPasIndexedFile;
      const AName: string; const ASymbolRange: TNXPasSourceRange;
      out ARange: TNXPasSourceRange): Boolean; static;
    class procedure FindLexicalIdentifierReferences(AIndex: TNXPasWorkspaceIndex;
      const AName: string; AIncludeDeclaration: Boolean;
      AResults: TNXPasReferenceMatchList); static;
  end;

implementation

uses
  SysUtils,
  obNXPasLexer,
  tpNXPasTokens;

function TNXPasReferenceMatchList.AddMatch(AFile: TNXPasIndexedFile;
  const ARange: TNXPasSourceRange): TNXPasReferenceMatch;
begin
  Result := TNXPasReferenceMatch.Create;
  Result.FileRef := AFile;
  Result.Range := ARange;
  Add(Result);
end;

function TNXPasReferenceMatchList.MatchAt(AIndex: Integer): TNXPasReferenceMatch;
begin
  Result := TNXPasReferenceMatch(Items[AIndex]);
end;

class function TNXPasLookup.PositionInRange(ALine, AColumn: Integer;
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

class function TNXPasLookup.RangesEqual(const ALeft,
  ARight: TNXPasSourceRange): Boolean;
begin
  Result :=
    (ALeft.StartPos.Line = ARight.StartPos.Line) and
    (ALeft.StartPos.Column = ARight.StartPos.Column) and
    (ALeft.EndPos.Line = ARight.EndPos.Line) and
    (ALeft.EndPos.Column = ARight.EndPos.Column);
end;

class function TNXPasLookup.TokenIsInactive(const ARange: TNXPasSourceRange;
  AInactiveRegions: TNXPasInactiveRegionList): Boolean;
var
  lIdx: Integer;
begin
  Result := False;
  if AInactiveRegions = nil then
    Exit;

  for lIdx := 0 to AInactiveRegions.Count - 1 do
    if PositionInRange(ARange.StartPos.Line, ARange.StartPos.Column,
      AInactiveRegions.RegionAt(lIdx).Range) then
      Exit(True);
end;

class function TNXPasLookup.TokenIsDeclaration(const ARange: TNXPasSourceRange;
  AFile: TNXPasIndexedFile; ADeclarations: TNXPasWorkspaceSymbolMatchList): Boolean;
var
  lIdx: Integer;
  lRange: TNXPasSourceRange;
  lSymbol: TNXPasWorkspaceSymbolMatch;
begin
  Result := False;
  if ADeclarations = nil then
    Exit;

  for lIdx := 0 to ADeclarations.Count - 1 do
  begin
    lSymbol := ADeclarations.MatchAt(lIdx);
    if (lSymbol.FileRef <> AFile) or (lSymbol.Symbol = nil) then
      Continue;

    if FindSymbolIdentifierRange(AFile, lSymbol.Symbol.Name,
      lSymbol.Symbol.Range, lRange) and RangesEqual(ARange, lRange) then
      Exit(True);
  end;
end;

class function TNXPasLookup.IdentifierAtPosition(ASource: TNXPasSourceFile;
  ALine, AColumn: Integer; out AName: string;
  out ARange: TNXPasSourceRange): Boolean;
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  Result := False;
  AName := '';
  if ASource = nil then
    Exit;

  lLexer := TNXPasLexer.Create(ASource.Text);
  try
    repeat
      lToken := lLexer.NextToken;
      if (lToken.Kind = ptkIdentifier) and
        PositionInRange(ALine, AColumn, ASource.RangeFromPositions(
        lToken.StartPos, lToken.EndPos)) then
      begin
        AName := lToken.Text(ASource.Text);
        ARange := ASource.RangeFromPositions(lToken.StartPos, lToken.EndPos);
        Exit(True);
      end;
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;
end;

class function TNXPasLookup.FindSymbolIdentifierRange(AFile: TNXPasIndexedFile;
  const AName: string; const ASymbolRange: TNXPasSourceRange;
  out ARange: TNXPasSourceRange): Boolean;
var
  lLexer: TNXPasLexer;
  lToken: TNXPasToken;
begin
  Result := False;
  if (AFile = nil) or (Trim(AName) = '') then
    Exit;

  lLexer := TNXPasLexer.Create(AFile.Text);
  try
    repeat
      lToken := lLexer.NextToken;
      if (lToken.Kind = ptkIdentifier) and
        SameText(lToken.Text(AFile.Text), AName) and
        PositionInRange(lToken.StartPos.Line, lToken.StartPos.Column,
        ASymbolRange) then
      begin
        ARange.StartPos := lToken.StartPos;
        ARange.EndPos := lToken.EndPos;
        Exit(True);
      end;
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;
end;

class procedure TNXPasLookup.FindLexicalIdentifierReferences(
  AIndex: TNXPasWorkspaceIndex;
  const AName: string; AIncludeDeclaration: Boolean;
  AResults: TNXPasReferenceMatchList);
var
  lDeclarations: TNXPasWorkspaceSymbolMatchList;
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lLexer: TNXPasLexer;
  lRange: TNXPasSourceRange;
  lToken: TNXPasToken;
begin
  if (AIndex = nil) or (Trim(AName) = '') or (AResults = nil) then
    Exit;

  lDeclarations := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    if not AIncludeDeclaration then
      AIndex.FindSymbolsByName(AName, '', lDeclarations);

    for lFileIdx := 0 to AIndex.FileCount - 1 do
    begin
      lFile := AIndex.Files[lFileIdx];
      lLexer := TNXPasLexer.Create(lFile.Text);
      try
        repeat
          lToken := lLexer.NextToken;
          if (lToken.Kind = ptkIdentifier) and
            SameText(lToken.Text(lFile.Text), AName) then
          begin
            lRange.StartPos := lToken.StartPos;
            lRange.EndPos := lToken.EndPos;
            if (not TokenIsInactive(lRange,
              lFile.Metadata.InactiveRegions)) and
              (AIncludeDeclaration or
              (not TokenIsDeclaration(lRange, lFile, lDeclarations))) then
              AResults.AddMatch(lFile, lRange);
          end;
        until lToken.Kind = ptkEndOfFile;
      finally
        lLexer.Free;
      end;
    end;
  finally
    lDeclarations.Free;
  end;
end;

end.
