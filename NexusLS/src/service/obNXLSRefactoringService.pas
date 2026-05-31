unit obNXLSRefactoringService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext;

type
  TNXLSRefactoringService = class(TNXLSLSPService)
  public
    function FillRename(AParams: TNXLSRenameParams;
      AResult: TNXLSWorkspaceEdit): Boolean; virtual;
    function FillPrepareRename(AParams: TNXLSTextDocumentPositionParams;
      AResult: TNXLSPrepareRenamePlaceholder): Boolean; virtual;
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
  obNXJSONValues,
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

function NXLSAddTextDocumentEdit(AEdit: TNXLSWorkspaceEdit;
  const AURI: string): TNXLSTextDocumentEdit;
begin
  Result := TNXLSTextDocumentEdit(AEdit.documentChanges.AddObject(
    TNXLSTextDocumentEdit));
  Result.textDocument.uri.Value := AURI;
  Result.textDocument.version.SetNull;
  Result.edits.Assigned := True;
  Result.Assigned := True;
end;

procedure NXLSAssignPosition(APosition: TNXLSPosition; ALine, ACharacter: Integer);
begin
  APosition.line.Value := ALine;
  APosition.character.Value := ACharacter;
  APosition.Assigned := True;
end;

procedure NXLSAddRenameEdit(AEdits: TNXLSTextEditArray; ACodePos: PCodeXYPosition;
  const AIdentifier, ANewName: string);
var
  lEdit: TNXLSTextEdit;
begin
  lEdit := TNXLSTextEdit(AEdits.AddObject(TNXLSTextEdit));
  NXLSAssignPosition(lEdit.range.start, ACodePos^.Y - 1, ACodePos^.X - 1);
  NXLSAssignPosition(lEdit.range.&end, ACodePos^.Y - 1,
    ACodePos^.X - 1 + Length(AIdentifier));
  lEdit.range.Assigned := True;
  lEdit.newText.Value := ANewName;
  lEdit.Assigned := True;
end;

function TNXLSRefactoringService.FillRename(AParams: TNXLSRenameParams;
  AResult: TNXLSWorkspaceEdit): Boolean;
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
  lCurrentURI: string;
  lCurrentEdit: TNXLSTextDocumentEdit;

begin
  Result := False;
  if AResult = nil then
    Exit;
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

    AResult.documentChanges.Assigned := True;
    AResult.Assigned := True;
    lCurrentURI := '';
    lNode := TAVLTreeNode(lTree.FindLowest);
    while lNode <> nil do
    begin
      lCodePos := PCodeXYPosition(lNode.Data);
      if NXLSPathToFileURI(lCodePos^.Code.Filename) <> lCurrentURI then
      begin
        lCurrentURI := NXLSPathToFileURI(lCodePos^.Code.Filename);
        lCurrentEdit := NXLSAddTextDocumentEdit(AResult, lCurrentURI);
      end;

      NXLSAddRenameEdit(lCurrentEdit.edits, lCodePos, lIdentifier,
        AParams.newName.Value);
      lNode := TAVLTreeNode(lTree.FindSuccessor(lNode));
    end;
    Result := True;
  finally
    lFiles.Free;
    CodeToolBoss.FreeListOfPCodeXYPosition(lList);
    CodeToolBoss.FreeTreeOfPCodeXYPosition(lTree);
    lCache.Free;
  end;
end;

function TNXLSRefactoringService.FillPrepareRename(
  AParams: TNXLSTextDocumentPositionParams;
  AResult: TNXLSPrepareRenamePlaceholder): Boolean;
var
  lDocument: TNXLSDocument;
  lCode: TCodeBuffer;
  lDeclCode: TCodeBuffer;
  lDeclX: Integer;
  lDeclY: Integer;
  lDeclTopLine: Integer;
  lIdentifier: string;
begin
  Result := False;
  if AResult = nil then
    Exit;
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

  NXLSSetIdentifierRange(AResult.range, lCode,
    AParams.position.character.Value + 1, AParams.position.line.Value);
  AResult.placeholder.Value := lIdentifier;
  AResult.Assigned := True;
  Result := True;
end;

end.
