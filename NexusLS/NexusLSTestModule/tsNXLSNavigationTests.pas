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
    'procedure TargetProc;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TargetProc;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Caller;' + LineEnding +
    'begin' + LineEnding +
    '  TargetProc;' + LineEnding +
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

procedure NXLSCleanupNavigationModel(AModel: TNXLSLSPModel; const AFileName: string);
var
  lRoot: string;
begin
  AModel.Free;
  TNXLSLSPModel.SetCurrent(nil);

  if FileExists(AFileName) then
    DeleteFile(AFileName);

  lRoot := ExtractFileDir(AFileName);
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

procedure TestDeclarationFindsInterfaceDeclaration(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXJSONValue;
begin
  NXLSCreateNavigationModel(cNavigationUnit, lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lParams.position.line.Value := 10;
      lParams.position.character.Value := 2;
      lValue := lModel.Navigation.Declaration(lParams);
      try
        NXLSAssertLocation(AContext, lValue, 'Declaration should return a location.');
        AContext.AssertEquals(3, NXLSLocationLine(lValue),
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
  lValue: TNXJSONValue;
begin
  NXLSCreateNavigationModel(cNavigationUnit, lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lParams.position.line.Value := 10;
      lParams.position.character.Value := 2;
      lValue := lModel.Navigation.Definition(lParams);
      try
        NXLSAssertLocation(AContext, lValue, 'Definition should return a location.');
        AContext.AssertEquals(5, NXLSLocationLine(lValue),
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

procedure RegisterNXLSNavigationTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.Navigation');
  lSuite.AddTest('DeclarationFindsInterfaceDeclaration',
    @TestDeclarationFindsInterfaceDeclaration);
  lSuite.AddTest('DefinitionFindsImplementationDeclaration',
    @TestDefinitionFindsImplementationDeclaration);
end;

end.
