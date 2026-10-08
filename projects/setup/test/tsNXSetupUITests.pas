(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXSetupUITests;

{$mode objfpc}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterSetupUITests(ARegistry: TNXTestRegistry);

implementation

uses SysUtils, fpg_main, fpg_form, obNXTestContext, obNXTestSuite,
  obVTVTree, tpVTV, uiNXSetupMain, obNXSetupModel, tpNXSetup, utNXSetupFiles;

function FindNode(ATree: TfpgVirtualStringTree; const AName: string): PVirtualNode;
begin
  Result := ATree.GetFirst;
  while Result <> nil do
  begin
    if ATree.Text[Result, 0] = AName then Exit;
    Result := ATree.GetNext(Result);
  end;
  raise Exception.Create('Missing feature node: ' + AName);
end;

procedure TestCheckboxes(AContext: TNXTestContext);
var
  lForm: TNXSetupMainForm;
  lEditor, lStable, lDevelopment: PVirtualNode;
begin
  lForm := TNXSetupMainForm.Create(nil);
  try
    lForm.WindowPosition := wpUser;
    lForm.Left := 80;
    lForm.Top := 80;
    lForm.LoadFile(ExpandFileName('projects/setup/examples/Nexus.nxscript'));
    lForm.Show;
    fpgApplication.ProcessMessages;
    AContext.AssertEquals(5, Integer(lForm.Tree.RootNodeCount), 'UI expands only the owned feature roots.');
    AContext.AssertEquals(7, Integer(lForm.Tree.TotalCount), 'Cyclic requirements do not expand into tree copies.');
    lEditor := FindNode(lForm.Tree, 'Editor');
    AContext.AssertTrue(lForm.Tree.CheckState[lEditor] = csCheckedNormal, 'Implied selection is painted checked.');
    lForm.Tree.CheckState[lEditor] := csUncheckedNormal;
    AContext.AssertTrue(lForm.Tree.CheckState[lEditor] = csCheckedNormal,
      'Rejected checkbox removal restores the actual resolved state.');
    lStable := FindNode(lForm.Tree, 'Stable');
    lDevelopment := FindNode(lForm.Tree, 'Development');
    lForm.Tree.CheckState[lStable] := csCheckedNormal;
    lForm.Tree.CheckState[lDevelopment] := csCheckedNormal;
    AContext.AssertTrue(lForm.Tree.CheckState[lStable] = csCheckedNormal, 'The first explicit exclusive choice remains.');
    AContext.AssertTrue(lForm.Tree.CheckState[lDevelopment] = csUncheckedNormal, 'An exclusive conflict is not committed.');
    AContext.AssertEquals(5, lForm.Selection.Selected.Count, 'UI includes the selected child and its parent.');
  finally
    lForm.Free;
  end;
end;

procedure TestReload(AContext: TNXTestContext);
var
  lForm: TNXSetupMainForm;
  lDocument: TNXSetupDocument;
  lFailed: Boolean;
begin
  lForm := TNXSetupMainForm.Create(nil);
  try
    lForm.LoadFile(ExpandFileName('projects/setup/examples/Nexus.nxscript'));
    lForm.LoadFile(ExpandFileName('projects/setup/test/fixtures/Nexus.nxscript'));
    AContext.AssertEquals(7, Integer(lForm.Tree.TotalCount), 'Reload replaces owned nodes rather than appending.');
    lDocument := lForm.Document;
    lFailed := False;
    try lForm.LoadFile(ExpandFileName('projects/setup/test/fixtures/absent.nxscript'));
    except on lError: ENXSetup do lFailed := True; end;
    AContext.AssertTrue(lFailed, 'A missing definition is reported.');
    AContext.AssertTrue(lForm.Document = lDocument, 'A failed load preserves the current document.');
    AContext.AssertEquals(3, lForm.Selection.Selected.Count, 'Selection remains valid after a failed replacement.');
  finally
    lForm.Free;
  end;
end;

procedure TestFileOperations(AContext: TNXTestContext);
var
  lForm: TNXSetupMainForm;
  lWork, lRoot: string;
  lRejected: Boolean;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lRoot := ExpandFileName(lWork + '/installed');
  lForm := TNXSetupMainForm.Create(nil);
  try
    lForm.WindowPosition := wpUser;
    lForm.Left := 80;
    lForm.Top := 80;
    lForm.LoadFile(ExpandFileName('projects/setup/examples/Nexus.nxscript'));
    lForm.Destination.Directory := lRoot;
    lForm.Show;
    lRejected := False;
    try lForm.ExecuteOperation(sopInstall);
    except on lError: ENXSetup do lRejected := True; end;
    AContext.AssertTrue(lRejected, 'An unsupported installation reports its error before returning.');
    AContext.AssertTrue(not lForm.Busy and lForm.Tree.Enabled and lForm.CloseQuery,
      'Failure restores the local busy state and controls.');
    AContext.AssertTrue(not DirectoryExists(lRoot), 'Rejected operations do not write payload files.');
    lForm.LoadFile(ExpandFileName('projects/setup/examples/Files.nxscript'));
    lForm.ExecuteOperation(sopInstall);
    AContext.AssertTrue(not lForm.Busy, 'Installation completes before ExecuteOperation returns.');
    AContext.AssertTrue(Pos('Installed.', lForm.Status.Text) = 1, lForm.Status.Text);
    AContext.AssertTrue(FileExists(lRoot + '/README.md'), 'The GUI executes the real file installer.');
    AContext.AssertTrue(lForm.Tree.Enabled and lForm.CloseQuery, 'Completion restores the controls.');
    lForm.ExecuteOperation(sopUninstall);
    AContext.AssertTrue(not lForm.Busy, 'Uninstall completes before ExecuteOperation returns.');
    AContext.AssertEquals('Uninstall completed.', lForm.Status.Text, 'Removal completion is reported on the GUI thread.');
    AContext.AssertTrue(not FileExists(lRoot + '/README.md'), 'GUI removal uses installed evidence.');
  finally
    lForm.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure TestWizardNavigation(AContext: TNXTestContext);
var
  lForm: TNXSetupMainForm;
  lWork, lRoot: string;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lRoot := ExpandFileName(lWork + '/installed');
  lForm := TNXSetupMainForm.Create(nil);
  try
    lForm.WindowPosition := wpUser;
    lForm.Left := 80;
    lForm.Top := 80;
    lForm.LoadFile(ExpandFileName('projects/setup/examples/Files.nxscript'));
    lForm.Show;
    AContext.AssertTrue(lForm.Page = swpWelcome, 'A loaded installer begins at Welcome.');
    AContext.AssertTrue(not lForm.Tree.Parent.Visible, 'Component selection is not shown on Welcome.');
    AContext.AssertTrue(not lForm.Destination.Parent.Visible, 'Destination editing has its own page.');
    lForm.NextButton.OnClick(lForm.NextButton);
    AContext.AssertTrue(lForm.Page = swpDestination, 'Next opens the destination page.');
    AContext.AssertEquals(lForm.Destination.Parent.Width, lForm.Destination.Width,
      'The integrated folder field fills the destination row.');
    lForm.NextButton.OnClick(lForm.NextButton);
    AContext.AssertTrue(lForm.Page = swpDestination, 'An empty folder cannot advance.');
    AContext.AssertTrue(lForm.Status.Text <> '', 'Invalid folder input has an inline explanation.');
    lForm.Destination.Directory := lRoot;
    lForm.NextButton.OnClick(lForm.NextButton);
    AContext.AssertTrue(lForm.Page = swpComponents, 'A valid folder advances to components.');
    AContext.AssertTrue(lForm.Tree.Parent.Visible, 'Component selection is visible on its page.');
    lForm.BackButton.OnClick(lForm.BackButton);
    AContext.AssertTrue(lForm.Page = swpDestination, 'Back returns to the folder page.');
    AContext.AssertEquals(lRoot, lForm.Destination.Directory, 'Back preserves the selected folder.');
    lForm.NextButton.OnClick(lForm.NextButton);
    lForm.NextButton.OnClick(lForm.NextButton);
    AContext.AssertTrue(lForm.Page = swpReady, 'Selections lead to a review page.');
    AContext.AssertEquals('Install', lForm.NextButton.Text, 'The final action is labeled Install.');
    AContext.AssertTrue(Pos(lRoot, lForm.Summary.Text) > 0, 'Review shows the destination.');
    AContext.AssertTrue(Pos('Documentation', lForm.Summary.Text) > 0, 'Review shows selected components.');
    AContext.AssertTrue(not DirectoryExists(lRoot), 'Navigation and review do not install anything.');
    lForm.NextButton.OnClick(lForm.NextButton);
    AContext.AssertTrue(lForm.Page = swpFinished, 'Successful installation opens the completion page.');
    AContext.AssertEquals('Finish', lForm.NextButton.Text, 'Completion has an explicit Finish action.');
    AContext.AssertTrue(not lForm.BackButton.Visible, 'Completed work cannot navigate back into installation.');
    AContext.AssertTrue(FileExists(lRoot + '/README.md'), 'The wizard installs the real selected payload.');
    AContext.AssertTrue(not lForm.Busy, 'Completion has no pending worker or callback.');
  finally
    lForm.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure TestWizardFailure(AContext: TNXTestContext);
var
  lForm: TNXSetupMainForm;
  lWork, lRoot: string;
begin
  lWork := SetupWorkFolder(ExpandFileName('output'));
  lRoot := ExpandFileName(lWork + '/installed');
  lForm := TNXSetupMainForm.Create(nil);
  try
    lForm.LoadFile(ExpandFileName('projects/setup/examples/Nexus.nxscript'));
    lForm.Destination.Directory := lRoot;
    lForm.NextButton.OnClick(lForm.NextButton);
    lForm.NextButton.OnClick(lForm.NextButton);
    lForm.NextButton.OnClick(lForm.NextButton);
    lForm.NextButton.OnClick(lForm.NextButton);
    AContext.AssertTrue(lForm.Page = swpReady, 'Failed installation returns to review, not completion.');
    AContext.AssertTrue(lForm.Status.Text <> '', 'Installation errors remain visible to the user.');
    AContext.AssertTrue(lForm.Status.Visible, 'The error label is visible after failure.');
    AContext.AssertTrue(lForm.NextButton.Enabled and lForm.BackButton.Enabled,
      'Failure restores navigation and retry controls.');
    AContext.AssertTrue(not lForm.Busy, 'Failure leaves no pending execution state.');
    AContext.AssertTrue(not DirectoryExists(lRoot), 'Unsupported selected work writes no payload.');
  finally
    lForm.Free;
    RemoveSetupTree(lWork);
  end;
end;

procedure RegisterSetupUITests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusSetup.UI');
  lSuite.AddTest('CheckboxesAndFiniteTree', @TestCheckboxes);
  lSuite.AddTest('ReloadOwnership', @TestReload);
  lSuite.AddTest('SynchronousFileOperations', @TestFileOperations);
  lSuite.AddTest('WizardNavigationAndInstallation', @TestWizardNavigation);
  lSuite.AddTest('WizardFailureReturnsToReview', @TestWizardFailure);
end;

end.
