unit obNXLSNavigationService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext,
  obNXPasLookup,
  obNXPasWorkspaceIndex;

type
  TNXLSNavigationService = class(TNXLSLSPService)
  private
    FWorkspaceIndex: TNXPasWorkspaceIndex;
    procedure AddReferenceLocation(AResult: TNXLSLocationArray;
      AMatch: TNXPasReferenceMatch);
    function FindIdentifierAtParams(AParams: TNXLSTextDocumentPositionParams;
      out ADocument: TNXLSDocument; out AName: string): Boolean;
    function FindRoutinePair(const AName, AURI: string;
      AImplementation: Boolean; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FindSymbol(const AName, AURI: string;
      out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FindSymbolAtPosition(const AName, AURI: string; ALine,
      AColumn: Integer; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FillLocationFromSymbol(AMatch: TNXPasWorkspaceSymbolMatch;
      AResult: TNXLSLocation): Boolean;
    function FillLocationFromDeclaredType(AMatch: TNXPasWorkspaceSymbolMatch;
      AURI: string; AResult: TNXLSLocation): Boolean;
    function ImplementationLine(AFile: TNXPasIndexedFile): Integer;
    function IsImplementationSymbol(AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
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
    function FillTypeDefinition(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSLocation): Boolean; virtual;
    procedure FillReferences(AParams: TNXLSReferenceParams;
      AResult: TNXLSLocationArray); virtual;
    procedure RebuildWorkspaceIndex;
    procedure ReindexDocument(ADocument: TNXLSDocument);
  end;

implementation

uses
  Classes,
  SysUtils,
  obNXPasSymbols,
  obNXPasSource;

constructor TNXLSNavigationService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create(AModel);
  FWorkspaceIndex := TNXPasWorkspaceIndex.Create;
end;

destructor TNXLSNavigationService.Destroy;
begin
  FreeAndNil(FWorkspaceIndex);
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
  end;
end;

function TNXLSNavigationService.FillDefinition(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lDocument: TNXLSDocument;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lName: string;
begin
  Result := False;
  if not FindIdentifierAtParams(AParams, lDocument, lName) then
    Exit;

  if FindSymbol(lName, lDocument.URI, lMatch) then
  try
    Result := FillLocationFromSymbol(lMatch, AResult);
  finally
    lMatch.Free;
  end;
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

function TNXLSNavigationService.FillTypeDefinition(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSLocation): Boolean;
var
  lDocument: TNXLSDocument;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lName: string;
begin
  Result := False;
  if not FindIdentifierAtParams(AParams, lDocument, lName) then
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

    TNXPasLookup.FindReferences(FWorkspaceIndex, lName, lIncludeDeclaration,
      lReferences);
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
    FWorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    if lMatches.Count = 0 then
      Exit;

    AMatch := lMatches.MatchAt(0);
    lMatches.Extract(AMatch);
    Result := True;
  finally
    lMatches.Free;
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
    FWorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
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
    FWorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
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
begin
  Result := (AMatch <> nil) and (AMatch.FileRef <> nil) and
    (AMatch.Symbol <> nil) and (AResult <> nil);
  if not Result then
    Exit;

  lRange := AMatch.Symbol.Range;
  TNXPasLookup.FindSymbolIdentifierRange(AMatch.FileRef, AMatch.Symbol.Name,
    AMatch.Symbol.Range, lRange);

  AResult.uri.Value := AMatch.FileRef.URI;
  SetRange(AResult.range, lRange.StartPos.Line, lRange.StartPos.Column,
    lRange.EndPos.Line, lRange.EndPos.Column);
  AResult.Assigned := True;
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

procedure TNXLSNavigationService.RebuildWorkspaceIndex;
var
  lIdx: Integer;
begin
  FWorkspaceIndex.Clear;
  for lIdx := 0 to Model.DocumentCount - 1 do
    ReindexDocument(Model.DocumentByIndex(lIdx));
end;

procedure TNXLSNavigationService.ReindexDocument(ADocument: TNXLSDocument);
var
  lSource: TNXPasSourceFile;
begin
  if ADocument = nil then
    Exit;

  lSource := TNXPasSourceFile.Create(ADocument.LocalPath, ADocument.URI,
    ADocument.Text);
  try
    FWorkspaceIndex.UpdateSourceFile(lSource);
  finally
    lSource.Free;
  end;
end;

procedure TNXLSNavigationService.SetRange(ARange: TNXLSRange; AStartLine,
  AStartColumn, AEndLine, AEndColumn: Integer);
begin
  NXLSSetPosition(ARange.start, AStartLine, AStartColumn);
  NXLSSetPosition(ARange.&end, AEndLine, AEndColumn);
  ARange.Assigned := True;
end;

end.
