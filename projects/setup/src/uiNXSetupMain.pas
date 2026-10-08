(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)



unit uiNXSetupMain;

{$mode objfpc}{$H+}

interface

uses Classes, Generics.Collections, obNXControls, obNXVirtualTreeView,
  obVTVTree, tpVTV, obNXSetupModel, obNXSetupSelection, fpg_base, fpg_widget,
  obNXSetupSession, tpNXSetup, fpg_editbtn;

type
  TNXSetupMainForm = class(TNXForm)
  private
    FDocument: TNXSetupDocument;
    FSelection: TNXSetupSelection;
    FSession: TNXSetupSession;
    FNodes: specialize TDictionary<TNXSetupFeature, PVirtualNode>;
    FUpdating, FBusy: Boolean;
    FPage: TNXSetupWizardPage;
    FPages: array[TNXSetupWizardPage] of TfpgWidget;
    FSteps: array[0..3] of TNXLabel;
    FProduct, FVersion, FTitle, FCaption, FWelcome, FResult: TNXLabel;
    FStatus: TNXLabel;
    FSummary: TNXMemo;
    FTree: TNXVirtualTreeView;
    FRoot: TfpgDirectoryEdit;
    FOpen, FBack, FNext, FCancel, FRepair, FRemove: TNXButton;
    procedure CreateChrome;
    procedure CreatePages;
    procedure SetSession(ASession: TNXSetupSession);
    procedure ShowPage(APage: TNXSetupWizardPage);
    procedure UpdateButtons;
    procedure RefreshSummary;
    function StateFile: string;
    procedure NextClicked(ASender: TObject);
    procedure BackClicked(ASender: TObject);
    procedure CancelClicked(ASender: TObject);
    procedure OperationClicked(ASender: TObject);
  protected
    procedure GetText(ASender: TfpgVirtualStringTree; ANode: PVirtualNode;
      AColumn: TColumnIndex; var AText: string);
    procedure Checked(ASender: TfpgVirtualStringTree; ANode: PVirtualNode);
    procedure OpenClicked(ASender: TObject);
    procedure AddFeature(AFeature: TNXSetupFeature; AParent: PVirtualNode);
    procedure RefreshSelection;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterCreate; override;
    procedure LoadFile(const AFileName: string);
    procedure LoadExecutable(const AFileName: string);
    procedure ExecuteOperation(AOperation: TNXSetupOperation);
    function CloseQuery: Boolean; override;
    property Document: TNXSetupDocument read FDocument;
    property Selection: TNXSetupSelection read FSelection;
    property Tree: TNXVirtualTreeView read FTree;
    property Destination: TfpgDirectoryEdit read FRoot;
    property Busy: Boolean read FBusy;
    property Status: TNXLabel read FStatus;
    property Page: TNXSetupWizardPage read FPage;
    property NextButton: TNXButton read FNext;
    property BackButton: TNXButton read FBack;
    property Summary: TNXMemo read FSummary;
  end;

procedure RunNexusSetup;

implementation

uses SysUtils, fpg_main, fpg_form, fpg_stylemanager, fpg_dialogs,
  obNXSetupState, obNXSetupBundle, obNXSetupFileInstaller, obNXSkin;

const
  cPageColor = $FFFFFF;
  cTextColor = $243044;
  cMutedColor = $617086;
  cSideColor = $20334E;
  cSideMutedColor = $A5B5CC;
  cAccentColor = $64BCDB;
  cErrorColor = $B33535;
  cTitles: array[TNXSetupWizardPage] of string = (
    'Welcome', 'Installation folder', 'Select components', 'Ready to install',
    'Installing', 'Installation complete');
  cCaptions: array[TNXSetupWizardPage] of string = (
    'A few simple steps to get started.',
    'Choose where you want the application installed.',
    'Choose the components you want to install.',
    'Review your choices before making changes.',
    'Please wait while Setup installs the selected files.',
    'Setup has finished.');

type
  TNXSetupDirectoryEdit = class(TfpgDirectoryEdit)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  PFeatureData = ^TFeatureData;
  TFeatureData = record
    Feature: TNXSetupFeature;
  end;

constructor TNXSetupDirectoryEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEdit.FontDesc := 'Liberation Sans-10';
end;

function NewSurface(AParent: TfpgWidget; ALeft, ATop, AWidth, AHeight: Integer;
  AColor: TfpgColor): TfpgWidget;
begin
  Result := TfpgWidget.Create(AParent);
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Height := AHeight;
  Result.BackgroundColor := AColor;
end;

function NewLabel(AParent: TfpgWidget; ALeft, ATop, AWidth, AHeight: Integer;
  const AText, AFont: string; AColor: TfpgColor = cTextColor): TNXLabel;
begin
  Result := TNXLabel.Create(AParent);
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Height := AHeight;
  Result.Text := AText;
  Result.FontDesc := AFont;
  Result.TextColor := AColor;
  Result.BackgroundColor := AParent.BackgroundColor;
  Result.WrapText := True;
  Result.Anchors := [anLeft, anRight, anTop];
end;

function NewButton(AParent: TfpgWidget; ALeft, ATop, AWidth: Integer;
  const AText: string; AClick: TNotifyEvent): TNXButton;
begin
  Result := TNXButton.Create(AParent);
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Height := 32;
  Result.Text := AText;
  Result.FontDesc := 'Liberation Sans-10';
  Result.OnClick := AClick;
end;

constructor TNXSetupMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FNodes := specialize TDictionary<TNXSetupFeature, PVirtualNode>.Create;
end;

destructor TNXSetupMainForm.Destroy;
begin
  if FTree <> nil then
  begin
    FTree.OnChecked := nil;
    FTree.OnGetText := nil;
    FTree.Clear;
  end;
  FNodes.Free;
  FSession.Free;
  inherited Destroy;
end;

procedure TNXSetupMainForm.AfterCreate;
begin
  inherited AfterCreate;
  WindowTitle := 'Nexus Setup';
  WindowPosition := wpScreenCenter;
  Width := 800;
  Height := 540;
  MinWidth := 800;
  MinHeight := 540;
  BackgroundColor := cPageColor;
  TextColor := cTextColor;
  CreateChrome;
  CreatePages;
  ShowPage(swpWelcome);
end;

procedure TNXSetupMainForm.CreateChrome;
const
  cSteps: array[0..3] of string = ('1   Welcome', '2   Folder',
    '3   Components', '4   Install');
var
  lSide, lFooter, lRule: TfpgWidget;
  lIndex: Integer;
begin
  lSide := NewSurface(Self, 0, 0, 184, 540, cSideColor);
  lSide.Anchors := [anLeft, anTop, anBottom];
  NewLabel(lSide, 24, 30, 140, 36, 'NEXUS', 'Liberation Sans-20:bold', cPageColor);
  NewSurface(lSide, 24, 78, 40, 3, cAccentColor);
  FProduct := NewLabel(lSide, 24, 106, 140, 74, 'Setup',
    'Liberation Sans-12:bold', cPageColor);
  FVersion := NewLabel(lSide, 24, 182, 140, 24, '', 'Liberation Sans-10', cSideMutedColor);
  for lIndex := 0 to 3 do
    FSteps[lIndex] := NewLabel(lSide, 24, 244 + lIndex * 38, 140, 26,
      cSteps[lIndex], 'Liberation Sans-10', cSideMutedColor);
  NewLabel(lSide, 24, 488, 140, 24, 'Nexus Setup', 'Liberation Sans-9',
    cSideMutedColor).Anchors := [anLeft, anBottom];
  FTitle := NewLabel(Self, 224, 30, 544, 42, 'Welcome', 'Liberation Sans-21:bold');
  FCaption := NewLabel(Self, 224, 82, 544, 42, '', 'Liberation Sans-10', cMutedColor);
  FStatus := NewLabel(Self, 224, 426, 544, 36, '', 'Liberation Sans-9', cErrorColor);
  FStatus.Anchors := [anLeft, anRight, anBottom];
  lFooter := NewSurface(Self, 184, 470, 616, 70, $F3F5F8);
  lFooter.Anchors := [anLeft, anRight, anBottom];
  lRule := NewSurface(lFooter, 0, 0, 616, 1, $E1E6EE);
  lRule.Anchors := [anLeft, anRight, anTop];
  FBack := NewButton(lFooter, 280, 18, 88, '< Back', @BackClicked);
  FNext := NewButton(lFooter, 380, 18, 104, 'Next >', @NextClicked);
  FNext.Default := True;
  FCancel := NewButton(lFooter, 504, 18, 88, 'Cancel', @CancelClicked);
  FBack.Anchors := [anRight, anTop];
  FNext.Anchors := [anRight, anTop];
  FCancel.Anchors := [anRight, anTop];
end;

procedure TNXSetupMainForm.CreatePages;
var
  lPage: TNXSetupWizardPage;
  lFrame: TfpgWidget;
  lLabel: TNXLabel;
begin
  for lPage := Low(TNXSetupWizardPage) to High(TNXSetupWizardPage) do
  begin
    FPages[lPage] := NewSurface(Self, 224, 134, 544, 278, cPageColor);
    FPages[lPage].Anchors := [anLeft, anRight, anTop, anBottom];
    FPages[lPage].Visible := False;
  end;
  lFrame := FPages[swpWelcome];
  FWelcome := NewLabel(lFrame, 0, 14, 544, 130,
    'Choose a setup file to begin.', 'Liberation Sans-11');
  NewLabel(lFrame, 0, 194, 544, 54,
    'Click Next to continue, or Cancel to leave Setup.',
    'Liberation Sans-10', cMutedColor);
  FOpen := NewButton(lFrame, 0, 158, 176, 'Choose setup file...', @OpenClicked);
  lFrame := FPages[swpDestination];
  lLabel := NewLabel(lFrame, 0, 18, 544, 24, 'Installation folder',
    'Liberation Sans-10:bold');
  FRoot := TNXSetupDirectoryEdit.Create(lFrame);
  FRoot.Left := 0;
  FRoot.Top := 56;
  FRoot.Width := 544;
  FRoot.Height := 32;
  FRoot.Anchors := [anLeft, anRight, anTop];
  lLabel.FocusWidget := FRoot;
  NewLabel(lFrame, 0, 110, 544, 76,
    'Enter a full folder path, or click the folder button to select a folder.' + LineEnding +
    'Setup will create the folder if it does not exist.',
    'Liberation Sans-10', cMutedColor);
  lFrame := FPages[swpComponents];
  FTree := TNXVirtualTreeView.Create(lFrame);
  FTree.Left := 0;
  FTree.Top := 0;
  FTree.Width := 544;
  FTree.Height := 248;
  FTree.Anchors := [anLeft, anRight, anTop, anBottom];
  FTree.FontDesc := 'Liberation Sans-10';
  FTree.NodeDataSize := SizeOf(TFeatureData);
  FTree.DefaultNodeHeight := 28;
  FTree.Header.Columns[0].Text := 'Component';
  FTree.Header.Columns[0].Width := 278;
  FTree.Header.Columns.Add.Text := 'Selection';
  FTree.Header.Columns[1].Width := 244;
  FTree.TreeOptions.MiscOptions := FTree.TreeOptions.MiscOptions + [toCheckSupport];
  FTree.TreeOptions.AutoOptions := [];
  FTree.OnGetText := @GetText;
  FTree.OnChecked := @Checked;
  NewLabel(lFrame, 0, 256, 544, 22,
    'Required components are selected automatically.',
    'Liberation Sans-9', cMutedColor).Anchors := [anLeft, anRight, anBottom];
  lFrame := FPages[swpReady];
  FSummary := TNXMemo.Create(lFrame);
  FSummary.Left := 0;
  FSummary.Top := 0;
  FSummary.Width := 544;
  FSummary.Height := 192;
  FSummary.Anchors := [anLeft, anRight, anTop, anBottom];
  FSummary.ReadOnly := True;
  FSummary.BorderStyle := ebsNone;
  FSummary.BackgroundColor := cPageColor;
  FSummary.TextColor := cTextColor;
  FSummary.FontDesc := 'Liberation Sans-10';
  FRepair := NewButton(lFrame, 0, 228, 156, 'Repair existing files', @OperationClicked);
  FRemove := NewButton(lFrame, 168, 228, 156, 'Uninstall...', @OperationClicked);
  FRepair.Anchors := [anLeft, anBottom];
  FRemove.Anchors := [anLeft, anBottom];
  NewLabel(FPages[swpInstalling], 0, 18, 544, 76,
    'Copying the selected files and saving installation information.' + LineEnding +
    'Do not close Setup until this operation has finished.',
    'Liberation Sans-11');
  lFrame := FPages[swpFinished];
  NewLabel(lFrame, 0, 12, 544, 32, 'All done.', 'Liberation Sans-16:bold', $247653);
  FResult := NewLabel(lFrame, 0, 68, 544, 162, '', 'Liberation Sans-11');
  NewLabel(lFrame, 0, 238, 544, 32, 'Click Finish to close Setup.',
    'Liberation Sans-10', cMutedColor).Anchors := [anLeft, anRight, anBottom];
end;

procedure TNXSetupMainForm.ShowPage(APage: TNXSetupWizardPage);
var
  lPage: TNXSetupWizardPage;
  lStep, lIndex: Integer;
begin
  FPage := APage;
  for lPage := Low(TNXSetupWizardPage) to High(TNXSetupWizardPage) do
    FPages[lPage].Visible := lPage = APage;
  FTitle.Text := cTitles[APage];
  FCaption.Text := cCaptions[APage];
  FStatus.Visible := APage <> swpFinished;
  lStep := Ord(APage);
  if lStep > 3 then lStep := 3;
  for lIndex := 0 to 3 do
    if lIndex = lStep then FSteps[lIndex].TextColor := cPageColor
    else FSteps[lIndex].TextColor := cSideMutedColor;
  if APage = swpReady then RefreshSummary;
  UpdateButtons;
  if Visible then
    if APage = swpDestination then FRoot.SetFocus
    else if not FBusy then FNext.SetFocus;
end;

procedure TNXSetupMainForm.UpdateButtons;
var
  lInstalled: Boolean;
begin
  FBack.Visible := FPage in [swpDestination, swpComponents, swpReady];
  FBack.Enabled := not FBusy;
  FNext.Enabled := not FBusy and (FSession <> nil);
  FCancel.Visible := FPage <> swpFinished;
  FCancel.Enabled := not FBusy;
  FOpen.Visible := (FSession = nil) or (FSession.Bundled = nil);
  FOpen.Enabled := not FBusy;
  FRoot.Enabled := not FBusy;
  FTree.Enabled := not FBusy;
  case FPage of
    swpReady: FNext.Text := 'Install';
    swpFinished: FNext.Text := 'Finish';
    else FNext.Text := 'Next >';
  end;
  lInstalled := (FPage = swpReady) and (FSession <> nil) and
    (FRoot.Directory <> '') and FileExists(StateFile);
  FRepair.Visible := lInstalled;
  FRemove.Visible := lInstalled;
  FRepair.Enabled := not FBusy;
  FRemove.Enabled := not FBusy;
end;

function TNXSetupMainForm.StateFile: string;
begin
  Result := IncludeTrailingPathDelimiter(
    TNXSetupState.Folder(FRoot.Directory, FDocument.Product.Id)) + 'installation';
end;

procedure TNXSetupMainForm.RefreshSummary;
var
  lFeature: TNXSetupFeature;
begin
  FSummary.Text := 'Installation folder' + LineEnding + FRoot.Directory +
    LineEnding + LineEnding + 'Selected components' + LineEnding;
  for lFeature in FSelection.Selected do
    FSummary.Lines.Add('  ' + lFeature.Name);
end;

procedure TNXSetupMainForm.NextClicked(ASender: TObject);
begin
  if FBusy or (FSession = nil) then Exit;
  FStatus.Text := '';
  try
    case FPage of
      swpWelcome: ShowPage(swpDestination);
      swpDestination:
        begin
          FSession.Root := FRoot.Directory;
          FRoot.Directory := FSession.Root;
          ShowPage(swpComponents);
        end;
      swpComponents: ShowPage(swpReady);
      swpReady: ExecuteOperation(sopInstall);
      swpFinished: Close;
      else ;
    end;
  except
    on lError: Exception do FStatus.Text := lError.Message;
  end;
end;

procedure TNXSetupMainForm.BackClicked(ASender: TObject);
begin
  if not FBusy and (FPage in [swpDestination, swpComponents, swpReady]) then
  begin
    FStatus.Text := '';
    ShowPage(Pred(FPage));
  end;
end;

procedure TNXSetupMainForm.CancelClicked(ASender: TObject);
begin
  if not FBusy then Close;
end;

procedure TNXSetupMainForm.GetText(ASender: TfpgVirtualStringTree;
  ANode: PVirtualNode; AColumn: TColumnIndex; var AText: string);
var
  lData: PFeatureData;
begin
  lData := ASender.GetNodeData(ANode);
  AText := '';
  if lData^.Feature = nil then Exit;
  if AColumn = 0 then AText := lData^.Feature.Name
  else if FSelection <> nil then AText := FSelection.Explain(lData^.Feature);
end;

procedure TNXSetupMainForm.AddFeature(AFeature: TNXSetupFeature; AParent: PVirtualNode);
var
  lNode: PVirtualNode;
  lData: PFeatureData;
  lChild: TNXSetupFeature;
begin
  lNode := FTree.AddChild(AParent);
  lData := FTree.GetNodeData(lNode);
  lData^.Feature := AFeature;
  lNode^.CheckType := ctCheckBox;
  FNodes.Add(AFeature, lNode);
  for lChild in AFeature.Children do AddFeature(lChild, lNode);
end;

procedure TNXSetupMainForm.LoadFile(const AFileName: string);
var
  lSession: TNXSetupSession;
begin
  if Busy then raise ENXSetup.Create('Cannot reload during installation.');
  lSession := TNXSetupSession.OpenDefinition(AFileName);
  try
    SetSession(lSession);
  finally
    if FSession <> lSession then lSession.Free;
  end;
end;

procedure TNXSetupMainForm.LoadExecutable(const AFileName: string);
var
  lSession: TNXSetupSession;
begin
  if Busy then raise ENXSetup.Create('Cannot reload during installation.');
  lSession := TNXSetupSession.OpenExecutable(AFileName);
  try
    SetSession(lSession);
  finally
    if FSession <> lSession then lSession.Free;
  end;
end;

procedure TNXSetupMainForm.SetSession(ASession: TNXSetupSession);
var
  lFeature: TNXSetupFeature;
begin
  FUpdating := True;
  try
    FTree.Clear;
    FNodes.Clear;
    FSession.Free;
    FSession := ASession;
    FDocument := ASession.Document;
    FSelection := ASession.Selection;
    for lFeature in FDocument.Roots do AddFeature(lFeature, nil);
    FTree.FullExpand;
  finally
    FUpdating := False;
  end;
  WindowTitle := 'Setup - ' + FDocument.Product.Name;
  FProduct.Text := FDocument.Product.Name;
  FVersion.Text := 'Version ' + FDocument.Product.Version;
  FWelcome.Text := 'This wizard will install ' + FDocument.Product.Name +
    ' on your computer.' + LineEnding + LineEnding;
  if FDocument.Product.Description <> '' then
    FWelcome.Text := FWelcome.Text + FDocument.Product.Description
  else
    FWelcome.Text := FWelcome.Text +
      'You can choose the installation folder and the components you need.';
  FStatus.Text := '';
  RefreshSelection;
  ShowPage(swpWelcome);
end;

procedure TNXSetupMainForm.RefreshSelection;
var
  lFeature: TNXSetupFeature;
begin
  FUpdating := True;
  try
    for lFeature in FNodes.Keys do
      if FSelection.Selected.IndexOf(lFeature) >= 0 then
        FTree.CheckState[FNodes[lFeature]] := csCheckedNormal
      else FTree.CheckState[FNodes[lFeature]] := csUncheckedNormal;
    FTree.Invalidate;
    if FPage = swpReady then RefreshSummary;
  finally
    FUpdating := False;
  end;
end;

procedure TNXSetupMainForm.Checked(ASender: TfpgVirtualStringTree; ANode: PVirtualNode);
var
  lData: PFeatureData;
  lReason: string;
begin
  if FUpdating or Busy or (FSelection = nil) then Exit;
  lData := ASender.GetNodeData(ANode);
  if not FSelection.SetSelected(lData^.Feature,
    ANode^.CheckState = csCheckedNormal, lReason) then FStatus.Text := lReason
  else FStatus.Text := '';
  RefreshSelection;
end;

procedure TNXSetupMainForm.OpenClicked(ASender: TObject);
var
  lDialog: TNXFileDialog;
begin
  lDialog := TNXFileDialog.Create(nil);
  try
    lDialog.Filter := 'NexusScript (*.nxscript)|*.nxscript';
    if lDialog.RunOpenFile then
      try LoadFile(lDialog.FileName);
      except on lError: Exception do FStatus.Text := lError.Message; end;
  finally
    lDialog.Free;
  end;
end;

function TNXSetupMainForm.CloseQuery: Boolean;
begin
  Result := not Busy and inherited CloseQuery;
end;

procedure TNXSetupMainForm.ExecuteOperation(AOperation: TNXSetupOperation);
var
  lStateFile, lResult: string;
  lPreviousPage: TNXSetupWizardPage;
begin
  if Busy then raise ENXSetup.Create('A file operation is already running.');
  if FSession = nil then raise ENXSetup.Create('Load a definition first.');
  FSession.Root := FRoot.Directory;
  lStateFile := StateFile;
  lPreviousPage := FPage;
  FBusy := True;
  try
    ShowPage(swpInstalling);
    FStatus.Text := '';
    try
      case AOperation of
        sopInstall:
          begin
            lStateFile := FSession.Install;
            FStatus.Text := 'Installed. State: ' + lStateFile;
            lResult := FDocument.Product.Name + ' was installed successfully.';
          end;
        sopRepair:
          begin
            TNXSetupSession.Repair(lStateFile);
            FStatus.Text := 'Repair completed.';
            lResult := 'The installed files were repaired successfully.';
          end;
        sopUninstall:
          begin
            TNXSetupFileInstaller.Uninstall(lStateFile);
            FStatus.Text := 'Uninstall completed.';
            lResult := 'The installed files were removed successfully.';
          end;
      end;
      FResult.Text := lResult + LineEnding + LineEnding + FSession.Root;
      ShowPage(swpFinished);
      case AOperation of
        sopRepair: FTitle.Text := 'Repair complete';
        sopUninstall: FTitle.Text := 'Uninstall complete';
        else ;
      end;
    except
      ShowPage(lPreviousPage);
      raise;
    end;
  finally
    FBusy := False;
    UpdateButtons;
  end;
end;

procedure TNXSetupMainForm.OperationClicked(ASender: TObject);
begin
  FStatus.Text := '';
  try
    if ASender = FRepair then ExecuteOperation(sopRepair)
    else if (ASender = FRemove) and
      (TfpgMessageDialog.Question('Uninstall',
        'Remove the recorded installed files?', [mbYes, mbNo], mbNo) = mbYes) then
      ExecuteOperation(sopUninstall);
  except
    on lError: Exception do FStatus.Text := lError.Message;
  end;
end;

procedure RunNexusSetup;
var
  lForm: TNXSetupMainForm;
begin
  fpgApplication.Initialize;
  fpgStyleManager.SetStyle('Nexus');
  fpgStyle := fpgStyleManager.Style;
  fpgApplication.AppTitle := 'Nexus Setup';
  lForm := TNXSetupMainForm.Create(nil);
  try
    try
      if TNXSetupBundle.HasPayload(ParamStr(0)) then lForm.LoadExecutable(ParamStr(0))
      else if ParamCount > 0 then lForm.LoadFile(ParamStr(1))
      else if FileExists('projects/setup/examples/Files.nxscript') then
        lForm.LoadFile(ExpandFileName('projects/setup/examples/Files.nxscript'));
    except
      on lError: Exception do lForm.Status.Text := lError.Message;
    end;
    lForm.Show;
    fpgApplication.Run;
  finally
    lForm.Free;
  end;
end;

end.

