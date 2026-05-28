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

procedure NXLSWriteTextFile(const AFileName, AText: string);
var
  lFile: TextFile;
begin
  AssignFile(lFile, AFileName);
  Rewrite(lFile);
  try
    Write(lFile, AText);
  finally
    CloseFile(lFile);
  end;
end;

procedure TestInitializeConfiguresCodeToolsWorkspace(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSInitializeParams;
  lFolder: TNXLSWorkspaceFolder;
  lRoot: string;
  lUnitDir: string;
  lFileName: string;
  lJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lUnitDir := IncludeTrailingPathDelimiter(lRoot) + 'src';
  ForceDirectories(lUnitDir);

  lFileName := IncludeTrailingPathDelimiter(lUnitDir) + 'SampleUnit.pas';
  NXLSWriteTextFile(lFileName, 'unit SampleUnit;' + LineEnding +
    'interface' + LineEnding + 'implementation' + LineEnding + 'end.');

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

procedure TestInitializeHonorsOptionsMacrosAndExcludes(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSInitializeParams;
  lFolder: TNXLSWorkspaceFolder;
  lRoot: string;
  lSourceDir: string;
  lExcludedDir: string;
  lSourceFile: string;
  lExcludedFile: string;
  lOptions: TJSONObject;
  lFPCOptions: TJSONArray;
  lExcludes: TJSONArray;
  lRootJSON: TJSONData;
  lOptionsJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lSourceDir := IncludeTrailingPathDelimiter(lRoot) + 'src';
  lExcludedDir := IncludeTrailingPathDelimiter(lRoot) + 'ignored';
  ForceDirectories(lSourceDir);
  ForceDirectories(lExcludedDir);

  lSourceFile := IncludeTrailingPathDelimiter(lSourceDir) + 'IncludedUnit.pas';
  lExcludedFile := IncludeTrailingPathDelimiter(lExcludedDir) + 'IgnoredUnit.pas';
  NXLSWriteTextFile(lSourceFile, 'unit IncludedUnit; interface implementation end.');
  NXLSWriteTextFile(lExcludedFile, 'unit IgnoredUnit; interface implementation end.');

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
      lOptions.Add('includeWorkspaceFoldersAsUnitPaths', False);
      lOptions.Add('includeWorkspaceFoldersAsIncludePaths', True);

      lExcludes := TJSONArray.Create;
      lExcludes.Add('$(root)ignored');
      lOptions.Add('excludeWorkspaceFolders', lExcludes);

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
    AContext.AssertFalse(lModel.EffectiveFPCOptions.IndexOf('-Fu' +
      IncludeTrailingPathDelimiter(ExpandFileName(lSourceDir))) >= 0,
      'Unit path generation should honor includeWorkspaceFoldersAsUnitPaths=false.');
    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf('-Fi' +
      IncludeTrailingPathDelimiter(ExpandFileName(lSourceDir))) >= 0,
      'Include path generation should honor includeWorkspaceFoldersAsIncludePaths=true.');
    AContext.AssertFalse(lModel.EffectiveWorkspacePaths.IndexOf(
      IncludeTrailingPathDelimiter(ExpandFileName(lExcludedDir))) >= 0,
      'Excluded workspace folders should not be scanned.');
  finally
    lModel.Free;
    lParams.Free;
    if FileExists(lExcludedFile) then
      DeleteFile(lExcludedFile);
    if FileExists(lSourceFile) then
      DeleteFile(lSourceFile);
    RemoveDir(lExcludedDir);
    RemoveDir(lSourceDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestInitializeHonorsProgramConfigAndRootPathFallback(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSInitializeParams;
  lRoot: string;
  lSourceDir: string;
  lFileName: string;
  lRootJSON: TJSONData;
  lOptions: TJSONObject;
  lOptionsJSON: TJSONData;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lSourceDir := IncludeTrailingPathDelimiter(lRoot) + 'src';
  ForceDirectories(lSourceDir);

  lFileName := IncludeTrailingPathDelimiter(lSourceDir) + 'RootPathUnit.pas';
  NXLSWriteTextFile(lFileName, 'unit RootPathUnit; interface implementation end.');

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
      lOptions.Add('codeToolsConfig', '$(root)codetools.config');
      lOptions.Add('includeWorkspaceFoldersAsUnitPaths', True);
      lOptions.Add('includeWorkspaceFoldersAsIncludePaths', False);

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
    AContext.AssertEquals(IncludeTrailingPathDelimiter(ExpandFileName(lRoot)) + 'codetools.config',
      lModel.Settings.CodeToolsConfig, 'codeToolsConfig should parse and expand $(root).');
    AContext.AssertTrue(lModel.EffectiveFPCOptions.IndexOf('-Fu' +
      IncludeTrailingPathDelimiter(ExpandFileName(lSourceDir))) >= 0,
      'Unit path generation should honor includeWorkspaceFoldersAsUnitPaths=true.');
    AContext.AssertFalse(lModel.EffectiveFPCOptions.IndexOf('-Fi' +
      IncludeTrailingPathDelimiter(ExpandFileName(lSourceDir))) >= 0,
      'Include path generation should honor includeWorkspaceFoldersAsIncludePaths=false.');
  finally
    lModel.Free;
    lParams.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lSourceDir);
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
  lSuite.AddTest('InitializeHonorsOptionsMacrosAndExcludes',
    @TestInitializeHonorsOptionsMacrosAndExcludes);
  lSuite.AddTest('InitializeHonorsProgramConfigAndRootPathFallback',
    @TestInitializeHonorsProgramConfigAndRootPathFallback);
end;

end.
