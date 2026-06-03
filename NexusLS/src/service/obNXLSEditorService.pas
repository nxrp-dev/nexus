unit obNXLSEditorService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext,
  obNXPasWorkspaceIndex;

type
  TNXLSEditorService = class(TNXLSLSPService)
  private
    function FindIndexedFile(const AURI: string): TNXPasIndexedFile;
    function FindSymbol(const AName, AURI: string;
      out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function FindSymbolAtPosition(const AName, AURI: string; ALine,
      AColumn: Integer; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function HoverText(AMatch: TNXPasWorkspaceSymbolMatch): string;
    function PositionIsInactive(AFile: TNXPasIndexedFile; ALine,
      AColumn: Integer): Boolean;
    function ResolveMemberAtParams(AParams: TNXLSTextDocumentPositionParams;
      out AIsMemberAccess: Boolean;
      out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function WorkspaceIndex: TNXPasWorkspaceIndex;
    procedure SetRange(ARange: TNXLSRange; AStartLine, AStartColumn,
      AEndLine, AEndColumn: Integer);
  public
    constructor Create(AModel: TNXLSLSPContext); override;
    destructor Destroy; override;
    procedure FillCodeActions(AParams: TNXLSCodeActionParams;
      AResult: TNXLSCodeActionArray); virtual;
    procedure FillDocumentHighlights(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSDocumentHighlightArray); virtual;
    function FillHover(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSHover): Boolean; virtual;
    procedure FillInlayHints(AParams: TNXLSInlayHintParams;
      AResult: TNXLSInlayHintArray); virtual;
  end;

implementation

uses
  SysUtils,
  obNXPasCompletion,
  obNXPasDocumentHighlights,
  obNXPasLookup,
  obNXPasMemberLookup,
  obNXPasSignatures,
  obNXPasSource,
  obNXPasSymbols;

constructor TNXLSEditorService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create(AModel);
end;

destructor TNXLSEditorService.Destroy;
begin
  inherited Destroy;
end;

procedure TNXLSEditorService.FillCodeActions(AParams: TNXLSCodeActionParams;
  AResult: TNXLSCodeActionArray);
begin
  if AResult <> nil then
    AResult.Assigned := True;
end;

procedure TNXLSEditorService.FillDocumentHighlights(
  AParams: TNXLSTextDocumentPositionParams; AResult: TNXLSDocumentHighlightArray);
var
  lDocument: TNXLSDocument;
  lHighlight: TNXLSDocumentHighlight;
  lIdx: Integer;
  lIndexedFile: TNXPasIndexedFile;
  lReferences: TNXPasReferenceMatchList;
  lSource: TNXPasSourceFile;
  lTempIndex: TNXPasWorkspaceIndex;
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
  lTempIndex := TNXPasWorkspaceIndex.Create;
  try
    lIndexedFile := FindIndexedFile(lDocument.URI);
    if PositionIsInactive(lIndexedFile, AParams.position.line.Value,
      AParams.position.character.Value) then
      Exit;

    if TNXPasCompletionHelper.CompletionSuppressedAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value) then
      Exit;

    lTempIndex.UpdateSourceFile(lSource);
    TNXPasDocumentHighlightResolver.FindDocumentHighlights(lTempIndex,
      lDocument.URI, AParams.position.line.Value,
      AParams.position.character.Value, lReferences);
    for lIdx := 0 to lReferences.Count - 1 do
    begin
      lHighlight := TNXLSDocumentHighlight(
        AResult.AddObject(TNXLSDocumentHighlight));
      SetRange(lHighlight.range, lReferences.MatchAt(lIdx).Range.StartPos.Line,
        lReferences.MatchAt(lIdx).Range.StartPos.Column,
        lReferences.MatchAt(lIdx).Range.EndPos.Line,
        lReferences.MatchAt(lIdx).Range.EndPos.Column);
      lHighlight.kind.Value := 1;
      lHighlight.Assigned := True;
    end;
  finally
    lTempIndex.Free;
    lReferences.Free;
    lSource.Free;
  end;
end;

function TNXLSEditorService.FillHover(AParams: TNXLSTextDocumentPositionParams;
  AResult: TNXLSHover): Boolean;
var
  lDocument: TNXLSDocument;
  lIdentifierRange: TNXPasSourceRange;
  lIndexedFile: TNXPasIndexedFile;
  lIsMemberAccess: Boolean;
  lMatch: TNXPasWorkspaceSymbolMatch;
  lName: string;
  lRange: TNXPasSourceRange;
  lSource: TNXPasSourceFile;
begin
  Result := False;
  if (AParams = nil) or (AParams.textDocument = nil) or (AResult = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lSource := TNXPasSourceFile.Create(lDocument.LocalPath, lDocument.URI,
    lDocument.Text);
  try
    lIndexedFile := FindIndexedFile(lDocument.URI);
    if PositionIsInactive(lIndexedFile, AParams.position.line.Value,
      AParams.position.character.Value) then
      Exit;

    if TNXPasCompletionHelper.CompletionSuppressedAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value) then
      Exit;

    if not TNXPasLookup.IdentifierAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value, lName,
      lIdentifierRange) then
      Exit;

    if ResolveMemberAtParams(AParams, lIsMemberAccess, lMatch) then
    try
      AResult.contents.kind.Value := 'plaintext';
      AResult.contents.value.Value := HoverText(lMatch);
      lRange := lMatch.Symbol.Range;
      TNXPasLookup.FindSymbolIdentifierRange(lMatch.FileRef,
        lMatch.Symbol.Name, lMatch.Symbol.Range, lRange);
      SetRange(AResult.range, lRange.StartPos.Line, lRange.StartPos.Column,
        lRange.EndPos.Line, lRange.EndPos.Column);
      AResult.Assigned := True;
      Exit(True);
    finally
      lMatch.Free;
    end
    else if lIsMemberAccess then
      Exit;

    if not FindSymbolAtPosition(lName, lDocument.URI,
      AParams.position.line.Value, AParams.position.character.Value,
      lMatch) then
      Exit;
    try
      AResult.contents.kind.Value := 'plaintext';
      AResult.contents.value.Value := HoverText(lMatch);
      lRange := lMatch.Symbol.Range;
      TNXPasLookup.FindSymbolIdentifierRange(lMatch.FileRef,
        lMatch.Symbol.Name, lMatch.Symbol.Range, lRange);
      SetRange(AResult.range, lRange.StartPos.Line, lRange.StartPos.Column,
        lRange.EndPos.Line, lRange.EndPos.Column);
      AResult.Assigned := True;
      Result := True;
    finally
      lMatch.Free;
    end;
  finally
    lSource.Free;
  end;
end;

procedure TNXLSEditorService.FillInlayHints(AParams: TNXLSInlayHintParams;
  AResult: TNXLSInlayHintArray);
begin
  if AResult <> nil then
    AResult.Assigned := True;
end;

function TNXLSEditorService.FindIndexedFile(
  const AURI: string): TNXPasIndexedFile;
var
  lIdx: Integer;
begin
  Result := nil;
  for lIdx := 0 to WorkspaceIndex.FileCount - 1 do
    if SameText(WorkspaceIndex.Files[lIdx].URI, AURI) then
      Exit(WorkspaceIndex.Files[lIdx]);
end;

function TNXLSEditorService.FindSymbol(const AName, AURI: string;
  out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lMatches: TNXPasWorkspaceSymbolMatchList;
begin
  Result := False;
  AMatch := nil;
  if Trim(AName) = '' then
    Exit;

  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    WorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
    if lMatches.Count = 0 then
      Exit;

    AMatch := lMatches.MatchAt(0);
    lMatches.Extract(AMatch);
    Result := True;
  finally
    lMatches.Free;
  end;
end;

function TNXLSEditorService.FindSymbolAtPosition(const AName, AURI: string;
  ALine, AColumn: Integer; out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
var
  lIdx: Integer;
  lMatches: TNXPasWorkspaceSymbolMatchList;
begin
  Result := False;
  AMatch := nil;
  if Trim(AName) = '' then
    Exit;

  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    WorkspaceIndex.FindSymbolsByName(AName, AURI, lMatches);
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

function TNXLSEditorService.PositionIsInactive(AFile: TNXPasIndexedFile;
  ALine, AColumn: Integer): Boolean;
var
  lIdx: Integer;
  lRange: TNXPasSourceRange;
begin
  Result := False;
  if AFile = nil then
    Exit;

  for lIdx := 0 to AFile.Metadata.InactiveRegions.Count - 1 do
  begin
    lRange := AFile.Metadata.InactiveRegions.RegionAt(lIdx).Range;
    if (ALine < lRange.StartPos.Line) or (ALine > lRange.EndPos.Line) then
      Continue;
    if (ALine = lRange.StartPos.Line) and
      (AColumn < lRange.StartPos.Column) then
      Continue;
    if (ALine = lRange.EndPos.Line) and
      (AColumn > lRange.EndPos.Column) then
      Continue;
    Exit(True);
  end;
end;

function TNXLSEditorService.ResolveMemberAtParams(
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

function TNXLSEditorService.HoverText(AMatch: TNXPasWorkspaceSymbolMatch): string;
var
  lSignature: TNXPasRoutineSignature;
begin
  Result := '';
  if (AMatch = nil) or (AMatch.Symbol = nil) then
    Exit;

  if AMatch.Symbol.Kind = pskRoutine then
  begin
    lSignature := TNXPasRoutineSignature.Create;
    try
      if TNXPasSignatureHelper.ExtractSignature(AMatch.FileRef, AMatch.Symbol,
        lSignature) then
        Exit(lSignature.&Label);
    finally
      lSignature.Free;
    end;
  end;

  if AMatch.Symbol.DeclaredTypeText <> '' then
  begin
    Result := LowerCase(NXPasSymbolKindName(AMatch.Symbol.Kind)) + ' ' +
      AMatch.Symbol.Name + ': ' + AMatch.Symbol.DeclaredTypeText;
    Exit;
  end;

  Result := LowerCase(NXPasSymbolKindName(AMatch.Symbol.Kind)) + ' ' +
    AMatch.Symbol.Name;
end;

procedure TNXLSEditorService.SetRange(ARange: TNXLSRange; AStartLine,
  AStartColumn, AEndLine, AEndColumn: Integer);
begin
  NXLSSetPosition(ARange.start, AStartLine, AStartColumn);
  NXLSSetPosition(ARange.&end, AEndLine, AEndColumn);
  ARange.Assigned := True;
end;

function TNXLSEditorService.WorkspaceIndex: TNXPasWorkspaceIndex;
begin
  Result := Model.PascalLanguage.WorkspaceIndex;
end;

end.
