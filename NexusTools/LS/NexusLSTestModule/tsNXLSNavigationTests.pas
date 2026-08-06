unit tsNXLSNavigationTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSNavigationTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  fpjson,
  obNXJSONValues,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXTestContext,
  obNXTestSuite;

const
  cNavigationUnit =
    'unit NavigationUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TTargetType = class' + LineEnding +
    '  end;' + LineEnding +
    '  TConsumer = class' + LineEnding +
    '  private' + LineEnding +
    '    FItem: TTargetType;' + LineEnding +
    '  public' + LineEnding +
    '    property Item: TTargetType read FItem;' + LineEnding +
    '    procedure Accept(AValue: TTargetType);' + LineEnding +
    '    function CreateItem: TTargetType;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TargetProc;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TConsumer.Accept(AValue: TTargetType);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'function TConsumer.CreateItem: TTargetType;' + LineEnding +
    'begin' + LineEnding +
    '  Result := nil;' + LineEnding +
    'end;' + LineEnding +
    'procedure TargetProc;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Caller;' + LineEnding +
    'begin' + LineEnding +
    '  TargetProc;' + LineEnding +
    'end;' + LineEnding +
    'end.';

  cUsedPlatformUnit =
    'unit UsedPlatformUnit;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TUsedRect = record' + LineEnding +
    '    X: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'function MakeUsedRect(AX: Integer): TUsedRect;' + LineEnding +
    'implementation' + LineEnding +
    'function MakeUsedRect(AX: Integer): TUsedRect;' + LineEnding +
    'begin' + LineEnding +
    '  Result.X := AX;' + LineEnding +
    'end;' + LineEnding +
    'end.';

  cUsedConsumerUnit =
    'unit UsedConsumerUnit;' + LineEnding +
    'interface' + LineEnding +
    'uses' + LineEnding +
    '  UsedPlatformUnit;' + LineEnding +
    'implementation' + LineEnding +
    'procedure Caller;' + LineEnding +
    'var' + LineEnding +
    '  LRect: TUsedRect;' + LineEnding +
    'begin' + LineEnding +
    '  LRect := MakeUsedRect(1);' + LineEnding +
    'end;' + LineEnding +
    'end.';

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
  lFile: TextFile;
begin
  AssignFile(lFile, AFileName);
  Rewrite(lFile);
  try
    Write(lFile, AText);
  finally
    CloseFile(lFile);
  end;
end;

procedure NXLSSetJSONValue(AValue: TNXJSONValue; AData: TJSONData);
begin
  try
    AValue.FromJSONData(AData);
  finally
    AData.Free;
  end;
end;

procedure NXLSCreateNavigationModel(const AText: string; out AModel: TNXLSLSPModel;
  out AFileName: string; out AURI: string);
var
  lRoot: string;
  lParams: TNXLSInitializeParams;
  lItem: TNXLSTextDocumentItem;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  AFileName := IncludeTrailingPathDelimiter(lRoot) + 'NavigationUnit.pas';
  NXLSWriteTextFile(AFileName, AText);
  AURI := NXLSPathToFileURI(AFileName);

  AModel := TNXLSLSPModel.Create;
  TNXLSLSPModel.SetCurrent(AModel);
  try
    lParams := TNXLSInitializeParams.Create;
    try
      NXLSSetJSONValue(lParams.rootPath, TJSONString.Create(lRoot));
      AModel.BeginInitialize(lParams);
    finally
      lParams.Free;
    end;

    lItem := TNXLSTextDocumentItem.Create;
    try
      lItem.uri.Value := AURI;
      lItem.languageId.Value := 'pascal';
      lItem.version.Value := 1;
      lItem.text.Value := AText;
      AModel.OpenDocument(lItem);
    finally
      lItem.Free;
    end;
  except
    AModel.Free;
    AModel := nil;
    raise;
  end;
end;

procedure NXLSCreateNavigationModelWithUsedUnit(out AModel: TNXLSLSPModel;
  out AFileName: string; out AURI: string);
var
  lRoot: string;
  lParams: TNXLSInitializeParams;
  lItem: TNXLSTextDocumentItem;
begin
  lRoot := NXLSCreateUniqueTempDir('nxls');
  NXLSWriteTextFile(IncludeTrailingPathDelimiter(lRoot) +
    'UsedPlatformUnit.pas', cUsedPlatformUnit);
  AFileName := IncludeTrailingPathDelimiter(lRoot) + 'UsedConsumerUnit.pas';
  NXLSWriteTextFile(AFileName, cUsedConsumerUnit);
  AURI := NXLSPathToFileURI(AFileName);

  AModel := TNXLSLSPModel.Create;
  TNXLSLSPModel.SetCurrent(AModel);
  try
    lParams := TNXLSInitializeParams.Create;
    try
      NXLSSetJSONValue(lParams.rootPath, TJSONString.Create(lRoot));
      AModel.BeginInitialize(lParams);
    finally
      lParams.Free;
    end;

    lItem := TNXLSTextDocumentItem.Create;
    try
      lItem.uri.Value := AURI;
      lItem.languageId.Value := 'pascal';
      lItem.version.Value := 1;
      lItem.text.Value := cUsedConsumerUnit;
      AModel.OpenDocument(lItem);
    finally
      lItem.Free;
    end;
  except
    AModel.Free;
    AModel := nil;
    raise;
  end;
end;

procedure NXLSCleanupNavigationModel(AModel: TNXLSLSPModel; const AFileName: string);
var
  lRoot: string;
  lUsedUnit: string;
begin
  AModel.Free;
  TNXLSLSPModel.SetCurrent(nil);

  if FileExists(AFileName) then
    DeleteFile(AFileName);

  lRoot := ExtractFileDir(AFileName);
  lUsedUnit := IncludeTrailingPathDelimiter(lRoot) + 'UsedPlatformUnit.pas';
  if FileExists(lUsedUnit) then
    DeleteFile(lUsedUnit);
  if DirectoryExists(lRoot) then
    RemoveDir(lRoot);
end;

function NXLSLocationLine(AValue: TNXJSONValue): Integer;
var
  lJSON: TJSONData;
begin
  Result := -1;
  lJSON := AValue.ToJSONData;
  try
    if lJSON is TJSONObject then
      Result := TJSONObject(lJSON).Objects['range'].Objects['start'].Integers['line'];
  finally
    lJSON.Free;
  end;
end;

procedure NXLSSetPositionAtText(AParams: TNXLSTextDocumentPositionParams;
  const AText, ALineText, AIdentifier: string);
var
  lLines: TStringList;
  lIdx: Integer;
  lLine: string;
  lLinePos: Integer;
  lIdentPos: Integer;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := AText;
    lLinePos := -1;
    lIdentPos := 0;
    for lIdx := 0 to lLines.Count - 1 do
    begin
      lLine := lLines[lIdx];
      if Pos(ALineText, lLine) > 0 then
      begin
        lLinePos := lIdx;
        lIdentPos := Pos(AIdentifier, lLine);
        Break;
      end;
    end;

    if (lLinePos < 0) or (lIdentPos < 1) then
      raise Exception.CreateFmt('Unable to find %s on line containing %s.',
        [AIdentifier, ALineText]);

    AParams.position.line.Value := lLinePos;
    AParams.position.character.Value := lIdentPos - 1;
  finally
    lLines.Free;
  end;
end;

procedure NXLSAssertLocation(AContext: TNXTestContext; AValue: TNXJSONValue;
  const AMessage: string);
var
  lJSON: TJSONData;
begin
  lJSON := AValue.ToJSONData;
  try
    AContext.AssertTrue(lJSON is TJSONObject, AMessage);
  finally
    lJSON.Free;
  end;
end;

procedure TestDefinitionFindsPropertyTypeDeclaration(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXLSLocation;
begin
  NXLSCreateNavigationModel(cNavigationUnit, lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      NXLSSetPositionAtText(lParams, cNavigationUnit, 'property Item',
        'TTargetType');
      lValue := TNXLSLocation.Create;
      try
        AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lValue),
          'Definition should resolve property type references.');
        NXLSAssertLocation(AContext, lValue,
          'Definition should resolve property type references.');
        AContext.AssertEquals(4, NXLSLocationLine(lValue),
          'Property type reference should resolve to TTargetType.');
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupNavigationModel(lModel, lFileName);
  end;
end;

procedure TestDefinitionFindsArgumentTypeDeclaration(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXLSLocation;
begin
  NXLSCreateNavigationModel(cNavigationUnit, lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      NXLSSetPositionAtText(lParams, cNavigationUnit, 'procedure Accept',
        'TTargetType');
      lValue := TNXLSLocation.Create;
      try
        AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lValue),
          'Definition should resolve argument type references.');
        NXLSAssertLocation(AContext, lValue,
          'Definition should resolve argument type references.');
        AContext.AssertEquals(4, NXLSLocationLine(lValue),
          'Argument type reference should resolve to TTargetType.');
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupNavigationModel(lModel, lFileName);
  end;
end;

procedure TestDefinitionFindsResultTypeDeclaration(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXLSLocation;
begin
  NXLSCreateNavigationModel(cNavigationUnit, lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      NXLSSetPositionAtText(lParams, cNavigationUnit, 'function CreateItem',
        'TTargetType');
      lValue := TNXLSLocation.Create;
      try
        AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lValue),
          'Definition should resolve result type references.');
        NXLSAssertLocation(AContext, lValue,
          'Definition should resolve result type references.');
        AContext.AssertEquals(4, NXLSLocationLine(lValue),
          'Result type reference should resolve to TTargetType.');
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupNavigationModel(lModel, lFileName);
  end;
end;

procedure TestDeclarationFindsInterfaceDeclaration(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXLSLocation;
begin
  NXLSCreateNavigationModel(cNavigationUnit, lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      NXLSSetPositionAtText(lParams, cNavigationUnit, '  TargetProc;',
        'TargetProc');
      lValue := TNXLSLocation.Create;
      try
        AContext.AssertTrue(lModel.Navigation.FillDeclaration(lParams, lValue),
          'Declaration should return a location.');
        NXLSAssertLocation(AContext, lValue, 'Declaration should return a location.');
        AContext.AssertEquals(14, NXLSLocationLine(lValue),
          'Declaration should resolve to the interface declaration.');
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupNavigationModel(lModel, lFileName);
  end;
end;

procedure TestDefinitionFindsImplementationDeclaration(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXLSLocation;
begin
  NXLSCreateNavigationModel(cNavigationUnit, lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      NXLSSetPositionAtText(lParams, cNavigationUnit, '  TargetProc;',
        'TargetProc');
      lValue := TNXLSLocation.Create;
      try
        AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lValue),
          'Definition should return a location.');
        NXLSAssertLocation(AContext, lValue, 'Definition should return a location.');
        AContext.AssertEquals(23, NXLSLocationLine(lValue),
          'Definition should resolve to the implementation declaration.');
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupNavigationModel(lModel, lFileName);
  end;
end;

procedure TestDefinitionFindsUsedUnitRoutine(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXLSLocation;
begin
  NXLSCreateNavigationModelWithUsedUnit(lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      NXLSSetPositionAtText(lParams, cUsedConsumerUnit, 'MakeUsedRect',
        'MakeUsedRect');
      lValue := TNXLSLocation.Create;
      try
        AContext.AssertTrue(lModel.Navigation.FillDefinition(lParams, lValue),
          'Definition should resolve routines declared in used units.');
        NXLSAssertLocation(AContext, lValue,
          'Definition should resolve routines declared in used units.');
        AContext.AssertEquals(6, NXLSLocationLine(lValue),
          'Used unit routine reference should resolve to interface declaration.');
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupNavigationModel(lModel, lFileName);
  end;
end;

procedure RegisterNXLSNavigationTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.Navigation');
  lSuite.AddTest('DeclarationFindsInterfaceDeclaration',
    @TestDeclarationFindsInterfaceDeclaration);
  lSuite.AddTest('DefinitionFindsImplementationDeclaration',
    @TestDefinitionFindsImplementationDeclaration);
  lSuite.AddTest('DefinitionFindsPropertyTypeDeclaration',
    @TestDefinitionFindsPropertyTypeDeclaration);
  lSuite.AddTest('DefinitionFindsArgumentTypeDeclaration',
    @TestDefinitionFindsArgumentTypeDeclaration);
  lSuite.AddTest('DefinitionFindsResultTypeDeclaration',
    @TestDefinitionFindsResultTypeDeclaration);
  lSuite.AddTest('DefinitionFindsUsedUnitRoutine',
    @TestDefinitionFindsUsedUnitRoutine);
end;

end.
