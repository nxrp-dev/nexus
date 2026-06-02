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
  lSuite.AddTest('InitializeHonorsProgramConfigAndRootPathFallback',
    @TestInitializeHonorsProgramConfigAndRootPathFallback);
  lSuite.AddTest('InitializeUsesExplicitLPIProgram',
    @TestInitializeUsesExplicitLPIProgram);
end;

end.
