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
  obNXFPCBuildOptions,
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

function NXLSProjectSourceDir(const ATargetDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ATargetDir)) + 'src';
end;

function NXLSProjectProgramFileName(const AProjectName, ATargetDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(NXLSProjectSourceDir(ATargetDir)) +
    AProjectName + '.lpr';
end;

function NXLSProjectLPIFileName(const AProjectName, ATargetDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ATargetDir)) +
    AProjectName + '.lpi';
end;

function NXLSImportedProjectName(const ALPIFile: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(ALPIFile), '');
  if Result = '' then
    Result := 'importedproject';
end;

function NXLSPascalIdentifier(const AProjectName: string): string;
var
  lIdx: Integer;
  lChar: Char;
begin
  Result := '';
  for lIdx := 1 to Length(AProjectName) do
  begin
    lChar := AProjectName[lIdx];
    if lChar in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then
      Result := Result + lChar
    else
      Result := Result + '_';
  end;

  if (Result = '') or not (Result[1] in ['A'..'Z', 'a'..'z', '_']) then
    Result := 'NexusProject';
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

procedure NXLSAddFieldOption(AField: TNXLSProjectField; const AValue,
  ALabel: string);
var
  lOption: TNXLSProjectFieldOption;
begin
  if AField = nil then
    Exit;

  lOption := TNXLSProjectFieldOption(
    AField.options.AddObject(TNXLSProjectFieldOption));
  lOption.value.Value := AValue;
  lOption.&label.Value := ALabel;
  lOption.Assigned := True;
  AField.options.Assigned := True;
end;

function NXLSBuildToolName(ABuildTool: TNXPascalBuildTool): string;
begin
  case ABuildTool of
    pbtLazarus:
      Result := 'lazarus';
    else
      Result := 'fpc';
  end;
end;

function NXLSBuildToolLabel(ABuildTool: TNXPascalBuildTool): string;
begin
  case ABuildTool of
    pbtLazarus:
      Result := 'Lazarus';
    else
      Result := 'FPC';
  end;
end;

function NXLSBuildToolFromName(const ABuildTool: string): TNXPascalBuildTool;
begin
  if SameText(ABuildTool, 'lazarus') then
    Result := pbtLazarus
  else
    Result := pbtFPC;
end;

procedure NXLSAddBuildToolField(AFields: TNXLSProjectFieldArray;
  ABuildTool: TNXPascalBuildTool);
var
  lField: TNXLSProjectField;
begin
  if AFields = nil then
    Exit;

  lField := TNXLSProjectField(AFields.AddObject(TNXLSProjectField));
  lField.id.Value := 'buildTool';
  lField.&label.Value := 'Build Tool';
  lField.&type.Value := 'select';
  lField.value.Value := NXLSBuildToolName(ABuildTool);
  lField.required.Value := True;
  lField.description.Value := 'Select the build tool NexusBuild will invoke.';
  NXLSAddFieldOption(lField, 'fpc', 'FPC');
  NXLSAddFieldOption(lField, 'lazarus', 'Lazarus');
  lField.Assigned := True;
end;

procedure NXLSFillNexusProjectFields(AFields: TNXLSProjectFieldArray;
  const AProjectName, ATargetDir: string; ABuildTool: TNXPascalBuildTool);
begin
  if AFields = nil then
    Exit;
  NXLSAddField(AFields, 'projectName', 'Project Name', 'text', AProjectName,
    True, 'Used for the .nxp file name in this first project-service pass.');
  NXLSAddBuildToolField(AFields, ABuildTool);
  NXLSAddField(AFields, 'targetDir', 'Destination Folder', 'folder',
    ATargetDir, True, '', 'Select Project Folder');
  AFields.Assigned := True;
end;

procedure NXLSFillLazarusImportFields(AFields: TNXLSProjectFieldArray;
  const AProjectName, ATargetDir, ALPIFile: string);
begin
  if AFields = nil then
    Exit;
  NXLSAddField(AFields, 'kind', 'Project Type', 'readonly', 'lazarus',
    True, 'Import an existing Lazarus project into a Nexus project file.');
  NXLSAddField(AFields, 'projectName', 'Project Name', 'text', AProjectName,
    True, 'Used for the generated .nxp file name.');
  NXLSAddField(AFields, 'targetDir', 'Destination Folder', 'folder',
    ATargetDir, True, '', 'Select Project Folder');
  NXLSAddField(AFields, 'lpiFile', 'Lazarus Project File', 'file',
    ALPIFile, True, 'The .lpi file this Nexus project builds with lazbuild.',
    'Select Lazarus Project');
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

function NXLSNexusProjectJSON(const AProjectName, ATargetDir: string;
  ABuildTool: TNXPascalBuildTool): string;
var
  lProject: TNXPascalProject;
begin
  lProject := TNXPascalProject.Create;
  try
    lProject.Name := AProjectName;
    lProject.BuildTool := ABuildTool;
    lProject.ProjectRoot := ExpandFileName(ATargetDir);
    lProject.ProjectFileName := NXLSProjectFileName(AProjectName, ATargetDir);
    lProject.SourceRoot := 'src';
    lProject.OutputRoot := 'output';
    if ABuildTool = pbtLazarus then
    begin
      lProject.ProjectKind := ppkLazarusProject;
      lProject.BuildFile := AProjectName + '.lpi';
    end
    else
    begin
      lProject.ProjectKind := ppkProgram;
      lProject.BuildFile := '$(SourceRoot)' + DirectorySeparator +
        AProjectName + '.lpr';
    end;
    lProject.TargetPlatform.FPCMode := 'objfpc';
    lProject.FPCBuildOptions.InputFile := lProject.BuildFile;
    lProject.FPCBuildOptions.Files.UnitPaths.Add('$(SourceRoot)');
    lProject.FPCBuildOptions.Files.UnitOutputPath := '$(OutputRoot)' +
      DirectorySeparator + 'units';
    lProject.FPCBuildOptions.Files.ExecutableOutputPath := '$(OutputRoot)';
    lProject.FPCBuildOptions.Language.Mode := flmObjFPC;
    Result := lProject.JSON;
  finally
    lProject.Free;
  end;
end;

function NXLSLazarusProjectJSON(const AProjectName, ATargetDir,
  ALPIFile: string): string;
var
  lProject: TNXPascalProject;
begin
  lProject := TNXPascalProject.Create;
  try
    lProject.Name := AProjectName;
    lProject.BuildTool := pbtLazarus;
    lProject.BuildFile := ExpandFileName(ALPIFile);
    lProject.ProjectRoot := ExpandFileName(ATargetDir);
    lProject.ProjectFileName := NXLSProjectFileName(AProjectName, ATargetDir);
    lProject.ProjectKind := ppkLazarusProject;
    lProject.OutputRoot := 'output';
    Result := lProject.JSON;
  finally
    lProject.Free;
  end;
end;

function NXLSNexusProgramSource(const AProjectName: string): string;
var
  lProgramName: string;
begin
  lProgramName := NXLSPascalIdentifier(AProjectName);
  Result :=
    'program ' + lProgramName + ';' + LineEnding +
    LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    LineEnding +
    'begin' + LineEnding +
    '  WriteLn(''Hello from ' + AProjectName + '.'');' + LineEnding +
    'end.' + LineEnding;
end;

function NXLSNexusLazarusProjectSource(const AProjectName: string): string;
begin
  Result :=
    '<?xml version="1.0" encoding="UTF-8"?>' + LineEnding +
    '<CONFIG>' + LineEnding +
    '  <ProjectOptions>' + LineEnding +
    '    <Version Value="12"/>' + LineEnding +
    '    <General>' + LineEnding +
    '      <MainUnit Value="0"/>' + LineEnding +
    '      <Title Value="' + AProjectName + '"/>' + LineEnding +
    '    </General>' + LineEnding +
    '    <Units Count="1">' + LineEnding +
    '      <Unit0>' + LineEnding +
    '        <Filename Value="src/' + AProjectName + '.lpr"/>' + LineEnding +
    '        <IsPartOfProject Value="True"/>' + LineEnding +
    '      </Unit0>' + LineEnding +
    '    </Units>' + LineEnding +
    '  </ProjectOptions>' + LineEnding +
    '</CONFIG>' + LineEnding;
end;

procedure NXLSReadNexusProjectParams(AParams: TNXLSProjectCreateParams;
  out AProjectName, ATargetDir, AKind, ALPIFile: string;
  out ABuildTool: TNXPascalBuildTool);
begin
  AProjectName := 'newproject';
  ATargetDir := GetCurrentDir;
  AKind := 'nexus';
  ALPIFile := '';
  ABuildTool := pbtFPC;
  if AParams <> nil then
  begin
    AProjectName := NXLSCleanProjectName(AParams.projectName.Value);
    ATargetDir := Trim(AParams.targetDir.Value);
    AKind := LowerCase(Trim(AParams.kind.Value));
    ALPIFile := Trim(AParams.lpiFile.Value);
    ABuildTool := NXLSBuildToolFromName(AParams.buildTool.Value);
  end;
  if AKind = '' then
    AKind := 'nexus';
  if (AProjectName = '') and (AKind = 'lazarus') then
    AProjectName := NXLSCleanProjectName(NXLSImportedProjectName(ALPIFile));
  if AProjectName = '' then
    AProjectName := 'newproject';
  if (ATargetDir = '') and (ALPIFile <> '') then
    ATargetDir := ExtractFileDir(ExpandFileName(ALPIFile));
  if ATargetDir = '' then
    ATargetDir := GetCurrentDir;
end;

class procedure TNXLSProjectService.FillCreateNexusProjectWizard(
  AParams: TNXLSProjectCreateWizardParams;
  AResult: TNXLSProjectCreateWizardResult);
var
  lWorkspaceRoot: string;
  lKind: string;
  lLPIFile: string;
  lProjectName: string;
  lTargetDir: string;
  lBuildTool: TNXPascalBuildTool;
begin
  if AResult = nil then
    Exit;

  lWorkspaceRoot := GetCurrentDir;
  if (AParams <> nil) and (AParams.workspaceRoot.Value <> '') then
    lWorkspaceRoot := AParams.workspaceRoot.Value;

  lKind := 'nexus';
  lLPIFile := '';
  lBuildTool := pbtFPC;
  if AParams <> nil then
  begin
    lKind := LowerCase(Trim(AParams.kind.Value));
    lLPIFile := Trim(AParams.lpiFile.Value);
    lBuildTool := NXLSBuildToolFromName(AParams.buildTool.Value);
  end;
  if lKind = '' then
    lKind := 'nexus';

  if lKind = 'lazarus' then
  begin
    lProjectName := NXLSImportedProjectName(lLPIFile);
    if lLPIFile <> '' then
      lTargetDir := ExtractFileDir(ExpandFileName(lLPIFile))
    else
      lTargetDir := ExpandFileName(lWorkspaceRoot);

    AResult.title.Value := 'Import Lazarus Project';
    AResult.request.kind.Value := 'lazarus';
    AResult.request.buildTool.Value := NXLSBuildToolName(pbtLazarus);
    AResult.request.projectName.Value := lProjectName;
    AResult.request.targetDir.Value := lTargetDir;
    AResult.request.lpiFile.Value := ExpandFileName(lLPIFile);
    NXLSFillLazarusImportFields(AResult.fields, lProjectName, lTargetDir,
      ExpandFileName(lLPIFile));
  end
  else
  begin
    AResult.title.Value := 'New Nexus Project';
    AResult.request.kind.Value := 'nexus';
    AResult.request.buildTool.Value := NXLSBuildToolName(lBuildTool);
    AResult.request.projectName.Value := 'newproject';
    AResult.request.targetDir.Value := ExpandFileName(lWorkspaceRoot);
    NXLSFillNexusProjectFields(AResult.fields, 'newproject',
      ExpandFileName(lWorkspaceRoot), lBuildTool);
  end;

  AResult.request.Assigned := True;
  AResult.Assigned := True;
end;

class procedure TNXLSProjectService.FillPlanNexusProjectCreate(
  AParams: TNXLSProjectCreateParams; AResult: TNXLSProjectPlanCreateResult);
var
  lProjectName: string;
  lTargetDir: string;
  lKind: string;
  lLPIFile: string;
  lBuildTool: TNXPascalBuildTool;
  lProjectFile: string;
  lCanExecute: Boolean;
begin
  if AResult = nil then
    Exit;

  NXLSReadNexusProjectParams(AParams, lProjectName, lTargetDir, lKind,
    lLPIFile, lBuildTool);
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

  if lKind = 'lazarus' then
  begin
    if (lLPIFile = '') or (not FileExists(lLPIFile)) or
      (not SameText(ExtractFileExt(lLPIFile), '.lpi')) then
    begin
      NXLSAddMessage(AResult.messages, 'error',
        'A Lazarus .lpi project file is required.');
      lCanExecute := False;
    end;
  end;

  NXLSAddOutput(AResult.outputs, 'Nexus project', lProjectFile);
  if lKind = 'lazarus' then
  begin
    NXLSAddDetail(AResult.details, 'Project type', 'Lazarus Project');
    NXLSAddDetail(AResult.details, 'Lazarus project', ExpandFileName(lLPIFile));
  end
  else
  begin
    NXLSAddOutput(AResult.outputs, 'Program source',
      NXLSProjectProgramFileName(lProjectName, lTargetDir));
    if lBuildTool = pbtLazarus then
      NXLSAddOutput(AResult.outputs, 'Lazarus project',
        NXLSProjectLPIFileName(lProjectName, lTargetDir));
    NXLSAddDetail(AResult.details, 'Project type', 'Nexus Project');
    NXLSAddDetail(AResult.details, 'Build tool', NXLSBuildToolLabel(lBuildTool));
  end;
  NXLSAddDetail(AResult.details, 'Project name', lProjectName);
  NXLSAddDetail(AResult.details, 'Destination', ExpandFileName(lTargetDir));

  if lKind = 'lazarus' then
  begin
    AResult.title.Value := 'Import Lazarus Project';
    AResult.summary.Value := 'Create Nexus project "' + lProjectName +
      '" tracking ' + ExpandFileName(lLPIFile);
  end
  else
  begin
    AResult.title.Value := 'New Nexus Project';
    AResult.summary.Value := 'Create Nexus project "' + lProjectName +
      '" using ' + NXLSBuildToolLabel(lBuildTool) + ' in ' +
      ExpandFileName(lTargetDir);
  end;
  AResult.canExecute.Value := lCanExecute;
  AResult.messages.Assigned := True;
  AResult.outputs.Assigned := True;
  AResult.details.Assigned := True;
  if lKind = 'lazarus' then
    NXLSFillLazarusImportFields(AResult.fields, lProjectName,
      ExpandFileName(lTargetDir), ExpandFileName(lLPIFile))
  else
    NXLSFillNexusProjectFields(AResult.fields, lProjectName,
      ExpandFileName(lTargetDir), lBuildTool);
  AResult.Assigned := True;
end;

class procedure TNXLSProjectService.FillCreateNexusProject(
  AParams: TNXLSProjectCreateParams; AResult: TNXLSProjectCreateResult);
var
  lProjectName: string;
  lTargetDir: string;
  lKind: string;
  lLPIFile: string;
  lBuildTool: TNXPascalBuildTool;
  lProjectFile: string;
  lFile: TNXLSProjectFile;
begin
  if AResult = nil then
    Exit;

  NXLSReadNexusProjectParams(AParams, lProjectName, lTargetDir, lKind,
    lLPIFile, lBuildTool);
  if not NXLSIsValidProjectName(lProjectName) then
    raise Exception.Create('Project name is invalid.');
  if (lKind = 'lazarus') and ((lLPIFile = '') or
    (not FileExists(lLPIFile)) or (not SameText(ExtractFileExt(lLPIFile), '.lpi'))) then
    raise Exception.Create('Lazarus .lpi project file is required.');

  lProjectFile := NXLSProjectFileName(lProjectName, lTargetDir);

  lFile := TNXLSProjectFile(AResult.files.AddObject(TNXLSProjectFile));
  lFile.path.Value := lProjectFile;
  if lKind = 'lazarus' then
    lFile.content.Value := NXLSLazarusProjectJSON(lProjectName, lTargetDir,
      lLPIFile)
  else
    lFile.content.Value := NXLSNexusProjectJSON(lProjectName, lTargetDir,
      lBuildTool);
  lFile.Assigned := True;

  if lKind <> 'lazarus' then
  begin
    if lBuildTool = pbtLazarus then
    begin
      lFile := TNXLSProjectFile(AResult.files.AddObject(TNXLSProjectFile));
      lFile.path.Value := NXLSProjectLPIFileName(lProjectName, lTargetDir);
      lFile.content.Value := NXLSNexusLazarusProjectSource(lProjectName);
      lFile.Assigned := True;
    end;

    lFile := TNXLSProjectFile(AResult.files.AddObject(TNXLSProjectFile));
    lFile.path.Value := NXLSProjectProgramFileName(lProjectName, lTargetDir);
    lFile.content.Value := NXLSNexusProgramSource(lProjectName);
    lFile.Assigned := True;
  end;

  if lKind = 'lazarus' then
    AResult.message.Value := 'Lazarus project imported: ' + lProjectName
  else
    AResult.message.Value := 'Nexus project created: ' + lProjectName;
  AResult.files.Assigned := True;
  AResult.Assigned := True;
end;

end.
