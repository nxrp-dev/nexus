(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXBuildTests;

{$mode objfpc}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterNXBuildTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes, SysUtils, TypInfo, obNXTestContext, obNXTestSuite,
  obNXBuildProjectLoader, obNXBuildPlanner, obNXPascalProject,
  obNXFPCBuildOptions, obNexusScriptAnalysis, obNexusScriptLanguageDefinition;

function NXBuildTestDialect: string;
begin
  Result := ExpandFileName('projects/nxbuild/language/nxbuild.Language.nxscript');
end;

function NXBuildTestLoad(const AText: string;
  AWithDialect: Boolean = True): TNXPascalProject;
var
  lFileName: string;
  lSource: TStringList;
  lLoader: TNXBuildProjectLoader;
begin
  lFileName := ExpandFileName('output/nxbuildTests/fixture.nxproject');
  ForceDirectories(ExtractFileDir(lFileName));
  lSource := TStringList.Create;
  lLoader := TNXBuildProjectLoader.Create;
  try
    if AWithDialect then
      lSource.Add('dialect "' + StringReplace(NXBuildTestDialect, '\', '/',
        [rfReplaceAll]) + '";');
    lSource.Add(AText);
    lSource.SaveToFile(lFileName);
    Result := lLoader.LoadProject(lFileName);
  finally
    DeleteFile(lFileName);
    lLoader.Free;
    lSource.Free;
  end;
end;

procedure NXBuildTestReject(AContext: TNXTestContext; const AText: string;
  AWithDialect: Boolean = True);
var
  lProject: TNXPascalProject;
  lError: string;
begin
  lProject := nil;
  lError := '';
  try
    try
      lProject := NXBuildTestLoad(AText, AWithDialect);
    except
      on E: Exception do lError := E.Message;
    end;
  finally
    lProject.Free;
  end;
  AContext.AssertTrue(lError <> '', 'The invalid build script was accepted.');
end;

procedure TestDefaults(AContext: TNXTestContext);
var
  lProject: TNXPascalProject;
begin
  lProject := NXBuildTestLoad('Project Demo {}');
  try
    AContext.AssertEquals('Demo', lProject.Name);
    AContext.AssertEquals(ExpandFileName('output/nxbuildTests/fixture.nxproject'),
      lProject.ProjectFileName);
    AContext.AssertEquals(ExpandFileName('output/nxbuildTests'), lProject.ProjectRoot);
    AContext.AssertEquals(Ord(pbtUnknown), Ord(lProject.BuildTool));
    AContext.AssertEquals(Ord(fssEnabled),
      Ord(lProject.FPCBuildOptions.Syntax.COperators));
  finally
    lProject.Free;
  end;
end;

procedure NXBuildCheckCOperators(AContext: TNXTestContext; const AValue: string;
  AExpected: TNXFPCSwitchState);
var
  lProject: TNXPascalProject;
  lArguments: TStringList;
begin
  lProject := NXBuildTestLoad('Project Demo { FPCBuildOptions Compiler {' +
    ' Syntax Options { COperators: ' + AValue + '; } } }');
  lArguments := TStringList.Create;
  try
    AContext.AssertEquals(Ord(AExpected),
      Ord(lProject.FPCBuildOptions.Syntax.COperators));
    lProject.FPCBuildOptions.AppendArguments(lArguments);
    AContext.AssertEquals(Ord(AExpected = fssEnabled),
      Ord(lArguments.IndexOf('-Sc') >= 0));
    AContext.AssertEquals(Ord(AExpected = fssDisabled),
      Ord(lArguments.IndexOf('-Sc-') >= 0));
  finally
    lArguments.Free;
    lProject.Free;
  end;
end;

procedure TestCOperators(AContext: TNXTestContext);
begin
  NXBuildCheckCOperators(AContext, 'Enabled', fssEnabled);
  NXBuildCheckCOperators(AContext, 'Disabled', fssDisabled);
  NXBuildCheckCOperators(AContext, 'Unset', fssUnset);
end;

procedure TestNativeValues(AContext: TNXTestContext);
var
  lProject: TNXPascalProject;
begin
  lProject := NXBuildTestLoad(
    'Project Demo {' +
    ' Name: "Native Demo"; BuildTool: FPC; ProjectKind: Program;' +
    ' SourceRoot: "src"; OutputRoot: "out";' +
    ' Toolchain Tools { CompilerPath: "my-fpc"; }' +
    ' TargetPlatform Platform { TargetOS: "win64"; ConfigName: "debug"; }' +
    ' FPCBuildOptions Compiler {' +
    '  CompilerPath: "ignored"; RawOptions: ["-d" + @Demo.Platform.ConfigName];' +
    '  Config Options { DisableDefaultConfigFiles: False; }' +
    '  CodeGeneration Checks { RangeChecking: Enabled; MinimumHeapSize: 4096; }' +
    '  Files Paths { UnitPaths: [@Demo.SourceRoot, @Demo.OutputRoot]; }' +
    '  Language Pascal { Mode: ObjFPC; }' +
    '  Optimization Optimize { Level: Level2; OptimizeForSize: Disabled; }' +
    '  Linking Link { StripSymbols: Enabled; LinkerOptions: ["--one", "--two"]; }' +
    ' } }');
  try
    AContext.AssertEquals('Native Demo', lProject.Name);
    AContext.AssertEquals(Ord(pbtFPC), Ord(lProject.BuildTool));
    AContext.AssertEquals(Ord(ppkProgram), Ord(lProject.ProjectKind));
    AContext.AssertEquals('my-fpc', lProject.FPCBuildOptions.CompilerPath);
    AContext.AssertEquals('win64', lProject.FPCBuildOptions.Target.OperatingSystem);
    AContext.AssertFalse(lProject.FPCBuildOptions.Config.DisableDefaultConfigFiles);
    AContext.AssertEquals(Ord(fssEnabled),
      Ord(lProject.FPCBuildOptions.CodeGeneration.RangeChecking));
    AContext.AssertEquals(4096, lProject.FPCBuildOptions.CodeGeneration.MinimumHeapSize);
    AContext.AssertEquals(Ord(flmObjFPC), Ord(lProject.FPCBuildOptions.Language.Mode));
    AContext.AssertEquals(Ord(folLevel2), Ord(lProject.FPCBuildOptions.Optimization.Level));
    AContext.AssertEquals(Ord(fssDisabled),
      Ord(lProject.FPCBuildOptions.Optimization.OptimizeForSize));
    AContext.AssertEquals(2, lProject.FPCBuildOptions.Files.UnitPaths.Count);
    AContext.AssertEquals(lProject.ResolvePath('src'),
      lProject.FPCBuildOptions.Files.UnitPaths[0]);
    AContext.AssertEquals(lProject.ResolvePath('out'),
      lProject.FPCBuildOptions.Files.UnitPaths[1]);
    AContext.AssertEquals('-ddebug', lProject.FPCBuildOptions.RawOptions[0]);
    AContext.AssertEquals('--two', lProject.FPCBuildOptions.Linking.LinkerOptions[1]);
  finally
    lProject.Free;
  end;
end;

procedure TestRelativeCompilerPath(AContext: TNXTestContext);
var
  lProject: TNXPascalProject;
begin
  lProject := NXBuildTestLoad('Project Demo {' +
    ' Toolchain Tools { CompilerPath: "../../tools/my-fpc.exe"; } }');
  try
    AContext.AssertEquals(ExpandFileName('tools/my-fpc.exe'),
      lProject.FPCBuildOptions.CompilerPath);
  finally
    lProject.Free;
  end;
end;

procedure TestBooleanTrue(AContext: TNXTestContext);
var
  lProject: TNXPascalProject;
begin
  lProject := NXBuildTestLoad('Project Demo { FPCBuildOptions Compiler {' +
    ' Config Options { DisableDefaultConfigFiles: True; } } }');
  try
    AContext.AssertTrue(lProject.FPCBuildOptions.Config.DisableDefaultConfigFiles);
  finally
    lProject.Free;
  end;
end;

procedure TestFPCPlan(AContext: TNXTestContext);
var
  lLoader: TNXBuildProjectLoader;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
begin
  lLoader := TNXBuildProjectLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lPlan := lPlanner.CreatePlan(lLoader.LoadProject(
      'projects/nxbuild/examples/Hello.nxproject'));
    try
      AContext.AssertEquals(ExpandFileName('projects/nxbuild/examples'),
        lPlan.WorkingDirectory);
      AContext.AssertTrue(lPlan.Arguments.IndexOf('-Mobjfpc') >= 0);
      AContext.AssertTrue(lPlan.Arguments.IndexOf('-Sc') >= 0);
      AContext.AssertFalse(lPlan.Arguments.IndexOf('-Sc-') >= 0);
      AContext.AssertTrue(lPlan.Arguments.IndexOf('-Cr') >= 0);
      AContext.AssertTrue(lPlan.Arguments.IndexOf('-gl') >= 0);
      AContext.AssertEquals(ExpandFileName('projects/nxbuild/examples/Hello.lpr'),
        lPlan.Arguments[lPlan.Arguments.Count - 1]);
    finally
      lPlan.Free;
    end;
  finally
    lPlanner.Free;
    lLoader.Free;
  end;
end;

procedure TestLazarusPlan(AContext: TNXTestContext);
var
  lProject: TNXPascalProject;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
begin
  lProject := NXBuildTestLoad('Project Demo { BuildTool: Lazarus;' +
    ' BuildFile: "../../projects/nxbuild/examples/Hello.lpi"; }');
  lPlanner := TNXBuildPlanner.Create;
  try
    lPlan := lPlanner.CreatePlan(lProject);
    try
      AContext.AssertEquals(ExpandFileName('projects/nxbuild/examples'),
        lPlan.WorkingDirectory);
      AContext.AssertEquals('--quiet', lPlan.Arguments[0]);
      AContext.AssertEquals(ExpandFileName('projects/nxbuild/examples/Hello.lpi'),
        lPlan.Arguments[1]);
    finally
      lPlan.Free;
    end;
  finally
    lPlanner.Free;
  end;
end;

procedure NXBuildCheckSchema(AContext: TNXTestContext;
  ALanguage: TNexusScriptLanguageDefinition; AObject: TObject; const AKind: string);
var
  lRule: TNSDefinitionRule;
  lPropertyRule: TNSPropertyRule;
  lProperties: PPropList;
  lCount, lIndex, lEnum: Integer;
  lProperty: PPropInfo;
  lObject: TObject;
begin
  lRule := ALanguage.FindDefinitionRule(AKind);
  AContext.AssertTrue(lRule <> nil, 'Missing definition ' + AKind);
  lCount := GetPropList(AObject.ClassInfo, lProperties);
  try
    for lIndex := 0 to lCount - 1 do
    begin
      lProperty := lProperties^[lIndex];
      if lProperty^.PropType^.Kind = tkClass then
      begin
        lObject := GetObjectProp(AObject, lProperty);
        if not (lObject is TStrings) then
        begin
          AContext.AssertTrue(lRule.FindChildRule(lProperty^.Name) <> nil,
            'Missing section ' + AKind + '.' + lProperty^.Name);
          AContext.AssertEquals(1, lRule.FindChildRule(lProperty^.Name).Maximum);
          NXBuildCheckSchema(AContext, ALanguage, lObject, lProperty^.Name);
          Continue;
        end;
      end;
      lPropertyRule := lRule.FindPropertyRule(lProperty^.Name);
      AContext.AssertTrue(lPropertyRule <> nil,
        'Missing property ' + AKind + '.' + lProperty^.Name);
      if lProperty^.PropType^.Kind = tkEnumeration then
        for lEnum := GetTypeData(lProperty^.PropType)^.MinValue to
          GetTypeData(lProperty^.PropType)^.MaxValue do
          AContext.AssertTrue(lPropertyRule.ValueRule.HasAllowedValue(
            Copy(GetEnumName(lProperty^.PropType, lEnum), 4, MaxInt)),
            'Missing enum value ' + GetEnumName(lProperty^.PropType, lEnum));
    end;
  finally
    FreeMem(lProperties);
  end;
end;

procedure TestCompleteSchema(AContext: TNXTestContext);
var
  lAnalysis: TNexusScriptAnalysis;
  lProject: TNXPascalProject;
begin
  lAnalysis := TNexusScriptAnalysis.Create(
    ExpandFileName('projects/nxbuild/examples/Hello.nxproject'), 1, nil);
  lProject := TNXPascalProject.Create;
  try
    lAnalysis.Execute;
    AContext.AssertTrue(lAnalysis.Succeeded, lAnalysis.Session.LastError);
    AContext.AssertEquals(0, lAnalysis.Language.DiagnosticCount);
    AContext.AssertEquals(0, lAnalysis.Validator.Diagnostics.Count);
    NXBuildCheckSchema(AContext, lAnalysis.Language, lProject, 'Project');
  finally
    lProject.Free;
    lAnalysis.Free;
  end;
end;

procedure TestNoJSON(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, '{"Name":"Demo","BuildTool":"pbtFPC"}', False);
end;

procedure TestRequiredDialect(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo {}', False);
end;

procedure TestSingleRoot(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project One {} Project Two {}');
  NXBuildTestReject(AContext, '');
end;

procedure TestUnknownProperty(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo { Typo: "bad"; }');
end;

procedure TestUnknownChild(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo { CopyFile Copy {} }');
end;

procedure TestDuplicateSection(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo {' +
    ' Toolchain First {} Toolchain Second {} }');
end;

procedure TestInvalidEnum(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo { BuildTool: MSBuild; }');
end;

procedure TestInvalidScalar(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo { FPCBuildOptions Compiler {' +
    ' Config Options { DisableDefaultConfigFiles: "banana"; } } }');
  NXBuildTestReject(AContext, 'Project Demo { FPCBuildOptions Compiler {' +
    ' Syntax Checks { ErrorLimit: "not-an-integer"; } } }');
end;

procedure TestInvalidArray(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo { FPCBuildOptions Compiler {' +
    ' RawOptions: [["nested"]]; } }');
  NXBuildTestReject(AContext, 'Project Demo { FPCBuildOptions Compiler {' +
    ' RawOptions: ["named": "-dDebug"]; } }');
end;

procedure TestRemovedVariables(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo { Variables: ["Flavor=debug"]; }');
end;

procedure RegisterNXBuildTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NXBuild');
  lSuite.AddTest('Defaults', @TestDefaults);
  lSuite.AddTest('COperators', @TestCOperators);
  lSuite.AddTest('NativeValues', @TestNativeValues);
  lSuite.AddTest('RelativeCompilerPath', @TestRelativeCompilerPath);
  lSuite.AddTest('BooleanTrue', @TestBooleanTrue);
  lSuite.AddTest('FPCPlan', @TestFPCPlan);
  lSuite.AddTest('LazarusPlan', @TestLazarusPlan);
  lSuite.AddTest('CompleteSchema', @TestCompleteSchema);
  lSuite.AddTest('NoJSON', @TestNoJSON);
  lSuite.AddTest('RequiredDialect', @TestRequiredDialect);
  lSuite.AddTest('SingleRoot', @TestSingleRoot);
  lSuite.AddTest('UnknownProperty', @TestUnknownProperty);
  lSuite.AddTest('UnknownChild', @TestUnknownChild);
  lSuite.AddTest('DuplicateSection', @TestDuplicateSection);
  lSuite.AddTest('InvalidEnum', @TestInvalidEnum);
  lSuite.AddTest('InvalidScalar', @TestInvalidScalar);
  lSuite.AddTest('InvalidArray', @TestInvalidArray);
  lSuite.AddTest('RemovedVariables', @TestRemovedVariables);
end;

end.
