unit obNXLSRefactoringService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSRefactoringService = class(TNXLSLSPService)
  public
    function Rename(AParams: TNXLSRenameParams): TNXJSONValue; virtual;
    function PrepareRename(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue; virtual;
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
  fpjson,
  obNXLSProtocolObjects,
  utNXLSServiceHelpers;

procedure NXLSAddRenameFileList(AFiles: TStrings; const AStartFile: string);
var
  lDir: string;
begin
  if AStartFile = '' then
    Exit;

  AFiles.Add(AStartFile);
  lDir := ExtractFileDir(AStartFile);
  if DirectoryExists(lDir) then
    FindAllFiles(AFiles, lDir, '*.pas;*.pp;*.p;*.lpr;*.inc', True);
end;

function NXLSCreateTextDocumentEdit(const AURI: string): TJSONObject;
var
  lTextDocument: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    lTextDocument := TJSONObject.Create;
    lTextDocument.Add('uri', AURI);
    lTextDocument.Add('version', 0);
    Result.Add('textDocument', lTextDocument);
    Result.Add('edits', TJSONArray.Create);
  except
    Result.Free;
    raise;
  end;
end;

procedure NXLSAddRenameEdit(AEdits: TJSONArray; ACodePos: PCodeXYPosition;
  const AIdentifier, ANewName: string);
var
  lEdit: TJSONObject;
  lRange: TJSONObject;
  lStart: TJSONObject;
  lEnd: TJSONObject;
begin
  lEdit := TJSONObject.Create;
  try
    lRange := TJSONObject.Create;
    lStart := TJSONObject.Create;
    lEnd := TJSONObject.Create;

    lStart.Add('line', ACodePos^.Y - 1);
    lStart.Add('character', ACodePos^.X - 1);
    lEnd.Add('line', ACodePos^.Y - 1);
    lEnd.Add('character', ACodePos^.X - 1 + Length(AIdentifier));
    lRange.Add('start', lStart);
    lRange.Add('end', lEnd);

    lEdit.Add('range', lRange);
    lEdit.Add('newText', ANewName);
    AEdits.Add(lEdit);
  except
    lEdit.Free;
    raise;
  end;
end;

procedure NXLSAddDocumentChange(AEdit: TNXLSWorkspaceEdit; AData: TJSONData);
var
  lValue: TNXJSONValue;
begin
  lValue := TNXJSONValue.Create;
  try
    lValue.FromJSONData(AData);
    AEdit.documentChanges.Add(lValue);
    lValue := nil;
  finally
    lValue.Free;
  end;
end;

function TNXLSRefactoringService.Rename(AParams: TNXLSRenameParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lStartCode: TCodeBuffer;
  lDeclCode: TCodeBuffer;
  lSearchCode: TCodeBuffer;
  lTree: TAVLTree;
  lList: TFPList;
  lCache: TFindIdentifierReferenceCache;
  lFiles: TStringList;
  lIdx: Integer;
  lNode: TAVLTreeNode;
  lCodePos: PCodeXYPosition;
  lDeclX: Integer;
  lDeclY: Integer;
  lDeclTopLine: Integer;
  lIdentifier: string;
  lWorkspaceEdit: TNXLSWorkspaceEdit;
  lCurrentURI: string;
  lCurrentEdit: TJSONObject;

  procedure FlushCurrentEdit;
  begin
    if lCurrentEdit = nil then
      Exit;

    NXLSAddDocumentChange(lWorkspaceEdit, lCurrentEdit);
    FreeAndNil(lCurrentEdit);
  end;

  function CurrentEdits: TJSONArray;
  begin
    Result := TJSONArray(lCurrentEdit.Find('edits'));
  end;

begin
  Result := TNXLSWorkspaceEditResult.CreateValue;
  if (AParams = nil) or (AParams.textDocument = nil) or
    (AParams.position = nil) or (AParams.newName.Value = '') then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lStartCode := lDocument.CodeBuffer;
  if lStartCode = nil then
    Exit;

  if not CodeToolBoss.FindMainDeclaration(lStartCode,
    AParams.position.character.Value + 1, AParams.position.line.Value + 1,
    lDeclCode, lDeclX, lDeclY, lDeclTopLine) then
    Exit;

  CodeToolBoss.GetIdentifierAt(lDeclCode, lDeclX, lDeclY, lIdentifier);
  if lIdentifier = '' then
    lIdentifier := NXLSIdentifierNear(lDeclCode, lDeclX, lDeclY - 1);
  if lIdentifier = '' then
    Exit;

  lFiles := TStringList.Create;
  lTree := nil;
  lList := nil;
  lCache := nil;
  lCurrentEdit := nil;
  try
    lFiles.Sorted := True;
    lFiles.Duplicates := dupIgnore;
    NXLSAddRenameFileList(lFiles, lStartCode.Filename);
    if CompareText(lDeclCode.Filename, lStartCode.Filename) <> 0 then
      NXLSAddRenameFileList(lFiles, lDeclCode.Filename);

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

    if (lTree = nil) or (lTree.Count = 0) then
      Exit;

    Result.Free;
    lWorkspaceEdit := TNXLSWorkspaceEdit.Create;
    lWorkspaceEdit.documentChanges.Assigned := True;
    lWorkspaceEdit.Assigned := True;
    Result := lWorkspaceEdit;

    lCurrentURI := '';
    lNode := TAVLTreeNode(lTree.FindLowest);
    while lNode <> nil do
    begin
      lCodePos := PCodeXYPosition(lNode.Data);
      if NXLSPathToFileURI(lCodePos^.Code.Filename) <> lCurrentURI then
      begin
        FlushCurrentEdit;
        lCurrentURI := NXLSPathToFileURI(lCodePos^.Code.Filename);
        lCurrentEdit := NXLSCreateTextDocumentEdit(lCurrentURI);
      end;

      NXLSAddRenameEdit(CurrentEdits, lCodePos, lIdentifier,
        AParams.newName.Value);
      lNode := TAVLTreeNode(lTree.FindSuccessor(lNode));
    end;
    FlushCurrentEdit;
  finally
    lCurrentEdit.Free;
    lFiles.Free;
    CodeToolBoss.FreeListOfPCodeXYPosition(lList);
    CodeToolBoss.FreeTreeOfPCodeXYPosition(lTree);
    lCache.Free;
  end;
end;

function TNXLSRefactoringService.PrepareRename(AParams: TNXLSTextDocumentPositionParams): TNXJSONValue;
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lDeclCode: TCodeBuffer;
  lDeclX: Integer;
  lDeclY: Integer;
  lDeclTopLine: Integer;
  lIdentifier: string;
  lResult: TNXLSPrepareRenamePlaceholder;
begin
  Result := TNXLSPrepareRenameResult.CreateValue;
  if (AParams = nil) or (AParams.textDocument = nil) or
    (AParams.position = nil) then
    Exit;

  lDocument := Model.RequireDocument(AParams.textDocument.uri.Value);
  lCode := lDocument.CodeBuffer;
  if lCode = nil then
    Exit;

  if not CodeToolBoss.FindMainDeclaration(lCode,
    AParams.position.character.Value + 1, AParams.position.line.Value + 1,
    lDeclCode, lDeclX, lDeclY, lDeclTopLine) then
    Exit;

  CodeToolBoss.GetIdentifierAt(lDeclCode, lDeclX, lDeclY, lIdentifier);
  if lIdentifier = '' then
    lIdentifier := NXLSIdentifierNear(lCode,
      AParams.position.character.Value + 1, AParams.position.line.Value);
  if lIdentifier = '' then
    Exit;

  Result.Free;
  lResult := TNXLSPrepareRenamePlaceholder.Create;
  NXLSSetIdentifierRange(lResult.range, lCode,
    AParams.position.character.Value + 1, AParams.position.line.Value);
  lResult.placeholder.Value := lIdentifier;
  lResult.Assigned := True;
  Result := lResult;
end;

end.
