unit tsNXForgePackageTests;

{$mode delphi}{$H+}

interface
uses obNXTestRegistry;
procedure RegisterForgePackageTests(ARegistry: TNXTestRegistry);

implementation
uses Classes, SysUtils, obNXTestContext, obNXTestSuite, obNXForgePackages, obNXForge,
  obNexusScriptModel;

function Root: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../../');
end;

function FreshDirectory: string;
var
  lID: TGUID;
begin
  CreateGUID(lID);
  Result := Root + 'output/ForgePackages/' + GUIDToString(lID) + '/';
  ForceDirectories(Result);
end;

procedure Save(const AFileName, AText: string);
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFileName, fmCreate);
  try
    if AText <> '' then lStream.WriteBuffer(AText[1], Length(AText));
  finally
    lStream.Free;
  end;
end;

function NXString(const AText: string): string;
begin
  Result := '"' + StringReplace(AText, '\', '/', [rfReplaceAll]) + '"';
end;

function Dialect(const AName: string): string;
begin
  Result := 'dialect ' + NXString(Root + 'NexusLib/script/dialects/' +
    AName + '/' + AName + '.Language.nxscript') + '; ';
end;

function Contract: string;
begin
  Result := 'Targets: [Dimension TargetCPU { Required: True; Allowed: [x86, x64]; }, ' +
    'Dimension TargetOS { Required: True; Allowed: [Windows, Linux]; }]; ';
end;

function Selections(const ACPU: string): string;
begin
  Result := 'Targets: [Selection TargetCPU { Value: ' + ACPU + '; }, ' +
    'Selection TargetOS { Value: Windows; }]; ';
end;

function Targets(const ACPU: string = 'x64'): TNexusScriptTargetSelection;
begin
  Result := TNexusScriptTargetSelection.Create;
  Result.Add('TargetCPU', ACPU);
  Result.Add('TargetOS', 'Windows');
end;

procedure CommandTemplate(const ADirectory, ACommand: string);
begin
  Save(ADirectory + 'command.mustache', ACommand);
end;

function Helper(const AMode: string): string;
begin
  Result := '"' + ParamStr(0) + '" child ' + AMode;
end;

procedure TestBuildAndReuse(AContext: TNXTestContext);
var
  lDirectory, lDocument: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  lDocument := Dialect('NexusForge') +
    'Package Example { Version: "development snapshot"; Author: "Example Author"; ' +
    'License: "Project-specific terms"; ' + Contract +
    'Outputs: [Output Result { Path: "made & ready.txt"; }]; ' +
    'Git Build { Template: "command.mustache"; Repository: "made & ready.txt"; } }';
  Save(lDirectory + 'example.SillyPackage.nxscript', lDocument);
  CommandTemplate(lDirectory, Helper('create') + ' "{{{Repository}}}"');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'example.SillyPackage.nxscript',
      'Example', lTargets), lPackages.Diagnostic);
    AContext.AssertFalse(lPackages.PackageResult.Reused, 'Missing output built');
    AContext.AssertEquals('development snapshot',
      ForgePropertyText(lPackages.PackageResult.Definition, 'Version'), 'Version is unrestricted text');
    AContext.AssertEquals('Example Author',
      ForgePropertyText(lPackages.PackageResult.Definition, 'Author'), 'Author retained');
    AContext.AssertEquals('Project-specific terms',
      ForgePropertyText(lPackages.PackageResult.Definition, 'License'), 'License is unrestricted text');
    AContext.AssertTrue(FileExists(lDirectory + 'made & ready.txt'), 'Output exists');
    Save(lDirectory + 'example.SillyPackage.nxscript',
      StringReplace(lDocument, 'development snapshot', 'next snapshot', []));
    Save(lDirectory + 'command.mustache', 'this-tool-does-not-exist');
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'example.SillyPackage.nxscript',
      'Example', lTargets), lPackages.Diagnostic);
    AContext.AssertTrue(lPackages.PackageResult.Reused, 'Existing output reused despite recipe change');
    AContext.AssertTrue(lPackages.PackageResult.Runner = nil, 'Reuse launches nothing');
    AContext.AssertEquals('next snapshot',
      ForgePropertyText(lPackages.PackageResult.Definition, 'Version'), 'Metadata change does not invalidate output');
    DeleteFile(lDirectory + 'made & ready.txt');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'example.SillyPackage.nxscript',
      'Example', lTargets), 'Missing artifact invokes changed recipe');
    AContext.AssertTrue(lPackages.Requests[0].Runner <> nil, 'Build attempted again');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestTargetContract(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'package.nxscript', Dialect('NexusForge') +
    'Package Example { ' + Contract + 'Outputs: [Output Result { Path: "ready"; }]; }');
  Save(lDirectory + 'ready', 'present');
  lPackages := TNXForgePackages.Create;
  lTargets := TNexusScriptTargetSelection.Create;
  try
    lTargets.Add('TargetCPU', 'x64');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'OS is required even for existing output');
    AContext.AssertTrue(Pos('required target TargetOS', lPackages.Diagnostic) > 0, lPackages.Diagnostic);
    lTargets.Add('TargetOS', 'Windows');
    lTargets.SetValue('TargetCPU', 'unsupported');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Allowed values enforced');
    lTargets.SetValue('TargetCPU', 'x64');
    lTargets.Add('Surprise', 'yes');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Undeclared dimensions rejected');
    AContext.AssertTrue(Pos('undeclared target Surprise', lPackages.Diagnostic) > 0, lPackages.Diagnostic);
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestDependencies(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  ForceDirectories(lDirectory + 'dependency');
  Save(lDirectory + 'dependency/tool.nxscript', Dialect('NexusForge') + 'module "../Shared.nxscript"; ' +
    'Package Tool { ' + Contract + 'Outputs: [Output Data { Path: "data.txt"; }]; ' +
    'Git Build (Defaults) { Repository: "data.txt"; } }');
  Save(lDirectory + 'app.nxscript', Dialect('NexusForge') + 'module Tool "dependency/tool.nxscript"; module "Shared.nxscript"; ' +
    'Package App { ' + Contract + 'Requires: [' +
    'Requirement Tools { Package: @Tool; ' + Selections('x86') + ' }, ' +
    'Requirement Again { Package: @Tool; Targets: [Selection TargetOS { Value: Windows; }, ' +
    'Selection TargetCPU { Value: x86; }]; }]; ' +
    'Outputs: [Output Result { Path: "done.txt"; }]; ' +
    'PackageOutput Input { Requirement: Tools; Output: Data; } ' +
    'Git Build (Defaults) { Repository: @App.Input; } }');
  Save(lDirectory + 'Shared.nxscript', Dialect('NexusForge') +
    'Git Defaults TargetCPU[x86] { Template: "create.mustache"; } ' +
    'Git Defaults TargetCPU[x64] { Template: "consume.mustache"; }');
  Save(lDirectory + 'create.mustache', Helper('create') + ' "{{{Repository}}}"');
  Save(lDirectory + 'consume.mustache', Helper('consume') + ' "{{{Repository}}}"');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'app.nxscript', 'App',
      lTargets), lPackages.Diagnostic);
    AContext.AssertEquals(2, lPackages.Requests.Count, 'Same dependency selections reuse one request');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'create.mustache'), lPackages.Requests[1].Runner.Invocations[0].TemplatePath,
      'Dependency uses its own full target selection');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'consume.mustache'), lPackages.Requests[0].Runner.Invocations[0].TemplatePath,
      'Consumer composes the same module with its own selections');
    AContext.AssertTrue(Pos(ExpandFileName(lDirectory + 'dependency/data.txt'),
      lPackages.Requests[0].Runner.Invocations[0].Command) > 0, 'Named output anchored at dependency root');
    AContext.AssertTrue(FileExists(lDirectory + 'done.txt'), 'Consumer produced its result');
    DeleteFile(lDirectory + 'dependency/data.txt');
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'app.nxscript', 'App',
      lTargets), lPackages.Diagnostic);
    AContext.AssertEquals(1, lPackages.Requests.Count, 'Ready consumer does not obtain prerequisites');
    AContext.AssertFalse(FileExists(lDirectory + 'dependency/data.txt'), 'Missing prerequisite stays missing');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestMissingOutputs(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'package.nxscript', Dialect('NexusForge') +
    'Package Example { ' + Contract + 'Outputs: [Output Needed { Path: "missing"; }]; ' +
    'Git Build { Template: "command.mustache"; Repository: dot; } }');
  CommandTemplate(lDirectory, Helper('ok'));
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Zero exit is insufficient');
    AContext.AssertTrue(Pos('missing output Needed', lPackages.Diagnostic) > 0, lPackages.Diagnostic);
    Save(lDirectory + 'package.nxscript', Dialect('NexusForge') +
      'Package Example { ' + Contract + 'Outputs: []; }');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Empty outputs cannot be ready');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestMultiplePackages(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'several.nxscript', Dialect('NexusForge') +
    'Package One { ' + Contract + 'Outputs: [Output File { Path: "one"; }]; } ' +
    'Package Two { ' + Contract + 'Outputs: [Output Folder { Path: "two"; Directory: True; }]; }');
  Save(lDirectory + 'one', 'ready');
  ForceDirectories(lDirectory + 'two');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'several.nxscript', '',
      lTargets), 'Ambiguous entry requires a package name');
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'several.nxscript', 'One',
      lTargets), lPackages.Diagnostic);
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'several.nxscript', 'Two',
      lTargets), lPackages.Diagnostic);
    AContext.AssertEquals(ExcludeTrailingPathDelimiter(ExpandFileName(lDirectory)),
      lPackages.PackageResult.Root, 'Defining directory is root for both packages');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestCompilerOutput(AContext: TNXTestContext);
var
  lDirectory, lFPC: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  lFPC := FileSearch('fpc.exe', GetEnvironmentVariable('PATH'));
  AContext.AssertTrue(lFPC <> '', 'This integration test requires fpc.exe on PATH');
  ForceDirectories(lDirectory + 'compiler');
  Save(lDirectory + 'compiler/fpc.nxscript', Dialect('NexusForge') +
    'Package Compiler { ' + Contract + 'Outputs: [Output Executable { Path: ' + NXString(lFPC) + '; }]; }');
  Save(lDirectory + 'app.nxscript', Dialect('NexusForge') + 'module "compiler/fpc.nxscript"; ' +
    'Package App { ' + Contract +
    'Requires: [Requirement Tools { Package: @Compiler; ' + Selections('x64') + ' }]; ' +
    'Outputs: [Output Executable TargetCPU[x64] { Path: "bin/x64/hello & package.exe"; }, ' +
    'Output Executable TargetCPU[x86] { Path: "bin/x86/hello & package.exe"; }]; ' +
    'PackageOutput CompilerPath { Requirement: Tools; Output: Executable; } ' +
    'FPC Compile { Template: ' + NXString(Root + 'NexusTools/Forge/examples/FPC.mustache') + '; Compiler: @App.CompilerPath; Source: "hello & package.lpr"; UnitOutput: "bin/x64"; Output: "bin/x64/hello & package.exe"; } }');
  Save(lDirectory + 'hello & package.lpr', 'program Hello; uses ExampleUnit; begin WriteLn(MessageText); end.');
  Save(lDirectory + 'ExampleUnit.pas', 'unit ExampleUnit; interface const MessageText = ''package-ok''; implementation end.');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'app.nxscript', 'App',
      lTargets), lPackages.Diagnostic);
    AContext.AssertTrue(lPackages.Requests[1].Reused, 'Existing compiler package reused');
    AContext.AssertTrue(FileExists(lDirectory + 'bin/x64/hello & package.exe'), 'Missing artifact directory prepared for compiler');
    AContext.AssertTrue(FileExists(lDirectory + 'bin/x64/ExampleUnit.ppu'), 'Compiled unit shares artifact directory');
    AContext.AssertFalse(FileExists(lDirectory + 'ExampleUnit.ppu'), 'No compiled unit in source directory');
    AContext.AssertFalse(DirectoryExists(lDirectory + 'bin/x86'), 'Unselected target directory not created');
    AContext.AssertTrue(Pos(lFPC, lPackages.PackageResult.Runner.Invocations[0].Command) > 0,
      'Template receives exact declared compiler path');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestFailureArtifacts(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'package.nxscript', Dialect('NexusForge') +
    'Package Example { ' + Contract + 'Outputs: [Output Result { Path: "left.txt"; }]; ' +
    'Git First { Template: "command.mustache"; Repository: "left.txt"; } Git Later { Template: "command.mustache"; Repository: "later.txt"; } }');
  CommandTemplate(lDirectory, Helper('partial') + ' "{{{Repository}}}"');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Nonzero exit fails this request');
    AContext.AssertEquals(7, lPackages.Requests[0].Runner.Invocations[0].ExitStatus, 'Actual failure retained');
    AContext.AssertFalse(lPackages.Requests[0].Runner.Invocations[1].Started, 'Later operation stopped');
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Next request uses presence alone');
    AContext.AssertTrue(lPackages.PackageResult.Reused, 'No persistent success stamp required');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestOptionalSelection(AContext: TNXTestContext);
var
  lDirectory, lRequirements: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'library.nxscript', Dialect('NexusForge') + 'Package Library { ' +
    'Targets: [Dimension TargetCPU { Required: True; }, Dimension TargetOS { Required: True; }, ' +
    'Dimension Mode { Allowed: [Debug]; }]; Outputs: [Output Data { Path: "data"; }]; }');
  Save(lDirectory + 'data', 'ready');
  lRequirements := 'Requirement Unspecified { Package: @Library; ' + Selections('x64') + ' }, ' +
    'Requirement Debug { Package: @Library; Targets: [Selection TargetCPU { Value: x64; }, ' +
    'Selection TargetOS { Value: Windows; }, Selection Mode { Value: Debug; }]; }';
  Save(lDirectory + 'app.nxscript', Dialect('NexusForge') + 'module "library.nxscript"; ' +
    'Package App { ' + Contract + 'Requires: [' + lRequirements + ']; ' +
    'Outputs: [Output Result { Path: "made"; }]; Git Build { Template: "command.mustache"; Repository: "made"; } }');
  CommandTemplate(lDirectory, Helper('create') + ' "{{{Repository}}}"');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'app.nxscript', 'App',
      lTargets), lPackages.Diagnostic);
    AContext.AssertEquals(3, lPackages.Requests.Count, 'Unspecified and Debug are distinct requests');
    AContext.AssertTrue(lPackages.Requests[1].Reused and lPackages.Requests[2].Reused,
      'Explicitly shared output can satisfy both requests');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestUnknownOutputAndPrerequisiteFailure(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'library.nxscript', Dialect('NexusForge') +
    'Package Library { ' + Contract + 'Outputs: [Output Data { Path: "data"; }]; }');
  Save(lDirectory + 'app.nxscript', Dialect('NexusForge') + 'module "library.nxscript"; ' +
    'Package App { ' + Contract + 'Requires: [Requirement Tools { Package: @Library; ' + Selections('x64') + ' }]; ' +
    'Outputs: [Output Result { Path: "made"; }]; ' +
    'PackageOutput Input { Requirement: Tools; Output: Unknown; } Git Build { Template: "command.mustache"; Repository: @App.Input; } }');
  CommandTemplate(lDirectory, Helper('ok'));
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'app.nxscript', 'App',
      lTargets), 'Missing prerequisite fails');
    AContext.AssertTrue(lPackages.Requests[0].Runner = nil, 'Consumer never starts');
    Save(lDirectory + 'data', 'ready');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'app.nxscript', 'App',
      lTargets), 'Unknown output fails before rendering');
    AContext.AssertTrue(Pos('Unknown package output Unknown', lPackages.Diagnostic) > 0, lPackages.Diagnostic);
    AContext.AssertTrue(lPackages.Requests[0].Runner = nil, 'Unknown output never launches consumer');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestOutputDirectoryFailures(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'blocked', 'This is a file');
  Save(lDirectory + 'package.nxscript', Dialect('NexusForge') +
    'Package Example { ' + Contract +
    'Outputs: [Output Result { Path: "blocked/result.txt"; }]; Git Build { Template: "command.mustache"; Repository: "ran"; } }');
  CommandTemplate(lDirectory, Helper('create') + ' "{{{Repository}}}"');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Cannot create directory over file');
    AContext.AssertTrue(Pos('Unable to create package output directory', lPackages.Diagnostic) > 0, lPackages.Diagnostic);
    AContext.AssertTrue(lPackages.Requests[0].Runner = nil, 'Preparation failure launches nothing');
    AContext.AssertFalse(FileExists(lDirectory + 'ran'), 'Recipe did not run');

    Save(lDirectory + 'package.nxscript', Dialect('NexusForge') +
      'Package Example { ' + Contract +
      'Outputs: [Output Result { Path: "container/artifact"; Directory: True; }]; }');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), 'Preparation must not fabricate a directory artifact');
    AContext.AssertTrue(DirectoryExists(lDirectory + 'container'), 'Artifact parent prepared');
    AContext.AssertFalse(DirectoryExists(lDirectory + 'container/artifact'), 'Artifact not fabricated');

  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestIntermediateOutputs(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lTargets: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  // Intermediate preparation belongs to the recipe; it is explicit in this fixture.
  ForceDirectories(lDirectory + 'temp');
  Save(lDirectory + 'package.nxscript', Dialect('NexusForge') +
    'Package Example { ' + Contract +
    'Outputs: [Output Result { Path: "done.txt"; }]; ' +
    'FPC Compile { Template: "compile.mustache"; Source: "app.pas"; Output: "temp/foo.o"; } ' +
    'Git Link { Template: "link.mustache"; Repository: "temp/foo.o"; } }');
  Save(lDirectory + 'compile.mustache', Helper('create') +
    ' "{{{Output}}}"{{#OutputDirectory}} UNEXPECTED{{/OutputDirectory}}');
  Save(lDirectory + 'link.mustache', Helper('consume') + ' "{{{Repository}}}"');
  lPackages := TNXForgePackages.Create;
  lTargets := Targets;
  try
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'package.nxscript', 'Example',
      lTargets), lPackages.Diagnostic);
    AContext.AssertEquals(2, lPackages.PackageResult.Runner.Invocations.Count,
      'Both stages execute');
    AContext.AssertEquals(Helper('create') + ' "temp/foo.o"',
      lPackages.PackageResult.Runner.Invocations[0].Command,
      'Output remains ordinary data without an injected OutputDirectory');
    AContext.AssertTrue(FileExists(lDirectory + 'temp/foo.o'), 'Intermediate outside artifact directory produced');
    AContext.AssertTrue(FileExists(lDirectory + 'done.txt'), 'Consumer reads intermediate and produces final artifact');
  finally
    lTargets.Free;
    lPackages.Free;
  end;
end;

procedure TestEnvironmentArtifactLookup(AContext: TNXTestContext);
var
  lDirectory: string;
  lPackages: TNXForgePackages;
  lWindows, lLinux: TNexusScriptTargetSelection;
begin
  lDirectory := FreshDirectory;
  Save(lDirectory + 'Shared.nxscript', Dialect('NexusForge') +
    'Environment Platform TargetOS[Windows] { ExecutableSuffix: ".exe"; } ' +
    'Environment Platform TargetOS[Linux] { ExecutableSuffix: ""; } ' +
    'FPC CompileApplication { Template: "missing.mustache"; }');
  Save(lDirectory + 'package.nxscript', Dialect('NexusForge') + 'module "Shared.nxscript"; ' +
    'Package Example { ' + Contract +
    'Outputs: [Output Result { Path: "product" + @Platform.ExecutableSuffix; }]; ' +
    'FPC Compile (CompileApplication) { Source: "app.pas"; Output: @Example.Outputs.Result.Path; } }');
  Save(lDirectory + 'product.exe', 'Windows artifact');
  Save(lDirectory + 'product', 'Linux artifact');
  lPackages := TNXForgePackages.Create;
  lWindows := Targets;
  lLinux := TNexusScriptTargetSelection.Create;
  lLinux.Add('TargetCPU', 'x64');
  lLinux.Add('TargetOS', 'Linux');
  try
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'package.nxscript', 'Example', lWindows), lPackages.Diagnostic);
    AContext.AssertTrue(lPackages.PackageResult.Reused, 'Windows artifact reused without reading template');
    AContext.AssertEquals(ExpandFileName(lDirectory + 'product.exe'),
      lPackages.PackageResult.Outputs[0].Path, 'Selected environment resolves before readiness');
    AContext.AssertEquals('product.exe', ForgePropertyText(
      lPackages.PackageResult.Definition.FindChild('Compile'), 'Output'), 'Compiler and detection share resolved path');
    AContext.AssertTrue(lPackages.Execute(lDirectory + 'package.nxscript', 'Example', lLinux), lPackages.Diagnostic);
    AContext.AssertEquals(ExpandFileName(lDirectory + 'product'),
      lPackages.PackageResult.Outputs[0].Path, 'Empty suffix remains ordinary data');
    AContext.AssertEquals('product', ForgePropertyText(
      lPackages.PackageResult.Definition.FindChild('Compile'), 'Output'), 'Linux compiler destination matches artifact');
    DeleteFile(lDirectory + 'product.exe');
    AContext.AssertFalse(lPackages.Execute(lDirectory + 'package.nxscript', 'Example', lWindows),
      'Linux artifact cannot satisfy Windows request; missing template prevents build');
    AContext.AssertTrue(lPackages.Requests[0].Runner <> nil, 'Missing selected artifact attempts build');
  finally
    lLinux.Free;
    lWindows.Free;
    lPackages.Free;
  end;
end;

procedure RegisterForgePackageTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusForge.Packages');
  lSuite.AddTest('BuildAndReuse', @TestBuildAndReuse);
  lSuite.AddTest('TargetContract', @TestTargetContract);
  lSuite.AddTest('Dependencies', @TestDependencies);
  lSuite.AddTest('MissingOutputs', @TestMissingOutputs);
  lSuite.AddTest('MultiplePackages', @TestMultiplePackages);
  lSuite.AddTest('CompilerOutput', @TestCompilerOutput);
  lSuite.AddTest('FailureArtifacts', @TestFailureArtifacts);
  lSuite.AddTest('OptionalSelection', @TestOptionalSelection);
  lSuite.AddTest('UnknownOutputAndPrerequisiteFailure', @TestUnknownOutputAndPrerequisiteFailure);
  lSuite.AddTest('OutputDirectoryFailures', @TestOutputDirectoryFailures);
  lSuite.AddTest('IntermediateOutputs', @TestIntermediateOutputs);
  lSuite.AddTest('EnvironmentArtifactLookup', @TestEnvironmentArtifactLookup);
end;

end.
