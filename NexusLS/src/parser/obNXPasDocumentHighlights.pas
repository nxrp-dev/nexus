unit obNXPasDocumentHighlights;

{$mode objfpc}{$H+}

interface

uses
  obNXPasLookup,
  obNXPasWorkspaceIndex;

type
  TNXPasDocumentHighlightResolver = class
  public
    class procedure FindDocumentHighlights(AIndex: TNXPasWorkspaceIndex;
      const AURI: string; ALine, AColumn: Integer;
      AResults: TNXPasReferenceMatchList); static;
  end;

implementation

uses
  SysUtils,
  obNXPasLexer,
  obNXPasRoutineIdentity,
  obNXPasSource,
  obNXPasSymbols,
  tpNXPasTokens;

function NXPasHighlightRangeAssigned(const ARange: TNXPasSourceRange): Boolean;
begin
  Result := ARange.EndPos.Offset > ARange.StartPos.Offset;
end;

function NXPasHighlightRangesEqual(const ALeft,
  ARight: TNXPasSourceRange): Boolean;
begin
  Result :=
    (ALeft.StartPos.Line = ARight.StartPos.Line) and
    (ALeft.StartPos.Column = ARight.StartPos.Column) and
    (ALeft.EndPos.Line = ARight.EndPos.Line) and
    (ALeft.EndPos.Column = ARight.EndPos.Column);
end;

function NXPasHighlightFileByURI(AIndex: TNXPasWorkspaceIndex;
  const AURI: string): TNXPasIndexedFile;
var
  lIdx: Integer;
begin
  Result := nil;
  if AIndex = nil then
    Exit;

  for lIdx := 0 to AIndex.FileCount - 1 do
    if SameText(AIndex.Files[lIdx].URI, AURI) then
      Exit(AIndex.Files[lIdx]);
end;

function NXPasHighlightSymbolNameRange(AFile: TNXPasIndexedFile;
  ASymbol: TNXPasSymbol; out ARange: TNXPasSourceRange): Boolean;
begin
  Result := False;
  if (AFile = nil) or (ASymbol = nil) then
    Exit;

  if NXPasHighlightRangeAssigned(ASymbol.NameRange) then
  begin
    ARange := ASymbol.NameRange;
    Exit(True);
  end;

  Result := TNXPasLookup.FindSymbolIdentifierRange(AFile, ASymbol.Name,
    ASymbol.Range, ARange);
end;

procedure NXPasHighlightAddRange(AResults: TNXPasReferenceMatchList;
  AFile: TNXPasIndexedFile; const ARange: TNXPasSourceRange);
var
  lIdx: Integer;
begin
  if (AResults = nil) or (AFile = nil) or
    (not NXPasHighlightRangeAssigned(ARange)) then
    Exit;

  for lIdx := 0 to AResults.Count - 1 do
    if (AResults.MatchAt(lIdx).FileRef = AFile) and
      NXPasHighlightRangesEqual(AResults.MatchAt(lIdx).Range, ARange) then
      Exit;

  AResults.AddMatch(AFile, ARange);
end;

function NXPasHighlightFindSmallestRoutineAt(AFile: TNXPasIndexedFile;
  ALine, AColumn: Integer; out ASymbol: TNXPasSymbol): Boolean;
var
  lBestSize: Integer;
  lSymbolIdx: Integer;

  procedure Consider(ACandidate: TNXPasSymbol);
  var
    lChildIdx: Integer;
    lSize: Integer;
  begin
    if ACandidate = nil then
      Exit;

    if (ACandidate.Kind = pskRoutine) and
      NXPasRangeContains(ACandidate.Range, ALine, AColumn) then
    begin
      lSize := ACandidate.Range.EndPos.Offset - ACandidate.Range.StartPos.Offset;
      if (ASymbol = nil) or (lSize < lBestSize) then
      begin
        ASymbol := ACandidate;
        lBestSize := lSize;
      end;
    end;

    for lChildIdx := 0 to ACandidate.ChildCount - 1 do
      Consider(ACandidate.Children[lChildIdx]);
  end;

begin
  ASymbol := nil;
  lBestSize := MaxInt;
  if AFile = nil then
    Exit(False);

  for lSymbolIdx := 0 to AFile.Symbols.Count - 1 do
    Consider(AFile.Symbols.SymbolAt(lSymbolIdx));

  Result := ASymbol <> nil;
end;

function NXPasHighlightFindSymbolAtNameRange(AFile: TNXPasIndexedFile;
  ALine, AColumn: Integer; out ASymbol: TNXPasSymbol): Boolean;
var
  lSymbolIdx: Integer;

  procedure Consider(ACandidate: TNXPasSymbol);
  var
    lChildIdx: Integer;
    lNameRange: TNXPasSourceRange;
  begin
    if (ASymbol <> nil) or (ACandidate = nil) then
      Exit;

    if NXPasHighlightSymbolNameRange(AFile, ACandidate, lNameRange) and
      NXPasRangeContains(lNameRange, ALine, AColumn) then
    begin
      ASymbol := ACandidate;
      Exit;
    end;

    for lChildIdx := 0 to ACandidate.ChildCount - 1 do
      Consider(ACandidate.Children[lChildIdx]);
  end;

begin
  ASymbol := nil;
  if AFile = nil then
    Exit(False);

  for lSymbolIdx := 0 to AFile.Symbols.Count - 1 do
    Consider(AFile.Symbols.SymbolAt(lSymbolIdx));

  Result := ASymbol <> nil;
end;

function NXPasHighlightFindRoutineChild(AOwnerRoutine: TNXPasSymbol;
  AKind: TNXPasSymbolKind; const AName: string; out ASymbol: TNXPasSymbol):
  Boolean;
var
  lIdx: Integer;
begin
  ASymbol := nil;
  if AOwnerRoutine = nil then
    Exit(False);

  for lIdx := 0 to AOwnerRoutine.ChildCount - 1 do
    if (AOwnerRoutine.Children[lIdx].Kind = AKind) and
      SameText(AOwnerRoutine.Children[lIdx].Name, AName) then
    begin
      ASymbol := AOwnerRoutine.Children[lIdx];
      Exit(True);
    end;

  Result := False;
end;

procedure NXPasHighlightAddLexicalMatchesInRange(AResults: TNXPasReferenceMatchList;
  AFile: TNXPasIndexedFile; const AName: string;
  const AScopeRange: TNXPasSourceRange);
var
  lLexer: TNXPasLexer;
  lRange: TNXPasSourceRange;
  lToken: TNXPasToken;
begin
  if (AResults = nil) or (AFile = nil) or (Trim(AName) = '') then
    Exit;

  lLexer := TNXPasLexer.Create(AFile.Text);
  try
    repeat
      lToken := lLexer.NextToken;
      if (lToken.Kind = ptkIdentifier) and SameText(lToken.Text, AName) and
        NXPasRangeContains(AScopeRange, lToken.StartPos.Line,
        lToken.StartPos.Column) then
      begin
        lRange.StartPos := lToken.StartPos;
        lRange.EndPos := lToken.EndPos;
        NXPasHighlightAddRange(AResults, AFile, lRange);
      end;
    until lToken.Kind = ptkEndOfFile;
  finally
    lLexer.Free;
  end;
end;

function NXPasHighlightFindOwnerQualifierRange(ASymbol: TNXPasSymbol;
  out ARange: TNXPasSourceRange): Boolean;
begin
  Result := False;
  if (ASymbol = nil) or (ASymbol.Kind <> pskRoutine) then
    Exit;

  if not NXPasHighlightRangeAssigned(ASymbol.OwnerNameRange) then
    Exit;

  ARange := ASymbol.OwnerNameRange;
  Result := True;
end;

function NXPasHighlightOwnerQualifierAtPosition(AFile: TNXPasIndexedFile;
  ALine, AColumn: Integer; out AOwnerName: string): Boolean;
var
  lRange: TNXPasSourceRange;
  lSymbolIdx: Integer;

  procedure Consider(ASymbol: TNXPasSymbol);
  var
    lChildIdx: Integer;
  begin
    if Result or (ASymbol = nil) then
      Exit;

    if (ASymbol.Kind = pskRoutine) and
      NXPasHighlightFindOwnerQualifierRange(ASymbol, lRange) and
      NXPasRangeContains(lRange, ALine, AColumn) then
    begin
      AOwnerName := NXPasRoutineOwnerName(ASymbol);
      Result := True;
      Exit;
    end;

    for lChildIdx := 0 to ASymbol.ChildCount - 1 do
      Consider(ASymbol.Children[lChildIdx]);
  end;

begin
  Result := False;
  AOwnerName := '';
  if AFile = nil then
    Exit;

  for lSymbolIdx := 0 to AFile.Symbols.Count - 1 do
    Consider(AFile.Symbols.SymbolAt(lSymbolIdx));
end;

procedure NXPasHighlightAddRoutineIdentity(AIndex: TNXPasWorkspaceIndex;
  const AIdentity: string; AResults: TNXPasReferenceMatchList);
var
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lSymbolIdx: Integer;

  procedure Consider(AFile: TNXPasIndexedFile; ASymbol: TNXPasSymbol);
  var
    lChildIdx: Integer;
    lRange: TNXPasSourceRange;
  begin
    if ASymbol = nil then
      Exit;

    if (ASymbol.Kind = pskRoutine) and
      (NXPasRoutineIdentity(ASymbol) = AIdentity) and
      NXPasHighlightSymbolNameRange(AFile, ASymbol, lRange) then
      NXPasHighlightAddRange(AResults, AFile, lRange);

    for lChildIdx := 0 to ASymbol.ChildCount - 1 do
      Consider(AFile, ASymbol.Children[lChildIdx]);
  end;

begin
  if (AIndex = nil) or (AIdentity = '') then
    Exit;

  for lFileIdx := 0 to AIndex.FileCount - 1 do
  begin
    lFile := AIndex.Files[lFileIdx];
    for lSymbolIdx := 0 to lFile.Symbols.Count - 1 do
      Consider(lFile, lFile.Symbols.SymbolAt(lSymbolIdx));
  end;
end;

procedure NXPasHighlightAddType(AIndex: TNXPasWorkspaceIndex;
  const ATypeName: string; AResults: TNXPasReferenceMatchList);
var
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lSymbolIdx: Integer;

  procedure Consider(AFile: TNXPasIndexedFile; ASymbol: TNXPasSymbol);
  var
    lChildIdx: Integer;
    lRange: TNXPasSourceRange;
  begin
    if ASymbol = nil then
      Exit;

    if (ASymbol.Kind in [pskType, pskClass, pskRecord, pskObject,
      pskInterface]) and SameText(ASymbol.Name, ATypeName) and
      NXPasHighlightSymbolNameRange(AFile, ASymbol, lRange) then
      NXPasHighlightAddRange(AResults, AFile, lRange);

    if (ASymbol.DeclaredTypeText <> '') and
      SameText(Trim(ASymbol.DeclaredTypeText), ATypeName) and
      NXPasHighlightRangeAssigned(ASymbol.DeclaredTypeRange) then
      NXPasHighlightAddRange(AResults, AFile, ASymbol.DeclaredTypeRange);

    if (ASymbol.Kind = pskRoutine) and
      SameText(NXPasRoutineOwnerName(ASymbol), ATypeName) and
      NXPasHighlightFindOwnerQualifierRange(ASymbol, lRange) then
      NXPasHighlightAddRange(AResults, AFile, lRange);

    for lChildIdx := 0 to ASymbol.ChildCount - 1 do
      Consider(AFile, ASymbol.Children[lChildIdx]);
  end;

begin
  if (AIndex = nil) or (Trim(ATypeName) = '') then
    Exit;

  for lFileIdx := 0 to AIndex.FileCount - 1 do
  begin
    lFile := AIndex.Files[lFileIdx];
    for lSymbolIdx := 0 to lFile.Symbols.Count - 1 do
      Consider(lFile, lFile.Symbols.SymbolAt(lSymbolIdx));
  end;
end;

function NXPasHighlightFindDeclaredTypeAtPosition(AFile: TNXPasIndexedFile;
  ALine, AColumn: Integer; out ATypeName: string): Boolean;
var
  lSymbolIdx: Integer;

  procedure Consider(ASymbol: TNXPasSymbol);
  var
    lChildIdx: Integer;
  begin
    if Result or (ASymbol = nil) then
      Exit;

    if (ASymbol.DeclaredTypeText <> '') and
      NXPasHighlightRangeAssigned(ASymbol.DeclaredTypeRange) and
      NXPasRangeContains(ASymbol.DeclaredTypeRange, ALine, AColumn) then
    begin
      ATypeName := Trim(ASymbol.DeclaredTypeText);
      Result := True;
      Exit;
    end;

    for lChildIdx := 0 to ASymbol.ChildCount - 1 do
      Consider(ASymbol.Children[lChildIdx]);
  end;

begin
  Result := False;
  ATypeName := '';
  if AFile = nil then
    Exit;

  for lSymbolIdx := 0 to AFile.Symbols.Count - 1 do
    Consider(AFile.Symbols.SymbolAt(lSymbolIdx));
end;

class procedure TNXPasDocumentHighlightResolver.FindDocumentHighlights(
  AIndex: TNXPasWorkspaceIndex; const AURI: string; ALine, AColumn: Integer;
  AResults: TNXPasReferenceMatchList);
var
  lFile: TNXPasIndexedFile;
  lIdentifierRange: TNXPasSourceRange;
  lName: string;
  lOwnerName: string;
  lRoutine: TNXPasSymbol;
  lSource: TNXPasSourceFile;
  lSymbol: TNXPasSymbol;
begin
  if (AIndex = nil) or (AResults = nil) then
    Exit;

  lFile := NXPasHighlightFileByURI(AIndex, AURI);
  if lFile = nil then
    Exit;

  lSource := TNXPasSourceFile.Create(lFile.FileName, lFile.URI, lFile.Text);
  try
    if not TNXPasLookup.IdentifierAtPosition(lSource, ALine, AColumn, lName,
      lIdentifierRange) then
      Exit;
  finally
    lSource.Free;
  end;

  if NXPasHighlightFindSymbolAtNameRange(lFile, ALine, AColumn, lSymbol) then
  begin
    if lSymbol.Kind = pskRoutine then
    begin
      NXPasHighlightAddRoutineIdentity(AIndex,
        NXPasRoutineIdentity(lSymbol), AResults);
      Exit;
    end;

    if lSymbol.Kind in [pskParameter, pskVariable] then
    begin
      lRoutine := NXPasSymbolOwnerRoutine(lSymbol);
      if lRoutine <> nil then
      begin
        NXPasHighlightAddLexicalMatchesInRange(AResults, lFile, lSymbol.Name,
          lRoutine.Range);
        Exit;
      end;
    end;

    if lSymbol.Kind in [pskType, pskClass, pskRecord, pskObject,
      pskInterface] then
    begin
      NXPasHighlightAddType(AIndex, lSymbol.Name, AResults);
      Exit;
    end;
  end;

  if NXPasHighlightOwnerQualifierAtPosition(lFile, ALine, AColumn,
    lOwnerName) then
  begin
    NXPasHighlightAddType(AIndex, lOwnerName, AResults);
    Exit;
  end;

  if NXPasHighlightFindSmallestRoutineAt(lFile, ALine, AColumn, lRoutine) then
  begin
    if NXPasHighlightFindRoutineChild(lRoutine, pskParameter, lName,
      lSymbol) or
      NXPasHighlightFindRoutineChild(lRoutine, pskVariable, lName,
      lSymbol) then
    begin
      NXPasHighlightAddLexicalMatchesInRange(AResults, lFile, lSymbol.Name,
        lRoutine.Range);
      Exit;
    end;
  end;

  if NXPasHighlightFindDeclaredTypeAtPosition(lFile, ALine, AColumn,
    lOwnerName) then
  begin
    NXPasHighlightAddType(AIndex, lOwnerName, AResults);
    Exit;
  end;
end;

end.
