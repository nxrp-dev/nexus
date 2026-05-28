unit tsNXLSCoreTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSCoreTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  obNXFPCBuildOptions,
  obNXLSLSPModel,
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXPascalProject,
  obNXTestContext,
  obNXTestSuite;

procedure TestFPCSwitchStateHelpers(AContext: TNXTestContext);
begin
  AContext.AssertEquals('+', NXFPCSwitchSuffix(fssEnabled),
    'Enabled switch suffix should be +.');
  AContext.AssertEquals('-', NXFPCSwitchSuffix(fssDisabled),
    'Disabled switch suffix should be -.');
  AContext.AssertEquals('', NXFPCSwitchSuffix(fssUnset),
    'Unset switch suffix should be empty.');
  AContext.AssertTrue(NXFPCSwitchEnabled(fssEnabled),
    'Enabled switch should report enabled.');
  AContext.AssertTrue(NXFPCSwitchDisabled(fssDisabled),
    'Disabled switch should report disabled.');
end;

procedure TestFPCBuildOptionsGenerateArguments(AContext: TNXTestContext);
var
  lArguments: TStringList;
  lOptions: TNXFPCBuildOptions;
begin
  lOptions := TNXFPCBuildOptions.Create;
  try
    lOptions.Language.Mode := flmObjFPC;
    lOptions.Target.OperatingSystem := NXFPCOperatingSystemWin64;
    lOptions.OutputFile := 'nexusls.exe';
    lOptions.InputFile := 'nexusls.lpr';

    lArguments := lOptions.BuildArguments;
    try
      AContext.AssertTrue(lArguments.IndexOf('-Mobjfpc') >= 0,
        'Build arguments should include ObjFPC mode.');
      AContext.AssertTrue(lArguments.IndexOf('-Twin64') >= 0,
        'Build arguments should include Win64 target.');
      AContext.AssertTrue(lArguments.IndexOf('-onexusls.exe') >= 0,
        'Build arguments should include output file.');
      AContext.AssertTrue(lArguments.IndexOf('nexusls.lpr') >= 0,
        'Build arguments should include input file.');
    finally
      lArguments.Free;
    end;
  finally
    lOptions.Free;
  end;
end;

procedure TestPascalProjectVariableResolution(AContext: TNXTestContext);
var
  lProject: TNXPascalProject;
begin
  lProject := TNXPascalProject.Create;
  try
    lProject.Name := 'NexusLS';
    lProject.ProjectFileName := 'nexusls.lpi';
    lProject.ProjectRoot := 'C:' + PathDelim + 'workspace' + PathDelim +
      'NexusLS';
    lProject.SetVariable('BuildMode', 'Debug');

    AContext.AssertEquals('NexusLS-Debug',
      lProject.ResolveValue('$(ProjectName)-$(BuildMode)'),
      'Project variables should resolve by name.');
    AContext.AssertEquals(ExpandFileName(IncludeTrailingPathDelimiter(
      lProject.ProjectRoot) + 'src' + PathDelim + 'nexusls.lpr'),
      lProject.ResolvePath('src' + PathDelim + 'nexusls.lpr'),
      'Relative paths should resolve against the project root.');
  finally
    lProject.Free;
  end;
end;

procedure TestLSPModelStartsEmpty(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
begin
  lModel := TNXLSLSPModel.Create;
  try
    AContext.AssertFalse(lModel.InitializeReceived,
      'Fresh model should not be initialized.');
    AContext.AssertEquals(0, lModel.DocumentCount,
      'Fresh model should not contain documents.');
  finally
    lModel.Free;
  end;
end;

function NXLSCreateUniqueTempDir(const APrefix: string): string;
var
  lTempFile: string;
begin
  lTempFile := GetTempFileName('', APrefix);
  if FileExists(lTempFile) then
    DeleteFile(lTempFile);

  Result := lTempFile + '_dir';
  ForceDirectories(Result);
end;

procedure TestInitializeConfiguresCodeToolsWorkspace(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSInitializeParams;
  lFolder: TNXLSWorkspaceFolder;
  lRoot: string;
  lUnitDir: string;
  lFileName: string;
  lFile: TextFile;
  lJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lUnitDir := IncludeTrailingPathDelimiter(lRoot) + 'src';
  ForceDirectories(lUnitDir);

  lFileName := IncludeTrailingPathDelimiter(lUnitDir) + 'SampleUnit.pas';
  AssignFile(lFile, lFileName);
  Rewrite(lFile);
  try
    WriteLn(lFile, 'unit SampleUnit;');
    WriteLn(lFile, 'interface');
    WriteLn(lFile, 'implementation');
    WriteLn(lFile, 'end.');
  finally
    CloseFile(lFile);
  end;

  lParams := TNXLSInitializeParams.Create;
  lModel := TNXLSLSPModel.Create;
  try
    lJSON := TJSONString.Create(NXLSPathToFileURI(lRoot));
    try
      lParams.rootUri.FromJSONData(lJSON);
    finally
      lJSON.Free;
    end;

    lFolder := TNXLSWorkspaceFolder(lParams.workspaceFolders.AddObject(TNXLSWorkspaceFolder));
    lFolder.uri.Value := NXLSPathToFileURI(lRoot);
    lFolder.name.Value := 'nexusls-core-test';

    lModel.BeginInitialize(lParams);

    AContext.AssertTrue(lModel.CodeToolsInitialized,
      'Initialize should configure CodeTools.');
    AContext.AssertTrue(lModel.EffectiveWorkspacePaths.IndexOf(
      IncludeTrailingPathDelimiter(ExpandFileName(lUnitDir))) >= 0,
      'Initialize should collect workspace folders containing Pascal source.');
    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf('-Fu' +
      IncludeTrailingPathDelimiter(ExpandFileName(lUnitDir))) >= 0,
      'Initialize should add workspace source folders as unit paths.');
    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf('-Fi' +
      IncludeTrailingPathDelimiter(ExpandFileName(lUnitDir))) >= 0,
      'Initialize should add workspace source folders as include paths.');
  finally
    lModel.Free;
    lParams.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lUnitDir);
    RemoveDir(lRoot);
  end;
end;

procedure RegisterNXLSCoreTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.Core');
  lSuite.AddTest('FPCSwitchStateHelpers', @TestFPCSwitchStateHelpers);
  lSuite.AddTest('FPCBuildOptionsGenerateArguments',
    @TestFPCBuildOptionsGenerateArguments);
  lSuite.AddTest('PascalProjectVariableResolution',
    @TestPascalProjectVariableResolution);
  lSuite.AddTest('LSPModelStartsEmpty', @TestLSPModelStartsEmpty);
  lSuite.AddTest('InitializeConfiguresCodeToolsWorkspace',
    @TestInitializeConfiguresCodeToolsWorkspace);
end;

end.
