unit obNXLSProjectService;

{$mode objfpc}{$H+}

interface

uses
  fpjson,
  obNXJSONValues;

type
  TNXLSProjectService = class
  public
    class function CreateNexusProjectWizard(const AWorkspaceRoot: string): TNXJSONValue;
    class function PlanNexusProjectCreate(ARequest: TJSONData): TNXJSONValue;
    class function CreateNexusProject(ARequest: TJSONData): TNXJSONValue;
  end;

implementation

uses
  SysUtils;

function NXLSWrapJSON(AData: TJSONData): TNXJSONValue;
begin
  Result := TNXJSONValue.Create;
  try
    Result.FromJSONData(AData);
  finally
    AData.Free;
  end;
end;

function NXLSObjectString(AObject: TJSONObject; const AName, ADefault: string): string;
var
  lValue: TJSONData;
begin
  Result := ADefault;
  if AObject = nil then
    Exit;

  lValue := AObject.Find(AName);
  if (lValue <> nil) and (lValue.JSONType = jtString) then
    Result := lValue.AsString;
end;

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

procedure NXLSAddField(AFields: TJSONArray; const AId, ALabel, AType,
  AValue: string; ARequired: Boolean; const ADescription: string = '';
  const ABrowseLabel: string = '');
var
  lField: TJSONObject;
begin
  lField := TJSONObject.Create;
  lField.Add('id', AId);
  lField.Add('label', ALabel);
  lField.Add('type', AType);
  lField.Add('value', AValue);
  lField.Add('required', ARequired);
  if ADescription <> '' then
    lField.Add('description', ADescription);
  if ABrowseLabel <> '' then
    lField.Add('browseLabel', ABrowseLabel);
  AFields.Add(lField);
end;

function NXLSNexusProjectFields(const AProjectName, ATargetDir: string): TJSONArray;
begin
  Result := TJSONArray.Create;
  NXLSAddField(Result, 'projectName', 'Project Name', 'text', AProjectName,
    True, 'Used for the .nxp file name in this first project-service pass.');
  NXLSAddField(Result, 'targetDir', 'Destination Folder', 'folder',
    ATargetDir, True, '', 'Select Project Folder');
end;

procedure NXLSAddMessage(AMessages: TJSONArray; const ASeverity, AText: string);
var
  lMessage: TJSONObject;
begin
  lMessage := TJSONObject.Create;
  lMessage.Add('severity', ASeverity);
  lMessage.Add('text', AText);
  AMessages.Add(lMessage);
end;

procedure NXLSAddDetail(ADetails: TJSONArray; const ALabel, AValue: string);
var
  lDetail: TJSONObject;
begin
  lDetail := TJSONObject.Create;
  lDetail.Add('label', ALabel);
  lDetail.Add('value', AValue);
  ADetails.Add(lDetail);
end;

procedure NXLSAddOutput(AOutputs: TJSONArray; const ALabel, APath: string);
var
  lOutput: TJSONObject;
begin
  lOutput := TJSONObject.Create;
  lOutput.Add('label', ALabel);
  lOutput.Add('path', APath);
  AOutputs.Add(lOutput);
end;

function NXLSMinimalNexusProjectJSON(const AProjectName, ATargetDir: string): string;
var
  lProject: TJSONObject;
begin
  lProject := TJSONObject.Create;
  try
    lProject.Add('class', 'TNXPascalProject');
    lProject.Add('name', AProjectName);
    lProject.Add('projectRoot', ExpandFileName(ATargetDir));
    Result := lProject.AsJSON + LineEnding;
  finally
    lProject.Free;
  end;
end;

procedure NXLSReadNexusProjectRequest(ARequest: TJSONData; out AProjectName,
  ATargetDir: string);
var
  lRequest: TJSONObject;
begin
  lRequest := nil;
  if (ARequest <> nil) and (ARequest.JSONType = jtObject) then
    lRequest := TJSONObject(ARequest);

  AProjectName := NXLSCleanProjectName(NXLSObjectString(lRequest,
    'projectName', 'newproject'));
  ATargetDir := Trim(NXLSObjectString(lRequest, 'targetDir', GetCurrentDir));
  if ATargetDir = '' then
    ATargetDir := GetCurrentDir;
end;

class function TNXLSProjectService.CreateNexusProjectWizard(
  const AWorkspaceRoot: string): TNXJSONValue;
var
  lRoot: TJSONObject;
  lRequest: TJSONObject;
begin
  lRequest := TJSONObject.Create;
  lRequest.Add('projectName', 'newproject');
  lRequest.Add('targetDir', ExpandFileName(AWorkspaceRoot));

  lRoot := TJSONObject.Create;
  lRoot.Add('title', 'New Nexus Project');
  lRoot.Add('request', lRequest);
  lRoot.Add('fields', NXLSNexusProjectFields('newproject',
    ExpandFileName(AWorkspaceRoot)));
  Result := NXLSWrapJSON(lRoot);
end;

class function TNXLSProjectService.PlanNexusProjectCreate(
  ARequest: TJSONData): TNXJSONValue;
var
  lProjectName: string;
  lTargetDir: string;
  lProjectFile: string;
  lRoot: TJSONObject;
  lMessages: TJSONArray;
  lOutputs: TJSONArray;
  lDetails: TJSONArray;
  lCanExecute: Boolean;
begin
  NXLSReadNexusProjectRequest(ARequest, lProjectName, lTargetDir);
  lProjectFile := NXLSProjectFileName(lProjectName, lTargetDir);

  lMessages := TJSONArray.Create;
  lOutputs := TJSONArray.Create;
  lDetails := TJSONArray.Create;
  lCanExecute := True;

  if not NXLSIsValidProjectName(lProjectName) then
  begin
    NXLSAddMessage(lMessages, 'error',
      'Project name is required and may only contain letters, digits, underscore, or dash.');
    lCanExecute := False;
  end;

  if Trim(lTargetDir) = '' then
  begin
    NXLSAddMessage(lMessages, 'error', 'Destination folder is required.');
    lCanExecute := False;
  end;

  NXLSAddOutput(lOutputs, 'Nexus project', lProjectFile);
  NXLSAddDetail(lDetails, 'Project type', 'Nexus Project');
  NXLSAddDetail(lDetails, 'Project name', lProjectName);
  NXLSAddDetail(lDetails, 'Destination', ExpandFileName(lTargetDir));

  lRoot := TJSONObject.Create;
  lRoot.Add('title', 'New Nexus Project');
  lRoot.Add('summary', 'Create Nexus project "' + lProjectName + '" in ' +
    ExpandFileName(lTargetDir));
  lRoot.Add('canExecute', lCanExecute);
  lRoot.Add('messages', lMessages);
  lRoot.Add('outputs', lOutputs);
  lRoot.Add('details', lDetails);
  lRoot.Add('fields', NXLSNexusProjectFields(lProjectName, ExpandFileName(lTargetDir)));
  Result := NXLSWrapJSON(lRoot);
end;

class function TNXLSProjectService.CreateNexusProject(
  ARequest: TJSONData): TNXJSONValue;
var
  lProjectName: string;
  lTargetDir: string;
  lProjectFile: string;
  lRoot: TJSONObject;
  lFiles: TJSONArray;
  lFile: TJSONObject;
begin
  NXLSReadNexusProjectRequest(ARequest, lProjectName, lTargetDir);
  if not NXLSIsValidProjectName(lProjectName) then
    raise Exception.Create('Project name is invalid.');

  lProjectFile := NXLSProjectFileName(lProjectName, lTargetDir);

  lFile := TJSONObject.Create;
  lFile.Add('path', lProjectFile);
  lFile.Add('content', NXLSMinimalNexusProjectJSON(lProjectName, lTargetDir));

  lFiles := TJSONArray.Create;
  lFiles.Add(lFile);

  lRoot := TJSONObject.Create;
  lRoot.Add('message', 'Nexus project created: ' + lProjectName);
  lRoot.Add('files', lFiles);
  Result := NXLSWrapJSON(lRoot);
end;

end.
