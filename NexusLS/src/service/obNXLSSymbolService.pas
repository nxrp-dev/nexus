unit obNXLSSymbolService;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CodeCache,
  Contnrs,
  obNXJSONValues,
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXLSSymbolCache;

type
  TNXLSIndexedSymbol = class
  private
    FName: string;
    FKind: Integer;
    FURI: string;
    FRangeStartLine: Integer;
    FRangeStartCharacter: Integer;
    FRangeEndLine: Integer;
    FRangeEndCharacter: Integer;
    FSelectionStartLine: Integer;
    FSelectionStartCharacter: Integer;
    FSelectionEndLine: Integer;
    FSelectionEndCharacter: Integer;
    FContainerName: string;
  public
    property Name: string read FName write FName;
    property Kind: Integer read FKind write FKind;
    property URI: string read FURI write FURI;
    property RangeStartLine: Integer read FRangeStartLine write FRangeStartLine;
    property RangeStartCharacter: Integer read FRangeStartCharacter write FRangeStartCharacter;
    property RangeEndLine: Integer read FRangeEndLine write FRangeEndLine;
    property RangeEndCharacter: Integer read FRangeEndCharacter write FRangeEndCharacter;
    property SelectionStartLine: Integer read FSelectionStartLine write FSelectionStartLine;
    property SelectionStartCharacter: Integer read FSelectionStartCharacter write FSelectionStartCharacter;
    property SelectionEndLine: Integer read FSelectionEndLine write FSelectionEndLine;
    property SelectionEndCharacter: Integer read FSelectionEndCharacter write FSelectionEndCharacter;
    property ContainerName: string read FContainerName write FContainerName;
  end;

  TNXLSSymbolService = class(TNXLSLSPService)
  private
    FWorkspaceFolders: TStringList;
    FIndexedSymbols: TObjectList;
    FCache: TNXLSSymbolCache;
    FCacheFileName: string;
    FCacheLoaded: Boolean;
    procedure ClearWorkspaceFolders;
    procedure AddWorkspaceFolderPath(const APath: string);
    procedure AddWorkspaceFolderURI(const AURI: string);
    procedure RemoveWorkspaceFolderURI(const AURI: string);
    procedure ClearIndexedSymbolsForURI(const AURI: string);
    procedure ResetSymbolCacheState;
    procedure LoadSymbolCache;
    procedure SaveSymbolCache;
    function SymbolCacheFileName: string;
    procedure CopyCacheFileToIndexedSymbols(AFile: TNXLSSymbolCacheFile);
    procedure CopyIndexedSymbolsToCacheFile(AStartIndex: Integer; AFile: TNXLSSymbolCacheFile);
    procedure IndexCodeBuffer(const AURI: string; ACodeBuffer: TCodeBuffer);
    procedure IndexWorkspaceFile(const AFileName: string);
  public
    constructor Create(AModel: TNXLSLSPContext); override;
    destructor Destroy; override;

    function DocumentSymbol(AParams: TNXLSDocumentSymbolParams): TNXJSONValue; virtual;
    function WorkspaceSymbol(AParams: TNXLSWorkspaceSymbolParams): TNXJSONValue; virtual;
    procedure SetWorkspaceFolders(AParams: TNXLSInitializeParams);
    procedure AddWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
    procedure RemoveWorkspaceFolders(AFolders: TNXLSWorkspaceFolderArray);
    procedure RebuildWorkspaceIndex;
    procedure ReindexDocument(ADocument: TNXLSDocument);
    property IndexedSymbols: TObjectList read FIndexedSymbols;
  end;

implementation

uses
  SysUtils,
  fpjson,
  CodeTree,
  CodeToolManager,
  PascalParserTool,
  obNXLSProtocolBase,
  obNXLSProtocolObjects;

const
  cNXLSKindClass = 5;
  cNXLSKindMethod = 6;
  cNXLSKindField = 8;
  cNXLSKindEnum = 10;
  cNXLSKindFunction = 12;
  cNXLSKindVariable = 13;
  cNXLSKindConstant = 14;
  cNXLSKindEnumMember = 22;
  cNXLSKindStruct = 23;
  cNXLSKindTypeParameter = 26;
  cNXLSSymbolCacheEnv = 'NEXUSLS_CACHE_DIR';
  cNXLSSymbolCacheFileName = 'symbols.sqlite';

procedure NXLSSetRange(ARange: TNXLSRange; const AStartPos, AEndPos: TCodeXYPosition);
begin
  NXLSSetPosition(ARange.start, AStartPos.Y - 1, AStartPos.X - 1);
  NXLSSetPosition(ARange.&end, AEndPos.Y - 1, AEndPos.X - 1);
  ARange.Assigned := True;
end;

procedure NXLSSetNodeRange(ATool: TCodeTool; ANode: TCodeTreeNode; ARange: TNXLSRange);
var
  lStart: TCodeXYPosition;
  lEnd: TCodeXYPosition;
begin
  if (ATool = nil) or (ANode = nil) or (ARange = nil) then
    Exit;

  if not ATool.CleanPosToCaret(ANode.StartPos, lStart) then
    Exit;

  if not ATool.CleanPosToCaret(ANode.EndPos, lEnd) then
    lEnd := lStart;

  NXLSSetRange(ARange, lStart, lEnd);
end;

function NXLSIdentFromLineStart(const ALine: string): string;
var
  lIdx: Integer;
  lText: string;
begin
  Result := '';
  lText := TrimLeft(ALine);
  lIdx := 1;
  while (lIdx <= Length(lText)) and
    (lText[lIdx] in ['A'..'Z', 'a'..'z', '_', '0'..'9']) do
    Inc(lIdx);
  Result := Copy(lText, 1, lIdx - 1);
end;

function NXLSIdentifierAfterKeyword(const ALine, AKeyword: string): string;
var
  lText: string;
  lIdx: Integer;
begin
  Result := '';
  lText := Trim(ALine);
  if Pos(LowerCase(AKeyword) + ' ', LowerCase(lText)) <> 1 then
    Exit;

  lText := Trim(Copy(lText, Length(AKeyword) + 2, MaxInt));
  lIdx := 1;
  while (lIdx <= Length(lText)) and
    (lText[lIdx] in ['A'..'Z', 'a'..'z', '_', '.', '0'..'9']) do
    Inc(lIdx);
  Result := Copy(lText, 1, lIdx - 1);
  if Pos('.', Result) > 0 then
    Result := Copy(Result, LastDelimiter('.', Result) + 1, MaxInt);
end;

function NXLSNameStartCharacter(const ALine, AName: string): Integer;
begin
  Result := Pos(AName, ALine) - 1;
  if Result < 0 then
    Result := 0;
end;

procedure NXLSSetLineSymbolRange(ARange: TNXLSRange; ALineIndex: Integer;
  const ALine, AName: string; ASelectionOnly: Boolean);
var
  lStart: Integer;
  lEnd: Integer;
begin
  lStart := NXLSNameStartCharacter(ALine, AName);
  lEnd := lStart + Length(AName);
  if ASelectionOnly then
    NXLSSetPosition(ARange.start, ALineIndex, lStart)
  else
    NXLSSetPosition(ARange.start, ALineIndex, 0);
  if ASelectionOnly then
    NXLSSetPosition(ARange.&end, ALineIndex, lEnd)
  else
    NXLSSetPosition(ARange.&end, ALineIndex, Length(ALine));
  ARange.Assigned := True;
end;

procedure NXLSAddFallbackDocumentSymbol(ATarget: TNXJSONArray; ALineIndex: Integer;
  const ALine, AName: string; AKind: Integer);
var
  lSymbol: TNXLSDocumentSymbol;
begin
  if (ATarget = nil) or (AName = '') then
    Exit;

  lSymbol := TNXLSDocumentSymbol(ATarget.AddObject(TNXLSDocumentSymbol));
  lSymbol.name.Value := AName;
  lSymbol.kind.Value := AKind;
  NXLSSetLineSymbolRange(lSymbol.range, ALineIndex, ALine, AName, False);
  NXLSSetLineSymbolRange(lSymbol.selectionRange, ALineIndex, ALine, AName, True);
  lSymbol.Assigned := True;
end;

procedure NXLSAddFallbackIndexedSymbol(ATarget: TObjectList; const AURI: string;
  ALineIndex: Integer; const ALine, AName: string; AKind: Integer);
var
  lSymbol: TNXLSIndexedSymbol;
  lStart: Integer;
begin
  if (ATarget = nil) or (AName = '') then
    Exit;

  lStart := NXLSNameStartCharacter(ALine, AName);
  lSymbol := TNXLSIndexedSymbol.Create;
  ATarget.Add(lSymbol);
  lSymbol.Name := AName;
  lSymbol.Kind := AKind;
  lSymbol.URI := AURI;
  lSymbol.RangeStartLine := ALineIndex;
  lSymbol.RangeStartCharacter := 0;
  lSymbol.RangeEndLine := ALineIndex;
  lSymbol.RangeEndCharacter := Length(ALine);
  lSymbol.SelectionStartLine := ALineIndex;
  lSymbol.SelectionStartCharacter := lStart;
  lSymbol.SelectionEndLine := ALineIndex;
  lSymbol.SelectionEndCharacter := lStart + Length(AName);
end;

procedure NXLSScanFallbackSymbols(ACodeBuffer: TCodeBuffer;
  ADocumentTarget: TNXJSONArray; const AURI: string; AIndexTarget: TObjectList);
var
  lIdx: Integer;
  lLine: string;
  lText: string;
  lLower: string;
  lName: string;
  lSection: string;
  lKind: Integer;
  lMembers: string;
  lMember: string;
  lMemberStart: Integer;
  lMemberEnd: Integer;

  procedure AddSymbol(const AName: string; AKind: Integer);
  begin
    NXLSAddFallbackDocumentSymbol(ADocumentTarget, lIdx, lLine, AName, AKind);
    NXLSAddFallbackIndexedSymbol(AIndexTarget, AURI, lIdx, lLine, AName, AKind);
  end;

begin
  if ACodeBuffer = nil then
    Exit;

  lSection := '';
  for lIdx := 0 to ACodeBuffer.LineCount - 1 do
  begin
    lLine := ACodeBuffer.GetLine(lIdx);
    lText := Trim(lLine);
    lLower := LowerCase(lText);
    if (lText = '') or (Copy(lText, 1, 2) = '//') then
      Continue;

    if (not SameText(lText, 'type')) and
      (Pos(' type ', ' ' + lLower + ' ') > 0) then
    begin
      lText := Trim(Copy(lText, Pos(' type ', ' ' + lLower + ' ') + 5, MaxInt));
      lLower := LowerCase(lText);
      lSection := 'type';
    end;

    if SameText(lText, 'type') then
    begin
      lSection := 'type';
      Continue;
    end;
    if SameText(lText, 'const') then
    begin
      lSection := 'const';
      Continue;
    end;
    if SameText(lText, 'var') then
    begin
      lSection := 'var';
      Continue;
    end;
    if (lLower = 'interface') or (lLower = 'implementation') or
      (lLower = 'begin') then
    begin
      lSection := '';
      Continue;
    end;

    lName := NXLSIdentifierAfterKeyword(lText, 'procedure');
    if lName <> '' then
    begin
      AddSymbol(lName, cNXLSKindFunction);
      Continue;
    end;

    lName := NXLSIdentifierAfterKeyword(lText, 'function');
    if lName <> '' then
    begin
      AddSymbol(lName, cNXLSKindFunction);
      Continue;
    end;

    if lSection = 'const' then
    begin
      lName := NXLSIdentFromLineStart(lText);
      if (lName <> '') and (Pos('=', lText) > 0) then
        AddSymbol(lName, cNXLSKindConstant);
      Continue;
    end;

    if lSection = 'var' then
    begin
      lName := NXLSIdentFromLineStart(lText);
      if (lName <> '') and (Pos(':', lText) > 0) then
        AddSymbol(lName, cNXLSKindVariable);
      Continue;
    end;

    if lSection <> 'type' then
      Continue;

    lName := NXLSIdentFromLineStart(lText);
    if (lName = '') or (Pos('=', lText) = 0) then
      Continue;
    if Pos('= class;', lLower) > 0 then
      Continue;

    lKind := cNXLSKindTypeParameter;
    if Pos('= class', lLower) > 0 then
      lKind := cNXLSKindClass
    else if Pos('= record', lLower) > 0 then
      lKind := cNXLSKindStruct
    else if Pos('= (', lLower) > 0 then
      lKind := cNXLSKindEnum;

    AddSymbol(lName, lKind);

    if lKind = cNXLSKindEnum then
    begin
      lMembers := Trim(Copy(lText, Pos('(', lText) + 1, MaxInt));
      if Pos(')', lMembers) > 0 then
        lMembers := Copy(lMembers, 1, Pos(')', lMembers) - 1);
      lMemberStart := 1;
      repeat
        lMemberEnd := Pos(',', Copy(lMembers, lMemberStart, MaxInt));
        if lMemberEnd = 0 then
          lMemberEnd := Length(lMembers) - lMemberStart + 2;
        lMember := Trim(Copy(lMembers, lMemberStart, lMemberEnd - 1));
        AddSymbol(lMember, cNXLSKindEnumMember);
        Inc(lMemberStart, lMemberEnd);
      until lMemberStart > Length(lMembers);
    end;
  end;
end;

function NXLSNodeRange(ATool: TCodeTool; ANode: TCodeTreeNode;
  out AStartLine, AStartCharacter, AEndLine, AEndCharacter: Integer): Boolean;
var
  lStart: TCodeXYPosition;
  lEnd: TCodeXYPosition;
begin
  Result := False;
  AStartLine := 0;
  AStartCharacter := 0;
  AEndLine := 0;
  AEndCharacter := 0;

  if (ATool = nil) or (ANode = nil) then
    Exit;

  if not ATool.CleanPosToCaret(ANode.StartPos, lStart) then
    Exit;

  if not ATool.CleanPosToCaret(ANode.EndPos, lEnd) then
    lEnd := lStart;

  AStartLine := lStart.Y - 1;
  AStartCharacter := lStart.X - 1;
  AEndLine := lEnd.Y - 1;
  AEndCharacter := lEnd.X - 1;
  if AStartLine < 0 then
    AStartLine := 0;
  if AStartCharacter < 0 then
    AStartCharacter := 0;
  if AEndLine < 0 then
    AEndLine := 0;
  if AEndCharacter < 0 then
    AEndCharacter := 0;
  Result := True;
end;

function NXLSNodeHasClassChild(ANode: TCodeTreeNode): Boolean;
var
  lChild: TCodeTreeNode;
begin
  Result := False;
  if ANode = nil then
    Exit;

  lChild := ANode.FirstChild;
  while lChild <> nil do
  begin
    if lChild.Desc in AllClasses then
      Exit(True);
    lChild := lChild.NextBrother;
  end;
end;

function NXLSNodeInClass(ANode: TCodeTreeNode): Boolean;
begin
  Result := (ANode <> nil) and
    ((ANode.GetNodeOfTypes([ctnClass, ctnObject, ctnRecordType, ctnObjCClass,
      ctnObjCCategory, ctnCPPClass, ctnClassHelper, ctnRecordHelper,
      ctnTypeHelper, ctnClassInterface, ctnDispinterface, ctnObjCProtocol]) <> nil));
end;

function NXLSNodeSymbolKind(ANode: TCodeTreeNode): Integer;
begin
  Result := cNXLSKindVariable;
  if ANode = nil then
    Exit;

  case ANode.Desc of
    ctnClass, ctnObject, ctnObjCClass, ctnObjCCategory, ctnCPPClass,
    ctnClassHelper, ctnRecordHelper, ctnTypeHelper:
      Result := cNXLSKindClass;
    ctnClassInterface, ctnDispinterface, ctnObjCProtocol:
      Result := 11;
    ctnRecordType:
      Result := cNXLSKindStruct;
    ctnProcedure:
      if NXLSNodeInClass(ANode.Parent) then
        Result := cNXLSKindMethod
      else
        Result := cNXLSKindFunction;
    ctnProperty, ctnGlobalProperty:
      Result := 7;
    ctnVarDefinition:
      if NXLSNodeInClass(ANode.Parent) then
        Result := cNXLSKindField
      else
        Result := cNXLSKindVariable;
    ctnConstDefinition, ctnConstant:
      Result := cNXLSKindConstant;
    ctnEnumIdentifier:
      Result := cNXLSKindEnumMember;
    ctnEnumerationType:
      Result := cNXLSKindEnum;
    ctnTypeDefinition, ctnGenericType:
      Result := cNXLSKindStruct;
  end;
end;

function NXLSNodeSymbolName(ATool: TCodeTool; ANode: TCodeTreeNode): string;
begin
  Result := '';
  if (ATool = nil) or (ANode = nil) then
    Exit;

  case ANode.Desc of
    ctnProcedure:
      Result := ATool.ExtractProcName(ANode, [phpWithoutClassName]);
    ctnProperty:
      Result := ATool.ExtractPropName(ANode, False);
    ctnTypeDefinition, ctnVarDefinition, ctnConstDefinition, ctnGlobalProperty,
    ctnGenericType, ctnEnumIdentifier:
      Result := ATool.ExtractDefinitionName(ANode);
    ctnClass, ctnObject, ctnRecordType, ctnObjCClass, ctnObjCCategory,
    ctnCPPClass, ctnClassHelper, ctnRecordHelper, ctnTypeHelper,
    ctnClassInterface, ctnDispinterface, ctnObjCProtocol:
      if (ANode.Parent <> nil) and (ANode.Parent.Desc = ctnTypeDefinition) then
        Result := ATool.ExtractDefinitionName(ANode.Parent);
  end;
end;

function NXLSNodeIsDocumentSymbol(ANode: TCodeTreeNode): Boolean;
begin
  Result := False;
  if ANode = nil then
    Exit;

  case ANode.Desc of
    ctnProcedure, ctnProperty, ctnGlobalProperty, ctnVarDefinition,
    ctnConstDefinition, ctnEnumIdentifier, ctnClass, ctnObject,
    ctnRecordType, ctnObjCClass, ctnObjCCategory, ctnCPPClass,
    ctnClassHelper, ctnRecordHelper, ctnTypeHelper, ctnClassInterface,
    ctnDispinterface, ctnObjCProtocol:
      Result := True;
    ctnTypeDefinition, ctnGenericType:
      Result := not NXLSNodeHasClassChild(ANode);
  end;
end;

procedure NXLSAddDocumentSymbols(ATool: TCodeTool; ANode: TCodeTreeNode; ATarget: TNXJSONArray);
var
  lNode: TCodeTreeNode;
  lSymbol: TNXLSDocumentSymbol;
  lTarget: TNXJSONArray;
  lName: string;
begin
  lNode := ANode;
  while lNode <> nil do
  begin
    lTarget := ATarget;
    lSymbol := nil;

    if NXLSNodeIsDocumentSymbol(lNode) then
    begin
      lName := NXLSNodeSymbolName(ATool, lNode);
      if lName <> '' then
      begin
        lSymbol := TNXLSDocumentSymbol(ATarget.AddObject(TNXLSDocumentSymbol));
        lSymbol.name.Value := lName;
        lSymbol.kind.Value := NXLSNodeSymbolKind(lNode);
        lSymbol.detail.Value := NodeDescriptionAsString(lNode.Desc);
        NXLSSetNodeRange(ATool, lNode, lSymbol.range);
        NXLSSetNodeRange(ATool, lNode, lSymbol.selectionRange);
        lSymbol.Assigned := True;
        lTarget := lSymbol.children;
      end;
    end;

    if lNode.FirstChild <> nil then
      NXLSAddDocumentSymbols(ATool, lNode.FirstChild, lTarget);

    lNode := lNode.NextBrother;
  end;
end;

procedure NXLSAddIndexedSymbols(ATool: TCodeTool; ANode: TCodeTreeNode; const AURI,
  AContainerName: string; ATarget: TObjectList);
var
  lNode: TCodeTreeNode;
  lSymbol: TNXLSIndexedSymbol;
  lName: string;
  lContainerName: string;
  lStartLine: Integer;
  lStartCharacter: Integer;
  lEndLine: Integer;
  lEndCharacter: Integer;
begin
  lNode := ANode;
  while lNode <> nil do
  begin
    lContainerName := AContainerName;

    if NXLSNodeIsDocumentSymbol(lNode) then
    begin
      lName := NXLSNodeSymbolName(ATool, lNode);
      if lName <> '' then
      begin
        lSymbol := TNXLSIndexedSymbol.Create;
        ATarget.Add(lSymbol);
        lSymbol.Name := lName;
        lSymbol.Kind := NXLSNodeSymbolKind(lNode);
        lSymbol.URI := AURI;
        lSymbol.ContainerName := AContainerName;
        if NXLSNodeRange(ATool, lNode, lStartLine, lStartCharacter, lEndLine, lEndCharacter) then
        begin
          lSymbol.RangeStartLine := lStartLine;
          lSymbol.RangeStartCharacter := lStartCharacter;
          lSymbol.RangeEndLine := lEndLine;
          lSymbol.RangeEndCharacter := lEndCharacter;
          lSymbol.SelectionStartLine := lStartLine;
          lSymbol.SelectionStartCharacter := lStartCharacter;
          lSymbol.SelectionEndLine := lEndLine;
          lSymbol.SelectionEndCharacter := lEndCharacter;
        end;
        lContainerName := lName;
      end;
    end;

    if lNode.FirstChild <> nil then
      NXLSAddIndexedSymbols(ATool, lNode.FirstChild, AURI, lContainerName, ATarget);

    lNode := lNode.NextBrother;
  end;
end;

constructor TNXLSSymbolService.Create(AModel: TNXLSLSPContext);
begin
  inherited Create(AModel);
  FWorkspaceFolders := TStringList.Create;
  FWorkspaceFolders.Sorted := True;
  FWorkspaceFolders.Duplicates := dupIgnore;
  FIndexedSymbols := TObjectList.Create(True);
  FCache := TNXLSSymbolCache.Create;
end;

destructor TNXLSSymbolService.Destroy;
begin
  SaveSymbolCache;
  FreeAndNil(FCache);
  FreeAndNil(FIndexedSymbols);
  FreeAndNil(FWorkspaceFolders);
  inherited Destroy;
end;

function TNXLSSymbolService.DocumentSymbol(AParams: TNXLSDocumentSymbolParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lTool: TCodeTool;
begin
  if (AParams = nil) or (AParams.textDocument = nil) then
    raise Exception.Create('Document symbol params require a text document.');

  Result := TNXLSDocumentSymbolArrayResult.CreateValue;
  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  if lDocument.CodeBuffer = nil then
    Exit;

  lTool := nil;
  if (not CodeToolBoss.Explore(lDocument.CodeBuffer, lTool, False)) or
    (lTool = nil) or (lTool.Tree = nil) or (lTool.Tree.Root = nil) then
  begin
    NXLSScanFallbackSymbols(lDocument.CodeBuffer, TNXJSONArray(Result), '', nil);
    Exit;
  end;

  NXLSAddDocumentSymbols(lTool, lTool.Tree.Root.FirstChild, TNXJSONArray(Result));
  NXLSScanFallbackSymbols(lDocument.CodeBuffer, TNXJSONArray(Result), '', nil);
end;

function TNXLSSymbolService.WorkspaceSymbol(AParams: TNXLSWorkspaceSymbolParams): TNXJSONValue;
var
  lQuery: string;
  lIdx: Integer;
  lIndexedSymbol: TNXLSIndexedSymbol;
  lSymbol: TNXLSWorkspaceSymbol;
  lLocation: TNXLSLocation;
  lJSON: TJSONData;
begin
  Result := TNXLSWorkspaceSymbolArrayResult.CreateValue;
  if AParams = nil then
    Exit;

  lQuery := LowerCase(Trim(AParams.query.Value));

  for lIdx := 0 to IndexedSymbols.Count - 1 do
  begin
    lIndexedSymbol := TNXLSIndexedSymbol(IndexedSymbols[lIdx]);
    if (lQuery <> '') and (Pos(lQuery, LowerCase(lIndexedSymbol.Name)) = 0) then
      Continue;

    lSymbol := TNXLSWorkspaceSymbol(TNXJSONArray(Result).AddObject(TNXLSWorkspaceSymbol));
    lSymbol.name.Value := lIndexedSymbol.Name;
    lSymbol.kind.Value := lIndexedSymbol.Kind;
    if lIndexedSymbol.ContainerName <> '' then
      lSymbol.containerName.Value := lIndexedSymbol.ContainerName;

    lLocation := TNXLSLocation.Create;
    try
      lLocation.uri.Value := lIndexedSymbol.URI;
      NXLSSetPosition(lLocation.range.start, lIndexedSymbol.RangeStartLine, lIndexedSymbol.RangeStartCharacter);
      NXLSSetPosition(lLocation.range.&end, lIndexedSymbol.RangeEndLine, lIndexedSymbol.RangeEndCharacter);
      lLocation.range.Assigned := True;
      lLocation.Assigned := True;

      lJSON := lLocation.ToJSONData;
      try
        lSymbol.location.FromJSONData(lJSON);
      finally
        lJSON.Free;
      end;
    finally
      lLocation.Free;
    end;

    lSymbol.Assigned := True;
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

procedure TNXLSSymbolService.ClearIndexedSymbolsForURI(const AURI: string);
var
  lIdx: Integer;
begin
  for lIdx := FIndexedSymbols.Count - 1 downto 0 do
    if SameText(TNXLSIndexedSymbol(FIndexedSymbols[lIdx]).URI, AURI) then
      FIndexedSymbols.Delete(lIdx);
end;

procedure TNXLSSymbolService.ResetSymbolCacheState;
begin
  FCacheFileName := '';
  FCacheLoaded := False;
  if FCache <> nil then
    FCache.Clear;
end;

function TNXLSSymbolService.SymbolCacheFileName: string;
var
  lCacheDir: string;
begin
  Result := FCacheFileName;
  if Result <> '' then
    Exit;

  lCacheDir := GetEnvironmentVariable(cNXLSSymbolCacheEnv);
  if lCacheDir = '' then
  begin
    if FWorkspaceFolders.Count > 0 then
      lCacheDir := IncludeTrailingPathDelimiter(FWorkspaceFolders[0]) + '.nexusls' +
        DirectorySeparator + 'cache'
    else
      lCacheDir := IncludeTrailingPathDelimiter(GetTempDir) + 'NexusLS' +
        DirectorySeparator + 'cache';
  end;

  Result := IncludeTrailingPathDelimiter(lCacheDir) + cNXLSSymbolCacheFileName;
  FCacheFileName := Result;
end;

procedure TNXLSSymbolService.LoadSymbolCache;
var
  lFileName: string;
begin
  if FCacheLoaded then
    Exit;

  FCacheLoaded := True;
  lFileName := SymbolCacheFileName;
  if lFileName <> '' then
    FCache.Load(lFileName);
end;

procedure TNXLSSymbolService.SaveSymbolCache;
var
  lFileName: string;
begin
  if (FCache = nil) or (not FCache.Dirty) then
    Exit;

  lFileName := SymbolCacheFileName;
  if lFileName <> '' then
    FCache.Save(lFileName);
end;

procedure TNXLSSymbolService.CopyCacheFileToIndexedSymbols(AFile: TNXLSSymbolCacheFile);
var
  lIdx: Integer;
  lCachedSymbol: TNXLSSymbolCacheSymbol;
  lSymbol: TNXLSIndexedSymbol;
begin
  if AFile = nil then
    Exit;

  ClearIndexedSymbolsForURI(AFile.URI);

  for lIdx := 0 to AFile.Symbols.Count - 1 do
  begin
    lCachedSymbol := TNXLSSymbolCacheSymbol(AFile.Symbols[lIdx]);
    lSymbol := TNXLSIndexedSymbol.Create;
    FIndexedSymbols.Add(lSymbol);
    lSymbol.Name := lCachedSymbol.Name;
    lSymbol.Kind := lCachedSymbol.Kind;
    lSymbol.URI := lCachedSymbol.URI;
    lSymbol.RangeStartLine := lCachedSymbol.RangeStartLine;
    lSymbol.RangeStartCharacter := lCachedSymbol.RangeStartCharacter;
    lSymbol.RangeEndLine := lCachedSymbol.RangeEndLine;
    lSymbol.RangeEndCharacter := lCachedSymbol.RangeEndCharacter;
    lSymbol.SelectionStartLine := lCachedSymbol.SelectionStartLine;
    lSymbol.SelectionStartCharacter := lCachedSymbol.SelectionStartCharacter;
    lSymbol.SelectionEndLine := lCachedSymbol.SelectionEndLine;
    lSymbol.SelectionEndCharacter := lCachedSymbol.SelectionEndCharacter;
    lSymbol.ContainerName := lCachedSymbol.ContainerName;
  end;
end;

procedure TNXLSSymbolService.CopyIndexedSymbolsToCacheFile(AStartIndex: Integer;
  AFile: TNXLSSymbolCacheFile);
var
  lIdx: Integer;
  lIndexedSymbol: TNXLSIndexedSymbol;
  lCachedSymbol: TNXLSSymbolCacheSymbol;
begin
  if AFile = nil then
    Exit;

  AFile.ClearSymbols;
  for lIdx := AStartIndex to FIndexedSymbols.Count - 1 do
  begin
    lIndexedSymbol := TNXLSIndexedSymbol(FIndexedSymbols[lIdx]);
    if not SameText(lIndexedSymbol.URI, AFile.URI) then
      Continue;

    lCachedSymbol := TNXLSSymbolCacheSymbol.Create;
    AFile.Symbols.Add(lCachedSymbol);
    lCachedSymbol.Name := lIndexedSymbol.Name;
    lCachedSymbol.Kind := lIndexedSymbol.Kind;
    lCachedSymbol.URI := lIndexedSymbol.URI;
    lCachedSymbol.RangeStartLine := lIndexedSymbol.RangeStartLine;
    lCachedSymbol.RangeStartCharacter := lIndexedSymbol.RangeStartCharacter;
    lCachedSymbol.RangeEndLine := lIndexedSymbol.RangeEndLine;
    lCachedSymbol.RangeEndCharacter := lIndexedSymbol.RangeEndCharacter;
    lCachedSymbol.SelectionStartLine := lIndexedSymbol.SelectionStartLine;
    lCachedSymbol.SelectionStartCharacter := lIndexedSymbol.SelectionStartCharacter;
    lCachedSymbol.SelectionEndLine := lIndexedSymbol.SelectionEndLine;
    lCachedSymbol.SelectionEndCharacter := lIndexedSymbol.SelectionEndCharacter;
    lCachedSymbol.ContainerName := lIndexedSymbol.ContainerName;
  end;
end;

procedure TNXLSSymbolService.IndexCodeBuffer(const AURI: string; ACodeBuffer: TCodeBuffer);
var
  lTool: TCodeTool;
begin
  if (Trim(AURI) = '') or (ACodeBuffer = nil) then
    Exit;

  ClearIndexedSymbolsForURI(AURI);

  lTool := nil;
  if (not CodeToolBoss.Explore(ACodeBuffer, lTool, False)) or
    (lTool = nil) or (lTool.Tree = nil) or (lTool.Tree.Root = nil) then
  begin
    NXLSScanFallbackSymbols(ACodeBuffer, nil, AURI, FIndexedSymbols);
    Exit;
  end;

  NXLSAddIndexedSymbols(lTool, lTool.Tree.Root.FirstChild, AURI, '', FIndexedSymbols);
  NXLSScanFallbackSymbols(ACodeBuffer, nil, AURI, FIndexedSymbols);
end;

procedure TNXLSSymbolService.IndexWorkspaceFile(const AFileName: string);
var
  lCodeBuffer: TCodeBuffer;
  lURI: string;
  lStartIndex: Integer;
  lCacheFile: TNXLSSymbolCacheFile;
begin
  if not NXLSIsPascalSourceFile(AFileName) then
    Exit;

  lURI := NXLSPathToFileURI(AFileName);
  LoadSymbolCache;

  if FCache.IsFresh(AFileName, lURI) then
  begin
    CopyCacheFileToIndexedSymbols(FCache.FileByURI(lURI));
    Exit;
  end;

  try
    ClearIndexedSymbolsForURI(lURI);
    lStartIndex := FIndexedSymbols.Count;
    lCodeBuffer := NXLSLoadCodeBuffer(AFileName);
    IndexCodeBuffer(lURI, lCodeBuffer);
    lCacheFile := FCache.ReplaceFile(AFileName, lURI);
    CopyIndexedSymbolsToCacheFile(lStartIndex, lCacheFile);
  except
    on Exception do
    begin
      ClearIndexedSymbolsForURI(lURI);
      FCache.RemoveFile(lURI);
    end;
  end;
end;

procedure TNXLSSymbolService.SetWorkspaceFolders(AParams: TNXLSInitializeParams);
var
  lIdx: Integer;
  lFolder: TNXLSWorkspaceFolder;
begin
  ClearWorkspaceFolders;
  ResetSymbolCacheState;

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

  ResetSymbolCacheState;
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

  ResetSymbolCacheState;
end;

procedure TNXLSSymbolService.RebuildWorkspaceIndex;
var
  lIdx: Integer;

  procedure IndexFolder(const AFolder: string);
  var
    lSearch: TSearchRec;
    lPath: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(AFolder) + '*', faAnyFile, lSearch) <> 0 then
      Exit;
    try
      repeat
        if (lSearch.Name = '.') or (lSearch.Name = '..') then
          Continue;

        lPath := IncludeTrailingPathDelimiter(AFolder) + lSearch.Name;
        if (lSearch.Attr and faDirectory) <> 0 then
          IndexFolder(lPath)
        else
          IndexWorkspaceFile(lPath);
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;

begin
  FIndexedSymbols.Clear;
  LoadSymbolCache;

  for lIdx := 0 to FWorkspaceFolders.Count - 1 do
    IndexFolder(FWorkspaceFolders[lIdx]);

  for lIdx := 0 to Model.DocumentCount - 1 do
    ReindexDocument(Model.DocumentByIndex(lIdx));

  SaveSymbolCache;
end;

procedure TNXLSSymbolService.ReindexDocument(ADocument: TNXLSDocument);
begin
  if ADocument = nil then
    Exit;

  IndexCodeBuffer(ADocument.URI, ADocument.CodeBuffer);
end;

end.
