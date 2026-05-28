unit tsNXLSIntelligenceTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSIntelligenceTests(ARegistry: TNXTestRegistry);

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
  obNXTestSuite,
  utNXLSServiceHelpers;

const
  cIntelligenceUnit =
    'unit IntelligenceUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'procedure TargetProc(AValue: Integer);' + LineEnding +
    'implementation' + LineEnding +
    'procedure TargetProc(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Caller;' + LineEnding +
    'begin' + LineEnding +
    '  Tar' + LineEnding +
    '  TargetProc(1);' + LineEnding +
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

procedure NXLSCreateIntelligenceModel(out AModel: TNXLSLSPModel;
  out AFileName: string; out AURI: string);
var
  lRoot: string;
  lParams: TNXLSInitializeParams;
  lItem: TNXLSTextDocumentItem;
begin
  lRoot := NXLSCreateUniqueTempDir('nxlsi');
  AFileName := IncludeTrailingPathDelimiter(lRoot) + 'IntelligenceUnit.pas';
  NXLSWriteTextFile(AFileName, cIntelligenceUnit);
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
      lItem.text.Value := cIntelligenceUnit;
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

procedure NXLSCleanupIntelligenceModel(AModel: TNXLSLSPModel; const AFileName: string);
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

function NXLSArrayFromValue(AValue: TNXJSONValue): TJSONArray;
var
  lJSON: TJSONData;
begin
  Result := nil;
  lJSON := AValue.ToJSONData;
  if lJSON is TJSONArray then
    Result := TJSONArray(lJSON)
  else
    lJSON.Free;
end;

function NXLSHasObjectNamed(AArray: TJSONArray; const AName: string): Boolean;
var
  lIdx: Integer;
begin
  Result := False;
  if AArray = nil then
    Exit;

  for lIdx := 0 to AArray.Count - 1 do
    if (AArray.Items[lIdx] is TJSONObject) and
      (TJSONObject(AArray.Items[lIdx]).Get('label', '') = AName) then
      Exit(True);
end;

procedure TestCompletionReturnsVisibleIdentifier(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSCompletionParams;
  lValue: TNXJSONValue;
  lArray: TJSONArray;
begin
  NXLSCreateIntelligenceModel(lModel, lFileName, lURI);
  try
    lParams := TNXLSCompletionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lParams.position.line.Value := 10;
      lParams.position.character.Value := 2;
      lValue := lModel.Completion.Completion(lParams);
      try
        lArray := NXLSArrayFromValue(lValue);
        try
          AContext.AssertTrue(lArray <> nil, 'Completion should return an array.');
          AContext.AssertTrue(NXLSHasObjectNamed(lArray, 'TargetProc'),
            'Completion should include TargetProc. Actual: ' + lArray.AsJSON);
        finally
          lArray.Free;
        end;
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupIntelligenceModel(lModel, lFileName);
  end;
end;

procedure TestCompletionHonorsIdentifierPrefix(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSCompletionParams;
  lValue: TNXJSONValue;
  lArray: TJSONArray;
begin
  NXLSCreateIntelligenceModel(lModel, lFileName, lURI);
  try
    lParams := TNXLSCompletionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lParams.position.line.Value := 10;
      lParams.position.character.Value := 5;
      lValue := lModel.Completion.Completion(lParams);
      try
        lArray := NXLSArrayFromValue(lValue);
        try
          AContext.AssertTrue(lArray <> nil, 'Completion should return an array.');
          AContext.AssertTrue(NXLSHasObjectNamed(lArray, 'TargetProc'),
            'Prefix "Tar" should include TargetProc. Actual: ' + lArray.AsJSON);
          AContext.AssertFalse(NXLSHasObjectNamed(lArray, 'Caller'),
            'Prefix "Tar" should not include Caller. Actual: ' + lArray.AsJSON);
        finally
          lArray.Free;
        end;
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupIntelligenceModel(lModel, lFileName);
  end;
end;

procedure TestRangeClampPreventsNegativePositions(AContext: TNXTestContext);
var
  lRange: TNXLSRange;
  lJSON: TJSONData;
  lObject: TJSONObject;
begin
  lRange := TNXLSRange.Create;
  try
    NXLSSetRange(lRange, -2, -3, -1, -4);
    lJSON := lRange.ToJSONData;
    try
      AContext.AssertTrue(lJSON is TJSONObject,
        'Range should serialize as an object.');
      lObject := TJSONObject(lJSON);
      AContext.AssertEquals(0, lObject.Objects['start'].Integers['line'],
        'Start line should be clamped.');
      AContext.AssertEquals(0, lObject.Objects['start'].Integers['character'],
        'Start character should be clamped.');
      AContext.AssertEquals(0, lObject.Objects['end'].Integers['line'],
        'End line should be clamped.');
      AContext.AssertEquals(0, lObject.Objects['end'].Integers['character'],
        'End character should be clamped.');
    finally
      lJSON.Free;
    end;
  finally
    lRange.Free;
  end;
end;

procedure TestReferencesFindUsage(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSReferenceParams;
  lValue: TNXJSONValue;
  lArray: TJSONArray;
begin
  NXLSCreateIntelligenceModel(lModel, lFileName, lURI);
  try
    lParams := TNXLSReferenceParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lParams.position.line.Value := 11;
      lParams.position.character.Value := 2;
      lParams.context.includeDeclaration.Value := True;
      lValue := lModel.Navigation.References(lParams);
      try
        lArray := NXLSArrayFromValue(lValue);
        try
          AContext.AssertTrue(lArray <> nil, 'References should return an array.');
          AContext.AssertTrue(lArray.Count >= 2,
            'References should include at least the declaration and call site. Actual: ' + lArray.AsJSON);
        finally
          lArray.Free;
        end;
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupIntelligenceModel(lModel, lFileName);
  end;
end;

procedure TestHoverReturnsSmartHint(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSTextDocumentPositionParams;
  lValue: TNXJSONValue;
  lJSON: TJSONData;
begin
  NXLSCreateIntelligenceModel(lModel, lFileName, lURI);
  try
    lParams := TNXLSTextDocumentPositionParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lParams.position.line.Value := 11;
      lParams.position.character.Value := 2;
      lValue := lModel.Editor.Hover(lParams);
      try
        lJSON := lValue.ToJSONData;
        try
          AContext.AssertTrue(lJSON is TJSONObject, 'Hover should return an object. Actual: ' + lJSON.AsJSON);
          AContext.AssertTrue(Pos('TargetProc', lJSON.AsJSON) > 0,
            'Hover should include TargetProc.');
        finally
          lJSON.Free;
        end;
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupIntelligenceModel(lModel, lFileName);
  end;
end;

procedure TestSignatureHelpReturnsParameter(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSSignatureHelpParams;
  lValue: TNXJSONValue;
  lJSON: TJSONData;
begin
  NXLSCreateIntelligenceModel(lModel, lFileName, lURI);
  try
    lParams := TNXLSSignatureHelpParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lParams.position.line.Value := 11;
      lParams.position.character.Value := 14;
      lValue := lModel.Completion.SignatureHelp(lParams);
      try
        lJSON := lValue.ToJSONData;
        try
          AContext.AssertTrue(lJSON is TJSONObject,
            'SignatureHelp should return an object. Actual: ' + lJSON.AsJSON);
          AContext.AssertTrue(Pos('AValue', lJSON.AsJSON) > 0,
            'SignatureHelp should include the declared parameter.');
        finally
          lJSON.Free;
        end;
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    NXLSCleanupIntelligenceModel(lModel, lFileName);
  end;
end;

procedure RegisterNXLSIntelligenceTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.Intelligence');
  lSuite.AddTest('CompletionReturnsVisibleIdentifier',
    @TestCompletionReturnsVisibleIdentifier);
  lSuite.AddTest('CompletionHonorsIdentifierPrefix',
    @TestCompletionHonorsIdentifierPrefix);
  lSuite.AddTest('RangeClampPreventsNegativePositions',
    @TestRangeClampPreventsNegativePositions);
  lSuite.AddTest('ReferencesFindUsage', @TestReferencesFindUsage);
  lSuite.AddTest('HoverReturnsSmartHint', @TestHoverReturnsSmartHint);
  lSuite.AddTest('SignatureHelpReturnsParameter',
    @TestSignatureHelpReturnsParameter);
end;

end.
