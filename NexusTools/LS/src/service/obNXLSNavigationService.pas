unit obNXLSNavigationService;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext,
  obNXPasLookup,
  obNXPasSymbols,
  obNXPasWorkspaceIndex;

type
  TNXLSNavigationService = class(TNXLSLSPService)
  private
    procedure AddReferenceLocation(AResult: TNXLSLocationArray;
      AMatch: TNXPasReferenceMatch);
    function FindIdentifierAtParams(AParams: TNXLSTextDocumentPositionParams;
      out ADocument: TNXLSDocument; out AName: string): Boolean;
    function FindRoutinePair(const AName, AURI: string;
      AImplementation: Boolean; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FindRoutinePairByIdentity(ASource: TNXPasWorkspaceSymbolMatch;
      AImplementation: Boolean; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FindSymbol(const AName, AURI: string;
      out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FindSymbolAtPosition(const AName, AURI: string; ALine,
      AColumn: Integer; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function ResolveMemberAtParams(AParams: TNXLSTextDocumentPositionParams;
      out AIsMemberAccess: Boolean;
      out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FillLocationFromSymbol(AMatch: TNXPasWorkspaceSymbolMatch;
      AResult: TNXLSLocation): Boolean;
    function FillLocationFromUnitFile(const AName: string;
      AResult: TNXLSLocation): Boolean;
    function FillLocationFromDeclaredType(AMatch: TNXPasWorkspaceSymbolMatch;
      AURI: string; AResult: TNXLSLocation): Boolean;
    function ImplementationLine(AFile: TNXPasIndexedFile): Integer;
    function IsImplementationSymbol(AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function TryFindRoutineAtPosition(const AURI: string; ALine,
      AColumn: Integer; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function WorkspaceIndex: TNXPasWorkspaceIndex;
    procedure SetRange(ARange: TNXLSRange; AStartLine, AStartColumn,
      AEndLine, AEndColumn: Integer);
  public
    constructor Create(AModel: TNXLSLSPContext); override;
    destructor Destroy; override;

    function FillDeclaration(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSLocation): Boolean; virtual;
    function FillDefinition(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSLocation): Boolean; virtual;
    function FillImplementationLocation(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSLocation): Boolean; virtual;
    function FillRoutineDeclaration(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSLocation): Boolean; virtual;
    function FillRoutineImplementation(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSLocation): Boolean; virtual;
    function FillTypeDefinition(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSLocation): Boolean; virtual;
    procedure CollectRoutinePairDiagnostics(
      AParams: TNXLSTextDocumentPositionParams; AImplementation: Boolean;
      AReport: TStrings); virtual;
    procedure FillReferences(AParams: TNXLSReferenceParams;
      AResult: TNXLSLocationArray); virtual;
  end;

implementation

uses
  SysUtils,
  obNXPasMemberLookup,
  obNXPasRoutineIdentity,
  obNXPasSource;

constructor TNXLSNavigationService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create(AModel);
end;

destructor TNXLSNavigationService.Destroy;
begin
  inherited Destroy;
end;

function TNXLSNavigationService.FillDeclaration(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lDocument: TNXLSDocument;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lName: string;
begin
  Result := False;
  if not FindIdentifierAtParams(AParams, lDocument, lName) then
    Exit;

  if FindRoutinePair(lName, lDocument.URI, False, lMatch) then
  try
    Exit(FillLocationFromSymbol(lMatch, AResult));
  finally
    lMatch.Free;
  end;

  if FindSymbol(lName, lDocument.URI, lMatch) then
  try
    Result := FillLocationFromSymbol(lMatch, AResult);
  finally
    lMatch.Free;
  end
  else
    Result := FillLocationFromUnitFile(lName, AResult);
end;

function TNXLSNavigationService.FillDefinition(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lDocument: TNXLSDocument;
  lIsMemberAccess: Boolean;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lName: string;
begin
  Result := False;
  if not FindIdentifierAtParams(AParams, lDocument, lName) then
    Exit;

  if ResolveMemberAtParams(AParams, lIsMemberAccess, lMatch) then
  try
    Exit(FillLocationFromSymbol(lMatch, AResult));
  finally
    lMatch.Free;
  end
  else if lIsMemberAccess then
    Exit;

  if FindSymbol(lName, lDocument.URI, lMatch) then
  try
    Result := FillLocationFromSymbol(lMatch, AResult);
  finally
    lMatch.Free;
  end
  else
    Result := FillLocationFromUnitFile(lName, AResult);
end;

function TNXLSNavigationService.FillImplementationLocation(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lDocument: TNXLSDocument;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lName: string;
begin
  Result := False;
  if not FindIdentifierAtParams(AParams, lDocument, lName) then
    Exit;

  if FindRoutinePair(lName, lDocument.URI, True, lMatch) then
  try
    Result := FillLocationFromSymbol(lMatch, AResult);
  finally
    lMatch.Free;
  end;
end;

function TNXLSNavigationService.FillRoutineDeclaration(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lMatch: TNXPasWorkspaceSymbolMatch;
  lSource: TNXPasWorkspaceSymbolMatch;
begin
  Result := False;
  if (AParams = nil) or (AParams.textDocument = nil) then
    Exit;

  lSource := nil;
  lMatch := nil;
  try
    if not TryFindRoutineAtPosition(AParams.textDocument.uri.Value,
      AParams.position.line.Value, AParams.position.character.Value,
      lSource) then
      Exit;

    if not IsImplementationSymbol(lSource) then
      Exit;

    if FindRoutinePairByIdentity(lSource, False, lMatch) then
      Result := FillLocationFromSymbol(lMatch, AResult);
  finally
    lMatch.Free;
    lSource.Free;
  end;
end;

function TNXLSNavigationService.FillRoutineImplementation(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lMatch: TNXPasWorkspaceSymbolMatch;
  lSource: TNXPasWorkspaceSymbolMatch;
begin
  Result := False;
  if (AParams = nil) or (AParams.textDocument = nil) then
    Exit;

  lSource := nil;
  lMatch := nil;
  try
    if not TryFindRoutineAtPosition(AParams.textDocument.uri.Value,
      AParams.position.line.Value, AParams.position.character.Value,
      lSource) then
      Exit;

    if IsImplementationSymbol(lSource) then
      Exit;

    if FindRoutinePairByIdentity(lSource, True, lMatch) then
      Result := FillLocationFromSymbol(lMatch, AResult);
  finally
    lMatch.Free;
    lSource.Free;
  end;
end;

function TNXLSNavigationService.FillTypeDefinition(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lDocument: TNXLSDocument;
  lIsMemberAccess: Boolean;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lName: string;
begin
  Result := False;
  if not FindIdentifierAtParams(AParams, lDocument, lName) then
    Exit;

  if ResolveMemberAtParams(AParams, lIsMemberAccess, lMatch) then
  try
    Exit(FillLocationFromDeclaredType(lMatch, lDocument.URI, AResult));
  finally
    lMatch.Free;
  end
  else if lIsMemberAccess then
    Exit;

  if FindSymbolAtPosition(lName, lDocument.URI, AParams.position.line.Value,
    AParams.position.character.Value, lMatch) then
  try
    if lMatch.Symbol.Kind in [pskType, pskClass, pskRecord, pskObject,
      pskInterface] then
      Result := FillLocationFromSymbol(lMatch, AResult)
    else
      Result := FillLocationFromDeclaredType(lMatch, lDocument.URI, AResult);
  finally
    lMatch.Free;
  end;
end;

procedure TNXLSNavigationService.CollectRoutinePairDiagnostics(
  AParams: TNXLSTextDocumentPositionParams; AImplementation: Boolean;
  AReport: TStrings);
var
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lLine: Integer;
  lColumn: Integer;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lPair: TNXPasWorkspaceSymbolMatch;
  lSymbolIdx: Integer;
  lURI: string;

  function BoolText(AValue: Boolean): string;
  begin
    if AValue then
      Result := 'true'
    else
      Result := 'false';
  end;

  function RangeText(const ARange: TNXPasSourceRange): string;
  begin
    Result := Format('%d:%d-%d:%d', [ARange.StartPos.Line,
      ARange.StartPos.Column, ARange.EndPos.Line, ARange.EndPos.Column]);
  end;

  procedure AddRoutineSymbol(AFile: TNXPasIndexedFile; ASymbol: TNXPasSymbol;
    const AIndent: string);
  var
    lChildIdx: Integer;
  begin
    if ASymbol = nil then
      Exit;

    if ASymbol.Kind = pskRoutine then
    begin
      AReport.Add(AIndent + 'routine name=' + ASymbol.Name +
        ' parent=' + NXPasRoutineOwnerName(ASymbol) +
        ' range=' + RangeText(ASymbol.Range) +
        ' identity=' + NXPasRoutineIdentity(ASymbol));

      lMatch := TNXPasWorkspaceSymbolMatch.Create;
      try
        lMatch.FileRef := AFile;
        lMatch.Symbol := ASymbol;
        AReport.Add(AIndent + '  implementation=' +
          BoolText(IsImplementationSymbol(lMatch)));
      finally
        FreeAndNil(lMatch);
      end;
    end;

    for lChildIdx := 0 to ASymbol.ChildCount - 1 do
      AddRoutineSymbol(AFile, ASymbol.Children[lChildIdx], AIndent + '  ');
  end;

begin
  if AReport = nil then
    Exit;

  AReport.Add('routine-pair-diagnostics');
  AReport.Add('direction=' + BoolText(AImplementation));
  if (AParams = nil) or (AParams.textDocument = nil) or
    (AParams.position = nil) then
  begin
    AReport.Add('params=missing');
    Exit;
  end;

  lURI := AParams.textDocument.uri.Value;
  lLine := AParams.position.line.Value;
  lColumn := AParams.position.character.Value;
  AReport.Add('uri=' + lURI);
  AReport.Add(Format('position=%d:%d', [lLine, lColumn]));
  AReport.Add('file-count=' + IntToStr(WorkspaceIndex.FileCount));

  for lFileIdx := 0 to WorkspaceIndex.FileCount - 1 do
  begin
    lFile := WorkspaceIndex.Files[lFileIdx];
    if lFile = nil then
      Continue;

    AReport.Add('file[' + IntToStr(lFileIdx) + '].uri=' + lFile.URI);
    AReport.Add('file[' + IntToStr(lFileIdx) + '].matches-uri=' +
      BoolText(SameText(lFile.URI, lURI)));
    AReport.Add('file[' + IntToStr(lFileIdx) + '].symbol-count=' +
      IntToStr(lFile.Symbols.Count));

    for lSymbolIdx := 0 to lFile.Symbols.Count - 1 do
      AddRoutineSymbol(lFile, lFile.Symbols.SymbolAt(lSymbolIdx), '  ');
  end;

  lMatch := nil;
  lPair := nil;
  try
    if TryFindRoutineAtPosition(lURI, lLine, lColumn, lMatch) then
    begin
      AReport.Add('routine-at-position=true');
      AReport.Add('source.name=' + lMatch.Symbol.Name);
      AReport.Add('source.range=' + RangeText(lMatch.Symbol.Range));
      AReport.Add('source.identity=' + NXPasRoutineIdentity(lMatch.Symbol));
      AReport.Add('source.implementation=' +
        BoolText(IsImplementationSymbol(lMatch)));

      if FindRoutinePairByIdentity(lMatch, AImplementation, lPair) then
      begin
        AReport.Add('pair-found=true');
        AReport.Add('pair.name=' + lPair.Symbol.Name);
        AReport.Add('pair.range=' + RangeText(lPair.Symbol.Range));
        AReport.Add('pair.identity=' + NXPasRoutineIdentity(lPair.Symbol));
        AReport.Add('pair.implementation=' +
          BoolText(IsImplementationSymbol(lPair)));
      end
      else
        AReport.Add('pair-found=false');
    end
    else
      AReport.Add('routine-at-position=false');
  finally
    lPair.Free;
    lMatch.Free;
  end;
end;

procedure TNXLSNavigationService.FillReferences(AParams: TNXLSReferenceParams;
  AResult: TNXLSLocationArray);
var
  lDocument: TNXLSDocument;
  lIdentifierRange: TNXPasSourceRange;
  lIncludeDeclaration: Boolean;
  lIdx: Integer;
  lName: string;
  lReferences: TNXPasReferenceMatchList;
  lSource: TNXPasSourceFile;
begin
  if AResult = nil then
    Exit;

  AResult.Assigned := True;
  if (AParams = nil) or (AParams.textDocument = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lSource := TNXPasSourceFile.Create(lDocument.LocalPath, lDocument.URI,
    lDocument.Text);
  lReferences := TNXPasReferenceMatchList.Create(True);
  try
    if not TNXPasLookup.IdentifierAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value, lName,
      lIdentifierRange) then
      Exit;

    lIncludeDeclaration := True;
    if (AParams.context <> nil) and (AParams.context.includeDeclaration <> nil)
      and AParams.context.includeDeclaration.Assigned then
      lIncludeDeclaration := AParams.context.includeDeclaration.Value;

    TNXPasLookup.FindLexicalIdentifierReferences(WorkspaceIndex, lName,
      lIncludeDeclaration, lReferences);
    for lIdx := 0 to lReferences.Count - 1 do
      AddReferenceLocation(AResult, lReferences.MatchAt(lIdx));
  finally
    lReferences.Free;
    lSource.Free;
  end;
end;

function TNXLSNavigationService.FindIdentifierAtParams(
  AParams: TNXLSTextDocumentPositionParams; out ADocument: TNXLSDocument;
  out AName: string): Boolean;
var
  lIdentifierRange: TNXPasSourceRange;
  lSource: TNXPasSourceFile;
begin
  Result := False;
  ADocument := nil;
  AName := '';
  if (AParams = nil) or (AParams.textDocument = nil) then
    Exit;

  ADocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lSource := TNXPasSourceFile.Create(ADocument.LocalPath, ADocument.URI,
    ADocument.Text);
  try
    Result := TNXPasLookup.IdentifierAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value, AName,
      lIdentifierRange);
  finally
    lSource.Free;
  end;
end;

function TNXLSNavigationService.FindSymbol(const AName, AURI: string;
  out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lMatches: TNXPasWorkspaceSymbolMatchList;
begin
  Result := False;
  AMatch := nil;
  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    WorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    if lMatches.Count = 0 then
    begin
      Model.PascalLanguage.EnsureUsedUnitsIndexedForURI(AURI);
      WorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    end;
    if lMatches.Count = 0 then
      Exit;

    AMatch := lMatches.MatchAt(0);
    lMatches.Extract(AMatch);
    Result := True;
  finally
    lMatches.Free;
  end;
end;

function TNXLSNavigationService.FindRoutinePairByIdentity(
  ASource: TNXPasWorkspaceSymbolMatch; AImplementation: Boolean;
  out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lIdentity: string;
  lSymbolIdx: Integer;

  function SearchSymbol(ASymbol: TNXPasSymbol): Boolean;
  var
    lChildIdx: Integer;
  begin
    Result := False;
    if ASymbol = nil then
      Exit;

    if (ASymbol.Kind = pskRoutine) and (ASymbol <> ASource.Symbol) and
      (NXPasRoutineIdentity(ASymbol) = lIdentity) then
    begin
      AMatch := TNXPasWorkspaceSymbolMatch.Create;
      AMatch.FileRef := lFile;
      AMatch.Symbol := ASymbol;
      Result := IsImplementationSymbol(AMatch) = AImplementation;
      if Result then
        Exit;
      FreeAndNil(AMatch);
    end;

    for lChildIdx := 0 to ASymbol.ChildCount - 1 do
      if SearchSymbol(ASymbol.Children[lChildIdx]) then
        Exit(True);
  end;

begin
  Result := False;
  AMatch := nil;
  if (ASource = nil) or (ASource.Symbol = nil) then
    Exit;

  lIdentity := NXPasRoutineIdentity(ASource.Symbol);
  if lIdentity = '' then
    Exit;

  for lFileIdx := 0 to WorkspaceIndex.FileCount - 1 do
  begin
    lFile := WorkspaceIndex.Files[lFileIdx];
    if lFile = nil then
      Continue;

    for lSymbolIdx := 0 to lFile.Symbols.Count - 1 do
      if SearchSymbol(lFile.Symbols.SymbolAt(lSymbolIdx)) then
        Exit(True);
  end;
end;

function TNXLSNavigationService.FindSymbolAtPosition(const AName,
  AURI: string; ALine, AColumn: Integer;
  out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lIdx: Integer;
  lMatches: TNXPasWorkspaceSymbolMatchList;
begin
  Result := False;
  AMatch := nil;
  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    WorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    if lMatches.Count = 0 then
    begin
      Model.PascalLanguage.EnsureUsedUnitsIndexedForURI(AURI);
      WorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    end;
    for lIdx := 0 to lMatches.Count - 1 do
      if NXPasSymbolIsRoutineOwned(lMatches.MatchAt(lIdx).Symbol) and
        NXPasSymbolIsVisibleAt(lMatches.MatchAt(lIdx).Symbol, ALine, AColumn) then
      begin
        AMatch := lMatches.MatchAt(lIdx);
        lMatches.Extract(AMatch);
        Exit(True);
      end;

    for lIdx := 0 to lMatches.Count - 1 do
      if (not NXPasSymbolIsRoutineOwned(lMatches.MatchAt(lIdx).Symbol)) and
        NXPasSymbolIsVisibleAt(lMatches.MatchAt(lIdx).Symbol, ALine, AColumn) then
      begin
        AMatch := lMatches.MatchAt(lIdx);
        lMatches.Extract(AMatch);
        Exit(True);
      end;
  finally
    lMatches.Free;
  end;
end;

function TNXLSNavigationService.ResolveMemberAtParams(
  AParams: TNXLSTextDocumentPositionParams; out AIsMemberAccess: Boolean;
  out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lDocument: TNXLSDocument;
  lMember: TNXPasSymbol;
  lMemberName: string;
  lMemberRange: TNXPasSourceRange;
  lReceiverMatch: TNXPasWorkspaceSymbolMatch;
  lReceiverName: string;
  lSource: TNXPasSourceFile;
  lTypeMatch: TNXPasWorkspaceSymbolMatch;
begin
  Result := False;
  AIsMemberAccess := False;
  AMatch := nil;
  if (AParams = nil) or (AParams.textDocument = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lSource := TNXPasSourceFile.Create(lDocument.LocalPath, lDocument.URI,
    lDocument.Text);
  try
    AIsMemberAccess := TNXPasMemberLookup.DetectMemberAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value,
      lReceiverName, lMemberName, lMemberRange);
    if not AIsMemberAccess then
      Exit;
  finally
    lSource.Free;
  end;

  lReceiverMatch := nil;
  lTypeMatch := nil;
  try
    if not TNXPasMemberLookup.ResolveReceiverType(WorkspaceIndex,
      lDocument.URI, lReceiverName, AParams.position.line.Value,
      AParams.position.character.Value, lReceiverMatch, lTypeMatch) then
      Exit;

    if not TNXPasMemberLookup.FindDirectMember(lTypeMatch.Symbol, lMemberName,
      lMember) then
      Exit;

    AMatch := TNXPasWorkspaceSymbolMatch.Create;
    AMatch.FileRef := lTypeMatch.FileRef;
    AMatch.Symbol := lMember;
    Result := True;
  finally
    lTypeMatch.Free;
    lReceiverMatch.Free;
  end;
end;

function TNXLSNavigationService.FindRoutinePair(const AName, AURI: string;
  AImplementation: Boolean; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lIdx: Integer;
  lMatches: TNXPasWorkspaceSymbolMatchList;
  lMatch: TNXPasWorkspaceSymbolMatch;
begin
  Result := False;
  AMatch := nil;
  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    WorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    for lIdx := 0 to lMatches.Count - 1 do
    begin
      lMatch := lMatches.MatchAt(lIdx);
      if (lMatch.FileRef = nil) or (lMatch.Symbol = nil) or
        (not SameText(lMatch.FileRef.URI, AURI)) or
        (lMatch.Symbol.Kind <> pskRoutine) then
        Continue;

      if IsImplementationSymbol(lMatch) = AImplementation then
      begin
        AMatch := lMatch;
        lMatches.Extract(AMatch);
        Exit(True);
      end;
    end;
  finally
    lMatches.Free;
  end;
end;

function TNXLSNavigationService.FillLocationFromSymbol(
  AMatch: TNXPasWorkspaceSymbolMatch; AResult: TNXLSLocation): Boolean;
var
  lRange: TNXPasSourceRange;

  function RangeAssigned(const ARange: TNXPasSourceRange): Boolean;
  begin
    Result := ARange.StartPos.Offset > 0;
  end;
begin
  Result := (AMatch <> nil) and (AMatch.FileRef <> nil) and
    (AMatch.Symbol <> nil) and (AResult <> nil);
  if not Result then
    Exit;

  lRange := AMatch.Symbol.Range;
  if RangeAssigned(AMatch.Symbol.NameRange) then
    lRange := AMatch.Symbol.NameRange
  else
    TNXPasLookup.FindSymbolIdentifierRange(AMatch.FileRef, AMatch.Symbol.Name,
      AMatch.Symbol.Range, lRange);

  AResult.uri.Value := AMatch.FileRef.URI;
  SetRange(AResult.range, lRange.StartPos.Line, lRange.StartPos.Column,
    lRange.EndPos.Line, lRange.EndPos.Column);
  AResult.Assigned := True;
end;

function TNXLSNavigationService.FillLocationFromUnitFile(const AName: string;
  AResult: TNXLSLocation): Boolean;
var
  lFile: TNXPasIndexedFile;
  lRange: TNXPasSourceRange;
  lSymbol: TNXPasSymbol;
begin
  Result := False;
  if AResult = nil then
    Exit;

  lFile := Model.PascalLanguage.ResolveUnitReference(AName);
  if lFile = nil then
    Exit;

  AResult.uri.Value := lFile.URI;
  if lFile.Symbols.Count > 0 then
  begin
    lSymbol := lFile.Symbols.SymbolAt(0);
    lRange := lSymbol.Range;
    TNXPasLookup.FindSymbolIdentifierRange(lFile, lSymbol.Name,
      lSymbol.Range, lRange);
    SetRange(AResult.range, lRange.StartPos.Line, lRange.StartPos.Column,
      lRange.EndPos.Line, lRange.EndPos.Column);
  end
  else
    SetRange(AResult.range, 0, 0, 0, 0);
  AResult.Assigned := True;
  Result := True;
end;

function TNXLSNavigationService.FillLocationFromDeclaredType(
  AMatch: TNXPasWorkspaceSymbolMatch; AURI: string;
  AResult: TNXLSLocation): Boolean;
var
  lTypeMatch: TNXPasWorkspaceSymbolMatch;
begin
  Result := False;
  if (AMatch = nil) or (AMatch.Symbol = nil) or
    (AMatch.Symbol.DeclaredTypeText = '') then
    Exit;

  if FindSymbol(AMatch.Symbol.DeclaredTypeText, AURI, lTypeMatch) then
  try
    if lTypeMatch.Symbol.Kind in [pskType, pskClass, pskRecord, pskObject,
      pskInterface] then
      Result := FillLocationFromSymbol(lTypeMatch, AResult);
  finally
    lTypeMatch.Free;
  end;
end;

function TNXLSNavigationService.ImplementationLine(
  AFile: TNXPasIndexedFile): Integer;
var
  lIdx: Integer;
  lLines: TStringList;
begin
  Result := MaxInt;
  if AFile = nil then
    Exit;

  lLines := TStringList.Create;
  try
    lLines.Text := AFile.Text;
    for lIdx := 0 to lLines.Count - 1 do
      if SameText(Trim(lLines[lIdx]), 'implementation') then
        Exit(lIdx);
  finally
    lLines.Free;
  end;
end;

function TNXLSNavigationService.IsImplementationSymbol(
  AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
begin
  Result := (AMatch <> nil) and (AMatch.FileRef <> nil) and
    (AMatch.Symbol <> nil) and
    (AMatch.Symbol.Range.StartPos.Line > ImplementationLine(AMatch.FileRef));
end;

function TNXLSNavigationService.TryFindRoutineAtPosition(const AURI: string;
  ALine, AColumn: Integer; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lBestFile: TNXPasIndexedFile;
  lBestRangeSize: Integer;
  lBestSymbol: TNXPasSymbol;
  lFile: TNXPasIndexedFile;
  lFileIdx: Integer;
  lSymbolIdx: Integer;

  function RangeSize(ASymbol: TNXPasSymbol): Integer;
  begin
    Result := MaxInt;
    if ASymbol <> nil then
      Result := ASymbol.Range.EndPos.Offset - ASymbol.Range.StartPos.Offset;
  end;

  procedure ConsiderSymbol(AFile: TNXPasIndexedFile; ASymbol: TNXPasSymbol);
  var
    lChildIdx: Integer;
    lSize: Integer;
  begin
    if ASymbol = nil then
      Exit;

    if (ASymbol.Kind = pskRoutine) and
      NXPasRangeContains(ASymbol.Range, ALine, AColumn) then
    begin
      lSize := RangeSize(ASymbol);
      if (lBestSymbol = nil) or (lSize < lBestRangeSize) then
      begin
        lBestFile := AFile;
        lBestRangeSize := lSize;
        lBestSymbol := ASymbol;
      end;
    end;

    for lChildIdx := 0 to ASymbol.ChildCount - 1 do
      ConsiderSymbol(AFile, ASymbol.Children[lChildIdx]);
  end;

begin
  Result := False;
  AMatch := nil;
  lBestFile := nil;
  lBestRangeSize := MaxInt;
  lBestSymbol := nil;

  for lFileIdx := 0 to WorkspaceIndex.FileCount - 1 do
  begin
    lFile := WorkspaceIndex.Files[lFileIdx];
    if (lFile = nil) or (not SameText(lFile.URI, AURI)) then
      Continue;

    for lSymbolIdx := 0 to lFile.Symbols.Count - 1 do
      ConsiderSymbol(lFile, lFile.Symbols.SymbolAt(lSymbolIdx));
  end;

  if (lBestFile = nil) or (lBestSymbol = nil) then
    Exit;

  AMatch := TNXPasWorkspaceSymbolMatch.Create;
  AMatch.FileRef := lBestFile;
  AMatch.Symbol := lBestSymbol;
  Result := True;
end;

procedure TNXLSNavigationService.AddReferenceLocation(AResult: TNXLSLocationArray;
  AMatch: TNXPasReferenceMatch);
var
  lLocation: TNXLSLocation;
begin
  if (AResult = nil) or (AMatch = nil) or (AMatch.FileRef = nil) then
    Exit;

  lLocation := TNXLSLocation(AResult.AddObject(TNXLSLocation));
  lLocation.uri.Value := AMatch.FileRef.URI;
  SetRange(lLocation.range, AMatch.Range.StartPos.Line,
    AMatch.Range.StartPos.Column, AMatch.Range.EndPos.Line,
    AMatch.Range.EndPos.Column);
  lLocation.Assigned := True;
end;

procedure TNXLSNavigationService.SetRange(ARange: TNXLSRange; AStartLine,
  AStartColumn, AEndLine, AEndColumn: Integer);
begin
  NXLSSetPosition(ARange.start, AStartLine, AStartColumn);
  NXLSSetPosition(ARange.&end, AEndLine, AEndColumn);
  ARange.Assigned := True;
end;

function TNXLSNavigationService.WorkspaceIndex: TNXPasWorkspaceIndex;
begin
  Result := Model.PascalLanguage.WorkspaceIndex;
end;

end.
