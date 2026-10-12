(*
  Copyright (c) 2026 Kevin Collins.
  
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  
  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.
  
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXForgeTests;

{$mode delphi}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterForgeTests(ARegistry: TNXTestRegistry);

implementation

uses Classes, SysUtils, DateUtils, fpjson, jsonparser, obNXTestContext, obNXTestSuite,
  obNXForge, obNXForgeProcess, obNXForgeInvocation, obNexusScriptModel, obNexusScriptSession,
  obNexusScriptLanguageDefinition, obNexusScriptJSON, obNXCommandLine,
  tsNXForgeContractTests, utNXForgeBuildIdentity, utNXForgePackageSDK;

function Root: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../../');
end;

procedure DeleteDirRecursive(const APath: string);
var
  lInfo: TSearchRec;
  lFull: string;
begin
  if not DirectoryExists(APath) then Exit;
  if FindFirst(APath + '*', faAnyFile, lInfo) = 0 then
  begin
    try
      repeat
        if (lInfo.Name = '.') or (lInfo.Name = '..') then Continue;
        lFull := APath + lInfo.Name;
        if (lInfo.Attr and faDirectory) <> 0 then
          DeleteDirRecursive(lFull + PathDelim)
        else
        begin
          FileSetAttr(lFull, faArchive);
          DeleteFile(lFull);
        end;
      until FindNext(lInfo) <> 0;
    finally
      FindClose(lInfo);
    end;
  end;
  RemoveDir(APath);
end;

function TestDir(const AName: string): string;
begin
  Result := Root + 'output/ForgeVerification/' + AName + '/';
  // Discard any prior run's fixture so stale ownership/state never leaks between runs.
  DeleteDirRecursive(Result);
  ForceDirectories(Result);
end;

procedure Save(const AFile, AText: string);
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFile, fmCreate);
  try
    if AText <> '' then lStream.WriteBuffer(AText[1], Length(AText));
  finally
    lStream.Free;
  end;
end;

function LoadRaw(const AFile: string): string;
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFile, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, lStream.Size);
    if lStream.Size > 0 then lStream.ReadBuffer(Result[1], lStream.Size);
  finally
    lStream.Free;
  end;
end;

function Dialect(const AName: string): string;
var
  lDialectPath: string;
begin
  if AName = 'Schema' then
    lDialectPath := Root + 'projects/schema/language/Schema.Language.nxscript'
  else
    lDialectPath := Root + 'projects/forge/language/Forge.nxscript';
  Result := 'dialect "' + StringReplace(lDialectPath, '\', '/', [rfReplaceAll]) + '"; ';
end;

function ChildCommand(const AMode: string): string;
begin
  Result := '"' + ParamStr(0) + '" child ' + AMode;
end;

procedure Fixture(const ADirectory, AOperations, ATemplate: string);
begin
  Save(ADirectory + 'Build.nxscript', Dialect('NexusForge') + AOperations);
  Save(ADirectory + 'command.mustache', ATemplate);
end;

procedure AssertNoLaunch(AContext: TNXTestContext; AForge: TNXForge);
var
  lInvocation: TNXForgeInvocation;
begin
  for lInvocation in AForge.Invocations do
    AContext.AssertFalse(lInvocation.Started, 'Preflight must not launch a child.');
end;

procedure TestLanguagePieces(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lLanguage: TNexusScriptLanguageDefinition;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lLanguage := TNexusScriptLanguageDefinition.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(Root +
      'projects/forge/test/fixtures/composition.nxscript'), lSession.LastError);
    AContext.AssertTrue(lLanguage.Normalize(
      lSession.EntryCompiler.CompiledDocument.DialectDocument), 'Normalize included rules');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('FPC') <> nil, 'FPC rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('NXBuild') <> nil, 'NXBuild rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Clang') <> nil, 'Clang rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('LLVMAr') <> nil, 'LLVMAr rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Git') <> nil, 'Git rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('MSBuild') <> nil, 'MSBuild rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('PowerShell') <> nil, 'PowerShell rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('LazBuild') <> nil, 'LazBuild rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Npm') <> nil, 'Npm rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('InnoSetup') <> nil, 'InnoSetup rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Group') <> nil, 'Group rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('NexusPackage') = nil,
      'Package entities are not Forge tasks');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Package') <> nil,
      'Package combines its common contract and ordered tasks');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('PackageIndex') <> nil,
      'Catalog rules are available to contract references');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Project') <> nil,
      'Project has a distinct artifact contract');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('NexusProject') = nil,
      'NexusProject is not a Forge task');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('PackageOutput') = nil,
      'PackageOutput is not a Forge value');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Environment') <> nil, 'Environment rule present');
  finally
    lLanguage.Free;
    lSession.Free;
  end;
end;

procedure TestRejectEntityDocument(AContext: TNXTestContext);
var
  lForge: TNXForge;
begin
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(Root +
      'projects/nxpackage/examples/Package.nxscript'),
      'Package entity is not a Forge task');
    AContext.AssertTrue(Pos('NexusForge dialect', lForge.Diagnostic) > 0,
      lForge.Diagnostic);
    AContext.AssertEquals(0, lForge.Invocations.Count,
      'No operation is prepared from an entity document');
  finally
    lForge.Free;
  end;
end;

procedure TestGroups(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('groups');
  lForge := TNXForge.Create;
  try
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { WriteTextFile First { Path: "first.txt"; Text: "one"; } ' +
      'Group Nested { CopyFile Second { Source: "first.txt"; Destination: "second.txt"; } ' +
      'Group Deeper { DeletePath Third { Path: "first.txt"; } } } }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(3, lForge.Invocations.Count, 'Nested groups contain ordered tasks');
    AContext.AssertEquals('one' + #10, LoadRaw(lDirectory + 'second.txt'),
      'Nested task consumes prior output');
    AContext.AssertFalse(FileExists(lDirectory + 'first.txt'), 'Later nested task runs');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { WriteTextFile Prepare { Path: "ready.txt"; Text: "ready"; } ' +
      'CopyFile After { Source: "ready.txt"; Destination: "after.txt"; } }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(2, lForge.Invocations.Count, 'Group contains explicit tasks');
    AContext.AssertEquals('ready' + #10, LoadRaw(lDirectory + 'after.txt'),
      'Task following preparation executes');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'WriteTextFile Alone { Path: "single.txt"; Text: "single"; }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(1, lForge.Invocations.Count, 'A singular root runs alone');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'WriteTextFile One { Path: "never.txt"; Text: "one"; } ' +
      'WriteTextFile Two { Path: "never.txt"; Text: "two"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Multiple executable roots require a Group');
    AContext.AssertTrue(Pos('one executable root', lForge.Diagnostic) > 0,
      lForge.Diagnostic);
    AContext.AssertEquals(0, lForge.Invocations.Count, 'Invalid roots prepare no tasks');
    AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Invalid roots write nothing');
  finally
    lForge.Free;
  end;
end;

procedure TestPowerShellOperation(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lTemplate, lExpected: string;
begin
  lDirectory := TestDir('powershell');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/PowerShell.mustache';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { PowerShell Dependencies { Template: "' + lTemplate + '"; ' +
    'EntryPoint: "Build-X64Dependencies.ps1"; } ' +
    'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents execution');
    AContext.AssertEquals(2, lForge.Invocations.Count, 'Both operations prepared');
    AssertNoLaunch(AContext, lForge);
    lExpected := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' +
      ExpandFileName(lDirectory + 'Build-X64Dependencies.ps1') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Dependency script renders with the absolute script path');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { PowerShell Dependencies { Template: "' + lTemplate + '"; ' +
      'Executable: "C:/Tools/powershell.exe"; EntryPoint: "Build-X64Dependencies.ps1"; ' +
      'Arguments: ["-CMakePath", "../tools/cmake.exe"]; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents the optional form from executing');
    AssertNoLaunch(AContext, lForge);
    lExpected := '"C:/Tools/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "' +
      ExpandFileName(lDirectory + 'Build-X64Dependencies.ps1') +
      '" "-CMakePath" "../tools/cmake.exe"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Optional executable and arguments render in order');
  finally
    lForge.Free;
  end;
end;

procedure TestMSBuildOperation(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lTemplate, lExpected: string;
begin
  lDirectory := TestDir('msbuild');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/MSBuild.mustache';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { MSBuild Simulator { Template: "' + lTemplate + '"; ' +
    'EntryPoint: "Corona.Simulator.sln"; Configuration: Release; Platform: x64; } ' +
    'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents execution');
    AContext.AssertEquals(2, lForge.Invocations.Count, 'Both operations prepared');
    AssertNoLaunch(AContext, lForge);
    lExpected := 'MSBuild "' + ExpandFileName(lDirectory + 'Corona.Simulator.sln') +
      '" "/p:Configuration=Release" "/p:Platform=x64"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Nexus2D Release x64 command renders with the absolute solution path');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { MSBuild Simulator { Template: "' + lTemplate + '"; ' +
      'Executable: "C:/Tools/MSBuild.exe"; EntryPoint: "Corona.Simulator.sln"; ' +
      'Configuration: Release; Platform: x64; BuildTarget: Build; ' +
      'Properties: ["ForgeTest=value with spaces"]; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents the optional form from executing');
    AssertNoLaunch(AContext, lForge);
    lExpected := '"C:/Tools/MSBuild.exe" "' +
      ExpandFileName(lDirectory + 'Corona.Simulator.sln') +
      '" "/p:Configuration=Release" "/p:Platform=x64" "/t:Build" ' +
      '"/p:ForgeTest=value with spaces"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Optional executable, target, and properties render as MSBuild arguments');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'MSBuild Invalid { Template: "' + lTemplate + '"; ' +
      'EntryPoint: "Corona.Simulator.sln"; Configuration: Release; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'MSBuild platform is required');
    AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0,
      lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestNXBuildOperation(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lTemplate, lExpected: string;
begin
  lDirectory := TestDir('nxbuild');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/NXBuild.mustache';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { NXBuild Compile { Template: "' + lTemplate + '"; ' +
    'EntryPoint: "project & source/app.nxproject"; } ' +
    'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents execution');
    AContext.AssertEquals(2, lForge.Invocations.Count, 'Both operations prepared');
    AssertNoLaunch(AContext, lForge);
    lExpected := 'nxbuild /action=build "/project=' +
      ExpandFileName(lDirectory + 'project & source/app.nxproject') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'nxbuild receives the quoted absolute project path');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { NXBuild Compile { Template: "' + lTemplate + '"; ' +
      'Executable: "C:/Tools & builds/nxbuild.exe"; ' +
      'EntryPoint: "project & source/app.nxproject"; WorkingDirectory: "project & source"; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents the explicit form from executing');
    AssertNoLaunch(AContext, lForge);
    lExpected := '"C:/Tools & builds/nxbuild.exe" /action=build "/project=' +
      ExpandFileName(lDirectory + 'project & source/app.nxproject') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Explicit nxbuild executable is quoted separately');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'project & source'),
      lForge.Invocations[0].WorkingDirectory, 'NXBuild operation directory');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { NXBuild Compile { Template: "' + lTemplate + '"; ' +
      'Executable: "tools & builds/nxbuild.exe"; ' +
      'EntryPoint: "app.nxproject"; WorkingDirectory: "project & source"; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Preflight prevents relative executable launch');
    AssertNoLaunch(AContext, lForge);
    lExpected := '"' + ExpandFileName(lDirectory + 'tools & builds/nxbuild.exe') +
      '" /action=build "/project=' + ExpandFileName(lDirectory + 'app.nxproject') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Relative executable uses its source document, not the child working directory');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { NXBuild Compile { Template: "' + lTemplate + '"; ' +
      'Executable: "nxbuild.exe"; EntryPoint: "app.nxproject"; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Preflight prevents PATH executable launch');
    AssertNoLaunch(AContext, lForge);
    lExpected := '"nxbuild.exe" /action=build "/project=' +
      ExpandFileName(lDirectory + 'app.nxproject') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Bare executable name remains available for PATH lookup');

    ForceDirectories(lDirectory + 'library');
    Save(lDirectory + 'library/Shared.nxscript',
      'NXBuild Defaults { Template: "' + lTemplate + '"; Executable: "bin/nxbuild.exe"; }');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'module "library/Shared.nxscript"; Group Build { NXBuild Compile (Defaults) { ' +
      'EntryPoint: "app.nxproject"; WorkingDirectory: "project & source"; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Preflight prevents composed executable launch');
    AContext.AssertEquals(2, lForge.Invocations.Count, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
    lExpected := '"' + ExpandFileName(lDirectory + 'library/bin/nxbuild.exe') +
      '" /action=build "/project=' + ExpandFileName(lDirectory + 'app.nxproject') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Inherited executable retains the supplying module directory');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'NXBuild Invalid { Template: "' + lTemplate + '"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'NXBuild project entry point is required');
    AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0,
      lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestFPCSwitches(AContext: TNXTestContext);
const
  cSettings: array[0..7] of string = (
    '',
    'DisableDefaultConfigFiles: False; CompileSystemUnit: False; ' +
      'LabelAndGoto: False; GenerateReleaseUnitFiles: False; ' +
      'UseLLD: False; PositionIndependentCode: False; StripSymbols: False;',
    'DisableDefaultConfigFiles: True; CompileSystemUnit: True; ' +
      'LabelAndGoto: True; OptimizationLevel: 2; GenerateReleaseUnitFiles: True;',
    'OptimizationLevel: 1;', 'OptimizationLevel: 3;', 'OptimizationLevel: 4;',
    'TargetOS: "android"; Assembler: "as-clang"; UseLLD: True; ' +
      'PositionIndependentCode: True; CompilerUtilitiesPath: "C:/NDK tools/bin";',
    'StripSymbols: True; ResponseFiles: ["build options.cfg"];');
  cSwitches: array[0..7] of string = (
    '', '', ' -n -Us -Sg -O2 -Ur', ' -O1', ' -O3', ' -O4',
    ' "-Tandroid" "-Aas-clang" -XLL -Cg "-FDC:/NDK tools/bin"',
    ' -Xs "@build options.cfg"');
var
  lForge: TNXForge;
  lDirectory, lTemplate, lExpected, lCompiler: string;
  lIndex: Integer;
begin
  lDirectory := TestDir('fpc-switches');
  lCompiler := StringReplace(lDirectory, '\', '/', [rfReplaceAll]) + 'missing compiler.exe';
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/FPC.mustache';
  Save(lDirectory + 'input.pas', 'program input; begin end.');
  lForge := TNXForge.Create;
  try
    for lIndex := Low(cSettings) to High(cSettings) do
    begin
      Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
        'FPC Compile { Template: "' + lTemplate + '"; Compiler: "' + lCompiler + '"; ' +
        'Source: ["input.pas"]; EntryPoint: "input.pas"; Output: "output.exe"; ' +
        cSettings[lIndex] + ' }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'The intentionally missing compiler prevents launch after source resolution');
      AContext.AssertEquals(1, lForge.Invocations.Count, lForge.Diagnostic);
      AContext.AssertFalse(lForge.Invocations[0].Started, 'No compiler process was launched');
      lExpected := '"' + lCompiler + '"' + cSwitches[lIndex] + ' "' +
        ExpandFileName(lDirectory + 'input.pas') + '" "-ooutput.exe" "-Fu' +
        ExcludeTrailingPathDelimiter(ExpandFileName(lDirectory)) + '"';
      AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
        'Named FPC settings render through the shared Mustache template');
    end;
  finally
    lForge.Free;
  end;
end;

procedure TestFPCOptionalOutput(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lTemplate: string;
begin
  lDirectory := TestDir('fpc-optional-output');
  ForceDirectories(lDirectory + 'compiled units');
  ForceDirectories(lDirectory + 'source');
  ForceDirectories(lDirectory + 'include paths');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/FPC.mustache';
  Save(lDirectory + 'include paths/value.inc', 'cValue = 42;');
  Save(lDirectory + 'source/utOptionalOutput.pas',
    'unit utOptionalOutput; interface const {$I value.inc} implementation end.');
  Save(lDirectory + 'optional_output.lpr',
    'program optional_output; uses utOptionalOutput; begin if cValue <> 42 then Halt(1); end.');
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { FPC CompileUnit { Template: "' + lTemplate + '"; ' +
    'Source: ["source/utOptionalOutput.pas"]; EntryPoint: "source/utOptionalOutput.pas"; ' +
    'UnitOutput: "compiled units"; IncludePaths: ["include paths"]; } ' +
    'FPC CompileProgram { Template: "' + lTemplate + '"; ' +
    'Source: ["optional_output.lpr"]; EntryPoint: "optional_output.lpr"; ' +
    'UnitPaths: ["compiled units"]; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(2, lForge.Invocations.Count, 'Unit and program compile');
    AContext.AssertTrue(FileExists(lDirectory + 'compiled units/utoptionaloutput.ppu'),
      'Unit output uses the explicit unit directory');
    AContext.AssertTrue(FileExists(lDirectory + 'optional_output.exe'),
      'Program finds the compiled unit through UnitPaths and uses normal output naming');
    AContext.AssertEquals(0, Pos('"-o', lForge.Invocations[0].Command),
      'Unit compilation has no executable output switch');
    AContext.AssertEquals(0, Pos('"-o', lForge.Invocations[1].Command),
      'Program compilation has no executable output switch when omitted');
  finally
    lForge.Free;
  end;
end;

procedure TestFPCSwitchValidation(AContext: TNXTestContext);
const
  cInvalidSettings: array[0..15] of string = (
    'DisableDefaultConfigFiles: invalid;', 'CompileSystemUnit: invalid;',
    'LabelAndGoto: invalid;', 'GenerateReleaseUnitFiles: invalid;',
    'OptimizationLevel: 0;', 'OptimizationLevel: 5;',
    'OptimizationLevel: 2.5;', 'OptimizationLevel: "2 -Xs";',
    'Arguments: ["-n"];', 'TargetOS: [linux];', 'Assembler: ["as-clang"];',
    'UseLLD: invalid;', 'PositionIndependentCode: invalid;',
    'CompilerUtilitiesPath: ["tools"];', 'StripSymbols: invalid;',
    'ResponseFiles: "file.cfg";');
var
  lForge: TNXForge;
  lDirectory, lSetting: string;
begin
  lDirectory := TestDir('fpc-switch-validation');
  lForge := TNXForge.Create;
  try
    for lSetting in cInvalidSettings do
    begin
      Fixture(lDirectory, 'FPC Bad { Template: "command.mustache"; ' +
        'Source: [a]; EntryPoint: a; Output: b; ' + lSetting + ' }', ChildCommand('ok'));
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'Invalid FPC setting rejected: ' + lSetting);
      AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0,
        lForge.Diagnostic);
      AssertNoLaunch(AContext, lForge);
    end;
  finally
    lForge.Free;
  end;
end;

procedure TestClangOperation(AContext: TNXTestContext);
const
  cInvalidSettings: array[0..5] of string = (
    'SourceLanguage: [assembler];', 'AssemblerSymbols: "CPU64=1";',
    'AssemblerSymbols: [["CPU64=1"]];', 'SystemIncludePaths: "include";',
    'OptimizationLevel: 9;', 'DisableStackProtector: sometimes;');
var
  lForge: TNXForge;
  lDirectory, lTemplate, lExpected, lCompiler, lSetting: string;
begin
  lDirectory := TestDir('clang');
  lCompiler := StringReplace(lDirectory, '\', '/', [rfReplaceAll]) + 'missing clang.exe';
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/Clang.mustache';
  Save(lDirectory + 'input & one.c', 'int sample(void) { return 7; }');
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Clang Compile { Template: "' + lTemplate + '"; Executable: "' + lCompiler + '"; ' +
    'Source: ["input & one.c"]; Output: "object file.obj"; CompileOnly: True; }');
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'The intentionally missing compiler prevents launch after source resolution');
    AContext.AssertEquals(1, lForge.Invocations.Count, lForge.Diagnostic);
    AContext.AssertFalse(lForge.Invocations[0].Started, 'No compiler process was launched');
    lExpected := '"' + lCompiler + '" -c "' + ExpandFileName(lDirectory + 'input & one.c') +
      '" -o "object file.obj"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'C source paths expand and retain native quoting');

    Save(lDirectory + 'second.c', 'int another(void) { return 9; }');
    ForceDirectories(lDirectory + 'objects');
    Save(lDirectory + 'Headers.nxscript', 'Environment Headers { System: "system include"; }');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'module "Headers.nxscript"; ' +
      'Clang Compile { Template: "' + lTemplate + '"; Executable: "' + lCompiler + '"; ' +
      'Source: ["*.c"]; CompileOnly: True; WorkingDirectory: "objects"; ' +
      'SystemIncludePaths: [@Headers.System]; OptimizationLevel: 2; DisableStackProtector: True; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'The intentionally missing compiler prevents the batch launch');
    AContext.AssertEquals(1, lForge.Invocations.Count,
      'One command for all selected C sources: ' + lForge.Diagnostic);
    lExpected := '"' + lCompiler + '" -c -isystem "' +
      ExpandFileName(lDirectory + 'system include') + '" -O2 -fno-stack-protector "' +
      ExpandFileName(lDirectory + 'input & one.c') + '" "' +
      ExpandFileName(lDirectory + 'second.c') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Batch compilation omits -o and preserves source/header origins');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'objects'),
      lForge.Invocations[0].WorkingDirectory, 'Objects are emitted in the selected working directory');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Clang Compile { Template: "' + lTemplate + '"; Executable: "' + lCompiler + '"; ' +
      'Source: ["second.c"]; CompileOnly: True; OptimizationLevel: 0; DisableStackProtector: False; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'The intentionally missing compiler prevents launch');
    lExpected := '"' + lCompiler + '" -c -O0 "' + ExpandFileName(lDirectory + 'second.c') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Explicit zero optimization and false stack-protector override render correctly');

    Save(lDirectory + 'input.as', '.text');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Clang Assemble { Template: "' + lTemplate + '"; Executable: "' + lCompiler + '"; ' +
      'Source: ["input.as"]; Output: "object file.o"; CompileOnly: True; ' +
      'SourceLanguage: "assembler"; Target: "aarch64-linux-android"; ' +
      'AssemblerSymbols: ["CPU64=1", "OTHER=2"]; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'The intentionally missing assembler driver prevents launch');
    AContext.AssertEquals(1, lForge.Invocations.Count, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
    lExpected := '"' + lCompiler + '" -c -x "assembler" ' +
      '"--target=aarch64-linux-android" "' + ExpandFileName(lDirectory + 'input.as') +
      '" -o "object file.o" "-Wa,-defsym,CPU64=1" "-Wa,-defsym,OTHER=2"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Assembly language and symbols render through the shared Clang template');

    for lSetting in cInvalidSettings do
    begin
      Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
        'Clang Invalid { Template: "' + lTemplate + '"; Source: ["input.as"]; ' +
        'Output: "object.o"; CompileOnly: True; ' + lSetting + ' }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'Invalid Clang setting rejected: ' + lSetting);
      AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0,
        lForge.Diagnostic);
      AssertNoLaunch(AContext, lForge);
    end;

    lCompiler := StringReplace(lDirectory, '\', '/', [rfReplaceAll]) + 'missing clang++.exe';
    ForceDirectories(lDirectory + 'work');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Clang Link { Template: "' + lTemplate + '"; ' +
      'Executable: "' + lCompiler + '"; ' +
      'Source: ["input & one.c"]; Output: "program.exe"; CompileOnly: False; ' +
      'Target: "x86_64-pc-windows-msvc"; Standard: "c++17"; ' +
      'IncludePaths: ["include folder"]; Defines: ["TEXT=a & b"]; ' +
      'Arguments: ["-fuse-ld=lld", "native library.lib"]; WorkingDirectory: "work"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'The intentionally missing C++ driver prevents launch');
    AContext.AssertEquals(1, lForge.Invocations.Count, lForge.Diagnostic);
    AContext.AssertFalse(lForge.Invocations[0].Started, 'No C++ driver process was launched');
    lExpected := '"' + lCompiler + '" "--target=x86_64-pc-windows-msvc" ' +
      '"-std=c++17" "-Iinclude folder" "-DTEXT=a & b" "' +
      ExpandFileName(lDirectory + 'input & one.c') +
      '" -o "program.exe" "-fuse-ld=lld" "native library.lib"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'False omits -c; explicit C++ driver and linker inputs retain their arguments');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'work'),
      lForge.Invocations[0].WorkingDirectory, 'Explicit tool working directory');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Clang Invalid { Template: "' + lTemplate + '"; Source: ["input & one.c"]; ' +
      'Output: "object.obj"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'CompileOnly must be explicit');
    AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestLLVMArOperation(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lTemplate: string;
begin
  lDirectory := TestDir('llvm-ar');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/LLVMAr.mustache';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { LLVMAr Library { Template: "' + lTemplate + '"; ' +
    'Operation: "rcs"; Output: "library file.lib"; Objects: ["first.obj", "second file.obj"]; } ' +
    'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents execution');
    AContext.AssertEquals(2, lForge.Invocations.Count, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
    AContext.AssertEquals('llvm-ar "rcs" "library file.lib" "first.obj" "second file.obj"',
      lForge.Invocations[0].Command, 'Explicit object inputs do not require prior artifacts');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { LLVMAr Library { Template: "' + lTemplate + '"; ' +
      'Executable: "C:/Tools/LLVM/bin/llvm-ar.exe"; Operation: "rcs"; ' +
      'Output: "library.lib"; Objects: ["object.obj"]; Arguments: ["--format=coff"]; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents execution');
    AContext.AssertEquals(2, lForge.Invocations.Count, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
    AContext.AssertEquals('"C:/Tools/LLVM/bin/llvm-ar.exe" "--format=coff" ' +
      '"rcs" "library.lib" "object.obj"', lForge.Invocations[0].Command,
      'Explicit archiver and native options render unchanged');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'LLVMAr Invalid { Template: "' + lTemplate + '"; Operation: "rcs"; ' +
      'Output: "library.lib"; Objects: []; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'An archive build requires object inputs');
    AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestToolOperations(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lExamples, lExpected: string;
begin
  lDirectory := TestDir('tool-operations');
  lExamples := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { LazBuild Compile { Template: "' + lExamples + 'LazBuild.mustache"; ' +
    'EntryPoint: "project/app.lpi"; WorkingDirectory: "project"; ' +
    'Executable: "C:/Tools/lazbuild.exe"; Quiet: True; BuildAll: True; ' +
    'PrimaryConfigPath: "C:/Lazarus Config"; LazarusDirectory: "C:/Lazarus"; } ' +
    'Npm Bundle { Template: "' + lExamples + 'Npm.mustache"; ' +
    'Command: run; Arguments: [esbuild, "--watch=false"]; ' +
    'WorkingDirectory: "extension"; } ' +
    'InnoSetup Installer { Template: "' + lExamples + 'InnoSetup.mustache"; ' +
    'EntryPoint: "setup/install.iss"; WorkingDirectory: "setup"; ' +
    'Quiet: False; Defines: ["Version=1.0", "Root=C:/Build Output"]; ' +
    'Arguments: ["/DExtra=one two"]; OutputDirectory: "out"; ' +
    'OutputBaseFilename: "installer"; } ' +
    'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents any tool launch');
    AContext.AssertEquals(4, lForge.Invocations.Count, 'All tool operations prepared');
    AssertNoLaunch(AContext, lForge);
    lExpected := '"C:/Tools/lazbuild.exe" "--pcp=C:/Lazarus Config" ' +
      '"--lazarusdir=C:/Lazarus" --quiet --build-all "' +
      ExpandFileName(lDirectory + 'project/app.lpi') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'LazBuild flags and absolute project path');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'project'),
      lForge.Invocations[0].WorkingDirectory, 'LazBuild operation directory');
    AContext.AssertEquals('npm.cmd run "esbuild" "--watch=false"',
      lForge.Invocations[1].Command, 'Npm script and arguments');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'extension'),
      lForge.Invocations[1].WorkingDirectory, 'Npm operation directory');
    lExpected := 'ISCC.exe "/DExtra=one two" "/DVersion=1.0" ' +
      '"/DRoot=C:/Build Output" "/Oout" "/Finstaller" "' +
      ExpandFileName(lDirectory + 'setup/install.iss') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[2].Command,
      'InnoSetup switches and absolute script path');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'setup'),
      lForge.Invocations[2].WorkingDirectory, 'InnoSetup operation directory');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { LazBuild Minimal { Template: "' + lExamples + 'LazBuild.mustache"; ' +
      'EntryPoint: "project/app.lpi"; Quiet: False; BuildAll: False; } ' +
      'Git NoLaunch { Template: "missing.mustache"; Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing later template prevents the minimal form from running');
    AssertNoLaunch(AContext, lForge);
    AContext.AssertEquals('lazbuild "' +
      ExpandFileName(lDirectory + 'project/app.lpi') + '"',
      lForge.Invocations[0].Command,
      'False Quiet and BuildAll values do not emit switches');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'LazBuild Invalid { Template: "' + lExamples + 'LazBuild.mustache"; ' +
      'EntryPoint: "project/app.lpi"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Quiet must be specified for LazBuild');
    AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0,
      lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestValidation(AContext: TNXTestContext);
const
  cInvalidOperations: array[0..4] of string = (
    'FPC Bad { Template: "command.mustache"; Source: [a]; EntryPoint: a; Output: b; Bogus: x; }',
    'Git Bad { Template: "command.mustache"; }',
    'FPC Bad { Template: "command.mustache"; Source: [a]; EntryPoint: a; Output: [invalid]; }',
    'FPC Bad { Template: "command.mustache"; Source: [a]; EntryPoint: a; Output: b; Defines: text; }',
    'FPC Bad { Template: "command.mustache"; Source: [a]; EntryPoint: a; Output: b; UnitOutput: [invalid]; }');
var
  lForge: TNXForge;
  lDirectory, lOperation: string;
begin
  lDirectory := TestDir('validation');
  lForge := TNXForge.Create;
  try
    for lOperation in cInvalidOperations do
    begin
      Fixture(lDirectory, lOperation, ChildCommand('ok'));
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Invalid completed operation rejected');
      AContext.AssertTrue(Pos('Validation failed', lForge.Diagnostic) > 0, lForge.Diagnostic);
      AssertNoLaunch(AContext, lForge);
    end;
    Fixture(lDirectory, 'Git Bad { Repository: dot; }', ChildCommand('ok'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Template is required');
    AContext.AssertTrue(Pos('Template', lForge.Diagnostic) > 0, lForge.Diagnostic);
    Save(lDirectory + 'Build.nxscript', 'Git Bare { Repository: dot; Template: "command.mustache"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Dialect required');
    AContext.AssertTrue(Pos('declared dialect', lForge.Diagnostic) > 0, lForge.Diagnostic);
  finally
    lForge.Free;
  end;
end;

procedure TestTemplateComposition(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lTargets: TNexusScriptTargetSelection;
  lDirectory: string;
begin
  lDirectory := TestDir('template-composition');
  Save(lDirectory + 'app.pas', '');
  Save(lDirectory + 'tests.pas', '');
  Save(lDirectory + 'other.pas', '');
  ForceDirectories(lDirectory + 'library/nested');
  Save(lDirectory + 'library/Paths.nxscript', 'Environment Paths { Command: "command.mustache"; }');
  Save(lDirectory + 'library/Shared.nxscript', Dialect('NexusForge') + 'module "Paths.nxscript"; ' +
    'Environment Platform TargetOS[Windows] { ExecutableSuffix: ".exe"; } ' +
    'Environment Platform TargetOS[Linux] { ExecutableSuffix: ""; } ' +
    'FPC Application { Template: @Paths.Command; UnitOutput: "units & cache"; Defines: [APPLICATION]; } ' +
    'FPC Tests { Template: "tests.mustache"; Defines: [TESTS]; }');
  Save(lDirectory + 'library/nested/Presets.nxscript',
    'module "../Shared.nxscript"; FPC Defaults (Application) {}');
  Save(lDirectory + 'library/command.mustache', ChildCommand('ok') + ' app {{{Output}}}{{#Defines}} {{{.}}}{{/Defines}} {{{UnitOutput}}');
  Save(lDirectory + 'library/tests.mustache', ChildCommand('ok') + ' tests');
  Fixture(lDirectory, 'module "library/Shared.nxscript"; module Defaults "library/nested/Presets.nxscript"; ' +
    'Environment Local { Template: "must-not-run.mustache"; } ' +
    'Group BuildAll { FPC Build (Defaults) { Source: ["app.pas"]; EntryPoint: "app.pas"; Output: "app" + @Platform.ExecutableSuffix; } ' +
    'FPC Check (Tests) { Source: ["tests.pas"]; EntryPoint: "tests.pas"; Output: "tests.exe"; } ' +
    'FPC Override (Defaults) { Template: "command.mustache"; Source: ["other.pas"]; EntryPoint: "other.pas"; Output: "other.exe"; } }',
    ChildCommand('ok') + ' override');
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('TargetOS', 'Windows');
  lForge := TNXForge.Create(lTargets);
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(3, lForge.Invocations.Count, 'Only concrete operations execute');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'library/command.mustache'),
      lForge.Invocations[0].TemplatePath, 'Nested composition and property alias retain template origin');
    AContext.AssertEquals(ChildCommand('ok') + ' app app.exe APPLICATION units & cache',
      lForge.Invocations[0].Command, 'Environment and inherited settings resolve before rendering');
    AContext.AssertEquals(ChildCommand('ok') + ' tests', lForge.Invocations[1].Command,
      'Two operations of the same kind select their own templates');
    AContext.AssertEquals(ChildCommand('ok') + ' override', lForge.Invocations[2].Command,
      'Local template override resolves from the local document');
  finally
    lForge.Free;
    lTargets.Free;
  end;
end;

procedure TestTargetsOrderAndRendering(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lTargets: TNexusScriptTargetSelection;
  lDirectory: string;
begin
  lDirectory := TestDir('order');
  Save(lDirectory + 'source', '');
  Save(lDirectory + 'Base.nxscript',
    'FPC Defaults HostOS[Win32] { Template: "command.mustache"; Source: [source]; EntryPoint: source; Output: output; Defines: [ONE, TWO]; } ' +
    'FPC Defaults HostOS[Linux] { Template: "absent.mustache"; }');
  Fixture(lDirectory, 'module "Base.nxscript"; ' +
    'Group Build { FPC Zulu (Defaults) {} FPC Hidden HostOS[Linux] {} FPC Alpha (Defaults) { Output: other; } }',
    ChildCommand('ok') + ' {{{_nx.Name}}} {{{EntryPoint}}} {{{Output}}}{{#Defines}} {{{.}}}{{/Defines}}');
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('HostOS', 'Win32');
  lForge := TNXForge.Create(lTargets);
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(2, lForge.Invocations.Count, 'Inactive and module roots not scheduled');
    AContext.AssertEquals('Zulu', lForge.Invocations[0].OperationName, 'Declaration order');
    AContext.AssertEquals(ChildCommand('ok') + ' Zulu ' + ExpandFileName(lDirectory + 'source') + ' output ONE TWO',
      lForge.Invocations[0].Command, 'Exact resolved template context');
    AContext.AssertEquals(ChildCommand('ok') + ' Alpha ' + ExpandFileName(lDirectory + 'source') + ' other ONE TWO',
      lForge.Invocations[1].Command, 'Same template, different name and override');
  finally
    lForge.Free;
    lTargets.Free;
  end;
end;

procedure TestFailuresAndReuse(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory: string;
begin
  lDirectory := TestDir('failure');
  lForge := TNXForge.Create;
  try
    Fixture(lDirectory, 'Group Build { Git First { Template: "command.mustache"; Repository: dot; } ' +
      'Git Later { Template: "absent.mustache"; Repository: dot; } }', ChildCommand('ok'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing later template fails preflight');
    AContext.AssertTrue(Pos('Later', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
    Fixture(lDirectory, 'Group Build { Git First { Template: "command.mustache"; Repository: dot; } ' +
      'Git Later { Template: "command.mustache"; Repository: dot; } }', ChildCommand('fail'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Nonzero child stops execution');
    AContext.AssertEquals(7, lForge.Invocations[0].ExitStatus, 'Actual child exit');
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Later operation not launched');
    AContext.AssertTrue(Pos('failure', lForge.Invocations[0].StdErr) > 0, 'Stderr retained');
    Save(lDirectory + 'command.mustache', 'nxforge-tool-that-does-not-exist-739');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing executable fails');
    AContext.AssertFalse(lForge.Invocations[0].Exited, 'No fabricated child exit');
    Save(lDirectory + 'command.mustache', '');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Empty command fails');
    AssertNoLaunch(AContext, lForge);
    Fixture(lDirectory, 'Git Restored { Template: "command.mustache"; Repository: dot; }', ChildCommand('ok'));
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(1, lForge.Invocations.Count, 'Run state reset on reuse');
  finally
    lForge.Free;
  end;
end;

procedure TestNativeTools(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lInvocation: TNXForgeInvocation;
  lDirectory: string;
begin
  lDirectory := TestDir('native tools & paths');
  Save(lDirectory + 'hello world & test.lpr', 'program Hello; begin WriteLn(''forge-ok''); end.');
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'module "' + StringReplace(Root, '\', '/', [rfReplaceAll]) + 'projects/forge/examples/Shared.nxscript"; ' +
    'Group Build { FPC Compile (CompileFPC) { Source: ["hello world & test.lpr"]; EntryPoint: "hello world & test.lpr"; Output: "hello world & test.exe"; } ' +
    'Git Inspect (GitStatus) { Repository: "."; } }');
  lInvocation := TNXForgeInvocation.Create;
  lForge := TNXForge.Create;
  try
    lInvocation.Command := 'git init --quiet';
    lInvocation.WorkingDirectory := lDirectory;
    ExecuteForgeProcess(lInvocation);
    AContext.AssertTrue(lInvocation.Succeeded, 'Local git init: ' + lInvocation.Diagnostic);
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(2, lForge.Invocations.Count, 'FPC and Git use same runner');
    AContext.AssertTrue(FileExists(lDirectory + 'hello world & test.exe'), 'FPC produced executable');
    lInvocation.Free;
    lInvocation := TNXForgeInvocation.Create;
    lInvocation.Command := '"' + lDirectory + 'hello world & test.exe"';
    lInvocation.WorkingDirectory := lDirectory;
    ExecuteForgeProcess(lInvocation);
    AContext.AssertTrue(lInvocation.Succeeded, lInvocation.Diagnostic);
    AContext.AssertEquals('forge-ok', Trim(lInvocation.StdOut), 'Produced executable runs');
  finally
    lForge.Free;
    lInvocation.Free;
  end;
end;

procedure TestWorkingDirectory(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory: string;
begin
  lDirectory := TestDir('working-directory');
  ForceDirectories(lDirectory + 'child & space');
  Fixture(lDirectory, 'Git Context { Template: "command.mustache"; Repository: dot; }', ChildCommand('cwd'));
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript', 'child & space'), lForge.Diagnostic);
    AContext.AssertEquals(ExpandFileName(lDirectory + 'child & space'),
      Trim(lForge.Invocations[0].StdOut), 'Override is relative to entry document');
  finally
    lForge.Free;
  end;
end;

procedure TestRelativeCompiler(AContext: TNXTestContext);
var
  lDirectory, lCompiler: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('relative-compiler');
  ForceDirectories(lDirectory + 'configuration');
  ForceDirectories(lDirectory + 'working');
  lCompiler := ExpandFileName(lDirectory + 'configuration/tools/compiler & test.exe');
  Save(lDirectory + 'input.pas', '');
  Save(lDirectory + 'configuration/compiler.mustache', '"{{{Compiler}}}" child cwd');
  Save(lDirectory + 'configuration/Base.nxscript',
    'FPC CompilerDefaults { Template: "compiler.mustache"; ' +
    'Compiler: "tools/compiler & test.exe"; }');
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'module "configuration/Base.nxscript"; Group Build { ' +
    'CopyFile StageCompiler { Source: "' + ParamStr(0) + '"; Destination: "' + lCompiler + '"; } ' +
    'FPC Compile (CompilerDefaults) { Source: ["input.pas"]; EntryPoint: "input.pas"; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(FileExists(lCompiler), 'Compiler is absent during preparation');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript', 'working'),
      lForge.Diagnostic);
    AContext.AssertTrue(lForge.Invocations[0].Completed, 'Compiler is staged first');
    AContext.AssertEquals('"' + lCompiler + '" child cwd', lForge.Invocations[1].Command,
      'Inherited Compiler resolves from the document supplying its value');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'working'),
      Trim(lForge.Invocations[1].StdOut),
      'The staged compiler launches with the separately selected working directory');
  finally
    lForge.Free;
  end;
end;

procedure TestStreams(AContext: TNXTestContext);
var
  lInvocation: TNXForgeInvocation;
begin
  lInvocation := TNXForgeInvocation.Create;
  try
    lInvocation.Command := ChildCommand('streams');
    lInvocation.WorkingDirectory := TestDir('streams');
    ExecuteForgeProcess(lInvocation);
    AContext.AssertTrue(lInvocation.Succeeded, lInvocation.Diagnostic);
    AContext.AssertEquals(1048576, Length(lInvocation.StdOut), 'All stdout bytes');
    AContext.AssertEquals(1048576, Length(lInvocation.StdErr), 'All stderr bytes');
    AContext.AssertEquals(StringOfChar('O', 1048576), lInvocation.StdOut, 'Distinct stdout');
    AContext.AssertEquals(StringOfChar('E', 1048576), lInvocation.StdErr, 'Distinct stderr');
  finally
    lInvocation.Free;
  end;
end;

procedure TestSourceSelections(AContext: TNXTestContext);
var
  lDirectory, lExpected: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('source-selections');
  ForceDirectories(lDirectory + 'src/nested');
  ForceDirectories(lDirectory + 'elsewhere');
  Save(lDirectory + 'src/a.pas', '');
  Save(lDirectory + 'src/b.pas', '');
  Save(lDirectory + 'src/ignored.txt', '');
  Save(lDirectory + 'src/nested/c.pas', '');
  Save(lDirectory + 'Base.nxscript', 'FPC Base { Source: ["src/a.pas"]; }');
  Fixture(lDirectory, 'module "Base.nxscript"; FPC Compile (Base) { ' +
    'Source: ["src/*.pas", "src/**/*.pas"]; EntryPoint: "src/a.pas"; ' +
    'Output: app; Template: "command.mustache"; }',
    ChildCommand('ok') + '{{#Source}} "{{{.}}}"{{/Source}}' +
    '{{#_nx.SourcePaths}} "{{{.}}}"{{/_nx.SourcePaths}}');
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript', 'elsewhere'), lForge.Diagnostic);
    AContext.AssertEquals(1, lForge.Invocations.Count, 'One command for all source selections');
    lExpected := ChildCommand('ok') + ' "' + ExpandFileName(lDirectory + 'src/a.pas') +
      '" "' + ExpandFileName(lDirectory + 'src/b.pas') +
      '" "' + ExpandFileName(lDirectory + 'src/nested/c.pas') +
      '" "' + ExpandFileName(lDirectory + 'src') +
      '" "' + ExpandFileName(lDirectory + 'src/nested') + '"';
    AContext.AssertEquals(lExpected, lForge.Invocations[0].Command,
      'Composed selections expand, deduplicate and anchor to declaration, not working directory');
    Fixture(lDirectory, 'FPC Compile { Source: ["src/*.absent"]; EntryPoint: "src/a.pas"; ' +
      'Output: app; Template: "command.mustache"; }', ChildCommand('ok'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Empty selection fails');
    AContext.AssertTrue(Pos('matched no files', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
    Fixture(lDirectory, 'FPC Compile { Source: "src/a.pas"; EntryPoint: "src/a.pas"; ' +
      'Output: app; Template: "command.mustache"; }', ChildCommand('ok'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Scalar Source is invalid');
    AssertNoLaunch(AContext, lForge);
    Fixture(lDirectory, 'FPC Compile { Source: ["src/a.pas"]; ' +
      'Output: app; Template: "command.mustache"; }', ChildCommand('ok'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Concrete FPC operation needs EntryPoint');
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestStagedSources(AContext: TNXTestContext);
var
  lDirectory, lTemplate: string;
  lForge: TNXForge;
  lRun: TNXForgeInvocation;
begin
  lDirectory := TestDir('staged-sources');
  ForceDirectories(lDirectory + 'input/nested');
  Save(lDirectory + 'input/nested/uStaged.pas',
    'unit uStaged; interface const cAnswer = 42; implementation end.');
  Save(lDirectory + 'input/main.pas',
    'program main; uses uStaged; begin WriteLn(cAnswer); end.');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'projects/forge/examples/FPC.mustache';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { CopyFile Stage { Source: "input"; Destination: "staged"; Recursive: True; } ' +
    'FPC Compile { Template: "' + lTemplate + '"; Source: ["staged/**/*.pas"]; ' +
    'EntryPoint: "staged/main.pas"; Output: "staged.exe"; UnitOutput: "staged"; } }');
  lForge := TNXForge.Create;
  lRun := TNXForgeInvocation.Create;
  try
    AContext.AssertFalse(DirectoryExists(lDirectory + 'staged'), 'Staging starts empty');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertTrue(lForge.Invocations[0].Completed, 'Source copy completed first');
    AContext.AssertTrue(lForge.Invocations[1].Succeeded, 'Compiler consumes the staged source');
    lRun.Command := '"' + lDirectory + 'staged/staged.exe"';
    lRun.WorkingDirectory := lDirectory;
    ExecuteForgeProcess(lRun);
    AContext.AssertTrue(lRun.Succeeded, lRun.Diagnostic + lRun.StdErr);
    AContext.AssertEquals('42', Trim(lRun.StdOut),
      'Recursive source selection supplied the newly copied dependency');
  finally
    lRun.Free;
    lForge.Free;
  end;
end;

procedure TestSourcePreflight(AContext: TNXTestContext);
const
  cInvalidTasks: array[0..2] of string = (
    'FPC Bad { Template: "missing.mustache"; Source: ["missing/*.pas"]; EntryPoint: "missing/main.pas"; }',
    'FPC Bad { Template: "broken.mustache"; Source: ["missing/*.pas"]; EntryPoint: "missing/main.pas"; }',
    'FPC Bad { Template: "command.mustache"; Source: invalid; EntryPoint: "missing/main.pas"; }');
var
  lDirectory, lTask: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('source-preflight');
  Save(lDirectory + 'broken.mustache', '{{#Source}}');
  lForge := TNXForge.Create;
  try
    for lTask in cInvalidTasks do
    begin
      Fixture(lDirectory, 'Group Build { ' +
        'WriteTextFile Before { Path: "never.txt"; Text: "never"; } ' + lTask + ' }',
        ChildCommand('ok'));
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'Invalid schema or command template still fails preflight');
      AssertNoLaunch(AContext, lForge);
      AContext.AssertFalse(FileExists(lDirectory + 'never.txt'),
        'Preflight failure prevents earlier filesystem changes');
    end;
  finally
    lForge.Free;
  end;
end;

procedure TestSourceExecutionFailure(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('source-execution-failure');
  Fixture(lDirectory, 'Group Build { ' +
    'WriteTextFile Before { Path: "before.txt"; Text: "before"; } ' +
    'FPC Compile { Template: "command.mustache"; Source: ["missing/*.pas"]; ' +
    'EntryPoint: "missing/main.pas"; } ' +
    'WriteTextFile After { Path: "never.txt"; Text: "never"; } }', ChildCommand('ok'));
  lForge := TNXForge.Create;
  try
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Missing sources fail when their task is reached');
    AContext.AssertEquals(3, lForge.Invocations.Count, 'All tasks passed preflight');
    AContext.AssertTrue(lForge.Invocations[0].Completed, 'Earlier task completed');
    AContext.AssertEquals('before' + #10, LoadRaw(lDirectory + 'before.txt'),
      'Earlier output is retained');
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Compiler was not launched');
    AContext.AssertFalse(lForge.Invocations[2].Started, 'Later task did not run');
    AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Later output is absent');
    AContext.AssertTrue(Pos('Source directory not found', lForge.Invocations[1].Diagnostic) > 0,
      lForge.Diagnostic);
    AContext.AssertTrue(Pos('Compile [', lForge.Diagnostic) = 1,
      'The source failure identifies its task');
  finally
    lForge.Free;
  end;
end;

procedure TestSelectedDefinition(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lEmitter: TNexusScriptJSONEmitter;
  lBefore: string;
  lJSON: TJSONData;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(Root +
      'projects/forge/test/fixtures/composition.nxscript'), lSession.LastError);
    lEmitter.AddDocument(lSession.EntryCompiler.CompiledDocument);
    lBefore := lEmitter.JSON;
    lJSON := GetJSON(lEmitter.RenderDefinition(
      lSession.EntryCompiler.CompiledDocument.FindDefinition('CompileExample'),
      lSession.EntryCompiler.CompiledDocument));
    try
      AContext.AssertEquals('hello world & test.lpr', lJSON.FindPath('EntryPoint').AsString,
        'Selected context contains direct resolved properties');
      AContext.AssertEquals('CompileExample', lJSON.FindPath('_nx.Name').AsString, 'Metadata retained');
      AContext.AssertEquals(DateToISO8601(lSession.EntryCompiler.CompiledDocument.CompiledAt),
        lJSON.FindPath('_nx.CompiledAt').AsString, 'Selected operation retains document timestamp');
      AContext.AssertTrue(lJSON.FindPath('InspectRepository') = nil, 'Other roots excluded');
      AContext.AssertEquals(lBefore, lEmitter.JSON, 'Document output unchanged');
    finally
      lJSON.Free;
    end;
  finally
    lEmitter.Free;
    lSession.Free;
  end;
end;

procedure TestRender(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lOutput: string;
  lText: TStringList;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := TestDir('render');
  ForceDirectories(lDirectory + 'config');
  Save(lDirectory + 'model.nxscript', Dialect('Schema') +
    'Table Demo TargetDB[One] { TableName: FIRST; Fields: [Field Name { Type: varchar(20); }]; } ' +
    'Table Demo TargetDB[Two] { TableName: SECOND; Fields: [Field Name { Type: varchar(20); }]; }');
  Save(lDirectory + 'config/settings.nxscript', Dialect('NexusForge') +
    'Environment Settings { Template: "text.mustache"; Source: "../model.nxscript"; Prefix: base; }');
  Save(lDirectory + 'config/text.mustache',
    '{{Environment.Prefix}}:{{#_nx.Collections.Table}}{{TableName}}{{/_nx.Collections.Table}}' + LineEnding);
  Save(lDirectory + 'config/override.nxscript', Dialect('NexusForge') +
    'module Settings "settings.nxscript"; Environment Selected (Settings) { Prefix: override; }');
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'module Selected "config/override.nxscript"; module Settings "config/settings.nxscript"; ' +
    'Render Generate { Source: @Settings.Source; Template: @Settings.Template; ' +
    'Environment: @Selected; Output: "artifact.txt"; }');
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('TargetDB', 'Two');
  lForge := TNXForge.Create(lTargets);
  lText := TStringList.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    lOutput := lDirectory + 'artifact.txt';
    lText.LoadFromFile(lOutput);
    AContext.AssertEquals('override:SECOND' + LineEnding, lText.Text,
      'Source targets, composed Environment and inherited path provenance reach rendering');
    AContext.AssertTrue(lForge.Invocations[0].Completed, 'Render completed');
    AContext.AssertFalse(lForge.Invocations[0].Exited, 'Render does not fabricate a process exit');

    Save(lDirectory + 'model.nxscript', Dialect('Schema') +
      'Table Environment { TableName: COLLISION; Fields: [Field Name { Type: varchar(20); }]; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Context collisions fail');
    AssertNoLaunch(AContext, lForge);
    AContext.AssertTrue(Pos('collides', lForge.Diagnostic) > 0, lForge.Diagnostic);
  finally
    lText.Free;
    lForge.Free;
    lTargets.Free;
  end;
end;

procedure TestRenderFailures(AContext: TNXTestContext);
var
  lForge: TNXForge;
  lDirectory, lBadSource: string;
  lIndex: Integer;
const
  cBadSources: array[0..1] of string = ('Table Broken {', 'Table Broken { Wrong: value; }');
begin
  lDirectory := TestDir('render-failures');
  Save(lDirectory + 'artifact.mustache', 'untouched');
  Save(lDirectory + 'native.mustache', ChildCommand('success'));
  Save(lDirectory + 'model.nxscript', Dialect('Schema') +
    'Table Demo { TableName: DEMO; Fields: [Field Name { Type: varchar(20); }]; }');
  lForge := TNXForge.Create;
  try
    for lIndex := 0 to 2 do
    begin
      lBadSource := 'missing.nxscript';
      if lIndex < 2 then
      begin
        lBadSource := 'bad.nxscript';
        Save(lDirectory + lBadSource, Dialect('Schema') + cBadSources[lIndex]);
      end;
      Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
        'Group Build { Render First { Source: "model.nxscript"; Template: "artifact.mustache"; Output: "never.txt"; } ' +
        'Git Next { Template: "native.mustache"; Repository: repo; } ' +
        'Render Bad { Source: "' + lBadSource + '"; Template: "artifact.mustache"; Output: "bad.txt"; } }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Bad render fails preflight');
      AssertNoLaunch(AContext, lForge);
      AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Preflight writes nothing');
    end;
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { Render Bad { Source: "model.nxscript"; Template: "artifact.mustache"; Output: "missing/out.txt"; } ' +
      'Git Next { Template: "native.mustache"; Repository: repo; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Write failure stops execution');
    AContext.AssertTrue(lForge.Invocations[0].Started, 'Write attempted');
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Later native command was not launched');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { Git First { Template: "native.mustache"; Repository: repo; } ' +
      'Render Bad { Source: "model.nxscript"; Template: "missing.mustache"; Output: "bad.txt"; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing artifact template fails');
    AssertNoLaunch(AContext, lForge);
    Save(lDirectory + 'artifact.mustache', '');
    Save(lDirectory + 'native.mustache', ChildCommand('ok'));
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { Render Empty { Source: "model.nxscript"; Template: "artifact.mustache"; Output: "empty.txt"; } ' +
      'Git Next { Template: "native.mustache"; Repository: repo; } }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertTrue(FileExists(lDirectory + 'empty.txt'), 'An empty artifact is still a file');
    AContext.AssertEquals('', lForge.Invocations[0].ArtifactText, 'Empty content is preserved');
    AContext.AssertTrue(lForge.Invocations[1].Exited, 'Mixed list executes the native command');
  finally
    lForge.Free;
  end;
end;

procedure TestCreateDirectory(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('create-directory');
  lForge := TNXForge.Create;
  try
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'CreateDirectory Units { Path: "nested output/units"; }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertTrue(DirectoryExists(lDirectory + 'nested output/units'),
      'Creates the directory and missing parents');
    AContext.AssertTrue(lForge.Invocations[0].Completed, 'Directory creation completed');
    AContext.AssertFalse(lForge.Invocations[0].Exited, 'No child process is used');

    Save(lDirectory + 'nested output/units/keep.txt', 'keep');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals('keep', LoadRaw(lDirectory + 'nested output/units/keep.txt'),
      'An existing directory succeeds and preserves its contents');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { CreateDirectory Bin { Path: "bin"; } }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript', 'nested output'),
      lForge.Diagnostic);
    AContext.AssertTrue(DirectoryExists(lDirectory + 'nested output/bin'),
      'Grouped directory creation resolves from the selected working directory');
  finally
    lForge.Free;
  end;
end;

procedure TestCreateDirectoryFailures(AContext: TNXTestContext);
var
  lDirectory, lPath: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('create-directory-failures');
  Save(lDirectory + 'occupied', 'keep');
  lForge := TNXForge.Create;
  try
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { CreateDirectory First { Path: "never"; } ' +
      'CreateDirectory Invalid { } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'A missing Path fails validation');
    AssertNoLaunch(AContext, lForge);
    AContext.AssertFalse(DirectoryExists(lDirectory + 'never'),
      'Validation failure prevents earlier directory creation');

    for lPath in ['occupied', 'occupied/child'] do
    begin
      Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
        'Group Build { CreateDirectory Blocked { Path: "' + lPath + '"; } ' +
        'WriteTextFile Later { Path: "never.txt"; Text: "never"; } }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'A file at the destination or in its parent path prevents directory creation');
      AContext.AssertTrue(Pos('Could not create directory:', lForge.Diagnostic) > 0,
        'The creation failure is reported');
      AContext.AssertFalse(lForge.Invocations[1].Started, 'Failure stops later operations');
      AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Later output is absent');
      AContext.AssertEquals('keep', LoadRaw(lDirectory + 'occupied'),
        'The blocking file is preserved');
    end;
  finally
    lForge.Free;
  end;
end;

procedure TestFileOperations(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('file-operations');
  lForge := TNXForge.Create;
  try
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { WriteTextFile Generate { Path: "source.txt"; Text: "first"; } ' +
      'CopyFile Copy { Source: "source.txt"; Destination: "copy.txt"; } ' +
      'Archive Zip { Operation: Zip; Source: "copy.txt"; Destination: "bundle.zip"; } ' +
      'DeletePath Remove { Path: "source.txt"; } ' +
      'Archive Unzip { Operation: Unzip; Source: "bundle.zip"; Destination: "extracted"; } }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertFalse(FileExists(lDirectory + 'source.txt'), 'DeletePath removed the file');
    AContext.AssertEquals('first' + #10,
      LoadRaw(lDirectory + 'extracted/copy.txt'),
      'Write, copy, ZIP and unzip preserve content');
    AContext.AssertEquals(5, lForge.Invocations.Count, 'All file operations prepared');
    AContext.AssertTrue(lForge.Invocations[4].Completed, 'Unzip completed without a process');
    AContext.AssertFalse(lForge.Invocations[4].Exited, 'Native operation has no process exit');

    ForceDirectories(lDirectory + 'tree/sub');
    ForceDirectories(lDirectory + 'destination');
    Save(lDirectory + 'tree/keep.txt', 'keep');
    Save(lDirectory + 'tree/skip.txt', 'skip');
    Save(lDirectory + 'tree/sub/nested.txt', 'nested');
    Save(lDirectory + 'destination/stale.txt', 'stale');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { CopyFile Tree { Source: "tree"; Destination: "destination"; Recursive: True; ' +
      'CleanDestination: True; ExcludeNames: "skip.txt"; } ' +
      'Archive ZipTree { Operation: Zip; Source: "tree"; Destination: "tree.zip"; ' +
      'ExcludeNames: "skip.txt"; } ' +
      'Archive ExtractTree { Operation: Unzip; Source: "tree.zip"; ' +
      'Destination: "tree-extracted"; } }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertFalse(FileExists(lDirectory + 'destination/stale.txt'),
      'CleanDestination removed old content');
    AContext.AssertFalse(FileExists(lDirectory + 'destination/skip.txt'),
      'CopyFile excluded a matching basename');
    AContext.AssertEquals('keep', LoadRaw(lDirectory + 'destination/keep.txt'),
      'Recursive copy kept the top-level file');
    AContext.AssertEquals('nested', LoadRaw(lDirectory + 'destination/sub/nested.txt'),
      'Recursive copy kept the nested file');
    AContext.AssertFalse(FileExists(lDirectory + 'tree-extracted/skip.txt'),
      'Archive excluded a matching basename');
    AContext.AssertEquals('nested',
      LoadRaw(lDirectory + 'tree-extracted/sub/nested.txt'),
      'Directory archive preserved nested content');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'DeletePath Nested { Path: "destination/*.txt"; Recursive: True; }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertFalse(FileExists(lDirectory + 'destination/keep.txt'),
      'Wildcard DeletePath removed a top-level matching file');
    AContext.AssertFalse(FileExists(lDirectory + 'destination/sub/nested.txt'),
      'Recursive mask deleted nested matching file');
    AContext.AssertTrue(DirectoryExists(lDirectory + 'destination/sub'),
      'Wildcard DeletePath retains directories');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'DeletePath Tree { Path: "destination"; Recursive: True; }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertFalse(DirectoryExists(lDirectory + 'destination'),
      'Recursive DeletePath removed the directory');
  finally
    lForge.Free;
  end;
end;

procedure TestCopyIncludeMasks(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('copy-include-masks');
  ForceDirectories(lDirectory + 'source/nested');
  ForceDirectories(lDirectory + 'source/excluded');
  ForceDirectories(lDirectory + 'destination');
  Save(lDirectory + 'source/main.pas', 'program');
  Save(lDirectory + 'source/nested/unit.pp', 'unit');
  Save(lDirectory + 'source/nested/shared.inc', 'include');
  Save(lDirectory + 'source/nested/UNIT.PAS', 'uppercase');
  Save(lDirectory + 'source/nested/unit.o', 'object');
  Save(lDirectory + 'source/main.exe', 'executable');
  Save(lDirectory + 'source/msgidx.inc', 'generated');
  Save(lDirectory + 'source/excluded/hidden.pas', 'excluded');
  Save(lDirectory + 'destination/stale.pas', 'stale');
  lForge := TNXForge.Create;
  try
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'CopyFile Stage { Source: "source"; Destination: "destination"; Recursive: True; ' +
      'CleanDestination: True; IncludeMasks: ["*.pas", "*.pp", "*.inc", "main.*"]; ' +
      'ExcludeNames: "msgidx.inc;excluded;main.exe"; }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals('program', LoadRaw(lDirectory + 'destination/main.pas'),
      'Overlapping masks copy a file once without requiring Overwrite');
    AContext.AssertEquals('unit', LoadRaw(lDirectory + 'destination/nested/unit.pp'),
      'Masks do not filter directory traversal');
    AContext.AssertEquals('include', LoadRaw(lDirectory + 'destination/nested/shared.inc'),
      'All supplied extensions are included');
    {$IFDEF WINDOWS}
    AContext.AssertTrue(FileExists(lDirectory + 'destination/nested/UNIT.PAS'),
      'Windows filename matching ignores case');
    {$ELSE}
    AContext.AssertFalse(FileExists(lDirectory + 'destination/nested/UNIT.PAS'),
      'Filename matching is case-sensitive outside Windows');
    {$ENDIF}
    AContext.AssertFalse(FileExists(lDirectory + 'destination/nested/unit.o'),
      'Unmatched artifacts are not copied');
    AContext.AssertFalse(FileExists(lDirectory + 'destination/main.exe'),
      'Excluded names take precedence over masks');
    AContext.AssertFalse(FileExists(lDirectory + 'destination/msgidx.inc'),
      'Generated includes are excluded');
    AContext.AssertFalse(DirectoryExists(lDirectory + 'destination/excluded'),
      'Excluded directories are not traversed');
    AContext.AssertFalse(FileExists(lDirectory + 'destination/stale.pas'),
      'CleanDestination removes stale files even when they match a mask');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Copy { ' +
      'CopyFile Match { Source: "source/main.pas"; Destination: "single.pas"; ' +
      'IncludeMasks: ["ma?n.pas"]; } ' +
      'CopyFile Miss { Source: "source/main.exe"; Destination: "never.exe"; ' +
      'IncludeMasks: ["*.pas"]; } ' +
      'CopyFile Empty { Source: "source"; Destination: "empty"; Recursive: True; ' +
      'IncludeMasks: ["*.missing"]; } }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals('program', LoadRaw(lDirectory + 'single.pas'),
      'A question mark matches one character for a single-file source');
    AContext.AssertFalse(FileExists(lDirectory + 'never.exe'),
      'An unmatched single-file source is skipped');
    AContext.AssertTrue(DirectoryExists(lDirectory + 'empty/nested'),
      'An unmatched recursive copy can create empty directories');
    AContext.AssertFalse(FileExists(lDirectory + 'empty/main.pas'),
      'No matches succeeds without copying files');
  finally
    lForge.Free;
  end;
end;

procedure TestCopyIncludeMasksFailures(AContext: TNXTestContext);
var
  lDirectory, lMasks: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('copy-include-masks-failures');
  lForge := TNXForge.Create;
  try
    for lMasks in ['"*.pas"', '[]', '[""]', '["nested/*.pas"]',
      '["nested\*.pas"]', '["C:*.pas"]'] do
    begin
      Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
        'Group Copy { WriteTextFile First { Path: "never.txt"; Text: "never"; } ' +
        'CopyFile Invalid { Source: "source"; Destination: "destination"; ' +
        'Recursive: True; IncludeMasks: ' + lMasks + '; } }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'Invalid IncludeMasks must fail before execution: ' + lMasks);
      AssertNoLaunch(AContext, lForge);
      AContext.AssertFalse(FileExists(lDirectory + 'never.txt'),
        'Invalid IncludeMasks prevents earlier file operations');
    end;
  finally
    lForge.Free;
  end;
end;

procedure TestCompareFiles(AContext: TNXTestContext);
var
  lDirectory, lData: string;
  lForge: TNXForge;
  lIndex: Integer;
begin
  lDirectory := TestDir('compare-files');
  ForceDirectories(lDirectory + 'working & files');
  SetLength(lData, 131077);
  for lIndex := 1 to Length(lData) do lData[lIndex] := Chr(lIndex mod 256);
  Save(lDirectory + 'working & files/left.bin', lData);
  Save(lDirectory + 'working & files/right.bin', lData);
  Save(lDirectory + 'working & files/empty.bin', '');
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Verify { CompareFiles Binary { Left: "left.bin"; Right: "' +
    ExpandFileName(lDirectory + 'working & files/right.bin') + '"; } ' +
    'CopyFile EmptyCopy { Source: "empty.bin"; Destination: "empty-copy.bin"; } ' +
    'CompareFiles Empty { Left: "empty.bin"; Right: "empty-copy.bin"; } ' +
    'CompareFiles Same { Left: "left.bin"; Right: "left.bin"; } ' +
    'WriteTextFile Later { Path: "passed.txt"; Text: "passed"; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript', 'working & files'),
      lForge.Diagnostic);
    AContext.AssertEquals(ExpandFileName(lDirectory + 'working & files/left.bin'),
      lForge.Invocations[0].LeftPath, 'Relative comparison path uses the selected working directory');
    AContext.AssertTrue(lForge.Invocations[0].Completed, 'Binary comparison completes');
    AContext.AssertFalse(lForge.Invocations[0].Exited, 'Comparison launches no process');
    AContext.AssertTrue(lForge.Invocations[2].Completed, 'An earlier task can produce an input');
    AContext.AssertTrue(FileExists(lDirectory + 'working & files/passed.txt'),
      'Equal files allow later tasks to run');
    AContext.AssertEquals(lData, LoadRaw(lDirectory + 'working & files/left.bin'),
      'Comparison preserves the left input');
    AContext.AssertEquals(lData, LoadRaw(lDirectory + 'working & files/right.bin'),
      'Comparison preserves the right input');
  finally
    lForge.Free;
  end;
end;

procedure TestCompareFilesDifferences(AContext: TNXTestContext);
const
  cOffsets: array[0..3] of Integer = (0, 65535, 65536, 131076);
var
  lDirectory, lData, lChanged: string;
  lOffset: Integer;
  lForge: TNXForge;

  procedure CheckDifference(const ARight: string; AOffset: Integer);
  begin
    Save(lDirectory + 'right.bin', ARight);
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Different files fail comparison');
    AContext.AssertTrue(Pos('byte offset ' + IntToStr(AOffset), lForge.Diagnostic) > 0,
      lForge.Diagnostic);
    AContext.AssertTrue(Pos(ExpandFileName(lDirectory + 'left.bin'), lForge.Diagnostic) > 0,
      'Mismatch identifies the left file');
    AContext.AssertTrue(Pos(ExpandFileName(lDirectory + 'right.bin'), lForge.Diagnostic) > 0,
      'Mismatch identifies the right file');
    AContext.AssertTrue(lForge.Invocations[1].Started, 'Comparison was attempted');
    AContext.AssertFalse(lForge.Invocations[1].Completed, 'Mismatch does not mark completion');
    AContext.AssertFalse(lForge.Invocations[2].Started, 'Mismatch stops later tasks');
    AContext.AssertTrue(FileExists(lDirectory + 'before.txt'), 'Earlier output is retained');
    AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Later output is absent');
    AContext.AssertEquals(ARight, LoadRaw(lDirectory + 'right.bin'), 'Right input is unchanged');
  end;

begin
  lDirectory := TestDir('compare-files-differences');
  lData := StringOfChar(#0, 131077);
  Save(lDirectory + 'left.bin', lData);
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Verify { WriteTextFile Before { Path: "before.txt"; Text: "before"; } ' +
    'CompareFiles Check { Left: "left.bin"; Right: "right.bin"; } ' +
    'WriteTextFile Later { Path: "never.txt"; Text: "never"; } }');
  lForge := TNXForge.Create;
  try
    for lOffset in cOffsets do
    begin
      lChanged := lData;
      lChanged[lOffset + 1] := #255;
      CheckDifference(lChanged, lOffset);
    end;
    CheckDifference(lData + #0, Length(lData));
    CheckDifference(Copy(lData, 1, Length(lData) - 1), Length(lData) - 1);
    lChanged := Copy(lData, 1, Length(lData) - 1);
    lChanged[65537] := #1;
    CheckDifference(lChanged, 65536);
    CheckDifference('', 0);
  finally
    lForge.Free;
  end;
end;

procedure TestCompareFilesErrors(AContext: TNXTestContext);
var
  lDirectory, lProperties: string;
  lForge: TNXForge;
  {$IFDEF WINDOWS}lLocked: TFileStream;{$ENDIF}
begin
  lDirectory := TestDir('compare-files-errors');
  Save(lDirectory + 'input.bin', 'input');
  ForceDirectories(lDirectory + 'folder');
  lForge := TNXForge.Create;
  try
    for lProperties in ['Left: "input.bin";', 'Right: "input.bin";',
      'Left: []; Right: "input.bin";', 'Left: ""; Right: "input.bin";'] do
    begin
      Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
        'Group Verify { WriteTextFile Before { Path: "never.txt"; Text: "never"; } ' +
        'CompareFiles Invalid { ' + lProperties + ' } }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'Invalid comparison properties fail preflight');
      AssertNoLaunch(AContext, lForge);
      AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Preflight failure writes nothing');
    end;
    for lProperties in ['Left: "missing.bin"; Right: "input.bin";',
      'Left: "input.bin"; Right: "missing.bin";',
      'Left: "folder"; Right: "input.bin";'] do
    begin
      Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
        'Group Verify { CompareFiles Check { ' + lProperties + ' } ' +
        'WriteTextFile Later { Path: "never.txt"; Text: "never"; } }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
        'Missing files and directories fail comparison');
      AContext.AssertTrue(Pos('is not a file', lForge.Diagnostic) > 0, lForge.Diagnostic);
      AContext.AssertFalse(lForge.Invocations[1].Started, 'Input failure stops later tasks');
    end;
    {$IFDEF WINDOWS}
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'CompareFiles Locked { Left: "input.bin"; Right: "input.bin"; }');
    lLocked := TFileStream.Create(lDirectory + 'input.bin', fmOpenReadWrite or fmShareExclusive);
    try
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Open errors fail comparison');
      AContext.AssertTrue(Pos('input.bin', lForge.Diagnostic) > 0, 'Open error identifies the input');
    finally
      lLocked.Free;
    end;
    {$ENDIF}
  finally
    lForge.Free;
  end;
end;

procedure TestFileOperationFailures(AContext: TNXTestContext);
var
  lDirectory: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('file-operation-failures');
  Save(lDirectory + 'source.txt', 'source');
  Save(lDirectory + 'destination.txt', 'destination');
  lForge := TNXForge.Create;
  try
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { WriteTextFile First { Path: "never.txt"; Text: "never"; } ' +
      'DeletePath Invalid { Path: "missing.txt"; Recursive: "not boolean"; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Invalid boolean fails validation');
    AssertNoLaunch(AContext, lForge);
    AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Preflight writes nothing');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { WriteTextFile First { Path: "never.txt"; Text: "never"; } ' +
      'Archive Invalid { Operation: Tar; Source: "source.txt"; ' +
      'Destination: "never.zip"; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Invalid archive operation fails preparation');
    AssertNoLaunch(AContext, lForge);
    AContext.AssertFalse(FileExists(lDirectory + 'never.txt'),
      'Invalid archive operation leaves earlier output absent');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Build { CopyFile Existing { Source: "source.txt"; Destination: "destination.txt"; } ' +
      'WriteTextFile Later { Path: "never.txt"; Text: "never"; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'Existing destination fails without Overwrite');
    AContext.AssertTrue(lForge.Invocations[0].Started, 'Copy was attempted');
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Failure stops later operation');
    AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Later operation did not run');

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'DeletePath Missing { Path: "missing.txt"; MissingOk: False; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'),
      'MissingOk False reports a missing path');
  finally
    lForge.Free;
  end;
end;

procedure TestBuildIdentity(AContext: TNXTestContext);
var
  lDirectory, lRepository, lOutput, lRevision, lEpoch, lCommand: string;
  lIdentityText, lOptionsText, lRevisionText, lInvalid: string;
  lForge: TNXForge;
  lRecord: TJSONObject;
  lRejected: Boolean;
  lDateSeparator, lTimeSeparator: Char;

  function Git(const AArguments: string): string;
  var
    lInvocation: TNXForgeInvocation;
  begin
    lInvocation := TNXForgeInvocation.Create;
    try
      lInvocation.Command := 'git ' + AArguments;
      lInvocation.WorkingDirectory := lRepository;
      ExecuteForgeProcess(lInvocation);
      AContext.AssertTrue(lInvocation.Succeeded,
        AArguments + ': ' + lInvocation.Diagnostic + lInvocation.StdErr);
      Result := Trim(lInvocation.StdOut);
    finally
      lInvocation.Free;
    end;
  end;

  procedure CheckRecord(ADirty: Boolean; const AEpoch: string);
  var
    lExpectedIdentity: string;
  begin
    lRecord := GetJSON(LoadRaw(lOutput + 'build-identity.json')) as TJSONObject;
    try
      lExpectedIdentity := lRevision;
      if ADirty then lExpectedIdentity := lExpectedIdentity + '-dirty';
      AContext.AssertEquals(lRevision, lRecord.Get('Revision', ''));
      AContext.AssertTrue(ADirty = lRecord.Booleans['Dirty'], 'Dirty state');
      AContext.AssertEquals(lExpectedIdentity, lRecord.Get('Identity', ''));
      AContext.AssertEquals(AEpoch, lRecord.Find('SourceDateEpoch').AsString);
      AContext.AssertEquals(QuotedStr(lExpectedIdentity) + #10,
        LoadRaw(lOutput + 'source/revision.inc'), 'Pascal identity is quoted with LF and no BOM');
      AContext.AssertEquals('-DD' + lRecord.Get('Date', '') + #10 +
        '-DT' + lRecord.Get('Time', '') + #10,
        LoadRaw(lOutput + 'build-options.cfg'), 'Compiler options match the record');
    finally
      lRecord.Free;
    end;
  end;
begin
  lDirectory := TestDir('build identity');
  lRepository := lDirectory + 'repository & source/';
  lOutput := lRepository + 'build/seed/';
  ForceDirectories(lRepository);
  Save(lRepository + '.gitignore', '/build/' + #10);
  Save(lRepository + 'version.pas', 'unit version;' + #10);
  Git('init -q');
  Git('add .');
  Git('-c user.name=ForgeIdentityTest -c user.email=forge@example.invalid ' +
    '-c commit.gpgSign=false commit -qm Fixture');
  lRevision := Git('rev-parse HEAD');
  lEpoch := GetEnvironmentVariable('SOURCE_DATE_EPOCH');
  if lEpoch = '' then lEpoch := Git('show -s --format=%ct HEAD');
  lCommand := 'BuildIdentity Capture { Repository: "repository & source"; ' +
    'OutputDirectory: "repository & source/build/seed"; } ';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Project Bootstrap { Id: "NXRP.IdentityTest"; ' +
    'CreateDirectory Stage { Path: "repository & source/build/seed/source"; } ' +
    'CopyFile Source { Source: "repository & source/version.pas"; ' +
    'Destination: "repository & source/build/seed/source/version.pas"; Overwrite: True; } ' +
    'Group Metadata { ' + lCommand + '} ' +
    'CopyFile Consume { Source: "repository & source/build/seed/build-identity.json"; ' +
    'Destination: "captured.json"; Overwrite: True; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertTrue(lForge.Invocations[2].Completed, 'Identity runs after source staging');
    AContext.AssertFalse(lForge.Invocations[2].Exited, 'File operation has no process exit status');
    AContext.AssertEquals('', lForge.Invocations[2].TemplatePath, 'No command template');
    CheckRecord(False, lEpoch);
    AContext.AssertEquals(LoadRaw(lOutput + 'build-identity.json'),
      LoadRaw(lDirectory + 'captured.json'), 'Following child consumes newly written identity');
    lDateSeparator := DefaultFormatSettings.DateSeparator;
    lTimeSeparator := DefaultFormatSettings.TimeSeparator;
    try
      DefaultFormatSettings.DateSeparator := '-';
      DefaultFormatSettings.TimeSeparator := '.';
      WriteForgeBuildIdentity(lRepository, lOutput, '1234567890');
    finally
      DefaultFormatSettings.DateSeparator := lDateSeparator;
      DefaultFormatSettings.TimeSeparator := lTimeSeparator;
    end;
    CheckRecord(False, '1234567890');
    AContext.AssertEquals('-DD2009/02/13' + #10 + '-DT23:31:30' + #10,
      LoadRaw(lOutput + 'build-options.cfg'), 'Fixed UTC epoch and locale-independent separators');
    lIdentityText := LoadRaw(lOutput + 'build-identity.json');
    WriteForgeBuildIdentity(lRepository, lOutput, '1234567890');
    AContext.AssertEquals(lIdentityText, LoadRaw(lOutput + 'build-identity.json'), 'Repeatable capture');
    Save(lRepository + 'version.pas', 'modified');
    WriteForgeBuildIdentity(lRepository, lOutput, '1234567890');
    CheckRecord(True, '1234567890');
    Git('restore version.pas');
    Save(lRepository + 'new.pas', 'untracked');
    WriteForgeBuildIdentity(lRepository, lOutput, '1234567890');
    CheckRecord(True, '1234567890');
    lIdentityText := LoadRaw(lOutput + 'build-identity.json');
    lOptionsText := LoadRaw(lOutput + 'build-options.cfg');
    lRevisionText := LoadRaw(lOutput + 'source/revision.inc');
    for lInvalid in ['invalid', '-1', '$10', '0x10', '9223372036854775808', '253402300800'] do
    begin
      lRejected := False;
      try
        WriteForgeBuildIdentity(lRepository, lOutput, lInvalid);
      except
        on E: Exception do lRejected := Pos('timestamp must be', E.Message) > 0;
      end;
      AContext.AssertTrue(lRejected, 'Reject invalid epoch ' + lInvalid);
      AContext.AssertEquals(lIdentityText, LoadRaw(lOutput + 'build-identity.json'));
      AContext.AssertEquals(lOptionsText, LoadRaw(lOutput + 'build-options.cfg'));
      AContext.AssertEquals(lRevisionText, LoadRaw(lOutput + 'source/revision.inc'));
    end;
    WriteForgeBuildIdentity(lRepository, lOutput, '0');
    AContext.AssertEquals('-DD1970/01/01' + #10 + '-DT00:00:00' + #10,
      LoadRaw(lOutput + 'build-options.cfg'), 'Unix epoch zero is valid');
    WriteForgeBuildIdentity(lRepository, lOutput, '');
    CheckRecord(True, Git('show -s --format=%ct HEAD'));

    DeleteFile(lOutput + 'source/version.pas');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Failure { ' + lCommand + 'WriteTextFile Later { Path: "never.txt"; Text: "bad"; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing staged source fails');
    AContext.AssertTrue(Pos('must be staged', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Capture failure stops the next child');
    AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'No later artifact');

    Save(lOutput + 'source/version.pas', 'unit version;');
    ForceDirectories(lDirectory + 'empty repository');
    lRepository := lDirectory + 'empty repository/';
    Git('init -q');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'BuildIdentity MissingHEAD { Repository: "empty repository"; ' +
      'OutputDirectory: "repository & source/build/seed"; }');
    lIdentityText := LoadRaw(lOutput + 'build-identity.json');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing HEAD fails');
    AContext.AssertTrue(Pos('rev-parse', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AContext.AssertEquals(lIdentityText, LoadRaw(lOutput + 'build-identity.json'));

    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Group Invalid { WriteTextFile First { Path: "never.txt"; Text: "bad"; } ' +
      'BuildIdentity MissingOutput { Repository: "."; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Required output is validated');
    AssertNoLaunch(AContext, lForge);
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'BuildIdentity Empty { Repository: ""; OutputDirectory: "output"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Empty repository is rejected');
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestCompilationTimestamp(AContext: TNXTestContext);
var
  lDirectory, lCommand: string;
  lForge: TNXForge;
begin
  lDirectory := TestDir('timestamp');
  lCommand := ChildCommand('ok');
  Save(lDirectory + 'stamp.mustache', lCommand + ' {{_nx.CompiledAt}}');
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Group Build { Git First { Template: "stamp.mustache"; Repository: repo; } ' +
    'Git Second { Template: "stamp.mustache"; Repository: repo; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(lForge.Invocations[0].Command, lForge.Invocations[1].Command,
      'Operations share the entry document timestamp');
    lCommand := Copy(lForge.Invocations[0].Command, Length(lCommand) + 2, MaxInt);
    AContext.AssertEquals(24, Length(lCommand), 'Template receives ISO 8601 timestamp with milliseconds');
    AContext.AssertEquals('Z', Copy(lCommand, 24, 1), 'Timestamp explicitly identifies UTC');
    AContext.AssertTrue(ISO8601ToDate(lCommand) > 0, 'Timestamp is parseable');
  finally
    lForge.Free;
  end;
end;

procedure TestCommandLinePathValues(AContext: TNXTestContext);
var
  lRejected: Boolean;
begin
  TNXCommandLine.ClearRegisteredFlags;
  try
    TNXCommandLine.RegisterFlag('input', True, True, '', 'Source');
    TNXCommandLine.ParseArguments(['/input=some/folder/file.csv']);
    TNXCommandLine.Validate;
    AContext.AssertEquals('some/folder/file.csv', TNXCommandLine.GetValueDefault('input', ''),
      'Slash characters belong to the value, not the flag name');
    lRejected := False;
    try
      TNXCommandLine.ParseArguments(['//input=file.csv']);
    except
      on E: ENXCommandLine do lRejected := True;
    end;
    AContext.AssertTrue(lRejected, 'Extra slash in the flag name remains invalid');
  finally
    TNXCommandLine.ClearRegisteredFlags;
  end;
end;

procedure TestCSVTool(AContext: TNXTestContext);
var
  lDirectory, lTool, lTemplate, lOutput: string;
  lForge: TNXForge;
  lText: TStringList;
begin
  lDirectory := TestDir('csv source & output');
  ForceDirectories(lDirectory + 'artifacts');
  lTool := StringReplace(ExpandFileName(Root + 'output/NexusCSV/x86_64-win64/nxcsv.exe'), '\', '/', [rfReplaceAll]);
  AContext.AssertTrue(FileExists(lTool), 'Build projects/csv/NexusCSV.lpi first');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) + 'projects/csv/templates/SQL.mustache';
  Save(lDirectory + 'source.csv', 'ID,NAME,NOTE' + LineEnding +
    '1,O''Brien,"comma, and ""quote"""' + LineEnding + '2,,' + LineEnding);
  Save(lDirectory + 'native.mustache', ChildCommand('ok'));
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'module "' + StringReplace(Root, '\', '/', [rfReplaceAll]) + 'projects/csv/config/CSV.nxscript"; ' +
    'Group Build { CSV Generate (CompileCSV) { Compiler: "' + lTool + '"; Source: "source.csv"; ' +
    'SourceTemplate: "' + lTemplate + '"; Output: "artifacts/seed.sql"; Name: DEMO; } ' +
    'Git Next { Template: "native.mustache"; Repository: repo; } }');
  lForge := TNXForge.Create;
  lText := TStringList.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertTrue(lForge.Invocations[0].Exited, 'CSV is an ordinary native compiler invocation');
    lOutput := lDirectory + 'artifacts/seed.sql';
    lText.LoadFromFile(lOutput);
    AContext.AssertTrue(Pos('''O''''Brien''', lText.Text) > 0, 'Template explicitly SQL-quotes apostrophes');
    AContext.AssertTrue(Pos('comma, and "quote"', lText.Text) > 0, 'CSV quoting is preserved');
    AContext.AssertTrue(Pos('VALUES (''2'', '''', '''');', lText.Text) > 0, 'Empty fields remain empty strings');
    AContext.AssertTrue(lForge.Invocations[1].Succeeded, 'Next ordinary command executes');
    Save(lDirectory + 'source.csv', 'ID,NAME' + LineEnding + '1' + LineEnding);
    Save(lOutput, 'previous artifact');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Bad CSV fails the operation');
    AContext.AssertTrue(lForge.Invocations[0].ExitStatus <> 0, 'Tool reports a failed compilation');
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Failure stops later operations');
    lText.LoadFromFile(lOutput);
    AContext.AssertEquals('previous artifact', Trim(lText.Text), 'Failed input preserves existing output');

    Save(lDirectory + 'source.csv', 'ID' + #9 + 'NAME' + LineEnding + '1' + #9 + 'O''Brien' + LineEnding);
    Save(lDirectory + 'plain.mustache', '{{#DataSource.Records}}{{#.}}[{{{.}}}]{{/.}}{{/DataSource.Records}}');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'module "' + StringReplace(Root, '\', '/', [rfReplaceAll]) + 'projects/csv/config/CSV.nxscript"; ' +
      'CSV Plain (CompileCSV) { Compiler: "' + lTool + '"; Source: "source.csv"; ' +
      'Delimiter: tab; SourceTemplate: "plain.mustache"; Output: "artifacts/plain.txt"; }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    lText.LoadFromFile(lDirectory + 'artifacts/plain.txt');
    AContext.AssertEquals('[1][O''Brien]', Trim(lText.Text), 'Non-SQL template receives original data unchanged');
  finally
    lText.Free;
    lForge.Free;
  end;
end;

procedure TestPackageSDKOptions(AContext: TNXTestContext);
const
  cExpected = '7B68E268877E024A8AFC598A652C8A74F777EA68D755A2F61D1DAF172725F40D';
var
  lDirectory, lSDK, lCommand, lFirstBuild, lPath, lBefore, lOriginal: string;
  lForge: TNXForge;
  lRecord: TJSONObject;
  lIndex: Integer;
begin
  lDirectory := TestDir('package sdk & paths');
  lSDK := lDirectory + 'sdk/';
  ForceDirectories(lSDK + 'bin');
  ForceDirectories(lSDK + 'work/rtl-units');
  ForceDirectories(lDirectory + 'bootstrap/seed/rtl/inc');
  Save(lSDK + 'bin/ppcx64.exe', 'compiler');
  Save(lSDK + 'work/rtl-units/z.o', 'object');
  Save(lSDK + 'work/rtl-units/a.ppu', 'unit');
  Save(lDirectory + 'bootstrap/seed/rtl/inc/sample.inc', 'source');
  Save(lDirectory + 'bootstrap/seed/build-options.cfg', 'options');
  lCommand := 'PackageSDKOptions Identity { BootstrapDirectory: "bootstrap"; OutputDirectory: "sdk"; } ';
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'Project SDK { Id: "NXRP.SDKTest"; Group Prepare { ' + lCommand + '} ' +
    'CopyFile Consume { Source: "sdk/work/identity.json"; Destination: "copied.json"; Overwrite: True; } }');
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(LoadRaw(lSDK + 'work/identity.json'), LoadRaw(lDirectory + 'copied.json'));
    lRecord := GetJSON(LoadRaw(lSDK + 'work/identity.json')) as TJSONObject;
    try
      AContext.AssertEquals(cExpected, lRecord.Get('SDK', ''), 'Independent SHA-256 fingerprint vector');
      lFirstBuild := lRecord.Get('Build', '');
      AContext.AssertEquals(32, Length(lFirstBuild));
      AContext.AssertEquals('-Fj' + cExpected + #10 + '-Fk' + lFirstBuild + #10,
        LoadRaw(lSDK + 'work/foundation.cfg'));
      AContext.AssertEquals('-Fj' + cExpected + #10 + '-Fp' +
        StringReplace(ExpandFileName(lSDK), '\', '/', [rfReplaceAll]) +
        'packages' + #10 + '-FPnxrtl' + #10, LoadRaw(lSDK + 'work/startup.cfg'));
    finally
      lRecord.Free;
    end;
    for lIndex := 0 to 3 do
    begin
      case lIndex of
        0: lPath := lSDK + 'bin/ppcx64.exe';
        1: lPath := lSDK + 'work/rtl-units/z.o';
        2: lPath := lDirectory + 'bootstrap/seed/rtl/inc/sample.inc';
        3: lPath := lDirectory + 'bootstrap/seed/build-options.cfg';
      end;
      lOriginal := LoadRaw(lPath);
      Save(lPath, lOriginal + ' changed');
      WriteForgePackageSDKOptions(lDirectory + 'bootstrap', lSDK);
      lRecord := GetJSON(LoadRaw(lSDK + 'work/identity.json')) as TJSONObject;
      try
        AContext.AssertTrue(cExpected <> lRecord.Get('SDK', ''), 'Every input category affects the identity');
      finally
        lRecord.Free;
      end;
      Save(lPath, lOriginal);
    end;
    WriteForgePackageSDKOptions(lDirectory + 'bootstrap', lSDK);
    lRecord := GetJSON(LoadRaw(lSDK + 'work/identity.json')) as TJSONObject;
    try
      AContext.AssertEquals(cExpected, lRecord.Get('SDK', ''), 'Stable SDK identity');
      AContext.AssertTrue(lFirstBuild <> lRecord.Get('Build', ''), 'Fresh foundation build identity');
    finally
      lRecord.Free;
    end;
    lBefore := LoadRaw(lSDK + 'work/identity.json');
    DeleteFile(lDirectory + 'bootstrap/seed/build-options.cfg');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') + 'Group Failure { ' + lCommand +
      'WriteTextFile Later { Path: "never.txt"; Text: "bad"; } }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing input fails options');
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Failure stops later tasks');
    AContext.AssertEquals(lBefore, LoadRaw(lSDK + 'work/identity.json'));
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'PackageSDKOptions Bad { BootstrapDirectory: "bootstrap"; OutputDirectory: ""; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Empty SDK path rejected');
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure TestPackageSDKManifest(AContext: TNXTestContext);
var
  lDirectory, lSDK, lIdentity, lBuild, lPCP, lImage, lBinary, lManifest, lCommand: string;
  lForge: TNXForge;
  lRecord: TJSONObject;
  lInvocation: TNXForgeInvocation;
  lIndex: Integer;

  procedure PutNumber(AOffset: Integer; AValue: QWord; ASize: Integer);
  var
    lByte: Integer;
  begin
    for lByte := 0 to ASize - 1 do
      lBinary[AOffset + lByte + 1] := Chr((AValue shr (8 * lByte)) and $FF);
  end;

  procedure PutText(AOffset: Integer; const AText: string);
  begin
    Move(AText[1], lBinary[AOffset + 1], Length(AText));
  end;

  function ShortText(const AText: string): string;
  begin
    Result := Chr(Length(AText)) + AText;
  end;

  function Entry(AKind: Byte; const AText: string): string;
  begin
    lBinary := StringOfChar(#0, 6);
    PutNumber(0, Length(AText), 4);
    PutNumber(4, 1, 1);
    PutNumber(5, AKind, 1);
    Result := lBinary + AText;
  end;

  procedure Reject(const AMessage: string);
  begin
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), AMessage);
    AContext.AssertFalse(lForge.Invocations[1].Started, AMessage + ' stops later tasks');
    AContext.AssertEquals(lManifest, LoadRaw(lSDK + 'sdk.json'), AMessage + ' preserves manifest');
  end;
begin
  lDirectory := TestDir('package manifest & paths');
  lSDK := lDirectory + 'sdk/';
  ForceDirectories(lSDK + 'bin');
  ForceDirectories(lSDK + 'work');
  ForceDirectories(lSDK + 'packages');
  ForceDirectories(lSDK + 'units');
  lIdentity := StringOfChar('A', 64);
  lBuild := StringOfChar('B', 32);
  Save(lSDK + 'work/identity.json', '{"SDK":"' + lIdentity + '","Build":"' + lBuild + '"}');
  lPCP := 'NXP004' + StringOfChar(#0, 26) + Entry(93, ShortText('nxrtl')) +
    Entry(92, ShortText('nxrtl.dll') + ShortText(lIdentity) + ShortText(lBuild)) + Entry(255, '');
  lBinary := StringOfChar(#0, $600);
  PutText(0, 'MZ');
  PutNumber(60, $80, 4);
  PutNumber($80, $4550, 4);
  PutNumber($84, $8664, 2);
  PutNumber($86, 1, 2);
  PutNumber($94, $F0, 2);
  PutNumber($98, $20B, 2);
  PutNumber($B0, $180000000, 8);
  PutNumber($104, 16, 4);
  PutNumber($108, $1000, 4);
  PutNumber($10C, $80, 4);
  PutNumber($194, $1000, 4); // Section RVA.
  PutNumber($198, $400, 4); // Raw section size.
  PutNumber($19C, $200, 4); // Raw section position.
  PutNumber($214, 1, 4); // Export function count.
  PutNumber($218, 1, 4); // Export name count.
  PutNumber($21C, $1048, 4);
  PutNumber($220, $1040, 4);
  PutNumber($224, $1044, 4);
  PutNumber($240, $1050, 4);
  PutNumber($248, $1080, 4);
  PutText($250, 'FPC_PACKAGE_INFO' + #0);
  PutNumber($280, $180001100, 8);
  PutNumber($300, $4E58504B, 8);
  PutNumber($308, 4, 8);
  PutNumber($310, 168, 8);
  PutNumber($330, $180001200, 8);
  PutNumber($390, $180001250, 8);
  PutNumber($398, $1800012A0, 8);
  PutText($400, ShortText('nxrtl'));
  PutText($450, ShortText(lIdentity));
  PutText($4A0, ShortText(lBuild));
  lImage := lBinary;
  Save(lSDK + 'packages/nxrtl.pcp', lPCP);
  Save(lSDK + 'packages/nxrtl.dll', lImage);
  Save(lSDK + 'units/startup.ppu', 'abc');
  Save(lDirectory + 'version.pas', 'program Version; begin WriteLn(''3.3.1''); end.');
  lInvocation := TNXForgeInvocation.Create;
  try
    lInvocation.WorkingDirectory := lDirectory;
    lInvocation.Command := 'fpc "version.pas" "-osdk/bin/ppcx64.exe"';
    ExecuteForgeProcess(lInvocation);
    AContext.AssertTrue(lInvocation.Succeeded, lInvocation.Diagnostic + lInvocation.StdOut + lInvocation.StdErr);
  finally
    lInvocation.Free;
  end;
  lCommand := Dialect('NexusForge') + 'Group Publish { PackageSDKManifest Manifest { Directory: "sdk"; } ' +
    'WriteTextFile Later { Path: "passed.txt"; Text: "ok"; } }';
  Save(lDirectory + 'Build.nxscript', lCommand);
  lForge := TNXForge.Create;
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    lManifest := LoadRaw(lSDK + 'sdk.json');
    lRecord := GetJSON(lManifest) as TJSONObject;
    try
      AContext.AssertEquals(2, lRecord.Get('Format', 0));
      AContext.AssertEquals('3.3.1', lRecord.Get('CompilerVersion', ''));
      AContext.AssertEquals(lIdentity, lRecord.Get('SDKIdentity', ''));
      AContext.AssertEquals(4, lRecord.Arrays['Artifacts'].Count);
      AContext.AssertEquals('units/startup.ppu', lRecord.Arrays['Artifacts'].Objects[3].Get('Path', ''));
      AContext.AssertEquals('BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD',
        lRecord.Arrays['Artifacts'].Objects[3].Get('SHA256', ''), 'Known SHA-256 artifact vector');
    finally
      lRecord.Free;
    end;
    // Corrupt separate structures; every failure must preserve the prior manifest.
    for lIndex := 0 to 8 do
    begin
      lBinary := lImage;
      case lIndex of
        0: PutNumber($308, 5, 8); // Wrong runtime descriptor ABI.
        1: PutNumber($244, 1, 2); // Export ordinal beyond function table.
        2: PutNumber($280, 0, 8); // Invalid descriptor pointer.
        3: PutNumber($4A1, Ord('C'), 1); // Mismatched build ID.
        4: SetLength(lBinary, $200); // Truncated image.
        5: PutNumber($21C, $FFFFFFF0, 4); // Unmapped export table.
        6:
          begin
            PutNumber($390, $1800013FF, 8);
            PutNumber($5FF, 255, 1); // String extends beyond raw section.
          end;
        7: PutNumber($250, Ord('X'), 1); // Missing descriptor export.
        8: PutNumber($84, $14C, 2); // Unsupported target.
      end;
      Save(lSDK + 'packages/nxrtl.dll', lBinary);
      Reject('Invalid PE case ' + IntToStr(lIndex));
    end;
    Save(lSDK + 'packages/nxrtl.dll', lImage);
    Save(lSDK + 'packages/nxrtl.pcp', Copy(lPCP, 1, Length(lPCP) - 1));
    Reject('Truncated PCP');
    Save(lSDK + 'packages/nxrtl.pcp', StringReplace(lPCP, lBuild, StringOfChar('C', 32), []));
    Reject('PCP identity mismatch');
    Save(lSDK + 'packages/nxrtl.pcp', StringReplace(lPCP, 'NXP004', 'NXP003', []));
    Reject('Wrong PCP version');
    Save(lSDK + 'packages/nxrtl.pcp', lPCP);
    Save(lSDK + 'work/identity.json', '{}');
    Reject('Incomplete JSON identity');
    Save(lSDK + 'work/identity.json', '{"SDK":"' + lIdentity + '","Build":"' + lBuild + '"}');
    Save(lSDK + 'bin/ppcx64.exe', 'not executable');
    Reject('Compiler version query failure');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') + 'PackageSDKManifest Bad { Directory: ""; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Empty manifest path rejected');
    AssertNoLaunch(AContext, lForge);
  finally
    lForge.Free;
  end;
end;

procedure RegisterForgeTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusForge');
  RegisterForgeContractTests(lSuite);
  lSuite.AddTest('Groups', @TestGroups);
  lSuite.AddTest('CommandLinePathValues', @TestCommandLinePathValues);
  lSuite.AddTest('CSVTool', @TestCSVTool);
  lSuite.AddTest('Render', @TestRender);
  lSuite.AddTest('RenderFailures', @TestRenderFailures);
  lSuite.AddTest('CreateDirectory', @TestCreateDirectory);
  lSuite.AddTest('CreateDirectoryFailures', @TestCreateDirectoryFailures);
  lSuite.AddTest('FileOperations', @TestFileOperations);
  lSuite.AddTest('CopyIncludeMasks', @TestCopyIncludeMasks);
  lSuite.AddTest('CopyIncludeMasksFailures', @TestCopyIncludeMasksFailures);
  lSuite.AddTest('CompareFiles', @TestCompareFiles);
  lSuite.AddTest('CompareFilesDifferences', @TestCompareFilesDifferences);
  lSuite.AddTest('CompareFilesErrors', @TestCompareFilesErrors);
  lSuite.AddTest('FileOperationFailures', @TestFileOperationFailures);
  lSuite.AddTest('LanguagePieces', @TestLanguagePieces);
  lSuite.AddTest('RejectEntityDocument', @TestRejectEntityDocument);
  lSuite.AddTest('MSBuildOperation', @TestMSBuildOperation);
  lSuite.AddTest('NXBuildOperation', @TestNXBuildOperation);
  lSuite.AddTest('FPCSwitches', @TestFPCSwitches);
  lSuite.AddTest('FPCOptionalOutput', @TestFPCOptionalOutput);
  lSuite.AddTest('FPCSwitchValidation', @TestFPCSwitchValidation);
  lSuite.AddTest('ClangOperation', @TestClangOperation);
  lSuite.AddTest('LLVMArOperation', @TestLLVMArOperation);
  lSuite.AddTest('PowerShellOperation', @TestPowerShellOperation);
  lSuite.AddTest('ToolOperations', @TestToolOperations);
  lSuite.AddTest('Validation', @TestValidation);
  lSuite.AddTest('TemplateComposition', @TestTemplateComposition);
  lSuite.AddTest('TargetsOrderAndRendering', @TestTargetsOrderAndRendering);
  lSuite.AddTest('FailuresAndReuse', @TestFailuresAndReuse);
  lSuite.AddTest('Streams', @TestStreams);
  lSuite.AddTest('NativeTools', @TestNativeTools);
  lSuite.AddTest('WorkingDirectory', @TestWorkingDirectory);
  lSuite.AddTest('RelativeCompiler', @TestRelativeCompiler);
  lSuite.AddTest('CompilationTimestamp', @TestCompilationTimestamp);
  lSuite.AddTest('BuildIdentity', @TestBuildIdentity);
  lSuite.AddTest('PackageSDKOptions', @TestPackageSDKOptions);
  lSuite.AddTest('PackageSDKManifest', @TestPackageSDKManifest);
  lSuite.AddTest('SourceSelections', @TestSourceSelections);
  lSuite.AddTest('StagedSources', @TestStagedSources);
  lSuite.AddTest('SourcePreflight', @TestSourcePreflight);
  lSuite.AddTest('SourceExecutionFailure', @TestSourceExecutionFailure);
  lSuite.AddTest('SelectedDefinition', @TestSelectedDefinition);
end;

end.
