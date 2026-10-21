(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit tsNexusSystemTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterNexusSystemTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, obNXTestContext, obNXTestSuite, obNXForge,
  obNexusScriptModel, obNexusScriptLive, obNXForgeInvocation,
  utNXForgeFileOperations, utNXForgePaths, tpNXForge,
  obNXBuildDescription, obNXBuildDescriptionLoader, obNXBuildPlanner;

procedure CheckStage(AContext: TNXTestContext;
  ADefinition: TNexusScriptLiveDefinition; const AHost, AConfiguration: string;
  AExecutables: TStrings);
var
  lChild: TNexusScriptLiveDefinition;
  lInvocation: TNXForgeInvocation;
  lSourceRoot, lName: string;
begin
  if IsForgeFileOperation(ADefinition.Kind) then
  begin
    lInvocation := TNXForgeInvocation.Create;
    try
      lInvocation.WorkingDirectory := GetCurrentDir;
      PrepareForgeFileOperation(ADefinition, lInvocation);
      lSourceRoot := IncludeTrailingPathDelimiter(GetCurrentDir);
      AContext.AssertFalse(Pos(lSourceRoot, lInvocation.OutputPath) = 1,
        'System staging outputs must remain outside source: ' + lInvocation.OutputPath);
      if (lInvocation.Kind = fokCopyFile) and
        (ExtractFileName(ExtractFileDir(lInvocation.OutputPath)) = 'bin') then
      begin
        lName := ExtractFileName(lInvocation.OutputPath);
        AExecutables.Add(lName);
      end;
      if ADefinition.Name = 'DebugToolchain' then
      begin
        AContext.AssertEquals('Debug', AConfiguration);
        AContext.AssertTrue(lInvocation.CleanDestination);
        AContext.AssertTrue(Pos('toolchain/nexus/x86_64-' + AHost + '/current',
          StringReplace(lInvocation.OutputPath, '\', '/', [rfReplaceAll])) > 0);
      end;
      if ADefinition.Name = 'CompilerMatrix' then
        AContext.AssertTrue(lInvocation.Recursive);
    finally
      lInvocation.Free;
    end;
  end;
  for lChild in ADefinition.Children do
    CheckStage(AContext, lChild, AHost, AConfiguration, AExecutables);
end;

procedure TestStageLayouts(AContext: TNXTestContext);
const
  cPrograms: array[0..12] of string = ('nxbuild', 'nxforge', 'NexusScript',
    'nxcsv', 'NexusProfilerImport', 'NexusScriptLS', 'nexusls', 'NexusBotHost',
    'nxtest_host', 'NexusTestUI', 'nxpackage', 'NexusSetupBuilder', 'NexusSetup');
var
  lTargets: TNexusScriptTargetSelection;
  lDocument: TNexusScriptLiveDocument;
  lProject: TNexusScriptLiveDefinition;
  lExecutables: TStringList;
  lHost, lConfiguration, lProgram, lSuffix: string;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lExecutables := TStringList.Create;
  try
    for lHost in ['linux', 'win64'] do
    for lConfiguration in ['Debug', 'Release'] do
    begin
      lTargets.SetValue('HostCPU', 'x86_64');
      lTargets.SetValue('TargetCPU', 'x86_64');
      lTargets.SetValue('HostOS', lHost);
      lTargets.SetValue('TargetOS', lHost);
      lTargets.SetValue('BuildConfiguration', lConfiguration);
      lDocument := LoadForgeDocument(ExpandFileName('Nexus.Stage.nxscript'), lTargets);
      try
        lProject := lDocument.FindDefinition('StageSystem');
        AContext.AssertTrue(lProject <> nil);
        lExecutables.Clear;
        CheckStage(AContext, lProject, lHost, lConfiguration, lExecutables);
        if lHost = 'win64' then lSuffix := '.exe' else lSuffix := '';
        for lProgram in cPrograms do
          AContext.AssertTrue(lExecutables.IndexOf(lProgram + lSuffix) >= 0,
            lHost + '/' + lConfiguration + ' stages ' + lProgram);
        AContext.AssertTrue((lConfiguration = 'Debug') =
          (lProject.FindChild('DebugToolchain') <> nil));
        AContext.AssertTrue(lProject.FindChild('CompilerMatrix') <> nil,
          'Both build configurations must stage the full compiler distribution');
        AContext.AssertTrue(lProject.FindChild('NativeCompiler') = nil,
          'Development publication must include cross compilers and target RTLs');
      finally
        lDocument.Free;
      end;
    end;
  finally
    lExecutables.Free;
    lTargets.Free;
  end;
end;

procedure CollectReleaseInputs(ADefinition: TNexusScriptLiveDefinition; AInputs: TStrings);
var
  lChild: TNexusScriptLiveDefinition;
  lInvocation: TNXForgeInvocation;
begin
  if ADefinition.Kind = 'CompareFiles' then
  begin
    lInvocation := TNXForgeInvocation.Create;
    try
      lInvocation.WorkingDirectory := GetCurrentDir;
      PrepareForgeFileOperation(ADefinition, lInvocation);
      AInputs.Add(StringReplace(lInvocation.LeftPath, '\', '/', [rfReplaceAll]));
    finally
      lInvocation.Free;
    end;
  end;
  for lChild in ADefinition.Children do CollectReleaseInputs(lChild, AInputs);
end;

procedure TestReleaseInputs(AContext: TNXTestContext);
const
  cTargets: array[0..12] of string = ('i386-linux', 'x86_64-linux', 'aarch64-linux',
    'i386-win32', 'x86_64-win64', 'aarch64-win64', 'x86_64-android', 'aarch64-android',
    'x86_64-darwin', 'aarch64-darwin', 'x86_64-iphonesim', 'aarch64-iphonesim', 'aarch64-ios');
var
  lTargets: TNexusScriptTargetSelection;
  lDocument: TNexusScriptLiveDocument;
  lInputs: TStringList;
  lHost, lTarget, lUnit, lPrefix, lSource, lConfigDirectory: string;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lInputs := TStringList.Create;
  try
    lTargets.Add('HostCPU', 'x86_64');
    lTargets.Add('TargetCPU', 'x86_64');
    lTargets.Add('HostOS', 'linux');
    lTargets.Add('TargetOS', 'linux');
    lTargets.Add('BuildConfiguration', 'Release');
    lDocument := LoadForgeDocument(ExpandFileName('Nexus.Release.nxscript'), lTargets);
    try
      AContext.AssertTrue(lDocument.FindDefinition('NexusRelease') <> nil);
      CollectReleaseInputs(lDocument.FindDefinition('NexusRelease'), lInputs);
      for lHost in ['x86_64-linux', 'x86_64-win64'] do
      begin
        lPrefix := '/' + lHost + '/Release/host/';
        for lTarget in cTargets do
        for lUnit in ['system', 'sysutils', 'classes'] do
        begin
          lSource := '';
          for lSource in lInputs do
            if Pos(lPrefix + 'compiler/units/' + lTarget + '/rtl/' + lUnit + '.nxu', lSource) > 0 then Break;
          AContext.AssertTrue(Pos(lPrefix + 'compiler/units/' + lTarget + '/rtl/' + lUnit + '.nxu', lSource) > 0,
            'Release requires ' + lHost + ' compiler units for ' + lTarget + '/' + lUnit);
        end;
        lSource := '';
        for lSource in lInputs do
          if Pos(lPrefix + 'extension/nexus-pascal.vsix', lSource) > 0 then Break;
        AContext.AssertTrue(Pos(lPrefix + 'extension/nexus-pascal.vsix', lSource) > 0,
          'Release requires the extension for ' + lHost);
        if lHost = 'x86_64-linux' then lConfigDirectory := 'etc'
        else lConfigDirectory := lHost;
        lSource := '';
        for lSource in lInputs do
          if Pos(lPrefix + 'compiler/bin/' + lConfigDirectory + '/nxpc.cfg', lSource) > 0 then Break;
        AContext.AssertTrue(Pos(lPrefix + 'compiler/bin/' + lConfigDirectory + '/nxpc.cfg', lSource) > 0,
          'Release requires the compiler configuration for ' + lHost);
      end;
    finally
      lDocument.Free;
    end;
  finally
    lInputs.Free;
    lTargets.Free;
  end;
end;

procedure CheckReferencedTool(AContext: TNXTestContext; ARelativePath, ACompiler: Boolean);
var
  lDirectory, lTool, lLiteralTool, lArguments, lOperation, lTemplate, lProperty, lInputs: string;
  lGuid: TGUID;
  lText: TStringList;
  lForge: TNXForge;
begin
  CreateGUID(lGuid);
  lDirectory := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'system-fixtures/' + GUIDToString(lGuid) + '/';
  ForceDirectories(lDirectory + 'settings');
  if ARelativePath then
  begin
    lTool := StringReplace(ExtractRelativePath(lDirectory + 'settings/',
      ParamStr(0)), '\', '/', [rfReplaceAll]);
    lLiteralTool := StringReplace(ParamStr(0), '\', '/', [rfReplaceAll]);
    lArguments := '["child", "ok"]';
    AContext.AssertTrue(Pos('../', lTool) = 1, 'The fixture must exercise a relative tool path');
  end
  else
  begin
    {$IFDEF WINDOWS}
    lTool := 'cmd.exe';
    lArguments := '["/c", "echo path-tool-ok"]';
    {$ELSE}
    lTool := 'sh';
    lArguments := '["-c", "printf path-tool-ok"]';
    {$ENDIF}
    lLiteralTool := lTool;
  end;
  lText := TStringList.Create;
  lForge := TNXForge.Create;
  try
    lText.Text := 'Environment Shared { Tool: "' + lTool + '"; }';
    lText.SaveToFile(lDirectory + 'settings/Settings.nxscript');
    if ACompiler then
    begin
      lOperation := 'FPC';
      lProperty := 'Compiler';
      lTemplate := lDirectory + 'Compiler.mustache';
      {$IFDEF WINDOWS}
      lText.Text := '"{{{Compiler}}}" /c echo path-tool-ok';
      {$ELSE}
      lText.Text := '"{{{Compiler}}}" -c "printf path-tool-ok"';
      {$ENDIF}
      if ARelativePath then lText.Text := '"{{{Compiler}}}" child ok';
      lText.SaveToFile(lTemplate);
      lText.Text := '';
      lText.SaveToFile(lDirectory + 'input.pas');
      lInputs := 'Source: ["input.pas"]; EntryPoint: "input.pas"; ';
    end
    else
    begin
      lOperation := 'Run';
      lProperty := 'Executable';
      lTemplate := ExpandFileName('projects/forge/templates/Run.mustache');
      lInputs := 'Arguments: ' + lArguments + '; ';
    end;
    lText.Text := 'dialect "' + StringReplace(ExpandFileName(
      'projects/forge/language/Forge.nxscript'), '\', '/', [rfReplaceAll]) + '"; ' +
      'module "settings/Settings.nxscript"; Group Build { ' +
      lOperation + ' Literal { Template: "' +
      StringReplace(lTemplate, '\', '/', [rfReplaceAll]) + '"; ' +
      lProperty + ': "' + lLiteralTool + '"; ' + lInputs + '} ' +
      lOperation + ' Referenced { Template: "' +
      StringReplace(lTemplate, '\', '/', [rfReplaceAll]) + '"; ' +
      lProperty + ': @Shared.Tool; ' + lInputs + '} }';
    lText.SaveToFile(lDirectory + 'Build.nxscript');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(2, lForge.Invocations.Count);
    AContext.AssertEquals(lForge.Invocations[0].Command, lForge.Invocations[1].Command,
      'References preserve tool lookup and explicit path origins');
    if ARelativePath then
      AContext.AssertEquals('ok', Trim(lForge.Invocations[1].StdOut))
    else
      AContext.AssertEquals('path-tool-ok', Trim(lForge.Invocations[1].StdOut));
  finally
    lForge.Free;
    lText.Free;
    DeleteFile(lDirectory + 'settings/Settings.nxscript');
    DeleteFile(lDirectory + 'Build.nxscript');
    if ACompiler then
    begin
      DeleteFile(lDirectory + 'Compiler.mustache');
      DeleteFile(lDirectory + 'input.pas');
    end;
    RemoveDir(lDirectory + 'settings');
    RemoveDir(lDirectory);
  end;
end;

procedure TestReferencedToolName(AContext: TNXTestContext);
begin
  CheckReferencedTool(AContext, False, False);
end;

procedure TestReferencedToolPath(AContext: TNXTestContext);
begin
  CheckReferencedTool(AContext, True, False);
end;

procedure TestReferencedCompilerName(AContext: TNXTestContext);
begin
  CheckReferencedTool(AContext, False, True);
end;

procedure TestReferencedCompilerPath(AContext: TNXTestContext);
begin
  CheckReferencedTool(AContext, True, True);
end;

procedure TestCompilerForwardedPaths(AContext: TNXTestContext);
{ Paths forwarded through /targets are plain text in the child process.
  A relative BuildRoot acquires the child nxproject's directory as its base,
  although the parent Forge script staged sources relative to its own directory. }
var
  lTargets: TNexusScriptTargetSelection;
  lDocument: TNexusScriptLiveDocument;
  lProject, lCompiler, lOperation: TNexusScriptLiveDefinition;
  lArgument: TNexusScriptLiveValue;
  lHost, lConfiguration, lText, lBuildRoot, lInstallRoot, lSystemRoot: string;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  try
    for lHost in ['linux', 'win64'] do
    for lConfiguration in ['Debug', 'Release'] do
    begin
      lTargets.SetValue('HostCPU', 'x86_64');
      lTargets.SetValue('TargetCPU', 'x86_64');
      lTargets.SetValue('HostOS', lHost);
      lTargets.SetValue('TargetOS', lHost);
      lTargets.SetValue('BuildConfiguration', lConfiguration);
      lTargets.SetValue('SystemStage', 'Compiler');
      lDocument := LoadForgeDocument(ExpandFileName('Nexus.Forge.nxscript'), lTargets);
      try
        lProject := lDocument.FindDefinition('Nexus');
        lSystemRoot := ExtractFileDir(ForgeValuePath(
          lProject.FindProperty('Outputs').Value.FindItem('Host'), GetCurrentDir, True));
        lBuildRoot := IncludeTrailingPathDelimiter(lSystemRoot) + 'compiler';
        lInstallRoot := IncludeTrailingPathDelimiter(lSystemRoot) + 'compiler-install';
        lCompiler := lProject.FindChild('Compiler');
        for lOperation in lCompiler.Children do
        for lArgument in lOperation.FindProperty('Arguments').Value.Items do
        begin
          lText := lArgument.AsText;
          if Pos('/targets=', lText) <> 1 then Continue;
          AContext.AssertTrue(Pos('BuildRoot:' + lBuildRoot, lText) > 0,
            lHost + '/' + lConfiguration + '/' + lOperation.Name +
            ' must forward the same absolute build root used for staging: ' + lText);
          if Pos('InstallRoot:', lText) > 0 then
            AContext.AssertTrue(Pos('InstallRoot:' + lInstallRoot, lText) > 0,
              'The child must receive the same absolute installation root: ' + lText);
        end;
      finally
        lDocument.Free;
      end;
    end;
  finally
    lTargets.Free;
  end;
end;

procedure TestCompilerConfigLocations(AContext: TNXTestContext);
var
  lTargets: TNexusScriptTargetSelection;
  lDocument: TNexusScriptLiveDocument;
  lProject, lConfig: TNexusScriptLiveDefinition;
  lInvocation: TNXForgeInvocation;
  lHost, lDirectory, lExpected, lPublished: string;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lInvocation := TNXForgeInvocation.Create;
  try
    for lHost in ['linux', 'win64'] do
    begin
      lTargets.SetValue('HostCPU', 'x86_64');
      lTargets.SetValue('TargetCPU', 'x86_64');
      lTargets.SetValue('HostOS', lHost);
      lTargets.SetValue('TargetOS', lHost);
      lTargets.SetValue('BuildConfiguration', 'Debug');
      if lHost = 'linux' then lDirectory := 'etc'
      else lDirectory := 'x86_64-win64';
      lExpected := '/compiler/bin/' + lDirectory + '/nxpc.cfg';
      lDocument := LoadForgeDocument(ExpandFileName('Nexus.Stage.nxscript'), lTargets);
      try
        lProject := lDocument.FindDefinition('StageSystem');
        lConfig := lProject.FindChild('CompilerMatrix');
        lInvocation.WorkingDirectory := GetCurrentDir;
        PrepareForgeFileOperation(lConfig, lInvocation);
        AContext.AssertTrue(lInvocation.Recursive);
        AContext.AssertTrue(Pos('/Debug/compiler/distribution', lInvocation.SourcePath) > 0,
          'Debug must publish the assembled compiler distribution');
        lPublished := StringReplace(lInvocation.OutputPath + '/bin/' + lDirectory + '/nxpc.cfg',
          '\', '/', [rfReplaceAll]);
        AContext.AssertTrue(Copy(lPublished, Length(lPublished) - Length(lExpected) + 1,
          Length(lExpected)) = lExpected,
          lHost + ' must stage nxpc.cfg where the compiler searches: ' + lPublished);
      finally
        lDocument.Free;
      end;
      lTargets.SetValue('Build', 'Release');
      lTargets.SetValue('BuildRoot', ExpandFileName('../../worktree/forge-config-locations'));
      lTargets.SetValue('NXBuildExecutable', 'nxbuild');
      lTargets.SetValue('BuildConfiguration', 'Release');
      lExpected := '/distribution/bin/' + lDirectory + '/nxpc.cfg';
      lDocument := LoadForgeDocument(ExpandFileName('../nexus-fpc/NXPC.Forge.nxscript'), lTargets);
      try
        lProject := lDocument.FindDefinition('Release');
        lPublished := StringReplace(lProject.FindProperty('Outputs').Value.FindItem('Config').AsText,
          '\', '/', [rfReplaceAll]);
        AContext.AssertTrue(Copy(lPublished, Length(lPublished) - Length(lExpected) + 1,
          Length(lExpected)) = lExpected,
          lHost + ' release must publish the compiler configuration search location: ' + lPublished);
        lConfig := lProject.FindChild('AssembleRelease').FindChild('ReleaseConfig');
        PrepareForgeFileOperation(lConfig, lInvocation);
        AContext.AssertEquals(ForgeValuePath(lProject.FindProperty('Outputs').Value.FindItem('Config'),
          GetCurrentDir, True), lInvocation.OutputPath,
          'Release must copy nxpc.cfg to its published location');
      finally
        lDocument.Free;
      end;
    end;
  finally
    lInvocation.Free;
    lTargets.Free;
  end;
end;

procedure TestDevelopmentMatrix(AContext: TNXTestContext);
const
  cTargets: array[0..12] of string = ('i386-linux', 'x86_64-linux', 'aarch64-linux',
    'i386-win32', 'x86_64-win64', 'aarch64-win64', 'x86_64-android', 'aarch64-android',
    'x86_64-darwin', 'aarch64-darwin', 'x86_64-iphonesim', 'aarch64-iphonesim', 'aarch64-ios');
var
  lTargets: TNexusScriptTargetSelection;
  lDocument: TNexusScriptLiveDocument;
  lMatrix: TNexusScriptLiveDefinition;
  lHost, lConfiguration, lTarget: string;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  try
    for lHost in ['linux', 'win64'] do
    for lConfiguration in ['Debug', 'Release'] do
    begin
      lTargets.SetValue('HostCPU', 'x86_64');
      lTargets.SetValue('TargetCPU', 'x86_64');
      lTargets.SetValue('HostOS', lHost);
      lTargets.SetValue('TargetOS', lHost);
      lTargets.SetValue('BuildConfiguration', lConfiguration);
      lTargets.SetValue('SystemStage', 'Matrix');
      lDocument := LoadForgeDocument(ExpandFileName('Nexus.Forge.nxscript'), lTargets);
      try
        lMatrix := lDocument.FindDefinition('Nexus').FindChild('CompilerMatrix');
        AContext.AssertTrue(lMatrix <> nil,
          lHost + '/' + lConfiguration + ' must build the compiler matrix');
        for lTarget in cTargets do
          AContext.AssertTrue(lMatrix.FindChild(StringReplace(lTarget, '-', '_', [])) <> nil,
            lHost + '/' + lConfiguration + ' must build ' + lTarget);
        AContext.AssertEquals(14, lMatrix.Children.Count,
          'Build all 13 targets, then assemble the compiler distribution');
      finally
        lDocument.Free;
      end;
    end;
  finally
    lTargets.Free;
  end;
end;

procedure TestDevelopmentCompilerSelection(AContext: TNXTestContext);
var
  lTargets: TNexusScriptTargetSelection;
  lDocument: TNexusScriptLiveDocument;
  lLoader: TNXBuildDescriptionLoader;
  lPlanner: TNXBuildPlanner;
  lDescription: TNXBuildDescription;
  lPlan: TNXBuildPlan;
  lInvocation: TNXForgeInvocation;
  lHost, lRoot, lCompiler, lRTL, lSuffix: string;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lLoader := TNXBuildDescriptionLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  lInvocation := TNXForgeInvocation.Create;
  try
    for lHost in ['linux', 'win64'] do
    begin
      lTargets.SetValue('HostCPU', 'x86_64');
      lTargets.SetValue('TargetCPU', 'x86_64');
      lTargets.SetValue('HostOS', lHost);
      lTargets.SetValue('TargetOS', lHost);
      lTargets.SetValue('BuildConfiguration', 'Debug');
      lDocument := LoadForgeDocument(ExpandFileName('Nexus.Stage.nxscript'), lTargets);
      try
        lInvocation.WorkingDirectory := GetCurrentDir;
        PrepareForgeFileOperation(lDocument.FindDefinition('StageSystem').FindChild('DebugToolchain'), lInvocation);
        lRoot := IncludeTrailingPathDelimiter(lInvocation.OutputPath) + 'compiler/';
      finally
        lDocument.Free;
      end;
      if lHost = 'win64' then lSuffix := '.exe' else lSuffix := '';
      lCompiler := lRoot + 'bin/x86_64-' + lHost + '/nxpc-x86_64' + lSuffix;
      lRTL := lRoot + 'units/x86_64-' + lHost + '/rtl';
      lDescription := lLoader.LoadDescription(ExpandFileName('projects/forge/test/NexusForgeTests.nxproject'), lTargets);
      try
        lPlan := lPlanner.CreatePlan(lDescription, False);
        try
          AContext.AssertEquals(1, lPlan.Steps.Count);
          AContext.AssertEquals(lCompiler, lPlan.Steps[0].Executable,
            'Normal development builds must use the published compiler for ' + lHost);
          AContext.AssertTrue(lPlan.Steps[0].Arguments.IndexOf('-Fu' + lRTL) >= 0,
            'Normal development builds must use the matching published RTL for ' + lHost);
        finally
          lPlan.Free;
        end;
      finally
        lDescription.Free;
      end;
    end;
  finally
    lInvocation.Free;
    lPlanner.Free;
    lLoader.Free;
    lTargets.Free;
  end;
end;

procedure RegisterNexusSystemTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('Nexus.System');
  lSuite.AddTest('StageLayouts', @TestStageLayouts);
  lSuite.AddTest('DevelopmentMatrix', @TestDevelopmentMatrix);
  lSuite.AddTest('DevelopmentCompilerSelection', @TestDevelopmentCompilerSelection);
  lSuite.AddTest('ReleaseInputs', @TestReleaseInputs);
  lSuite.AddTest('CompilerForwardedPaths', @TestCompilerForwardedPaths);
  lSuite.AddTest('CompilerConfigLocations', @TestCompilerConfigLocations);
  lSuite.AddTest('ReferencedToolName', @TestReferencedToolName);
  lSuite.AddTest('ReferencedToolPath', @TestReferencedToolPath);
  lSuite.AddTest('ReferencedCompilerName', @TestReferencedCompilerName);
  lSuite.AddTest('ReferencedCompilerPath', @TestReferencedCompilerPath);
end;
end.
