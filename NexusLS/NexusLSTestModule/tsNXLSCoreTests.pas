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
  obNXFPCBuildOptions,
  obNXLSLSPModel,
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
end;

end.
