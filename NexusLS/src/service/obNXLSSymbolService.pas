unit obNXLSSymbolService;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXPasSymbols,
  obNXPasWorkspaceIndex;

type
  TNXLSSymbolService = class(TNXLSLSPService)
  private
    FWorkspaceIndex: TNXPasWorkspaceIndex;
    FWorkspaceFolders: TStringList;
    procedure ClearWorkspaceFolders;
    procedure AddWorkspaceFolderPath(const APath: string);
    procedure AddWorkspaceFolderURI(const AURI: string);
    procedure RemoveWorkspaceFolderURI(const AURI: string);
    function LSPKindForSymbol(AKind: Integer): Integer;
    procedure AddDocumentSymbol(AParent: TNXJSONArray; ASymbol: TNXPasSymbol);
    procedure AddWorkspaceSymbol(AParent: TNXJSONArray;
      AMatch: TNXPasWorkspaceSymbolMatch);
    procedure SetRange(ARange: TNXLSRange; AStartLine, AStartColumn,
      AEndLine, AEndColumn: Integer);
  public
    constructor Create(AModel: TNXLSLSPContext); override;
    destructor Destroy; override;

    procedure FillDocumentSymbols(AParams: TNXLSDocumentSymbolParams;
      AResult: TNXJSONArray); virtual;
    procedure FillWorkspaceSymbols(AParams: TNXLSWorkspaceSymbolParams;
      AResult: TNXJSONArray); virtual;
    procedure SetWorkspaceFolders(AParams: TNXLSInitializeParams);
    procedure AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
    procedure RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
    procedure RebuildWorkspaceIndex;
    procedure ReindexDocument(ADocument: TNXLSDocument);
  end;

implementation

uses
  SysUtils,
  obNXPasAST,
  obNXPasDiagnostics,
  obNXPasParser,
  obNXPasSource;

constructor TNXLSSymbolService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create(AModel);
  FWorkspaceIndex := TNXPasWorkspaceIndex.Create;
  FWorkspaceFolders := TStringList.Create;
  FWorkspaceFolders.Sorted := True;
  FWorkspaceFolders.Duplicates := dupIgnore;
end;

destructor TNXLSSymbolService.Destroy;
begin
  FreeAndNil(FWorkspaceFolders);
  FreeAndNil(FWorkspaceIndex);
  inherited Destroy;
end;

procedure TNXLSSymbolService.FillDocumentSymbols(AParams: TNXLSDocumentSymbolParams;
  AResult: TNXJSONArray);
var
  lDocument: TNXLSDocument;
  lSource: TNXPasSourceFile;
  lDiagnostics: TNXPasDiagnosticList;
  lParser: TNXPasParser;
  lTree: TNXPasSyntaxTree;
  lExtractor: TNXPasSymbolExtractor;
  lSymbols: TNXPasSymbolTable;
  lIdx: Integer;
  lSymbol: TNXPasSymbol;
begin
  if (AParams = nil) or (AParams.textDocument = nil) or (AResult = nil) then
    Exit;

  AResult.Assigned := True;
  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);

  lSource := TNXPasSourceFile.Create(lDocument.LocalPath, lDocument.URI,
    lDocument.Text);
  lDiagnostics := TNXPasDiagnosticList.Create(True);
  lParser := TNXPasParser.Create(lDiagnostics);
  lTree := nil;
  lExtractor := TNXPasSymbolExtractor.Create;
  lSymbols := TNXPasSymbolTable.Create(True);
  try
    lTree := lParser.Parse(lSource);
    lExtractor.Extract(lTree, lSymbols);

    for lIdx := 0 to lSymbols.Count - 1 do
    begin
      lSymbol := lSymbols.SymbolAt(lIdx);
      if lSymbol.Kind in [pskUnknown, pskUsesUnit, pskVisibility] then
        Continue;

      AddDocumentSymbol(AResult, lSymbol);
    end;
  finally
    lSymbols.Free;
    lExtractor.Free;
    lTree.Free;
    lParser.Free;
    lDiagnostics.Free;
    lSource.Free;
  end;
end;

procedure TNXLSSymbolService.AddDocumentSymbol(AParent: TNXJSONArray;
  ASymbol: TNXPasSymbol);
var
  lChildIdx: Integer;
  lDocumentSymbol: TNXLSDocumentSymbol;
  lChild: TNXPasSymbol;
begin
  lDocumentSymbol := TNXLSDocumentSymbol(AParent.AddObject(TNXLSDocumentSymbol));
  lDocumentSymbol.name.Value := ASymbol.Name;
  lDocumentSymbol.kind.Value := LSPKindForSymbol(Ord(ASymbol.Kind));
  SetRange(lDocumentSymbol.range, ASymbol.Range.StartPos.Line,
    ASymbol.Range.StartPos.Column, ASymbol.Range.EndPos.Line,
    ASymbol.Range.EndPos.Column);
  SetRange(lDocumentSymbol.selectionRange, ASymbol.Range.StartPos.Line,
    ASymbol.Range.StartPos.Column, ASymbol.Range.EndPos.Line,
    ASymbol.Range.EndPos.Column);

  for lChildIdx := 0 to ASymbol.ChildCount - 1 do
  begin
    lChild := ASymbol.Children[lChildIdx];
    if lChild.Kind in [pskUnknown, pskUsesUnit, pskVisibility] then
      Continue;

    lDocumentSymbol.children.Assigned := True;
    AddDocumentSymbol(lDocumentSymbol.children, lChild);
  end;
end;

procedure TNXLSSymbolService.FillWorkspaceSymbols(AParams: TNXLSWorkspaceSymbolParams;
  AResult: TNXJSONArray);
var
  lIdx: Integer;
  lMatches: TNXPasWorkspaceSymbolMatchList;
  lQuery: string;
begin
  if AResult = nil then
    Exit;

  AResult.Assigned := True;
  lQuery := '';
  if (AParams <> nil) and (AParams.query <> nil) and AParams.query.Assigned then
    lQuery := AParams.query.Value;

  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  try
    FWorkspaceIndex.QuerySymbols(lQuery, lMatches);
    for lIdx := 0 to lMatches.Count - 1 do
      AddWorkspaceSymbol(AResult, lMatches.MatchAt(lIdx));
  finally
    lMatches.Free;
  end;
end;

procedure TNXLSSymbolService.AddWorkspaceSymbol(AParent: TNXJSONArray;
  AMatch: TNXPasWorkspaceSymbolMatch);
var
  lLocation: TNXLSLocation;
  lSymbol: TNXLSWorkspaceSymbol;
begin
  if (AParent = nil) or (AMatch = nil) or (AMatch.Symbol = nil) or
    (AMatch.FileRef = nil) then
    Exit;

  lSymbol := TNXLSWorkspaceSymbol(AParent.AddObject(TNXLSWorkspaceSymbol));
  lSymbol.name.Value := AMatch.Symbol.Name;
  lSymbol.kind.Value := LSPKindForSymbol(Ord(AMatch.Symbol.Kind));
  if AMatch.ContainerName <> '' then
    lSymbol.containerName.Value := AMatch.ContainerName;

  lLocation := TNXLSLocation.Create;
  try
    lLocation.uri.Value := AMatch.FileRef.URI;
    SetRange(lLocation.range, AMatch.Symbol.Range.StartPos.Line,
      AMatch.Symbol.Range.StartPos.Column, AMatch.Symbol.Range.EndPos.Line,
      AMatch.Symbol.Range.EndPos.Column);
    lSymbol.location.Value := lLocation;
    lLocation := nil;
  finally
    lLocation.Free;
  end;
end;

procedure TNXLSSymbolService.ClearWorkspaceFolders;
begin
  FWorkspaceFolders.Clear;
end;

procedure TNXLSSymbolService.AddWorkspaceFolderPath(const APath: string);
var
  lPath: string;
begin
  lPath := Trim(APath);
  if lPath = '' then
    Exit;

  lPath := ExpandFileName(lPath);
  if DirectoryExists(lPath) then
    FWorkspaceFolders.Add(lPath);
end;

procedure TNXLSSymbolService.AddWorkspaceFolderURI(const AURI: string);
begin
  if Trim(AURI) = '' then
    Exit;

  AddWorkspaceFolderPath(NXLSFileURIToPath(AURI));
end;

procedure TNXLSSymbolService.RemoveWorkspaceFolderURI(const AURI: string);
var
  lIdx: Integer;
  lPath: string;
begin
  if Trim(AURI) = '' then
    Exit;

  lPath := ExpandFileName(NXLSFileURIToPath(AURI));
  lIdx := FWorkspaceFolders.IndexOf(lPath);
  if lIdx >= 0 then
    FWorkspaceFolders.Delete(lIdx);
end;

procedure TNXLSSymbolService.SetWorkspaceFolders(AParams: TNXLSInitializeParams);
var
  lIdx: Integer;
  lFolder: TNXLSWorkspaceFolder;
begin
  ClearWorkspaceFolders;

  if AParams = nil then
    Exit;

  if (AParams.workspaceFolders <> nil) and AParams.workspaceFolders.Assigned then
    for lIdx := 0 to AParams.workspaceFolders.Count - 1 do
    begin
      lFolder := TNXLSWorkspaceFolder(AParams.workspaceFolders[lIdx]);
      AddWorkspaceFolderURI(lFolder.uri.Value);
    end;

  if (FWorkspaceFolders.Count = 0) and (AParams.rootUri <> nil) and AParams.rootUri.Assigned then
    AddWorkspaceFolderURI(AParams.rootUri.AsString);

  if (FWorkspaceFolders.Count = 0) and (AParams.rootPath <> nil) and AParams.rootPath.Assigned then
    AddWorkspaceFolderPath(AParams.rootPath.AsString);
end;

procedure TNXLSSymbolService.AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
var
  lIdx: Integer;
  lFolder: TNXLSWorkspaceFolder;
begin
  if AFolders = nil then
    Exit;

  for lIdx := 0 to AFolders.Count - 1 do
  begin
    lFolder := TNXLSWorkspaceFolder(AFolders[lIdx]);
    AddWorkspaceFolderURI(lFolder.uri.Value);
  end;
end;

procedure TNXLSSymbolService.RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
var
  lIdx: Integer;
  lFolder: TNXLSWorkspaceFolder;
begin
  if AFolders = nil then
    Exit;

  for lIdx := 0 to AFolders.Count - 1 do
  begin
    lFolder := TNXLSWorkspaceFolder(AFolders[lIdx]);
    RemoveWorkspaceFolderURI(lFolder.uri.Value);
  end;
end;

procedure TNXLSSymbolService.RebuildWorkspaceIndex;
var
  lIdx: Integer;
begin
  FWorkspaceIndex.Clear;
  for lIdx := 0 to Model.DocumentCount - 1 do
    ReindexDocument(Model.DocumentByIndex(lIdx));
end;

procedure TNXLSSymbolService.ReindexDocument(ADocument: TNXLSDocument);
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

function TNXLSSymbolService.LSPKindForSymbol(AKind: Integer): Integer;
begin
  case TNXPasSymbolKind(AKind) of
    pskUnit, pskProgram, pskLibrary:
      Result := 2;
    pskClass:
      Result := 5;
    pskInterface:
      Result := 11;
    pskRoutine:
      Result := 12;
    pskConst:
      Result := 14;
    pskVariable:
      Result := 13;
    pskField:
      Result := 8;
    pskProperty:
      Result := 7;
    pskRecord:
      Result := 23;
    pskObject:
      Result := 19;
    pskType:
      Result := 26;
  else
    Result := 1;
  end;
end;

procedure TNXLSSymbolService.SetRange(ARange: TNXLSRange; AStartLine,
  AStartColumn, AEndLine, AEndColumn: Integer);
begin
  NXLSSetPosition(ARange.start, AStartLine, AStartColumn);
  NXLSSetPosition(ARange.&end, AEndLine, AEndColumn);
  ARange.Assigned := True;
end;

end.
