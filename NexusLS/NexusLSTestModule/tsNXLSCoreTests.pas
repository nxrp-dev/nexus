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
  obNXJSONRPCMessages,
  obNXLSDispatcher,
  obNXLSLSPModel,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXLSToolchainService,
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

procedure TestInitializeLoadsExplicitPaths(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSInitializeParams;
  lFolder: TNXLSWorkspaceFolder;
  lRoot: string;
  lUnitDir: string;
  lIncludeDir: string;
  lOptions: TJSONObject;
  lFPCOptions: TJSONArray;
  lJSON: TJSONData;
  lOptionsJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lUnitDir := IncludeTrailingPathDelimiter(lRoot) + 'src';
  lIncludeDir := IncludeTrailingPathDelimiter(lRoot) + 'include';
  ForceDirectories(lUnitDir);
  ForceDirectories(lIncludeDir);

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

    lOptions := TJSONObject.Create;
    try
      lFPCOptions := TJSONArray.Create;
      lFPCOptions.Add('-Fu$(root)src');
      lFPCOptions.Add('-Fi$(root)include');
      lOptions.Add('fpcOptions', lFPCOptions);

      lOptionsJSON := lOptions;
      lParams.initializationOptions.FromJSONData(lOptionsJSON);
    finally
      lOptions.Free;
    end;

    lModel.BeginInitialize(lParams);

    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf('-Fu' +
      ExpandFileName(lUnitDir)) >= 0,
      'Explicit unit search paths should be loaded.');
    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf('-Fi' +
      ExpandFileName(lIncludeDir)) >= 0,
      'Explicit include search paths should be loaded.');
  finally
    lModel.Free;
    lParams.Free;
    RemoveDir(lIncludeDir);
    RemoveDir(lUnitDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestInitializeHonorsOptionsMacros(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSInitializeParams;
  lFolder: TNXLSWorkspaceFolder;
  lRoot: string;
  lOptions: TJSONObject;
  lFPCOptions: TJSONArray;
  lRootJSON: TJSONData;
  lOptionsJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');

  lParams := TNXLSInitializeParams.Create;
  lModel := TNXLSLSPModel.Create;
  try
    lRootJSON := TJSONString.Create(NXLSPathToFileURI(lRoot));
    try
      lParams.rootUri.FromJSONData(lRootJSON);
    finally
      lRootJSON.Free;
    end;

    lFolder := TNXLSWorkspaceFolder(lParams.workspaceFolders.AddObject(TNXLSWorkspaceFolder));
    lFolder.uri.Value := NXLSPathToFileURI(lRoot);
    lFolder.name.Value := 'nexusls-options-test';

    lOptions := TJSONObject.Create;
    try
      lFPCOptions := TJSONArray.Create;
      lFPCOptions.Add('$(root)manual');
      lFPCOptions.Add('$(tmpdir)nxls-include');
      lOptions.Add('fpcOptions', lFPCOptions);

      lOptionsJSON := lOptions;
      lParams.initializationOptions.FromJSONData(lOptionsJSON);
    finally
      lOptions.Free;
    end;

    lModel.BeginInitialize(lParams);

    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf(
      IncludeTrailingPathDelimiter(ExpandFileName(lRoot)) + 'manual') >= 0,
      'Initialization option macros should expand $(root).');
    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf(
      GetTempDir(True) + 'nxls-include') >= 0,
      'Initialization option macros should expand $(tmpdir).');
  finally
    lModel.Free;
    lParams.Free;
    RemoveDir(lRoot);
  end;
end;

procedure TestInitializeLoadsToolchainConfig(AContext: TNXTestContext);
var
  lFPCDir: string;
  lLazarusDir: string;
  lLazarusToolchain: TJSONObject;
  lModel: TNXLSLSPModel;
  lOptions: TJSONObject;
  lOptionsJSON: TJSONData;
  lParams: TNXLSInitializeParams;
  lRoot: string;
  lRootJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lLazarusDir := IncludeTrailingPathDelimiter(lRoot) + 'lazarus';
  lFPCDir := IncludeTrailingPathDelimiter(lLazarusDir) + 'fpc' +
    DirectorySeparator + '3.2.2';
  ForceDirectories(lFPCDir);

  lParams := TNXLSInitializeParams.Create;
  lModel := TNXLSLSPModel.Create;
  try
    lRootJSON := TJSONString.Create(NXLSPathToFileURI(lRoot));
    try
      lParams.rootUri.FromJSONData(lRootJSON);
    finally
      lRootJSON.Free;
    end;

    lOptions := TJSONObject.Create;
    try
      lLazarusToolchain := TJSONObject.Create;
      lLazarusToolchain.Add('enabled', True);
      lLazarusToolchain.Add('lazarusDirectory', lLazarusDir);
      lOptions.Add('toolchains', TJSONObject.Create([
        'lazarus', lLazarusToolchain
      ]));

      lOptionsJSON := lOptions;
      lParams.initializationOptions.FromJSONData(lOptionsJSON);
    finally
      lOptions.Free;
    end;

    lModel.BeginInitialize(lParams);

    AContext.AssertEquals(ExpandFileName(lLazarusDir),
      lModel.Settings.LazarusDir,
      'Initialize should load Lazarus directory from toolchain config.');
    AContext.AssertEquals(ExpandFileName(lFPCDir),
      lModel.Settings.FPCDir,
      'Initialize should derive bundled FPC directory from Lazarus toolchain config.');
    AContext.AssertEquals(IncludeTrailingPathDelimiter(ExpandFileName(lFPCDir)) +
      'source', lModel.Settings.FPCSrcDir,
      'Toolchain resolution should derive FPC source directory.');
    AContext.AssertEquals(ExpandFileName(lLazarusDir),
      lModel.Settings.LazarusSrcDir,
      'Toolchain resolution should derive Lazarus source directory.');
    AContext.AssertEquals(lModel.Settings.FPCSrcDir,
      lModel.PascalSearchPathContext.FPCSrcDir,
      'Search paths should consume resolved FPC source directory from settings.');
    AContext.AssertEquals(lModel.Settings.LazarusSrcDir,
      lModel.PascalSearchPathContext.LazarusSrcDir,
      'Search paths should consume resolved Lazarus source directory from settings.');
  finally
    lModel.Free;
    lParams.Free;
    RemoveDir(lFPCDir);
    RemoveDir(ExtractFileDir(lFPCDir));
    RemoveDir(lLazarusDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestInitializeHonorsProgramConfigAndRootPathFallback(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSInitializeParams;
  lRoot: string;
  lRootJSON: TJSONData;
  lOptions: TJSONObject;
  lOptionsJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');

  lParams := TNXLSInitializeParams.Create;
  lModel := TNXLSLSPModel.Create;
  try
    lRootJSON := TJSONString.Create(lRoot);
    try
      lParams.rootPath.FromJSONData(lRootJSON);
    finally
      lRootJSON.Free;
    end;

    lOptions := TJSONObject.Create;
    try
      lOptions.Add('program', '$(root)app.lpr');
      lOptionsJSON := lOptions;
      lParams.initializationOptions.FromJSONData(lOptionsJSON);
    finally
      lOptions.Free;
    end;

    lModel.BeginInitialize(lParams);

    AContext.AssertEquals(IncludeTrailingPathDelimiter(ExpandFileName(lRoot)),
      lModel.ProjectDir, 'Initialize should fall back to rootPath when rootUri is absent.');
    AContext.AssertEquals(IncludeTrailingPathDelimiter(ExpandFileName(lRoot)) + 'app.lpr',
      lModel.Settings.ProgramFile, 'program should parse and expand $(root).');
  finally
    lModel.Free;
    lParams.Free;
    RemoveDir(lRoot);
  end;
end;

procedure TestInitializeUsesExplicitLPIProgram(AContext: TNXTestContext);
var
  lLPIFile: string;
  lModel: TNXLSLSPModel;
  lOptions: TJSONObject;
  lOptionsJSON: TJSONData;
  lParams: TNXLSInitializeParams;
  lProjectDir: string;
  lRoot: string;
  lRootJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lProjectDir := IncludeTrailingPathDelimiter(lRoot) + 'NexusLS';
  ForceDirectories(lProjectDir);
  lLPIFile := IncludeTrailingPathDelimiter(lProjectDir) + 'nexusls.lpi';

  with TStringList.Create do
  try
    Text :=
      '<?xml version="1.0"?>' + LineEnding +
      '<CONFIG>' + LineEnding +
      '  <ProjectOptions>' + LineEnding +
      '    <General><Title Value="NexusLS"/></General>' + LineEnding +
      '  </ProjectOptions>' + LineEnding +
      '  <CompilerOptions>' + LineEnding +
      '    <SearchPaths><OtherUnitFiles Value="src;src\protocol;..\NexusLib\src"/></SearchPaths>' + LineEnding +
      '  </CompilerOptions>' + LineEnding +
      '</CONFIG>';
    SaveToFile(lLPIFile);
  finally
    Free;
  end;

  lParams := TNXLSInitializeParams.Create;
  lModel := TNXLSLSPModel.Create;
  try
    lRootJSON := TJSONString.Create(lRoot);
    try
      lParams.rootPath.FromJSONData(lRootJSON);
    finally
      lRootJSON.Free;
    end;

    lOptions := TJSONObject.Create;
    try
      lOptions.Add('cwd', lProjectDir);
      lOptions.Add('program', lLPIFile);
      lOptionsJSON := lOptions;
      lParams.initializationOptions.FromJSONData(lOptionsJSON);
    finally
      lOptions.Free;
    end;

    lModel.BeginInitialize(lParams);

    AContext.AssertEquals(IncludeTrailingPathDelimiter(ExpandFileName(lProjectDir)),
      lModel.ProjectDir,
      'Explicit .lpi program should set project root to the .lpi directory.');
    AContext.AssertEquals(ExpandFileName(lLPIFile),
      lModel.PascalSearchPathContext.LPIFileName,
      'Explicit .lpi program should be used instead of shallow root discovery.');
    AContext.AssertEquals(ExpandFileName(lLPIFile),
      lModel.Settings.ProgramFile,
      'Settings should preserve and expand the explicit program file.');
  finally
    lModel.Free;
    lParams.Free;
    DeleteFile(lLPIFile);
    RemoveDir(lProjectDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestLazarusToolchainPlanValidatesDirectory(AContext: TNXTestContext);
var
  lRoot: string;
  lLazbuildFile: string;
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlaz');
  lLazbuildFile := IncludeTrailingPathDelimiter(lRoot) + 'lazbuild';
  {$IFDEF MSWINDOWS}
  lLazbuildFile := lLazbuildFile + '.exe';
  {$ENDIF}

  with TStringList.Create do
  try
    Text := '';
    SaveToFile(lLazbuildFile);
  finally
    Free;
  end;

  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'lazarus';
    lParams.lazarusDirectory.Value := lRoot;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'A Lazarus directory with lazbuild should validate.');
    AContext.AssertEquals(ExpandFileName(lRoot),
      lResult.normalizedLazarusDirectory.Value,
      'Toolchain plan should normalize the Lazarus directory.');
  finally
    lResult.Free;
    lParams.Free;
    DeleteFile(lLazbuildFile);
    RemoveDir(lRoot);
  end;
end;

function NXLSFindProjectField(AFields: TNXLSProjectFieldArray;
  const AId: string): TNXLSProjectField;
var
  lField: TNXLSProjectField;
  lIndex: Integer;
begin
  Result := nil;
  for lIndex := 0 to AFields.Count - 1 do
  begin
    lField := TNXLSProjectField(AFields[lIndex]);
    if lField.id.Value = AId then
      Exit(lField);
  end;
end;

procedure NXLSCreateEmptyFile(const AFileName: string);
begin
  ForceDirectories(ExtractFileDir(AFileName));
  with TStringList.Create do
  try
    Text := '';
    SaveToFile(AFileName);
  finally
    Free;
  end;
end;

function NXLSTestExecutableFileName(const ABaseName: string): string;
begin
  Result := ABaseName;
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function NXLSTestBatchFileName(const ABaseName: string): string;
begin
  Result := ABaseName;
  {$IFDEF MSWINDOWS}
  Result := Result + '.cmd';
  {$ENDIF}
end;

procedure TestToolchainPlanMarksInvalidField(AContext: TNXTestContext);
var
  lField: TNXLSProjectField;
  lMissingRoot: string;
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
begin
  lMissingRoot := IncludeTrailingPathDelimiter(GetTempDir) +
    'nexus-lazarus-missing-directory';
  if DirectoryExists(lMissingRoot) then
    RemoveDir(lMissingRoot);

  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'lazarus';
    lParams.lazarusDirectory.Value := lMissingRoot;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Missing Lazarus directory should still allow partial settings to be saved.');
    lField := NXLSFindProjectField(lResult.fields, 'lazarusDirectory');
    AContext.AssertTrue(lField <> nil,
      'Toolchain plan should return the Lazarus directory field.');
    AContext.AssertFalse(lField.valid.Value,
      'Missing Lazarus directory should mark its field invalid.');
    AContext.AssertEquals('error', lField.severity.Value,
      'Invalid Lazarus directory field should report error severity.');
    AContext.AssertEquals('The Lazarus directory does not exist.',
      lField.message.Value,
      'Invalid Lazarus directory field should report the field-level reason.');
  finally
    lResult.Free;
    lParams.Free;
  end;
end;

procedure TestAndroidNDKFieldSuggestsDownloadURL(AContext: TNXTestContext);
var
  lField: TNXLSProjectField;
  lMissingRoot: string;
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
  lSuggestion: TNXLSProjectFieldSuggestion;
begin
  lMissingRoot := IncludeTrailingPathDelimiter(GetTempDir) +
    'nexus-android-ndk-missing-directory';
  if DirectoryExists(lMissingRoot) then
    RemoveDir(lMissingRoot);

  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'android';
    lParams.androidSdkDirectory.Value := lMissingRoot;
    lParams.androidNdkDirectory.Value := lMissingRoot;
    lParams.javaHome.Value := lMissingRoot;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Missing Android NDK directory should still allow partial settings to be saved.');
    lField := NXLSFindProjectField(lResult.fields, 'androidNdkDirectory');
    AContext.AssertTrue(lField <> nil,
      'Toolchain plan should return the Android NDK field.');
    AContext.AssertFalse(lField.valid.Value,
      'Missing Android NDK directory should mark its field invalid.');
    AContext.AssertTrue(lField.suggestions.Count > 0,
      'Missing Android NDK should provide a suggestion.');

    lSuggestion := TNXLSProjectFieldSuggestion(lField.suggestions[0]);
    AContext.AssertEquals('url', lSuggestion.kind.Value,
      'Android NDK missing suggestion should be a URL suggestion.');
    AContext.AssertEquals('https://developer.android.com/ndk/downloads',
      lSuggestion.value.Value,
      'Android NDK missing suggestion should point to the official downloads page.');
  finally
    lResult.Free;
    lParams.Free;
  end;
end;

procedure TestFreePascalDirectoryRequiresCompiler(AContext: TNXTestContext);
var
  lField: TNXLSProjectField;
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
  lRoot: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxfpc');

  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'freepascal';
    lParams.fpcDirectory.Value := lRoot;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Invalid Free Pascal directory should still allow partial settings to be saved.');
    lField := NXLSFindProjectField(lResult.fields, 'fpcDirectory');
    AContext.AssertTrue(lField <> nil,
      'Toolchain plan should return the Free Pascal directory field.');
    AContext.AssertFalse(lField.valid.Value,
      'Free Pascal directory without fpc should be invalid.');
    AContext.AssertEquals(
      'fpc was not found in the selected Free Pascal directory.',
      lField.message.Value,
      'Free Pascal install validator should report missing fpc.');
  finally
    lResult.Free;
    lParams.Free;
    RemoveDir(lRoot);
  end;
end;

procedure TestFreePascalDirectoryWithCompilerValidates(AContext: TNXTestContext);
var
  lBinDir: string;
  lField: TNXLSProjectField;
  lFpcFile: string;
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
  lRoot: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxfpc');
  {$IFDEF MSWINDOWS}
  lBinDir := IncludeTrailingPathDelimiter(lRoot) + 'bin' +
    DirectorySeparator + 'x86_64-win64';
  {$ELSE}
  lBinDir := IncludeTrailingPathDelimiter(lRoot) + 'bin';
  {$ENDIF}
  lFpcFile := IncludeTrailingPathDelimiter(lBinDir) +
    NXLSTestExecutableFileName('fpc');
  NXLSCreateEmptyFile(lFpcFile);

  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'freepascal';
    lParams.fpcDirectory.Value := lRoot;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Valid Free Pascal directory should allow saving.');
    lField := NXLSFindProjectField(lResult.fields, 'fpcDirectory');
    AContext.AssertTrue(lField <> nil,
      'Toolchain plan should return the Free Pascal directory field.');
    AContext.AssertTrue(lField.valid.Value,
      'Free Pascal directory with fpc should validate.');
  finally
    lResult.Free;
    lParams.Free;
    DeleteFile(lFpcFile);
    RemoveDir(lBinDir);
    RemoveDir(ExtractFileDir(lBinDir));
    RemoveDir(lRoot);
  end;
end;

procedure TestAndroidToolchainVerifiesInstalledTools(AContext: TNXTestContext);
var
  lField: TNXLSProjectField;
  lJavaHome: string;
  lNdkDir: string;
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
  lRoot: string;
  lSdkDir: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxandroid');
  lSdkDir := IncludeTrailingPathDelimiter(lRoot) + 'sdk';
  lNdkDir := IncludeTrailingPathDelimiter(lRoot) + 'ndk';
  lJavaHome := IncludeTrailingPathDelimiter(lRoot) + 'java';
  ForceDirectories(lSdkDir);
  ForceDirectories(lNdkDir);
  ForceDirectories(lJavaHome);

  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'android';
    lParams.androidSdkDirectory.Value := lSdkDir;
    lParams.androidNdkDirectory.Value := lNdkDir;
    lParams.javaHome.Value := lJavaHome;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Invalid Android toolchain paths should still allow partial settings to be saved.');

    lField := NXLSFindProjectField(lResult.fields, 'androidSdkDirectory');
    AContext.AssertTrue(lField <> nil,
      'Toolchain plan should return the Android SDK field.');
    AContext.AssertFalse(lField.valid.Value,
      'Android SDK without adb should be invalid.');
    AContext.AssertEquals(
      'adb was not found under platform-tools in the selected Android SDK directory.',
      lField.message.Value,
      'Android SDK validator should report missing adb.');

    lField := NXLSFindProjectField(lResult.fields, 'androidNdkDirectory');
    AContext.AssertTrue(lField <> nil,
      'Toolchain plan should return the Android NDK field.');
    AContext.AssertFalse(lField.valid.Value,
      'Android NDK without ndk-build/source.properties should be invalid.');
    AContext.AssertEquals(
      'ndk-build and source.properties were not found in the selected Android NDK directory.',
      lField.message.Value,
      'Android NDK validator should report missing NDK markers.');

    lField := NXLSFindProjectField(lResult.fields, 'javaHome');
    AContext.AssertTrue(lField <> nil,
      'Toolchain plan should return the Java Home field.');
    AContext.AssertFalse(lField.valid.Value,
      'Java Home without bin/java should be invalid.');
    AContext.AssertEquals(
      'java was not found under bin in the selected Java Home directory.',
      lField.message.Value,
      'Java Home validator should report missing java.');
  finally
    lResult.Free;
    lParams.Free;
    RemoveDir(lJavaHome);
    RemoveDir(lNdkDir);
    RemoveDir(lSdkDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestAndroidToolchainInstalledToolsValidate(AContext: TNXTestContext);
var
  lAdbFile: string;
  lField: TNXLSProjectField;
  lJavaFile: string;
  lJavaHome: string;
  lNdkBuildFile: string;
  lNdkDir: string;
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
  lRoot: string;
  lSdkDir: string;
  lSourcePropertiesFile: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxandroid');
  lSdkDir := IncludeTrailingPathDelimiter(lRoot) + 'sdk';
  lNdkDir := IncludeTrailingPathDelimiter(lRoot) + 'ndk';
  lJavaHome := IncludeTrailingPathDelimiter(lRoot) + 'java';

  lAdbFile := IncludeTrailingPathDelimiter(lSdkDir) + 'platform-tools' +
    DirectorySeparator + NXLSTestExecutableFileName('adb');
  lNdkBuildFile := IncludeTrailingPathDelimiter(lNdkDir) +
    NXLSTestBatchFileName('ndk-build');
  lSourcePropertiesFile := IncludeTrailingPathDelimiter(lNdkDir) +
    'source.properties';
  lJavaFile := IncludeTrailingPathDelimiter(lJavaHome) + 'bin' +
    DirectorySeparator + NXLSTestExecutableFileName('java');

  NXLSCreateEmptyFile(lAdbFile);
  NXLSCreateEmptyFile(lNdkBuildFile);
  NXLSCreateEmptyFile(lSourcePropertiesFile);
  NXLSCreateEmptyFile(lJavaFile);

  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'android';
    lParams.androidSdkDirectory.Value := lSdkDir;
    lParams.androidNdkDirectory.Value := lNdkDir;
    lParams.javaHome.Value := lJavaHome;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Valid Android toolchain paths should allow saving.');

    lField := NXLSFindProjectField(lResult.fields, 'androidSdkDirectory');
    AContext.AssertTrue(lField.valid.Value,
      'Android SDK with adb should validate.');
    lField := NXLSFindProjectField(lResult.fields, 'androidNdkDirectory');
    AContext.AssertTrue(lField.valid.Value,
      'Android NDK with ndk-build/source.properties should validate.');
    lField := NXLSFindProjectField(lResult.fields, 'javaHome');
    AContext.AssertTrue(lField.valid.Value,
      'Java Home with bin/java should validate.');
  finally
    lResult.Free;
    lParams.Free;
    DeleteFile(lJavaFile);
    RemoveDir(ExtractFileDir(lJavaFile));
    DeleteFile(lSourcePropertiesFile);
    DeleteFile(lNdkBuildFile);
    RemoveDir(lNdkDir);
    DeleteFile(lAdbFile);
    RemoveDir(ExtractFileDir(lAdbFile));
    RemoveDir(lSdkDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestToolchainListSupportedIncludesLazarus(AContext: TNXTestContext);
var
  lResult: TNXLSToolchainListSupportedResult;
begin
  lResult := TNXLSToolchainListSupportedResult.Create;
  try
    TNXLSToolchainService.FillListSupported(lResult);

    AContext.AssertTrue(lResult.toolchains.Count >= 3,
      'Supported toolchains should include Lazarus, Free Pascal, and Android.');
    AContext.AssertEquals('lazarus',
      TNXLSToolchainDescriptor(lResult.toolchains[0]).kind.Value,
      'The initial supported toolchain should be Lazarus.');
    AContext.AssertEquals('freepascal',
      TNXLSToolchainDescriptor(lResult.toolchains[1]).kind.Value,
      'Supported toolchains should include Free Pascal.');
    AContext.AssertEquals('android',
      TNXLSToolchainDescriptor(lResult.toolchains[2]).kind.Value,
      'Supported toolchains should include Android.');
  finally
    lResult.Free;
  end;
end;

procedure TestToolchainListSupportedDispatchReturnsDescriptors(
  AContext: TNXTestContext);
var
  lMessage: TNXJSONRPCMessage;
  lDispatched: Boolean;
  lResponseText: string;
  lResponse: TJSONData;
  lResult: TJSONObject;
  lToolchains: TJSONArray;
begin
  lMessage := TNXJSONRPC.ParseMessage(
    '{"jsonrpc":"2.0","id":1,"method":"nexusls.toolchain.listSupported","params":{}}');
  try
    lDispatched := TNXLSDispatcher.DispatchMessage(lMessage, lResponseText);
  finally
    lMessage.Free;
  end;

  AContext.AssertTrue(lDispatched,
    'Toolchain listSupported request should dispatch.');
  lResponse := GetJSON(lResponseText);
  try
    AContext.AssertTrue(lResponse is TJSONObject,
      'Toolchain listSupported response should be a JSON object.');
    lResult := TJSONObject(lResponse).Objects['result'];
    lToolchains := lResult.Arrays['toolchains'];
    AContext.AssertEquals(3, lToolchains.Count,
      'Toolchain listSupported dispatch should return all supported toolchains.');
    AContext.AssertEquals('lazarus',
      lToolchains.Objects[0].Strings['kind'],
      'The first dispatched toolchain should be Lazarus.');
    AContext.AssertEquals('freepascal',
      lToolchains.Objects[1].Strings['kind'],
      'The second dispatched toolchain should be Free Pascal.');
    AContext.AssertEquals('android',
      lToolchains.Objects[2].Strings['kind'],
      'The third dispatched toolchain should be Android.');
  finally
    lResponse.Free;
  end;
end;

procedure TestDisabledLazarusToolchainPlanDoesNotRequireDirectory(
  AContext: TNXTestContext);
var
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
begin
  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'lazarus';
    lParams.enabled.Value := False;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Disabled Lazarus toolchain should be saveable without a directory.');
  finally
    lResult.Free;
    lParams.Free;
  end;
end;

procedure TestDisabledAndroidToolchainPlanDoesNotRequireDirectories(
  AContext: TNXTestContext);
var
  lParams: TNXLSToolchainConfigureParams;
  lResult: TNXLSToolchainPlanConfigureResult;
begin
  lParams := TNXLSToolchainConfigureParams.Create;
  lResult := TNXLSToolchainPlanConfigureResult.Create;
  try
    lParams.kind.Value := 'android';
    lParams.enabled.Value := False;

    TNXLSToolchainService.FillPlanConfigure(lParams, lResult);

    AContext.AssertTrue(lResult.canExecute.Value,
      'Disabled Android toolchain should be saveable without SDK paths.');
  finally
    lResult.Free;
    lParams.Free;
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
  lSuite.AddTest('InitializeLoadsExplicitPaths',
    @TestInitializeLoadsExplicitPaths);
  lSuite.AddTest('InitializeHonorsOptionsMacros',
    @TestInitializeHonorsOptionsMacros);
  lSuite.AddTest('InitializeLoadsToolchainConfig',
    @TestInitializeLoadsToolchainConfig);
  lSuite.AddTest('InitializeHonorsProgramConfigAndRootPathFallback',
    @TestInitializeHonorsProgramConfigAndRootPathFallback);
  lSuite.AddTest('InitializeUsesExplicitLPIProgram',
    @TestInitializeUsesExplicitLPIProgram);
  lSuite.AddTest('ToolchainListSupportedIncludesLazarus',
    @TestToolchainListSupportedIncludesLazarus);
  lSuite.AddTest('ToolchainListSupportedDispatchReturnsDescriptors',
    @TestToolchainListSupportedDispatchReturnsDescriptors);
  lSuite.AddTest('LazarusToolchainPlanValidatesDirectory',
    @TestLazarusToolchainPlanValidatesDirectory);
  lSuite.AddTest('ToolchainPlanMarksInvalidField',
    @TestToolchainPlanMarksInvalidField);
  lSuite.AddTest('AndroidNDKFieldSuggestsDownloadURL',
    @TestAndroidNDKFieldSuggestsDownloadURL);
  lSuite.AddTest('FreePascalDirectoryRequiresCompiler',
    @TestFreePascalDirectoryRequiresCompiler);
  lSuite.AddTest('FreePascalDirectoryWithCompilerValidates',
    @TestFreePascalDirectoryWithCompilerValidates);
  lSuite.AddTest('AndroidToolchainVerifiesInstalledTools',
    @TestAndroidToolchainVerifiesInstalledTools);
  lSuite.AddTest('AndroidToolchainInstalledToolsValidate',
    @TestAndroidToolchainInstalledToolsValidate);
  lSuite.AddTest('DisabledLazarusToolchainPlanDoesNotRequireDirectory',
    @TestDisabledLazarusToolchainPlanDoesNotRequireDirectory);
  lSuite.AddTest('DisabledAndroidToolchainPlanDoesNotRequireDirectories',
    @TestDisabledAndroidToolchainPlanDoesNotRequireDirectories);
end;

end.
