unit tsNXSchemaCoreTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXSchemaCoreTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  obNXTestContext,
  obNXTestSuite,
  obMetaDataJSON,
  obMetaDataModuleList,
  obMetaDataTransformations,
  obMustacheRenderer,
  obNexusSchemaParser,
  obNexusSchemaTokenizer,
  obNexusSchemaTypes,
  obTokenQueue;

function NXSchemaRootPath: string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName('NexusTools' +
    DirectorySeparator + 'Schema'));
end;

function NXSchemaPath(const ARelativePath: string): string;
begin
  Result := NXSchemaRootPath + ARelativePath;
end;

function NXSchemaTempPath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + 'nxschema-test-' +
    IntToStr(GetTickCount64) + '-' + AName;
end;

function CreateTestSchemaFile: string;
var
  lSchema: TStringList;
begin
  Result := NXSchemaTempPath('TestSchema.nxs');
  lSchema := TStringList.Create;
  try
    lSchema.Add('module TestSchema');
    lSchema.Add('');
    lSchema.Add('TestTypes = Type {');
    lSchema.Add('  DOM_NAME : "varchar(100)"');
    lSchema.Add('}');
    lSchema.Add('');
    lSchema.Add('CUSTOMER = Table {');
    lSchema.Add('  NAME : DOM_NAME');
    lSchema.Add('}');
    lSchema.SaveToFile(Result);
  finally
    lSchema.Free;
  end;
end;

procedure TestTokenizerRecognizesCoreTokens(AContext: TNXTestContext);
var
  lQueue: TTokenQueue;
  lSource: string;
begin
  lSource := 'module Demo' + LineEnding +
    'Customer = table {' + LineEnding +
    '  Name : "varchar(100)"' + LineEnding +
    '}';

  lQueue := TokenizeNexusSchemaModule(PChar(lSource));
  try
    AContext.AssertEquals(13, lQueue.Count, 'Token count mismatch.');
    AContext.AssertEquals('module', lQueue[0].Text, 'First token text.');
    AContext.AssertTrue(lQueue[0].TokenType = ttKeyword,
      'module should be a keyword.');
    AContext.AssertEquals('Demo', lQueue[1].Text, 'Module name token.');
    AContext.AssertTrue(lQueue[1].TokenType = ttIdentifier,
      'Module name should be an identifier.');
    AContext.AssertEquals('varchar(100)', lQueue[10].Text,
      'String token content.');
    AContext.AssertTrue(lQueue[10].TokenType = ttString,
      'Field type should be a string token.');
  finally
    lQueue.Free;
  end;
end;

procedure TestParserLoadsLocalFixture(AContext: TNXTestContext);
var
  lSchemaFile: string;
  lMetaData: TMetaDataModuleList;
  lParser: TNexusSchemaParser;
begin
  lSchemaFile := CreateTestSchemaFile;
  lMetaData := TMetaDataModuleList.Create;
  lParser := TNexusSchemaParser.Create(lMetaData);
  try
    lParser.ExecuteFile(lSchemaFile);
    AContext.AssertTrue(lMetaData.Count > 0,
      'Parser should load at least one module.');
    AContext.AssertEquals('TestSchema', lMetaData[0].Name,
      'Fixture module name mismatch.');
    AContext.AssertTrue(lMetaData[0].Tables.Count > 0,
      'Fixture should define tables.');
  finally
    if FileExists(lSchemaFile) then
      DeleteFile(lSchemaFile);
    lParser.Free;
    lMetaData.Free;
  end;
end;

procedure TestMetadataJSONContainsRoot(AContext: TNXTestContext);
var
  lJSON: string;
  lSchemaFile: string;
  lMetaData: TMetaDataModuleList;
  lParser: TNexusSchemaParser;
  lTransform: TMetaDataTransform;
begin
  lSchemaFile := CreateTestSchemaFile;
  lMetaData := TMetaDataModuleList.Create;
  lParser := TNexusSchemaParser.Create(lMetaData);
  try
    lParser.ExecuteFile(lSchemaFile);
    lTransform := TMetaDataTransform.Create;
    try
      lTransform.Transform(lMetaData);
    finally
      lTransform.Free;
    end;
    lJSON := MetaDataToMustacheJSON(lMetaData);

    AContext.AssertTrue(Pos('"NexusSchema"', lJSON) > 0,
      'JSON should contain the NexusSchema root.');
    AContext.AssertTrue(Pos('"TestSchema"', lJSON) > 0,
      'JSON should contain the fixture module name.');
  finally
    if FileExists(lSchemaFile) then
      DeleteFile(lSchemaFile);
    lParser.Free;
    lMetaData.Free;
  end;
end;

procedure TestRenderFirebirdTemplate(AContext: TNXTestContext);
var
  lJSONFile: string;
  lOutputFile: string;
  lOutput: TStringList;
  lSchemaFile: string;
  lMetaData: TMetaDataModuleList;
  lParser: TNexusSchemaParser;
  lTransform: TMetaDataTransform;
begin
  lSchemaFile := CreateTestSchemaFile;
  lJSONFile := NXSchemaTempPath('TestSchema.schema.json');
  lOutputFile := NXSchemaTempPath('TestSchema.create');
  lMetaData := TMetaDataModuleList.Create;
  lParser := TNexusSchemaParser.Create(lMetaData);
  try
    lParser.ExecuteFile(lSchemaFile);
    lTransform := TMetaDataTransform.Create;
    try
      lTransform.Transform(lMetaData);
    finally
      lTransform.Free;
    end;

    SaveMetaDataMustacheJSON(lMetaData, lJSONFile);
    RenderMustacheFile(lJSONFile,
      NXSchemaPath('firebird' + DirectorySeparator +
      'DatabaseSchema.create.mustache'), lOutputFile);

    lOutput := TStringList.Create;
    try
      lOutput.LoadFromFile(lOutputFile);
      AContext.AssertTrue(Pos('create table', LowerCase(lOutput.Text)) > 0,
        'Rendered output should contain CREATE TABLE statements.');
    finally
      lOutput.Free;
    end;
  finally
    if FileExists(lSchemaFile) then
      DeleteFile(lSchemaFile);
    if FileExists(lJSONFile) then
      DeleteFile(lJSONFile);
    if FileExists(lOutputFile) then
      DeleteFile(lOutputFile);
    lParser.Free;
    lMetaData.Free;
  end;
end;

procedure RegisterNXSchemaCoreTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusSchema.Core');
  lSuite.AddTest('TokenizerRecognizesCoreTokens',
    @TestTokenizerRecognizesCoreTokens);
  lSuite.AddTest('ParserLoadsLocalFixture', @TestParserLoadsLocalFixture);
  lSuite.AddTest('MetadataJSONContainsRoot', @TestMetadataJSONContainsRoot);
  lSuite.AddTest('RenderFirebirdTemplate', @TestRenderFirebirdTemplate);
end;

end.
