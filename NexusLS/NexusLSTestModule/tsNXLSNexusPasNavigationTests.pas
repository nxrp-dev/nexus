unit tsNXLSNexusPasNavigationTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSNexusPasNavigationTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  obNXJSONValues,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXPasLookup,
  obNXPasSearchPaths,
  obNXPasSource,
  obNXPasUnitLocator,
  obNXTestContext,
  obNXTestSuite;

const
  cNavigationUnit =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TSample = class' + LineEnding +
    '  end;' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'procedure Call;' + LineEnding +
    'var' + LineEnding +
    '  Local: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  DoWork;' + LineEnding +
    'end;' + LineEnding +
    'end.';

function NXLSLineOf(const AText, ANeedle: string): Integer;
var
  lIdx: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    for lIdx := 0 to lLines.Count - 1 do
      if Pos(ANeedle, lLines[lIdx]) > 0 then
        Exit(lIdx);
  finally
    lLines.Free;
  end;
end;

function NXLSColumnOf(const AText, ALineNeedle, AColumnNeedle: string): Integer;
var
  lLine: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLine := NXLSLineOf(AText, ALineNeedle);
  if lLine < 0 then
    Exit;

  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    Result := Pos(AColumnNeedle, lLines[lLine]) - 1;
  finally
    lLines.Free;
  end;
end;

function NXLSLineOfAfter(const AText, ANeedle: string;
  AAfterLine: Integer): Integer;
var
  lIdx: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    for lIdx := AAfterLine + 1 to lLines.Count - 1 do
      if Pos(ANeedle, lLines[lIdx]) > 0 then
        Exit(lIdx);
  finally
    lLines.Free;
  end;
end;

procedure NXLSOpenDocument(AModel: TNXLSLSPModel; const AURI,
  AText: string);
var
  lItem: TNXLSTextDocumentItem;
begin
  lItem := TNXLSTextDocumentItem.Create;
  try
    lItem.uri.Value := AURI;
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value := AText;
    AModel.ReindexDocument(AModel.OpenDocument(lItem));
  finally
    lItem.Free;
  end;
end;

procedure NXLSSetTextPosition(AParams: TNXLSTextDocumentPositionParams;
  const AURI, AText, ALineNeedle, AColumnNeedle: string);
begin
  AParams.textDocument.uri.Value := AURI;
  AParams.position.line.Value := NXLSLineOf(AText, ALineNeedle);
  AParams.position.character.Value := NXLSColumnOf(AText, ALineNeedle,
    AColumnNeedle);
end;

function NXLSHasReferenceOnLine(AResult: TNXLSLocationArray;
  ALine: Integer): Boolean;
var
  lIdx: Integer;
  lLocation: TNXLSLocation;
begin
  Result := False;
  if AResult = nil then
    Exit;

  for lIdx := 0 to AResult.Count - 1 do
  begin
    lLocation := TNXLSLocation(AResult[lIdx]);
    if lLocation.range.start.line.Value = ALine then
      Exit(True);
  end;
end;

function NXLSCreateUniqueTempDir(const APrefix: string): string;
var
  lTempFile: string;
begin
  lTempFile := GetTempFileName('', APrefix);
  if FileExists(lTempFile) then
    DeleteFile(lTempFile);

  Result := lTempFile + '_dir';
  ForceDirectories(Result);
end;

procedure NXLSWriteTextFile(const AFileName, AText: string);
var
  lText: TStringList;
begin
  ForceDirectories(ExtractFileDir(AFileName));
  lText := TStringList.Create;
  try
    lText.Text := AText;
    lText.SaveToFile(AFileName);
  finally
    lText.Free;
  end;
end;

procedure TestIdentifierAtPosition(AContext: TNXTestContext);
var
  lName: string;
  lRange: TNXPasSourceRange;
  lSource: TNXPasSourceFile;
begin
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', cNavigationUnit);
  try
    AContext.AssertTrue(TNXPasLookup.IdentifierAtPosition(lSource,
      NXLSLineOf(cNavigationUnit, 'Local: TSample'),
      NXLSColumnOf(cNavigationUnit, 'Local: TSample', 'TSample') + 2, lName,
      lRange), 'Identifier lookup should find the identifier under cursor.');
    AContext.AssertEquals('TSample', lName,
      'Identifier lookup should return the expected token text.');
    AContext.AssertEquals(NXLSColumnOf(cNavigationUnit, 'Local: TSample',
      'TSample'), lRange.StartPos.Column,
      'Identifier range should start at the token column.');
    AContext.AssertFalse(TNXPasLookup.IdentifierAtPosition(lSource,
      NXLSLineOf(cNavigationUnit, 'Local: TSample'),
      NXLSColumnOf(cNavigationUnit, 'Local: TSample', ':') + 1, lName,
      lRange), 'Identifier lookup should not return whitespace or punctuation.');
  finally
    lSource.Free;
  end;
end;

procedure TestDefinitionFindsClassInCurrentDocument(AContext: TNXTestContext);
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit, 'Local: TSample', 'TSample');

    AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Definition should resolve a simple class/type name.');
    AContext.AssertEquals('file:///C:/workspace/Sample.pas',
      lLocation.uri.Value, 'Definition should resolve in the current document.');
    AContext.AssertEquals(3, lLocation.range.start.line.Value,
      'Definition should point to the class declaration line.');
    AContext.AssertEquals(2, lLocation.range.start.character.Value,
      'Definition should point to the class identifier column.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDefinitionFindsRoutineInCurrentDocument(AContext: TNXTestContext);
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit, 'DoWork;', 'DoWork');

    AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Definition should resolve a simple routine name.');
    AContext.AssertEquals(5, lLocation.range.start.line.Value,
      'Definition should point to the routine declaration line.');
    AContext.AssertEquals(10, lLocation.range.start.character.Value,
      'Definition should point to the routine identifier column.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDefinitionFindsSymbolAcrossIndexedDocuments(
  AContext: TNXTestContext);
const
  cUnitA =
    'unit UnitA;' + LineEnding +
    'interface' + LineEnding +
    'type TShared = class end;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
  cUnitB =
    'unit UnitB;' + LineEnding +
    'interface' + LineEnding +
    'uses UnitA;' + LineEnding +
    'var Shared: TShared;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/UnitA.pas', cUnitA);
    NXLSOpenDocument(lModel, 'file:///C:/workspace/UnitB.pas', cUnitB);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/UnitB.pas', cUnitB,
      'Shared: TShared', 'TShared');

    AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Definition should resolve across indexed documents.');
    AContext.AssertEquals('file:///C:/workspace/UnitA.pas',
      lLocation.uri.Value, 'Definition should point to the declaring document.');
    AContext.AssertEquals(2, lLocation.range.start.line.Value,
      'Definition should point to the declaration line in UnitA.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDefinitionFindsUnopenedUsesUnitName(AContext: TNXTestContext);
const
  cTargetUnit =
    'unit UsedPlatformUnit;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'end.';
  cConsumerUnit =
    'unit UsedConsumerUnit;' + LineEnding +
    'interface' + LineEnding +
    'uses UsedPlatformUnit;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lConsumerFile: string;
  lConsumerURI: string;
  lExpectedURI: string;
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
  lRoot: string;
  lTargetFile: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lTargetFile := IncludeTrailingPathDelimiter(lRoot) + 'UsedPlatformUnit.pas';
  lConsumerFile := IncludeTrailingPathDelimiter(lRoot) + 'UsedConsumerUnit.pas';
  NXLSWriteTextFile(lTargetFile, cTargetUnit);

  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    lModel.PascalSearchPathContext.AddRawPath(lRoot, 'test', pspkUnitPath);
    lConsumerURI := TNXPasUnitLocator.PathToFileURI(lConsumerFile);
    NXLSOpenDocument(lModel, lConsumerURI, cConsumerUnit);
    NXLSSetTextPosition(lParams, lConsumerURI, cConsumerUnit,
      'uses UsedPlatformUnit', 'UsedPlatformUnit');

    AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Definition should resolve unopened uses-unit names through search paths.');
    lExpectedURI := TNXPasUnitLocator.PathToFileURI(lTargetFile);
    AContext.AssertEquals(lExpectedURI, lLocation.uri.Value,
      'Uses-unit definition should point to the resolved unit file.');
    AContext.AssertEquals(0, lLocation.range.start.line.Value,
      'Uses-unit definition should point to the unit header.');
    AContext.AssertEquals(5, lLocation.range.start.character.Value,
      'Uses-unit definition should point to the unit identifier.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
    if FileExists(lTargetFile) then
      DeleteFile(lTargetFile);
    if FileExists(lConsumerFile) then
      DeleteFile(lConsumerFile);
    if DirectoryExists(lRoot) then
      RemoveDir(lRoot);
  end;
end;

procedure TestDefinitionFindsSystemUnitAfterInitializeAndDidOpen(
  AContext: TNXTestContext);
const
  cSysUtilsUnit =
    'unit SysUtils;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'end.';
  cConsumerUnit =
    'unit Consumer;' + LineEnding +
    'interface' + LineEnding +
    'uses SysUtils;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lConsumerFile: string;
  lConsumerURI: string;
  lExpectedURI: string;
  lFPCDir: string;
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lOptions: TJSONObject;
  lOptionsJSON: TJSONData;
  lParams: TNXLSTextDocumentPositionParams;
  lRoot: string;
  lRootJSON: TJSONData;
  lInitializeParams: TNXLSInitializeParams;
  lSysUtilsFile: string;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  lFPCDir := IncludeTrailingPathDelimiter(lRoot) + 'fpc';
  lSysUtilsFile := IncludeTrailingPathDelimiter(lFPCDir) +
    'source' + DirectorySeparator + 'rtl' + DirectorySeparator + 'win' +
    DirectorySeparator + 'SysUtils.pp';
  lConsumerFile := IncludeTrailingPathDelimiter(lRoot) + 'Consumer.pas';
  NXLSWriteTextFile(lSysUtilsFile, cSysUtilsUnit);

  lModel := TNXLSLSPModel.Create;
  lInitializeParams := TNXLSInitializeParams.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    lRootJSON := TJSONString.Create(TNXPasUnitLocator.PathToFileURI(lRoot));
    try
      lInitializeParams.rootUri.FromJSONData(lRootJSON);
    finally
      lRootJSON.Free;
    end;

    lOptions := TJSONObject.Create;
    try
      lOptions.Add('fpcDir', lFPCDir);
      lOptionsJSON := lOptions;
      lInitializeParams.initializationOptions.FromJSONData(lOptionsJSON);
    finally
      lOptions.Free;
    end;

    lModel.BeginInitialize(lInitializeParams);
    lConsumerURI := TNXPasUnitLocator.PathToFileURI(lConsumerFile);
    NXLSOpenDocument(lModel, lConsumerURI, cConsumerUnit);
    NXLSSetTextPosition(lParams, lConsumerURI, cConsumerUnit,
      'uses SysUtils', 'SysUtils');

    AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Definition should resolve system units after initialize and didOpen.');
    lExpectedURI := TNXPasUnitLocator.PathToFileURI(lSysUtilsFile);
    AContext.AssertEquals(lExpectedURI, lLocation.uri.Value,
      'System-unit definition should point to the FPC source file.');
    AContext.AssertEquals(0, lLocation.range.start.line.Value,
      'System-unit definition should point to the unit header.');
    AContext.AssertEquals(5, lLocation.range.start.character.Value,
      'System-unit definition should point to the unit identifier.');
  finally
    lLocation.Free;
    lParams.Free;
    lInitializeParams.Free;
    lModel.Free;
    if FileExists(lSysUtilsFile) then
      DeleteFile(lSysUtilsFile);
    if FileExists(lConsumerFile) then
      DeleteFile(lConsumerFile);
    RemoveDir(ExtractFileDir(lSysUtilsFile));
    RemoveDir(ExtractFileDir(ExtractFileDir(lSysUtilsFile)));
    RemoveDir(ExtractFileDir(ExtractFileDir(ExtractFileDir(lSysUtilsFile))));
    RemoveDir(lFPCDir);
    RemoveDir(lRoot);
  end;
end;

procedure TestDefinitionReturnsEmptyForUnknownIdentifier(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'var Value: TMissing;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value: TMissing', 'TMissing');

    AContext.AssertFalse(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Unknown identifiers should not produce a definition location.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionFindsTypeIdentifier(AContext: TNXTestContext);
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit, 'Local: TSample', 'TSample');

    AContext.AssertTrue(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Type definition should resolve a type identifier.');
    AContext.AssertEquals(3, lLocation.range.start.line.Value,
      'Type definition should point to the type declaration line.');
    AContext.AssertEquals(2, lLocation.range.start.character.Value,
      'Type definition should point to the type identifier column.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionReturnsEmptyForRoutineWithoutReturnType(
  AContext: TNXTestContext);
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit, 'DoWork;', 'DoWork');

    AContext.AssertFalse(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Routine without declared return type should not resolve type definition.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionUsesVariableDeclaredType(AContext: TNXTestContext);
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit, 'Local: TSample', 'Local');

    AContext.AssertTrue(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Type definition should use variable declared type.');
    AContext.AssertEquals(3, lLocation.range.start.line.Value,
      'Type definition should point to the declared type symbol.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionUsesFieldDeclaredType(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TSample = class end;' + LineEnding +
    '  THolder = class' + LineEnding +
    '  private' + LineEnding +
    '    FItem: TSample;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'FItem: TSample', 'FItem');

    AContext.AssertTrue(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Type definition should use field declared type.');
    AContext.AssertEquals(3, lLocation.range.start.line.Value,
      'Type definition should point to the declared field type symbol.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionUsesParameterDeclaredType(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'procedure DoWork(AItem: TSample);' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'AItem: TSample', 'AItem');

    AContext.AssertTrue(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Type definition should use parameter declared type.');
    AContext.AssertEquals(2, lLocation.range.start.line.Value,
      'Type definition should point to the declared parameter type symbol.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionUnknownDeclaredTypeReturnsEmpty(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'var Value: TMissing;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'Value: TMissing', 'Value');

    AContext.AssertFalse(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Unknown declared types should not produce a location.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionPrefersCurrentRoutineLocal(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFirst = class end;' + LineEnding +
    '  TSecond = class end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure First;' + LineEnding +
    'var' + LineEnding +
    '  Local: TFirst;' + LineEnding +
    'begin' + LineEnding +
    '  Local;' + LineEnding +
    'end;' + LineEnding +
    'procedure Second;' + LineEnding +
    'var' + LineEnding +
    '  Local: TSecond;' + LineEnding +
    'begin' + LineEnding +
    '  Local; // second' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      '  Local; // second', 'Local');

    AContext.AssertTrue(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation),
      'Type definition should use the local visible in the current routine.');
    AContext.AssertEquals(4, lLocation.range.start.line.Value,
      'Type definition should point to the second local declared type.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionIgnoresInactiveDeclaration(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'type THidden = class end;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'var Value: THidden;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value: THidden', 'THidden');

    AContext.AssertFalse(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Inactive type declarations should not be returned.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestInactiveDeclarationIsNotDefinition(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'type THidden = class end;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'var Value: THidden;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value: THidden', 'THidden');

    AContext.AssertFalse(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Inactive declarations should not be returned as definitions.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestReferencesFindActiveOccurrences(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSReferenceParams;
  lResult: TNXLSLocationArray;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSReferenceParams.Create;
  lResult := TNXLSLocationArray.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit, 'Local: TSample', 'TSample');
    lParams.context.includeDeclaration.Value := True;

    lModel.Navigation.FillReferences(lParams, lResult);

    AContext.AssertTrue(lResult.Count >= 2,
      'References should include declaration and active usage.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 3),
      'References should include the declaration line.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 9),
      'References should include the active usage line.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestReferencesExcludeCommentsStringsAndInactiveRegions(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    '// TSample in comment' + LineEnding +
    'const Text = ''TSample in string'';' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'var Hidden: TSample;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'var Visible: TSample;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSReferenceParams;
  lResult: TNXLSLocationArray;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSReferenceParams.Create;
  lResult := TNXLSLocationArray.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Visible: TSample', 'TSample');
    lParams.context.includeDeclaration.Value := True;

    lModel.Navigation.FillReferences(lParams, lResult);

    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 2),
      'References should include the active declaration.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 8),
      'References should include active usage.');
    AContext.AssertFalse(NXLSHasReferenceOnLine(lResult, 3),
      'References should not include comments.');
    AContext.AssertFalse(NXLSHasReferenceOnLine(lResult, 4),
      'References should not include strings.');
    AContext.AssertFalse(NXLSHasReferenceOnLine(lResult, 6),
      'References should not include inactive regions.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestReferencesExcludeDeclarationIdentifierOnly(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TSample = class' + LineEnding +
    '  private' + LineEnding +
    '    FValue: TSample;' + LineEnding +
    '  public' + LineEnding +
    '    property Value: TSample read FValue;' + LineEnding +
    '    procedure Run(AValue: TSample);' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  Item: TSample;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSReferenceParams;
  lResult: TNXLSLocationArray;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSReferenceParams.Create;
  lResult := TNXLSLocationArray.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Item: TSample', 'TSample');
    lParams.context.includeDeclaration.Value := False;

    lModel.Navigation.FillReferences(lParams, lResult);

    AContext.AssertFalse(NXLSHasReferenceOnLine(lResult, 3),
      'includeDeclaration=false should exclude the declaration identifier.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 5),
      'Field type references inside the class body should remain references.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 7),
      'Property type references inside the class body should remain references.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 8),
      'Parameter type references inside the class body should remain references.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 11),
      'Variable type references should remain references.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestReferencesRemainLexicalForSameNameLocals(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure First;' + LineEnding +
    'var' + LineEnding +
    '  Local: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Local;' + LineEnding +
    'end;' + LineEnding +
    'procedure Second;' + LineEnding +
    'var' + LineEnding +
    '  Local: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Local; // second' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSReferenceParams;
  lResult: TNXLSLocationArray;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSReferenceParams.Create;
  lResult := TNXLSLocationArray.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      '  Local;', 'Local');
    lParams.context.includeDeclaration.Value := True;

    lModel.Navigation.FillReferences(lParams, lResult);

    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 5),
      'Lexical references include the first local declaration.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 11),
      'Lexical references still include same-name locals in other routines.');
    AContext.AssertTrue(NXLSHasReferenceOnLine(lResult, 13),
      'Lexical references still include same-name usages in other routines.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDefinitionFindsDirectDeclaredTypeMember(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TSample = class' + LineEnding +
    '  public' + LineEnding +
    '    FCount: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'var Value: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  Value.FCount := 1;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value.FCount', 'FCount');

    AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Definition should resolve a direct declared-type member.');
    AContext.AssertEquals(5, lLocation.range.start.line.Value,
      'Definition should point to the member declaration.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDefinitionUnknownMemberReturnsEmpty(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    'var Value: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  Value.Missing;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value.Missing', 'Missing');

    AContext.AssertFalse(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Unknown direct members should not resolve.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDefinitionUnknownReceiverReturnsEmpty(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  Missing.FCount;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Missing.FCount', 'FCount');

    AContext.AssertFalse(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Unknown receivers should not resolve member definitions.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestMemberDefinitionDoesNotFallbackToGlobal(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'var Missing: Integer;' + LineEnding +
    'implementation' + LineEnding +
    'var Value: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  Value.Missing;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value.Missing', 'Missing');

    AContext.AssertFalse(lModel.Navigation.FillDefinition(lParams, lLocation),
      'Member lookup should not fall back to an unrelated global symbol.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionUsesDirectMemberDeclaredType(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TInner = class end;' + LineEnding +
    '  TSample = class' + LineEnding +
    '  public' + LineEnding +
    '    Item: TInner;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'var Value: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  Value.Item;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value.Item', 'Item');

    AContext.AssertTrue(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Type definition should use direct member declared type.');
    AContext.AssertEquals(3, lLocation.range.start.line.Value,
      'Type definition should point to the member declared type symbol.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestTypeDefinitionPrimitiveMemberTypeReturnsEmpty(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TSample = class' + LineEnding +
    '  public' + LineEnding +
    '    Count: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'var Value: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  Value.Count;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value.Count', 'Count');

    AContext.AssertFalse(lModel.Navigation.FillTypeDefinition(lParams,
      lLocation), 'Primitive/unresolved member types should not fake locations.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDeclarationFindsClassInCurrentDocument(AContext: TNXTestContext);
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cNavigationUnit, 'Local: TSample', 'TSample');

    AContext.AssertTrue(lModel.Navigation.FillDeclaration(lParams, lLocation),
      'Declaration should resolve a simple class/type name.');
    AContext.AssertEquals(3, lLocation.range.start.line.Value,
      'Declaration should point to the class declaration line.');
    AContext.AssertEquals(2, lLocation.range.start.character.Value,
      'Declaration should point to the class identifier column.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDeclarationReturnsEmptyForUnknownIdentifier(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'var Value: TMissing;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value: TMissing', 'TMissing');

    AContext.AssertFalse(lModel.Navigation.FillDeclaration(lParams, lLocation),
      'Unknown identifiers should not produce a declaration location.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDeclarationIgnoresInactiveDeclaration(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'type THidden = class end;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'var Value: THidden;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'Value: THidden', 'THidden');

    AContext.AssertFalse(lModel.Navigation.FillDeclaration(lParams, lLocation),
      'Inactive declarations should not be returned as declarations.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestImplementationFindsRoutineBody(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lImplementationLine: Integer;
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'procedure DoWork;', 'DoWork');
    lImplementationLine := NXLSLineOfAfter(cSource, 'procedure DoWork;',
      lParams.position.line.Value);

    AContext.AssertTrue(lModel.Navigation.FillImplementationLocation(lParams,
      lLocation), 'Implementation should resolve a simple routine body.');
    AContext.AssertEquals(lImplementationLine, lLocation.range.start.line.Value,
      'Implementation should point to the implementation routine line.');
    AContext.AssertEquals(10, lLocation.range.start.character.Value,
      'Implementation should point to the routine identifier column.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDeclarationFindsRoutineInterfaceDeclaration(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lImplementationLine: Integer;
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    lImplementationLine := NXLSLineOfAfter(cSource, 'procedure DoWork;',
      NXLSLineOf(cSource, 'procedure DoWork;'));
    lParams.textDocument.uri.Value := 'file:///C:/workspace/Sample.pas';
    lParams.position.line.Value := lImplementationLine;
    lParams.position.character.Value := 10;

    AContext.AssertTrue(lModel.Navigation.FillDeclaration(lParams, lLocation),
      'Declaration should resolve from an implementation routine to interface.');
    AContext.AssertEquals(2, lLocation.range.start.line.Value,
      'Declaration should point to the interface routine declaration.');
    AContext.AssertEquals(10, lLocation.range.start.character.Value,
      'Declaration should point to the routine identifier column.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestImplementationFindsClassMethodBodyByOwner(
  AContext: TNXTestContext);
const
  cSource =
    'unit NavOwner;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFoo = class' + LineEnding +
    '    procedure Run(AValue: Integer);' + LineEnding +
    '  end;' + LineEnding +
    '  TBar = class' + LineEnding +
    '    procedure Run(AValue: Integer);' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TBar.Run(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TFoo.Run(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/NavOwner.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/NavOwner.pas',
      cSource, '    procedure Run(AValue: Integer);', 'Run');

    AContext.AssertTrue(lModel.Navigation.FillImplementationLocation(lParams,
      lLocation), 'Implementation should resolve a class method by owner.');
    AContext.AssertEquals(NXLSLineOf(cSource,
      'procedure TFoo.Run(AValue: Integer);'),
      lLocation.range.start.line.Value,
      'Implementation should point to the matching owner method.');
    AContext.AssertEquals(NXLSColumnOf(cSource,
      'procedure TFoo.Run(AValue: Integer);', 'Run'),
      lLocation.range.start.character.Value,
      'Implementation should point to the simple routine identifier.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestImplementationFindsMethodAfterForwardClassDeclaration(
  AContext: TNXTestContext);
const
  cSource =
    'unit NavForwardClass;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBar = class;' + LineEnding +
    '  TFoo = class;' + LineEnding +
    '  TFoo = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run(AValue: TBar); virtual;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TFoo.Run(AValue: TBar);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/NavForwardClass.pas',
      cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/NavForwardClass.pas',
      cSource, '    procedure Run(AValue: TBar);', 'Run');

    AContext.AssertTrue(lModel.Navigation.FillImplementationLocation(lParams,
      lLocation),
      'Implementation should resolve methods after forward class declarations.');
    AContext.AssertEquals(NXLSLineOf(cSource,
      'procedure TFoo.Run(AValue: TBar);'), lLocation.range.start.line.Value,
      'Implementation should point to the qualified implementation.');
    AContext.AssertEquals(NXLSColumnOf(cSource,
      'procedure TFoo.Run(AValue: TBar);', 'Run'),
      lLocation.range.start.character.Value,
      'Implementation should point to the simple routine identifier.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDeclarationFindsMethodAfterForwardClassDeclaration(
  AContext: TNXTestContext);
const
  cSource =
    'unit NavForwardClass;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TBar = class;' + LineEnding +
    '  TFoo = class;' + LineEnding +
    '  TFoo = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run(AValue: TBar); virtual;' + LineEnding +
    '  end;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TFoo.Run(AValue: TBar);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/NavForwardClass.pas',
      cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/NavForwardClass.pas',
      cSource, 'procedure TFoo.Run(AValue: TBar);', 'Run');

    AContext.AssertTrue(lModel.Navigation.FillDeclaration(lParams, lLocation),
      'Declaration should resolve methods after forward class declarations.');
    AContext.AssertEquals(NXLSLineOf(cSource,
      '    procedure Run(AValue: TBar);'), lLocation.range.start.line.Value,
      'Declaration should point to the class-body method declaration.');
    AContext.AssertEquals(NXLSColumnOf(cSource,
      '    procedure Run(AValue: TBar);', 'Run'),
      lLocation.range.start.character.Value,
      'Declaration should point to the simple routine identifier.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestImplementationFindsOverloadByParameterType(
  AContext: TNXTestContext);
const
  cSource =
    'unit NavOverload;' + LineEnding +
    'interface' + LineEnding +
    'procedure Run(AValue: Integer);' + LineEnding +
    'procedure Run(AValue: string);' + LineEnding +
    'procedure Run(AValue: Boolean);' + LineEnding +
    'implementation' + LineEnding +
    'procedure Run(AValue: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Run(AValue: Boolean);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Run(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lImplementationStart: Integer;
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/NavOverload.pas',
      cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/NavOverload.pas',
      cSource, 'procedure Run(AValue: Integer);', 'Run');
    lImplementationStart := NXLSLineOf(cSource, 'implementation');

    AContext.AssertTrue(lModel.Navigation.FillImplementationLocation(lParams,
      lLocation), 'Implementation should resolve an overload by parameter type.');
    AContext.AssertEquals(NXLSLineOfAfter(cSource,
      'procedure Run(AValue: Integer);', lImplementationStart),
      lLocation.range.start.line.Value,
      'Implementation should point to the Integer overload.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDeclarationFindsOverloadByParameterType(
  AContext: TNXTestContext);
const
  cSource =
    'unit NavOverload;' + LineEnding +
    'interface' + LineEnding +
    'procedure Run(AValue: Integer);' + LineEnding +
    'procedure Run(AValue: string);' + LineEnding +
    'procedure Run(AValue: Boolean);' + LineEnding +
    'implementation' + LineEnding +
    'procedure Run(AValue: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Run(AValue: Boolean);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Run(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lImplementationStart: Integer;
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/NavOverload.pas',
      cSource);
    lImplementationStart := NXLSLineOf(cSource, 'implementation');
    lParams.textDocument.uri.Value := 'file:///C:/workspace/NavOverload.pas';
    lParams.position.line.Value := NXLSLineOfAfter(cSource,
      'procedure Run(AValue: Boolean);', lImplementationStart);
    lParams.position.character.Value := 10;

    AContext.AssertTrue(lModel.Navigation.FillDeclaration(lParams, lLocation),
      'Declaration should resolve an overload by parameter type.');
    AContext.AssertEquals(NXLSLineOf(cSource,
      'procedure Run(AValue: Boolean);'), lLocation.range.start.line.Value,
      'Declaration should point to the Boolean overload.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestImplementationDoesNotFallbackToDifferentOverload(
  AContext: TNXTestContext);
const
  cSource =
    'unit NavNoFallback;' + LineEnding +
    'interface' + LineEnding +
    'procedure Run(AValue: Integer);' + LineEnding +
    'implementation' + LineEnding +
    'procedure Run(AValue: string);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/NavNoFallback.pas',
      cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/NavNoFallback.pas',
      cSource, 'procedure Run(AValue: Integer);', 'Run');

    AContext.AssertFalse(lModel.Navigation.FillImplementationLocation(lParams,
      lLocation), 'Implementation must not fall back to a different overload.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestInactiveRoutineImplementationIsIgnored(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure Hidden;' + LineEnding +
    'implementation' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'procedure Hidden;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'end.';
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lLocation := TNXLSLocation.Create;
  try
    NXLSOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXLSSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas', cSource,
      'procedure Hidden;', 'Hidden');

    AContext.AssertFalse(lModel.Navigation.FillImplementationLocation(lParams,
      lLocation), 'Inactive routine implementations should not be returned.');
  finally
    lLocation.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure RegisterNXLSNexusPasNavigationTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.NexusPasNavigation');
  lSuite.AddTest('IdentifierAtPosition', @TestIdentifierAtPosition);
  lSuite.AddTest('DefinitionFindsClassInCurrentDocument',
    @TestDefinitionFindsClassInCurrentDocument);
  lSuite.AddTest('DefinitionFindsRoutineInCurrentDocument',
    @TestDefinitionFindsRoutineInCurrentDocument);
  lSuite.AddTest('DefinitionFindsSymbolAcrossIndexedDocuments',
    @TestDefinitionFindsSymbolAcrossIndexedDocuments);
  lSuite.AddTest('DefinitionFindsUnopenedUsesUnitName',
    @TestDefinitionFindsUnopenedUsesUnitName);
  lSuite.AddTest('DefinitionFindsSystemUnitAfterInitializeAndDidOpen',
    @TestDefinitionFindsSystemUnitAfterInitializeAndDidOpen);
  lSuite.AddTest('DefinitionReturnsEmptyForUnknownIdentifier',
    @TestDefinitionReturnsEmptyForUnknownIdentifier);
  lSuite.AddTest('TypeDefinitionFindsTypeIdentifier',
    @TestTypeDefinitionFindsTypeIdentifier);
  lSuite.AddTest('TypeDefinitionReturnsEmptyForRoutineWithoutReturnType',
    @TestTypeDefinitionReturnsEmptyForRoutineWithoutReturnType);
  lSuite.AddTest('TypeDefinitionUsesVariableDeclaredType',
    @TestTypeDefinitionUsesVariableDeclaredType);
  lSuite.AddTest('TypeDefinitionUsesFieldDeclaredType',
    @TestTypeDefinitionUsesFieldDeclaredType);
  lSuite.AddTest('TypeDefinitionUsesParameterDeclaredType',
    @TestTypeDefinitionUsesParameterDeclaredType);
  lSuite.AddTest('TypeDefinitionUnknownDeclaredTypeReturnsEmpty',
    @TestTypeDefinitionUnknownDeclaredTypeReturnsEmpty);
  lSuite.AddTest('TypeDefinitionPrefersCurrentRoutineLocal',
    @TestTypeDefinitionPrefersCurrentRoutineLocal);
  lSuite.AddTest('TypeDefinitionIgnoresInactiveDeclaration',
    @TestTypeDefinitionIgnoresInactiveDeclaration);
  lSuite.AddTest('InactiveDeclarationIsNotDefinition',
    @TestInactiveDeclarationIsNotDefinition);
  lSuite.AddTest('ReferencesFindActiveOccurrences',
    @TestReferencesFindActiveOccurrences);
  lSuite.AddTest('ReferencesExcludeCommentsStringsAndInactiveRegions',
    @TestReferencesExcludeCommentsStringsAndInactiveRegions);
  lSuite.AddTest('ReferencesExcludeDeclarationIdentifierOnly',
    @TestReferencesExcludeDeclarationIdentifierOnly);
  lSuite.AddTest('ReferencesRemainLexicalForSameNameLocals',
    @TestReferencesRemainLexicalForSameNameLocals);
  lSuite.AddTest('DefinitionFindsDirectDeclaredTypeMember',
    @TestDefinitionFindsDirectDeclaredTypeMember);
  lSuite.AddTest('DefinitionUnknownMemberReturnsEmpty',
    @TestDefinitionUnknownMemberReturnsEmpty);
  lSuite.AddTest('DefinitionUnknownReceiverReturnsEmpty',
    @TestDefinitionUnknownReceiverReturnsEmpty);
  lSuite.AddTest('MemberDefinitionDoesNotFallbackToGlobal',
    @TestMemberDefinitionDoesNotFallbackToGlobal);
  lSuite.AddTest('TypeDefinitionUsesDirectMemberDeclaredType',
    @TestTypeDefinitionUsesDirectMemberDeclaredType);
  lSuite.AddTest('TypeDefinitionPrimitiveMemberTypeReturnsEmpty',
    @TestTypeDefinitionPrimitiveMemberTypeReturnsEmpty);
  lSuite.AddTest('DeclarationFindsClassInCurrentDocument',
    @TestDeclarationFindsClassInCurrentDocument);
  lSuite.AddTest('DeclarationReturnsEmptyForUnknownIdentifier',
    @TestDeclarationReturnsEmptyForUnknownIdentifier);
  lSuite.AddTest('DeclarationIgnoresInactiveDeclaration',
    @TestDeclarationIgnoresInactiveDeclaration);
  lSuite.AddTest('ImplementationFindsRoutineBody',
    @TestImplementationFindsRoutineBody);
  lSuite.AddTest('DeclarationFindsRoutineInterfaceDeclaration',
    @TestDeclarationFindsRoutineInterfaceDeclaration);
  lSuite.AddTest('ImplementationFindsClassMethodBodyByOwner',
    @TestImplementationFindsClassMethodBodyByOwner);
  lSuite.AddTest('ImplementationFindsMethodAfterForwardClassDeclaration',
    @TestImplementationFindsMethodAfterForwardClassDeclaration);
  lSuite.AddTest('DeclarationFindsMethodAfterForwardClassDeclaration',
    @TestDeclarationFindsMethodAfterForwardClassDeclaration);
  lSuite.AddTest('ImplementationFindsOverloadByParameterType',
    @TestImplementationFindsOverloadByParameterType);
  lSuite.AddTest('DeclarationFindsOverloadByParameterType',
    @TestDeclarationFindsOverloadByParameterType);
  lSuite.AddTest('ImplementationDoesNotFallbackToDifferentOverload',
    @TestImplementationDoesNotFallbackToDifferentOverload);
  lSuite.AddTest('InactiveRoutineImplementationIsIgnored',
    @TestInactiveRoutineImplementationIsIgnored);
end;

end.
