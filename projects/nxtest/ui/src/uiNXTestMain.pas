unit uiNXTestMain;

{$mode objfpc}{$H+}

interface

procedure RunNexusTestUI;

implementation

uses
  Classes,
  SysUtils,
  fpg_base,
  fpg_form,
  fpg_main,
  fpg_stylemanager,
  obNXControls,
  obNXTreeView,
  obNXTestModuleClient,
  obNXTestRPCValues,
  tpNXTest;

type
  TNXTestUINodeKind = (
    nkRoot,
    nkSuite,
    nkCategory,
    nkTest
  );

  TNXTestUINodeRef = class
  private
    FCaption: string;
    FCategoryPath: string;
    FDurationMS: Int64;
    FKind: TNXTestUINodeKind;
    FMessageText: string;
    FStatus: string;
    FSuiteName: string;
    FTestId: string;
    FTestName: string;
  public
    constructor Create(AKind: TNXTestUINodeKind; const ACaption,
      ASuiteName: string; const ATestName: string = '';
      const ATestId: string = ''; const ACategoryPath: string = '');

    property Caption: string read FCaption;
    property CategoryPath: string read FCategoryPath;
    property DurationMS: Int64 read FDurationMS write FDurationMS;
    property Kind: TNXTestUINodeKind read FKind;
    property MessageText: string read FMessageText write FMessageText;
    property Status: string read FStatus write FStatus;
    property SuiteName: string read FSuiteName;
    property TestId: string read FTestId;
    property TestName: string read FTestName;
  end;

  TNXTestMainForm = class(TNXForm)
  private
    FButtonPanel: TNXPanel;
    FBrowseButton: TNXButton;
    FClient: TNXTestModuleClient;
    FDetailsBox: TNXGroupBox;
    FDetailsMemo: TNXMemo;
    FLoadButton: TNXButton;
    FModuleFileName: string;
    FModuleLoadError: string;
    FModulePathEdit: TNXEditBox;
    FModulePathLabel: TNXLabel;
    FNodeRefs: TList;
    FRefreshButton: TNXButton;
    FRootNode: TNXTreeViewNode;
    FRunAllButton: TNXButton;
    FRunSelectedButton: TNXButton;
    FTree: TNXTreeView;

    function AddCategoryPath(ASuiteNode: TNXTreeViewNode;
      const ASuiteName, ACategory: string): TNXTreeViewNode;
    function AddNodeRef(AKind: TNXTestUINodeKind; const ACaption,
      ASuiteName: string; const ATestName: string = '';
      const ATestId: string = '';
      const ACategoryPath: string = ''): TNXTestUINodeRef;
    procedure BrowseButtonClick(Sender: TObject);
    procedure ClearNodeRefs;
    function CountTestNodes(ANode: TNXTreeViewNode): Integer;
    function FindCategoryChild(AParentNode: TNXTreeViewNode;
      const AName: string): TNXTreeViewNode;
    function FindNodeByTestId(ANode: TNXTreeViewNode;
      const ATestId: string): TNXTreeViewNode;
    procedure LoadButtonClick(Sender: TObject);
    procedure LoadModule(const AModuleFileName: string);
    function NodeRef(ANode: TNXTreeViewNode): TNXTestUINodeRef;
    procedure PopulateTree;
    procedure RefreshButtonClick(Sender: TObject);
    function RolledUpStatus(ANode: TNXTreeViewNode): string;
    procedure RunAllButtonClick(Sender: TObject);
    procedure RunSelectedButtonClick(Sender: TObject);
    procedure RunTestsUnderNode(ANode: TNXTreeViewNode);
    procedure SetNodeStatus(ANode: TNXTreeViewNode; const AStatus: string;
      ADurationMS: Int64 = 0; const AMessage: string = '');
    procedure TreeChange(Sender: TObject; ANode: TNXTreeViewNode);
    procedure UpdateDetails(ANode: TNXTreeViewNode);
    procedure UpdateNodeText(ANode: TNXTreeViewNode);
    procedure UpdateParentStatuses(ANode: TNXTreeViewNode);
    procedure UpdateResult(AResult: TNXTestResultValue);
    procedure UpdateResults(AResults: TNXTestResultArray);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterCreate; override;
  end;

constructor TNXTestUINodeRef.Create(AKind: TNXTestUINodeKind;
  const ACaption, ASuiteName: string; const ATestName: string;
  const ATestId: string; const ACategoryPath: string);
begin
  inherited Create;
  FCaption := ACaption;
  FCategoryPath := ACategoryPath;
  FKind := AKind;
  FStatus := cNXTestStatusNotRun;
  FSuiteName := ASuiteName;
  FTestId := ATestId;
  FTestName := ATestName;
end;

constructor TNXTestMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FClient := TNXTestModuleClient.Create;
  FNodeRefs := TList.Create;
end;

destructor TNXTestMainForm.Destroy;
begin
  ClearNodeRefs;
  FreeAndNil(FNodeRefs);
  FreeAndNil(FClient);
  inherited Destroy;
end;

function TNXTestMainForm.AddCategoryPath(ASuiteNode: TNXTreeViewNode;
  const ASuiteName, ACategory: string): TNXTreeViewNode;
var
  lCategory: string;
  lCategoryNode: TNXTreeViewNode;
  lCategoryPath: string;
  lDelimiterIndex: Integer;
  lParentNode: TNXTreeViewNode;
  lSegment: string;
begin
  Result := ASuiteNode;
  lParentNode := ASuiteNode;
  lCategory := ACategory;
  lCategoryPath := '';

  while lCategory <> '' do
  begin
    lDelimiterIndex := Pos('\', lCategory);
    if lDelimiterIndex > 0 then
    begin
      lSegment := Copy(lCategory, 1, lDelimiterIndex - 1);
      Delete(lCategory, 1, lDelimiterIndex);
    end
    else
    begin
      lSegment := lCategory;
      lCategory := '';
    end;

    lSegment := Trim(lSegment);
    if lSegment = '' then
      Continue;

    if lCategoryPath <> '' then
      lCategoryPath := lCategoryPath + '\' + lSegment
    else
      lCategoryPath := lSegment;

    lCategoryNode := FindCategoryChild(lParentNode, lSegment);
    if not Assigned(lCategoryNode) then
    begin
      lCategoryNode := FTree.AddChildNode(lParentNode, lSegment,
        AddNodeRef(nkCategory, lSegment, ASuiteName, '', '', lCategoryPath));
      SetNodeStatus(lCategoryNode, cNXTestStatusNotRun);
    end;

    lParentNode := lCategoryNode;
    Result := lParentNode;
  end;
end;

function TNXTestMainForm.AddNodeRef(AKind: TNXTestUINodeKind;
  const ACaption, ASuiteName: string; const ATestName: string;
  const ATestId: string; const ACategoryPath: string): TNXTestUINodeRef;
begin
  Result := TNXTestUINodeRef.Create(AKind, ACaption, ASuiteName, ATestName,
    ATestId, ACategoryPath);
  FNodeRefs.Add(Result);
end;

procedure TNXTestMainForm.AfterCreate;
begin
  inherited AfterCreate;
  Name := 'NexusTestMainForm';
  Left := 100;
  Top := 80;
  Width := 1100;
  Height := 720;
  WindowPosition := wpScreenCenter;
  WindowTitle := 'NexusTest';
  MinWidth := 760;
  MinHeight := 480;

  FButtonPanel := TNXPanel.Create(Self);
  FButtonPanel.Align := alTop;
  FButtonPanel.Height := 70;

  FModulePathLabel := TNXLabel.Create(FButtonPanel);
  FModulePathLabel.Left := 8;
  FModulePathLabel.Top := 12;
  FModulePathLabel.Width := 72;
  FModulePathLabel.Height := 22;
  FModulePathLabel.Text := 'Module:';

  FModulePathEdit := TNXEditBox.Create(FButtonPanel);
  FModulePathEdit.Left := 82;
  FModulePathEdit.Top := 8;
  FModulePathEdit.Width := 786;
  FModulePathEdit.Height := 26;
  FModulePathEdit.Anchors := [anLeft, anRight, anTop];

  FBrowseButton := TNXButton.Create(FButtonPanel);
  FBrowseButton.Left := 876;
  FBrowseButton.Top := 8;
  FBrowseButton.Width := 96;
  FBrowseButton.Height := 26;
  FBrowseButton.Anchors := [anRight, anTop];
  FBrowseButton.Text := 'Browse...';
  FBrowseButton.OnClick := @BrowseButtonClick;

  FLoadButton := TNXButton.Create(FButtonPanel);
  FLoadButton.Left := 980;
  FLoadButton.Top := 8;
  FLoadButton.Width := 96;
  FLoadButton.Height := 26;
  FLoadButton.Anchors := [anRight, anTop];
  FLoadButton.Text := 'Load';
  FLoadButton.OnClick := @LoadButtonClick;

  FRunAllButton := TNXButton.Create(FButtonPanel);
  FRunAllButton.Left := 8;
  FRunAllButton.Top := 40;
  FRunAllButton.Width := 96;
  FRunAllButton.Height := 24;
  FRunAllButton.Text := 'Run All';
  FRunAllButton.OnClick := @RunAllButtonClick;

  FRunSelectedButton := TNXButton.Create(FButtonPanel);
  FRunSelectedButton.Left := 112;
  FRunSelectedButton.Top := 40;
  FRunSelectedButton.Width := 112;
  FRunSelectedButton.Height := 24;
  FRunSelectedButton.Text := 'Run Selected';
  FRunSelectedButton.OnClick := @RunSelectedButtonClick;

  FRefreshButton := TNXButton.Create(FButtonPanel);
  FRefreshButton.Left := 232;
  FRefreshButton.Top := 40;
  FRefreshButton.Width := 96;
  FRefreshButton.Height := 24;
  FRefreshButton.Text := 'Refresh';
  FRefreshButton.OnClick := @RefreshButtonClick;

  FDetailsBox := TNXGroupBox.Create(Self);
  FDetailsBox.Align := alRight;
  FDetailsBox.Width := 520;
  FDetailsBox.Text := 'Details';

  FDetailsMemo := TNXMemo.Create(FDetailsBox);
  FDetailsMemo.Align := alClient;
  FDetailsMemo.ReadOnly := True;

  FTree := TNXTreeView.Create(Self);
  FTree.Align := alClient;
  FTree.Columns[0].Width := 300;
  FTree.AddColumn('Status', 110);
  FTree.AddColumn('Duration', 90);
  FTree.AddColumn('Message', 360);
  FTree.OnChange := @TreeChange;

  if ParamCount > 0 then
    FModuleFileName := ParamStr(1);
  FModulePathEdit.Text := FModuleFileName;
  LoadModule(FModuleFileName);
  PopulateTree;
end;

procedure TNXTestMainForm.BrowseButtonClick(Sender: TObject);
var
  lDialog: TNXFileDialog;
begin
  lDialog := TNXFileDialog.Create(Self);
  try
    lDialog.Filter := 'Shared libraries (*.dll;*.so;*.dylib)|' +
      '*.dll;*.so;*.dylib|All files (*)|*';
    lDialog.FileName := FModulePathEdit.Text;
    if lDialog.RunOpenFile then
    begin
      FModulePathEdit.Text := lDialog.FileName;
      LoadModule(lDialog.FileName);
      PopulateTree;
    end;
  finally
    lDialog.Free;
  end;
end;

procedure TNXTestMainForm.ClearNodeRefs;
var
  lIndex: Integer;
begin
  if not Assigned(FNodeRefs) then
    Exit;
  for lIndex := 0 to FNodeRefs.Count - 1 do
    TObject(FNodeRefs[lIndex]).Free;
  FNodeRefs.Clear;
end;

function TNXTestMainForm.CountTestNodes(ANode: TNXTreeViewNode): Integer;
var
  lIndex: Integer;
  lRef: TNXTestUINodeRef;
begin
  Result := 0;
  if not Assigned(ANode) then
    Exit;

  lRef := NodeRef(ANode);
  if Assigned(lRef) and (lRef.Kind = nkTest) then
    Exit(1);

  for lIndex := 0 to ANode.ChildCount - 1 do
    Inc(Result, CountTestNodes(ANode.Child[lIndex]));
end;

function TNXTestMainForm.FindCategoryChild(AParentNode: TNXTreeViewNode;
  const AName: string): TNXTreeViewNode;
var
  lChild: TNXTreeViewNode;
  lIndex: Integer;
  lRef: TNXTestUINodeRef;
begin
  Result := nil;
  if not Assigned(AParentNode) then
    Exit;

  for lIndex := 0 to AParentNode.ChildCount - 1 do
  begin
    lChild := AParentNode.Child[lIndex];
    lRef := NodeRef(lChild);
    if Assigned(lRef) and (lRef.Kind = nkCategory) and
      SameText(lRef.Caption, AName) then
      Exit(lChild);
  end;
end;

function TNXTestMainForm.FindNodeByTestId(ANode: TNXTreeViewNode;
  const ATestId: string): TNXTreeViewNode;
var
  lIndex: Integer;
  lRef: TNXTestUINodeRef;
begin
  Result := nil;
  if not Assigned(ANode) then
    Exit;

  lRef := NodeRef(ANode);
  if Assigned(lRef) and (lRef.Kind = nkTest) and
    SameText(lRef.TestId, ATestId) then
    Exit(ANode);

  for lIndex := 0 to ANode.ChildCount - 1 do
  begin
    Result := FindNodeByTestId(ANode.Child[lIndex], ATestId);
    if Assigned(Result) then
      Exit;
  end;
end;

procedure TNXTestMainForm.LoadButtonClick(Sender: TObject);
begin
  LoadModule(FModulePathEdit.Text);
  PopulateTree;
end;

procedure TNXTestMainForm.LoadModule(const AModuleFileName: string);
begin
  FModuleLoadError := '';
  FModuleFileName := AModuleFileName;
  FClient.UnloadModule;

  if Trim(AModuleFileName) = '' then
  begin
    FModuleLoadError :=
      'Choose a test module DLL/shared library, then click Load.';
    Exit;
  end;

  try
    FClient.LoadModule(AModuleFileName);
    FModuleFileName := FClient.LibraryName;
    FModulePathEdit.Text := FModuleFileName;
  except
    on E: Exception do
      FModuleLoadError := E.Message;
  end;
end;

function TNXTestMainForm.NodeRef(ANode: TNXTreeViewNode): TNXTestUINodeRef;
begin
  Result := nil;
  if Assigned(ANode) then
    Result := TNXTestUINodeRef(ANode.Data);
end;

procedure TNXTestMainForm.PopulateTree;
var
  lRegistry: TNXTestRegistryValue;
  lSuite: TNXTestSuiteInfoValue;
  lSuiteIndex: Integer;
  lSuiteNode: TNXTreeViewNode;
  lTest: TNXTestCaseInfoValue;
  lTestIndex: Integer;
  lTestNode: TNXTreeViewNode;
  lTestParentNode: TNXTreeViewNode;
begin
  if not Assigned(FTree) then
    Exit;

  FTree.Clear;
  ClearNodeRefs;
  FRootNode := FTree.AddNode('NexusTest',
    AddNodeRef(nkRoot, 'NexusTest', ''));
  SetNodeStatus(FRootNode, cNXTestStatusNotRun);

  if FModuleLoadError <> '' then
  begin
    SetNodeStatus(FRootNode, cNXTestStatusError, 0, FModuleLoadError);
    FTree.SelectedNode := FRootNode;
    UpdateDetails(FRootNode);
    Exit;
  end;

  try
    lRegistry := FClient.ListTests;
  except
    on E: Exception do
    begin
      SetNodeStatus(FRootNode, cNXTestStatusError, 0, E.Message);
      FTree.SelectedNode := FRootNode;
      UpdateDetails(FRootNode);
      Exit;
    end;
  end;

  try
    for lSuiteIndex := 0 to lRegistry.suites.Count - 1 do
    begin
      lSuite := TNXTestSuiteInfoValue(lRegistry.suites[lSuiteIndex]);
      lSuiteNode := FTree.AddChildNode(FRootNode, lSuite.name.Value,
        AddNodeRef(nkSuite, lSuite.name.Value, lSuite.name.Value));
      SetNodeStatus(lSuiteNode, cNXTestStatusNotRun);

      for lTestIndex := 0 to lSuite.tests.Count - 1 do
      begin
        lTest := TNXTestCaseInfoValue(lSuite.tests[lTestIndex]);
        lTestParentNode := AddCategoryPath(lSuiteNode, lSuite.name.Value,
          lTest.category.Value);
        lTestNode := FTree.AddChildNode(lTestParentNode, lTest.name.Value,
          AddNodeRef(nkTest, lTest.name.Value, lSuite.name.Value,
          lTest.name.Value, lTest.id.Value, lTest.category.Value));
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

procedure TNXTestMainForm.RefreshButtonClick(Sender: TObject);
begin
  PopulateTree;
end;

function TNXTestMainForm.RolledUpStatus(ANode: TNXTreeViewNode): string;
var
  lAllNotRun: Boolean;
  lAllPassedOrSkipped: Boolean;
  lAnyError: Boolean;
  lAnyFailed: Boolean;
  lAnyRunning: Boolean;
  lChild: TNXTreeViewNode;
  lIndex: Integer;
  lStatus: string;
begin
  Result := cNXTestStatusNotRun;
  if not Assigned(ANode) then
    Exit;
  if ANode.ChildCount = 0 then
    Exit(NodeRef(ANode).Status);

  lAllNotRun := True;
  lAllPassedOrSkipped := True;
  lAnyError := False;
  lAnyFailed := False;
  lAnyRunning := False;
  for lIndex := 0 to ANode.ChildCount - 1 do
  begin
    lChild := ANode.Child[lIndex];
    lStatus := NodeRef(lChild).Status;
    if SameText(lStatus, cNXTestStatusError) then
      lAnyError := True
    else if SameText(lStatus, cNXTestStatusFailed) then
      lAnyFailed := True
    else if SameText(lStatus, cNXTestStatusRunning) then
      lAnyRunning := True;

    if not (SameText(lStatus, cNXTestStatusPassed) or
      SameText(lStatus, cNXTestStatusSkipped)) then
      lAllPassedOrSkipped := False;
    if not SameText(lStatus, cNXTestStatusNotRun) then
      lAllNotRun := False;
  end;

  if lAnyError then
    Result := cNXTestStatusError
  else if lAnyFailed then
    Result := cNXTestStatusFailed
  else if lAnyRunning then
    Result := cNXTestStatusRunning
  else if lAllPassedOrSkipped then
    Result := cNXTestStatusPassed
  else if lAllNotRun then
    Result := cNXTestStatusNotRun
  else
    Result := cNXTestStatusMixed;
end;

procedure TNXTestMainForm.RunAllButtonClick(Sender: TObject);
var
  lResult: TNXTestRunAllResultValue;
begin
  SetNodeStatus(FRootNode, cNXTestStatusRunning);
  fpgApplication.ProcessMessages;
  try
    lResult := FClient.RunAll;
    try
      UpdateResults(lResult.results);
    finally
      lResult.Free;
    end;
    UpdateParentStatuses(FRootNode);
  except
    on E: Exception do
      SetNodeStatus(FRootNode, cNXTestStatusError, 0, E.Message);
  end;
  UpdateDetails(FTree.SelectedNode);
end;

procedure TNXTestMainForm.RunSelectedButtonClick(Sender: TObject);
var
  lNode: TNXTreeViewNode;
  lRef: TNXTestUINodeRef;
  lResult: TNXTestResultValue;
  lSuiteResult: TNXTestRunSuiteResultValue;
begin
  lNode := FTree.SelectedNode;
  lRef := NodeRef(lNode);
  if not Assigned(lRef) then
    Exit;

  case lRef.Kind of
    nkRoot:
      RunAllButtonClick(Sender);
    nkSuite:
    begin
      SetNodeStatus(lNode, cNXTestStatusRunning);
      fpgApplication.ProcessMessages;
      try
        lSuiteResult := FClient.RunSuite(lRef.SuiteName);
        try
          UpdateResults(lSuiteResult.results);
        finally
          lSuiteResult.Free;
        end;
        UpdateParentStatuses(FRootNode);
      except
        on E: Exception do
          SetNodeStatus(lNode, cNXTestStatusError, 0, E.Message);
      end;
    end;
    nkCategory:
    begin
      SetNodeStatus(lNode, cNXTestStatusRunning);
      fpgApplication.ProcessMessages;
      RunTestsUnderNode(lNode);
      UpdateParentStatuses(FRootNode);
    end;
    nkTest:
    begin
      SetNodeStatus(lNode, cNXTestStatusRunning);
      fpgApplication.ProcessMessages;
      try
        lResult := FClient.RunTest(lRef.TestId);
        try
          UpdateResult(lResult);
        finally
          lResult.Free;
        end;
        UpdateParentStatuses(FRootNode);
      except
        on E: Exception do
          SetNodeStatus(lNode, cNXTestStatusError, 0, E.Message);
      end;
    end;
  end;
  UpdateDetails(FTree.SelectedNode);
end;

procedure TNXTestMainForm.RunTestsUnderNode(ANode: TNXTreeViewNode);
var
  lIndex: Integer;
  lRef: TNXTestUINodeRef;
  lResult: TNXTestResultValue;
begin
  if not Assigned(ANode) then
    Exit;
  lRef := NodeRef(ANode);
  if Assigned(lRef) and (lRef.Kind = nkTest) then
  begin
    SetNodeStatus(ANode, cNXTestStatusRunning);
    fpgApplication.ProcessMessages;
    try
      lResult := FClient.RunTest(lRef.TestId);
      try
        UpdateResult(lResult);
      finally
        lResult.Free;
      end;
    except
      on E: Exception do
        SetNodeStatus(ANode, cNXTestStatusError, 0, E.Message);
    end;
    Exit;
  end;

  for lIndex := 0 to ANode.ChildCount - 1 do
    RunTestsUnderNode(ANode.Child[lIndex]);
end;

procedure TNXTestMainForm.SetNodeStatus(ANode: TNXTreeViewNode;
  const AStatus: string; ADurationMS: Int64; const AMessage: string);
var
  lRef: TNXTestUINodeRef;
begin
  lRef := NodeRef(ANode);
  if not Assigned(lRef) then
    Exit;
  lRef.Status := AStatus;
  lRef.DurationMS := ADurationMS;
  lRef.MessageText := AMessage;
  UpdateNodeText(ANode);
end;

procedure TNXTestMainForm.TreeChange(Sender: TObject; ANode: TNXTreeViewNode);
begin
  UpdateDetails(ANode);
end;

procedure TNXTestMainForm.UpdateDetails(ANode: TNXTreeViewNode);
var
  lRef: TNXTestUINodeRef;
begin
  if not Assigned(FDetailsMemo) then
    Exit;
  FDetailsMemo.Clear;
  if not Assigned(ANode) then
  begin
    FDetailsMemo.Lines.Add('No selection.');
    Exit;
  end;

  lRef := NodeRef(ANode);
  if not Assigned(lRef) then
  begin
    FDetailsMemo.Lines.Add(ANode.Text);
    Exit;
  end;

  case lRef.Kind of
    nkRoot:
    begin
      FDetailsMemo.Lines.Add('Root: NexusTest');
      if FModulePathEdit.Text <> '' then
        FDetailsMemo.Lines.Add('Module: ' + FModulePathEdit.Text)
      else if FClient.LibraryName <> '' then
        FDetailsMemo.Lines.Add('Module: ' + FClient.LibraryName);
    end;
    nkSuite:
    begin
      FDetailsMemo.Lines.Add('Suite: ' + lRef.SuiteName);
      FDetailsMemo.Lines.Add('Tests: ' + IntToStr(CountTestNodes(ANode)));
    end;
    nkCategory:
    begin
      FDetailsMemo.Lines.Add('Category: ' + lRef.CategoryPath);
      FDetailsMemo.Lines.Add('Suite: ' + lRef.SuiteName);
      FDetailsMemo.Lines.Add('Tests: ' + IntToStr(CountTestNodes(ANode)));
    end;
    nkTest:
    begin
      FDetailsMemo.Lines.Add('Test: ' + lRef.TestName);
      FDetailsMemo.Lines.Add('Suite: ' + lRef.SuiteName);
      if lRef.CategoryPath <> '' then
        FDetailsMemo.Lines.Add('Category: ' + lRef.CategoryPath);
      FDetailsMemo.Lines.Add('ID: ' + lRef.TestId);
    end;
  end;

  FDetailsMemo.Lines.Add('Status: ' + lRef.Status);
  if lRef.DurationMS > 0 then
    FDetailsMemo.Lines.Add('Duration: ' + IntToStr(lRef.DurationMS) + ' ms');
  if lRef.MessageText <> '' then
    FDetailsMemo.Lines.Add('Message: ' + lRef.MessageText);
end;

procedure TNXTestMainForm.UpdateNodeText(ANode: TNXTreeViewNode);
var
  lRef: TNXTestUINodeRef;
begin
  lRef := NodeRef(ANode);
  if not Assigned(lRef) then
    Exit;
  ANode.Text := lRef.Caption;
  ANode.Cell[1].Text := lRef.Status;
  ANode.Cell[1].GlyphKind := tvgkCircle;
  ANode.Cell[1].UseGlyphColor := True;

  if SameText(lRef.Status, cNXTestStatusPassed) then
    ANode.Cell[1].GlyphColor := clGreen
  else if SameText(lRef.Status, cNXTestStatusFailed) or
    SameText(lRef.Status, cNXTestStatusError) then
    ANode.Cell[1].GlyphColor := clRed
  else if SameText(lRef.Status, cNXTestStatusRunning) then
    ANode.Cell[1].GlyphColor := clBlue
  else if SameText(lRef.Status, cNXTestStatusSkipped) then
    ANode.Cell[1].GlyphColor := clYellow
  else
    ANode.Cell[1].GlyphColor := clGray;

  if lRef.DurationMS > 0 then
    ANode.Cell[2].Text := IntToStr(lRef.DurationMS) + ' ms'
  else
    ANode.Cell[2].Text := '';
  ANode.Cell[3].Text := lRef.MessageText;
  FTree.NodeChanged(ANode);
end;

procedure TNXTestMainForm.UpdateParentStatuses(ANode: TNXTreeViewNode);
var
  lIndex: Integer;
begin
  if not Assigned(ANode) then
    Exit;
  for lIndex := 0 to ANode.ChildCount - 1 do
    UpdateParentStatuses(ANode.Child[lIndex]);
  if ANode.ChildCount > 0 then
    SetNodeStatus(ANode, RolledUpStatus(ANode));
end;

procedure TNXTestMainForm.UpdateResult(AResult: TNXTestResultValue);
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

procedure TNXTestMainForm.UpdateResults(AResults: TNXTestResultArray);
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
  lMainForm: TNXTestMainForm;
begin
  fpgApplication.Initialize;
  fpgStyleManager.SetStyle('Plastic Dark');
  fpgStyle := fpgStyleManager.Style;
  fpgApplication.AppTitle := 'NexusTest';
  lMainForm := TNXTestMainForm.Create(nil);
  try
    lMainForm.Show;
    fpgApplication.Run;
  finally
    lMainForm.Free;
  end;
end;

end.
