(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXBuildTests;

{$mode objfpc}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterNXBuildTests(ARegistry: TNXTestRegistry);
function NXBuildRunTestTool: Integer;
function NXBuildRunSourceTool: Integer;

implementation

uses
  Classes, SysUtils, TypInfo, obNXTestContext, obNXTestSuite,
  obNXBuildDescriptionLoader, obNXBuildDescription, obNXBuildEntry,
  obNXBuildPlanner, obNXBuildExecutor, obNXFPCBuildOptions,
  obNXLLVMBuildOptions, obNexusScriptAnalysis, obNexusScriptLanguageDefinition, obNexusScriptModel;

function NXBuildQuote(const AValue: string): string;
begin
  Result := '"' + StringReplace(AValue, '\', '/', [rfReplaceAll]) + '"';
end;

function NXBuildTestPath(const ARelativePath: string = ''): string;
begin
  Result := ExcludeTrailingPathDelimiter(ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'fixtures/' + ARelativePath));
end;

function NXBuildTestLoad(const AText: string;
  AWithDialect: Boolean = True; ATargets: TNexusScriptTargetSelection = nil): TNXBuildDescription;
var
  lFileName: string;
  lSource: TStringList;
  lLoader: TNXBuildDescriptionLoader;
begin
  lFileName := NXBuildTestPath('fixture.nxproject');
  ForceDirectories(ExtractFileDir(lFileName));
  lSource := TStringList.Create;
  lLoader := TNXBuildDescriptionLoader.Create;
  try
    if AWithDialect then
      lSource.Add('dialect ' + NXBuildQuote(ExpandFileName(
        'projects/nxbuild/language/nxbuild.Language.nxscript')) + ';');
    lSource.Add(AText);
    lSource.SaveToFile(lFileName);
    Result := lLoader.LoadDescription(lFileName, ATargets);
  finally
    DeleteFile(lFileName);
    lLoader.Free;
    lSource.Free;
  end;
end;

procedure NXBuildTestReject(AContext: TNXTestContext; const AText: string;
  AWithDialect: Boolean = True);
var
  lDescription: TNXBuildDescription;
  lError: string;
begin
  lDescription := nil;
  lError := '';
  try
    try
      lDescription := NXBuildTestLoad(AText, AWithDialect);
    except
      on E: Exception do lError := E.Message;
    end;
  finally
    lDescription.Free;
  end;
  AContext.AssertTrue(lError <> '', 'The invalid build script was accepted.');
end;

function NXBuildTestFolder: string;
var
  lGuid: TGUID;
begin
  CreateGUID(lGuid);
  Result := NXBuildTestPath(GUIDToString(lGuid));
end;

procedure TestDefaults(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lFPC: TNXFPCBuildOptions;
begin
  lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; FPC Pascal {} }');
  try
    AContext.AssertEquals('Demo', lDescription.Name);
    AContext.AssertEquals('Project', lDescription.Kind);
    AContext.AssertEquals(NXBuildTestPath('fixture.nxproject'),
      lDescription.FileName);
    AContext.AssertEquals(NXBuildTestPath, lDescription.RootDirectory);
    AContext.AssertEquals(1, lDescription.Builds.Count);
    lFPC := lDescription.Builds[0] as TNXFPCBuildOptions;
    AContext.AssertEquals('Pascal', lFPC.Name);
    AContext.AssertEquals(lDescription.RootDirectory, lFPC.OutputPath);
    AContext.AssertEquals(Ord(fssEnabled), Ord(lFPC.Syntax.COperators));
  finally
    lDescription.Free;
  end;
end;

procedure TestCOperators(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lFPC: TNXFPCBuildOptions;
  lArguments: TStringList;
  lValue: string;
  lSourceIndex: Integer;
begin
  for lValue in ['Enabled', 'Disabled', 'Unset'] do
  begin
    lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
      ' SourceFiles: ["main.pas"]; Syntax Options { COperators: ' + lValue + '; } } }');
    lArguments := TStringList.Create;
    try
      lFPC := lDescription.Builds[0] as TNXFPCBuildOptions;
      lFPC.AppendArguments(lArguments, lSourceIndex);
      AContext.AssertEquals(Ord(lValue = 'Enabled'), Ord(lArguments.IndexOf('-Sc') >= 0));
      AContext.AssertEquals(Ord(lValue = 'Disabled'), Ord(lArguments.IndexOf('-Sc-') >= 0));
    finally
      lArguments.Free;
      lDescription.Free;
    end;
  end;
end;

procedure TestNativeValues(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lFPC: TNXFPCBuildOptions;
begin
  lDescription := NXBuildTestLoad(
    'Project Demo { Id: "Tests.Demo"; Name: "Native Demo"; SourceRoot: "src"; OutputRoot: "out";' +
    ' FPC Pascal { CompilerPath: "my-fpc"; SourceFiles: [@Demo.SourceRoot + "/main.pas"];' +
    ' RawOptions: ["-d" + "debug"];' +
    ' Target Platform { OperatingSystem: "win64"; }' +
    ' Config Options { DisableDefaultConfigFiles: False; }' +
    ' CodeGeneration Checks { RangeChecking: Enabled; MinimumHeapSize: 4096; }' +
    ' Files Paths { UnitPaths: [@Demo.SourceRoot, @Demo.OutputRoot]; }' +
    ' Language Pascal { Mode: ObjFPC; }' +
    ' Optimization Optimize { Level: Level2; OptimizeForSize: Disabled; }' +
    ' Linking Link { StripSymbols: Enabled; LinkerOptions: ["--one", "--two"]; }' +
    ' } }');
  try
    lFPC := lDescription.Builds[0] as TNXFPCBuildOptions;
    AContext.AssertEquals('Native Demo', lDescription.Name);
    AContext.AssertEquals('my-fpc', lFPC.CompilerPath);
    AContext.AssertEquals(lDescription.ResolvePath('src/main.pas'), lFPC.SourceFiles[0]);
    AContext.AssertEquals('win64', lFPC.Target.OperatingSystem);
    AContext.AssertFalse(lFPC.Config.DisableDefaultConfigFiles);
    AContext.AssertEquals(Ord(fssEnabled), Ord(lFPC.CodeGeneration.RangeChecking));
    AContext.AssertEquals(4096, lFPC.CodeGeneration.MinimumHeapSize);
    AContext.AssertEquals(Ord(flmObjFPC), Ord(lFPC.Language.Mode));
    AContext.AssertEquals(Ord(folLevel2), Ord(lFPC.Optimization.Level));
    AContext.AssertEquals(Ord(fssDisabled), Ord(lFPC.Optimization.OptimizeForSize));
    AContext.AssertEquals(2, lFPC.Files.UnitPaths.Count);
    AContext.AssertEquals(lDescription.ResolvePath('src'), lFPC.Files.UnitPaths[0]);
    AContext.AssertEquals(lDescription.ResolvePath('out'), lFPC.Files.UnitPaths[1]);
    AContext.AssertEquals('-ddebug', lFPC.RawOptions[0]);
    AContext.AssertEquals('--two', lFPC.Linking.LinkerOptions[1]);
  finally
    lDescription.Free;
  end;
end;

procedure TestOrderedBuilds(AContext: TNXTestContext);
const
  cSources: array[0..2] of string = ('first.pas', 'second file.pas', 'first.pas');
var
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lStep: TNXBuildStep;
  lArguments: TStringList;
  lKind: string;
  lIndex: Integer;
begin
  for lKind in ['Project'] do
  begin
    lDescription := NXBuildTestLoad(lKind + ' Demo { Id: "Tests.Demo";' +
      ' LLVM First { Language: C; SourceFiles: ["missing.c"]; }' +
      ' FPC Second { SourceFiles: ["first.pas", "second file.pas", "first.pas"];' +
      ' OutputPath: "pascal output"; RawOptions: ["-dORDERED"]; }' +
      ' LLVM Third { Language: CPP; SourceFiles: ["missing.cpp", "also missing.cpp"];' +
      ' Libraries: ["support"]; }' +
      ' FPC Fourth { SourceFiles: ["also-missing.pas"]; } }');
    lPlanner := TNXBuildPlanner.Create;
    lArguments := TStringList.Create;
    try
      AContext.AssertEquals(lKind, lDescription.Kind);
      AContext.AssertEquals(4, lDescription.Builds.Count);
      for lIndex := 0 to 3 do
        (lDescription.Builds[lIndex] as TNXBuildEntry).CompilerPath := ParamStr(0);
      lPlan := lPlanner.CreatePlan(lDescription);
      try
        AContext.AssertEquals(4, lPlan.Steps.Count);
        AContext.AssertEquals('First', lPlan.Steps[0].Name);
        AContext.AssertEquals('LLVM', lPlan.Steps[0].BuildType);
        AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('c') >= 0);
        lStep := lPlan.Steps[1];
        AContext.AssertEquals('Second', lStep.Name);
        AContext.AssertEquals('FPC', lStep.BuildType);
        AContext.AssertTrue(lStep.CompileEachSource);
        AContext.AssertEquals(ExpandFileName(ParamStr(0)), lStep.Executable);
        AContext.AssertEquals(lDescription.ResolvePath('pascal output'), lStep.OutputPath);
        AContext.AssertEquals(3, lStep.SourceFiles.Count);
        for lIndex := 0 to 2 do
        begin
          AContext.AssertEquals(lDescription.ResolvePath(cSources[lIndex]), lStep.SourceFiles[lIndex]);
          lStep.FillArguments(lStep.SourceFiles, lIndex, lArguments);
          AContext.AssertEquals(lStep.Arguments.Count + 1, lArguments.Count);
          AContext.AssertTrue(lArguments.IndexOf('-dORDERED') >= 0);
          AContext.AssertEquals(lDescription.ResolvePath(cSources[lIndex]), lArguments[lArguments.Count - 1]);
        end;
        lStep := lPlan.Steps[2];
        AContext.AssertEquals('Third', lStep.Name);
        AContext.AssertEquals('LLVM', lStep.BuildType);
        AContext.AssertFalse(lStep.CompileEachSource);
        lStep.FillArguments(lStep.SourceFiles, 0, lArguments);
        AContext.AssertTrue(lArguments.IndexOf('c++') >= 0);
        AContext.AssertEquals(lDescription.ResolvePath('missing.cpp'), lArguments[lArguments.Count - 3]);
        AContext.AssertEquals(lDescription.ResolvePath('also missing.cpp'), lArguments[lArguments.Count - 2]);
        AContext.AssertEquals('-lsupport', lArguments[lArguments.Count - 1]);
        lStep := lPlan.Steps[3];
        AContext.AssertEquals('Fourth', lStep.Name);
        AContext.AssertEquals('FPC', lStep.BuildType);
        // The plan owns its source selections and arguments after loading ends.
        FreeAndNil(lDescription);
        lStep.FillArguments(lStep.SourceFiles, 0, lArguments);
        AContext.AssertEquals(lStep.SourceFiles[0], lArguments[lArguments.Count - 1]);
      finally
        lPlan.Free;
      end;
    finally
      lArguments.Free;
      lPlanner.Free;
      lDescription.Free;
    end;
  end;
end;

procedure TestLLVMOptions(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lLLVM: TNXLLVMBuildOptions;
  lArguments: TStringList;
  lSourceIndex: Integer;
begin
  lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; LLVM Native {' +
    ' Language: CPP; BuildKind: SharedLibrary; Target: "x86_64-w64-windows-gnu";' +
    ' ConfigFiles: ["config files/base.cfg", "config files/library.cfg"];' +
    ' Standard: "c++17"; DebugInfo: True; PositionIndependentCode: True;' +
    ' RawOptions: ["-O2", "-fno-stack-protector"]; SourceFiles: ["one file.cpp", "two.cpp"]; OutputPath: "out directory";' +
    ' IncludePaths: ["headers"]; SystemIncludePaths: ["sdk headers", "other sdk"]; Defines: ["VALUE=2"];' +
    ' LibraryPaths: ["libs"]; Libraries: ["support"]; } }');
  lArguments := TStringList.Create;
  try
    lLLVM := lDescription.Builds[0] as TNXLLVMBuildOptions;
    AContext.AssertEquals(2, lLLVM.RawOptions.Count);
    AContext.AssertEquals('clang++', lLLVM.DefaultCompiler);
    lLLVM.AppendArguments(lArguments, lSourceIndex);
    AContext.AssertEquals(2, lLLVM.ConfigFiles.Count);
    AContext.AssertEquals(lDescription.ResolvePath('config files/base.cfg'), lLLVM.ConfigFiles[0]);
    AContext.AssertEquals('--config=' + lDescription.ResolvePath('config files/base.cfg'), lArguments[0]);
    AContext.AssertEquals('--config=' + lDescription.ResolvePath('config files/library.cfg'), lArguments[1]);
    AContext.AssertTrue(lArguments.IndexOf('-shared') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-std=c++17') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('--target=x86_64-w64-windows-gnu') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-g') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-fPIC') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-DVALUE=2') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-I' + lDescription.ResolvePath('headers')) >= 0);
    AContext.AssertEquals(2, lLLVM.SystemIncludePaths.Count);
    AContext.AssertEquals(lDescription.ResolvePath('sdk headers'), lLLVM.SystemIncludePaths[0]);
    AContext.AssertEquals(lDescription.ResolvePath('sdk headers'),
      lArguments[lArguments.IndexOf('-isystem') + 1]);
    AContext.AssertEquals('-isystem', lArguments[lArguments.IndexOf('-isystem') + 2]);
    AContext.AssertEquals(lDescription.ResolvePath('other sdk'),
      lArguments[lArguments.IndexOf('-isystem') + 3]);
    AContext.AssertTrue(lArguments.IndexOf('-L' + lDescription.ResolvePath('libs')) >= 0);
    AContext.AssertEquals('-O2', lArguments[lSourceIndex - 2]);
    AContext.AssertEquals('-fno-stack-protector', lArguments[lSourceIndex - 1]);
    AContext.AssertEquals('-lsupport', lArguments[lSourceIndex]);
    AContext.AssertEquals('-lsupport', lArguments[lArguments.Count - 1]);
    AContext.AssertEquals(lDescription.ResolvePath('out directory'), lLLVM.OutputPath);
    AContext.AssertEquals(-1, lArguments.IndexOf('-o'));
  finally
    lArguments.Free;
    lDescription.Free;
  end;
end;

procedure TestResolvePaths(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lFPC: TNXFPCBuildOptions;
  lAbsolute: string;
begin
  lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; RootDirectory: "path root";' +
    ' FPC Pascal { CompilerPath: "../tools/compiler.exe";' +
    ' SourceFiles: ["../source.pas"]; Config Options { OptionFiles: ["settings.cfg"]; }' +
    ' OutputPath: "units"; Files Paths { ObjectPaths: ["objects"]; } } }');
  try
    lFPC := lDescription.Builds[0] as TNXFPCBuildOptions;
    AContext.AssertEquals(NXBuildTestPath('path root'), lDescription.RootDirectory);
    AContext.AssertEquals(NXBuildTestPath('tools/compiler.exe'), lFPC.CompilerPath);
    AContext.AssertEquals(NXBuildTestPath('source.pas'), lFPC.SourceFiles[0]);
    AContext.AssertEquals(lDescription.ResolvePath('settings.cfg'), lFPC.Config.OptionFiles[0]);
    AContext.AssertEquals(lDescription.ResolvePath('units'), lFPC.OutputPath);
    AContext.AssertEquals(lDescription.ResolvePath('objects'), lFPC.Files.ObjectPaths[0]);
    AContext.AssertEquals('', lDescription.ResolvePath(''));
    lAbsolute := ExpandFileName('../nexus-lab/examples/build/native/Hello.lpr');
    AContext.AssertEquals(lAbsolute, lDescription.ResolvePath(lAbsolute));
    {$IFDEF MSWINDOWS}
    AContext.AssertEquals('D:\sources\main.pas', lDescription.ResolvePath('D:\sources\main.pas'));
    AContext.AssertEquals('\\server\share\main.pas', lDescription.ResolvePath('\\server\share\main.pas'));
    {$ENDIF}
  finally
    lDescription.Free;
  end;
end;

procedure TestOutputPaths(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lRoot, lDestination: string;
  lKind: string;
  lIndex: Integer;
begin
  lRoot := NXBuildTestFolder;
  lDestination := NXBuildTestFolder;
  for lKind in ['Project'] do
  begin
    lDescription := NXBuildTestLoad(lKind + ' Demo { Id: "Tests.Demo"; RootDirectory: ' +
      NXBuildQuote(lRoot) + '; OutputRoot: "reference only";' +
      ' FPC Pascal { OutputPath: "pascal files"; }' +
      ' LLVM Native { OutputPath: ' + NXBuildQuote(lDestination) + '; }' +
      ' FPC DefaultPascal {} LLVM DefaultNative {} }');
    lPlanner := TNXBuildPlanner.Create;
    try
      for lIndex := 0 to lDescription.Builds.Count - 1 do
      begin
        (lDescription.Builds[lIndex] as TNXBuildEntry).CompilerPath := ParamStr(0);
        (lDescription.Builds[lIndex] as TNXBuildEntry).SourceFiles.Add(
          lDescription.ResolvePath('not-created-yet.pas'));
      end;
      lPlan := lPlanner.CreatePlan(lDescription);
      try
        AContext.AssertEquals(lDescription.ResolvePath('pascal files'),
          lPlan.Steps[0].OutputPath);
        AContext.AssertEquals(lDestination, lPlan.Steps[1].OutputPath);
        AContext.AssertEquals(lRoot, lPlan.Steps[2].OutputPath);
        AContext.AssertEquals(lRoot, lPlan.Steps[3].OutputPath);
        AContext.AssertFalse(DirectoryExists(lRoot));
        AContext.AssertFalse(DirectoryExists(lDestination));
      finally
        lPlan.Free;
      end;
    finally
      lPlanner.Free;
      lDescription.Free;
    end;
  end;
end;

procedure TestPlanningBoundary(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan, lSecondPlan: TNXBuildPlan;
  lFolder, lError: string;
  lFPC: TNXFPCBuildOptions;
begin
  lFolder := NXBuildTestFolder;
  lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; OutputRoot: ' + NXBuildQuote(lFolder) + ';' +
    ' FPC Pascal { CompilerPath: ' + NXBuildQuote(ParamStr(0)) + ';' +
    ' SourceFiles: ["not-created-yet.pas", @Demo.OutputRoot + "/generated/*.pas"]; OutputPath: @Demo.OutputRoot; } }');
  lPlanner := TNXBuildPlanner.Create;
  try
    lPlan := lPlanner.CreatePlan(lDescription);
    try
      AContext.AssertFalse(DirectoryExists(lFolder), 'Planning created output directories.');
      AContext.AssertEquals(lFolder, lPlan.Steps[0].OutputPath);
      AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-FE' + lFolder) >= 0);
      AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-FU' + lFolder) >= 0);
      AContext.AssertEquals(ExpandFileName(ParamStr(0)), lPlan.Steps[0].Executable);
      AContext.AssertEquals(lDescription.ResolvePath('not-created-yet.pas'), lPlan.Steps[0].SourceFiles[0]);
      AContext.AssertEquals(lDescription.ResolvePath(lFolder + '/generated/*.pas'), lPlan.Steps[0].SourceFiles[1]);
      lSecondPlan := lPlanner.CreatePlan(lDescription);
      try
        AContext.AssertEquals(lPlan.Steps[0].Arguments.Text,
          lSecondPlan.Steps[0].Arguments.Text);
        AContext.AssertEquals(lPlan.Steps[0].SourceFiles.Text, lSecondPlan.Steps[0].SourceFiles.Text);
      finally
        lSecondPlan.Free;
      end;
    finally
      lPlan.Free;
    end;
    lFPC := lDescription.Builds[0] as TNXFPCBuildOptions;
    lFPC.CompilerPath := lFolder + '/missing-compiler';
    lError := '';
    try
      lPlan := lPlanner.CreatePlan(lDescription);
      lPlan.Free;
    except
      on E: Exception do lError := E.Message;
    end;
    AContext.AssertTrue(Pos('Pascal', lError) > 0);
    AContext.AssertTrue(Pos('tool not found', lError) > 0);
    AContext.AssertFalse(DirectoryExists(lFolder));
  finally
    lPlanner.Free;
    lDescription.Free;
  end;
end;

procedure TestEmptySources(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lKind, lSources, lError, lFolder: string;
begin
  lFolder := NXBuildTestFolder;
  for lKind in ['FPC', 'LLVM'] do
    for lSources in ['', 'SourceFiles: [];'] do
    begin
      lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; ' + lKind + ' Empty {' +
        ' CompilerPath: ' + NXBuildQuote(ParamStr(0)) + ';' +
        ' OutputPath: ' + NXBuildQuote(lFolder) + '; ' + lSources + ' } }');
      lPlanner := TNXBuildPlanner.Create;
      try
        lError := '';
        try
          lPlan := lPlanner.CreatePlan(lDescription);
          lPlan.Free;
        except
          on E: Exception do lError := E.Message;
        end;
        AContext.AssertTrue(Pos('Empty', lError) > 0);
        AContext.AssertTrue(Pos(lKind, lError) > 0);
        AContext.AssertTrue(Pos('SourceFiles must contain at least one file', lError) > 0);
        AContext.AssertFalse(DirectoryExists(lFolder));
      finally
        lPlanner.Free;
        lDescription.Free;
      end;
    end;
end;

procedure TestEmptyPlan(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
begin
  lDescription := NXBuildTestLoad('Project Empty { Id: "Tests.Empty"; }');
  lPlanner := TNXBuildPlanner.Create;
  try
    lPlan := lPlanner.CreatePlan(lDescription);
    try
      AContext.AssertEquals(0, lPlan.Steps.Count);
      AContext.AssertEquals(1, lPlan.Projects.Count);
    finally
      lPlan.Free;
    end;
  finally
    lPlanner.Free;
    lDescription.Free;
  end;
end;

function NXBuildRunTestTool: Integer;
var
  lLog: TStringList;
begin
  lLog := TStringList.Create;
  try
    if GetCurrentDir <> ExtractFileDir(ParamStr(2)) then Exit(98);
    if FileExists(ParamStr(2)) then lLog.LoadFromFile(ParamStr(2));
    if lLog.Count <> StrToInt(ParamStr(5)) then Exit(99);
    lLog.Add(ParamStr(3));
    lLog.SaveToFile(ParamStr(2));
    Result := StrToInt(ParamStr(4));
  finally
    lLog.Free;
  end;
end;

procedure NXBuildCheckExecution(AContext: TNXTestContext; AFail: Boolean);
var
  lPlan: TNXBuildPlan;
  lExecutor: TNXBuildExecutor;
  lStep: TNXBuildStep;
  lLog: TStringList;
  lFolder, lLogFile: string;
  lIndex, lExitCode: Integer;
begin
  lFolder := NXBuildTestFolder;
  lLogFile := IncludeTrailingPathDelimiter(lFolder) + 'execution log.txt';
  lPlan := TNXBuildPlan.Create;
  lExecutor := TNXBuildExecutor.Create;
  lLog := TStringList.Create;
  try
    for lIndex := 0 to 2 do
    begin
      lStep := TNXBuildStep.Create;
      lPlan.Steps.Add(lStep);
      lStep.Name := 'Step' + IntToStr(lIndex);
      if lIndex = 1 then lStep.BuildType := 'FPC' else lStep.BuildType := 'LLVM';
      lStep.Executable := ExpandFileName(ParamStr(0));
      lStep.OutputPath := lFolder;
      lStep.Arguments.Add('--nxbuild-test-tool');
      lStep.Arguments.Add(lLogFile);
      lStep.Arguments.Add(lStep.Name);
      if AFail and (lIndex = 1) then lExitCode := 23 else lExitCode := 0;
      lStep.Arguments.Add(IntToStr(lExitCode));
      lStep.Arguments.Add(IntToStr(lIndex));
      lStep.SourceArgumentIndex := lStep.Arguments.Count;
      lStep.SourceFiles.Add('source.pas');
    end;
    lExitCode := lExecutor.Execute(lPlan);
    if AFail then AContext.AssertEquals(23, lExitCode) else AContext.AssertEquals(0, lExitCode);
    lLog.LoadFromFile(lLogFile);
    if AFail then AContext.AssertEquals(2, lLog.Count) else AContext.AssertEquals(3, lLog.Count);
    for lIndex := 0 to lLog.Count - 1 do
      AContext.AssertEquals('Step' + IntToStr(lIndex), lLog[lIndex]);
  finally
    lLog.Free;
    lExecutor.Free;
    lPlan.Free;
    DeleteFile(lLogFile);
    RemoveDir(lFolder);
  end;
end;

procedure TestExecutionOrder(AContext: TNXTestContext);
begin
  NXBuildCheckExecution(AContext, False);
end;

procedure TestExecutionFailure(AContext: TNXTestContext);
begin
  NXBuildCheckExecution(AContext, True);
end;
procedure TestSourceMasks(AContext: TNXTestContext);
var
  lSources, lExpanded, lFile: TStringList;
  lFolder, lName, lError: string;
begin
  lFolder := IncludeTrailingPathDelimiter(NXBuildTestFolder);
  lSources := TStringList.Create;
  lExpanded := TStringList.Create;
  lFile := TStringList.Create;
  try
    ForceDirectories(lFolder + 'nested.c');
    for lName in ['z.c', 'a file.c', 'item1.cpp', 'ignore.h', 'nested.c/inside.c'] do
      lFile.SaveToFile(lFolder + lName);
    lSources.Add(lFolder + 'z.c');
    lSources.Add(lFolder + '*.c');
    lSources.Add(lFolder + 'z.c');
    lSources.Add(lFolder + 'item?.cpp');
    TNXBuildEntry.ExpandSourceFiles(lSources, lExpanded);
    AContext.AssertEquals(5, lExpanded.Count);
    AContext.AssertEquals(lFolder + 'z.c', lExpanded[0]);
    AContext.AssertEquals(lFolder + 'z.c', lExpanded[3]);
    AContext.AssertEquals(lFolder + 'item1.cpp', lExpanded[4]);
    AContext.AssertTrue(lExpanded[1] <> lExpanded[2]);
    for lName in [lExpanded[1], lExpanded[2]] do
      AContext.AssertTrue((lName = lFolder + 'z.c') or (lName = lFolder + 'a file.c'));
    // Literal inputs still go to the compiler, even if they do not exist yet.
    lSources.Clear;
    lSources.Add(lFolder + 'missing.pas');
    TNXBuildEntry.ExpandSourceFiles(lSources, lExpanded);
    AContext.AssertEquals(lSources.Text, lExpanded.Text);
    for lName in ['*.missing', 'absent/*.c', 'nested*/*.c'] do
    begin
      lSources[0] := lFolder + lName;
      lError := '';
      try
        TNXBuildEntry.ExpandSourceFiles(lSources, lExpanded);
      except
        on E: Exception do lError := E.Message;
      end;
      AContext.AssertTrue(Pos(lSources[0], lError) > 0, 'Mask error must identify the selection.');
    end;
  finally
    lFile.Free;
    lExpanded.Free;
    lSources.Free;
    for lName in ['z.c', 'a file.c', 'item1.cpp', 'ignore.h', 'nested.c/inside.c'] do
      DeleteFile(lFolder + lName);
    RemoveDir(lFolder + 'nested.c');
    RemoveDir(lFolder);
  end;
end;

function NXBuildRunSourceTool: Integer;
var
  lLog, lFile: TStringList;
  lIndex: Integer;
  lLine: string;
begin
  lLog := TStringList.Create;
  lFile := TStringList.Create;
  try
    if ParamStr(ParamCount) <> '--tail' then Exit(97);
    if FileExists(ParamStr(2)) then lLog.LoadFromFile(ParamStr(2));
    lLine := ParamStr(3);
    Result := 0;
    for lIndex := 6 to ParamCount - 1 do
    begin
      if not FileExists(ParamStr(lIndex)) then Exit(98);
      lLine := lLine + '|' + ParamStr(lIndex);
      if ParamStr(lIndex) = ParamStr(5) then Result := 37;
    end;
    if ParamStr(4) <> '-' then lFile.SaveToFile(ParamStr(4));
    lLog.Add(lLine);
    lLog.SaveToFile(ParamStr(2));
  finally
    lFile.Free;
    lLog.Free;
  end;
end;

procedure TestSourceMaskExecution(AContext: TNXTestContext);
var
  lPlan: TNXBuildPlan;
  lStep: TNXBuildStep;
  lExecutor: TNXBuildExecutor;
  lLog, lFile: TStringList;
  lFolder, lFirst, lGenerated, lLogFile, lError: string;
  lIndex: Integer;
begin
  lFolder := NXBuildTestFolder;
  lFirst := IncludeTrailingPathDelimiter(lFolder) + 'first.pas';
  lGenerated := IncludeTrailingPathDelimiter(lFolder) + 'generated file.pas';
  lLogFile := IncludeTrailingPathDelimiter(lFolder) + 'execution.log';
  lPlan := TNXBuildPlan.Create;
  lExecutor := TNXBuildExecutor.Create;
  lLog := TStringList.Create;
  lFile := TStringList.Create;
  try
    for lIndex := 0 to 2 do
    begin
      lStep := TNXBuildStep.Create;
      lPlan.Steps.Add(lStep);
      lStep.Name := 'Step' + IntToStr(lIndex);
      lStep.CompileEachSource := lIndex = 1;
      if lStep.CompileEachSource then lStep.BuildType := 'FPC' else lStep.BuildType := 'LLVM';
      lStep.Executable := ExpandFileName(ParamStr(0));
      lStep.OutputPath := lFolder;
      lStep.Arguments.Add('--nxbuild-source-tool');
      lStep.Arguments.Add(lLogFile);
      lStep.Arguments.Add(lStep.Name);
      if lIndex = 0 then lStep.Arguments.Add(lGenerated) else lStep.Arguments.Add('-');
      lStep.Arguments.Add('-');
      lStep.SourceArgumentIndex := lStep.Arguments.Count;
      lStep.Arguments.Add('--tail');
      if lIndex = 0 then
        lStep.SourceFiles.Add(lFirst)
      else
      begin
        lStep.SourceFiles.Add(IncludeTrailingPathDelimiter(lFolder) + '*.pas');
        lStep.SourceFiles.Add(lFirst);
      end;
    end;
    // Files may appear after planning and in an earlier build entry.
    ForceDirectories(lFolder);
    lFile.SaveToFile(lFirst);
    AContext.AssertFalse(FileExists(lGenerated));
    AContext.AssertEquals(0, lExecutor.Execute(lPlan));
    lLog.LoadFromFile(lLogFile);
    AContext.AssertEquals(5, lLog.Count);
    AContext.AssertEquals('Step0|' + lFirst, lLog[0]);
    AContext.AssertTrue(lLog[1] <> lLog[2]);
    AContext.AssertTrue(lLog.IndexOf('Step1|' + lGenerated) >= 1);
    AContext.AssertEquals('Step1|' + lFirst, lLog[3]);
    AContext.AssertEquals('Step2' + Copy(lLog[1], 6, MaxInt) +
      Copy(lLog[2], 6, MaxInt) + '|' + lFirst, lLog[4]);
    AContext.AssertEquals(2, lPlan.Steps[1].SourceFiles.Count);
    AContext.AssertEquals(IncludeTrailingPathDelimiter(lFolder) + '*.pas', lPlan.Steps[1].SourceFiles[0]);
    // A failing FPC source stops the remaining sources and the following entry.
    DeleteFile(lLogFile);
    lPlan.Steps.Delete(0);
    lStep := lPlan.Steps[0];
    lStep.SourceFiles.Clear;
    lStep.SourceFiles.Add(lGenerated);
    lStep.SourceFiles.Add(lFirst);
    lStep.SourceFiles.Add(lGenerated);
    lStep.Arguments[4] := lFirst;
    AContext.AssertEquals(37, lExecutor.Execute(lPlan));
    lLog.LoadFromFile(lLogFile);
    AContext.AssertEquals(2, lLog.Count);
    AContext.AssertEquals('Step1|' + lGenerated, lLog[0]);
    AContext.AssertEquals('Step1|' + lFirst, lLog[1]);
    // An empty mask fails before launching this or any subsequent entry.
    DeleteFile(lLogFile);
    lStep.SourceFiles.Clear;
    lStep.SourceFiles.Add(IncludeTrailingPathDelimiter(lFolder) + '*.missing');
    lError := '';
    try
      lExecutor.Execute(lPlan);
    except
      on E: Exception do lError := E.Message;
    end;
    AContext.AssertTrue(Pos('Build "Step1" (FPC)', lError) > 0);
    AContext.AssertTrue(Pos('Source mask matched no files:', lError) > 0);
    AContext.AssertFalse(FileExists(lLogFile));
  finally
    lFile.Free;
    lLog.Free;
    lExecutor.Free;
    lPlan.Free;
    DeleteFile(lLogFile);
    DeleteFile(lGenerated);
    DeleteFile(lFirst);
    RemoveDir(lFolder);
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
  lTargets: TNexusScriptTargetSelection;
  lFPC: TNXFPCBuildOptions;
  lLLVM: TNXLLVMBuildOptions;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('TargetOS', 'linux');
  lTargets.Add('TargetCPU', 'x86_64');
  lAnalysis := TNexusScriptAnalysis.Create(
    ExpandFileName('../nexus-lab/examples/build/native/Mixed.nxproject'), 1, nil, lTargets);
  lTargets.Free;
  lFPC := TNXFPCBuildOptions.Create;
  lLLVM := TNXLLVMBuildOptions.Create;
  try
    lAnalysis.Execute;
    AContext.AssertTrue(lAnalysis.Succeeded, lAnalysis.Session.LastError);
    AContext.AssertEquals(0, lAnalysis.Language.DiagnosticCount);
    AContext.AssertEquals(0, lAnalysis.Validator.Diagnostics.Count);
    NXBuildCheckSchema(AContext, lAnalysis.Language, lFPC, 'FPC');
    NXBuildCheckSchema(AContext, lAnalysis.Language, lLLVM, 'LLVM');
  finally
    lLLVM.Free;
    lFPC.Free;
    lAnalysis.Free;
  end;
end;

procedure TestSharedEnvironmentModule(AContext: TNXTestContext);
var
  lModule: TStringList;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lLLVM: TNXLLVMBuildOptions;
  lFPC: TNXFPCBuildOptions;
  lFolder, lModuleFile, lSDKPath, lVersion, lKind, lText: string;
begin
  lFolder := NXBuildTestFolder;
  lModuleFile := IncludeTrailingPathDelimiter(lFolder) + 'environment.nxscript';
  lModule := TStringList.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    ForceDirectories(lFolder);
    for lVersion in ['first installation', 'second installation'] do
    begin
      lSDKPath := IncludeTrailingPathDelimiter(lFolder) + lVersion;
      lModule.Text := 'Environment Shared { SDK Kit { Path: ' + NXBuildQuote(lSDKPath) + ';' +
        ' IncludePaths: [@Shared.Kit.Path + "/headers", @Shared.Kit.Path + "/runtime"];' +
        ' LibraryPaths: [@Shared.Kit.Path + "/lib"]; }' +
        ' Toolchain Compiler { CompilerPath: ' + NXBuildQuote(ParamStr(0)) + ';' +
        ' SystemIncludePaths: @Shared.Kit.IncludePaths;' +
        ' LibraryPaths: @Shared.Kit.LibraryPaths; } }';
      lModule.SaveToFile(lModuleFile);
      for lKind in ['Project'] do
      begin
        lText := 'module ' + NXBuildQuote(lModuleFile) + '; ' + lKind + ' Demo { Id: "Tests.Demo";' +
          ' LLVM Native { CompilerPath: @Shared.Compiler.CompilerPath;' +
          ' SourceFiles: ["native.c"]; SystemIncludePaths: @Shared.Compiler.SystemIncludePaths;' +
          ' LibraryPaths: @Shared.Compiler.LibraryPaths; }' +
          ' FPC Pascal { CompilerPath: @Shared.Compiler.CompilerPath; SourceFiles: ["main.pas"];' +
          ' Files Paths { LibraryPaths: @Shared.Kit.LibraryPaths; } } }';
        lDescription := NXBuildTestLoad(lText);
        try
          AContext.AssertEquals('Demo', lDescription.Name);
          AContext.AssertEquals(2, lDescription.Builds.Count);
          lLLVM := lDescription.Builds[0] as TNXLLVMBuildOptions;
          lFPC := lDescription.Builds[1] as TNXFPCBuildOptions;
          AContext.AssertEquals(2, lLLVM.SystemIncludePaths.Count);
          AContext.AssertEquals(ExpandFileName(lSDKPath + '/headers'), lLLVM.SystemIncludePaths[0]);
          AContext.AssertEquals(ExpandFileName(lSDKPath + '/runtime'), lLLVM.SystemIncludePaths[1]);
          AContext.AssertEquals(ExpandFileName(lSDKPath + '/lib'), lLLVM.LibraryPaths[0]);
          AContext.AssertEquals(lLLVM.LibraryPaths.Text, lFPC.Files.LibraryPaths.Text);
          lPlan := lPlanner.CreatePlan(lDescription);
          try
            AContext.AssertEquals(2, lPlan.Steps.Count, 'Module definitions must not become builds.');
            AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-L' + lLLVM.LibraryPaths[0]) >= 0);
            AContext.AssertTrue(lPlan.Steps[1].Arguments.IndexOf('-Fl' + lFPC.Files.LibraryPaths[0]) >= 0);
          finally
            lPlan.Free;
          end;
        finally
          lDescription.Free;
        end;
      end;
    end;
    DeleteFile(lModuleFile);
    NXBuildTestReject(AContext, lText);
    lModule.Text := 'SDK SharedSDK { Path: @Missing.Path; }';
    lModule.SaveToFile(lModuleFile);
    NXBuildTestReject(AContext, lText);
  finally
    lPlanner.Free;
    lModule.Free;
    DeleteFile(lModuleFile);
    RemoveDir(lFolder);
  end;
end;

procedure TestTargetSelection(AContext: TNXTestContext);
var
  lModule: TStringList;
  lTargets: TNexusScriptTargetSelection;
  lDescription: TNXBuildDescription;
  lPlanner: TNXBuildPlanner;
  lPlan: TNXBuildPlan;
  lFPC: TNXFPCBuildOptions;
  lFolder, lModuleFile, lOS, lCPU, lText: string;
begin
  lFolder := NXBuildTestFolder;
  lModuleFile := IncludeTrailingPathDelimiter(lFolder) + 'environment.nxscript';
  lModule := TStringList.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    ForceDirectories(lFolder);
    lModule.Text := 'Environment Tools {' +
      ' Platform Native TargetOS[win64] { Directory: "windows"; }' +
      ' Platform Native TargetOS[linux] { Directory: "linux"; }' +
      ' Platform CPU TargetCPU[x86_64] { Directory: "x64"; }' +
      ' Platform CPU TargetCPU[aarch64] { Directory: "arm64"; } }';
    lModule.SaveToFile(lModuleFile);
    lText := 'module ' + NXBuildQuote(lModuleFile) + '; Project Demo { Id: "Tests.Demo";' +
      ' LLVM First { CompilerPath: ' + NXBuildQuote(ParamStr(0)) + '; SourceFiles: ["native.c"]; }' +
      ' FPC Unsupported TargetOS[darwin] { CompilerPath: "missing-tool"; SourceFiles: ["unused.pas"]; }' +
      ' FPC Pascal { CompilerPath: ' + NXBuildQuote(ParamStr(0)) + '; SourceFiles: ["main.pas"];' +
      ' OutputPath: @Tools.Native.Directory + "/" + @Tools.CPU.Directory;' +
      ' Files Paths TargetOS[win64] { IncludePaths: ["windows-headers"]; }' +
      ' Files Paths TargetOS[linux] { IncludePaths: ["linux-headers"]; } } }';
    for lOS in ['win64', 'linux'] do
      for lCPU in ['x86_64', 'aarch64'] do
      begin
        lTargets := TNexusScriptTargetSelection.Create;
        try
          lTargets.Add('TargetOS', lOS);
          lTargets.Add('TargetCPU', lCPU);
          lDescription := NXBuildTestLoad(lText, True, lTargets);
          try
            AContext.AssertEquals(2, lDescription.Builds.Count);
            AContext.AssertEquals('First', lDescription.Builds[0].Name);
            lFPC := lDescription.Builds[1] as TNXFPCBuildOptions;
            AContext.AssertEquals('Pascal', lFPC.Name);
            if lOS = 'win64' then
              AContext.AssertEquals(NXBuildTestPath('windows-headers'), lFPC.Files.IncludePaths[0])
            else
              AContext.AssertEquals(NXBuildTestPath('linux-headers'), lFPC.Files.IncludePaths[0]);
            if lCPU = 'x86_64' then
              AContext.AssertEquals('x64', ExtractFileName(lFPC.OutputPath))
            else
              AContext.AssertEquals('arm64', ExtractFileName(lFPC.OutputPath));
            lPlan := lPlanner.CreatePlan(lDescription);
            try
              AContext.AssertEquals(2, lPlan.Steps.Count);
            finally
              lPlan.Free;
            end;
          finally
            lDescription.Free;
          end;
        finally
          lTargets.Free;
        end;
      end;
  finally
    lPlanner.Free;
    lModule.Free;
    DeleteFile(lModuleFile);
    RemoveDir(lFolder);
  end;
end;
procedure TestRejectedDescriptions(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, '{"Name":"Demo"}', False);
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo";}', False);
  NXBuildTestReject(AContext, 'Project One {} Package Two {}');
  NXBuildTestReject(AContext, '');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; Typo: "bad"; }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; Image Picture {} }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
    ' Files First {} Files Second {} } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo";' +
    ' FPC First { Name: "same"; } LLVM Second { Name: "same"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; LLVM Native { Language: Pascal; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
    ' Config Options { DisableDefaultConfigFiles: "banana"; } } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
    ' Syntax Checks { ErrorLimit: "not-an-integer"; } } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; LLVM Native {' +
    ' SourceFiles: [["nested"]]; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
    ' RawOptions: ["named": "-dDebug"]; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal { SourceFiles: "main.pas"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal { SourceFiles: [["nested"]]; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal { SourceFiles: ["named": "main.pas"]; } }');
end;

procedure TestRemovedFields(AContext: TNXTestContext);
begin
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; BuildTool: Lazarus; }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; ProjectKind: LazarusProject; }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; LazarusProjectFile: "Demo.lpi"; }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; Toolchain Tools { LazarusRoot: "tools"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; TargetPlatform Native { WidgetSet: "win32"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; BuildTool: FPC; }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; BuildFile: "main.pas"; }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal { InputFile: "main.pas"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPCBuildOptions Compiler {} }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; Variables: ["Flavor=debug"]; }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal { OutputFile: "app.exe"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; LLVM Native { OutputFile: "app.exe"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal { OutputName: "app"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; LLVM Native { OutputName: "app"; } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
    ' Files Paths { ExecutableOutputPath: "out"; } } }');
  NXBuildTestReject(AContext, 'Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
    ' Files Paths { UnitOutputPath: "out"; } } }');
end;

procedure TestPackageMetadataOption(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lArguments: TStringList;
  lOptions: TNXFPCBuildControlOptions;
  lState: TNXFPCSwitchState;
begin
  lArguments := TStringList.Create;
  lOptions := TNXFPCBuildControlOptions.Create;
  try
    for lState := Low(TNXFPCSwitchState) to High(TNXFPCSwitchState) do
    begin
      lArguments.Clear;
      lOptions.EmbedPackageMetadata := lState;
      lOptions.AppendArguments(lArguments);
      case lState of
        fssUnset: AContext.AssertEquals(0, lArguments.Count);
        fssEnabled: AContext.AssertEquals('-FJ', lArguments[0]);
        fssDisabled: AContext.AssertEquals('-FJ-', lArguments[0]);
      end;
    end;
  finally
    lOptions.Free;
    lArguments.Free;
  end;
  lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; FPC Pascal { SourceFiles: ["demo.nxpk"]; ' +
    'BuildControl Options { EmbedPackageMetadata: Disabled; } } }');
  lDescription.Free;
end;
procedure TestRuntimePackageOptions(AContext: TNXTestContext);
var
  lDescription: TNXBuildDescription;
  lOptions: TNXFPCBuildOptions;
  lArguments: TStringList;
  lSourceIndex: Integer;
  lPackagePath: string;
begin
  lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; FPC Runtime {' +
    ' SourceFiles: ["Demo.nxpk"]; PackageSDKIdentity: "SDK";' +
    ' PackageBuildIdentity: "BUILD"; RequiredPackages: [nxrtl, Abbrevia];' +
    ' Target Platform { OperatingSystem: linux; }' +
    ' Files Paths { PackagePaths: ["sdk/packages"]; } } }');
  lArguments := TStringList.Create;
  try
    lOptions := lDescription.Builds[0] as TNXFPCBuildOptions;
    lPackagePath := ExpandFileName(lDescription.RootDirectory + '/sdk/packages');
    AContext.AssertEquals(lPackagePath, lOptions.Files.PackagePaths[0]);
    lOptions.AppendArguments(lArguments, lSourceIndex);
    AContext.AssertTrue(lArguments.IndexOf('-FjSDK') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-FkBUILD') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-FPnxrtl') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-FPAbbrevia') >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-Fp' + lPackagePath) >= 0);
    AContext.AssertTrue(lArguments.IndexOf('-Fp' + lPackagePath) <
      lArguments.IndexOf('-FPnxrtl'), 'Package search paths must precede requirements');
    AContext.AssertTrue(lArguments.IndexOf('-Tlinux') <
      lArguments.IndexOf('-FPnxrtl'), 'Target selection must precede requirements');
    AContext.AssertEquals(lArguments.Count, lSourceIndex);
  finally
    lArguments.Free;
    lDescription.Free;
  end;
end;
procedure TestRetainedDebugFormats(AContext: TNXTestContext);
const
  cFormats: array[0..1] of string = ('Dwarf3', 'Dwarf4');
  cSwitches: array[0..1] of string = ('-gw3', '-gw4');
var
  lDescription: TNXBuildDescription;
  lOptions: TNXFPCBuildOptions;
  lArguments: TStringList;
  lIndex: Integer;
  lState: TNXFPCSwitchState;
begin
  lArguments := TStringList.Create;
  try
    for lIndex := Low(cFormats) to High(cFormats) do
    begin
      lDescription := NXBuildTestLoad('Project Demo { Id: "Tests.Demo"; FPC Pascal {' +
        ' Debug Settings { Format: ' + cFormats[lIndex] + '; } } }');
      try
        lOptions := lDescription.Builds[0] as TNXFPCBuildOptions;
        lArguments.Clear;
        lOptions.Debug.AppendArguments(lArguments);
        AContext.AssertEquals(1, lArguments.Count);
        AContext.AssertEquals(cSwitches[lIndex], lArguments[0]);
        for lState := Low(TNXFPCSwitchState) to High(TNXFPCSwitchState) do
        begin
          lOptions.Debug.Valgrind := lState;
          lArguments.Clear;
          lOptions.Debug.AppendArguments(lArguments);
          case lState of
            fssUnset: AContext.AssertEquals(1, lArguments.Count);
            fssEnabled: AContext.AssertTrue(lArguments.IndexOf('-gv') >= 0);
            fssDisabled: AContext.AssertTrue(lArguments.IndexOf('-gv-') >= 0);
          end;
        end;
      finally
        lDescription.Free;
      end;
    end;
  finally
    lArguments.Free;
  end;
end;

procedure TestRetiredDebugOptions(AContext: TNXTestContext);
var
  lKind, lFormat: string;
begin
  for lKind in ['Project'] do
  begin
    for lFormat in ['Stabs', 'Dwarf2', 'CodeView'] do
      NXBuildTestReject(AContext, lKind + ' Demo { Id: "Tests.Demo"; FPC Pascal {' +
        ' Debug Settings { Format: ' + lFormat + '; } } }');
    NXBuildTestReject(AContext, lKind + ' Demo { Id: "Tests.Demo"; FPC Pascal {' +
      ' Debug Settings { PreserveStabsCase: Enabled; } } }');
  end;
end;

procedure TestRetiredLanguageModes(AContext: TNXTestContext);
var
  lKind, lMode: string;
begin
  for lKind in ['Project'] do
    for lMode in ['ExtendedPascal', 'NexusUnknownMode'] do
      NXBuildTestReject(AContext, lKind + ' Demo { Id: "Tests.Demo"; FPC Pascal {' +
        ' Language Settings { Mode: ' + lMode + '; } } }');
end;

procedure TestRetiredByteOrderOption(AContext: TNXTestContext);
var
  lKind, lState: string;
begin
  for lKind in ['Project'] do
    for lState in ['Unset', 'Enabled', 'Disabled'] do
      NXBuildTestReject(AContext, lKind + ' Demo { Id: "Tests.Demo"; FPC Pascal {' +
        ' CodeGeneration Settings { BigEndianCode: ' + lState + '; } } }');
end;

procedure RegisterNXBuildTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NXBuild');
  lSuite.AddTest('Defaults', @TestDefaults);
  lSuite.AddTest('RetainedDebugFormats', @TestRetainedDebugFormats);
  lSuite.AddTest('RetiredDebugOptions', @TestRetiredDebugOptions);
  lSuite.AddTest('RetiredLanguageModes', @TestRetiredLanguageModes);
  lSuite.AddTest('RetiredByteOrderOption', @TestRetiredByteOrderOption);
  lSuite.AddTest('PackageMetadataOption', @TestPackageMetadataOption);
  lSuite.AddTest('RuntimePackageOptions', @TestRuntimePackageOptions);
  lSuite.AddTest('COperators', @TestCOperators);
  lSuite.AddTest('NativeValues', @TestNativeValues);
  lSuite.AddTest('OrderedProjectBuilds', @TestOrderedBuilds);
  lSuite.AddTest('LLVMOptions', @TestLLVMOptions);
  lSuite.AddTest('ResolvePaths', @TestResolvePaths);
  lSuite.AddTest('OutputPaths', @TestOutputPaths);
  lSuite.AddTest('PlanningBoundary', @TestPlanningBoundary);
  lSuite.AddTest('EmptyPlan', @TestEmptyPlan);
  lSuite.AddTest('EmptySources', @TestEmptySources);
  lSuite.AddTest('ExecutionOrder', @TestExecutionOrder);
  lSuite.AddTest('ExecutionStopsOnFailure', @TestExecutionFailure);
  lSuite.AddTest('SourceMasks', @TestSourceMasks);
  lSuite.AddTest('SourceMaskExecution', @TestSourceMaskExecution);
  lSuite.AddTest('CompleteSchema', @TestCompleteSchema);
  lSuite.AddTest('SharedEnvironmentModule', @TestSharedEnvironmentModule);
  lSuite.AddTest('TargetSelection', @TestTargetSelection);
  lSuite.AddTest('RejectedDescriptions', @TestRejectedDescriptions);
  lSuite.AddTest('RemovedFields', @TestRemovedFields);
end;

end.
