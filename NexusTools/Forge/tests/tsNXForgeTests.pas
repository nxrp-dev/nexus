unit tsNXForgeTests;

{$mode delphi}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterForgeTests(ARegistry: TNXTestRegistry);

implementation

uses Classes, SysUtils, DateUtils, fpjson, jsonparser, obNXTestContext, obNXTestSuite,
  obNXForge, obNXForgeProcess, obNXForgeInvocation, obNexusScriptModel, obNexusScriptSession,
  obNexusScriptLanguageDefinition, obNexusScriptJSON, obNXCommandLine;

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
    'FPC Bad { Template: "command.mustache"; Source: [a]; EntryPoint: a; Output: b; Bogus: x; }',
    'Git Bad { Template: "command.mustache"; }',
    'FPC Bad { Template: "command.mustache"; Source: [a]; EntryPoint: a; }',
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
    'FPC Build (Defaults) { Source: ["app.pas"]; EntryPoint: "app.pas"; Output: "app" + @Platform.ExecutableSuffix; } ' +
    'FPC Check (Tests) { Source: ["tests.pas"]; EntryPoint: "tests.pas"; Output: "tests.exe"; } ' +
    'FPC Override (Defaults) { Template: "command.mustache"; Source: ["other.pas"]; EntryPoint: "other.pas"; Output: "other.exe"; }',
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
    'FPC Zulu (Defaults) {} FPC Hidden HostOS[Linux] {} FPC Alpha (Defaults) { Output: other; }',
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
    'module "' + StringReplace(Root, '\', '/', [rfReplaceAll]) + 'NexusLib/script/examples/forge/Shared.nxscript"; ' +
    'FPC Compile (CompileFPC) { Source: ["hello world & test.lpr"]; EntryPoint: "hello world & test.lpr"; Output: "hello world & test.exe"; } ' +
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
        'Render First { Source: "model.nxscript"; Template: "artifact.mustache"; Output: "never.txt"; } ' +
        'Git Next { Template: "native.mustache"; Repository: repo; } ' +
        'Render Bad { Source: "' + lBadSource + '"; Template: "artifact.mustache"; Output: "bad.txt"; }');
      AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Bad render fails preflight');
      AssertNoLaunch(AContext, lForge);
      AContext.AssertFalse(FileExists(lDirectory + 'never.txt'), 'Preflight writes nothing');
    end;
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Render Bad { Source: "model.nxscript"; Template: "artifact.mustache"; Output: "missing/out.txt"; } ' +
      'Git Next { Template: "native.mustache"; Repository: repo; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Write failure stops execution');
    AContext.AssertTrue(lForge.Invocations[0].Started, 'Write attempted');
    AContext.AssertFalse(lForge.Invocations[1].Started, 'Later native command was not launched');
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Git First { Template: "native.mustache"; Repository: repo; } ' +
      'Render Bad { Source: "model.nxscript"; Template: "missing.mustache"; Output: "bad.txt"; }');
    AContext.AssertFalse(lForge.Execute(lDirectory + 'Build.nxscript'), 'Missing artifact template fails');
    AssertNoLaunch(AContext, lForge);
    Save(lDirectory + 'artifact.mustache', '');
    Save(lDirectory + 'native.mustache', ChildCommand('ok'));
    Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
      'Render Empty { Source: "model.nxscript"; Template: "artifact.mustache"; Output: "empty.txt"; } ' +
      'Git Next { Template: "native.mustache"; Repository: repo; }');
    AContext.AssertTrue(lForge.Execute(lDirectory + 'Build.nxscript'), lForge.Diagnostic);
    AContext.AssertTrue(FileExists(lDirectory + 'empty.txt'), 'An empty artifact is still a file');
    AContext.AssertEquals('', lForge.Invocations[0].ArtifactText, 'Empty content is preserved');
    AContext.AssertTrue(lForge.Invocations[1].Exited, 'Mixed list executes the native command');
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
    'Git First { Template: "stamp.mustache"; Repository: repo; } ' +
    'Git Second { Template: "stamp.mustache"; Repository: repo; }');
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
  AContext.AssertTrue(FileExists(lTool), 'Build NexusTools/CSV/NexusCSV.lpi first');
  lTemplate := StringReplace(Root, '\', '/', [rfReplaceAll]) + 'NexusLib/script/tools/CSV/SQL.mustache';
  Save(lDirectory + 'source.csv', 'ID,NAME,NOTE' + LineEnding +
    '1,O''Brien,"comma, and ""quote"""' + LineEnding + '2,,' + LineEnding);
  Save(lDirectory + 'native.mustache', ChildCommand('ok'));
  Save(lDirectory + 'Build.nxscript', Dialect('NexusForge') +
    'module "' + StringReplace(Root, '\', '/', [rfReplaceAll]) + 'NexusLib/script/tools/CSV/CSV.nxscript"; ' +
    'CSV Generate (CompileCSV) { Compiler: "' + lTool + '"; Source: "source.csv"; ' +
    'SourceTemplate: "' + lTemplate + '"; Output: "artifacts/seed.sql"; Name: DEMO; } ' +
    'Git Next { Template: "native.mustache"; Repository: repo; }');
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
      'module "' + StringReplace(Root, '\', '/', [rfReplaceAll]) + 'NexusLib/script/tools/CSV/CSV.nxscript"; ' +
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

procedure RegisterForgeTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusForge');
  lSuite.AddTest('CommandLinePathValues', @TestCommandLinePathValues);
  lSuite.AddTest('CSVTool', @TestCSVTool);
  lSuite.AddTest('Render', @TestRender);
  lSuite.AddTest('RenderFailures', @TestRenderFailures);
  lSuite.AddTest('LanguagePieces', @TestLanguagePieces);
  lSuite.AddTest('Validation', @TestValidation);
  lSuite.AddTest('TemplateComposition', @TestTemplateComposition);
  lSuite.AddTest('TargetsOrderAndRendering', @TestTargetsOrderAndRendering);
  lSuite.AddTest('FailuresAndReuse', @TestFailuresAndReuse);
  lSuite.AddTest('Streams', @TestStreams);
  lSuite.AddTest('NativeTools', @TestNativeTools);
  lSuite.AddTest('WorkingDirectory', @TestWorkingDirectory);
  lSuite.AddTest('CompilationTimestamp', @TestCompilationTimestamp);
  lSuite.AddTest('SourceSelections', @TestSourceSelections);
  lSuite.AddTest('SelectedDefinition', @TestSelectedDefinition);
end;

end.
