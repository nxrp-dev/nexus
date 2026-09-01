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
  obNexusScriptJSON,
  obNexusScriptExternalSource,
  obNexusScriptCommand,
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

procedure TestDefinitionTags(AContext: TNXTestContext);
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
begin
  lCompiler := TNexusScriptCompiler.Create;
  lImportCompiler := TNexusScriptCompiler.Create;
  lFailureCompiler := TNexusScriptCompiler.Create;
  lValidatorCompiler := TNexusScriptCompiler.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lCompiler.CompileText('tags.nxscript',
      'Thing Root [Production, PRODUCTION, "Cross Reference", ' +
      '"Line^nBreak", "Build.Production", Environment=Production] { ' +
      'Tags: domain; ' +
      'Thing Base [Windows] { Thing MailSettings [Shared] {} } ' +
      'Thing Release (Base) [Production] {} ' +
      'Thing Nested [NestedTag] {} Alias: @Nested; ' +
      'Items: [Node Inline [InlineTag] { Value: yes; }]; }'),
      'Tagged definitions should compile.');
    lSourceRoot := lCompiler.SourceDocument.FindDefinition('Root');
    lRoot := lCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals(6, lSourceRoot.Tags.Count,
      'Source tags should retain their count.');
    AContext.AssertEquals('Production', lSourceRoot.Tags[0],
      'Source tags should retain declaration order and spelling.');
    AContext.AssertEquals('PRODUCTION', lSourceRoot.Tags[1],
      'Tag identity should be case-sensitive.');
    AContext.AssertEquals('Cross Reference', lSourceRoot.Tags[2],
      'Quoted tag whitespace should be decoded and retained.');
    AContext.AssertEquals('Line' + #10 + 'Break', lSourceRoot.Tags[3],
      'Quoted tags should use existing escape decoding.');
    AContext.AssertEquals('Build.Production', lSourceRoot.Tags[4],
      'Quoted language punctuation should remain literal tag text.');
    AContext.AssertEquals('Environment=Production', lSourceRoot.Tags[5],
      'Punctuation within a word should have no tag semantics.');
    AContext.AssertTrue(lRoot.Tags <> lSourceRoot.Tags,
      'Source and compiled definitions should own distinct tag lists.');
    AContext.AssertEquals(lSourceRoot.Tags.Text, lRoot.Tags.Text,
      'Compilation should preserve local tags exactly.');
    AContext.AssertEquals('domain',
      lRoot.FindProperty('Tags').Value.EffectiveText,
      'A domain Tags property should remain independent from metadata.');

    lRelease := lRoot.FindChild('Release');
    AContext.AssertEquals(1, lRelease.Tags.Count,
      'Composition should retain only receiver tags.');
    AContext.AssertEquals('Production', lRelease.Tags[0],
      'Composition should not copy contributor tags.');
    AContext.AssertEquals('Shared',
      lRelease.FindChild('MailSettings').Tags[0],
      'A composed child clone should retain its own local tags.');
    AContext.AssertEquals('NestedTag', lRoot.FindProperty('Alias').Value.
      StructuralDefinition.Tags[0],
      'Structural references should preserve represented-definition tags.');
    lInline := lRoot.FindProperty('Items').Value.Items[0].StructuralDefinition;
    AContext.AssertEquals('InlineTag', lInline.Tags[0],
      'Tagged inline definitions should be recognized and preserved.');

    lImportCompiler.AddImportedDocument(lCompiler.CompiledDocument);
    AContext.AssertTrue(lImportCompiler.CompileText('import-consumer.nxscript',
      'Thing Consumer {}'), 'Tagged imported definitions should compile.');
    lImportedRoot := lImportCompiler.CompiledDocument.FindDefinition('Root');
    AContext.AssertEquals(lRoot.Tags.Text, lImportedRoot.Tags.Text,
      'Imported-definition clones should preserve tags.');
    AContext.AssertTrue(lImportedRoot.Tags <> lRoot.Tags,
      'Imported definitions should own independent tag lists.');

    AContext.AssertTrue(lValidatorCompiler.CompileText('tag-language.nxscript',
      'Language Test { Definitions: [Definition Thing { Root: True; ' +
      'UnknownProperties: Allow; }]; }'),
      'Tag-neutral validator language should compile.');
    AContext.AssertTrue(lValidator.Validate(lCompiler.CompiledDocument,
      lValidatorCompiler.CompiledDocument),
      'Tags should add no validator policy semantics.');

    AContext.AssertTrue(not lFailureCompiler.CompileText('empty-tags.nxscript',
      'Thing Root [] {}'), 'An empty tag clause should fail.');
    AContext.AssertEquals('NXS3005', lFailureCompiler.Diagnostics[0].Code,
      'Empty tag clauses should use a stable diagnostic.');
    AContext.AssertEquals(13, lFailureCompiler.Diagnostics[0].SourceRange.
      StartPosition.Column,
      'The empty-clause diagnostic should point at the closing bracket.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('duplicate-tag.nxscript',
      'Thing Root [Production, "Production"] {}'),
      'Quoted and unquoted duplicate tags should fail.');
    AContext.AssertEquals('NXS3006', lFailureCompiler.Diagnostics[0].Code,
      'Duplicate tags should use a stable diagnostic.');
    AContext.AssertEquals(25, lFailureCompiler.Diagnostics[0].SourceRange.
      StartPosition.Column,
      'The duplicate diagnostic should point at the repeated tag.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('nested-tags.nxscript',
      'Thing Root [Production, [Nested]] {}'),
      'Nested tag arrays should fail.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('missing-comma.nxscript',
      'Thing Root [Production Win64] {}'),
      'Missing tag separators should fail.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('trailing-comma.nxscript',
      'Thing Root [Production,] {}'),
      'Trailing tag commas should fail.');
    AContext.AssertTrue(not lFailureCompiler.CompileText('missing-bracket.nxscript',
      'Thing Root [Production {}'),
      'An unterminated tag clause should fail.');
  finally
    lValidator.Free;
    lValidatorCompiler.Free;
    lFailureCompiler.Free;
    lImportCompiler.Free;
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

function ModuleFixturePath(const AFileName: string): string;
begin
  Result := ExpandFileName(
    '..\..\..\NexusTools\Script\tests\fixtures\modules\' + AFileName);
  if not FileExists(Result) then
    Result := ExpandFileName(
      'NexusTools\Script\tests\fixtures\modules\' + AFileName);
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
      'module "module.nxscript"; doctype folder/type.nxscript; ' +
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

procedure TestLanguageSelfValidation(AContext: TNXTestContext);
var
  lSession: TNexusScriptCompilationSession;
  lValidator: TNexusScriptValidator;
begin
  lSession := TNexusScriptCompilationSession.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(
      ValidatorFixturePath('Language.nxscript')),
      'Language definition should compile: ' + lSession.LastError);
    AContext.AssertTrue(lValidator.Validate(
      lSession.EntryCompiler.CompiledDocument,
      lSession.EntryCompiler.CompiledDocument),
      'Language definition should validate itself: ' +
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
  lLanguageDocument: TNexusScriptCompiledDocument;
begin
  lSubjectSession := TNexusScriptCompilationSession.Create;
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSubjectSession.CompileFile(
      ValidatorFixturePath('Customer.Schema.nxscript')),
      'Schema subject should compile: ' + lSubjectSession.LastError);
    lSubjectDocument := lSubjectSession.EntryCompiler.CompiledDocument;
    lSchemaDocument := lSubjectDocument.DoctypeDocument;
    AContext.AssertTrue(lSchemaDocument <> nil,
      'Subject should retain its compiled Schema doctype.');
    lLanguageDocument := lSchemaDocument.DoctypeDocument;
    AContext.AssertTrue(lLanguageDocument <> nil,
      'Schema should retain its compiled Language doctype.');
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
      ValidatorFixturePath('Language.nxscript')),
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
  lValidator := TNexusScriptValidator.Create;
  try
    AContext.AssertTrue(lSession.CompileFile(ExpandFileName(
      ExtractFileDir(ManifestFixturePath('Valid.NexusManifest.nxscript')) +
      '\..\..\..\validator\NexusManifest.Language.nxscript')),
      'NexusManifest language should compile with the foundational Language definition.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
      'NexusManifest language should validate against Language.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('Valid.NexusManifest.nxscript')),
      'Manifest with auxiliary properties should compile.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
      'Manifest with root and entry auxiliary properties should validate.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingOutput.NexusManifest.nxscript')),
      'Structurally invalid manifest should still compile.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
      'Manifest missing Output should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingModel.NexusManifest.nxscript')),
      'Manifest missing Model should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
      'Manifest missing Model should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingTemplate.NexusManifest.nxscript')),
      'Manifest missing Template should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
      'Manifest missing Template should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('MissingModelSource.NexusManifest.nxscript')),
      'Manifest missing Model.Source should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
      'Manifest missing Model.Source should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('UnknownChild.NexusManifest.nxscript')),
      'Manifest with unknown child should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
      'Manifest with unknown child should fail validation.');

    AContext.AssertTrue(lSession.CompileFile(
      ManifestFixturePath('WrongModelPlacement.NexusManifest.nxscript')),
      'Manifest with nested Model should compile structurally.');
    lDocument := lSession.EntryCompiler.CompiledDocument;
    AContext.AssertTrue(not lValidator.Validate(lDocument,
      lDocument.DoctypeDocument),
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
    'Successful doctype validation should allow artifact generation.');

  lActual := ExecuteCLI(['/input=' +
    FixturePath('nexusscript\inForceMain.Schema.nxscript'), '/validate']);
  AContext.AssertTrue(Pos('"inForce"', lActual) > 0,
    'Successful compilation should validate a document without a doctype.');

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
begin
  lCompiler := TNexusScriptCompiler.Create;
  lOtherCompiler := TNexusScriptCompiler.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  lData := nil;
  try
    AContext.AssertTrue(lCompiler.CompileText('artifact.nxscript',
      'Thing Catalog { Name: DomainName; Count: 17; ' +
      'EmptyText: ""; EmptyArray: []; ' +
      'Escaped: "quote^" and newline^n"; Unicode: "caf'#233' lambda '#955'"; ' +
      'Label: @Name + "-resolved"; ' +
      'Values: [plain, Selected: named, Group: [inner, Deep: value], ' +
      'Node Row { Name: DomainRow; }]; Copy: @Values; ' +
      'GroupCopy: @Values.Group; SelectedCopy: @Values.Selected; ' +
      'Thing Child { Name: ChildDomain; } Thing Empty {} Alias: @Child; }'),
      'Generic artifact source should compile.');
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
    AContext.AssertEquals('Selected', RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lNamed, '_nx'),
      'Named scalar metadata'), 'Name').AsString,
      'Named scalar entries should expose their name through _nx.');
    AContext.AssertEquals('named',
      RequireJSONMember(lNamed, 'Value').AsString,
      'Named scalar entries should retain their value.');
    lNamed := RequireJSONObject(lValues.Items[2], 'Named array entry');
    AContext.AssertEquals('Group', RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lNamed, '_nx'),
      'Named array metadata'), 'Name').AsString,
      'Named nested arrays should expose their name through _nx.');
    lNested := RequireJSONArray(RequireJSONMember(lNamed, 'Value'),
      'Named nested array value');
    AContext.AssertEquals('inner', lNested.Items[0].AsString,
      'Nested arrays should retain order and scalar values.');
    lStructure := RequireJSONObject(lValues.Items[3],
      'Structural array entry');
    AContext.AssertEquals('Row', RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lStructure, '_nx'),
      'Structural entry metadata'), 'Name').AsString,
      'Structural array entries should use definition metadata.');
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
    AContext.AssertTrue(lCatalog.Find('Child') <> nil,
      'Direct child definitions should become named object members.');
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

procedure TestDefinitionTagJSON(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lEmitter: TNexusScriptJSONEmitter;
  lData: TJSONData;
  lCatalog: TJSONObject;
  lMetaData: TJSONObject;
  lTags: TJSONArray;
  lInline: TJSONObject;
begin
  lCompiler := TNexusScriptCompiler.Create;
  lEmitter := TNexusScriptJSONEmitter.Create;
  lData := nil;
  try
    AContext.AssertTrue(lCompiler.CompileText('tag-json.nxscript',
      'Thing Catalog [Production, "Cross Reference"] { Tags: domain; ' +
      'Thing Nested [NestedTag] {} Thing Empty {} ' +
      'Items: [Node Inline [InlineTag] {}]; Alias: @Nested; }'),
      'Tagged JSON source should compile.');
    lEmitter.AddDocument(lCompiler.CompiledDocument);
    lData := GetJSON(lEmitter.JSON);
    lCatalog := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(lData, 'Artifact root'), 'Catalog'), 'Catalog');
    lMetaData := RequireJSONObject(RequireJSONMember(lCatalog, '_nx'),
      'Catalog metadata');
    lTags := RequireJSONArray(RequireJSONMember(lMetaData, 'Tags'),
      'Catalog tags');
    AContext.AssertEquals(2, lTags.Count,
      'Tagged metadata should emit every tag.');
    AContext.AssertEquals('Production', lTags.Items[0].AsString,
      'JSON tags should retain declaration order.');
    AContext.AssertEquals('Cross Reference', lTags.Items[1].AsString,
      'JSON tags should retain decoded text.');
    AContext.AssertEquals('domain', RequireJSONMember(lCatalog,
      'Tags').AsString,
      'A domain Tags property should coexist with _nx.Tags.');
    lMetaData := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lCatalog, 'Nested'), 'Nested'),
      '_nx'), 'Nested metadata');
    AContext.AssertEquals('NestedTag', RequireJSONArray(
      RequireJSONMember(lMetaData, 'Tags'), 'Nested tags').Items[0].AsString,
      'Nested definitions should emit tags.');
    lInline := RequireJSONObject(RequireJSONArray(RequireJSONMember(lCatalog,
      'Items'), 'Items').Items[0], 'Inline definition');
    AContext.AssertEquals('InlineTag', RequireJSONArray(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lInline, '_nx'), 'Inline metadata'),
      'Tags'), 'Inline tags').Items[0].AsString,
      'Inline definitions should emit tags.');
    lMetaData := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lCatalog, 'Alias'), 'Alias'),
      '_nx'), 'Alias metadata');
    AContext.AssertEquals('NestedTag', RequireJSONArray(
      RequireJSONMember(lMetaData, 'Tags'), 'Alias tags').Items[0].AsString,
      'Structural reference projections should emit target tags.');
    lMetaData := RequireJSONObject(RequireJSONMember(
      RequireJSONObject(RequireJSONMember(lCatalog, 'Empty'), 'Empty'),
      '_nx'), 'Empty metadata');
    AContext.AssertTrue(lMetaData.Find('Tags') = nil,
      'Untagged definitions should omit _nx.Tags.');
  finally
    lData.Free;
    lEmitter.Free;
    lCompiler.Free;
  end;
end;

procedure TestExternalDataDeclarations(AContext: TNXTestContext);
var
  lCompiler: TNexusScriptCompiler;
  lSession: TNexusScriptCompilationSession;
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
  try
    AContext.AssertTrue(lSession.CompileFile(
      ExternalDataFixturePath('dependency-entry.nxscript')),
      'External dependency fixture should compile: ' + lSession.LastError);
    AContext.AssertEquals(3, lSession.ExternalSources.Count,
      'Entry, include, and module declarations should all participate.');
    AContext.AssertEquals('ENTRY_DATA', lSession.ExternalSources[0].Name,
      'Entry declarations should retain deterministic first position.');
    AContext.AssertEquals('INCLUDE_DATA', lSession.ExternalSources[1].Name,
      'Include declarations should follow entry declarations.');
    AContext.AssertEquals('MODULE_DATA', lSession.ExternalSources[2].Name,
      'Module declarations should follow include declarations.');
    AContext.AssertEquals('csv', lSession.ExternalSources[0].SourceType,
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
      ExternalDataFixturePath('doctype-entry.nxscript')),
      'A doctype dependency fixture should compile: ' + lSession.LastError);
    AContext.AssertEquals(0, lSession.ExternalSources.Count,
      'Doctype documents must not contribute model-owned data sources.');
  finally
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
  lSuite.AddTest('DefinitionTags', @TestDefinitionTags);
  lSuite.AddTest('Composition', @TestComposition);
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
  lSuite.AddTest('DoctypeParsing', @TestDoctypeParsing);
  lSuite.AddTest('DoctypeLoading', @TestDoctypeLoading);
  lSuite.AddTest('IncludeParsing', @TestIncludeParsing);
  lSuite.AddTest('IncludeLoading', @TestIncludeLoading);
  lSuite.AddTest('LanguageSelfValidation', @TestLanguageSelfValidation);
  lSuite.AddTest('SchemaValidation', @TestSchemaValidation);
  lSuite.AddTest('IndependentContainmentRules',
    @TestIndependentContainmentRules);
  lSuite.AddTest('ValidatorDiagnostics', @TestValidatorDiagnostics);
  lSuite.AddTest('ValidatorReferences', @TestValidatorReferences);
  lSuite.AddTest('InvalidLanguageDefinition', @TestInvalidLanguageDefinition);
  lSuite.AddTest('LanguageFiniteValues', @TestLanguageFiniteValues);
  lSuite.AddTest('JSONEmitter', @TestJSONEmitter);
  lSuite.AddTest('DefinitionTagJSON', @TestDefinitionTagJSON);
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
end;

end.
