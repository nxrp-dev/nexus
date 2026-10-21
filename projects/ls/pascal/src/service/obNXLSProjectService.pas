(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSProjectService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProjectProtocol;

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
    AProjectName + '.nxproject';
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

procedure NXLSFillNexusProjectFields(AFields: TNXLSProjectFieldArray;
  const AProjectName, ATargetDir: string);
begin
  NXLSAddField(AFields, 'projectName', 'Project Name', 'text', AProjectName,
    True, 'Name of the Nexus project and program source.');
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

function NXLSQuoteScriptText(const AText: string): string;
begin
  Result := StringReplace(AText, '^', '^^', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '^"', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '^n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '^r', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '^t', [rfReplaceAll]);
  Result := '"' + Result + '"';
end;

function NXLSProjectDialectFile: string;
var
  lDirectory, lParent, lCandidate: string;
begin
  lDirectory := ExtractFileDir(ExpandFileName(ParamStr(0)));
  repeat
    lCandidate := IncludeTrailingPathDelimiter(lDirectory) + 'projects' +
      DirectorySeparator + 'nxbuild' + DirectorySeparator + 'language' +
      DirectorySeparator + 'nxbuild.Language.nxscript';
    if FileExists(lCandidate) then
      Exit(lCandidate);
    lParent := ExtractFileDir(lDirectory);
    if lParent = lDirectory then
      Break;
    lDirectory := lParent;
  until lDirectory = '';
  lCandidate := ExpandFileName('projects/nxbuild/language/nxbuild.Language.nxscript');
  if FileExists(lCandidate) then Exit(lCandidate);
  raise Exception.Create('nxbuild.Language.nxscript was not found under the Nexus installation.');
end;

function NXLSNexusProjectScript(const AProjectName, ATargetDir: string): string;
var
  lRoot, lId, lName: string;
  lGuid: TGUID;
begin
  lRoot := ExtractFileDir(ExtractFileDir(ExtractFileDir(
    ExtractFileDir(NXLSProjectDialectFile))));
  CreateGUID(lGuid);
  lId := Copy(GUIDToString(lGuid), 2, 36);
  lName := NXLSPascalIdentifier(AProjectName);
  Result :=
    'dialect ' + NXLSQuoteScriptText(NXLSProjectDialectFile) + ';' + LineEnding +
    'module Projects ' + NXLSQuoteScriptText(lRoot + '/projects/nxbuild/Projects.nxscript') + ';' + LineEnding +
    'module ' + NXLSQuoteScriptText(lRoot + '/projects/nxbuild/nxbuild.environment.nxscript') + ';' + LineEnding +
    'Project ' + lName + ' {' + LineEnding +
    '    Id: "Local.' + lId + '";' + LineEnding +
    '    RootDirectory: ' + NXLSQuoteScriptText(lRoot) + ';' + LineEnding +
    '    SourceRoot: ' + NXLSQuoteScriptText(NXLSProjectSourceDir(ATargetDir)) + ';' + LineEnding +
    '    OutputRoot: @Tools.OutputRoot + "/projects/' + lId + '/" + $TargetCPU + "-" + $TargetOS + "/" + $BuildConfiguration;' + LineEnding +
    '    Requires: [@Projects.NexusRTL];' + LineEnding +
    '    NXPC Application {' + LineEnding +
    '        CompilerPath: @Tools.Native.NXPCCompiler;' + LineEnding +
    '        SourceFiles: [@' + lName + '.SourceRoot + ' + NXLSQuoteScriptText('/' + AProjectName + '.lpr') + '];' + LineEnding +
    '        OutputPath: @' + lName + '.OutputRoot;' + LineEnding +
    '        Config Options { DisableDefaultConfigFiles: True; }' + LineEnding +
    '        Target Platform { OperatingSystem: $TargetOS; }' + LineEnding +
    '        Assembler LLVM TargetOS[linux] { OutputFormat: "as-clang"; }' + LineEnding +
    '        Language Pascal { Mode: ObjFPC; }' + LineEnding +
    '        Files Paths { CompilerUtilitiesPath: @Tools.Native.CompilerUtilitiesPath; UnitPaths: [@' + lName + '.SourceRoot]; }' + LineEnding +
    '    }' + LineEnding +
    '}' + LineEnding;
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
  if AProjectName = '' then AProjectName := 'newproject';
  if ATargetDir = '' then ATargetDir := GetCurrentDir;
end;

class procedure TNXLSProjectService.FillCreateNexusProjectWizard(
  AParams: TNXLSProjectCreateWizardParams;
  AResult: TNXLSProjectCreateWizardResult);
var
  lDirectory: string;
begin
  if AResult = nil then Exit;
  lDirectory := GetCurrentDir;
  if (AParams <> nil) and (AParams.workspaceRoot.Value <> '') then
    lDirectory := AParams.workspaceRoot.Value;
  AResult.title.Value := 'New Nexus Project';
  AResult.request.projectName.Value := 'newproject';
  AResult.request.targetDir.Value := ExpandFileName(lDirectory);
  AResult.request.Assigned := True;
  NXLSFillNexusProjectFields(AResult.fields, 'newproject', ExpandFileName(lDirectory));
  AResult.Assigned := True;
end;

class procedure TNXLSProjectService.FillPlanNexusProjectCreate(
  AParams: TNXLSProjectCreateParams; AResult: TNXLSProjectPlanCreateResult);
var
  lName, lDirectory, lProject, lSource: string;
  lCanExecute: Boolean;
begin
  if AResult = nil then Exit;
  NXLSReadNexusProjectParams(AParams, lName, lDirectory);
  lProject := NXLSProjectFileName(lName, lDirectory);
  lSource := NXLSProjectProgramFileName(lName, lDirectory);
  lCanExecute := NXLSIsValidProjectName(lName);
  if not lCanExecute then
    NXLSAddMessage(AResult.messages, 'error',
      'Project names may contain letters, digits, underscores and dashes.');
  if FileExists(lProject) or FileExists(lSource) then
  begin
    NXLSAddMessage(AResult.messages, 'error', 'A project or program file already exists at this destination.');
    lCanExecute := False;
  end;
  NXLSAddOutput(AResult.outputs, 'Nexus project', lProject);
  NXLSAddOutput(AResult.outputs, 'Program source', lSource);
  NXLSAddDetail(AResult.details, 'Project name', lName);
  NXLSAddDetail(AResult.details, 'Destination', ExpandFileName(lDirectory));
  AResult.title.Value := 'New Nexus Project';
  AResult.summary.Value := 'Create Nexus project "' + lName + '" in ' + ExpandFileName(lDirectory);
  AResult.canExecute.Value := lCanExecute;
  AResult.messages.Assigned := True;
  AResult.outputs.Assigned := True;
  AResult.details.Assigned := True;
  NXLSFillNexusProjectFields(AResult.fields, lName, ExpandFileName(lDirectory));
  AResult.Assigned := True;
end;

class procedure TNXLSProjectService.FillCreateNexusProject(
  AParams: TNXLSProjectCreateParams; AResult: TNXLSProjectCreateResult);
var
  lName, lDirectory: string;
  lFile: TNXLSProjectFile;
begin
  if AResult = nil then Exit;
  NXLSReadNexusProjectParams(AParams, lName, lDirectory);
  if not NXLSIsValidProjectName(lName) then
    raise Exception.Create('Project name is invalid.');
  if FileExists(NXLSProjectFileName(lName, lDirectory)) or
     FileExists(NXLSProjectProgramFileName(lName, lDirectory)) then
    raise Exception.Create('A project or program file already exists at this destination.');
  lFile := TNXLSProjectFile(AResult.files.AddObject(TNXLSProjectFile));
  lFile.path.Value := NXLSProjectFileName(lName, lDirectory);
  lFile.content.Value := NXLSNexusProjectScript(lName, lDirectory);
  lFile.Assigned := True;
  lFile := TNXLSProjectFile(AResult.files.AddObject(TNXLSProjectFile));
  lFile.path.Value := NXLSProjectProgramFileName(lName, lDirectory);
  lFile.content.Value := NXLSNexusProgramSource(lName);
  lFile.Assigned := True;
  AResult.message.Value := 'Nexus project created: ' + lName;
  AResult.files.Assigned := True;
  AResult.Assigned := True;
end;

end.
