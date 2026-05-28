unit obNXLSNavigationService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSNavigationService = class(TNXLSLSPService)
  public
    function Declaration(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function Definition(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function ImplementationLocation(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
    function References(AParams: TNXLSReferenceParams): TNXJSONValue; virtual;
  end;

implementation

uses
  SysUtils,
  Classes,
  AVL_Tree,
  BasicCodeTools,
  CodeCache,
  CodeToolManager,
  CTUnitGraph,
  FileUtil,
  obNXLSProtocolObjects,
  utNXLSServiceHelpers;

function NXLSCreateLocation(ACode: TCodeBuffer; AX, AY: Integer): TNXLSLocation;
begin
  Result := TNXLSLocation.Create;
  try
    Result.uri.Value := NXLSPathToFileURI(ACode.Filename);
    NXLSSetIdentifierRange(Result, ACode, AX, AY - 1);
    Result.Assigned := True;
  except
    Result.Free;
    raise;
  end;
end;

procedure NXLSAddReferenceLocation(ATarget: TNXJSONArray; ACode: TCodeBuffer;
  AX, AY: Integer);
var
  lLocation: TNXLSLocation;
begin
  lLocation := TNXLSLocation(ATarget.AddObject(TNXLSLocation));
  lLocation.uri.Value := NXLSPathToFileURI(ACode.Filename);
  NXLSSetIdentifierRange(lLocation, ACode, AX, AY - 1);
  lLocation.Assigned := True;
end;

procedure NXLSAddTextScanReferences(ATarget: TNXJSONArray; AFiles: TStrings;
  const AIdentifier: string);
var
  lFileIdx: Integer;
  lLineIdx: Integer;
  lPos: Integer;
  lOffset: Integer;
  lCode: TCodeBuffer;
  lLine: string;
begin
  if AIdentifier = '' then
    Exit;

  for lFileIdx := 0 to AFiles.Count - 1 do
  begin
    lCode := NXLSLoadCodeBuffer(AFiles[lFileIdx]);
    for lLineIdx := 0 to lCode.LineCount - 1 do
    begin
      lLine := lCode.GetLine(lLineIdx);
      lOffset := 1;
      lPos := Pos(AIdentifier, lLine);
      while lPos > 0 do
        begin
          if NXLSWholeIdentifierAt(lLine, AIdentifier, lPos) then
            NXLSAddReferenceLocation(ATarget, lCode, lPos, lLineIdx + 1);
          lOffset := lPos + Length(AIdentifier);
          lPos := Pos(AIdentifier, Copy(lLine, lOffset, MaxInt));
          if lPos > 0 then
            lPos := lPos + lOffset - 1;
      end;
    end;
  end;
end;

function TNXLSNavigationService.Declaration(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lNewCode: TCodeBuffer;
  lNewX: Integer;
  lNewY: Integer;
  lNewTopLine: Integer;
  lBlockTopLine: Integer;
  lBlockBottomLine: Integer;
  lIdentifier: string;
begin
  Result := TNXLSLocationResult.CreateValue;
  if (AParams = nil) or (AParams.textDocument = nil) or (AParams.position = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lCode := lDocument.CodeBuffer;
  if lCode = nil then
    Exit;

  if CodeToolBoss.FindDeclaration(lCode, AParams.position.character.Value + 1,
    AParams.position.line.Value + 1, lNewCode, lNewX, lNewY, lNewTopLine,
    lBlockTopLine, lBlockBottomLine) then
  begin
    lIdentifier := NXLSIdentifierAt(lCode, AParams.position.character.Value + 1,
      AParams.position.line.Value);
    if lIdentifier <> '' then
      CodeToolBoss.FindDeclarationInInterface(lNewCode, lIdentifier, lNewCode,
        lNewX, lNewY, lNewTopLine, lBlockTopLine, lBlockBottomLine);

    Result.Free;
    Result := NXLSCreateLocation(lNewCode, lNewX, lNewY);
  end;
end;

function TNXLSNavigationService.Definition(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lNewCode: TCodeBuffer;
  lNewX: Integer;
  lNewY: Integer;
  lNewTopLine: Integer;
begin
  Result := TNXLSLocationResult.CreateValue;
  if (AParams = nil) or (AParams.textDocument = nil) or (AParams.position = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lCode := lDocument.CodeBuffer;
  if lCode = nil then
    Exit;

  if CodeToolBoss.FindMainDeclaration(lCode, AParams.position.character.Value + 1,
    AParams.position.line.Value + 1, lNewCode, lNewX, lNewY, lNewTopLine) then
  begin
    Result.Free;
    Result := NXLSCreateLocation(lNewCode, lNewX, lNewY);
  end;
end;

function TNXLSNavigationService.ImplementationLocation(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
begin
  Result := TNXLSLocationResult.CreateValue;
end;

function TNXLSNavigationService.References(AParams: TNXLSReferenceParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lStartCode: TCodeBuffer;
  lDeclCode: TCodeBuffer;
  lSearchCode: TCodeBuffer;
  lTree: TAVLTree;
  lList: TFPList;
  lCache: TFindIdentifierReferenceCache;
  lNode: TAVLTreeNode;
  lCodePos: PCodeXYPosition;
  lFiles: TStringList;
  lIdx: Integer;
  lDeclX: Integer;
  lDeclY: Integer;
  lDeclTopLine: Integer;
  lIncludeDeclaration: Boolean;
  lIdentifier: string;
  lHasDeclaration: Boolean;
begin
  Result := TNXLSLocationArrayResult.CreateValue;
  if (AParams = nil) or (AParams.textDocument = nil) or
    (AParams.position = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lStartCode := lDocument.CodeBuffer;
  if lStartCode = nil then
    Exit;

  lHasDeclaration := CodeToolBoss.FindMainDeclaration(lStartCode,
    AParams.position.character.Value + 1, AParams.position.line.Value + 1,
    lDeclCode, lDeclX, lDeclY, lDeclTopLine);

  if lHasDeclaration then
  begin
    CodeToolBoss.GetIdentifierAt(lDeclCode, lDeclX, lDeclY, lIdentifier);
    if lIdentifier = '' then
      lIdentifier := NXLSIdentifierNear(lDeclCode, lDeclX, lDeclY - 1);
  end
  else
  begin
    lDeclCode := lStartCode;
    lDeclX := AParams.position.character.Value + 1;
    lDeclY := AParams.position.line.Value + 1;
    lIdentifier := NXLSIdentifierNear(lStartCode, lDeclX,
      AParams.position.line.Value);
  end;

  lIncludeDeclaration := True;
  if (AParams.context <> nil) and AParams.context.includeDeclaration.Assigned then
    lIncludeDeclaration := AParams.context.includeDeclaration.Value;

  lFiles := TStringList.Create;
  lTree := nil;
  lList := nil;
  lCache := nil;
  try
    lFiles.Sorted := True;
    lFiles.Duplicates := dupIgnore;
    lFiles.Add(lStartCode.Filename);
    if lHasDeclaration and
      (CompareText(lDeclCode.Filename, lStartCode.Filename) <> 0) then
      lFiles.Add(lDeclCode.Filename);
    if DirectoryExists(ExtractFileDir(lStartCode.Filename)) then
      FindAllFiles(lFiles, ExtractFileDir(lStartCode.Filename),
        '*.pas;*.pp;*.p;*.lpr;*.inc', True);

    if lHasDeclaration then
    begin
      for lIdx := 0 to lFiles.Count - 1 do
      begin
        lSearchCode := NXLSLoadCodeBuffer(lFiles[lIdx]);
        CodeToolBoss.FreeListOfPCodeXYPosition(lList);
        lList := nil;
        if not CodeToolBoss.FindReferences(lDeclCode, lDeclX, lDeclY,
          lSearchCode, True, lList, lCache) then
          Continue;

        if lList = nil then
          Continue;

        if lTree = nil then
          lTree := TAVLTree(CodeToolBoss.CreateTreeOfPCodeXYPosition);
        CodeToolBoss.AddListToTreeOfPCodeXYPosition(lList, lTree, True, False);
      end;

      if lTree <> nil then
      begin
        lNode := TAVLTreeNode(lTree.FindLowest);
        while lNode <> nil do
        begin
          lCodePos := PCodeXYPosition(lNode.Data);
          if lIncludeDeclaration or
            (CompareText(lCodePos^.Code.Filename, lDeclCode.Filename) <> 0) or
            (lCodePos^.X <> lDeclX) or (lCodePos^.Y <> lDeclY) then
          begin
            NXLSAddReferenceLocation(TNXJSONArray(Result), lCodePos^.Code,
              lCodePos^.X, lCodePos^.Y);
          end;
          lNode := TAVLTreeNode(lTree.FindSuccessor(lNode));
        end;
      end;
    end;

    if TNXJSONArray(Result).Count < 2 then
    begin
      TNXJSONArray(Result).Clear;
      NXLSAddTextScanReferences(TNXJSONArray(Result), lFiles, lIdentifier);
    end;
  finally
    lFiles.Free;
    CodeToolBoss.FreeListOfPCodeXYPosition(lList);
    CodeToolBoss.FreeTreeOfPCodeXYPosition(lTree);
    lCache.Free;
  end;
end;

end.
