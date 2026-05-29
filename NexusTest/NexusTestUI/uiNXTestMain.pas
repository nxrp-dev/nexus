unit uiNXTestMain;

{$mode objfpc}{$H+}

interface

procedure RunNexusTestUI;

implementation

uses
  Classes,
  DynLibs,
  SysUtils,
  {$IFDEF MSWINDOWS}
  Windows,
  CommDlg,
  {$ENDIF}
  obNXApplication,
  obNXButton,
  obNXControl,
  obNXEditBox,
  obNXGroupBox,
  obNXLabel,
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
    FBrowseButton: TNXButton;
    FDetailsBox: TNXGroupBox;
    FDetailsMemo: TNXMemo;
    FClient: TNXTestModuleClient;
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

    function AddNodeRef(AKind: TNXTestUINodeKind; const ASuiteName: string;
      const ATestName: string = ''; const ATestId: string = ''): TNXTestUINodeRef;
    procedure BrowseButtonClick(Sender: TObject; X, Y: Integer;
      Button: TNXMouseButton);
    procedure ClearNodeRefs;
    function FindNodeByTestId(ANode: TNXTreeViewNode;
      const ATestId: string): TNXTreeViewNode;
    procedure LoadButtonClick(Sender: TObject; X, Y: Integer;
      Button: TNXMouseButton);
    procedure LoadModule(const AModuleFileName: string);
    function NodeRef(ANode: TNXTreeViewNode): TNXTestUINodeRef;
    procedure PopulateTree;
    function RolledUpStatus(ANode: TNXTreeViewNode): string;
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
    procedure UpdateParentStatuses(ANode: TNXTreeViewNode);
    procedure UpdateResult(AResult: TNXTestResultValue);
    procedure UpdateResults(AResults: TNXTestResultArray);
  public
    constructor Create(const AModuleFileName: string);
    destructor Destroy; override;

    procedure BuildUI;
  end;

function BrowseForModuleFile(const AInitialFileName: string;
  out AFileName: string): Boolean; forward;

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

  LoadModule(AModuleFileName);
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
  FButtonPanel.Height := 70;
  FButtonPanel.BorderStyle := BS_None;
  FButtonPanel.Align := caTop;

  FModulePathLabel := TNXLabel.Create(FButtonPanel);
  FModulePathLabel.SetBounds(8, 10, 80, 20);
  FModulePathLabel.Caption := 'Module:';
  FModulePathLabel.VertA := VAlign_Center;

  FModulePathEdit := TNXEditBox.Create(FButtonPanel);
  FModulePathEdit.SetBounds(88, 8, 700, 24);
  FModulePathEdit.Text := FModuleFileName;
  FModulePathEdit.Placeholder := 'Choose or enter an NXTest DLL/shared library path';

  FBrowseButton := TNXButton.Create(FButtonPanel);
  FBrowseButton.SetBounds(796, 7, 82, 24);
  FBrowseButton.Caption := 'Browse...';
  FBrowseButton.OnMouseClick := @BrowseButtonClick;

  FLoadButton := TNXButton.Create(FButtonPanel);
  FLoadButton.SetBounds(886, 7, 70, 24);
  FLoadButton.Caption := 'Load';
  FLoadButton.OnMouseClick := @LoadButtonClick;

  FRunAllButton := TNXButton.Create(FButtonPanel);
  FRunAllButton.SetBounds(8, 39, 90, 24);
  FRunAllButton.Caption := 'Run All';
  FRunAllButton.OnMouseClick := @RunAllButtonClick;

  FRunSelectedButton := TNXButton.Create(FButtonPanel);
  FRunSelectedButton.SetBounds(106, 39, 105, 24);
  FRunSelectedButton.Caption := 'Run Selected';
  FRunSelectedButton.OnMouseClick := @RunSelectedButtonClick;

  FRefreshButton := TNXButton.Create(FButtonPanel);
  FRefreshButton.SetBounds(219, 39, 90, 24);
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

procedure TNXTestUIController.BrowseButtonClick(Sender: TObject; X,
  Y: Integer; Button: TNXMouseButton);
var
  lFileName: string;
begin
  if Button <> mbLeft then
    Exit;

  lFileName := FModulePathEdit.Text;
  if BrowseForModuleFile(lFileName, lFileName) then
  begin
    FModulePathEdit.Text := lFileName;
    LoadModule(lFileName);
    PopulateTree;
  end;
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

procedure TNXTestUIController.LoadButtonClick(Sender: TObject; X, Y: Integer;
  Button: TNXMouseButton);
begin
  if Button <> mbLeft then
    Exit;

  LoadModule(FModulePathEdit.Text);
  PopulateTree;
end;

procedure TNXTestUIController.LoadModule(const AModuleFileName: string);
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
  except
    on E: Exception do
      FModuleLoadError := E.Message;
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

function TNXTestUIController.RolledUpStatus(ANode: TNXTreeViewNode): string;
var
  lIndex: Integer;
  lStatus: string;
  lAnyError: Boolean;
  lAnyFailed: Boolean;
  lAnyRunning: Boolean;
  lAllPassedOrSkipped: Boolean;
  lAllNotRun: Boolean;
begin
  Result := cNXTestStatusNotRun;
  if not Assigned(ANode) then
    Exit;

  if ANode.ChildCount <= 0 then
    Exit(ANode.Cell[1].Text);

  lAnyError := False;
  lAnyFailed := False;
  lAnyRunning := False;
  lAllPassedOrSkipped := True;
  lAllNotRun := True;

  for lIndex := 0 to ANode.ChildCount - 1 do
  begin
    lStatus := ANode.Child[lIndex].Cell[1].Text;

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

procedure TNXTestUIController.RunAllButtonClick(Sender: TObject; X,
  Y: Integer; Button: TNXMouseButton);
var
  lResult: TNXTestRunAllResultValue;
begin
  if Button <> mbLeft then
    Exit;

  SetNodeStatus(FRootNode, cNXTestStatusRunning);
  Application.Render;

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
      SetNodeStatus(lNode, cNXTestStatusRunning);
      Application.Render;
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

    nkTest:
    begin
      SetNodeStatus(lNode, cNXTestStatusRunning);
      Application.Render;
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
  else if SameText(AStatus, cNXTestStatusRunning) then
    ANode.Cell[1].GlyphColor := MakeNXColor(70, 145, 230, 255)
  else if SameText(AStatus, cNXTestStatusMixed) then
    ANode.Cell[1].GlyphColor := MakeNXColor(210, 165, 60, 255)
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

procedure TNXTestUIController.UpdateParentStatuses(ANode: TNXTreeViewNode);
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
    begin
      FDetailsMemo.AddLine('Root: NexusTest');
      if Assigned(FModulePathEdit) and (FModulePathEdit.Text <> '') then
        FDetailsMemo.AddLine('Module: ' + FModulePathEdit.Text)
      else if FModuleFileName <> '' then
        FDetailsMemo.AddLine('Module: ' + FModuleFileName)
      else if FClient.LibraryName <> '' then
        FDetailsMemo.AddLine('Module: ' + FClient.LibraryName);
    end;
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

function BrowseForModuleFile(const AInitialFileName: string;
  out AFileName: string): Boolean;
{$IFDEF MSWINDOWS}
var
  lDialog: TOpenFileName;
  lFileName: array[0..4095] of Char;
  lFilter: string;
  lInitialDir: string;
begin
  FillChar(lDialog, SizeOf(lDialog), 0);
  FillChar(lFileName, SizeOf(lFileName), 0);
  StrPLCopy(lFileName, AInitialFileName, High(lFileName));

  lInitialDir := ExtractFilePath(AInitialFileName);
  lFilter := 'Shared libraries (*.dll;*.so;*.dylib)'#0'*.dll;*.so;*.dylib'#0 +
    'All files (*.*)'#0'*.*'#0#0;

  lDialog.lStructSize := SizeOf(lDialog);
  lDialog.lpstrFile := lFileName;
  lDialog.nMaxFile := SizeOf(lFileName);
  lDialog.lpstrFilter := PChar(lFilter);
  lDialog.lpstrTitle := 'Select NXTest Module';
  if lInitialDir <> '' then
    lDialog.lpstrInitialDir := PChar(lInitialDir);
  lDialog.Flags := OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or
    OFN_HIDEREADONLY or OFN_NOCHANGEDIR;

  Result := GetOpenFileName(@lDialog);
  if Result then
    AFileName := StrPas(lFileName);
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

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
    lModuleFileName := '';

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
