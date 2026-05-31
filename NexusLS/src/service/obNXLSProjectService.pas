unit obNXLSProjectService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolObjects,
  obNXLSProtocolParams;

type
  TNXLSProjectService = class
  public
    class procedure FillCreateNexusProjectWizard(
      AParams: TNXLSProjectCreateWizardParams;
      AResult: TNXLSProjectCreateWizardResult);
    class procedure FillPlanNexusProjectCreate(AParams: TNXLSProjectCreateParams;
      AResult: TNXLSProjectPlanCreateResult);
    class procedure FillCreateNexusProject(AParams: TNXLSProjectCreateParams;
      AResult: TNXLSProjectCreateResult);
  end;

implementation

uses
  obNXPascalProject,
  SysUtils;

function NXLSCleanProjectName(const AName: string): string;
begin
  Result := Trim(AName);
end;

function NXLSIsValidProjectName(const AName: string): Boolean;
var
  lIdx: Integer;
begin
  Result := AName <> '';
  if not Result then
    Exit;

  for lIdx := 1 to Length(AName) do
    if not (AName[lIdx] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-']) then
      Exit(False);
end;

function NXLSProjectFileName(const AProjectName, ATargetDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ATargetDir)) +
    AProjectName + '.nxp';
end;

procedure NXLSAddField(AFields: TNXLSProjectFieldArray; const AId, ALabel, AType,
  AValue: string; ARequired: Boolean; const ADescription: string = '';
  const ABrowseLabel: string = '');
var
  lField: TNXLSProjectField;
begin
  lField := TNXLSProjectField(AFields.AddObject(TNXLSProjectField));
  lField.id.Value := AId;
  lField.&label.Value := ALabel;
  lField.&type.Value := AType;
  lField.value.Value := AValue;
  lField.required.Value := ARequired;
  if ADescription <> '' then
    lField.description.Value := ADescription;
  if ABrowseLabel <> '' then
    lField.browseLabel.Value := ABrowseLabel;
  lField.Assigned := True;
end;

procedure NXLSFillNexusProjectFields(AFields: TNXLSProjectFieldArray;
  const AProjectName, ATargetDir: string);
begin
  if AFields = nil then
    Exit;
  NXLSAddField(AFields, 'projectName', 'Project Name', 'text', AProjectName,
    True, 'Used for the .nxp file name in this first project-service pass.');
  NXLSAddField(AFields, 'targetDir', 'Destination Folder', 'folder',
    ATargetDir, True, '', 'Select Project Folder');
  AFields.Assigned := True;
end;

procedure NXLSAddMessage(AMessages: TNXLSProjectMessageArray;
  const ASeverity, AText: string);
var
  lMessage: TNXLSProjectMessage;
begin
  lMessage := TNXLSProjectMessage(AMessages.AddObject(TNXLSProjectMessage));
  lMessage.severity.Value := ASeverity;
  lMessage.text.Value := AText;
  lMessage.Assigned := True;
end;

procedure NXLSAddDetail(ADetails: TNXLSProjectDetailArray;
  const ALabel, AValue: string);
var
  lDetail: TNXLSProjectDetail;
begin
  lDetail := TNXLSProjectDetail(ADetails.AddObject(TNXLSProjectDetail));
  lDetail.&label.Value := ALabel;
  lDetail.value.Value := AValue;
  lDetail.Assigned := True;
end;

procedure NXLSAddOutput(AOutputs: TNXLSProjectOutputArray;
  const ALabel, APath: string);
var
  lOutput: TNXLSProjectOutput;
begin
  lOutput := TNXLSProjectOutput(AOutputs.AddObject(TNXLSProjectOutput));
  lOutput.&label.Value := ALabel;
  lOutput.path.Value := APath;
  lOutput.Assigned := True;
end;

function NXLSNexusProjectJSON(const AProjectName, ATargetDir: string): string;
var
  lProject: TNXPascalProject;
begin
  lProject := TNXPascalProject.Create;
  try
    lProject.Name := AProjectName;
    lProject.ProjectRoot := ExpandFileName(ATargetDir);
    lProject.ProjectFileName := NXLSProjectFileName(AProjectName, ATargetDir);
    Result := lProject.JSON;
  finally
    lProject.Free;
  end;
end;

procedure NXLSReadNexusProjectParams(AParams: TNXLSProjectCreateParams;
  out AProjectName, ATargetDir: string);
begin
  AProjectName := 'newproject';
  ATargetDir := GetCurrentDir;
  if AParams <> nil then
  begin
    AProjectName := NXLSCleanProjectName(AParams.projectName.Value);
    ATargetDir := Trim(AParams.targetDir.Value);
  end;
  if AProjectName = '' then
    AProjectName := 'newproject';
  if ATargetDir = '' then
    ATargetDir := GetCurrentDir;
end;

class procedure TNXLSProjectService.FillCreateNexusProjectWizard(
  AParams: TNXLSProjectCreateWizardParams;
  AResult: TNXLSProjectCreateWizardResult);
var
  lWorkspaceRoot: string;
begin
  if AResult = nil then
    Exit;

  lWorkspaceRoot := GetCurrentDir;
  if (AParams <> nil) and (AParams.workspaceRoot.Value <> '') then
    lWorkspaceRoot := AParams.workspaceRoot.Value;

  AResult.title.Value := 'New Nexus Project';
  AResult.request.projectName.Value := 'newproject';
  AResult.request.targetDir.Value := ExpandFileName(lWorkspaceRoot);
  AResult.request.Assigned := True;
  NXLSFillNexusProjectFields(AResult.fields, 'newproject',
    ExpandFileName(lWorkspaceRoot));
  AResult.Assigned := True;
end;

class procedure TNXLSProjectService.FillPlanNexusProjectCreate(
  AParams: TNXLSProjectCreateParams; AResult: TNXLSProjectPlanCreateResult);
var
  lProjectName: string;
  lTargetDir: string;
  lProjectFile: string;
  lCanExecute: Boolean;
begin
  if AResult = nil then
    Exit;

  NXLSReadNexusProjectParams(AParams, lProjectName, lTargetDir);
  lProjectFile := NXLSProjectFileName(lProjectName, lTargetDir);

  lCanExecute := True;

  if not NXLSIsValidProjectName(lProjectName) then
  begin
    NXLSAddMessage(AResult.messages, 'error',
      'Project name is required and may only contain letters, digits, underscore, or dash.');
    lCanExecute := False;
  end;

  if Trim(lTargetDir) = '' then
  begin
    NXLSAddMessage(AResult.messages, 'error', 'Destination folder is required.');
    lCanExecute := False;
  end;

  NXLSAddOutput(AResult.outputs, 'Nexus project', lProjectFile);
  NXLSAddDetail(AResult.details, 'Project type', 'Nexus Project');
  NXLSAddDetail(AResult.details, 'Project name', lProjectName);
  NXLSAddDetail(AResult.details, 'Destination', ExpandFileName(lTargetDir));

  AResult.title.Value := 'New Nexus Project';
  AResult.summary.Value := 'Create Nexus project "' + lProjectName + '" in ' +
    ExpandFileName(lTargetDir);
  AResult.canExecute.Value := lCanExecute;
  AResult.messages.Assigned := True;
  AResult.outputs.Assigned := True;
  AResult.details.Assigned := True;
  NXLSFillNexusProjectFields(AResult.fields, lProjectName, ExpandFileName(lTargetDir));
  AResult.Assigned := True;
end;

class procedure TNXLSProjectService.FillCreateNexusProject(
  AParams: TNXLSProjectCreateParams; AResult: TNXLSProjectCreateResult);
var
  lProjectName: string;
  lTargetDir: string;
  lProjectFile: string;
  lFile: TNXLSProjectFile;
begin
  if AResult = nil then
    Exit;

  NXLSReadNexusProjectParams(AParams, lProjectName, lTargetDir);
  if not NXLSIsValidProjectName(lProjectName) then
    raise Exception.Create('Project name is invalid.');

  lProjectFile := NXLSProjectFileName(lProjectName, lTargetDir);

  lFile := TNXLSProjectFile(AResult.files.AddObject(TNXLSProjectFile));
  lFile.path.Value := lProjectFile;
  lFile.content.Value := NXLSNexusProjectJSON(lProjectName, lTargetDir);
  lFile.Assigned := True;

  AResult.message.Value := 'Nexus project created: ' + lProjectName;
  AResult.files.Assigned := True;
  AResult.Assigned := True;
end;

end.
