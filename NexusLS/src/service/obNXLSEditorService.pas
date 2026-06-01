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
    FWorkspaceIndex: TNXPasWorkspaceIndex;
    function FindSymbol(const AName, AURI: string;
      out AMatch: TNXPasWorkspaceSymbolMatch): Boolean;
    function HoverText(AMatch: TNXPasWorkspaceSymbolMatch): string;
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
    procedure RebuildWorkspaceIndex;
    procedure ReindexDocument(ADocument: TNXLSDocument);
  end;

implementation

uses
  SysUtils,
  obNXPasCompletion,
  obNXPasLookup,
  obNXPasSignatures,
  obNXPasSource,
  obNXPasSymbols;

constructor TNXLSEditorService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create(AModel);
  FWorkspaceIndex := TNXPasWorkspaceIndex.Create;
end;

destructor TNXLSEditorService.Destroy;
begin
  FreeAndNil(FWorkspaceIndex);
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
  lIdentifierRange: TNXPasSourceRange;
  lIdx: Integer;
  lName: string;
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
    if TNXPasCompletionHelper.CompletionSuppressedAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value) then
      Exit;

    if not TNXPasLookup.IdentifierAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value, lName,
      lIdentifierRange) then
      Exit;

    lTempIndex.UpdateSourceFile(lSource);
    TNXPasLookup.FindReferences(lTempIndex, lName, True, lReferences);
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
    if TNXPasCompletionHelper.CompletionSuppressedAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value) then
      Exit;

    if not TNXPasLookup.IdentifierAtPosition(lSource,
      AParams.position.line.Value, AParams.position.character.Value, lName,
      lIdentifierRange) then
      Exit;

    if not FindSymbol(lName, lDocument.URI, lMatch) then
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

  Result := LowerCase(NXPasSymbolKindName(AMatch.Symbol.Kind)) + ' ' +
    AMatch.Symbol.Name;
end;

procedure TNXLSEditorService.RebuildWorkspaceIndex;
var
  lIdx: Integer;
begin
  FWorkspaceIndex.Clear;
  for lIdx := 0 to Model.DocumentCount - 1 do
    ReindexDocument(Model.DocumentByIndex(lIdx));
end;

procedure TNXLSEditorService.ReindexDocument(ADocument: TNXLSDocument);
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

procedure TNXLSEditorService.SetRange(ARange: TNXLSRange; AStartLine,
  AStartColumn, AEndLine, AEndColumn: Integer);
begin
  NXLSSetPosition(ARange.start, AStartLine, AStartColumn);
  NXLSSetPosition(ARange.&end, AEndLine, AEndColumn);
  ARange.Assigned := True;
end;

end.
