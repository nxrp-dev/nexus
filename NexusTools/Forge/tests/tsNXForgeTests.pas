unit tsNXForgeTests;

{$mode delphi}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterForgeTests(ARegistry: TNXTestRegistry);

implementation

uses Classes, SysUtils, fpjson, jsonparser, obNXTestContext, obNXTestSuite,
  obNXForge, obNXForgeProcess, obNexusScriptModel, obNexusScriptSession,
  obNexusScriptLanguageDefinition, obNexusScriptJSON;

function Root: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../../');
end;

function TestDir(const AName: string): string;
begin
  Result := Root + 'output/ForgeVerification/' + AName + '/';
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

function Dialect(const AName: string): string;
begin
  Result := 'dialect "' + StringReplace(Root, '\', '/', [rfReplaceAll]) +
    'NexusLib/script/dialects/' + AName + '/' + AName + '.Language.nxscript"; ';
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
      'NexusTools/Forge/tests/fixtures/composition.nxscript'), lSession.LastError);
    AContext.AssertTrue(lLanguage.Normalize(
      lSession.EntryCompiler.CompiledDocument.DialectDocument), 'Normalize included rules');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('FPC') <> nil, 'FPC rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Git') <> nil, 'Git rule present');
    AContext.AssertTrue(lLanguage.FindDefinitionRule('Environment') <> nil, 'Environment rule present');
  finally
    lLanguage.Free;
    lSession.Free;
  end;
end;

procedure TestValidation(AContext: TNXTestContext);
const
  cInvalidOperations: array[0..4] of string = (
    'FPC Bad { Template: "command.mustache"; Source: a; Output: b; Bogus: x; }',
    'Git Bad { Template: "command.mustache"; }',
    'FPC Bad { Template: "command.mustache"; Source: a; }',
    'FPC Bad { Template: "command.mustache"; Source: a; Output: b; Defines: text; }',
    'FPC Bad { Template: "command.mustache"; Source: a; Output: b; UnitOutput: [invalid]; }');
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
    'FPC Build (Defaults) { Source: "app.pas"; Output: "app" + @Platform.ExecutableSuffix; } ' +
    'FPC Check (Tests) { Source: "tests.pas"; Output: "tests.exe"; } ' +
    'FPC Override (Defaults) { Template: "command.mustache"; Source: "other.pas"; Output: "other.exe"; }',
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
  Save(lDirectory + 'Base.nxscript',
    'FPC Defaults HostOS[Win32] { Template: "command.mustache"; Source: source; Output: output; Defines: [ONE, TWO]; } ' +
    'FPC Defaults HostOS[Linux] { Template: "absent.mustache"; }');
  Fixture(lDirectory, 'module "Base.nxscript"; ' +
    'FPC Zulu (Defaults) {} FPC Hidden HostOS[Linux] {} FPC Alpha (Defaults) { Output: other; }',
    ChildCommand('ok') + ' {{{_nx.Name}}} {{{Source}}} {{{Output}}}{{#Defines}} {{{.}}}{{/Defines}}');
  lTargets := TNexusScriptTargetSelection.Create;
  lTargets.Add('HostOS', 'Win32');
  lForge := TNXForge.Create(lTargets);
  try
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertEquals(2, lForge.Invocations.Count, 'Inactive and module roots not scheduled');
    AContext.AssertEquals('Zulu', lForge.Invocations[0].OperationName, 'Declaration order');
    AContext.AssertEquals(ChildCommand('ok') + ' Zulu source output ONE TWO',
      lForge.Invocations[0].Command, 'Exact resolved template context');
    AContext.AssertEquals(ChildCommand('ok') + ' Alpha source other ONE TWO',
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
    Fixture(lDirectory, 'Git First { Template: "command.mustache"; Repository: dot; } ' +
      'Git Later { Template: "absent.mustache"; Repository: dot; }', ChildCommand('ok'));
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing later template fails preflight');
    AContext.AssertTrue(Pos('Later', lForge.Diagnostic) > 0, lForge.Diagnostic);
    AssertNoLaunch(AContext, lForge);
    Fixture(lDirectory, 'Git First { Template: "command.mustache"; Repository: dot; } ' +
      'Git Later { Template: "command.mustache"; Repository: dot; }', ChildCommand('fail'));
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
    'module "' + StringReplace(Root, '\', '/', [rfReplaceAll]) + 'NexusTools/Forge/examples/Shared.nxscript"; ' +
    'FPC Compile (CompileFPC) { Source: "hello world & test.lpr"; Output: "hello world & test.exe"; } ' +
    'Git Inspect (GitStatus) { Repository: "."; }');
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
      'NexusTools/Forge/tests/fixtures/composition.nxscript'), lSession.LastError);
    lEmitter.AddDocument(lSession.EntryCompiler.CompiledDocument);
    lBefore := lEmitter.JSON;
    lJSON := GetJSON(lEmitter.RenderDefinition(
      lSession.EntryCompiler.CompiledDocument.FindDefinition('CompileExample')));
    try
      AContext.AssertEquals('hello world & test.lpr', lJSON.FindPath('Source').AsString,
        'Selected context contains direct resolved properties');
      AContext.AssertEquals('CompileExample', lJSON.FindPath('_nx.Name').AsString, 'Metadata retained');
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

procedure RegisterForgeTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusForge');
  lSuite.AddTest('LanguagePieces', @TestLanguagePieces);
  lSuite.AddTest('Validation', @TestValidation);
  lSuite.AddTest('TemplateComposition', @TestTemplateComposition);
  lSuite.AddTest('TargetsOrderAndRendering', @TestTargetsOrderAndRendering);
  lSuite.AddTest('FailuresAndReuse', @TestFailuresAndReuse);
  lSuite.AddTest('Streams', @TestStreams);
  lSuite.AddTest('NativeTools', @TestNativeTools);
  lSuite.AddTest('WorkingDirectory', @TestWorkingDirectory);
  lSuite.AddTest('SelectedDefinition', @TestSelectedDefinition);
end;

end.
