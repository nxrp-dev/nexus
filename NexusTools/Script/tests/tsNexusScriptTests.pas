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
  obNXTestContext,
  obNXTestSuite,
  obNXCommandLine,
  tpNexusScript,
  obNexusScriptModel,
  obNexusScriptCompiler,
  obNexusScriptSession,
  obNexusScriptCommand,
  obNexusScriptValidator,
  obNexusScriptSchemaConsumer,
  obMetaDataModuleList,
  obNexusSchemaParser,
  obMetaDataTransformations,
  obMetaDataJSON,
  obMustacheRenderer;

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
  Result := ExpandFileName('..\..\..\NexusTools\Script\validator\fixtures\' +
    AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName('NexusTools\Script\validator\fixtures\' +
      AFileName);
end;

function DoctypeFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\doctype\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\doctype\' + AFileName);
end;

function IncludeFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\include\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\include\' + AFileName);
end;

function CLIFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\cli\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\cli\' + AFileName);
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

function ExecuteCLI(const AArguments: array of string): string;
var
  lOutput: TMemoryStream;
begin
  TNXCommandLine.ClearRegisteredFlags;
  TNexusScriptCommand.RegisterCommandLineFlags;
  TNXCommandLine.AllowUnknownFlags := False;
  lOutput := TMemoryStream.Create;
  try
    TNXCommandLine.ParseArguments(AArguments);
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

procedure TestDoctypeParsing(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('none.nxscript',
      'Thing Root {}'), 'Document without doctype should compile.');
    AContext.AssertTrue(lCompiler.SourceDocument.Doctype = nil,
      'Document without doctype should retain no declaration.');

    AContext.AssertTrue(lCompiler.CompileText('quoted.nxscript',
      'doctype "folder/type.nxscript"; Thing Root {}'),
      'Quoted doctype path should parse.');
    AContext.AssertEquals('folder/type.nxscript',
      lCompiler.SourceDocument.Doctype.Path,
      'Quoted doctype path should be retained.');
    AContext.AssertTrue(
      lCompiler.SourceDocument.Doctype.SourceRange.SourceName = 'quoted.nxscript',
      'Doctype source range should retain its source identity.');

    AContext.AssertTrue(lCompiler.CompileText('unquoted.nxscript',
      'module Shared "module.nxscript"; doctype folder/type.nxscript; ' +
      'Thing Root {}'),
      'Unquoted doctype path should parse beside a module.');
    AContext.AssertEquals('folder/type.nxscript',
      lCompiler.SourceDocument.Doctype.Path,
      'Unquoted doctype path should retain punctuation.');

    AContext.AssertTrue(not lCompiler.CompileText('duplicate-doctype.nxscript',
      'doctype "one.nxscript"; doctype "two.nxscript"; ' +
      'Thing Root {}'), 'Duplicate doctype should fail compilation.');
    AContext.AssertEquals('NXS2012', lCompiler.Diagnostics[0].Code,
      'Duplicate doctype diagnostic should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('misplaced-doctype.nxscript',
      'Thing Root {} doctype "type.nxscript";'),
      'Doctype after a definition should fail compilation.');
    AContext.AssertEquals('NXS2014', lCompiler.Diagnostics[0].Code,
      'Misplaced doctype diagnostic should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('malformed-doctype.nxscript',
      'doctype; Thing Root {}'),
      'Doctype without a path should fail compilation.');
    AContext.AssertEquals('NXS2011', lCompiler.Diagnostics[0].Code,
      'Malformed doctype diagnostic should be deterministic.');

    AContext.AssertTrue(not lCompiler.CompileText('named-doctype.nxscript',
      'doctype Rules "type.nxscript"; Thing Root {}'),
      'The removed named doctype form should fail compilation.');
    AContext.AssertEquals('NXS2011', lCompiler.Diagnostics[0].Code,
      'Named doctype rejection should use the declaration diagnostic.');
  finally
    lCompiler.Free;
  end;
end;

procedure TestDoctypeLoading(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lDocument: TNexusScriptCompiledDocument;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(
      DoctypeFixturePath('subject.nxscript')),
      'Doctype subject should compile: ' + lSession.LastError);
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertEquals('type.nxscript', lDocument.DoctypePath,
      'Declared doctype path should be retained.');
    AContext.AssertTrue(lDocument.DoctypeDocument <> nil,
      'Compiled doctype document should be associated.');
    AContext.AssertTrue(lDocument.DoctypeDocument.FindDefinition('TypeRule') <>
      nil, 'Doctype document should be compiled normally.');
    AContext.AssertTrue(SameText(lDocument.DoctypeSourceName,
      ExpandFileName(DoctypeFixturePath('type.nxscript'))),
      'Compiled doctype should retain canonical source identity.');
    lRoot := lDocument.FindDefinition('Root');
    AContext.AssertEquals('metadata',
      lRoot.FindProperty('Imported').Value.EffectiveText,
      'A cached document should remain usable as both doctype and module.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(
      DoctypeFixturePath('unquoted.nxscript')),
      'Unquoted doctype path should load: ' + lSession.LastError);
    AContext.AssertTrue(not lSession.CompileFile(
      DoctypeFixturePath('invisible.nxscript')),
      'Doctype definitions must not enter reference lookup.');
    AContext.AssertTrue(not lSession.CompileFile(
      DoctypeFixturePath('missing.nxscript')),
      'Missing doctype file should fail.');
    AContext.AssertTrue(Pos('doctype', LowerCase(lSession.LastError)) > 0,
      'Missing doctype failure should identify the relationship.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(not lSession.CompileFile(
      DoctypeFixturePath('cycle-a.nxscript')),
      'Doctype dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Doctype cycle failure should be deterministic.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(not lSession.CompileFile(
      DoctypeFixturePath('mixed-a.nxscript')),
      'Mixed doctype/module dependency cycle should fail.');
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

procedure TestIncludeLoading(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
begin
  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(IncludeFixturePath('entry.nxscript')),
      'Transitive includes should compile: ' + lSession.LastError);
    AContext.AssertEquals(3, lSession.ArtifactDocuments.Count,
      'Entry and transitive includes should form one deduplicated artifact set.');
    AContext.AssertEquals('entry.nxscript', ExtractFileName(
      lSession.ArtifactDocuments[0].CompiledDocument.SourceName),
      'Entry document should be first.');
    AContext.AssertEquals('child.nxscript', ExtractFileName(
      lSession.ArtifactDocuments[1].CompiledDocument.SourceName),
      'Includes should follow declaration-order depth-first traversal.');
    AContext.AssertEquals('leaf.nxscript', ExtractFileName(
      lSession.ArtifactDocuments[2].CompiledDocument.SourceName),
      'A repeated canonical include should appear only once.');

    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('multiple.nxscript')),
      'Session reuse should compile a new artifact graph: ' +
      lSession.LastError);
    AContext.AssertEquals(3, lSession.ArtifactDocuments.Count,
      'Session reuse should replace rather than append artifact state.');
    AContext.AssertEquals('second.nxscript', ExtractFileName(
      lSession.ArtifactDocuments[2].CompiledDocument.SourceName),
      'Independent includes should retain declaration order.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
  try
    AContext.AssertTrue(not lSession.CompileFile(
      IncludeFixturePath('invisible.nxscript')),
      'Included definitions must not enter reference lookup.');
    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('module-and-include.nxscript')),
      'One document may be both a module and an include: ' +
      lSession.LastError);
    AContext.AssertEquals(2, lSession.ArtifactDocuments.Count,
      'The included dependency should join the artifact set once.');
    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('module-only.nxscript')),
      'A module-only dependency should compile: ' + lSession.LastError);
    AContext.AssertEquals(1, lSession.ArtifactDocuments.Count,
      'Module dependencies should not automatically become artifacts.');
    AContext.AssertTrue(lSession.CompileFile(
      IncludeFixturePath('doctype-only.nxscript')),
      'A doctype-only dependency should compile: ' + lSession.LastError);
    AContext.AssertEquals(1, lSession.ArtifactDocuments.Count,
      'Doctype dependencies should not automatically become artifacts.');
  finally
    lSession.Free;
  end;

  lSession := TNexusScriptCompilationSession.Create;
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
      'Mixed include, doctype, and module dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Mixed dependency cycle failure should be deterministic.');
  finally
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

procedure TestValidatorSelfValidation(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(
      ValidatorFixturePath('Validator.nxscript')),
      'Validator definition should compile: ' + lSession.LastError);
    AContext.AssertTrue(lValidator.Validate(
      lSession.EntryCompiler.CompiledDocument,
      lSession.EntryCompiler.CompiledDocument),
      'Validator definition should validate itself: ' +
      ValidationFailure(lValidator));
  finally
    lValidator.Free;
    lSession.Free;
  end;
end;

procedure TestSchemaValidation(AContext: TNXTestContext);
var
  lSubjectSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
  lSubjectDocument: TNexusScriptCompiledDocument;
  lSchemaDocument: TNexusScriptCompiledDocument;
  lValidatorDocument: TNexusScriptCompiledDocument;
begin
  lSubjectSession := TNexusScriptCompilationSession.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSubjectSession.CompileFile(
      ValidatorFixturePath('Customer.nxscript')),
      'Schema subject should compile: ' + lSubjectSession.LastError);
    lSubjectDocument := lSubjectSession.EntryCompiler.CompiledDocument;
    lSchemaDocument := lSubjectDocument.DoctypeDocument;
    AContext.AssertTrue(lSchemaDocument <> nil,
      'Subject should retain its compiled Schema doctype.');
    lValidatorDocument := lSchemaDocument.DoctypeDocument;
    AContext.AssertTrue(lValidatorDocument <> nil,
      'Schema should retain its compiled Validator doctype.');
    AContext.AssertTrue(lValidator.Validate(lSchemaDocument,
      lValidatorDocument),
      'Schema validator should satisfy the validator contract: ' +
      ValidationFailure(lValidator));
    AContext.AssertTrue(lValidator.Validate(lSubjectDocument, lSchemaDocument),
      'Schema subject should satisfy its validator: ' +
      ValidationFailure(lValidator));
  finally
    lValidator.Free;
    lSubjectSession.Free;
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

procedure TestInvalidValidatorDefinition(AContext: TNXTestContext);
var
  lValidatorCompiler: TNexusScriptCompiler;
  lSubjectCompiler: TNexusScriptCompiler;
  lValidator: TNexusScriptValidator;
begin
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lSubjectCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lValidatorCompiler.CompileText('invalid-validator.nxscript',
      'Language Test { Definitions: [' +
      'Definition Thing { Root: True; Unexpected: value; }]; }'),
      'Malformed validator should remain valid generic NexusScript.');
    AContext.AssertTrue(lSubjectCompiler.CompileText('subject.nxscript',
      'Thing Root {}'), 'Subject should compile.');
    AContext.AssertTrue(not lValidator.Validate(lSubjectCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Unknown validator vocabulary should fail normalization.');
    AContext.AssertEquals('NSV1007', lValidator.Diagnostics[0].Code,
      'Invalid rule diagnostic should be deterministic.');
  finally
    lValidator.Free;
    lSubjectCompiler.Free;
    lValidatorCompiler.Free;
  end;
end;

procedure TestSelfValidatorFiniteValues(AContext: TNXTestContext);
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
      ValidatorFixturePath('Validator.nxscript')),
      'Meta-validator should compile: ' + lMetaSession.LastError);

    AContext.AssertTrue(lSubjectCompiler.CompileText('bad-policy.nxscript',
      'Language Bad { UnknownDefinitions: Maybe; Definitions: [' +
      'Definition Thing { Root: True; }]; }'),
      'Invalid-policy validator subject should compile generically.');
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
      'Invalid-name-policy validator subject should compile generically.');
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
      'Invalid-source-form validator subject should compile generically.');
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

procedure LoadLegacy(const AFileName: string; AMetaData: TMetaDataModuleList);
var
  lParser: TNexusSchemaParser;
  lCurrentDirectory: string;
begin
  lCurrentDirectory := GetCurrentDir;
  SetCurrentDir(ExtractFileDir(AFileName));
  lParser := TNexusSchemaParser.Create(AMetaData);
  try
    lParser.ExecuteFile(AFileName);
  finally
    lParser.Free;
    SetCurrentDir(lCurrentDirectory);
  end;
end;

function FirstDifference(const AExpected, AActual: string): string;
var
  lIndex: Integer;
begin
  lIndex := 1;
  while (lIndex <= Length(AExpected)) and (lIndex <= Length(AActual)) and
    (AExpected[lIndex] = AActual[lIndex]) do
    Inc(lIndex);
  Result := 'first difference at ' + IntToStr(lIndex) + '; expected=' +
    Copy(AExpected, lIndex, 120) + '; actual=' + Copy(AActual, lIndex, 120);
end;

function RenderJSON(const AJSON: string): string;
var
  lJSONFile: string;
  lOutputFile: string;
  lText: TStringList;
begin
  lJSONFile := GetTempFileName(GetTempDir, 'nsj');
  lOutputFile := GetTempFileName(GetTempDir, 'nso');
  lText := TStringList.Create;
  try
    lText.Text := AJSON;
    lText.SaveToFile(lJSONFile);
    RenderMustacheFile(lJSONFile,
      ExpandFileName('NexusTools\Schema\firebird\DatabaseSchema.create.mustache'),
      lOutputFile);
    lText.LoadFromFile(lOutputFile);
    Result := lText.Text;
  finally
    lText.Free;
    DeleteFile(lOutputFile);
    DeleteFile(lJSONFile);
  end;
end;

procedure LoadNexusScript(const AFileName: string;
  AMetaData: TMetaDataModuleList);
var
  lSession: TNexusScriptCompilationSession;
  lConsumer: TNexusScriptSchemaConsumer;
  lArtifactDocument: TNexusScriptArtifactDocument;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lConsumer := TNexusScriptSchemaConsumer.Create;
  try
    if not lSession.CompileFile(AFileName) then
      raise Exception.Create(lSession.LastError);
    for lArtifactDocument in lSession.ArtifactDocuments do
      if not lConsumer.Consume(lArtifactDocument.SourceDocument,
        lArtifactDocument.CompiledDocument, AMetaData) then
        raise Exception.Create('Schema consumer rejected ' +
          lArtifactDocument.CompiledDocument.SourceName);
  finally
    lConsumer.Free;
    lSession.Free;
  end;
end;

procedure TransformMetaData(AMetaData: TMetaDataModuleList);
var
  lTransform: TMetaDataTransform;
begin
  lTransform := TMetaDataTransform.Create;
  try
    lTransform.Transform(AMetaData);
  finally
    lTransform.Free;
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

    TNXCommandLine.ParseArguments([]);
    try
      TNXCommandLine.Validate;
      lError := '';
    except
      on E: Exception do lError := E.Message;
    end;
    AContext.AssertTrue(Pos('input', LowerCase(lError)) > 0,
      'Missing input should be rejected.');

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
end;

procedure TestCommandJSONArtifact(AContext: TNXTestContext);
var
  lMetaData: TMetaDataModuleList;
  lExpected: string;
  lActual: string;
  lOutputFile: string;
begin
  lMetaData := TMetaDataModuleList.Create;
  try
    LoadNexusScript(CLIFixturePath('Valid.nxscript'), lMetaData);
    TransformMetaData(lMetaData);
    lExpected := MetaDataToMustacheJSON(lMetaData);
  finally
    lMetaData.Free;
  end;

  lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.nxscript')]);
  AContext.AssertEquals(lExpected, lActual,
    'Default command output should be the existing JSON artifact.');

  lOutputFile := GetTempFileName(GetTempDir, 'nsc');
  try
    lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.nxscript'),
      '/output=' + lOutputFile]);
    AContext.AssertEquals('', lActual,
      'File output should leave stdout empty.');
    AContext.AssertEquals(lExpected, FileText(lOutputFile),
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
  AContext.AssertTrue(Pos('unable to produce', LowerCase(CLIError([
    '/input=' + CLIFixturePath('Unsupported.nxscript')]))) > 0,
    'Unsupported documents should not produce misleading JSON.');
end;

procedure TestCommandTemplateArtifact(AContext: TNXTestContext);
var
  lActual: string;
  lOutputFile: string;
begin
  lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.nxscript'),
    '/template=' + CLIFixturePath('Name.mustache')]);
  AContext.AssertEquals('Example', Trim(lActual),
    'A template should transform the normal JSON artifact.');

  lOutputFile := GetTempFileName(GetTempDir, 'nst');
  try
    lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.nxscript'),
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
    '/input=' + CLIFixturePath('Valid.nxscript'),
    '/template=' + CLIFixturePath('Missing.mustache')]))) > 0,
    'Missing templates should fail clearly.');
end;

procedure TestCommandValidation(AContext: TNXTestContext);
var
  lActual: string;
  lError: string;
begin
  lActual := ExecuteCLI(['/input=' + CLIFixturePath('Valid.nxscript'),
    '/validate']);
  AContext.AssertTrue(Pos('"NexusSchema"', lActual) > 0,
    'Successful doctype validation should allow artifact generation.');

  lError := CLIError(['/input=' +
    FixturePath('nexusscript\inForceMain.Schema.nxscript'), '/validate']);
  AContext.AssertTrue(Pos('doctype', LowerCase(lError)) > 0,
    'Validation without a doctype should fail explicitly.');

  lError := CLIError(['/input=' +
    CLIFixturePath('InvalidValidation.nxscript'), '/validate']);
  AContext.AssertTrue(Pos('NSV', lError) > 0,
    'Validation failure should report validator diagnostics.');

  lError := CLIError(['/input=' + CLIFixturePath('Valid.nxscript'),
    '/validate=true']);
  AContext.AssertTrue(Pos('does not accept', LowerCase(lError)) > 0,
    'Validate should reject an assigned value.');
end;

procedure TestInForceArtifactParity(AContext: TNXTestContext);
var
  lBaseline: TMetaDataModuleList;
  lReplacement: TMetaDataModuleList;
  lExpected: string;
  lActual: string;
begin
  lBaseline := TMetaDataModuleList.Create;
  lReplacement := TMetaDataModuleList.Create;
  try
    LoadLegacy(FixturePath('legacy\inForceMain.nxs'), lBaseline);
    LoadNexusScript(FixturePath('nexusscript\inForceMain.Schema.nxscript'), lReplacement);
    TransformMetaData(lBaseline);
    TransformMetaData(lReplacement);
    lExpected := MetaDataToMustacheJSON(lBaseline);
    lActual := MetaDataToMustacheJSON(lReplacement);
    AContext.AssertTrue(lExpected = lActual,
      'inForce metadata JSON should match exactly: ' +
      FirstDifference(lExpected, lActual));
    AContext.AssertEquals(RenderJSON(lExpected), RenderJSON(lActual),
      'inForce Firebird rendering should match exactly.');
  finally
    lReplacement.Free;
    lBaseline.Free;
  end;
end;

procedure TestStormArtifactParity(AContext: TNXTestContext);
var
  lBaseline: TMetaDataModuleList;
  lReplacement: TMetaDataModuleList;
  lExpected: string;
  lActual: string;
begin
  lBaseline := TMetaDataModuleList.Create;
  lReplacement := TMetaDataModuleList.Create;
  try
    LoadLegacy(FixturePath('legacy\StormSpecific.nxs'), lBaseline);
    LoadNexusScript(FixturePath('nexusscript\StormSpecific.Schema.nxscript'), lReplacement);
    TransformMetaData(lBaseline);
    TransformMetaData(lReplacement);
    lExpected := MetaDataToMustacheJSON(lBaseline);
    lActual := MetaDataToMustacheJSON(lReplacement);
    AContext.AssertTrue(lExpected = lActual,
      'Storm metadata JSON should match exactly: ' +
      FirstDifference(lExpected, lActual));
    AContext.AssertEquals(RenderJSON(lExpected), RenderJSON(lActual),
      'Storm Firebird rendering should match exactly.');
    lActual := ExecuteCLI(['/input=' +
      FixturePath('nexusscript\StormSpecific.Schema.nxscript')]);
    AContext.AssertTrue(lExpected = lActual,
      'The CLI should aggregate the complete include artifact set: ' +
      FirstDifference(lExpected, lActual));
  finally
    lReplacement.Free;
    lBaseline.Free;
  end;
end;

procedure TestSchemaConsumer(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lConsumer: TNexusScriptSchemaConsumer;
  lMetaData: TMetaDataModuleList;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lConsumer := TNexusScriptSchemaConsumer.Create;
  lMetaData := TMetaDataModuleList.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('schema.Schema.nxscript',
      'Schema Demo { Type Types { Fields: [Field DOM_NAME { Type: "varchar(100)"; }]; } ' +
      'Template Named { Fields: [Field NAME { Type: DOM_NAME; }]; } ' +
      'Table MANAGER {} ' +
      'Table PERSON (Named) { Fields: [' +
      'DISPLAY_NAME: Field INTERNAL_NAME { Type: DOM_NAME; }, ' +
      'Field MANAGER_ID { Reference: @Demo.MANAGER; }]; } ' +
      'Attributes History { Attribute Tracked { Value: True; } } ' +
      'Data People { Path: "people.csv"; } }'),
      'Schema parity source should compile.');
    AContext.AssertTrue(lConsumer.Consume(lCompiler.SourceDocument,
      lCompiler.CompiledDocument, lMetaData),
      'Schema consumer should accept one schema root.');
    AContext.AssertEquals(1, lMetaData.Count,
      'One metadata module should be produced.');
    AContext.AssertEquals(2, lMetaData[0].Tables.Count,
      'Two tables should be produced.');
    AContext.AssertEquals(2, lMetaData[0].Tables[1].Fields.Count,
      'Only local fields should be present before transformation.');
    AContext.AssertEquals('DISPLAY_NAME',
      lMetaData[0].Tables[1].Fields[0].Name,
      'Locally renamed inline field should emit its effective name first.');
    AContext.AssertEquals('MANAGER_ID',
      lMetaData[0].Tables[1].Fields[1].Name,
      'Unrenamed inline field should retain its declared name and order.');
    AContext.AssertTrue(lMetaData[0].Tables[1].Fields[1].IsReference,
      'Definition reference should become a schema field reference.');
    AContext.AssertEquals('people.csv', lMetaData.Data[0].Value,
      'Data registration should retain its path.');
  finally
    lMetaData.Free;
    lConsumer.Free;
    lCompiler.Free;
  end;
end;

procedure TestModuleCompilation(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lRoot: TNexusScriptCompiledDefinition;
  lFixture: string;
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
      'Document-root module alias should expose every root definition.');
    AContext.AssertEquals(2, lRoot.FindProperty('ModuleItems').Value.
      EffectiveValue.Items.Count,
      'Module-qualified array references should expose an owned result.');
    AContext.AssertEquals('First', lRoot.FindProperty('ModuleItems').Value.
      EffectiveValue.Items[0].EffectiveName,
      'Module-qualified array results should retain entry names and order.');
    AContext.AssertEquals('inherited',
      lRoot.FindChild('Derived').FindProperty('Shared').Value.EffectiveText,
      'Nested composition should resolve through a module alias.');
  finally
    lSession.Free;
  end;
end;

procedure TestModuleFailures(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lFixture: string;
begin
  lSession := TNexusScriptCompilationSession.Create;
  try
    lFixture := ExpandFileName('..\..\..\NexusTools\Script\tests\fixtures\modules\cycle-a.nxscript');
    if not FileExists(lFixture) then
      lFixture := ExpandFileName('NexusTools\Script\tests\fixtures\modules\cycle-a.nxscript');
    AContext.AssertTrue(not lSession.CompileFile(lFixture),
      'Module dependency cycle should fail.');
    AContext.AssertTrue(Pos('cycle', LowerCase(lSession.LastError)) > 0,
      'Cycle failure should be deterministic.');
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
    AContext.AssertTrue(lItems.Items[3].Evaluated,
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

procedure TestQualifiedOwner(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lRoot: TNexusScriptCompiledDefinition;
begin
  lCompiler := TNexusScriptCompiler.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('owner.nxscript',
      'Thing Root { Thing Constants { Local: correct; Name: @Local; } ' +
      'Alias: @Root.Constants.Name; Local: wrong; }'),
      'Qualified reference should compile.');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals('correct',
      lRoot.FindProperty('Alias').Value.EffectiveText,
      'Referenced property should evaluate in its owner scope.');
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

procedure RegisterNexusScriptTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusScript.Compiler');
  lSuite.AddTest('StructureAndValues', @TestStructureAndValues);
  lSuite.AddTest('Composition', @TestComposition);
  lSuite.AddTest('StructuralReferences', @TestStructuralReferences);
  lSuite.AddTest('ArrayEntries', @TestArrayEntries);
  lSuite.AddTest('ReferenceArrayProjection', @TestReferenceArrayProjection);
  lSuite.AddTest('WholeArrayReferences', @TestWholeArrayReferences);
  lSuite.AddTest('ArrayComposition', @TestArrayComposition);
  lSuite.AddTest('QualifiedOwner', @TestQualifiedOwner);
  lSuite.AddTest('CompileFailures', @TestCompileFailures);
  lSuite.AddTest('ModuleCompilation', @TestModuleCompilation);
  lSuite.AddTest('ModuleFailures', @TestModuleFailures);
  lSuite.AddTest('DoctypeParsing', @TestDoctypeParsing);
  lSuite.AddTest('DoctypeLoading', @TestDoctypeLoading);
  lSuite.AddTest('IncludeParsing', @TestIncludeParsing);
  lSuite.AddTest('IncludeLoading', @TestIncludeLoading);
  lSuite.AddTest('ValidatorSelfValidation', @TestValidatorSelfValidation);
  lSuite.AddTest('SchemaValidation', @TestSchemaValidation);
  lSuite.AddTest('IndependentContainmentRules',
    @TestIndependentContainmentRules);
  lSuite.AddTest('ValidatorDiagnostics', @TestValidatorDiagnostics);
  lSuite.AddTest('ValidatorReferences', @TestValidatorReferences);
  lSuite.AddTest('InvalidValidatorDefinition', @TestInvalidValidatorDefinition);
  lSuite.AddTest('SelfValidatorFiniteValues', @TestSelfValidatorFiniteValues);
  lSuite.AddTest('SchemaConsumer', @TestSchemaConsumer);
  lSuite.AddTest('CommandLineParsing', @TestCommandLineParsing);
  lSuite.AddTest('CommandJSONArtifact', @TestCommandJSONArtifact);
  lSuite.AddTest('CommandTemplateArtifact', @TestCommandTemplateArtifact);
  lSuite.AddTest('CommandValidation', @TestCommandValidation);
  lSuite.AddTest('InForceArtifactParity', @TestInForceArtifactParity);
  lSuite.AddTest('StormArtifactParity', @TestStormArtifactParity);
end;

end.
