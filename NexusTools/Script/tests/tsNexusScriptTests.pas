unit tsNexusScriptTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNexusScriptTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  jsonparser,
  obNXTestContext,
  obNXTestSuite,
  obNXCommandLine,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler,
  obNexusScriptSession,
  obNexusScriptArtifactModel,
  obNexusScriptArtifactContext,
  obNexusScriptJSON,
  obNexusScriptExternalSource,
  obNexusScriptCommand,
  obNexusScriptLanguageDefinition,
  obNexusScriptValidator;

procedure TestStructureAndValues(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('basic.nxscript',
      'Thing Root { Suffix: done; Name: Tom + " " + @Suffix; ' +
      'Items: [one, @Suffix, "three"]; Thing Child {} Target: @Child; }'),
      'Basic script should compile.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertTrue(lRoot <> nil, 'Root definition should exist.');
    AContext.AssertEquals('Tom done',
      lRoot.FindProperty('Name').Value.EffectiveText,
      'Text composition should evaluate.');
    AContext.AssertEquals(3, lRoot.FindProperty('Items').Value.Items.Count,
      'Array should contain three items.');
    AContext.AssertTrue(lRoot.FindProperty('Target').Value.ResolvedDefinition =
      lRoot.FindChild('Child'), 'Definition reference should bind.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestDefinitionTargets(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lImportCompiler: TNexusScriptCompiler;
  lFailureCompiler: TNexusScriptCompiler;
  lValidatorCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
  lSourceRoot: TNexusScriptSourceDefinition;
  lRoot: TNexusScriptCompiledDefinition;
  lRelease: TNexusScriptCompiledDefinition;
  lImportedRoot: TNexusScriptCompiledDefinition;
  lInline: TNexusScriptCompiledDefinition;
  lSourceTarget: TNexusScriptTarget;
  lCompiledTarget: TNexusScriptTarget;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lImportCompiler := TNexusScriptCompiler.Create;
  lFailureCompiler := TNexusScriptCompiler.Create;
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('targets.nxscript',
      'Thing Root Target[Production, PRODUCTION, "Cross Reference", ' +
      '"Line^nBreak", "Build.Production", Environment=Production] ' +
      'Platform[Windows] { ' +
      'Targets: domain; ' +
      'Thing Base Platform[Windows] { ' +
      'Thing MailSettings Scope[Shared] {} } ' +
      'Thing Release (Base) Target[Production] {} ' +
      'Thing Nested Target[NestedTarget] {} Alias: @Nested; ' +
      'Items: [Node Inline Target[InlineTarget] { Value: yes; }]; }'),
      'Targeted definitions should compile.');
    lSourceRoot := lCompiler.SourceDocument.FindDefinition('Root');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals(2, lSourceRoot.Targets.Count,
      'Source definitions should retain each named Target kind.');
    lSourceTarget := lSourceRoot.Targets[0];
    AContext.AssertEquals('Target', lSourceTarget.Name,
      'Source Target kinds should retain declaration order.');
    AContext.AssertEquals(6, lSourceTarget.Values.Count,
      'Source Target values should retain their count.');
    AContext.AssertEquals('Production', lSourceTarget.Values[0],
      'Source Targets should retain declaration order and spelling.');
    AContext.AssertEquals('PRODUCTION', lSourceTarget.Values[1],
      'Target identity should be case-sensitive.');
    AContext.AssertEquals('Cross Reference', lSourceTarget.Values[2],
      'Quoted Target whitespace should be decoded and retained.');
    AContext.AssertEquals('Line' + #10 + 'Break',
      lSourceTarget.Values[3],
      'Quoted Targets should use existing escape decoding.');
    AContext.AssertEquals('Build.Production', lSourceTarget.Values[4],
      'Quoted language punctuation should remain literal Target text.');
    AContext.AssertEquals('Environment=Production',
      lSourceTarget.Values[5],
      'Punctuation within a word should remain part of the Target.');
    AContext.AssertEquals('Platform', lSourceRoot.Targets[1].Name,
      'A second Target kind should remain distinct.');
    AContext.AssertEquals('Windows', lSourceRoot.Targets[1].Values[0],
      'A second Target kind should retain its value.');
    AContext.AssertTrue(lRoot.Targets <> lSourceRoot.Targets,
      'Source and compiled definitions should own distinct Target lists.');
    lCompiledTarget := lRoot.Targets[0];
    AContext.AssertTrue(lCompiledTarget <> lSourceTarget,
      'Source and compiled definitions should own distinct Target entries.');
    AContext.AssertTrue(lCompiledTarget.Values <> lSourceTarget.Values,
      'Source and compiled Targets should own distinct value lists.');
    AContext.AssertEquals(lSourceTarget.Values.Text,
      lCompiledTarget.Values.Text,
      'Compilation should preserve Target values exactly.');
    AContext.AssertEquals('domain',
      lRoot.FindProperty('Targets').Value.EffectiveText,
      'A domain Targets property should remain independent from metadata.');

    lRelease := lRoot.FindChild('Release');
    AContext.AssertEquals(1, lRelease.Targets.Count,
      'Composition should retain only receiver Targets.');
    AContext.AssertEquals('Production', lRelease.Targets[0].Values[0],
      'Composition should not copy contributor Targets.');
    AContext.AssertEquals('Shared',
      lRelease.FindChild('MailSettings').Targets[0].Values[0],
      'A composed child clone should retain its own local Targets.');
    AContext.AssertEquals('NestedTarget', lRoot.FindProperty('Alias').Value.
      StructuralDefinition.Targets[0].Values[0],
      'Structural references should preserve represented-definition Targets.');
    lInline := lRoot.FindProperty('Items').Value.Items[0].StructuralDefinition;
    AContext.AssertEquals('InlineTarget', lInline.Targets[0].Values[0],
      'Targeted inline definitions should be recognized and preserved.');

    lImportCompiler.AddImportedDocument(lCompiler.CompiledDocument);
    AContext.AssertTrue(lImportCompiler.CompileText('import-consumer.nxscript',
      'Thing Consumer {}'), 'Targeted imported definitions should compile.');
    lImportedRoot := lImportCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals(lRoot.Targets[0].Values.Text,
      lImportedRoot.Targets[0].Values.Text,
      'Imported-definition clones should preserve Targets.');
    AContext.AssertTrue(lImportedRoot.Targets <> lRoot.Targets,
      'Imported definitions should own independent Target lists.');
    AContext.AssertTrue(lImportedRoot.Targets[0] <> lRoot.Targets[0],
      'Imported definitions should own independent Target entries.');

    AContext.AssertTrue(lValidatorCompiler.CompileText('target-language.nxscript',
      'Language Test { Definitions: [Definition Thing { Root: True; ' +
      'UnknownProperties: Allow; }, Definition Node { ' +
      'UnknownProperties: Allow; }]; }'),
      'Target-neutral validator language should compile.');
    AContext.AssertTrue(lValidator.Validate(lCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Targets should add no validator policy semantics.');

    AContext.AssertTrue(not lFailureCompiler.CompileText('empty-targets.nxscript',
      'Thing Root Target[] {}'), 'An empty Target clause should fail.');
    AContext.AssertEquals('NXS3005', lFailureCompiler.Diagnostics[0].Code,
      'Empty Target clauses should use a stable diagnostic.');
    AContext.AssertEquals(19, lFailureCompiler.Diagnostics[0].SourceRange.
      StartPosition.Column,
      'The empty-clause diagnostic should point at the closing bracket.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('duplicate-target.nxscript',
      'Thing Root Target[Production, "Production"] {}'),
      'Quoted and unquoted duplicate Targets should fail.');
    AContext.AssertEquals('NXS3006', lFailureCompiler.Diagnostics[0].Code,
      'Duplicate Targets should use a stable diagnostic.');
    AContext.AssertEquals(31, lFailureCompiler.Diagnostics[0].SourceRange.
      StartPosition.Column,
      'The duplicate diagnostic should point at the repeated Target.');
    AContext.AssertTrue(not lFailureCompiler.CompileText(
      'duplicate-target-kind.nxscript',
      'Thing Root Target[Dev] Target[QA] {}'),
      'A repeated Target kind should fail.');
    AContext.AssertEquals('NXS3007', lFailureCompiler.Diagnostics[0].Code,
      'Duplicate Target kinds should use a stable diagnostic.');
    AContext.AssertTrue(lFailureCompiler.CompileText(
      'case-distinct-target-kinds.nxscript',
      'Thing Root Target[Dev] target[QA] {}'),
      'Differently cased Target kinds should remain distinct.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('nested-targets.nxscript',
      'Thing Root Target[Production, [Nested]] {}'),
      'Nested Target arrays should fail.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('missing-comma.nxscript',
      'Thing Root Target[Production Win64] {}'),
      'Missing Target separators should fail.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('trailing-comma.nxscript',
      'Thing Root Target[Production,] {}'),
      'Trailing Target commas should fail.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('missing-bracket.nxscript',
      'Thing Root Target[Production {}'),
      'An unterminated Target clause should fail.');
    AContext.AssertTrue(not lFailureCompiler.CompileText(
      'anonymous-target.nxscript', 'Thing Root [Dev] {}'),
      'The obsolete anonymous Target clause should fail.');
    AContext.AssertTrue(lFailureCompiler.CompileText(
      'composition-target-order.nxscript',
      'Thing Base {} Thing Root (Base) Target[Dev] Platform[Windows] {}'),
      'Composition selectors before named Targets should compile.');
    AContext.AssertTrue(not lFailureCompiler.CompileText(
      'invalid-composition-target-order.nxscript',
      'Thing Base {} Thing Root Target[Dev] (Base) {}'),
      'Composition selectors after a Target clause should fail.');
  finally
    lValidator.Free;
    lValidatorCompiler.Free;
    lFailureCompiler.Free;
    lImportCompiler.Free;
    lCompiler.Free;
  end;
end;

procedure TestTargetFiltering(AContext: TNXTestContext);
const
  cSource =
    'Thing Universal { ' +
    'Thing Always {} Thing DevChild Target[Dev] {} ' +
    'Thing QAChild Target[QA] {} ' +
    'Thing WindowsChild Platform[Windows] {} ' +
    'Thing LinuxChild Platform[Linux] {} ' +
    'Items: [Node Common {}, Node DevInline Target[Dev] {}, ' +
    'Node QAInline Target[QA] {}]; } ' +
    'Thing DevOnly Target[Dev] {} ' +
    'Thing QAOrProd Target[QA, Prod] {} ' +
    'Thing Lower Target[dev] {} ' +
    'Thing WindowsOnly Platform[Windows] {} ' +
    'Thing DevWindows Target[Dev] Platform[Windows] {} ' +
    'Thing DevLinux Target[Dev] Platform[Linux] {}';
var
  lCompiler: TNexusScriptCompiler;
  lOtherCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lSelection: TNexusScriptTargetSelection;
  lOtherSelection: TNexusScriptTargetSelection;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('all-targets.nxscript', cSource),
      'Untargeted compilation should compile the complete model.');
    AContext.AssertEquals(7, lCompiler.CompiledDocument.Definitions.Count,
      'Untargeted compilation should retain every root definition.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Universal');
    AContext.AssertEquals(5, lRoot.Children.Count,
      'Untargeted compilation should retain every child definition.');
    AContext.AssertEquals(3,
      lRoot.FindProperty('Items').Value.Items.Count,
      'Untargeted compilation should retain every inline definition.');
  finally
    lCompiler.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'Dev');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('dev-target.nxscript',
        cSource), 'Dev-targeted compilation should succeed.');
      AContext.AssertEquals(7, lCompiler.SourceDocument.Definitions.Count,
        'Target filtering must not alter the parsed source model.');
      AContext.AssertEquals(5,
        lCompiler.CompiledDocument.Definitions.Count,
        'A selected kind should not filter unselected Platform clauses.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'Universal') <> nil, 'Universal roots should apply to every Target.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DevOnly') <> nil, 'A matching Target value should be retained.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'QAOrProd') = nil,
        'A nonmatching OR Target list should be excluded.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'Lower') = nil, 'Target values should remain case-sensitive.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'WindowsOnly') <> nil,
        'An unselected Platform kind should remain unfiltered.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DevWindows') <> nil,
        'A matching selected kind should retain other dimensions.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DevLinux') <> nil,
        'An unselected Platform must retain all Platform alternatives.');
      lRoot := lCompiler.CompiledDocument.FindDefinition('Universal');
      AContext.AssertTrue(lRoot.FindChild('Always') <> nil,
        'Untargeted children should apply to every Target.');
      AContext.AssertTrue(lRoot.FindChild('DevChild') <> nil,
        'A matching targeted child should be retained.');
      AContext.AssertTrue(lRoot.FindChild('QAChild') = nil,
        'A nonmatching targeted child should be excluded.');
      AContext.AssertTrue(lRoot.FindChild('WindowsChild') <> nil,
        'An unselected child Target kind should remain unfiltered.');
      AContext.AssertTrue(lRoot.FindChild('LinuxChild') <> nil,
        'All alternatives of an unselected child kind should remain.');
      AContext.AssertEquals(2,
        lRoot.FindProperty('Items').Value.Items.Count,
        'A nonmatching inline definition should be removed from its array.');
      AContext.AssertEquals('DevInline', lRoot.FindProperty('Items').Value.
        Items[1].StructuralDefinition.Name,
        'The retained inline array entries should not contain placeholders.');
      AContext.AssertEquals('Dev', lCompiler.CompiledDocument.FindDefinition(
        'DevOnly').Targets[0].Values[0],
        'A retained definition should preserve complete Target metadata.');
    finally
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'QA');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('qa-target.nxscript',
        cSource), 'QA-targeted compilation should succeed.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'QAOrProd') <> nil, 'Any matching value should satisfy an OR list.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DevOnly') = nil,
        'A nonmatching single Target should be excluded.');
    finally
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'Dev');
    lSelection.Add('Platform', 'Windows');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    lSelection.SetValue('Platform', 'Linux');
    try
      AContext.AssertTrue(lCompiler.CompileText('dev-windows.nxscript',
        cSource), 'Multidimensional compilation should succeed.');
      AContext.AssertEquals(4,
        lCompiler.CompiledDocument.Definitions.Count,
        'Every selected Target kind should filter independently.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DevWindows') <> nil,
        'A definition matching every selected kind should survive.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DevLinux') = nil,
        'A mismatch in one selected kind should exclude a definition.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'WindowsOnly') <> nil,
        'A definition absent from another selected kind stays universal.');
    finally
      lCompiler.Free;
    end;

    lOtherSelection := TNexusScriptTargetSelection.Create;
    try
      lOtherSelection.Add('Platform', 'Windows');
      lOtherSelection.Add('Target', 'Dev');
      lOtherCompiler := TNexusScriptCompiler.Create(lOtherSelection);
      try
        AContext.AssertTrue(lOtherCompiler.CompileText(
          'windows-dev.nxscript', cSource),
          'Reordered Target selections should compile.');
        AContext.AssertEquals(4,
          lOtherCompiler.CompiledDocument.Definitions.Count,
          'Selection insertion order should not change the result.');
        AContext.AssertTrue(lOtherCompiler.CompiledDocument.FindDefinition(
          'DevWindows') <> nil,
          'Reordered selections should retain the same definitions.');
        AContext.AssertTrue(lOtherCompiler.CompiledDocument.FindDefinition(
          'DevLinux') = nil,
          'Reordered selections should exclude the same definitions.');
      finally
        lOtherCompiler.Free;
      end;
    finally
      lOtherSelection.Free;
    end;
  finally
    lSelection.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Whatever', 'X');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('unknown-kind.nxscript',
        cSource), 'An unrelated selected kind should compile.');
      AContext.AssertEquals(7,
        lCompiler.CompiledDocument.Definitions.Count,
        'An unrelated selected kind should leave definitions unrestricted.');
    finally
      lCompiler.Free;
    end;

    lSelection.Add('platform', 'Linux');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText(
        'case-distinct-kind.nxscript', cSource),
        'A differently cased Target kind should compile.');
      AContext.AssertEquals(7,
        lCompiler.CompiledDocument.Definitions.Count,
        'A differently cased kind should be unrelated to Platform.');
    finally
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;
end;

procedure TestTargetVariants(AContext: TNXTestContext);
const
  cRootVariants =
    'Thing Base Platform[Linux] { Value: linux; } ' +
    'Thing Base Platform[Windows] { Value: windows; } ' +
    'Thing Result (Base) {}';
  cNestedVariants =
    'Thing Root { ' +
    'Thing Child Platform[Linux] { Value: linux; } ' +
    'Thing Child Platform[Windows] { Value: windows; } ' +
    'Thing Result (Child) {} }';
var
  lCompiler: TNexusScriptCompiler;
  lSelection: TNexusScriptTargetSelection;
  lDefinition: TNexusScriptCompiledDefinition;
  lSourceRoot: TNexusScriptSourceDefinition;
begin
  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Platform', 'Windows');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('root-variants.nxscript',
        cRootVariants), 'A selected root variant should compile.');
      AContext.AssertEquals(3, lCompiler.SourceDocument.Definitions.Count,
        'The source model should retain both same-identity root variants.');
      lDefinition := lCompiler.CompiledDocument.FindDefinition('Base');
      AContext.AssertTrue(lDefinition.SourceDefinition =
        lCompiler.SourceDocument.Definitions[1],
        'A compiled root should retain its exact source association.');
      AContext.AssertEquals('windows', lCompiler.CompiledDocument.
        FindDefinition('Result').FindProperty('Value').Value.EffectiveText,
        'Composition should use the selected root variant, not the first source match.');
    finally
      lCompiler.Free;
    end;

    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('nested-variants.nxscript',
        cNestedVariants), 'A selected nested variant should compile.');
      lSourceRoot := lCompiler.SourceDocument.FindDefinition('Root');
      lDefinition := lCompiler.CompiledDocument.FindDefinition('Root').
        FindChild('Child');
      AContext.AssertTrue(lDefinition.SourceDefinition =
        lSourceRoot.Children[1],
        'A compiled child should retain its exact source association.');
      AContext.AssertEquals('windows', lCompiler.CompiledDocument.
        FindDefinition('Root').FindChild('Result').FindProperty('Value').
        Value.EffectiveText,
        'Nested composition should use the selected variant.');
    finally
      lCompiler.Free;
    end;

    lSelection.SetValue('Platform', 'Linux');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('linux-root-variant.nxscript',
        cRootVariants), 'The other selected root variant should compile.');
      lDefinition := lCompiler.CompiledDocument.FindDefinition('Base');
      AContext.AssertTrue(lDefinition.SourceDefinition =
        lCompiler.SourceDocument.Definitions[0],
        'Selecting Linux should retain the exact Linux source variant.');
      AContext.AssertEquals('linux', lCompiler.CompiledDocument.
        FindDefinition('Result').FindProperty('Value').Value.EffectiveText,
        'Composition should use the selected Linux variant.');
      AContext.AssertTrue(lCompiler.CompileText('linux-nested-variant.nxscript',
        cNestedVariants), 'The other selected nested variant should compile.');
      lSourceRoot := lCompiler.SourceDocument.FindDefinition('Root');
      lDefinition := lCompiler.CompiledDocument.FindDefinition('Root').
        FindChild('Child');
      AContext.AssertTrue(lDefinition.SourceDefinition =
        lSourceRoot.Children[0],
        'Selecting Linux should retain the exact nested source variant.');
      AContext.AssertEquals('linux', lCompiler.CompiledDocument.
        FindDefinition('Root').FindChild('Result').FindProperty('Value').
        Value.EffectiveText,
        'Nested composition should use the selected Linux variant.');
    finally
      lCompiler.Free;
    end;

    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('linux-overlap.nxscript',
        'Thing Build Platform[Windows, Linux] {} ' +
        'Thing Build Platform[Windows] {}'),
        'Overlapping variants should compile when only one survives.');
    finally
      lCompiler.Free;
    end;

    lSelection.SetValue('Platform', 'Windows');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(not lCompiler.CompileText('overlap.nxscript',
        'Thing Build Platform[Windows, Linux] {} ' +
        'Thing Build Platform[Windows] {}'),
        'Overlapping variants should fail when both survive filtering.');
      AContext.AssertEquals('NXS3002', lCompiler.Diagnostics[0].Code,
        'Overlapping root variants should use the ordinary duplicate diagnostic.');
    finally
      lCompiler.Free;
    end;

    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(lCompiler.CompileText('filtered-collision.nxscript',
        'Thing Root { Choice: value; ' +
        'Thing Choice Platform[Linux] {} }'),
        'An excluded child should not collide with a retained property.');
    finally
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;

  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(not lCompiler.CompileText('untargeted-roots.nxscript',
      'Thing Build Platform[Windows] {} Thing Build Platform[Linux] {}'),
      'Untargeted same-identity root variants should fail.');
    AContext.AssertEquals(2, lCompiler.SourceDocument.Definitions.Count,
      'Duplicate validation should not remove source variants.');
    AContext.AssertEquals('NXS3002', lCompiler.Diagnostics[0].Code,
      'Untargeted root variants should use the ordinary duplicate diagnostic.');
  finally
    lCompiler.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'Dev');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(not lCompiler.CompileText('partial-selection.nxscript',
        'Thing Build Platform[Windows] {} Thing Build Platform[Linux] {}'),
        'An unrelated selection should not hide duplicate variants.');
      AContext.AssertEquals('NXS3002', lCompiler.Diagnostics[0].Code,
        'Partially selected root variants should use the ordinary duplicate diagnostic.');
    finally
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;

  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(not lCompiler.CompileText('nested-duplicates.nxscript',
      'Thing Root { Thing Child Platform[Windows] {} ' +
      'Thing Child Platform[Linux] {} }'),
      'Untargeted same-identity children should fail.');
    AContext.AssertEquals('NXS3001', lCompiler.Diagnostics[0].Code,
      'Retained child variants should use the ordinary member diagnostic.');
  finally
    lCompiler.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Platform', 'Linux');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(not lCompiler.CompileText('retained-collision.nxscript',
        'Thing Root { Choice: value; ' +
        'Thing Choice Platform[Linux] {} }'),
        'A retained child should collide with an existing property.');
      AContext.AssertEquals('NXS3001', lCompiler.Diagnostics[0].Code,
        'A retained member collision should use the ordinary diagnostic.');
    finally
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'Dev');
    lSelection.Add('Platform', 'Linux');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    try
      AContext.AssertTrue(not lCompiler.CompileText(
        'platform-composition-excluded.nxscript',
        'Thing Base Target[Dev] Platform[Windows] { Value: windows; } ' +
        'Thing Result (Base) Target[Dev] Platform[Linux] {}'),
        'Composition through a definition excluded by Platform should fail.');
      AContext.AssertTrue(Pos('Unresolved composition target Base',
        lCompiler.Diagnostics[0].MessageText) > 0,
        'Platform exclusion should use the existing composition diagnostic.');
    finally
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;
end;

function FixturePath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('..\..\..\NexusTools\Script\parity\fixtures\' +
    ARelativePath);
  if not FileExists(Result) then
    Result := ExpandFileName('NexusTools\Script\parity\fixtures\' +
      ARelativePath);
end;

function ValidatorFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName('..\..\..\NexusTools\Script\tests\fixtures\validation\' +
    AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName('NexusTools\Script\tests\fixtures\validation\' +
      AFileName);
end;

function DialectFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\dialect\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\dialect\' + AFileName);
end;

function TargetFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\targets\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\targets\' + AFileName);
end;

procedure TestTargetPropagation(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lArtifactContext: TNexusScriptArtifactContext;
  lCompiler: TNexusScriptCompiler;
  lDocument: TNexusScriptCompiledDocument;
  lSelection: TNexusScriptTargetSelection;
begin
  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'Dev');
    lSelection.Add('Platform', 'Windows');
    lSession := TNexusScriptCompilationSession.Create(lSelection);
    lSelection.SetValue('Target', 'QA');
    lSelection.SetValue('Platform', 'Linux');
    lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
    try
      AContext.AssertTrue(lSession.CompileFile(TargetFixturePath(
        'entry.nxscript')), 'The targeted document graph should compile: ' +
        lSession.LastError);
      lDocument := lSession.EntryCompiler.CompiledDocument;
      AContext.AssertTrue(lDocument.FindDefinition('ModuleDev') <> nil,
        'Explicit modules should retain matching Targets.');
      AContext.AssertTrue(lDocument.FindDefinition('ModuleQA') = nil,
        'Explicit modules should exclude nonmatching Targets.');
      AContext.AssertTrue(lDocument.FindDefinition('ModuleDevLinux') = nil,
        'Explicit modules should receive every selected Target kind.');
      AContext.AssertTrue(lDocument.FindDefinition(
        'DiscoveredModuleDev') <> nil,
        'Discovered modules should retain matching Targets.');
      AContext.AssertTrue(lDocument.FindDefinition(
        'DiscoveredModuleQA') = nil,
        'Discovered modules should exclude nonmatching Targets.');
      AContext.AssertTrue(lDocument.FindDefinition(
        'DiscoveredModuleDevLinux') = nil,
        'Discovered modules should receive every selected Target kind.');

      lDocument := lSession.EntryCompiler.CompiledDocument.DialectDocument;
      AContext.AssertTrue(lDocument.FindDefinition('DialectUniversal') <> nil,
        'Dialect documents should retain universal definitions.');
      AContext.AssertTrue(lDocument.FindDefinition('DialectDev') <> nil,
        'Dialect documents should retain matching Targets.');
      AContext.AssertTrue(lDocument.FindDefinition('DialectQA') = nil,
        'Dialect documents should exclude nonmatching Targets.');
      AContext.AssertTrue(lDocument.FindDefinition(
        'DialectDevLinux') = nil,
        'Dialect documents should receive every selected Target kind.');

      lCompiler := lSession.FindCompiler(TargetFixturePath('include.nxscript'));
      AContext.AssertTrue(lCompiler <> nil,
        'The explicit include compiler should be available.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'IncludeDev') <> nil,
        'Explicit includes should retain matching Targets.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'IncludeQA') = nil,
        'Explicit includes should exclude nonmatching Targets.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'IncludeDevLinux') = nil,
        'Explicit includes should receive every selected Target kind.');

      lCompiler := lSession.FindCompiler(TargetFixturePath(
        'includes\discovered.target.nxscript'));
      AContext.AssertTrue(lCompiler <> nil,
        'The discovered include compiler should be available.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DiscoveredIncludeDev') <> nil,
        'Discovered includes should retain matching Targets.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DiscoveredIncludeQA') = nil,
        'Discovered includes should exclude nonmatching Targets.');
      AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
        'DiscoveredIncludeDevLinux') = nil,
        'Discovered includes should receive every selected Target kind.');

      lArtifactContext.Build;
      AContext.AssertEquals(3, lArtifactContext.ArtifactDocuments.Count,
        'Target filtering should not alter include artifact membership.');
      AContext.AssertTrue(lSession.CompileFile(TargetFixturePath(
        'composition-match.nxscript')),
        'Composition through a matching imported Target should compile: ' +
        lSession.LastError);
      AContext.AssertEquals('module-dev', lSession.EntryCompiler.
        CompiledDocument.FindDefinition('Result').FindProperty('Value').Value.
        EffectiveText,
        'A matching Target should contribute through normal composition.');
    finally
      lArtifactContext.Free;
      lSession.Free;
    end;
  finally
    lSelection.Free;
  end;

  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'QA');
    lSession := TNexusScriptCompilationSession.Create(lSelection);
    try
      AContext.AssertTrue(not lSession.CompileFile(TargetFixturePath(
        'composition-excluded.nxscript')),
        'Composition through an excluded Target should fail.');
      AContext.AssertTrue(Pos('Unresolved composition target ModuleDev',
        lSession.LastError) > 0,
        'Excluded composition Targets should use the existing diagnostic.');
    finally
      lSession.Free;
    end;
  finally
    lSelection.Free;
  end;
end;

function IncludeFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\include\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\include\' + AFileName);
end;

function ModuleFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\modules\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\modules\' + AFileName);
end;

function DiscoveryFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\discover\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\discover\' + AFileName);
end;

function CLIFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\cli\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\cli\' + AFileName);
end;

function JSONFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\json\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\json\' + AFileName);
end;

function ManifestFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\manifest\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\manifest\' + AFileName);
end;

function ExternalDataFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\external-data\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\external-data\' + AFileName);
end;

function SchemaGenerationPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\parity\schema-generation\' + ARelativePath);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\parity\schema-generation\' + ARelativePath);
end;

function NewOutputDirectory(const APrefix: string): string;
begin
  Result := GetTempFileName(GetTempDir, APrefix);
  DeleteFile(Result);
end;

function StreamText(AStream: TMemoryStream): string;
var
  lText: RawByteString;
begin
  SetLength(lText, AStream.Size);
  AStream.Position := 0;
  if Length(lText) > 0 then
    AStream.ReadBuffer(Pointer(lText)^, Length(lText));
  Result := string(lText);
end;

function FileText(const AFileName: string): string;
var
  lStream: TFileStream;
  lText: RawByteString;
begin
  lStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(lText, lStream.Size);
    if Length(lText) > 0 then
      lStream.ReadBuffer(Pointer(lText)^, Length(lText));
    Result := string(lText);
  finally
    lStream.Free;
  end;
end;

function SharedDialectRoot: string;
begin
  Result := ExpandFileName('..\..\..\NexusLib\script\dialects');
  if not DirectoryExists(Result) then
    Result := ExpandFileName('NexusLib\script\dialects');
end;

function SharedDialectPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName(IncludeTrailingPathDelimiter(SharedDialectRoot) +
    ARelativePath);
end;

function ExecuteCLI(const AArguments: array of string): string;
var
  lArguments: array of string;
  lIndex: Integer;
  lOutput: TMemoryStream;
begin
  TNXCommandLine.ClearRegisteredFlags;
  TNexusScriptCommand.RegisterCommandLineFlags;
  TNXCommandLine.AllowUnknownFlags := False;
  lOutput := TMemoryStream.Create;
  try
    SetLength(lArguments, Length(AArguments) + 1);
    for lIndex := Low(AArguments) to High(AArguments) do
      lArguments[lIndex] := AArguments[lIndex];
    lArguments[High(lArguments)] := '/dialect-root=' + SharedDialectRoot;
    TNXCommandLine.ParseArguments(lArguments);
    TNXCommandLine.Validate;
    TNexusScriptCommand.Execute(lOutput);
    Result := StreamText(lOutput);
  finally
    lOutput.Free;
    TNXCommandLine.ClearRegisteredFlags;
  end;
end;

function CLIError(const AArguments: array of string): string;
begin
  try
    ExecuteCLI(AArguments);
    Result := '';
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TestDialectParsing(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('none.nxscript',
      'Thing Root {}'), 'Document without dialect should compile.');
    AContext.AssertTrue(lCompiler.SourceDocument.Dialect = nil,
      'Document without dialect should retain no declaration.');

    AContext.AssertTrue(lCompiler.CompileText('quoted.nxscript',
      'dialect "folder/type.nxscript"; Thing Root {}'),
      'Quoted dialect path should parse.');
    AContext.AssertEquals('folder/type.nxscript',
      lCompiler.SourceDocument.Dialect.Path,
      'Quoted dialect path should be retained.');
    AContext.AssertTrue(
      lCompiler.SourceDocument.Dialect.SourceRange.SourceName = 'quoted.nxscript',
      'Dialect source range should retain its source identity.');

    AContext.AssertTrue(lCompiler.CompileText('unquoted.nxscript',
      'module "module.nxscript"; dialect folder/type.nxscript; ' +
      'Thing Root {}'),
      'Unquoted dialect path should parse beside a module.');
    AContext.AssertEquals('folder/type.nxscript',
      lCompiler.SourceDocument.Dialect.Path,
      'Unquoted dialect path should retain punctuation.');

    AContext.AssertTrue(not lCompiler.CompileText('duplicate-dialect.nxscript',
      'dialect "one.nxscript"; dialect "two.nxscript"; ' +
      'Thing Root {}'), 'Duplicate dialect should fail compilation.');
    AContext.AssertEquals('NXS2012', lCompiler.Diagnostics[0].Code,
      'Duplicate dialect diagnostic should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('misplaced-dialect.nxscript',
      'Thing Root {} dialect "type.nxscript";'),
      'Dialect after a definition should fail compilation.');
    AContext.AssertEquals('NXS2014', lCompiler.Diagnostics[0].Code,
      'Misplaced dialect diagnostic should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('malformed-dialect.nxscript',
      'dialect; Thing Root {}'),
      'Dialect without a path should fail compilation.');
    AContext.AssertEquals('NXS2011', lCompiler.Diagnostics[0].Code,
      'Malformed dialect diagnostic should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('named-dialect.nxscript',
      'dialect Rules "type.nxscript"; Thing Root {}'),
      'The removed named dialect form should fail compilation.');
    AContext.AssertEquals('NXS2011', lCompiler.Diagnostics[0].Code,
      'Named dialect rejection should use the declaration diagnostic.');

    AContext.AssertTrue(not lCompiler.CompileText('legacy-doctype.nxscript',
      'doctype "type.nxscript"; Thing Root {}'),
      'The former doctype keyword must not remain as a compatibility alias.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestDialectLoading(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lDocument: TNexusScriptCompiledDocument;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lSession.DialectRoot := SharedDialectRoot;
  try
    AContext.AssertTrue(lSession.CompileFile(
      DialectFixturePath('subject.nxscript')),
      'Dialect subject should compile: ' + lSession.LastError);
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertEquals('type.nxscript', lDocument.DialectPath,
      'Declared dialect path should be retained.');
    AContext.AssertTrue(lDocument.DialectDocument <> nil,
      'Compiled dialect document should be associated.');
    AContext.AssertTrue(lDocument.DialectDocument.FindDefinition('TypeRule') <>
      nil, 'Dialect document should be compiled normally.');
    AContext.AssertTrue(SameText(lDocument.DialectSourceName,
      ExpandFileName(DialectFixturePath('type.nxscript'))),
      'Compiled dialect should retain canonical source identity.');
    lRoot := lDocument.FindDefinition('Root');
    AContext.AssertEquals('metadata',
      lRoot.FindProperty('Imported').Value.EffectiveText,
      'A cached document should remain usable as both dialect and module.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(
      DialectFixturePath('unquoted.nxscript')),
      'Unquoted dialect path should load: ' + lSession.LastError);
    AContext.AssertTrue(not lSession.CompileFile(
      DialectFixturePath('invisible.nxscript')),
      'Dialect definitions must not enter reference lookup.');
    AContext.AssertTrue(not lSession.CompileFile(
      DialectFixturePath('missing.nxscript')),
      'Missing dialect file should fail.');
    AContext.AssertTrue(Pos('dialect', LowerCase(lSession.LastError)) > 0,
      'Missing dialect failure should identify the relationship.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(not lSession.CompileFile(
      DialectFixturePath('cycle-a.nxscript')),
      'Dialect dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Dialect cycle failure should be deterministic.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(not lSession.CompileFile(
      DialectFixturePath('mixed-a.nxscript')),
      'Mixed dialect/module dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Mixed dependency cycle failure should be deterministic.');
  finally
    lSession.Free;
  end;
end;

procedure TestIncludeParsing(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('none.nxscript',
      'Thing Root {}'), 'Document without includes should compile.');
    AContext.AssertEquals(0, lCompiler.SourceDocument.Includes.Count,
      'Document without includes should retain an empty include list.');

    AContext.AssertTrue(lCompiler.CompileText('includes.nxscript',
      'include "folder/one.nxscript"; include folder/two.nxscript; ' +
      'Thing Root {}'), 'Quoted and unquoted include paths should parse.');
    AContext.AssertEquals(2, lCompiler.SourceDocument.Includes.Count,
      'Every include declaration should be retained in source order.');
    AContext.AssertEquals('folder/one.nxscript',
      lCompiler.SourceDocument.Includes[0].Path,
      'Quoted include path should be retained.');
    AContext.AssertEquals('folder/two.nxscript',
      lCompiler.SourceDocument.Includes[1].Path,
      'Unquoted include path should retain punctuation.');

    AContext.AssertTrue(not lCompiler.CompileText('malformed.nxscript',
      'include; Thing Root {}'), 'Include without a path should fail.');
    AContext.AssertEquals('NXS2015', lCompiler.Diagnostics[0].Code,
      'Malformed include diagnostic should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('misplaced.nxscript',
      'Thing Root {} include "leaf.nxscript";'),
      'Include after a definition should fail.');
    AContext.AssertEquals('NXS2016', lCompiler.Diagnostics[0].Code,
      'Misplaced include diagnostic should be deterministic.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestDependencyPatternParsing(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('patterns.nxscript',
      'include "*.include.nxscript"; ' +
      'include recursive "folder/*.include.nxscript"; ' +
      'include recursive "folder/exact.include.nxscript"; ' +
      'module "*.module.nxscript"; ' +
      'module recursive "folder/*.module.nxscript"; ' +
      'module recursive "folder/exact.module.nxscript"; ' +
      'Thing Root {}'), 'Dependency path patterns should parse.');
    AContext.AssertTrue(not lCompiler.SourceDocument.Includes[0].Recursive,
      'A plain include pattern should not recurse.');
    AContext.AssertEquals('*.include.nxscript',
      lCompiler.SourceDocument.Includes[0].Path,
      'An include should retain its complete path pattern.');
    AContext.AssertTrue(lCompiler.SourceDocument.Includes[1].Recursive,
      'A recursive include pattern should retain recursion.');
    AContext.AssertEquals('folder/*.include.nxscript',
      lCompiler.SourceDocument.Includes[1].Path,
      'A recursive include should retain its path and filename mask.');
    AContext.AssertTrue(lCompiler.SourceDocument.Includes[2].Recursive,
      'A recursive exact include should retain recursion.');
    AContext.AssertEquals('folder/exact.include.nxscript',
      lCompiler.SourceDocument.Includes[2].Path,
      'A recursive exact include should retain its complete path.');
    AContext.AssertTrue(not lCompiler.SourceDocument.Modules[0].Recursive,
      'A plain module pattern should not recurse.');
    AContext.AssertEquals('*.module.nxscript',
      lCompiler.SourceDocument.Modules[0].Path,
      'A module should retain its complete path pattern.');
    AContext.AssertTrue(lCompiler.SourceDocument.Modules[1].Recursive,
      'A recursive module pattern should retain recursion.');
    AContext.AssertTrue(lCompiler.SourceDocument.Modules[2].Recursive,
      'A recursive exact module should retain recursion.');
    AContext.AssertEquals('folder/exact.module.nxscript',
      lCompiler.SourceDocument.Modules[2].Path,
      'A recursive exact module should retain its complete path.');

    AContext.AssertTrue(not lCompiler.CompileText('missing-path.nxscript',
      'include recursive; Thing Root {}'),
      'A recursive include requires a path.');
    AContext.AssertEquals('NXS2015', lCompiler.Diagnostics[0].Code,
      'A malformed include pattern should use the include diagnostic.');
    AContext.AssertTrue(not lCompiler.CompileText('missing-module-path.nxscript',
      'module recursive; Thing Root {}'),
      'A recursive module requires a path.');
    AContext.AssertEquals('NXS2002', lCompiler.Diagnostics[0].Code,
      'A malformed module pattern should use the module diagnostic.');
    AContext.AssertTrue(not lCompiler.CompileText('selector-pattern.nxscript',
      'module Root "*.nxscript"; Thing Entry {}'),
      'A wildcard module must not accept a root selector.');
    AContext.AssertEquals('NXS2002', lCompiler.Diagnostics[0].Code,
      'A selected-root wildcard should use the module diagnostic.');
    AContext.AssertTrue(not lCompiler.CompileText('old-include.nxscript',
      'include discover "." "*.nxscript"; Thing Root {}'),
      'The old include discover syntax should fail.');
    AContext.AssertTrue(not lCompiler.CompileText('old-module.nxscript',
      'module discover "." "*.nxscript"; Thing Root {}'),
      'The old module discover syntax should fail.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestIncludePatterns(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lArtifactContext: TNexusScriptArtifactContext;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
  try
    AContext.AssertTrue(lSession.CompileFile(DiscoveryFixturePath(
      'include\nonrecursive\entry.include.nxscript')),
      'A non-recursive include pattern should compile: ' +
      lSession.LastError);
    AContext.AssertEquals(3, lSession.CompilerCount,
      'Non-recursive * and ? patterns should select matching siblings and ' +
      'exclude the declaring document.');
    lArtifactContext.Build;
    AContext.AssertEquals(3, lArtifactContext.ArtifactDocuments.Count,
      'Files selected by either filename wildcard should join the artifact.');
    AContext.AssertTrue(lSession.FindCompiler(DiscoveryFixturePath(
      'include\nonrecursive\nested\nested.include.nxscript')) = nil,
      'A non-recursive pattern should not select nested files.');
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
  try
    AContext.AssertTrue(lSession.CompileFile(DiscoveryFixturePath(
      'include\recursive\entry.nxscript')),
      'Recursive include patterns should compile: ' + lSession.LastError);
    AContext.AssertEquals(4, lSession.CompilerCount,
      'Recursive include patterns should select wildcard and exact matches.');
    AContext.AssertTrue(lSession.FindCompiler(DiscoveryFixturePath(
      'include\recursive\nested\exact.nxscript')) <> nil,
      'A recursive exact include should find its filename in a subfolder.');
    lArtifactContext.Build;
    AContext.AssertEquals(4, lArtifactContext.ArtifactDocuments.Count,
      'Every recursively selected include should join the artifact set.');
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(DiscoveryFixturePath(
      'empty\entry.nxscript')),
      'An empty pattern result should be a no-op: ' + lSession.LastError);
    AContext.AssertEquals(1, lSession.CompilerCount,
      'An empty pattern result should compile only the entry document.');
    AContext.AssertTrue(not lSession.CompileFile(DiscoveryFixturePath(
      'missing-folder.nxscript')),
      'A missing pattern folder should fail.');
    AContext.AssertTrue(Pos('folder not found',
      LowerCase(lSession.LastError)) > 0,
      'A missing pattern folder should report the selection failure.');
  finally
    lSession.Free;
  end;
end;

procedure TestModulePatterns(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(DiscoveryFixturePath(
      'module\nonrecursive\entry.module.nxscript')),
      'A non-recursive module pattern should compile: ' +
      lSession.LastError);
    AContext.AssertEquals(2, lSession.CompilerCount,
      'A module pattern should select its matching sibling and exclude its ' +
      'declaring document.');
    lRoot := lSession.EntryCompiler.CompiledDocument.FindDefinition('Entry');
    AContext.AssertEquals('module',
      lRoot.FindProperty('Value').Value.EffectiveText,
      'Pattern-selected module roots should enter normal reference lookup.');
    AContext.AssertTrue(lSession.FindCompiler(DiscoveryFixturePath(
      'module\nonrecursive\nested\nested.module.nxscript')) = nil,
      'A non-recursive module pattern should not select nested files.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(DiscoveryFixturePath(
      'module\recursive\entry.nxscript')),
      'Recursive module patterns should compile: ' + lSession.LastError);
    lRoot := lSession.EntryCompiler.CompiledDocument.FindDefinition('Entry');
    AContext.AssertEquals('sibling nested exact',
      lRoot.FindProperty('Value').Value.EffectiveText,
      'Recursive module patterns should expose wildcard and exact matches.');
    AContext.AssertTrue(lSession.FindCompiler(DiscoveryFixturePath(
      'module\recursive\nested\exact.nxscript')) <> nil,
      'A recursive exact module should find its filename in a subfolder.');
  finally
    lSession.Free;
  end;
end;

procedure TestPatternRelationshipOverlap(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lArtifactContext: TNexusScriptArtifactContext;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
  try
    AContext.AssertTrue(lSession.CompileFile(DiscoveryFixturePath(
      'overlap\entry.nxscript')),
      'Combined include and module patterns should compile: ' +
      lSession.LastError);
    AContext.AssertEquals(2, lSession.CompilerCount,
      'Both relationships should reuse one compiled dependency document.');
    lRoot := lSession.EntryCompiler.CompiledDocument.FindDefinition('Entry');
    AContext.AssertEquals('shared',
      lRoot.FindProperty('Value').Value.EffectiveText,
      'The module relationship should expose the shared root.');
    lArtifactContext.Build;
    AContext.AssertEquals(2, lArtifactContext.ArtifactDocuments.Count,
      'The include relationship should add the same document to the artifact.');
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;
end;

procedure TestIncludeLoading(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lArtifactContext: TNexusScriptArtifactContext;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
  try
    AContext.AssertTrue(lSession.CompileFile(IncludeFixturePath('entry.nxscript')),
      'Transitive includes should compile: ' + lSession.LastError);
    lArtifactContext.Build;
    AContext.AssertEquals(3, lArtifactContext.ArtifactDocuments.Count,
      'Entry and transitive includes should form one deduplicated artifact set.');
    AContext.AssertEquals('entry.nxscript', ExtractFileName(
      lArtifactContext.ArtifactDocuments[0].CompiledDocument.SourceName),
      'Entry document should be first.');
    AContext.AssertEquals('child.nxscript', ExtractFileName(
      lArtifactContext.ArtifactDocuments[1].CompiledDocument.SourceName),
      'Includes should follow declaration-order depth-first traversal.');
    AContext.AssertEquals('leaf.nxscript', ExtractFileName(
      lArtifactContext.ArtifactDocuments[2].CompiledDocument.SourceName),
      'A repeated canonical include should appear only once.');

    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('multiple.nxscript')),
      'Session reuse should compile a new artifact graph: ' +
      lSession.LastError);
    lArtifactContext.Build;
    AContext.AssertEquals(3, lArtifactContext.ArtifactDocuments.Count,
      'Session reuse should replace rather than append artifact state.');
    AContext.AssertEquals('second.nxscript', ExtractFileName(
      lArtifactContext.ArtifactDocuments[2].CompiledDocument.SourceName),
      'Independent includes should retain declaration order.');
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
  try
    AContext.AssertTrue(not lSession.CompileFile(
      IncludeFixturePath('invisible.nxscript')),
      'Included definitions must not enter reference lookup.');
    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('module-and-include.nxscript')),
      'One document may be both a module and an include: ' +
      lSession.LastError);
    lArtifactContext.Build;
    AContext.AssertEquals(2, lArtifactContext.ArtifactDocuments.Count,
      'The included dependency should join the artifact set once.');
    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('module-only.nxscript')),
      'A module-only dependency should compile: ' + lSession.LastError);
    lArtifactContext.Build;
    AContext.AssertEquals(1, lArtifactContext.ArtifactDocuments.Count,
      'Module dependencies should not automatically become artifacts.');
    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('dialect-only.nxscript')),
      'A dialect-only dependency should compile: ' + lSession.LastError);
    lArtifactContext.Build;
    AContext.AssertEquals(1, lArtifactContext.ArtifactDocuments.Count,
      'Dialect dependencies should not automatically become artifacts.');
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
  try
    AContext.AssertTrue(not lSession.CompileFile(
      IncludeFixturePath('missing.nxscript')),
      'Missing include file should fail.');
    AContext.AssertTrue(Pos('include', LowerCase(lSession.LastError)) > 0,
      'Missing include failure should identify the relationship.');
    AContext.AssertTrue(not lSession.CompileFile(
      IncludeFixturePath('invalid-entry.nxscript')),
      'An invalid included document should fail the entry compilation.');
    AContext.AssertTrue(Pos('include', LowerCase(lSession.LastError)) > 0,
      'Included compilation failure should identify the relationship.');
    AContext.AssertTrue(not lSession.CompileFile(
      IncludeFixturePath('cycle-a.nxscript')),
      'Include dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Include cycle failure should be deterministic.');
    AContext.AssertTrue(not lSession.CompileFile(
      IncludeFixturePath('mixed-a.nxscript')),
      'Mixed include, dialect, and module dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Mixed dependency cycle failure should be deterministic.');
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;
end;

function ValidationFailure(AValidator: TNexusScriptValidator): string;
begin
  if AValidator.Diagnostics.Count = 0 then
    Result := 'no diagnostic'
  else
    Result := AValidator.Diagnostics[0].Code + ': ' +
      AValidator.Diagnostics[0].MessageText;
end;

procedure TestLanguageSelfValidation(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lLanguageDefinition: TNexusScriptLanguageDefinition;
  lValidator: TNexusScriptValidator;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lLanguageDefinition := TNexusScriptLanguageDefinition.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(
      SharedDialectPath('Language\Language.nxscript')),
      'Language definition should compile: ' + lSession.LastError);
    AContext.AssertTrue(lLanguageDefinition.Normalize(
      lSession.EntryCompiler.CompiledDocument),
      'Public language definition should normalize the foundational language.');
    AContext.AssertEquals(0, lLanguageDefinition.DiagnosticCount,
      'Successful public normalization should have no diagnostics.');
    AContext.AssertTrue(
      lLanguageDefinition.FindDefinitionRule('Language') <> nil,
      'Public language definition should expose read-only rule lookup.');
    AContext.AssertTrue(lValidator.Validate(
      lSession.EntryCompiler.CompiledDocument,
      lSession.EntryCompiler.CompiledDocument),
      'Language definition should validate itself: ' +
      ValidationFailure(lValidator));
  finally
    lValidator.Free;
    lLanguageDefinition.Free;
    lSession.Free;
  end;
end;

procedure TestSchemaValidation(AContext: TNXTestContext);
var
  lSubjectSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
  lSubjectDocument: TNexusScriptCompiledDocument;
  lSchemaDocument: TNexusScriptCompiledDocument;
  lLanguageDocument: TNexusScriptCompiledDocument;
begin
  lSubjectSession := TNexusScriptCompilationSession.Create;
  lSubjectSession.DialectRoot := SharedDialectRoot;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSubjectSession.CompileFile(
      ValidatorFixturePath('Customer.Schema.nxscript')),
      'Schema subject should compile: ' + lSubjectSession.LastError);
    lSubjectDocument := lSubjectSession.EntryCompiler.CompiledDocument;
    lSchemaDocument := lSubjectDocument.DialectDocument;
    AContext.AssertTrue(lSchemaDocument <> nil,
      'Subject should retain its compiled Schema dialect.');
    lLanguageDocument := lSchemaDocument.DialectDocument;
    AContext.AssertTrue(lLanguageDocument <> nil,
      'Schema should retain its compiled Language dialect.');
    AContext.AssertTrue(SameFileName(lLanguageDocument.SourceName,
      SharedDialectPath('Language\Language.nxscript')),
      'A missing local dialect should resolve from the shared dialect root.');
    AContext.AssertTrue(lValidator.Validate(lSchemaDocument,
      lLanguageDocument),
      'Schema language should satisfy the Language contract: ' +
      ValidationFailure(lValidator));
    AContext.AssertTrue(lValidator.Validate(lSubjectDocument, lSchemaDocument),
      'Schema subject should satisfy its validator: ' +
      ValidationFailure(lValidator));
  finally
    lValidator.Free;
    lSubjectSession.Free;
  end;
end;

procedure TestSharedDialectCatalog(AContext: TNXTestContext);
const
  cDialectPaths: array[0..3] of string = (
    'Bot\Bot.Language.nxscript',
    'NexusManifest\NexusManifest.Language.nxscript',
    'Schema\Schema.Language.nxscript',
    'WorkspaceIndex\WorkspaceIndex.Language.nxscript');
var
  lDocument: TNexusScriptCompiledDocument;
  lIndex: Integer;
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lSession.DialectRoot := SharedDialectRoot;
  lValidator := TNexusScriptValidator.Create;
  try
    for lIndex := Low(cDialectPaths) to High(cDialectPaths) do
    begin
      AContext.AssertTrue(lSession.CompileFile(
        SharedDialectPath(cDialectPaths[lIndex])),
        cDialectPaths[lIndex] + ' should compile: ' + lSession.LastError);
      lDocument := lSession.EntryCompiler.CompiledDocument;
      AContext.AssertTrue(Assigned(lDocument.DialectDocument),
        cDialectPaths[lIndex] + ' should resolve the foundational dialect.');
      AContext.AssertTrue(lValidator.Validate(lDocument,
        lDocument.DialectDocument),
        cDialectPaths[lIndex] + ' should validate against Language: ' +
        ValidationFailure(lValidator));
    end;
  finally
    lValidator.Free;
    lSession.Free;
  end;
end;

procedure TestIndependentContainmentRules(AContext: TNXTestContext);
var
  lValidatorCompiler: TNexusScriptCompiler;
  lSubjectCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
begin
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lSubjectCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSubjectCompiler.CompileText('subject.nxscript',
      'Parent Root { Child Nested {} }'), 'Subject should compile.');
    AContext.AssertTrue(lValidatorCompiler.CompileText('parents.nxscript',
      'Language Test { Definitions: [' +
      'Definition Parent { Root: True; UnknownProperties: Allow; },' +
      'Definition Child { Parents: [Parent]; UnknownProperties: Allow; }]; }'),
      'Parents-only validator should compile.');
    AContext.AssertTrue(lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Parents-only containment should pass: ' + ValidationFailure(lValidator));

    AContext.AssertTrue(lValidatorCompiler.CompileText('children.nxscript',
      'Language Test { Definitions: [' +
      'Definition Parent { Root: True; UnknownProperties: Allow; Children: [' +
      'Child NestedKinds { Kinds: [Child]; Minimum: 1; }]; },' +
      'Definition Child { UnknownProperties: Allow; }]; }'),
      'Children-only validator should compile.');
    AContext.AssertTrue(lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Children-only containment should pass: ' + ValidationFailure(lValidator));

    AContext.AssertTrue(lValidatorCompiler.CompileText('intersection.nxscript',
      'Language Test { Definitions: [' +
      'Definition Parent { Root: True; UnknownProperties: Allow; Children: [' +
      'Child NestedKinds { Kinds: [Child]; }]; },' +
      'Definition Other { Root: True; UnknownProperties: Allow; },' +
      'Definition Child { Parents: [Other]; UnknownProperties: Allow; }]; }'),
      'Intersecting validator should compile.');
    AContext.AssertTrue(not lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Both containment constraints should apply when both are present.');
  finally
    lValidator.Free;
    lSubjectCompiler.Free;
    lValidatorCompiler.Free;
  end;
end;

procedure TestValidatorDiagnostics(AContext: TNXTestContext);
var
  lValidatorCompiler: TNexusScriptCompiler;
  lSubjectCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
begin
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lSubjectCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lValidatorCompiler.CompileText('rules.nxscript',
      'Language Test { Definitions: [' +
      'Definition Thing { Root: True; UnknownProperties: Reject; Properties: [' +
      'Property RequiredValue { Required: True; Value Value { Scalar: Integer; } },' +
      'Property Items { Value Value { EffectiveCategories: [Array]; Array Array {' +
      'Minimum: 2; Names: Required; EntryEffectiveCategories: [Text]; } } }]; }]; }'),
      'Diagnostic validator should compile.');
    AContext.AssertTrue(lSubjectCompiler.CompileText('invalid.nxscript',
      'Thing Root { Extra: value; Items: [one]; }'),
      'Invalid subject should still compile generically.');
    AContext.AssertTrue(not lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Domain-invalid subject should fail validation.');
    AContext.AssertTrue(lValidator.Diagnostics.Count >= 3,
      'Missing, unknown, and invalid-array diagnostics should be returned.');
    AContext.AssertEquals('NSV2101', lValidator.Diagnostics[0].Code,
      'Required-property diagnostic should be deterministic.');
  finally
    lValidator.Free;
    lSubjectCompiler.Free;
    lValidatorCompiler.Free;
  end;
end;

procedure TestValidatorReferences(AContext: TNXTestContext);
var
  lValidatorCompiler: TNexusScriptCompiler;
  lSubjectCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
begin
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lSubjectCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lValidatorCompiler.CompileText('references.nxscript',
      'Language Test { Definitions: [' +
      'Definition Thing { Root: True; UnknownProperties: Reject; Properties: [' +
      'Property Name { Value Value { Scalar: Text; } },' +
      'Property Link { Value Value { SourceForms: [Reference]; ' +
      'EffectiveCategories: [Definition]; Reference Reference {' +
      'Targets: [Definition]; DefinitionKinds: [Thing]; } } }]; Children: [' +
      'Child Things { Kinds: [Thing]; }]; }]; }'),
      'Reference validator should compile.');
    AContext.AssertTrue(lSubjectCompiler.CompileText('valid-reference.nxscript',
      'Thing Root { Thing Target {} Thing Holder { Link: @Root.Target; } }'),
      'Valid reference subject should compile.');
    AContext.AssertTrue(lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Definition reference should satisfy its target rule: ' +
      ValidationFailure(lValidator));
    AContext.AssertTrue(lSubjectCompiler.CompileText('invalid-reference.nxscript',
      'Thing Root { Name: value; Thing Holder { Link: @Root.Name; } }'),
      'Property-reference subject should compile.');
    AContext.AssertTrue(not lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Property reference should fail a definition-target rule.');
    AContext.AssertEquals('NSV2302', lValidator.Diagnostics[0].Code,
      'Effective target-category failure should be deterministic.');
  finally
    lValidator.Free;
    lSubjectCompiler.Free;
    lValidatorCompiler.Free;
  end;
end;

procedure TestInvalidLanguageDefinition(AContext: TNXTestContext);
var
  lValidatorCompiler: TNexusScriptCompiler;
  lSubjectCompiler: TNexusScriptCompiler;
  lLanguageDefinition: TNexusScriptLanguageDefinition;
  lValidator: TNexusScriptValidator;
begin
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lSubjectCompiler := TNexusScriptCompiler.Create;
  lLanguageDefinition := TNexusScriptLanguageDefinition.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lValidatorCompiler.CompileText('invalid-validator.nxscript',
      'Language Test { Definitions: [' +
      'Definition Thing { Root: True; Unexpected: value; }]; }'),
      'Malformed validator should remain valid generic NexusScript.');
    AContext.AssertTrue(lSubjectCompiler.CompileText('subject.nxscript',
      'Thing Root {}'), 'Subject should compile.');
    AContext.AssertTrue(not lLanguageDefinition.Normalize(
      lValidatorCompiler.CompiledDocument),
      'Public normalization should reject invalid language vocabulary.');
    AContext.AssertEquals(0, lLanguageDefinition.DefinitionRuleCount,
      'Failed normalization should not expose partial rules.');
    AContext.AssertEquals('NSV1007', lLanguageDefinition.Diagnostics[0].Code,
      'Public normalization should retain validator diagnostic codes.');
    AContext.AssertTrue(not lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Unknown validator vocabulary should fail normalization.');
    AContext.AssertEquals('NSV1007', lValidator.Diagnostics[0].Code,
      'Invalid rule diagnostic should be deterministic.');
  finally
    lValidator.Free;
    lLanguageDefinition.Free;
    lSubjectCompiler.Free;
    lValidatorCompiler.Free;
  end;
end;

procedure TestLanguageFiniteValues(AContext: TNXTestContext);
var
  lMetaSession: TNexusScriptCompilationSession;
  lSubjectCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
begin
  lMetaSession := TNexusScriptCompilationSession.Create;
  lSubjectCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lMetaSession.CompileFile(
      SharedDialectPath('Language\Language.nxscript')),
      'Foundational Language definition should compile: ' +
      lMetaSession.LastError);

    AContext.AssertTrue(lSubjectCompiler.CompileText('bad-policy.nxscript',
      'Language Bad { UnknownDefinitions: Maybe; Definitions: [' +
      'Definition Thing { Root: True; }]; }'),
      'Invalid-policy language definition should compile generically.');
    AContext.AssertTrue(not lValidator.Validate(
      lSubjectCompiler.CompiledDocument,
      lMetaSession.EntryCompiler.CompiledDocument),
      'Self-validator should reject an unknown policy value.');
    AContext.AssertEquals('NSV2306', lValidator.Diagnostics[0].Code,
      'Unknown policy should fail the scalar allowed-values rule.');

    AContext.AssertTrue(lSubjectCompiler.CompileText('bad-name-policy.nxscript',
      'Language Bad { Definitions: [Definition Thing { Root: True; ' +
      'Properties: [Property Items { Value Value { Array Array {' +
      'Names: Banana; } } }]; }]; }'),
      'Invalid-name-policy language definition should compile generically.');
    AContext.AssertTrue(not lValidator.Validate(
      lSubjectCompiler.CompiledDocument,
      lMetaSession.EntryCompiler.CompiledDocument),
      'Self-validator should reject an unknown array naming policy.');
    AContext.AssertEquals('NSV2306', lValidator.Diagnostics[0].Code,
      'Unknown naming policy should fail the scalar allowed-values rule.');

    AContext.AssertTrue(lSubjectCompiler.CompileText('bad-source-form.nxscript',
      'Language Bad { Definitions: [Definition Thing { Root: True; ' +
      'Properties: [Property Data { Value Value {' +
      'SourceForms: [Text, Banana]; } }]; }]; }'),
      'Invalid-source-form language definition should compile generically.');
    AContext.AssertTrue(not lValidator.Validate(
      lSubjectCompiler.CompiledDocument,
      lMetaSession.EntryCompiler.CompiledDocument),
      'Self-validator should reject an unknown source-form entry.');
    AContext.AssertEquals('NSV2409', lValidator.Diagnostics[0].Code,
      'Unknown source form should fail the array allowed-values rule.');
  finally
    lValidator.Free;
    lSubjectCompiler.Free;
    lMetaSession.Free;
  end;
end;

procedure TestCommandLineParsing(AContext: TNXTestContext);
var
  lError: string;
begin
  TNXCommandLine.ClearRegisteredFlags;
  TNexusScriptCommand.RegisterCommandLineFlags;
  TNXCommandLine.AllowUnknownFlags := False;
  try
    AContext.AssertTrue(Pos('/input', TNXCommandLine.HelpText) > 0,
      'Generated help should include input.');
    AContext.AssertTrue(Pos('/template', TNXCommandLine.HelpText) > 0,
      'Generated help should include template.');
    AContext.AssertTrue(Pos('/manifest', TNXCommandLine.HelpText) > 0,
      'Generated help should include manifest.');
    AContext.AssertTrue(Pos('/dialect-root', TNXCommandLine.HelpText) > 0,
      'Generated help should include the shared dialect root.');

    TNXCommandLine.ParseArguments([]);
    try
      TNXCommandLine.Validate;
      lError := '';
    except
      on E: Exception do lError := E.Message;
    end;
    AContext.AssertEquals('', lError,
      'Syntax validation should allow mode-dependent input selection.');

    TNXCommandLine.ParseArguments(['/input=script.nxscript', '/unknown']);
    try
      TNXCommandLine.Validate;
      lError := '';
    except
      on E: Exception do lError := E.Message;
    end;
    AContext.AssertTrue(Pos('unknown', LowerCase(lError)) > 0,
      'Unknown options should be rejected.');

    TNXCommandLine.ParseArguments(['script.nxscript']);
    try
      TNXCommandLine.Validate;
      lError := '';
    except
      on E: Exception do lError := E.Message;
    end;
    AContext.AssertTrue(Pos('invalid', LowerCase(lError)) > 0,
      'Positional input should be rejected.');

    TNXCommandLine.ParseArguments(['/input=script.nxscript', '/format=json']);
    try
      TNXCommandLine.Validate;
      lError := '';
    except
      on E: Exception do lError := E.Message;
    end;
    AContext.AssertTrue(Pos('format', LowerCase(lError)) > 0,
      'Removed mode options should remain unknown.');
  finally
    TNXCommandLine.ClearRegisteredFlags;
  end;
  AContext.AssertTrue(Pos('input', LowerCase(CLIError([]))) > 0,
    'Execution without input or manifest should fail clearly.');
end;

procedure TestNexusManifestLanguage(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
  lDocument: TNexusScriptCompiledDocument;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lSession.DialectRoot := SharedDialectRoot;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(SharedDialectPath(
      'NexusManifest\NexusManifest.Language.nxscript')),
      'NexusManifest language should compile with the foundational Language definition.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'NexusManifest language should validate against Language.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('Valid.NexusManifest.nxscript')),
      'Manifest with auxiliary properties should compile.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'A manifest with only Template renderers should validate.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('ExternalData.NexusManifest.nxscript')),
      'Manifest with only SourceTemplate renderers should compile.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'A manifest with only SourceTemplate renderers should validate.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('BothRenderers.NexusManifest.nxscript')),
      'Manifest with both renderer kinds should compile.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'A manifest with both renderer kinds should validate.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingOutput.NexusManifest.nxscript')),
      'Structurally invalid manifest should still compile.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'Manifest missing Output should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingModel.NexusManifest.nxscript')),
      'Manifest missing Model should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'Manifest missing Model should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingRenderer.NexusManifest.nxscript')),
      'Manifest missing a renderer should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'Manifest missing both renderer kinds should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingModelSource.NexusManifest.nxscript')),
      'Manifest missing Model.Source should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'Manifest missing Model.Source should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('UnknownChild.NexusManifest.nxscript')),
      'Manifest with unknown child should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'Manifest with unknown child should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('WrongModelPlacement.NexusManifest.nxscript')),
      'Manifest with nested Model should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DialectDocument),
      'Model outside the manifest root should fail validation.');
  finally
    lValidator.Free;
    lSession.Free;
  end;
end;

procedure TestCommandTemplateManifest(AContext: TNXTestContext);
var
  lOutputDirectory: string;
  lError: string;
begin
  AContext.AssertTrue(Pos('mutually exclusive', LowerCase(CLIError([
    '/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
    '/template=' + CLIFixturePath('Name.mustache'),
    '/manifest=' + ManifestFixturePath('Valid.NexusManifest.nxscript'),
    '/output=unused']))) > 0,
    'Template and manifest options should be mutually exclusive.');
  AContext.AssertTrue(Pos('output directory', LowerCase(CLIError([
    '/manifest=' + ManifestFixturePath('Valid.NexusManifest.nxscript')]))) > 0,
    'Manifest rendering should require an output directory.');
  AContext.AssertTrue(Pos('mutually exclusive', LowerCase(CLIError([
    '/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
    '/manifest=' + ManifestFixturePath('Valid.NexusManifest.nxscript'),
    '/output=unused']))) > 0,
    'Input and manifest options should be mutually exclusive.');

  lOutputDirectory := NewOutputDirectory('nsm');
  try
    AContext.AssertEquals('', ExecuteCLI([
      '/manifest=' + ManifestFixturePath('Valid.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]),
      'Manifest rendering should not write to stdout.');
    AContext.AssertEquals('First Example', Trim(FileText(
      lOutputDirectory + '\generated\first.txt')),
      'First manifest entry should use the shared JSON artifact.');
    AContext.AssertEquals('Second Example', Trim(FileText(
      lOutputDirectory + '\second.txt')),
      'Local reference composition should provide the second output path.');
  finally
    DeleteFile(lOutputDirectory + '\generated\first.txt');
    DeleteFile(lOutputDirectory + '\second.txt');
    RemoveDir(lOutputDirectory + '\generated');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nso');
  try
    ExecuteCLI([
      '/manifest=' + ManifestFixturePath('Ordered.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertEquals('Second Example', Trim(FileText(
      lOutputDirectory + '\shared.txt')),
      'Compiled child order should determine ordinary overwrite order.');
  finally
    DeleteFile(lOutputDirectory + '\shared.txt');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsf');
  try
    lError := CLIError([
      '/manifest=' + ManifestFixturePath('Failure.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue(Pos('GeneratedFiles.Missing', lError) > 0,
      'A render failure should identify the current manifest entry.');
    AContext.AssertTrue(FileExists(lOutputDirectory + '\first.txt'),
      'A later failure should not roll back an earlier successful write.');
  finally
    DeleteFile(lOutputDirectory + '\first.txt');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsl');
  try
    ExecuteCLI([
      '/manifest=' + ManifestFixturePath('Literal.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue(FileExists(lOutputDirectory + '\{{Name}}.txt'),
      'Output EffectiveText should not receive Mustache interpolation.');
  finally
    DeleteFile(lOutputDirectory + '\{{Name}}.txt');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nst');
  try
    lError := CLIError([
      '/manifest=' + ManifestFixturePath('Traversal.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue(Pos('GeneratedFiles.Escape', lError) > 0,
      'Unsafe output diagnostics should identify the manifest entry.');
    AContext.AssertTrue(Pos('escapes', LowerCase(lError)) > 0,
      'Traversal outside the output directory should be rejected.');
  finally
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsm');
  try
    ExecuteCLI([
      '/manifest=' + ManifestFixturePath('MultiModel.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertEquals('Example_TBL', Trim(FileText(
      lOutputDirectory + '\combined.txt')),
      'Independent models should contribute sibling roots to one context.');
  finally
    DeleteFile(lOutputDirectory + '\combined.txt');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsa');
  try
    ExecuteCLI([
      '/manifest=' + ManifestFixturePath(
      'MultiModelAlternative.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertEquals('Example_ALT', Trim(FileText(
      lOutputDirectory + '\combined.txt')),
      'A complete alternative constants model should change template data.');
  finally
    DeleteFile(lOutputDirectory + '\combined.txt');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsi');
  try
    ExecuteCLI([
      '/manifest=' + ManifestFixturePath('IncludedOnce.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertEquals('one/common/two', Trim(FileText(
      lOutputDirectory + '\included.txt')),
      'A shared canonical include should contribute once across model sessions.');
  finally
    DeleteFile(lOutputDirectory + '\included.txt');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsd');
  try
    lError := CLIError([
      '/manifest=' + ManifestFixturePath('DuplicateModel.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue((Pos('DuplicateModel.Second', lError) > 0) and
      (Pos('more than once', LowerCase(lError)) > 0),
      'A duplicate direct canonical model source should identify the later entry.');
    AContext.AssertTrue(not FileExists(lOutputDirectory + '\result.txt'),
      'Duplicate model failure should occur before output.');
  finally
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsr');
  try
    lError := CLIError([
      '/manifest=' + ManifestFixturePath('DuplicateRoot.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue((Pos('DuplicateRoot.Second', lError) > 0) and
      (Pos('duplicate artifact root', LowerCase(lError)) > 0),
      'Different files with the same root should fail without aliasing.');
    AContext.AssertTrue(not FileExists(lOutputDirectory + '\result.txt'),
      'Root collision should occur before output.');
  finally
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsv');
  try
    ExecuteCLI([
      '/manifest=' + ManifestFixturePath('ValidatedModels.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory, '/validate']);
    AContext.AssertTrue(FileExists(lOutputDirectory + '\result.txt'),
      'Validation should accept plain models and validate typed models.');
  finally
    DeleteFile(lOutputDirectory + '\result.txt');
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsv');
  try
    lError := CLIError([
      '/manifest=' + ManifestFixturePath('InvalidModel.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory, '/validate']);
    AContext.AssertTrue((Pos('InvalidModel.Broken', lError) > 0) and
      (Pos('NSV', lError) > 0),
      'A typed model validation failure should identify its manifest entry.');
    AContext.AssertTrue(not FileExists(lOutputDirectory + '\result.txt'),
      'Model validation failure should occur before output.');
  finally
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nsc');
  try
    lError := CLIError([
      '/manifest=' + ManifestFixturePath('MissingModelFile.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue(Pos('MissingModelFile.Missing', lError) > 0,
      'A model compilation failure should identify its manifest entry.');
    AContext.AssertTrue(not FileExists(lOutputDirectory + '\result.txt'),
      'Model compilation failure should occur before output.');
  finally
    RemoveDir(lOutputDirectory);
  end;
end;

procedure TestCommandJSONArtifact(AContext: TNXTestContext);
var
  lActual: string;
  lIncluded: string;
  lModuleJSON: string;
  lUnsupported: string;
  lOutputFile: string;
begin
  lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.Artifact.nxscript')]);
  AContext.AssertTrue(Pos('"Example"', lActual) > 0,
    'Default command output should contain the named root definition.');
  AContext.AssertTrue(Pos('"Kind" : "Schema"', lActual) > 0,
    'Default command output should contain definition metadata.');

  lOutputFile := GetTempFileName(GetTempDir, 'nsc');
  try
    lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
      '/output=' + lOutputFile]);
    AContext.AssertEquals('', lActual,
      'File output should leave stdout empty.');
    AContext.AssertEquals(ExecuteCLI([
      '/input=' + CLIFixturePath('Valid.Artifact.nxscript')]),
      FileText(lOutputFile),
      'File output should match stdout JSON exactly.');
  finally
    DeleteFile(lOutputFile);
  end;

  AContext.AssertTrue(Pos('file not found', LowerCase(CLIError([
    '/input=' + CLIFixturePath('Missing.nxscript')]))) > 0,
    'Missing input should fail clearly.');
  AContext.AssertTrue(Pos('compilation failed', LowerCase(CLIError([
    '/input=' + CLIFixturePath('Invalid.nxscript')]))) > 0,
    'Invalid NexusScript should fail before output.');
  lUnsupported := ExecuteCLI([
    '/input=' + CLIFixturePath('Unsupported.nxscript')]);
  AContext.AssertTrue(Pos('"Unsupported"', lUnsupported) > 0,
    'The generic emitter should serialize arbitrary definition kinds.');

  lIncluded := ExecuteCLI([
    '/input=' + IncludeFixturePath('entry.nxscript')]);
  AContext.AssertTrue((Pos('"Entry"', lIncluded) > 0) and
    (Pos('"Child"', lIncluded) > 0) and
    (Pos('"Leaf"', lIncluded) > 0),
    'The CLI should aggregate every artifact document into one JSON root.');

  lModuleJSON := ExecuteCLI([
    '/input=' + ModuleFixturePath('entry.nxscript')]);
  AContext.AssertTrue((Pos('"Greeting" : "hello world"', lModuleJSON) > 0) and
    (Pos('"Other" : "other"', lModuleJSON) > 0),
    'Module references should serialize only their completed domain values.');
end;

procedure TestCommandTemplateArtifact(AContext: TNXTestContext);
var
  lActual: string;
  lOutputFile: string;
begin
  lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
    '/template=' + CLIFixturePath('Name.mustache')]);
  AContext.AssertEquals('Example', Trim(lActual),
    'A template should transform the normal JSON artifact.');

  lOutputFile := GetTempFileName(GetTempDir, 'nst');
  try
    lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
      '/template=' + CLIFixturePath('Name.mustache'),
      '/output=' + lOutputFile]);
    AContext.AssertEquals('', lActual,
      'Rendered file output should leave stdout empty.');
    AContext.AssertEquals('Example', Trim(FileText(lOutputFile)),
      'Rendered file output should contain the final artifact.');
  finally
    DeleteFile(lOutputFile);
  end;

  AContext.AssertTrue(Pos('file not found', LowerCase(CLIError([
    '/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
    '/template=' + CLIFixturePath('Missing.mustache')]))) > 0,
    'Missing templates should fail clearly.');

  lActual := ExecuteCLI([
    '/input=' + JSONFixturePath('NexusSchemaShape.nxscript'),
    '/template=' + JSONFixturePath('NexusSchemaShape.mustache')]);
  AContext.AssertEquals('Example(Main):PERSON,ADDRESS', Trim(lActual),
    'A NexusSchema-shaped model should render through ordinary sections, ' +
    'dotted lookup, and -last.');

  lActual := ExecuteCLI([
    '/input=' + JSONFixturePath('Product.nxscript'),
    '/template=' + JSONFixturePath('Product.mustache')]);
  AContext.AssertEquals('Nexus:ID=UUID,Created=Timestamp', Trim(lActual),
    'An unrelated domain should consume the same generic JSON shape.');
end;

procedure TestCommandValidation(AContext: TNXTestContext);
var
  lActual: string;
  lError: string;
begin
  lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
    '/validate']);
  AContext.AssertTrue(Pos('"Example"', lActual) > 0,
    'Successful dialect validation should allow artifact generation.');

  lActual := ExecuteCLI(['/input=' +
    FixturePath('nexusscript\inForceMain.Schema.nxscript'), '/validate']);
  AContext.AssertTrue(Pos('"inForce"', lActual) > 0,
    'Successful compilation should validate a document without a dialect.');

  lError := CLIError(['/input=' +
    CLIFixturePath('InvalidValidation.Schema.nxscript'), '/validate']);
  AContext.AssertTrue(Pos('NSV', lError) > 0,
    'Validation failure should report validator diagnostics.');

  lError := CLIError(['/input=' + CLIFixturePath('Valid.Artifact.nxscript'),
    '/validate=true']);
  AContext.AssertTrue(Pos('does not accept', LowerCase(lError)) > 0,
    'Validate should reject an assigned value.');
end;

function RequireJSONObject(AData: TJSONData;
  const ADescription: string): TJSONObject;
begin
  if not (AData is TJSONObject) then
    raise Exception.Create(ADescription + ' must be a JSON object.');
  Result := TJSONObject(AData);
end;

function RequireJSONArray(AData: TJSONData;
  const ADescription: string): TJSONArray;
begin
  if not (AData is TJSONArray) then
    raise Exception.Create(ADescription + ' must be a JSON array.');
  Result := TJSONArray(AData);
end;

function RequireJSONMember(AObject: TJSONObject; const AName: string): TJSONData;
begin
  Result := AObject.Find(AName);
  if Result = nil then
    raise Exception.CreateFmt('Missing JSON member %s.', [AName]);
end;

procedure AssertDefinitionSourceRangeJSON(AContext: TNXTestContext;
  AMetaData: TJSONObject; const ASourceRange: TNexusScriptRange;
  const ADescription: string);
var
  lSourceRange: TJSONObject;
  lStartPosition: TJSONObject;
  lEndPosition: TJSONObject;
begin
  lSourceRange := RequireJSONObject(RequireJSONMember(AMetaData,
    'SourceRange'), ADescription + ' source range');
  lStartPosition := RequireJSONObject(RequireJSONMember(lSourceRange,
    'StartPosition'), ADescription + ' start position');
  lEndPosition := RequireJSONObject(RequireJSONMember(lSourceRange,
    'EndPosition'), ADescription + ' end position');
  AContext.AssertEquals(ASourceRange.SourceName,
    RequireJSONMember(lSourceRange, 'SourceName').AsString,
    ADescription + ' should retain its source name.');
  AContext.AssertEquals(ASourceRange.StartPosition.Offset,
    RequireJSONMember(lStartPosition, 'Offset').AsInteger,
    ADescription + ' should retain its start offset.');
  AContext.AssertEquals(ASourceRange.StartPosition.Line,
    RequireJSONMember(lStartPosition, 'Line').AsInteger,
    ADescription + ' should retain its start line.');
  AContext.AssertEquals(ASourceRange.StartPosition.Column,
    RequireJSONMember(lStartPosition, 'Column').AsInteger,
    ADescription + ' should retain its start column.');
  AContext.AssertEquals(ASourceRange.EndPosition.Offset,
    RequireJSONMember(lEndPosition, 'Offset').AsInteger,
    ADescription + ' should retain its end offset.');
  AContext.AssertEquals(ASourceRange.EndPosition.Line,
    RequireJSONMember(lEndPosition, 'Line').AsInteger,
    ADescription + ' should retain its end line.');
  AContext.AssertEquals(ASourceRange.EndPosition.Column,
    RequireJSONMember(lEndPosition, 'Column').AsInteger,
    ADescription + ' should retain its end column.');
end;

procedure TestJSONEmitter(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lOtherCompiler: TNexusScriptCompiler;
  lEmitter: TNexusScriptJSONEmitter;
  lData: TJSONData;
  lRoot: TJSONObject;
  lCatalog: TJSONObject;
  lMetaData: TJSONObject;
  lReference: TJSONObject;
  lValues: TJSONArray;
  lNested: TJSONArray;
  lNamed: TJSONObject;
  lStructure: TJSONObject;
  lError: string;
  lCatalogDefinition: TNexusScriptCompiledDefinition;
  lChildDefinition: TNexusScriptCompiledDefinition;
  lInlineDefinition: TNexusScriptCompiledDefinition;
  lSource: string;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lOtherCompiler := TNexusScriptCompiler.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  lData := nil;
  try
    lSource := 'Thing Catalog { Name: DomainName; Count: 17; ' +
      'EmptyText: ""; EmptyArray: []; ' +
      'Escaped: "quote^" and newline^n"; Unicode: "caf'#233' lambda '#955'"; ' +
      'Label: @Name + "-resolved"; ' +
      'Values: [plain, Selected: named, Group: [inner, Deep: value], ' +
      'Node Row { Name: DomainRow; }]; Copy: @Values; ' +
      'GroupCopy: @Values.Group; SelectedCopy: @Values.Selected; ' +
      'Thing Child { Name: ChildDomain; } Thing Empty {} Alias: @Child; }';
    AContext.AssertTrue(lCompiler.CompileText('artifact.nxscript', lSource),
      'Generic artifact source should compile.');
    lCatalogDefinition := lCompiler.CompiledDocument.FindDefinition('Catalog');
    lChildDefinition := lCatalogDefinition.FindChild('Child');
    lInlineDefinition := lCatalogDefinition.FindProperty('Values').Value.
      Items[3].StructuralDefinition;
    lEmitter.AddDocument(lCompiler.CompiledDocument);

    AContext.AssertTrue(lOtherCompiler.CompileText('other.nxscript',
      'Other Additional { Value: included; }'),
      'A second artifact document should compile.');
    lEmitter.AddDocument(lOtherCompiler.CompiledDocument);

    lData := GetJSON(lEmitter.JSON);
    lRoot := RequireJSONObject(lData, 'Artifact root');
    AContext.AssertTrue(lRoot.Find('Additional') <> nil,
      'Multiple artifact documents should contribute root members.');
    lCatalog := RequireJSONObject(RequireJSONMember(lRoot, 'Catalog'),
      'Catalog');
    lMetaData := RequireJSONObject(RequireJSONMember(lCatalog, '_nx'),
      'Catalog metadata');
    AContext.AssertEquals('Thing', RequireJSONMember(lMetaData, 'Kind').AsString,
      'Definition metadata should retain kind.');
    AContext.AssertEquals('Catalog',
      RequireJSONMember(lMetaData, 'Name').AsString,
      'Definition metadata should retain identity.');
    AContext.AssertTrue(not RequireJSONMember(lMetaData,
      'IsReference').AsBoolean,
      'Direct definitions should identify themselves as non-references.');
    AssertDefinitionSourceRangeJSON(AContext, lMetaData,
      lCatalogDefinition.SourceRange, 'Direct definition');
    AContext.AssertEquals('artifact.nxscript',
      lCatalogDefinition.SourceRange.SourceName,
      'CompileText should preserve its caller-supplied source identity.');
    AContext.AssertEquals(Length(lSource),
      lCatalogDefinition.SourceRange.EndPosition.Offset,
      'A definition source range should end after its closing brace.');
    AContext.AssertEquals('DomainName',
      RequireJSONMember(lCatalog, 'Name').AsString,
      'A domain Name property must remain distinct from metadata.');
    AContext.AssertTrue(RequireJSONMember(lCatalog, 'Count').JSONType = jtString,
      'Scalar-looking source text should remain a JSON string.');
    AContext.AssertEquals('', RequireJSONMember(lCatalog, 'EmptyText').AsString,
      'Empty text should remain an empty JSON string.');
    AContext.AssertEquals(0, RequireJSONArray(
      RequireJSONMember(lCatalog, 'EmptyArray'), 'EmptyArray').Count,
      'Empty arrays should remain empty JSON arrays.');
    AContext.AssertEquals('quote" and newline' + #10,
      RequireJSONMember(lCatalog, 'Escaped').AsString,
      'JSON escaping should preserve completed text exactly.');
    AContext.AssertEquals('caf'#233' lambda '#955,
      RequireJSONMember(lCatalog, 'Unicode').AsString,
      'Unicode text should survive JSON serialization and parsing.');
    AContext.AssertEquals('DomainName-resolved',
      RequireJSONMember(lCatalog, 'Label').AsString,
      'Text composition should emit completed text.');

    lValues := RequireJSONArray(RequireJSONMember(lCatalog, 'Values'),
      'Values');
    AContext.AssertEquals(4, lValues.Count,
      'Array order and entry count should be preserved.');
    AContext.AssertEquals('plain', lValues.Items[0].AsString,
      'Unnamed scalar entries should remain scalar strings.');
    lNamed := RequireJSONObject(lValues.Items[1], 'Named scalar entry');
    lMetaData := RequireJSONObject(RequireJSONMember(lNamed, '_nx'),
      'Named scalar metadata');
    AContext.AssertEquals('Selected', RequireJSONMember(lMetaData,
      'Name').AsString,
      'Named scalar entries should expose their name through _nx.');
    AContext.AssertTrue(lMetaData.Find('SourceRange') = nil,
      'Named scalar metadata should not claim a definition source range.');
    AContext.AssertEquals('named',
      RequireJSONMember(lNamed, 'Value').AsString,
      'Named scalar entries should retain their value.');
    lNamed := RequireJSONObject(lValues.Items[2], 'Named array entry');
    lMetaData := RequireJSONObject(RequireJSONMember(lNamed, '_nx'),
      'Named array metadata');
    AContext.AssertEquals('Group', RequireJSONMember(lMetaData,
      'Name').AsString,
      'Named nested arrays should expose their name through _nx.');
    AContext.AssertTrue(lMetaData.Find('SourceRange') = nil,
      'Named array metadata should not claim a definition source range.');
    lNested := RequireJSONArray(RequireJSONMember(lNamed, 'Value'),
      'Named nested array value');
    AContext.AssertEquals('inner', lNested.Items[0].AsString,
      'Nested arrays should retain order and scalar values.');
    lStructure := RequireJSONObject(lValues.Items[3],
      'Structural array entry');
    lMetaData := RequireJSONObject(RequireJSONMember(lStructure, '_nx'),
      'Structural entry metadata');
    AContext.AssertEquals('Row', RequireJSONMember(lMetaData,
      'Name').AsString,
      'Structural array entries should use definition metadata.');
    AssertDefinitionSourceRangeJSON(AContext, lMetaData,
      lInlineDefinition.SourceRange, 'Inline definition');
    AContext.AssertEquals('DomainRow',
      RequireJSONMember(lStructure, 'Name').AsString,
      'Structural domain members should be emitted directly.');
    AContext.AssertEquals(4, RequireJSONArray(
      RequireJSONMember(lCatalog, 'Copy'), 'Array reference').Count,
      'Whole-array references should emit their completed array.');
    AContext.AssertEquals(2, RequireJSONArray(
      RequireJSONMember(lCatalog, 'GroupCopy'),
      'Named nested-array reference').Count,
      'References to named nested arrays should emit completed arrays.');
    AContext.AssertEquals('named',
      RequireJSONMember(lCatalog, 'SelectedCopy').AsString,
      'References to named scalar entries should emit completed text.');
    lMetaData := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lCatalog, 'Alias'), 'Alias'),
      '_nx'), 'Alias metadata');
    AContext.AssertEquals('Alias', RequireJSONMember(lMetaData,
      'Name').AsString,
      'Structural references should use the receiving property name.');
    AContext.AssertTrue(RequireJSONMember(lMetaData,
      'IsReference').AsBoolean,
      'Structural references should identify themselves explicitly.');
    lReference := RequireJSONObject(RequireJSONMember(lMetaData,
      'Reference'), 'Alias reference metadata');
    AContext.AssertEquals('Thing', RequireJSONMember(lReference,
      'Kind').AsString,
      'Reference metadata should retain the resolved target kind.');
    AContext.AssertEquals('Child', RequireJSONMember(lReference,
      'Name').AsString,
      'Reference metadata should retain the resolved target identity.');
    AssertDefinitionSourceRangeJSON(AContext, lMetaData,
      lChildDefinition.SourceRange, 'Structural reference projection');
    AContext.AssertTrue(lCatalog.Find('Child') <> nil,
      'Direct child definitions should become named object members.');
    lMetaData := RequireJSONObject(RequireJSONMember(RequireJSONObject(
      RequireJSONMember(lCatalog, 'Child'), 'Child'), '_nx'),
      'Child metadata');
    AssertDefinitionSourceRangeJSON(AContext, lMetaData,
      lChildDefinition.SourceRange, 'Nested definition');
    AContext.AssertEquals(1, RequireJSONObject(
      RequireJSONMember(lCatalog, 'Empty'), 'Empty definition').Count,
      'An empty definition should contain only its _nx metadata.');

    AContext.AssertTrue(lOtherCompiler.CompileText('duplicate.nxscript',
      'Thing Catalog {}'), 'Duplicate-root source should compile alone.');
    lError := '';
    try
      lEmitter.AddDocument(lOtherCompiler.CompiledDocument);
    except
      on E: ENexusScriptJSON do
        lError := E.Message;
    end;
    AContext.AssertTrue(Pos('duplicate artifact root', LowerCase(lError)) > 0,
      'Duplicate root names across documents should fail explicitly.');

    AContext.AssertTrue(lOtherCompiler.CompileText('reserved.nxscript',
      'Thing Reserved { _nx: collision; }'),
      'Reserved-member source should compile generically.');
    lError := '';
    try
      lEmitter.AddDocument(lOtherCompiler.CompiledDocument);
    except
      on E: ENexusScriptJSON do
        lError := E.Message;
    end;
    AContext.AssertTrue(Pos('reserved member _nx', LowerCase(lError)) > 0,
      'A domain _nx member should fail instead of colliding silently.');

    AContext.AssertTrue(lOtherCompiler.CompileText('reserved-child.nxscript',
      'Thing ReservedChild { Thing _nx {} }'),
      'Reserved-child source should compile generically.');
    lError := '';
    try
      lEmitter.AddDocument(lOtherCompiler.CompiledDocument);
    except
      on E: ENexusScriptJSON do
        lError := E.Message;
    end;
    AContext.AssertTrue(Pos('reserved member _nx', LowerCase(lError)) > 0,
      'A child named _nx should fail instead of colliding silently.');
  finally
    lData.Free;
    lEmitter.Free;
    lOtherCompiler.Free;
    lCompiler.Free;
  end;
end;

procedure TestDefinitionSourceRangeJSON(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lEmitter: TNexusScriptJSONEmitter;
  lData: TJSONData;
  lEntry: TNexusScriptCompiledDefinition;
  lImported: TNexusScriptCompiledDefinition;
  lDerived: TNexusScriptCompiledDefinition;
  lModuleChild: TNexusScriptCompiledDefinition;
  lEntryJSON: TJSONObject;
  lDerivedJSON: TJSONObject;
  lModuleChildJSON: TJSONObject;
  lMetaData: TJSONObject;
  lEntryFileName: string;
  lModuleFileName: string;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  lData := nil;
  try
    lEntryFileName := ExpandFileName(DiscoveryFixturePath(
      'module\nonrecursive\entry.module.nxscript'));
    lModuleFileName := ExpandFileName(DiscoveryFixturePath(
      'module\nonrecursive\sibling.module.nxscript'));
    AContext.AssertTrue(lSession.CompileFile(lEntryFileName),
      'File-backed source-range fixture should compile: ' +
      lSession.LastError);
    lEntry := lSession.EntryCompiler.CompiledDocument.FindDefinition('Entry');
    lImported := lSession.EntryCompiler.CompiledDocument.
      FindDefinition('Shared');
    lDerived := lEntry.FindChild('Derived');
    lModuleChild := lDerived.FindChild('ModuleChild');
    AContext.AssertTrue(SameFileName(lImported.SourceRange.SourceName,
      lModuleFileName),
      'A discovered module root should retain its expanded source filename.');
    AContext.AssertTrue(SameFileName(lEntry.SourceRange.SourceName,
      lEntryFileName),
      'The receiving root should retain the entry document filename.');
    AContext.AssertTrue(SameFileName(lDerived.SourceRange.SourceName,
      lEntryFileName),
      'A composed receiver should retain its own declaration filename.');
    AContext.AssertTrue(SameFileName(lModuleChild.SourceRange.SourceName,
      lModuleFileName),
      'A composed child should retain its contributor document filename.');

    lEmitter.AddDocument(lSession.EntryCompiler.CompiledDocument);
    lData := GetJSON(lEmitter.JSON);
    lEntryJSON := RequireJSONObject(RequireJSONMember(RequireJSONObject(lData,
      'Artifact root'), 'Entry'), 'Entry');
    lMetaData := RequireJSONObject(RequireJSONMember(lEntryJSON, '_nx'),
      'Entry metadata');
    AssertDefinitionSourceRangeJSON(AContext, lMetaData, lEntry.SourceRange,
      'File-backed receiving root');
    lDerivedJSON := RequireJSONObject(RequireJSONMember(lEntryJSON, 'Derived'),
      'Derived');
    lMetaData := RequireJSONObject(RequireJSONMember(lDerivedJSON, '_nx'),
      'Derived metadata');
    AssertDefinitionSourceRangeJSON(AContext, lMetaData, lDerived.SourceRange,
      'Composed receiver');
    lModuleChildJSON := RequireJSONObject(RequireJSONMember(lDerivedJSON,
      'ModuleChild'), 'ModuleChild');
    lMetaData := RequireJSONObject(RequireJSONMember(lModuleChildJSON, '_nx'),
      'ModuleChild metadata');
    AssertDefinitionSourceRangeJSON(AContext, lMetaData,
      lModuleChild.SourceRange, 'Composed child');
  finally
    lData.Free;
    lEmitter.Free;
    lSession.Free;
  end;
end;

procedure TestDefinitionTargetJSON(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lEmitter: TNexusScriptJSONEmitter;
  lData: TJSONData;
  lCatalog: TJSONObject;
  lMetaData: TJSONObject;
  lTargets: TJSONArray;
  lTarget: TJSONObject;
  lValues: TJSONArray;
  lInline: TJSONObject;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  lData := nil;
  try
    AContext.AssertTrue(lCompiler.CompileText('target-json.nxscript',
      'Thing Catalog Target[Production, "Cross Reference"] ' +
      'Platform[Windows] { Targets: domain; ' +
      'Thing Nested Target[NestedTarget] {} Thing Empty {} ' +
      'Items: [Node Inline Target[InlineTarget] {}]; Alias: @Nested; }'),
      'Targeted JSON source should compile.');
    lEmitter.AddDocument(lCompiler.CompiledDocument);
    lData := GetJSON(lEmitter.JSON);
    lCatalog := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(lData, 'Artifact root'), 'Catalog'), 'Catalog');
    lMetaData := RequireJSONObject(RequireJSONMember(lCatalog, '_nx'),
      'Catalog metadata');
    lTargets := RequireJSONArray(RequireJSONMember(lMetaData, 'Targets'),
      'Catalog Targets');
    AContext.AssertEquals(2, lTargets.Count,
      'Target metadata should emit every named Target kind.');
    lTarget := RequireJSONObject(lTargets.Items[0], 'Target metadata entry');
    AContext.AssertEquals('Target', RequireJSONMember(lTarget,
      'Name').AsString, 'JSON Target kinds should retain declaration order.');
    lValues := RequireJSONArray(RequireJSONMember(lTarget, 'Values'),
      'Target values');
    AContext.AssertEquals(2, lValues.Count,
      'JSON Target entries should emit every value.');
    AContext.AssertEquals('Production', lValues.Items[0].AsString,
      'JSON Target values should retain declaration order.');
    AContext.AssertEquals('Cross Reference', lValues.Items[1].AsString,
      'JSON Target values should retain decoded text.');
    lTarget := RequireJSONObject(lTargets.Items[1], 'Platform metadata entry');
    AContext.AssertEquals('Platform', RequireJSONMember(lTarget,
      'Name').AsString, 'JSON should emit each named Target kind.');
    AContext.AssertEquals('Windows', RequireJSONArray(RequireJSONMember(
      lTarget, 'Values'), 'Platform values').Items[0].AsString,
      'JSON should emit values under their named Target kind.');
    AContext.AssertEquals('domain', RequireJSONMember(lCatalog,
      'Targets').AsString,
      'A domain Targets property should coexist with _nx.Targets.');
    lMetaData := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lCatalog, 'Nested'), 'Nested'),
      '_nx'), 'Nested metadata');
    lTarget := RequireJSONObject(RequireJSONArray(RequireJSONMember(lMetaData,
      'Targets'), 'Nested Targets').Items[0], 'Nested Target');
    AContext.AssertEquals('NestedTarget', RequireJSONArray(RequireJSONMember(
      lTarget, 'Values'), 'Nested Target values').Items[0].AsString,
      'Nested definitions should emit Targets.');
    lInline := RequireJSONObject(RequireJSONArray(RequireJSONMember(lCatalog,
      'Items'), 'Items').Items[0], 'Inline definition');
    lTarget := RequireJSONObject(RequireJSONArray(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lInline, '_nx'), 'Inline metadata'),
      'Targets'), 'Inline Targets').Items[0], 'Inline Target');
    AContext.AssertEquals('InlineTarget', RequireJSONArray(RequireJSONMember(
      lTarget, 'Values'), 'Inline Target values').Items[0].AsString,
      'Inline definitions should emit Targets.');
    lMetaData := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lCatalog, 'Alias'), 'Alias'),
      '_nx'), 'Alias metadata');
    lTarget := RequireJSONObject(RequireJSONArray(RequireJSONMember(lMetaData,
      'Targets'), 'Alias Targets').Items[0], 'Alias Target');
    AContext.AssertEquals('NestedTarget', RequireJSONArray(RequireJSONMember(
      lTarget, 'Values'), 'Alias Target values').Items[0].AsString,
      'Structural reference projections should emit definition Targets.');
    lMetaData := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lCatalog, 'Empty'), 'Empty'),
      '_nx'), 'Empty metadata');
    AContext.AssertTrue(lMetaData.Find('Targets') = nil,
      'Untargeted definitions should omit _nx.Targets.');
  finally
    lData.Free;
    lEmitter.Free;
    lCompiler.Free;
  end;
end;

procedure TestTargetFilteredJSON(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lEmitter: TNexusScriptJSONEmitter;
  lData: TJSONData;
  lRoot: TJSONObject;
  lDefinition: TJSONObject;
  lMetaData: TJSONObject;
  lTarget: TJSONObject;
  lSelection: TNexusScriptTargetSelection;
begin
  lSelection := TNexusScriptTargetSelection.Create;
  try
    lSelection.Add('Target', 'Dev');
    lCompiler := TNexusScriptCompiler.Create(lSelection);
    lEmitter := TNexusScriptJSONEmitter.Create;
    lData := nil;
    try
      AContext.AssertTrue(lCompiler.CompileText('filtered-json.nxscript',
        'Thing Universal {} Thing Dev Target[Dev] { Targets: domain; } ' +
        'Thing QA Target[QA] {}'), 'Targeted JSON source should compile.');
      lEmitter.AddDocument(lCompiler.CompiledDocument);
      lData := GetJSON(lEmitter.JSON);
      lRoot := RequireJSONObject(lData, 'Artifact root');
      AContext.AssertTrue(lRoot.Find('Universal') <> nil,
        'Targeted JSON should emit universal definitions.');
      AContext.AssertTrue(lRoot.Find('QA') = nil,
        'Targeted JSON should omit excluded definitions.');
      lDefinition := RequireJSONObject(RequireJSONMember(lRoot, 'Dev'), 'Dev');
      lMetaData := RequireJSONObject(RequireJSONMember(lDefinition, '_nx'),
        'Dev metadata');
      lTarget := RequireJSONObject(RequireJSONArray(RequireJSONMember(
        lMetaData, 'Targets'), 'Dev Targets').Items[0], 'Dev Target');
      AContext.AssertEquals('Target', RequireJSONMember(lTarget,
        'Name').AsString, 'Targeted JSON should retain the Target kind.');
      AContext.AssertEquals('Dev', RequireJSONArray(RequireJSONMember(
        lTarget, 'Values'), 'Dev Target values').Items[0].AsString,
        'Targeted JSON should retain declaration metadata.');
      AContext.AssertTrue(lMetaData.Find('Tags') = nil,
        'The incorrect _nx.Tags contract should not be emitted.');
      AContext.AssertEquals('domain', RequireJSONMember(lDefinition,
        'Targets').AsString,
        'A domain Targets property should remain separate from metadata.');
    finally
      lData.Free;
      lEmitter.Free;
      lCompiler.Free;
    end;
  finally
    lSelection.Free;
  end;
end;

procedure TestExternalDataDeclarations(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lSession: TNexusScriptCompilationSession;
  lArtifactContext: TNexusScriptArtifactContext;
  lEmitter: TNexusScriptJSONEmitter;
  lJSON: string;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('data.nxscript',
      'data STATE "data/state.csv"; Thing Root {}'),
      'A header-level data declaration should compile.');
    AContext.AssertEquals(1, lCompiler.SourceDocument.DataSources.Count,
      'The declaration should remain separate from definitions.');
    AContext.AssertEquals('STATE',
      lCompiler.SourceDocument.DataSources[0].Name,
      'The declaration should retain its logical identity.');
    AContext.AssertEquals('data/state.csv',
      lCompiler.SourceDocument.DataSources[0].Path,
      'The declaration should retain its declared path.');

    AContext.AssertTrue(not lCompiler.CompileText('duplicate-data.nxscript',
      'data STATE "one.csv"; data state "two.csv"; Thing Root {}'),
      'Data source identities should be case-insensitively unique.');
    AContext.AssertEquals('NXS2018', lCompiler.Diagnostics[0].Code,
      'Duplicate data source diagnostics should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('misplaced-data.nxscript',
      'Thing Root {} data STATE "state.csv";'),
      'Data declarations after definitions should fail.');
    AContext.AssertEquals('NXS2017', lCompiler.Diagnostics[0].Code,
      'Misplaced data source diagnostics should be deterministic.');
  finally
    lCompiler.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  lArtifactContext := TNexusScriptArtifactContext.Create(lSession);
  try
    AContext.AssertTrue(lSession.CompileFile(
      ExternalDataFixturePath('dependency-entry.nxscript')),
      'External dependency fixture should compile: ' + lSession.LastError);
    lArtifactContext.Build;
    AContext.AssertEquals(3, lArtifactContext.ExternalSources.Count,
      'Entry, include, and module declarations should all participate.');
    AContext.AssertEquals('ENTRY_DATA', lArtifactContext.ExternalSources[0].Name,
      'Entry declarations should retain deterministic first position.');
    AContext.AssertEquals('INCLUDE_DATA', lArtifactContext.ExternalSources[1].Name,
      'Include declarations should follow entry declarations.');
    AContext.AssertEquals('MODULE_DATA', lArtifactContext.ExternalSources[2].Name,
      'Module declarations should follow include declarations.');
    AContext.AssertEquals('csv', lArtifactContext.ExternalSources[0].SourceType,
      'The normalized extension should define the initial source type.');

    lEmitter := TNexusScriptJSONEmitter.Create;
    try
      lEmitter.AddDocument(lSession.EntryCompiler.CompiledDocument);
      lJSON := lEmitter.JSON;
    AContext.AssertTrue(Pos('ENTRY_DATA', lJSON) = 0,
        'External dependencies must not enter generic model JSON.');
    finally
      lEmitter.Free;
    end;

    AContext.AssertTrue(lSession.CompileFile(
      ExternalDataFixturePath('dialect-entry.nxscript')),
      'A dialect dependency fixture should compile: ' + lSession.LastError);
    lArtifactContext.Build;
    AContext.AssertEquals(0, lArtifactContext.ExternalSources.Count,
      'Dialect documents must not contribute model-owned data sources.');
  finally
    lArtifactContext.Free;
    lSession.Free;
  end;
end;

procedure TestExternalDataCompilation(AContext: TNXTestContext);
var
  lSource: TNexusScriptExternalSource;
  lRange: TNexusScriptRange;
  lJSON: string;
  lData: TJSONData;
  lRoot: TJSONObject;
  lDataSource: TJSONObject;
  lMetaData: TJSONObject;
  lFields: TJSONArray;
  lRecords: TJSONArray;
  lRecord: TJSONArray;
  lError: string;

  function CompileFixture(const AName, AFileName, ASourceType,
    ACompilerName: string): string;
  begin
    lSource := TNexusScriptExternalSource.Create(AName, AFileName,
      ExternalDataFixturePath(AFileName), ASourceType, 'test.nxscript',
      lRange);
    try
      Result := TNexusScriptExternalSourceCompilerRegistry.Compile(
        ACompilerName, lSource);
    finally
      lSource.Free;
    end;
  end;
begin
  FillChar(lRange, SizeOf(lRange), 0);
  lData := nil;
  lJSON := CompileFixture('STATE', 'state.csv', 'csv', 'CommaDelimited');
  try
    lData := GetJSON(lJSON);
    lRoot := RequireJSONObject(lData, 'External source root');
    lDataSource := RequireJSONObject(RequireJSONMember(lRoot, 'DataSource'),
      'DataSource');
    lMetaData := RequireJSONObject(RequireJSONMember(lDataSource, '_nx'),
      'DataSource metadata');
    AContext.AssertEquals('STATE',
      RequireJSONMember(lMetaData, 'Name').AsString,
      'External source identity should be available through _nx.');
    lFields := RequireJSONArray(RequireJSONMember(lDataSource, 'Fields'),
      'Fields');
    AContext.AssertEquals(2, lFields.Count,
      'The header should compile into an ordered field array.');
    AContext.AssertEquals('STATE_ID', lFields.Items[0].AsString,
      'Field order should be preserved.');
    lRecords := RequireJSONArray(RequireJSONMember(lDataSource, 'Records'),
      'Records');
    AContext.AssertEquals(2, lRecords.Count,
      'Every nonblank data row should become one record.');
    lRecord := RequireJSONArray(lRecords.Items[0], 'First record');
    AContext.AssertEquals('CA', lRecord.Items[0].AsString,
      'Record values should preserve field position.');
    AContext.AssertEquals('California', lRecord.Items[1].AsString,
      'Record values should remain parsed strings.');
  finally
    lData.Free;
  end;

  AContext.AssertTrue(Pos('Washington', CompileFixture('STATE', 'state.jcsv',
    'jcsv', 'CommaDelimited')) > 0,
    'JCSV should use the comma-delimited compiler.');
  lJSON := CompileFixture('QUOTED', 'quoted.csv', 'csv', 'CommaDelimited');
  AContext.AssertTrue((Pos('A, value', lJSON) > 0) and
    (Pos('He said \"Hello\"', lJSON) > 0),
    'Quoted delimiters and doubled quotes should preserve field values.');
  AContext.AssertTrue(Pos('North', CompileFixture('COUNTY', 'county.tsv',
    'tsv', 'TabDelimited')) > 0,
    'TSV should use the tab-delimited compiler.');
  AContext.AssertTrue(Pos('East', CompileFixture('COUNTY', 'county.tab',
    'tab', 'TabDelimited')) > 0,
    'TAB should use the tab-delimited compiler.');

  lError := '';
  try
    CompileFixture('BAD', 'duplicate-header.csv', 'csv', 'CommaDelimited');
  except
    on E: Exception do lError := E.Message;
  end;
  AContext.AssertTrue(Pos('duplicate field name', LowerCase(lError)) > 0,
    'Duplicate headers should fail clearly.');

  lError := '';
  try
    CompileFixture('BAD', 'short-row.csv', 'csv', 'CommaDelimited');
  except
    on E: Exception do lError := E.Message;
  end;
  AContext.AssertTrue(Pos('field count mismatch', LowerCase(lError)) > 0,
    'Row-width mismatches should fail clearly.');

  lError := '';
  try
    CompileFixture('BAD', 'malformed.csv', 'csv', 'CommaDelimited');
  except
    on E: Exception do lError := E.Message;
  end;
  AContext.AssertTrue(Pos('malformed quoted field', LowerCase(lError)) > 0,
    'Unclosed quoted fields should fail with a focused diagnostic.');
end;

procedure TestCommandExternalDataManifest(AContext: TNXTestContext);
var
  lOutputDirectory: string;
  lPreloadDirectory: string;
  lStateFile: string;
  lCountyFile: string;
  lStateSQL: string;
  lCountySQL: string;
  lError: string;
begin
  lOutputDirectory := NewOutputDirectory('nxd');
  lPreloadDirectory := lOutputDirectory + '\preload';
  lStateFile := lPreloadDirectory + '\state.sql';
  lCountyFile := lPreloadDirectory + '\county.sql';
  try
    ExecuteCLI(['/manifest=' +
      ManifestFixturePath('ExternalData.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue(FileExists(lStateFile),
      'A CSV dependency should produce a derived output.');
    AContext.AssertTrue(FileExists(lCountyFile),
      'A TSV dependency should produce a derived output.');
    lStateSQL := FileText(lStateFile);
    lCountySQL := FileText(lCountyFile);
    AContext.AssertTrue((Pos('source=STATE type=csv', lStateSQL) > 0) and
      (Pos('fields=STATE_ID,DESCRIPTION', lStateSQL) > 0) and
      (Pos('record=CA|California', lStateSQL) > 0),
      'The CSV template should receive only its completed source context.');
    AContext.AssertTrue((Pos('source=COUNTY type=tsv', lCountySQL) > 0) and
      (Pos('fields=COUNTY_ID,DESCRIPTION', lCountySQL) > 0) and
      (Pos('record=001|North', lCountySQL) > 0),
      'The TSV template should use the matching compiler and source context.');
  finally
    DeleteFile(lStateFile);
    DeleteFile(lCountyFile);
    RemoveDir(lPreloadDirectory);
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nxm');
  try
    lError := CLIError(['/manifest=' +
      ManifestFixturePath('MissingSourceRule.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue(Pos('no sourcetemplate matches',
      LowerCase(lError)) > 0,
      'A declared source without a matching rule should fail before output.');
    AContext.AssertTrue(not DirectoryExists(lOutputDirectory),
      'Missing source mappings should not create the output root.');
  finally
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nxs');
  lStateFile := lOutputDirectory + '\state.sql';
  lCountyFile := lOutputDirectory + '\county.sql';
  try
    ExecuteCLI(['/manifest=' +
      ManifestFixturePath('ExternalDataSQL.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    lStateSQL := FileText(lStateFile);
    AContext.AssertTrue((Pos('insert into STATE_TBL', lStateSQL) > 0) and
      (Pos('STATE_ID,', lStateSQL) > 0) and
      (Pos('''CA'',', lStateSQL) > 0),
      'The isolated parity SQL template should consume the new context.');
  finally
    DeleteFile(lStateFile);
    DeleteFile(lCountyFile);
    RemoveDir(lOutputDirectory);
  end;

  lOutputDirectory := NewOutputDirectory('nxc');
  try
    lError := CLIError(['/manifest=' +
      ManifestFixturePath('SourceCollision.NexusManifest.nxscript'),
      '/output=' + lOutputDirectory]);
    AContext.AssertTrue(Pos('output collision', LowerCase(lError)) > 0,
      'Derived outputs with the same basename should fail preflight.');
    AContext.AssertTrue(not DirectoryExists(lOutputDirectory),
      'Collision preflight should not create the output root.');
  finally
    RemoveDir(lOutputDirectory);
  end;
end;

procedure TestSchemaGenerationMockData(AContext: TNXTestContext);
const
  cPreloadFiles: array[0..8] of string = (
    'address_type.sql',
    'license_type.sql',
    'phone_type.sql',
    'service_billing_type.sql',
    'state.sql',
    'zipcode.sql',
    'person_type.sql',
    '1_person.sql',
    '2_login.sql'
  );
var
  lInForceOutput: string;
  lStormOutput: string;
  lFileName: string;
  lInForceFile: string;
  lStormFile: string;

  procedure RemoveGeneratedOutput(const ADirectory: string);
  var
    lGeneratedFile: string;
  begin
    for lGeneratedFile in cPreloadFiles do
      DeleteFile(ADirectory + '\preload\' + lGeneratedFile);
    DeleteFile(ADirectory + '\DatabaseSchema.sql');
    DeleteFile(ADirectory + '\AutoProviderList.prv');
    RemoveDir(ADirectory + '\preload');
    RemoveDir(ADirectory);
  end;
begin
  lInForceOutput := NewOutputDirectory('nxi');
  lStormOutput := NewOutputDirectory('nxt');
  try
    ExecuteCLI(['/manifest=' + SchemaGenerationPath(
      'manifests\inForce.Firebird.NexusManifest.nxscript'),
      '/output=' + lInForceOutput]);
    ExecuteCLI(['/manifest=' + SchemaGenerationPath(
      'manifests\Storm.Firebird.NexusManifest.nxscript'),
      '/output=' + lStormOutput]);

    for lFileName in cPreloadFiles do
    begin
      lInForceFile := lInForceOutput + '\preload\' + lFileName;
      lStormFile := lStormOutput + '\preload\' + lFileName;
      AContext.AssertTrue(FileExists(lInForceFile),
        'inForce should generate mock preload output ' + lFileName + '.');
      AContext.AssertTrue(FileExists(lStormFile),
        'Storm should inherit mock preload output ' + lFileName + '.');
      AContext.AssertEquals(FileText(lInForceFile), FileText(lStormFile),
        'Imported mock preload output should be deterministic for ' +
        lFileName + '.');
    end;
    AContext.AssertTrue(Pos('insert into STATE_TBL', FileText(
      lInForceOutput + '\preload\state.sql')) > 0,
      'The mock state data should render through the copied SQL template.');
  finally
    RemoveGeneratedOutput(lStormOutput);
    RemoveGeneratedOutput(lInForceOutput);
  end;
end;

procedure TestModuleCompilation(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lRoot: TNexusScriptCompiledDefinition;
  lFixture: string;
  lEmitter: TNexusScriptJSONEmitter;
  lJSON: string;
begin
  lSession := TNexusScriptCompilationSession.Create;
  try
    lFixture := ExpandFileName('..\..\..\NexusTools\Script\tests\fixtures\modules\entry.nxscript');
    if not FileExists(lFixture) then
      lFixture := ExpandFileName('NexusTools\Script\tests\fixtures\modules\entry.nxscript');
    AContext.AssertTrue(lSession.CompileFile(lFixture),
      'Module script should compile: ' + lSession.LastError);
    if lSession.EntryCompiler = nil then
      Exit;
    lRoot := lSession.EntryCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals('hello world',
      lRoot.FindProperty('Greeting').Value.EffectiveText,
      'Module-qualified property should evaluate.');
    AContext.AssertEquals('other',
      lRoot.FindProperty('Other').Value.EffectiveText,
      'A module should expose every imported root by its declared name.');
    AContext.AssertEquals(2, lRoot.FindProperty('ModuleItems').Value.
      EffectiveValue.Items.Count,
      'Module-qualified array references should expose an owned result.');
    AContext.AssertEquals('First', lRoot.FindProperty('ModuleItems').Value.
      EffectiveValue.Items[0].EffectiveName,
      'Module-qualified array results should retain entry names and order.');
    AContext.AssertEquals('inherited',
      lRoot.FindChild('Derived').FindProperty('Shared').Value.EffectiveText,
      'Nested composition should resolve through an imported root.');
    lEmitter := TNexusScriptJSONEmitter.Create;
    try
      lEmitter.AddDocument(lSession.EntryCompiler.CompiledDocument);
      lJSON := lEmitter.JSON;
      AContext.AssertTrue(Pos('"Root"', lJSON) > 0,
        'The entry root should be emitted.');
      AContext.AssertTrue(Pos('"CommonRoot"', lJSON) = 0,
        'Module-only imported roots should not be emitted as artifacts.');
    finally
      lEmitter.Free;
    end;

    AContext.AssertTrue(lSession.CompileFile(
      ModuleFixturePath('selected.nxscript')),
      'Selected-root module script should compile: ' + lSession.LastError);
    AContext.AssertTrue(lSession.EntryCompiler.CompiledDocument.
      FindDefinition('CommonRoot') <> nil,
      'A selected root should retain its declared name.');
    AContext.AssertTrue(lSession.EntryCompiler.CompiledDocument.
      FindDefinition('OtherRoot') = nil,
      'A root selector should not import unselected roots.');
  finally
    lSession.Free;
  end;
end;

procedure TestModuleFailures(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lCompiler: TNexusScriptCompiler;
  lFixture: string;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(not lCompiler.CompileText('alias.nxscript',
      'module Alias Root "module.nxscript"; Thing Entry {}'),
      'Module aliases should not parse.');
    AContext.AssertEquals('NXS2002', lCompiler.Diagnostics[0].Code,
      'Removed alias syntax should use the module declaration diagnostic.');
  finally
    lCompiler.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    lFixture := ExpandFileName('..\..\..\NexusTools\Script\tests\fixtures\modules\cycle-a.nxscript');
    if not FileExists(lFixture) then
      lFixture := ExpandFileName('NexusTools\Script\tests\fixtures\modules\cycle-a.nxscript');
    AContext.AssertTrue(not lSession.CompileFile(lFixture),
      'Module dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Cycle failure should be deterministic.');

    AContext.AssertTrue(not lSession.CompileFile(
      ModuleFixturePath('duplicate-import.nxscript')),
      'Repeated imports with duplicate root names should fail.');
    AContext.AssertTrue(Pos('duplicate imported root',
      LowerCase(lSession.LastError)) > 0,
      'Duplicate imported roots should fail explicitly.');

    AContext.AssertTrue(not lSession.CompileFile(
      ModuleFixturePath('collision.nxscript')),
      'Imported roots should not replace local roots.');
    AContext.AssertTrue(Pos('collides with local root',
      LowerCase(lSession.LastError)) > 0,
      'Imported/local root collisions should fail explicitly.');

    AContext.AssertTrue(not lSession.CompileFile(
      ModuleFixturePath('nested-selector.nxscript')),
      'A module selector should not flatten a nested definition into a root.');
    AContext.AssertTrue(Pos('root selector not found',
      LowerCase(lSession.LastError)) > 0,
      'Only declared document roots should be selectable.');
  finally
    lSession.Free;
  end;
end;

procedure TestComposition(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('composition.nxscript',
      'Thing Root { Thing A { Value: a; Name: @Value; } ' +
      'Thing B { Value: b; } Thing D (A, B) {} ' +
      'Thing L (A, B) { Value: c; } }'),
      'Composition script should compile.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals('b',
      lRoot.FindChild('D').FindProperty('Value').Value.EffectiveText,
      'Rightmost base should win.');
    AContext.AssertEquals('c',
      lRoot.FindChild('L').FindProperty('Name').Value.EffectiveText,
      'Inherited reference should bind against effective definition.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestCompiledTransferCloning(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lLibraryCompiler: TNexusScriptCompiler;
  lValidatorCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
  lResult: TNexusScriptCompiledDefinition;
  lChild: TNexusScriptCompiledDefinition;
  lItems: TNexusScriptCompiledValue;
  lReference: TNexusScriptCompiledValue;
  lValid: Boolean;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('composition-once.nxscript',
      'Thing Base { ' +
      'Thing Template { Items: [a]; } ' +
      'Thing Child (Template) { Items: [b]; } } ' +
      'Thing Result (Base) {}'),
      'An inherited composed child should compile.');
    lChild := lCompiler.CompiledDocument.FindDefinition('Result').
      FindChild('Child');
    lItems := lChild.FindProperty('Items').Value;
    AContext.AssertEquals(2, lItems.Items.Count,
      'An inherited child should apply its composition exactly once.');
    AContext.AssertEquals('a', lItems.Items[0].EffectiveText,
      'The inherited array contribution should occur once.');
    AContext.AssertEquals('b', lItems.Items[1].EffectiveText,
      'The child array contribution should occur once.');
  finally
    lCompiler.Free;
  end;

  lCompiler := TNexusScriptCompiler.Create;
  lLibraryCompiler := TNexusScriptCompiler.Create;
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lLibraryCompiler.CompileText('library.nxscript',
      'Thing Library { ' +
      'Template Template { Items: [a]; } ' +
      'Child Child (Template) { Items: [b]; ' +
      'Embedded: [Node Embedded {}]; ' +
      'Peer Peer { Value: library; } PeerReference: @Peer; } }'),
      'The independently owned library should compile.');
    lCompiler.AddImportedDocument(lLibraryCompiler.CompiledDocument);
    FreeAndNil(lLibraryCompiler);
    AContext.AssertTrue(lCompiler.CompileText('consumer.nxscript',
      'Result Local (Library) {}'),
      'A transferred library should outlive and rebind without its producer.');
    AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition(
      'Library').SourceDefinition = nil,
      'Imported definitions should not retain producer source objects.');
    AContext.AssertTrue(lCompiler.CompiledDocument.FindDefinition('Library').
      FindChild('Child').SourceDefinition = nil,
      'Imported child definitions should detach producer source objects.');
    lReference := lCompiler.CompiledDocument.FindDefinition('Library').
      FindChild('Child').FindProperty('PeerReference').Value;
    AContext.AssertTrue((lReference.ResolvedDefinition = nil) and
      (lReference.ResolvedProperty = nil) and
      (lReference.ResolvedValue = nil),
      'Imported values should not retain producer resolution objects.');
    lReference := lCompiler.CompiledDocument.FindDefinition('Library').
      FindChild('Child').FindProperty('Embedded').Value.Items[0];
    AContext.AssertTrue(lReference.InlineSourceDefinition = nil,
      'Imported values should not retain producer inline source objects.');
    AContext.AssertTrue(lReference.StructuralDefinition.SourceDefinition = nil,
      'Imported inline definitions should detach producer source objects.');
    lResult := lCompiler.CompiledDocument.FindDefinition('Local');
    lChild := lResult.FindChild('Child');
    lItems := lChild.FindProperty('Items').Value;
    AContext.AssertEquals(2, lItems.Items.Count,
      'Transferred child composition should remain applied exactly once.');
    AContext.AssertEquals('a', lItems.Items[0].EffectiveText,
      'Transferred composition should retain its inherited value once.');
    AContext.AssertEquals('b', lItems.Items[1].EffectiveText,
      'Transferred composition should retain its local value once.');
    lReference := lChild.FindProperty('PeerReference').Value;
    AContext.AssertTrue(lReference.ResolvedDefinition =
      lChild.FindChild('Peer'),
      'A transferred reference should resolve into the receiving graph.');
    AContext.AssertEquals('library', lReference.StructuralDefinition.
      FindProperty('Value').Value.EffectiveText,
      'A transferred reference projection should use the cloned member.');

    AContext.AssertTrue(lValidatorCompiler.CompileText(
      'transfer-language.nxscript',
      'Language Test { UnknownDefinitions: Allow; Definitions: [' +
      'Definition Result { Root: True; UnknownProperties: Allow; ' +
      'Children: [Child Members { Kinds: [Template, Child]; }]; }, ' +
      'Definition Child { UnknownProperties: Allow; ' +
      'Children: [Child Members { Kinds: [Peer]; }]; Properties: [' +
      'Property PeerReference { Value Value { SourceForms: [Reference]; ' +
      'EffectiveCategories: [Definition]; Reference Reference { ' +
      'Targets: [Definition]; DefinitionKinds: [Peer]; } } }]; }, ' +
      'Definition Template { UnknownProperties: Allow; }, ' +
      'Definition Peer { UnknownProperties: Allow; }]; }'),
      'The transfer validation language should compile.');
    lValid := lValidator.Validate(lCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument);
    AContext.AssertTrue(lValid,
      'Validation should safely dereference the rebound local target: ' +
      ValidationFailure(lValidator));
  finally
    lValidator.Free;
    lValidatorCompiler.Free;
    lLibraryCompiler.Free;
    lCompiler.Free;
  end;
end;

procedure TestStructuralReferences(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lAlias: TNexusScriptCompiledValue;
  lDiagnostic: TNexusScriptDiagnostic;
  lHasStructuralCycle: Boolean;
  lHasUnresolvedReference: Boolean;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('structural.nxscript',
      'Thing Root { Thing Base { Text: original; Thing Inner { Value: nested; } } ' +
      'Thing Extra { Added: composed; } Thing Effective (Base, Extra) {} ' +
      'NestedValue: @Alias.Inner.Value; Alias: @Root.Base; ' +
      'Composed: @Root.Effective; }'),
      'Structural references should compile.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lAlias := lRoot.FindProperty('Alias').Value;
    AContext.AssertTrue(lAlias.ResolvedDefinition = lRoot.FindChild('Base'),
      'Structural value should retain target provenance.');
    AContext.AssertTrue(lAlias.StructuralDefinition <> nil,
      'Definition reference should materialize an owned structure.');
    AContext.AssertEquals('Alias', lAlias.StructuralDefinition.Name,
      'Materialized structure should use the receiving property name.');
    AContext.AssertEquals('Thing', lAlias.StructuralDefinition.Kind,
      'Materialized structure should preserve target kind.');
    AContext.AssertEquals('nested',
      lRoot.FindProperty('NestedValue').Value.EffectiveText,
      'Qualified lookup should traverse a materialized structure.');
    AContext.AssertEquals('composed',
      lRoot.FindProperty('Composed').Value.StructuralDefinition.
        FindProperty('Added').Value.EffectiveText,
      'Materialization should use the effective composed target.');
    AContext.AssertTrue(not lCompiler.CompileText('structural-cycle.nxscript',
      'Thing Root { Thing A { Other: @Root.B; } ' +
      'Thing B { Other: @Root.A; } Value: @Root.A; }'),
      'Recursive structural references should fail safely.');
    lHasStructuralCycle := False;
    lHasUnresolvedReference := False;
    for lDiagnostic in lCompiler.Diagnostics do
    begin
      lHasStructuralCycle := lHasStructuralCycle or
        SameText(lDiagnostic.Code, 'NXS5004');
      lHasUnresolvedReference := lHasUnresolvedReference or
        SameText(lDiagnostic.Code, 'NXS5001');
    end;
    AContext.AssertTrue(lHasStructuralCycle,
      'Recursive structural references should report NXS5004.');
    AContext.AssertTrue(not lHasUnresolvedReference,
      'Structural cycles should not be misreported as unresolved references.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestArrayEntries(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lItems: TNexusScriptCompiledValue;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('arrays.nxscript',
      'Thing Root { Thing Target { Value: target; } ' +
      'Items: [plain, Label: named, ' +
      'Node Inline { Value: inline; }, ' +
      'Local: Node Declared { Value: local; }, @Root.Target]; ' +
      'NamedValue: @Items.Label; NestedValue: @Items.Local.Value; ' +
      'ScalarTarget: @Items.Label; InlineTarget: @Items.Local; ' +
      'InlineTargetAgain: @Items.Local; }'),
      'Mixed array entries should compile.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lItems := lRoot.FindProperty('Items').Value;
    AContext.AssertTrue(lItems.StructuralDefinition = nil,
      'Array value must not expose a synthetic wrapper definition.');
    AContext.AssertEquals(5, lItems.Items.Count,
      'Array order and entry count should be retained.');
    AContext.AssertEquals('', lItems.Items[0].EffectiveName,
      'Unnamed scalar should remain unnamed.');
    AContext.AssertEquals('Label', lItems.Items[1].EffectiveName,
      'Explicit scalar name should be effective.');
    AContext.AssertEquals('Inline', lItems.Items[2].EffectiveName,
      'Inline definition should default to its declared name.');
    AContext.AssertTrue(lItems.Items[2].Kind = nsvDefinition,
      'Inline definition should use the definition value kind.');
    AContext.AssertEquals('Local', lItems.Items[3].EffectiveName,
      'Explicit inline name should override declared name.');
    AContext.AssertEquals('Declared',
      lItems.Items[3].OriginalDefinitionName,
      'Inline definition should retain declared identity provenance.');
    AContext.AssertEquals('Node',
      lItems.Items[3].StructuralDefinition.Kind,
      'Inline definition should retain its kind.');
    AContext.AssertEquals('Target', lItems.Items[4].EffectiveName,
      'Referenced definition should default to target declared name.');
    AContext.AssertTrue(lItems.Items[4].ResolvedDefinition =
      lRoot.FindChild('Target'),
      'Referenced entry should retain target provenance.');
    AContext.AssertEquals('named',
      lRoot.FindProperty('NamedValue').Value.EffectiveText,
      'Named scalar entry should be addressable.');
    AContext.AssertEquals('local',
      lRoot.FindProperty('NestedValue').Value.EffectiveText,
      'Named structural entry should support qualified traversal.');
    AContext.AssertTrue(lRoot.FindProperty('ScalarTarget').Value.ResolvedValue =
      lItems.Items[1],
      'Named scalar reference should retain exact array-item provenance.');
    AContext.AssertTrue(lRoot.FindProperty('InlineTarget').Value.ResolvedValue =
      lItems.Items[3],
      'Named inline reference should retain exact array-item provenance.');
    AContext.AssertTrue(
      lRoot.FindProperty('InlineTargetAgain').Value.ResolvedValue =
        lItems.Items[3],
      'Repeated inline reference should retain stable array-item identity.');
    AContext.AssertTrue(lItems.Items[3].EvaluationState = nsvesCompleted,
      'Named inline item should remain completed after repeated references.');
    AContext.AssertEquals('InlineTarget',
      lRoot.FindProperty('InlineTarget').Value.StructuralDefinition.Name,
      'Named inline reference should materialize under the receiving name.');
    AContext.AssertTrue(not lCompiler.CompileText('array-duplicate.nxscript',
      'Thing Root { Values: [Same: one, Same: two]; }'),
      'Duplicate effective array names should fail.');
    AContext.AssertTrue(not lCompiler.CompileText('array-reference-duplicate.nxscript',
      'Thing Root { Thing Target {} Values: [@Root.Target, @Root.Target]; }'),
      'Duplicate referenced-definition effective names should fail.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestQualifiedArrayEntryLookup(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lDemo: TNexusScriptCompiledDefinition;
  lTables: TNexusScriptCompiledValue;
  lAddress: TNexusScriptCompiledDefinition;
  lTarget: TNexusScriptCompiledValue;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('array-entry-earlier.nxscript',
      'Thing Demo { Tables: [' +
      'Table PERSON { Code: person; }, ' +
      'Table ADDRESS { Target: @Demo.Tables.PERSON; ' +
      'TargetCode: @Demo.Tables.PERSON.Code; }]; }'),
      'An entry should resolve an earlier entry through its explicit array path.');
    lDemo := lCompiler.CompiledDocument.FindDefinition('Demo');
    lTables := lDemo.FindProperty('Tables').Value;
    lAddress := lTables.Items[1].StructuralDefinition;
    lTarget := lAddress.FindProperty('Target').Value;
    AContext.AssertTrue(lTarget.ResolvedValue = lTables.Items[0],
      'Qualified lookup should retain the exact effective array entry.');
    AContext.AssertEquals('PERSON', lTarget.OriginalDefinitionName,
      'Qualified lookup should retain referenced entry identity.');
    AContext.AssertEquals('Target', lTarget.StructuralDefinition.Name,
      'Structural projection should retain the receiving property name.');
    AContext.AssertEquals('person',
      lAddress.FindProperty('TargetCode').Value.EffectiveText,
      'Qualified lookup should continue downward through the selected entry.');

    AContext.AssertTrue(lCompiler.CompileText(
      'array-entry-structural-self-reference.nxscript',
      'Thing Root { Items: [Node A { Link: @Items.A; }]; }'),
      'A structural array entry should support a recursive structural reference.');
    lDemo := lCompiler.CompiledDocument.FindDefinition('Root');
    lTables := lDemo.FindProperty('Items').Value;
    lTarget := lTables.Items[0].StructuralDefinition.FindProperty('Link').Value;
    AContext.AssertTrue(lTarget.ResolvedDefinition <> nil,
      'A recursive structural reference should retain target provenance.');
    AContext.AssertEquals('A', lTarget.OriginalDefinitionName,
      'A recursive structural reference should retain target identity.');

    AContext.AssertTrue(lCompiler.CompileText(
      'array-entry-structural-composition.nxscript',
      'Thing Root { Thing Base { Values: [Base: one]; } ' +
      'Items: [Node A (Base) { Values: [Local: two]; }]; }'),
      'A structural array entry should apply its composition selectors.');
    lDemo := lCompiler.CompiledDocument.FindDefinition('Root');
    lTables := lDemo.FindProperty('Items').Value;
    AContext.AssertEquals(2, lTables.Items[0].StructuralDefinition.
      FindProperty('Values').Value.Items.Count,
      'Inline structural composition should retain base and local array values.');

    AContext.AssertTrue(lCompiler.CompileText(
      'array-entry-target-owner.nxscript',
      'Thing Root { Thing Base { Code: composed; } Items: [' +
      'Node Consumer { Target: @Items.Target; }, ' +
      'Node Target (Base) {}]; }'),
      'A referenced structural entry should evaluate in its array owner scope.');
    lDemo := lCompiler.CompiledDocument.FindDefinition('Root');
    lTables := lDemo.FindProperty('Items').Value;
    lTarget := lTables.Items[0].StructuralDefinition.FindProperty('Target').Value;
    AContext.AssertEquals('composed', lTarget.StructuralDefinition.
      FindProperty('Code').Value.EffectiveText,
      'A later structural target should retain owner-scoped composition.');

    AContext.AssertTrue(lCompiler.CompileText('array-entry-later.nxscript',
      'Thing Demo { Tables: [' +
      'Table ADDRESS { Target: @Demo.Tables.PERSON; }, ' +
      'Table PERSON { Code: person; }]; }'),
      'Named array lookup should not depend on entry source order.');
    lDemo := lCompiler.CompiledDocument.FindDefinition('Demo');
    lTables := lDemo.FindProperty('Tables').Value;
    lAddress := lTables.Items[0].StructuralDefinition;
    AContext.AssertTrue(lAddress.FindProperty('Target').Value.ResolvedValue =
      lTables.Items[1],
      'Forward lookup should retain the exact effective array entry.');

    AContext.AssertTrue(not lCompiler.CompileText(
      'array-entry-implicit-sibling.nxscript',
      'Thing Demo { Tables: [' +
      'Table PERSON {}, Table ADDRESS { Target: @PERSON; }]; }'),
      'Named array entries must not acquire implicit sibling lookup.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestReferenceArrayProjection(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lTarget: TNexusScriptCompiledDefinition;
  lProjection: TNexusScriptCompiledDefinition;
  lScalars: TNexusScriptCompiledValue;
  lHasStructuralCycle: Boolean;
  lDiagnostic: TNexusScriptDiagnostic;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('projection.nxscript',
      'Thing Root { ' +
      'Thing Other { Value: other; } ' +
      'Thing Target { Value: target; ' +
      'Scalars: [first, Label: second, @Root.Other.Value]; ' +
      'NestedScalars: [[one, two], Named: [three]]; ' +
      'InlineItems: [Node Inline {}]; ' +
      'ReferenceItems: [@Root.Other]; ' +
      'MixedItems: [plain, Node Mixed {}]; ' +
      'NestedStructural: [[plain], [Node Nested {}]]; ' +
      'Thing Child { Keep: yes; Drop: [Node Omitted {}]; } } ' +
      'Thing Self { Value: self; Links: [@Root.Self]; } ' +
      'Thing Left { Links: [@Root.Right]; } ' +
      'Thing Right { Links: [@Root.Left]; } ' +
      'Thing StructuralBase { Items: [X: Node Old {}]; } ' +
      'Thing ScalarDerived (StructuralBase) { Items: [X: scalar]; } ' +
      'Thing ScalarBase { Items: [X: scalar]; } ' +
      'Thing StructuralDerived (ScalarBase) { Items: [X: Node New {}]; } ' +
      'Projected: @Root.Target; SelfProjected: @Root.Self; ' +
      'MutualProjected: @Root.Left; ' +
      'ScalarProjection: @Root.ScalarDerived; ' +
      'StructuralProjection: @Root.StructuralDerived; }'),
      'Reference projections should cut cycles through structural arrays.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lTarget := lRoot.FindChild('Target');
    lProjection := lRoot.FindProperty('Projected').Value.StructuralDefinition;
    AContext.AssertEquals('Projected', lProjection.Name,
      'Projection should retain the receiving member name.');
    AContext.AssertTrue(lProjection.Parent = lRoot,
      'Projection should be owned by its receiving scope.');
    AContext.AssertTrue(lRoot.FindProperty('Projected').Value.ResolvedDefinition =
      lTarget, 'Projection should retain complete target provenance.');
    lScalars := lProjection.FindProperty('Scalars').Value;
    AContext.AssertEquals(3, lScalars.Items.Count,
      'Scalar array order and count should be copied.');
    AContext.AssertEquals('Label', lScalars.Items[1].EffectiveName,
      'Named scalar array entries should retain effective names.');
    AContext.AssertEquals('other', lScalars.Items[2].EffectiveText,
      'Scalar property references should retain their effective value.');
    AContext.AssertTrue(lScalars.Items[2].ResolvedProperty <> nil,
      'Scalar property references should retain provenance.');
    AContext.AssertTrue(lProjection.FindProperty('NestedScalars') <> nil,
      'Recursively scalar nested arrays should be copied.');
    AContext.AssertTrue(lProjection.FindProperty('InlineItems') = nil,
      'Inline-definition arrays should be omitted entirely.');
    AContext.AssertTrue(lProjection.FindProperty('ReferenceItems') = nil,
      'Definition-reference arrays should be omitted entirely.');
    AContext.AssertTrue(lProjection.FindProperty('MixedItems') = nil,
      'Mixed arrays should be omitted entirely.');
    AContext.AssertTrue(lProjection.FindProperty('NestedStructural') = nil,
      'Nested arrays with a structural leaf should be omitted entirely.');
    AContext.AssertTrue(lProjection.FindChild('Child').FindProperty('Drop') = nil,
      'Array omission should recurse through projected child definitions.');
    AContext.AssertTrue(lProjection.FindChild('Child').FindProperty('Keep') <> nil,
      'Ordinary child structure should remain in the projection.');
    AContext.AssertTrue(lTarget.FindProperty('InlineItems') <> nil,
      'The complete target should retain arrays omitted from its projection.');
    AContext.AssertTrue(lRoot.FindChild('Self').FindProperty('Links') <> nil,
      'A complete self-referencing target should retain its structural array.');
    AContext.AssertTrue(lRoot.FindProperty('SelfProjected').Value.
      StructuralDefinition.FindProperty('Links') = nil,
      'A self-cycle through a structural array should be cut by projection.');
    AContext.AssertTrue(lRoot.FindProperty('MutualProjected').Value.
      StructuralDefinition.FindProperty('Links') = nil,
      'A mutual cycle through structural arrays should be cut by projection.');
    AContext.AssertTrue(lRoot.FindProperty('ScalarProjection').Value.
      StructuralDefinition.FindProperty('Items') <> nil,
      'A final scalar override should make the effective array projectable.');
    AContext.AssertEquals('scalar', lRoot.FindProperty('ScalarProjection').
      Value.StructuralDefinition.FindProperty('Items').Value.Items[0].
      EffectiveText,
      'Projection classification should use the winning scalar entry.');
    AContext.AssertTrue(lRoot.FindProperty('StructuralProjection').Value.
      StructuralDefinition.FindProperty('Items') = nil,
      'A final structural override should make the effective array omitted.');

    AContext.AssertTrue(not lCompiler.CompileText('direct-cycle.nxscript',
      'Thing Root { Thing Direct { Next: @Root.Direct; } ' +
      'Value: @Root.Direct; }'),
      'A direct structural reference cycle should remain invalid.');
    lHasStructuralCycle := False;
    for lDiagnostic in lCompiler.Diagnostics do
      lHasStructuralCycle := lHasStructuralCycle or
        SameText(lDiagnostic.Code, 'NXS5004');
    AContext.AssertTrue(lHasStructuralCycle,
      'A remaining direct structural cycle should report NXS5004.');
    AContext.AssertTrue(not lCompiler.CompileText('array-caller-cycle.nxscript',
      'Thing Root { Thing Direct { Next: @Root.Direct; } ' +
      'Items: [Node Item { Bad: @Root.Direct; }]; }'),
      'An array caller must not hide a direct target cycle.');
    lHasStructuralCycle := False;
    for lDiagnostic in lCompiler.Diagnostics do
      lHasStructuralCycle := lHasStructuralCycle or
        SameText(lDiagnostic.Code, 'NXS5004');
    AContext.AssertTrue(lHasStructuralCycle,
      'A direct target cycle reached from an array should report NXS5004.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestWholeArrayReferences(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lTarget: TNexusScriptCompiledValue;
  lResult: TNexusScriptCompiledValue;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('array-reference.nxscript',
      'Thing Root { Copy: @Values; CopyOfCopy: @Copy; ' +
      'Qualified: @Root.Values; ' +
      'Values: [first, Named: second, Node Inline { Value: inline; }, ' +
      '@Root.Target, [nested, Inner: value]]; ' +
      'Thing Target { Value: target; } }'),
      'Forward and qualified whole-array references should compile.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lTarget := lRoot.FindProperty('Values').Value;
    lResult := lRoot.FindProperty('Copy').Value.EffectiveValue;
    AContext.AssertTrue(lResult <> nil,
      'A whole-array reference should own an explicit effective value.');
    AContext.AssertTrue(lResult.Kind = nsvArray,
      'The effective value should retain array kind.');
    AContext.AssertTrue(lResult <> lTarget,
      'The effective array must not alias its target value.');
    AContext.AssertTrue(lResult.Items[0] <> lTarget.Items[0],
      'Effective array entries must be independently owned.');
    AContext.AssertEquals(5, lResult.Items.Count,
      'Complete array order and entry count should be retained.');
    AContext.AssertEquals('Named', lResult.Items[1].EffectiveName,
      'Explicit entry names should be retained.');
    AContext.AssertEquals('Inline', lResult.Items[2].EffectiveName,
      'Implicit inline-definition names should be retained.');
    AContext.AssertTrue(lResult.Items[2].StructuralDefinition <> nil,
      'Inline definitions should remain complete in array results.');
    AContext.AssertTrue(lResult.Items[3].ResolvedDefinition =
      lRoot.FindChild('Target'),
      'Definition-reference entries should retain target provenance.');
    AContext.AssertTrue(lResult.Items[3].StructuralDefinition <> nil,
      'Definition-reference entries should retain projected structures.');
    AContext.AssertTrue(lResult.Items[4].Kind = nsvArray,
      'Nested arrays should be cloned completely.');
    AContext.AssertTrue(lRoot.FindProperty('Copy').Value.ResolvedProperty =
      lRoot.FindProperty('Values'),
      'The reference should retain resolved-property provenance.');
    AContext.AssertEquals(5, lRoot.FindProperty('Qualified').Value.
      EffectiveValue.Items.Count,
      'Qualified whole-array references should expose complete results.');
    AContext.AssertEquals(5, lRoot.FindProperty('CopyOfCopy').Value.
      EffectiveValue.Items.Count,
      'References to array-valued references should retain the array result.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestArrayComposition(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lDerived: TNexusScriptCompiledDefinition;
  lItems: TNexusScriptCompiledValue;
  lCopy: TNexusScriptCompiledValue;
  lHasDuplicate: Boolean;
  lDiagnostic: TNexusScriptDiagnostic;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('array-composition.nxscript',
      'Thing Root { Thing RefTarget { Value: ref; } ' +
      'Thing BaseOne { Items: [A: one, base, Node Implicit {}]; ' +
      'Copy: @Items; Scalar: base; Switch: [base]; SwitchBack: base; } ' +
      'Thing BaseTwo { Items: [A: two, B: inherited, @Root.RefTarget]; } ' +
      'Thing EffectiveBase { EffectiveItems: @Root.RootValues; } ' +
      'Thing EffectiveDerived (EffectiveBase) { EffectiveItems: [B: two]; } ' +
      'Thing EffectiveScalar (EffectiveBase) { EffectiveItems: scalar; } ' +
      'Thing Derived (BaseOne, BaseTwo) { ' +
      'Items: [B: local, C: added, local, Implicit: Node Replacement {}]; ' +
      'Scalar: local; Switch: local; SwitchBack: [local]; } ' +
      'RootValues: [A: one]; }'),
      'Array contributors should merge in effective-scope precedence.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lDerived := lRoot.FindChild('Derived');
    lItems := lDerived.FindProperty('Items').Value;
    AContext.AssertEquals(7, lItems.Items.Count,
      'Named overrides and every unnamed entry should be retained in order.');
    AContext.AssertEquals('A', lItems.Items[0].EffectiveName,
      'Right inherited contributor should replace A in its original slot.');
    AContext.AssertEquals('two', lItems.Items[0].EffectiveText,
      'The right inherited contributor should win A.');
    AContext.AssertEquals('', lItems.Items[1].EffectiveName,
      'Lower-precedence unnamed entries should remain unnamed and in place.');
    AContext.AssertEquals('Implicit', lItems.Items[2].EffectiveName,
      'An explicit name should override an implicit definition name in place.');
    AContext.AssertEquals('Replacement',
      lItems.Items[2].OriginalDefinitionName,
      'A replacement should retain higher-precedence definition provenance.');
    AContext.AssertEquals('B', lItems.Items[3].EffectiveName,
      'Local B should retain its inherited position.');
    AContext.AssertEquals('local', lItems.Items[3].EffectiveText,
      'Local named entries should win over inherited entries.');
    AContext.AssertEquals('RefTarget', lItems.Items[4].EffectiveName,
      'Implicit definition-reference names should resolve before folding.');
    AContext.AssertEquals('C', lItems.Items[5].EffectiveName,
      'New local named entries should append in local source order.');
    AContext.AssertEquals('', lItems.Items[6].EffectiveName,
      'Higher-precedence unnamed entries should append without matching.');
    lCopy := lDerived.FindProperty('Copy').Value.EffectiveValue;
    AContext.AssertEquals(7, lCopy.Items.Count,
      'Inherited array references should rebind to the final merged array.');
    AContext.AssertEquals('local', lCopy.Items[3].EffectiveText,
      'Inherited references should observe local effective-scope overrides.');
    AContext.AssertEquals('local',
      lDerived.FindProperty('Scalar').Value.EffectiveText,
      'Non-array property replacement should remain unchanged.');
    AContext.AssertTrue(lDerived.FindProperty('Switch').Value.Kind = nsvText,
      'Array-versus-non-array replacement should remain whole-property replacement.');
    AContext.AssertTrue(lDerived.FindProperty('SwitchBack').Value.Kind = nsvArray,
      'Non-array-versus-array replacement should remain whole-property replacement.');
    AContext.AssertEquals(2, lRoot.FindChild('EffectiveDerived').
      FindProperty('EffectiveItems').Value.Items.Count,
      'Effective array references should merge with higher array contributors.');
    AContext.AssertEquals('A', lRoot.FindChild('EffectiveDerived').
      FindProperty('EffectiveItems').Value.Items[0].EffectiveName,
      'The referenced lower array should retain its first entry.');
    AContext.AssertTrue(lRoot.FindChild('EffectiveScalar').
      FindProperty('EffectiveItems').Value.Kind = nsvText,
      'A higher scalar should replace a lower effective array reference.');

    AContext.AssertTrue(not lCompiler.CompileText('array-duplicate.nxscript',
      'Thing Root { Thing Base { Items: [Same: one, Same: two]; } ' +
      'Thing Derived (Base) { Items: [Same: local]; } }'),
      'Duplicate names inside one contributor should remain invalid.');
    lHasDuplicate := False;
    for lDiagnostic in lCompiler.Diagnostics do
      lHasDuplicate := lHasDuplicate or SameText(lDiagnostic.Code, 'NXS5005');
    AContext.AssertTrue(lHasDuplicate,
      'Contributor-local duplicate names should report NXS5005.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestComposedArrayEntryLookup(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lLibraryCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lDerived: TNexusScriptCompiledDefinition;
  lItems: TNexusScriptCompiledValue;
  lReference: TNexusScriptCompiledValue;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lLibraryCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText(
      'composed-array-entry-lookup.nxscript',
      'Thing Root { ' +
      'Thing Base { Items: [' +
      'Node A { Code: base; }, B: @Items.A, C: @Items.A.Code]; } ' +
      'Thing Higher { Items: [' +
      'Node A { Code: higher; }, D: high]; } ' +
      'Thing Derived (Base, Higher) { Items: [' +
      'Node A { Code: local; }, E: local]; } }'),
      'Contributor entry bodies should evaluate after the effective array is prepared.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lDerived := lRoot.FindChild('Derived');
    lItems := lDerived.FindProperty('Items').Value;
    AContext.AssertEquals(5, lItems.Items.Count,
      'The effective array should contain only final winning entries.');
    AContext.AssertEquals('A', lItems.Items[0].EffectiveName,
      'The local structural winner should retain the inherited position.');
    AContext.AssertEquals('local', lItems.Items[0].StructuralDefinition.
      FindProperty('Code').Value.EffectiveText,
      'The local structural entry should replace inherited contributors.');
    lReference := lItems.Items[1];
    AContext.AssertTrue(lReference.ResolvedValue = lItems.Items[0],
      'A contributor reference should resolve to the effective winning entry.');
    AContext.AssertEquals('B', lReference.StructuralDefinition.Name,
      'The effective structural projection should retain its receiving entry name.');
    AContext.AssertEquals('local', lReference.StructuralDefinition.
      FindProperty('Code').Value.EffectiveText,
      'The contributor projection should materialize the effective winner.');
    AContext.AssertEquals('local', lItems.Items[2].EffectiveText,
      'Downward lookup from a contributor should observe the effective winner.');
    AContext.AssertEquals('D', lItems.Items[3].EffectiveName,
      'A new inherited entry should retain contributor order.');
    AContext.AssertEquals('E', lItems.Items[4].EffectiveName,
      'A new local entry should append after inherited entries.');

    AContext.AssertTrue(lLibraryCompiler.CompileText('library.nxscript',
      'Thing Base { Items: [' +
      'Node A { Code: library; }, B: @Items.A]; }'),
      'The imported array contributor should compile independently.');
    lCompiler.AddImportedDocument(lLibraryCompiler.CompiledDocument);
    FreeAndNil(lLibraryCompiler);
    AContext.AssertTrue(lCompiler.CompileText('imported-composition.nxscript',
      'Thing Root { Thing Derived (Base) { Items: [' +
      'Node A { Code: local; }]; } }'),
      'A prepared imported contributor should compose into a local array.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lItems := lRoot.FindChild('Derived').FindProperty('Items').Value;
    AContext.AssertTrue(lItems.Items[1].ResolvedValue = lItems.Items[0],
      'An imported contributor reference should rebind to the local winner.');
    AContext.AssertEquals('local', lItems.Items[1].StructuralDefinition.
      FindProperty('Code').Value.EffectiveText,
      'An imported contributor projection should materialize the local winner.');

    AContext.AssertTrue(lCompiler.CompileText(
      'whole-array-reference-rebinding.nxscript',
      'Thing Root { Items: [' +
      'Node A { Code: root; }, B: @Items.A]; ' +
      'Thing Base { Items: @Root.Items; } ' +
      'Thing Derived (Base) { Items: [' +
      'Node A { Code: local; }]; } }'),
      'A completed whole-array reference should compose into a derived array.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lItems := lRoot.FindChild('Derived').FindProperty('Items').Value;
    AContext.AssertTrue(lItems.Items[1].ResolvedValue = lItems.Items[0],
      'A whole-array contributor reference should rebind to the final winner.');
    AContext.AssertEquals('local', lItems.Items[1].StructuralDefinition.
      FindProperty('Code').Value.EffectiveText,
      'A whole-array contributor projection should materialize the final winner.');
  finally
    lLibraryCompiler.Free;
    lCompiler.Free;
  end;
end;

procedure TestArrayEntryFailureState(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
  lItemsProperty: TNexusScriptCompiledProperty;
  lItems: TNexusScriptCompiledValue;
  lDiagnostic: TNexusScriptDiagnostic;
  lHasCycle: Boolean;
  lHasUnresolved: Boolean;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(not lCompiler.CompileText('array-entry-self-cycle.nxscript',
      'Thing Root { Items: [A: @Items.A]; Later: @Items.A; }'),
      'A named array entry must not recursively resolve itself.');
    lHasCycle := False;
    lHasUnresolved := False;
    for lDiagnostic in lCompiler.Diagnostics do
    begin
      lHasCycle := lHasCycle or SameText(lDiagnostic.Code, 'NXS5002');
      lHasUnresolved := lHasUnresolved or
        SameText(lDiagnostic.Code, 'NXS5001');
    end;
    AContext.AssertTrue(lHasCycle,
      'A recursive named entry should report NXS5002.');
    AContext.AssertTrue(not lHasUnresolved,
      'A matched recursive entry should not be misreported as unresolved.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lItemsProperty := lRoot.FindProperty('Items');
    lItems := lItemsProperty.Value;
    AContext.AssertTrue(lItems.Items[0].EvaluationState = nsvesFailed,
      'A cyclic entry must remain failed rather than completed.');
    AContext.AssertTrue(lItems.EvaluationState = nsvesFailed,
      'An array containing a cyclic entry must remain failed.');
    AContext.AssertTrue(not lItemsProperty.Resolving,
      'Property resolving state must clear after failed evaluation.');
    AContext.AssertTrue(lRoot.FindProperty('Later').Value.EvaluationState =
      nsvesFailed,
      'A later lookup must not expose the failed entry as completed.');

    AContext.AssertTrue(not lCompiler.CompileText(
      'array-entry-mutual-cycle.nxscript',
      'Thing Root { Items: [A: @Items.B, B: @Items.A]; }'),
      'Mutually recursive named entries must fail deterministically.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lItems := lRoot.FindProperty('Items').Value;
    AContext.AssertTrue(
      (lItems.Items[0].EvaluationState = nsvesFailed) and
      (lItems.Items[1].EvaluationState = nsvesFailed),
      'Both sides of a named-entry cycle must remain failed.');

    AContext.AssertTrue(not lCompiler.CompileText(
      'array-entry-unresolved-state.nxscript',
      'Thing Root { Items: [A: @Missing]; Later: @Items.A; }'),
      'An unresolved named entry must fail compilation.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lItems := lRoot.FindProperty('Items').Value;
    AContext.AssertTrue(lItems.Items[0].EvaluationState = nsvesFailed,
      'An unresolved entry must remain failed rather than completed.');
    AContext.AssertTrue(lRoot.FindProperty('Later').Value.EvaluationState =
      nsvesFailed,
      'Later lookup must propagate an unresolved entry failure.');

    AContext.AssertTrue(not lCompiler.CompileText(
      'array-entry-sibling-failure.nxscript',
      'Thing Root { Items: [A: good, B: @Missing]; Later: @Items.A; }'),
      'A failed array must not expose a separately completed entry.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    lItems := lRoot.FindProperty('Items').Value;
    AContext.AssertTrue(lItems.Items[0].EvaluationState = nsvesCompleted,
      'The independent sibling should demonstrate a completed partial result.');
    AContext.AssertTrue(lItems.EvaluationState = nsvesFailed,
      'The containing array must remain failed when another entry fails.');
    AContext.AssertTrue(lRoot.FindProperty('Later').Value.EvaluationState =
      nsvesFailed,
      'Later lookup must not expose a completed entry from a failed array.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestQualifiedOwner(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('owner.nxscript',
      'Thing Root { Thing Constants { Local: correct; Name: @Local; } ' +
      'Alias: @Root.Constants.Name; ChildValue: @Constants.Name; ' +
      'Local: wrong; }'),
      'Qualified reference should compile.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals('correct',
      lRoot.FindProperty('Alias').Value.EffectiveText,
      'Referenced property should evaluate in its owner scope.');
    AContext.AssertEquals('correct',
      lRoot.FindProperty('ChildValue').Value.EffectiveText,
      'A qualified reference should descend through a local child.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestCompileFailures(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(not lCompiler.CompileText('duplicate.nxscript',
      'Thing Root { Value: one; Thing Value {} }'),
      'Unified member collision should fail.');
    AContext.AssertTrue(not lCompiler.CompileText('unresolved.nxscript',
      'Thing Root { Value: @Missing; }'),
      'Unresolved reference should fail.');
    AContext.AssertTrue(not lCompiler.CompileText('cycle.nxscript',
      'Thing Root { A: @B; B: @A; }'),
      'Value dependency cycle should fail.');
    AContext.AssertTrue(not lCompiler.CompileText('malformed.nxscript',
      'Thing Root { Value: text;'),
      'Missing closing brace should produce a diagnostic.');
    AContext.AssertTrue(not lCompiler.CompileText('root-sibling-reference.nxscript',
      'Thing A { Value: hidden; } Thing B { Value: @A.Value; }'),
      'Nested references must not resolve through ordinary root siblings.');
    AContext.AssertTrue(not lCompiler.CompileText('root-sibling-composition.nxscript',
      'Thing A { Value: hidden; } Thing B { Thing C (A) {} }'),
      'Nested composition must not resolve through ordinary root siblings.');
  finally
    lCompiler.Free;
  end;
end;

function CollectionFixturePath(const AName: string): string;
begin
  Result := IncludeFixturePath('..\include-collections\' + AName);
end;

procedure TestIncludeCollections(AContext: TNXTestContext);
var
  lData: TJSONData;
  lRoot, lCollections, lTable, lMetadata: TJSONObject;
  lTables, lFields: TJSONArray;
  lIndex: Integer;
  lText: string;
begin
  lData := GetJSON(ExecuteCLI(['/input=' +
    CollectionFixturePath('CustomerInventory.nxscript')]));
  try
    lRoot := RequireJSONObject(lData, 'root');
    lCollections := RequireJSONObject(RequireJSONMember(RequireJSONObject(
      RequireJSONMember(lRoot, '_nx'), 'metadata'), 'Collections'), 'collections');
    lTables := RequireJSONArray(RequireJSONMember(lCollections, 'Table'), 'tables');
    AContext.AssertEquals(9, lTables.Count, 'All nine nested tables are presented together.');
    AContext.AssertEquals(1, RequireJSONArray(RequireJSONMember(lCollections,
      'Constants'), 'constants').Count, 'A diamond include contributes Shared once.');
    for lIndex := 0 to lTables.Count - 1 do
    begin
      lTable := RequireJSONObject(lTables.Items[lIndex], 'table');
      lFields := RequireJSONArray(RequireJSONMember(lTable, 'Fields'), 'fields');
      AContext.AssertEquals(1, lFields.Count, 'Each table keeps its own fields.');
      lMetadata := RequireJSONObject(RequireJSONMember(lTable, '_nx'), 'metadata');
      AContext.AssertTrue(Pos('.nxscript', RequireJSONMember(RequireJSONObject(
        RequireJSONMember(lMetadata, 'SourceRange'), 'source'), 'SourceName').AsString) > 0,
        'Collected tables retain their declaring source.');
    end;
  finally
    lData.Free;
  end;
  lText := ExecuteCLI(['/input=' + CollectionFixturePath('CustomerInventory.nxscript'),
    '/template=' + CollectionFixturePath('Tables.mustache')]);
  AContext.AssertEquals('Product:ID' + LineEnding + 'Stock:ID' + LineEnding +
    'Warehouse:ID' + LineEnding + 'Movement:ID' + LineEnding + 'Supplier:ID' +
    LineEnding + 'Account:ID' + LineEnding + 'Contact:ID' + LineEnding +
    'Address:ID' + LineEnding + 'Invoice:ID', Trim(lText),
    'One template iteration emits the nine tables in include order.');
end;

procedure TestIncludeModuleCollections(AContext: TNXTestContext);
var
  lData: TJSONData;
  lRoot, lCollections, lConcrete, lBase, lField: TJSONObject;
  lVariant: Integer;
  lFileName: string;
begin
  for lVariant := 0 to 1 do
  begin
    if lVariant = 0 then lFileName := 'ModuleOnly.nxscript'
    else lFileName := 'Mixed.nxscript';
    lData := GetJSON(ExecuteCLI(['/input=' + CollectionFixturePath(lFileName)]));
    try
      lRoot := RequireJSONObject(lData, 'root');
      lCollections := RequireJSONObject(RequireJSONMember(RequireJSONObject(
        RequireJSONMember(lRoot, '_nx'), 'metadata'), 'Collections'), 'collections');
      AContext.AssertEquals(1 + lVariant, RequireJSONArray(
        RequireJSONMember(lCollections, 'Table'), 'tables').Count,
        'Module-only bases are excluded; mixed includes contribute the base once.');
      lConcrete := RequireJSONObject(RequireJSONMember(lRoot, 'Concrete'), 'concrete');
      AContext.AssertTrue(RequireJSONMember(lConcrete, 'Fields') <> nil,
        'Composition retains inherited fields.');
      if lVariant = 1 then
      begin
        lField := RequireJSONObject(RequireJSONArray(RequireJSONMember(
          lConcrete, 'Fields'), 'concrete fields').Items[0], 'concrete ID');
        AContext.AssertEquals('UUID', RequireJSONMember(lField, 'Type').AsString,
          'Derived ID overrides only the derived table.');
        lBase := RequireJSONObject(RequireJSONMember(lRoot, 'Base'), 'base');
        lField := RequireJSONObject(RequireJSONArray(RequireJSONMember(
          lBase, 'Fields'), 'base fields').Items[0], 'base ID');
        AContext.AssertEquals('Integer', RequireJSONMember(lField, 'Type').AsString,
          'The original table keeps its original ID type.');
        lBase := RequireJSONObject(RequireJSONMember(lConcrete, 'Original'), 'original');
        lField := RequireJSONObject(RequireJSONArray(RequireJSONMember(
          lBase, 'Fields'), 'alias fields').Items[0], 'alias ID');
        AContext.AssertEquals('Integer', RequireJSONMember(lField, 'Type').AsString,
          'A reference to the original still denotes the original table.');
      end;
      AContext.AssertEquals('Base', RequireJSONMember(RequireJSONObject(
        RequireJSONMember(RequireJSONObject(RequireJSONMember(RequireJSONObject(
          RequireJSONMember(lConcrete, 'Original'), 'original'), '_nx'),
          'metadata'), 'Reference'), 'reference'), 'Name').AsString,
        'References still target the original base.');
    finally
      lData.Free;
    end;
  end;
  AContext.AssertTrue(Pos('duplicate artifact root', LowerCase(CLIError([
    '/input=' + CollectionFixturePath('Conflict.nxscript')]))) > 0,
    'Distinct same-named roots fail; they are never merged.');
  AContext.AssertTrue(Pos('duplicate artifact root', LowerCase(CLIError([
    '/input=' + CollectionFixturePath('CaseConflict.nxscript')]))) > 0,
    'Case variation does not bypass root-name collisions.');
end;

procedure TestIncludedLanguageRules(AContext: TNXTestContext);
begin
  AContext.AssertTrue(Pos('Compile', ExecuteCLI(['/input=' +
    CollectionFixturePath('Valid.nxscript'), '/validate'])) > 0,
    'Discovered FPC and Git rule pieces both validate.');
  AContext.AssertTrue(Pos('Validation failed', CLIError(['/input=' +
    CollectionFixturePath('Invalid.nxscript'), '/validate'])) > 0,
    'Operation-specific invalid properties fail.');
  AContext.AssertTrue(Pos('Validation failed', CLIError(['/input=' +
    CollectionFixturePath('InvalidInclude.nxscript'), '/validate'])) > 0,
    'Included subject definitions are validated too.');
  AContext.AssertTrue(Pos('Duplicate definition rule FPC', CLIError(['/input=' +
    CollectionFixturePath('DuplicateRule.nxscript'), '/validate'])) > 0,
    'Same-named rules from different fragments fail rather than merge.');
end;

procedure RemoveDefinitionProvenance(AData: TJSONData);
var
  lObject, lMetadata: TJSONObject;
  lIndex: Integer;
begin
  if AData.JSONType = jtObject then
  begin
    lObject := RequireJSONObject(AData, 'object');
    if lObject.Find('_nx', lMetadata) then
    begin
      lIndex := lMetadata.IndexOfName('SourceRange');
      if lIndex >= 0 then lMetadata.Delete(lIndex);
    end;
  end;
  for lIndex := 0 to AData.Count - 1 do
    RemoveDefinitionProvenance(AData.Items[lIndex]);
end;

procedure TestIncludeFileEquivalence(AContext: TNXTestContext);
var
  lSingle, lSplit: TJSONData;
  lLanguage, lSubject: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
  lIndex: Integer;
  lFileName: string;
begin
  lSingle := GetJSON(ExecuteCLI(['/input=' + CollectionFixturePath('SingleFile.nxscript')]));
  lSplit := nil;
  try
    lSplit := GetJSON(ExecuteCLI(['/input=' + CollectionFixturePath('CustomerInventory.nxscript')]));
    AContext.AssertTrue(lSingle.AsJSON <> lSplit.AsJSON,
      'Actual source provenance must differ between layouts.');
    RemoveDefinitionProvenance(lSingle);
    RemoveDefinitionProvenance(lSplit);
    AContext.AssertEquals(lSingle.AsJSON, lSplit.AsJSON,
      'Splitting into includes changes only source provenance, not the presented model.');
  finally
    lSplit.Free;
    lSingle.Free;
  end;
  AContext.AssertEquals(ExecuteCLI(['/input=' + CollectionFixturePath('SingleFile.nxscript'),
    '/template=' + CollectionFixturePath('Tables.mustache')]),
    ExecuteCLI(['/input=' + CollectionFixturePath('CustomerInventory.nxscript'),
    '/template=' + CollectionFixturePath('Tables.mustache')]),
    'Generated output must not depend on file boundaries.');
  lLanguage := TNexusScriptCompilationSession.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lLanguage.CompileFile(CollectionFixturePath('Equivalence.Language.nxscript')),
      'Equivalence language compiles.');
    for lIndex := 0 to 1 do
    begin
      if lIndex = 0 then lFileName := 'SingleFile.nxscript'
      else lFileName := 'CustomerInventory.nxscript';
      lSubject := TNexusScriptCompilationSession.Create;
      try
        AContext.AssertTrue(lSubject.CompileFile(CollectionFixturePath(lFileName)), lSubject.LastError);
        AContext.AssertTrue(lValidator.Validate(lSubject.EntryCompiler.CompiledDocument,
          lLanguage.EntryCompiler.CompiledDocument), 'Both layouts validate against the same rules.');
      finally
        lSubject.Free;
      end;
    end;
  finally
    lValidator.Free;
    lLanguage.Free;
  end;
end;

procedure TestCompleteSQLContract(AContext: TNXTestContext);
var
  lActual, lExpected: string;
begin
  lActual := ExecuteCLI(['/input=' + CollectionFixturePath('SQL.nxscript'),
    '/template=' + CollectionFixturePath('SQL.mustache')]);
  lExpected := FileText(CollectionFixturePath('SQL.expected.txt'));
  { Normalize platform line endings only. Do not rewrite expected content. }
  lActual := StringReplace(lActual, #13#10, #10, [rfReplaceAll]);
  lExpected := StringReplace(lExpected, #13#10, #10, [rfReplaceAll]);
  AContext.AssertEquals(lExpected, lActual,
    'Complete handwritten SQL contract: columns, ordering, index, and reference target.');
end;

procedure TestTargetedIncludeCollections(AContext: TNXTestContext);
var
  lSelection: TNexusScriptTargetSelection;
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
  lRules: TNexusScriptLanguageDefinition;
  lEmitter: TNexusScriptJSONEmitter;
  lData: TJSONData;
  lCollections: TJSONObject;
  lSelected, lExcluded: string;
  lIndex: Integer;
begin
  for lIndex := 0 to 1 do
  begin
    if lIndex = 0 then begin lSelected := 'Dev'; lExcluded := 'Prod'; end
    else begin lSelected := 'Prod'; lExcluded := 'Dev'; end;
    lSelection := TNexusScriptTargetSelection.Create;
    lSelection.Add('Target', lSelected);
    lSession := TNexusScriptCompilationSession.Create(lSelection);
    lValidator := TNexusScriptValidator.Create;
    lRules := TNexusScriptLanguageDefinition.Create;
    lEmitter := TNexusScriptJSONEmitter.Create;
    lData := nil;
    try
      AContext.AssertTrue(lSession.CompileFile(CollectionFixturePath('targets\Entry.nxscript')),
        lSession.LastError);
      AContext.AssertTrue(lValidator.Validate(lSession.EntryCompiler.CompiledDocument,
        lSession.EntryCompiler.CompiledDocument.DialectDocument), 'Selected rules validate selected includes.');
      AContext.AssertTrue(lRules.Normalize(lSession.EntryCompiler.CompiledDocument.DialectDocument),
        'Selected language normalizes.');
      AContext.AssertTrue(lRules.FindDefinitionRule(lSelected) <> nil, 'Selected rule exists.');
      AContext.AssertTrue(lRules.FindDefinitionRule(lExcluded) = nil, 'Excluded rule does not leak.');
      lEmitter.AddDocument(lSession.EntryCompiler.CompiledDocument);
      lData := GetJSON(lEmitter.JSON);
      lCollections := RequireJSONObject(RequireJSONMember(RequireJSONObject(
        RequireJSONMember(RequireJSONObject(lData, 'root'), '_nx'), 'metadata'),
        'Collections'), 'collections');
      AContext.AssertEquals(2, RequireJSONArray(RequireJSONMember(lCollections,
        lSelected), 'selected collection').Count, 'Entry and shared include appear once each.');
      AContext.AssertTrue(lCollections.Find(lExcluded) = nil, 'Excluded collection is absent.');
    finally
      lData.Free;
      lEmitter.Free;
      lRules.Free;
      lValidator.Free;
      lSession.Free;
      lSelection.Free;
    end;
  end;
end;

procedure TestEmitterFailureAndLifetime(AContext: TNXTestContext);
var
  lCompiler, lOther: TNexusScriptCompiler;
  lEmitter: TNexusScriptJSONEmitter;
  lBefore, lAfter: string;
  lFailed: Boolean;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lOther := TNexusScriptCompiler.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('stable.nxscript',
      'Thing Stable { Value: original; }'), 'Initial input compiles.');
    lEmitter.AddDocument(lCompiler.CompiledDocument);
    lBefore := lEmitter.JSON;
    AContext.AssertTrue(lOther.CompileText('bad.nxscript',
      'Thing Fresh {} Thing Invalid { _nx: forbidden; }'), 'Invalid output input compiles.');
    lFailed := False;
    try
      lEmitter.AddDocument(lOther.CompiledDocument);
    except
      on E: ENexusScriptJSON do lFailed := True;
    end;
    AContext.AssertTrue(lFailed, 'Reserved metadata fails during emission.');
    AContext.AssertEquals(lBefore, lEmitter.JSON,
      'Failure after staging a valid root must leave all prior output unchanged.');
    AContext.AssertTrue(lOther.CompileText('good.nxscript', 'Thing Fresh { Value: accepted; }'),
      'Recovery input compiles.');
    lEmitter.AddDocument(lOther.CompiledDocument);
    lAfter := lEmitter.JSON;
    AContext.AssertTrue(Pos('accepted', lAfter) > 0, 'A valid addition succeeds after failure.');
    AContext.AssertTrue(lCompiler.CompileText('stable.nxscript',
      'Thing Changed { Value: replacement; }'), 'Source can be recompiled after emission.');
    FreeAndNil(lCompiler);
    FreeAndNil(lOther);
    AContext.AssertEquals(lAfter, lEmitter.JSON,
      'Recompilation and source destruction cannot alter copied output.');
    AContext.AssertEquals(lAfter, lEmitter.JSON, 'Repeated serialization is deterministic.');
  finally
    lEmitter.Free;
    lOther.Free;
    lCompiler.Free;
  end;
end;

procedure TestStructuralReferenceAliasJSON(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lEmitter: TNexusScriptJSONEmitter;
  lData: TJSONData;
  lRoot, lAlias: TJSONObject;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('reference-alias.nxscript',
      'Thing Root { Thing Base { Value: original; } ' +
      'Original: @Root.Base; Alias: @Original; }'),
      'A reference to a structural reference compiles.');
    lEmitter.AddDocument(lCompiler.CompiledDocument);
    lData := GetJSON(lEmitter.JSON);
    try
      lRoot := RequireJSONObject(RequireJSONMember(
        RequireJSONObject(lData, 'root'), 'Root'), 'definition');
      lAlias := RequireJSONObject(RequireJSONMember(lRoot, 'Alias'), 'alias');
      AContext.AssertEquals('original', RequireJSONMember(lAlias, 'Value').AsString,
        'The alias presents the original definition value.');
    finally
      lData.Free;
    end;
  finally
    lEmitter.Free;
    lCompiler.Free;
  end;
end;

procedure RegisterNexusScriptTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusScript.Compiler');
  lSuite.AddTest('StructureAndValues', @TestStructureAndValues);
  lSuite.AddTest('DefinitionTargets', @TestDefinitionTargets);
  lSuite.AddTest('TargetFiltering', @TestTargetFiltering);
  lSuite.AddTest('TargetVariants', @TestTargetVariants);
  lSuite.AddTest('TargetPropagation', @TestTargetPropagation);
  lSuite.AddTest('Composition', @TestComposition);
  lSuite.AddTest('CompiledTransferCloning', @TestCompiledTransferCloning);
  lSuite.AddTest('StructuralReferences', @TestStructuralReferences);
  lSuite.AddTest('ArrayEntries', @TestArrayEntries);
  lSuite.AddTest('QualifiedArrayEntryLookup',
    @TestQualifiedArrayEntryLookup);
  lSuite.AddTest('ReferenceArrayProjection', @TestReferenceArrayProjection);
  lSuite.AddTest('WholeArrayReferences', @TestWholeArrayReferences);
  lSuite.AddTest('ArrayComposition', @TestArrayComposition);
  lSuite.AddTest('ComposedArrayEntryLookup',
    @TestComposedArrayEntryLookup);
  lSuite.AddTest('ArrayEntryFailureState', @TestArrayEntryFailureState);
  lSuite.AddTest('QualifiedOwner', @TestQualifiedOwner);
  lSuite.AddTest('CompileFailures', @TestCompileFailures);
  lSuite.AddTest('ModuleCompilation', @TestModuleCompilation);
  lSuite.AddTest('ModuleFailures', @TestModuleFailures);
  lSuite.AddTest('DialectParsing', @TestDialectParsing);
  lSuite.AddTest('DialectLoading', @TestDialectLoading);
  lSuite.AddTest('IncludeParsing', @TestIncludeParsing);
  lSuite.AddTest('IncludeLoading', @TestIncludeLoading);
  lSuite.AddTest('DependencyPatternParsing', @TestDependencyPatternParsing);
  lSuite.AddTest('IncludePatterns', @TestIncludePatterns);
  lSuite.AddTest('ModulePatterns', @TestModulePatterns);
  lSuite.AddTest('PatternRelationshipOverlap',
    @TestPatternRelationshipOverlap);
  lSuite.AddTest('LanguageSelfValidation', @TestLanguageSelfValidation);
  lSuite.AddTest('SharedDialectCatalog', @TestSharedDialectCatalog);
  lSuite.AddTest('SchemaValidation', @TestSchemaValidation);
  lSuite.AddTest('IndependentContainmentRules',
    @TestIndependentContainmentRules);
  lSuite.AddTest('ValidatorDiagnostics', @TestValidatorDiagnostics);
  lSuite.AddTest('ValidatorReferences', @TestValidatorReferences);
  lSuite.AddTest('InvalidLanguageDefinition', @TestInvalidLanguageDefinition);
  lSuite.AddTest('LanguageFiniteValues', @TestLanguageFiniteValues);
  lSuite.AddTest('JSONEmitter', @TestJSONEmitter);
  lSuite.AddTest('DefinitionSourceRangeJSON',
    @TestDefinitionSourceRangeJSON);
  lSuite.AddTest('DefinitionTargetJSON', @TestDefinitionTargetJSON);
  lSuite.AddTest('TargetFilteredJSON', @TestTargetFilteredJSON);
  lSuite.AddTest('ExternalDataDeclarations', @TestExternalDataDeclarations);
  lSuite.AddTest('ExternalDataCompilation', @TestExternalDataCompilation);
  lSuite.AddTest('CommandLineParsing', @TestCommandLineParsing);
  lSuite.AddTest('CommandJSONArtifact', @TestCommandJSONArtifact);
  lSuite.AddTest('CommandTemplateArtifact', @TestCommandTemplateArtifact);
  lSuite.AddTest('NexusManifestLanguage', @TestNexusManifestLanguage);
  lSuite.AddTest('CommandTemplateManifest', @TestCommandTemplateManifest);
  lSuite.AddTest('CommandExternalDataManifest',
    @TestCommandExternalDataManifest);
  lSuite.AddTest('SchemaGenerationMockData',
    @TestSchemaGenerationMockData);
  lSuite.AddTest('CommandValidation', @TestCommandValidation);
  lSuite.AddTest('IncludeCollections', @TestIncludeCollections);
  lSuite.AddTest('IncludeModuleCollections', @TestIncludeModuleCollections);
  lSuite.AddTest('IncludedLanguageRules', @TestIncludedLanguageRules);
  lSuite.AddTest('IncludeFileEquivalence', @TestIncludeFileEquivalence);
  lSuite.AddTest('CompleteSQLContract', @TestCompleteSQLContract);
  lSuite.AddTest('TargetedIncludeCollections', @TestTargetedIncludeCollections);
  lSuite.AddTest('EmitterFailureAndLifetime', @TestEmitterFailureAndLifetime);
  lSuite.AddTest('StructuralReferenceAliasJSON', @TestStructuralReferenceAliasJSON);
end;

end.
