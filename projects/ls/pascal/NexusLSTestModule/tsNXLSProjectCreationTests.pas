// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXLSProjectCreationTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterNXLSProjectCreationTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, obNXTestSuite, obNXTestContext,
  obNXLSProjectProtocol, obNXLSProjectService, obNexusScriptModel,
  obNXBuildDescriptionLoader, obNXBuildDescription, obNXBuildPlanner,
  obNXBuildExecutor;

procedure TestNativeWizard(AContext: TNXTestContext);
var
  lResult: TNXLSProjectCreateWizardResult;
begin
  lResult := TNXLSProjectCreateWizardResult.Create;
  try
    TNXLSProjectService.FillCreateNexusProjectWizard(nil, lResult);
    AContext.AssertEquals(2, lResult.fields.Count);
    AContext.AssertEquals('projectName', TNXLSProjectField(lResult.fields[0]).id.Value);
    AContext.AssertEquals('targetDir', TNXLSProjectField(lResult.fields[1]).id.Value);
  finally
    lResult.Free;
  end;
end;

procedure TestGeneratedProjectBuilds(AContext: TNXTestContext);
var
  lParams: TNXLSProjectCreateParams;
  lResult: TNXLSProjectCreateResult;
  lFile: TNXLSProjectFile;
  lText: TStringList;
  lTargets: TNexusScriptTargetSelection;
  lLoader: TNXBuildDescriptionLoader;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lExecutor: TNXBuildExecutor;
  lDirectory, lProjectFile: string;
  lId: TGUID;
  lIndex: Integer;
begin
  CreateGUID(lId);
  lDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nxls-project-' + GUIDToString(lId);
  ForceDirectories(lDirectory);
  lParams := TNXLSProjectCreateParams.Create;
  lResult := TNXLSProjectCreateResult.Create;
  lText := TStringList.Create;
  lTargets := TNexusScriptTargetSelection.Create;
  lLoader := TNXBuildDescriptionLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  lExecutor := TNXBuildExecutor.Create;
  lDescription := nil;
  lPlan := nil;
  try
    lParams.projectName.Value := 'sample-project';
    lParams.targetDir.Value := lDirectory;
    TNXLSProjectService.FillCreateNexusProject(lParams, lResult);
    AContext.AssertEquals(2, lResult.files.Count);
    for lIndex := 0 to lResult.files.Count - 1 do
    begin
      lFile := TNXLSProjectFile(lResult.files[lIndex]);
      ForceDirectories(ExtractFileDir(lFile.path.Value));
      lText.Text := lFile.content.Value;
      lText.SaveToFile(lFile.path.Value);
    end;
    lProjectFile := TNXLSProjectFile(lResult.files[0]).path.Value;
    lTargets.Add('TargetOS', LowerCase({$I %FPCTARGETOS%}));
    lTargets.Add('TargetCPU', LowerCase({$I %FPCTARGETCPU%}));
    lTargets.Add('BuildConfiguration', 'Debug');
    lDescription := lLoader.LoadDescription(lProjectFile, lTargets);
    lPlan := lPlanner.CreatePlan(lDescription);
    AContext.AssertEquals(1, lPlan.Steps.Count);
    AContext.AssertEquals('NXPC', lPlan.Steps[0].BuildType,
      'Native Nexus projects must explicitly select NXPC');
    AContext.AssertTrue(Pos(IncludeTrailingPathDelimiter(lDirectory),
      IncludeTrailingPathDelimiter(lDescription.OutputRoot)) <> 1,
      'Generated build output must remain outside the new project source.');
    AContext.AssertEquals(0, lExecutor.Execute(lPlan),
      'The project returned by the real service must build unchanged.');
  finally
    lPlan.Free;
    lDescription.Free;
    lExecutor.Free;
    lPlanner.Free;
    lLoader.Free;
    lTargets.Free;
    lText.Free;
    lResult.Free;
    lParams.Free;
  end;
end;

procedure TestInvalidName(AContext: TNXTestContext);
var
  lParams: TNXLSProjectCreateParams;
  lResult: TNXLSProjectPlanCreateResult;
begin
  lParams := TNXLSProjectCreateParams.Create;
  lResult := TNXLSProjectPlanCreateResult.Create;
  try
    lParams.projectName.Value := 'bad/name';
    lParams.targetDir.Value := GetTempDir(False);
    TNXLSProjectService.FillPlanNexusProjectCreate(lParams, lResult);
    AContext.AssertFalse(lResult.canExecute.Value);
    AContext.AssertEquals(1, lResult.messages.Count);
  finally
    lResult.Free;
    lParams.Free;
  end;
end;

procedure RegisterNXLSProjectCreationTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('LSProjectCreation');
  lSuite.AddTest('NativeWizard', @TestNativeWizard);
  lSuite.AddTest('GeneratedProjectBuilds', @TestGeneratedProjectBuilds);
  lSuite.AddTest('InvalidName', @TestInvalidName);
end;
end.
