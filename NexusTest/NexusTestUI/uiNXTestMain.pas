unit uiNXTestMain;

{$mode objfpc}{$H+}

interface

procedure RunNexusTestUI;

implementation

uses
  Classes,
  DynLibs,
  SysUtils,
  obNXApplication,
  obNXButton,
  obNXControl,
  obNXGroupBox,
  obNXMemo,
  obNXPanel,
  obNXTestModuleClient,
  obNXTestRPCValues,
  obNXTreeView,
  tpNXLayout,
  tpNXPlatform,
  tpNXTest,
  tpNXWindow;

type
  TNXTestUINodeKind = (
    nkRoot,
    nkSuite,
    nkTest
  );

  TNXTestUINodeRef = class
  private
    FKind: TNXTestUINodeKind;
    FSuiteName: string;
    FTestId: string;
    FTestName: string;
  public
    constructor Create(AKind: TNXTestUINodeKind; const ASuiteName: string;
      const ATestName: string = ''; const ATestId: string = '');

    property Kind: TNXTestUINodeKind read FKind;
    property SuiteName: string read FSuiteName;
    property TestId: string read FTestId;
    property TestName: string read FTestName;
  end;

  TNXTestUIController = class
  private
    FButtonPanel: TNXPanel;
    FDetailsBox: TNXGroupBox;
    FDetailsMemo: TNXMemo;
    FClient: TNXTestModuleClient;
    FModuleLoadError: string;
    FNodeRefs: TList;
    FRefreshButton: TNXButton;
    FRootNode: TNXTreeViewNode;
    FRunAllButton: TNXButton;
    FRunSelectedButton: TNXButton;
    FTree: TNXTreeView;

    function AddNodeRef(AKind: TNXTestUINodeKind; const ASuiteName: string;
      const ATestName: string = ''; const ATestId: string = ''): TNXTestUINodeRef;
    procedure ClearNodeRefs;
    function FindNodeByTestId(ANode: TNXTreeViewNode;
      const ATestId: string): TNXTreeViewNode;
    function NodeRef(ANode: TNXTreeViewNode): TNXTestUINodeRef;
    procedure PopulateTree;
    procedure RefreshButtonClick(Sender: TObject; X, Y: Integer;
      Button: TNXMouseButton);
    procedure RunAllButtonClick(Sender: TObject; X, Y: Integer;
      Button: TNXMouseButton);
    procedure RunSelectedButtonClick(Sender: TObject; X, Y: Integer;
      Button: TNXMouseButton);
    procedure SetNodeStatus(ANode: TNXTreeViewNode; const AStatus: string;
      ADurationMs: Int64 = 0; const AMessage: string = '');
    procedure TreeChange(Sender: TObject; ANode: TNXTreeViewNode);
    procedure UpdateDetails(ANode: TNXTreeViewNode);
    procedure UpdateResult(AResult: TNXTestResultValue);
    procedure UpdateResults(AResults: TNXTestResultArray);
  public
    constructor Create(const AModuleFileName: string);
    destructor Destroy; override;

    procedure BuildUI;
  end;

constructor TNXTestUINodeRef.Create(AKind: TNXTestUINodeKind;
  const ASuiteName: string; const ATestName: string; const ATestId: string);
begin
  inherited Create;
  FKind := AKind;
  FSuiteName := ASuiteName;
  FTestName := ATestName;
  FTestId := ATestId;
end;

constructor TNXTestUIController.Create(const AModuleFileName: string);
begin
  inherited Create;
  FNodeRefs := TList.Create;
  FClient := TNXTestModuleClient.Create;

  try
    FClient.LoadModule(AModuleFileName);
  except
    on E: Exception do
      FModuleLoadError := E.Message;
  end;
end;

destructor TNXTestUIController.Destroy;
begin
  ClearNodeRefs;
  FreeAndNil(FNodeRefs);
  FreeAndNil(FClient);
  inherited Destroy;
end;

function TNXTestUIController.AddNodeRef(AKind: TNXTestUINodeKind;
  const ASuiteName: string; const ATestName: string;
  const ATestId: string): TNXTestUINodeRef;
begin
  Result := TNXTestUINodeRef.Create(AKind, ASuiteName, ATestName, ATestId);
  FNodeRefs.Add(Result);
end;

procedure TNXTestUIController.BuildUI;
begin
  FButtonPanel := TNXPanel.Create(Application.RootWindow);
  FButtonPanel.Height := 38;
  FButtonPanel.BorderStyle := BS_None;
  FButtonPanel.Align := caTop;

  FRunAllButton := TNXButton.Create(FButtonPanel);
  FRunAllButton.SetBounds(8, 7, 90, 24);
  FRunAllButton.Caption := 'Run All';
  FRunAllButton.OnMouseClick := @RunAllButtonClick;

  FRunSelectedButton := TNXButton.Create(FButtonPanel);
  FRunSelectedButton.SetBounds(106, 7, 105, 24);
  FRunSelectedButton.Caption := 'Run Selected';
  FRunSelectedButton.OnMouseClick := @RunSelectedButtonClick;

  FRefreshButton := TNXButton.Create(FButtonPanel);
  FRefreshButton.SetBounds(219, 7, 90, 24);
  FRefreshButton.Caption := 'Refresh';
  FRefreshButton.OnMouseClick := @RefreshButtonClick;

  FDetailsBox := TNXGroupBox.Create(Application.RootWindow, 'Details',
    MakeNXRect(0, 0, 100, 170));
  FDetailsBox.Align := caBottom;

  FDetailsMemo := TNXMemo.Create(FDetailsBox.ContentPanel);
  FDetailsMemo.Align := caClient;
  FDetailsMemo.BorderStyle := BS_None;
  FDetailsMemo.TabStop := False;

  FTree := TNXTreeView.Create(Application.RootWindow);
  FTree.Align := caClient;
  FTree.Columns[0].Caption := 'Name';
  FTree.Columns[0].Width := 320;
  FTree.AddColumn('Status', 120);
  FTree.AddColumn('Duration', 100);
  FTree.AddColumn('Message', 460);
  FTree.OnChange := @TreeChange;

  PopulateTree;
end;

procedure TNXTestUIController.ClearNodeRefs;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FNodeRefs.Count - 1 do
    TObject(FNodeRefs[lIndex]).Free;
  FNodeRefs.Clear;
end;

function TNXTestUIController.FindNodeByTestId(ANode: TNXTreeViewNode;
  const ATestId: string): TNXTreeViewNode;
var
  lIndex: Integer;
  lRef: TNXTestUINodeRef;
begin
  Result := nil;
  if not Assigned(ANode) then
    Exit;

  lRef := NodeRef(ANode);
  if Assigned(lRef) and (lRef.Kind = nkTest) and SameText(lRef.TestId, ATestId) then
    Exit(ANode);

  for lIndex := 0 to ANode.ChildCount - 1 do
  begin
    Result := FindNodeByTestId(ANode.Child[lIndex], ATestId);
    if Assigned(Result) then
      Exit;
  end;
end;

function TNXTestUIController.NodeRef(ANode: TNXTreeViewNode): TNXTestUINodeRef;
begin
  Result := nil;
  if Assigned(ANode) then
    Result := TNXTestUINodeRef(ANode.Data);
end;

procedure TNXTestUIController.PopulateTree;
var
  lRegistry: TNXTestRegistryValue;
  lSuiteIndex: Integer;
  lTestIndex: Integer;
  lSuite: TNXTestSuiteInfoValue;
  lSuiteNode: TNXTreeViewNode;
  lTest: TNXTestCaseInfoValue;
  lTestNode: TNXTreeViewNode;
begin
  if not Assigned(FTree) then
    Exit;

  FTree.Clear;
  ClearNodeRefs;

  FRootNode := FTree.AddNode('NexusTest',
    AddNodeRef(nkRoot, ''));
  SetNodeStatus(FRootNode, cNXTestStatusNotRun);

  if FModuleLoadError <> '' then
  begin
    SetNodeStatus(FRootNode, cNXTestStatusError, 0, FModuleLoadError);
    FTree.SelectedNode := FRootNode;
    UpdateDetails(FRootNode);
    Exit;
  end;

  lRegistry := FClient.ListTests;
  try
    for lSuiteIndex := 0 to lRegistry.suites.Count - 1 do
    begin
      lSuite := TNXTestSuiteInfoValue(lRegistry.suites[lSuiteIndex]);
      lSuiteNode := FTree.AddChildNode(FRootNode, lSuite.name.Value,
        AddNodeRef(nkSuite, lSuite.name.Value));
      SetNodeStatus(lSuiteNode, cNXTestStatusNotRun);

      for lTestIndex := 0 to lSuite.tests.Count - 1 do
      begin
        lTest := TNXTestCaseInfoValue(lSuite.tests[lTestIndex]);
        lTestNode := FTree.AddChildNode(lSuiteNode, lTest.name.Value,
          AddNodeRef(nkTest, lSuite.name.Value, lTest.name.Value,
          lTest.id.Value));
        SetNodeStatus(lTestNode, cNXTestStatusNotRun);
      end;
    end;
  finally
    lRegistry.Free;
  end;

  FTree.ExpandAll;
  FTree.SelectedNode := FRootNode;
  UpdateDetails(FRootNode);
end;

procedure TNXTestUIController.RefreshButtonClick(Sender: TObject; X,
  Y: Integer; Button: TNXMouseButton);
begin
  if Button <> mbLeft then
    Exit;

  PopulateTree;
end;

procedure TNXTestUIController.RunAllButtonClick(Sender: TObject; X,
  Y: Integer; Button: TNXMouseButton);
var
  lResult: TNXTestRunAllResultValue;
begin
  if Button <> mbLeft then
    Exit;

  SetNodeStatus(FRootNode, 'running');
  Application.Render;

  try
    lResult := FClient.RunAll;
    try
      UpdateResults(lResult.results);
    finally
      lResult.Free;
    end;
    SetNodeStatus(FRootNode, 'complete');
  except
    on E: Exception do
      SetNodeStatus(FRootNode, cNXTestStatusError, 0, E.Message);
  end;
  UpdateDetails(FTree.SelectedNode);
end;

procedure TNXTestUIController.RunSelectedButtonClick(Sender: TObject; X,
  Y: Integer; Button: TNXMouseButton);
var
  lNode: TNXTreeViewNode;
  lRef: TNXTestUINodeRef;
  lResult: TNXTestResultValue;
  lSuiteResult: TNXTestRunSuiteResultValue;
begin
  if Button <> mbLeft then
    Exit;

  lNode := FTree.SelectedNode;
  lRef := NodeRef(lNode);
  if not Assigned(lRef) then
    Exit;

  case lRef.Kind of
    nkRoot:
      RunAllButtonClick(Sender, X, Y, Button);

    nkSuite:
    begin
      SetNodeStatus(lNode, 'running');
      Application.Render;
      try
        lSuiteResult := FClient.RunSuite(lRef.SuiteName);
        try
          UpdateResults(lSuiteResult.results);
        finally
          lSuiteResult.Free;
        end;
        SetNodeStatus(lNode, 'complete');
      except
        on E: Exception do
          SetNodeStatus(lNode, cNXTestStatusError, 0, E.Message);
      end;
    end;

    nkTest:
    begin
      SetNodeStatus(lNode, 'running');
      Application.Render;
      try
        lResult := FClient.RunTest(lRef.TestId);
        try
          UpdateResult(lResult);
        finally
          lResult.Free;
        end;
      except
        on E: Exception do
          SetNodeStatus(lNode, cNXTestStatusError, 0, E.Message);
      end;
    end;
  end;

  UpdateDetails(FTree.SelectedNode);
end;

procedure TNXTestUIController.SetNodeStatus(ANode: TNXTreeViewNode;
  const AStatus: string; ADurationMs: Int64; const AMessage: string);
begin
  if not Assigned(ANode) then
    Exit;

  ANode.Cell[1].Text := AStatus;
  ANode.Cell[1].GlyphKind := tvgkCircle;
  ANode.Cell[1].UseGlyphColor := True;

  if SameText(AStatus, cNXTestStatusPassed) then
    ANode.Cell[1].GlyphColor := MakeNXColor(60, 190, 95, 255)
  else if SameText(AStatus, cNXTestStatusFailed) or
    SameText(AStatus, cNXTestStatusError) then
    ANode.Cell[1].GlyphColor := MakeNXColor(215, 70, 70, 255)
  else if SameText(AStatus, 'running') then
    ANode.Cell[1].GlyphColor := MakeNXColor(70, 145, 230, 255)
  else
    ANode.Cell[1].GlyphColor := MakeNXColor(130, 130, 130, 255);

  if ADurationMs > 0 then
    ANode.Cell[2].Text := IntToStr(ADurationMs) + ' ms'
  else
    ANode.Cell[2].Text := '';
  ANode.Cell[3].Text := AMessage;
  FTree.NodeChanged(ANode);
end;

procedure TNXTestUIController.TreeChange(Sender: TObject;
  ANode: TNXTreeViewNode);
begin
  UpdateDetails(ANode);
end;

procedure TNXTestUIController.UpdateDetails(ANode: TNXTreeViewNode);
var
  lRef: TNXTestUINodeRef;
begin
  if not Assigned(FDetailsMemo) then
    Exit;

  FDetailsMemo.Clear;
  if not Assigned(ANode) then
  begin
    FDetailsMemo.AddLine('No selection.');
    Exit;
  end;

  lRef := NodeRef(ANode);
  if not Assigned(lRef) then
  begin
    FDetailsMemo.AddLine(ANode.Text);
    Exit;
  end;

  case lRef.Kind of
    nkRoot:
      FDetailsMemo.AddLine('Root: NexusTest');
    nkSuite:
    begin
      FDetailsMemo.AddLine('Suite: ' + lRef.SuiteName);
      FDetailsMemo.AddLine('Tests: ' + IntToStr(ANode.ChildCount));
    end;
    nkTest:
    begin
      FDetailsMemo.AddLine('Test: ' + lRef.TestName);
      FDetailsMemo.AddLine('Suite: ' + lRef.SuiteName);
      FDetailsMemo.AddLine('ID: ' + lRef.TestId);
    end;
  end;

  FDetailsMemo.AddLine('Status: ' + ANode.Cell[1].Text);
  if ANode.Cell[2].Text <> '' then
    FDetailsMemo.AddLine('Duration: ' + ANode.Cell[2].Text);
  if ANode.Cell[3].Text <> '' then
    FDetailsMemo.AddLine('Message: ' + ANode.Cell[3].Text);
end;

procedure TNXTestUIController.UpdateResult(AResult: TNXTestResultValue);
var
  lMessage: string;
  lNode: TNXTreeViewNode;
begin
  if not Assigned(AResult) then
    Exit;

  lNode := FindNodeByTestId(FRootNode, AResult.id.Value);
  if not Assigned(lNode) then
    Exit;

  lMessage := AResult.message.Value;
  if lMessage = '' then
    lMessage := AResult.errorMessage.Value;

  SetNodeStatus(lNode, AResult.status.Value, AResult.durationMs.Value,
    lMessage);
end;

procedure TNXTestUIController.UpdateResults(AResults: TNXTestResultArray);
var
  lIndex: Integer;
begin
  if not Assigned(AResults) then
    Exit;

  for lIndex := 0 to AResults.Count - 1 do
    UpdateResult(TNXTestResultValue(AResults[lIndex]));
end;

procedure RunNexusTestUI;
var
  lController: TNXTestUIController;
  lModuleFileName: string;
  lResourceRoot: string;
begin
  if ParamCount > 0 then
    lModuleFileName := ParamStr(1)
  else
    lModuleFileName := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
      '..' + PathDelim + '..' + PathDelim + 'NexusLS' + PathDelim +
      'NexusLSTestModule' + PathDelim + 'NexusLSTestModule' + SharedSuffix;

  lResourceRoot := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    '..' + PathDelim + '..' + PathDelim + 'NexusUI' + PathDelim + 'example';
  if DirectoryExists(lResourceRoot) then
    SetCurrentDir(lResourceRoot);

  Application.Initialize('NexusTest UI', 1100, 720, wspCentered);

  lController := TNXTestUIController.Create(lModuleFileName);
  try
    lController.BuildUI;
    Application.Run;
  finally
    lController.Free;
  end;
end;

end.
