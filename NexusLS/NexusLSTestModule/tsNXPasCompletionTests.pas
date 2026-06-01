unit tsNXPasCompletionTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasCompletionTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXPasCompletion,
  obNXPasSource,
  obNXTestContext,
  obNXTestSuite;

function NXPasLineOf(const AText, ANeedle: string): Integer;
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

function NXPasColumnOf(const AText, ALineNeedle,
  AColumnNeedle: string): Integer;
var
  lLine: Integer;
  lLines: TStringList;
begin
  Result := -1;
  lLine := NXPasLineOf(AText, ALineNeedle);
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

procedure NXPasOpenDocument(AModel: TNXLSLSPModel; const AURI,
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

procedure NXPasFillCompletion(AModel: TNXLSLSPModel; const AURI, AText,
  ALineNeedle, AColumnNeedle: string; AResult: TNXLSCompletionItemArray);
var
  lParams: TNXLSCompletionParams;
begin
  lParams := TNXLSCompletionParams.Create;
  try
    lParams.textDocument.uri.Value := AURI;
    lParams.position.line.Value := NXPasLineOf(AText, ALineNeedle);
    lParams.position.character.Value := NXPasColumnOf(AText, ALineNeedle,
      AColumnNeedle) + Length(AColumnNeedle);
    AModel.Completion.FillCompletionItems(lParams, AResult);
  finally
    lParams.Free;
  end;
end;

function NXPasCompletionLabelCount(AResult: TNXLSCompletionItemArray;
  const ALabel: string): Integer;
var
  lIdx: Integer;
begin
  Result := 0;
  if AResult = nil then
    Exit;

  for lIdx := 0 to AResult.Count - 1 do
    if TNXLSCompletionItem(AResult[lIdx]).&label.Value = ALabel then
      Inc(Result);
end;

function NXPasHasCompletion(AResult: TNXLSCompletionItemArray;
  const ALabel: string): Boolean;
begin
  Result := NXPasCompletionLabelCount(AResult, ALabel) > 0;
end;

procedure TestPrefixDetection(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'var Value: TSam' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lPrefix: string;
  lSource: TNXPasSourceFile;
begin
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', cSource);
  try
    AContext.AssertTrue(TNXPasCompletionHelper.CompletionPrefixAtPosition(
      lSource, NXPasLineOf(cSource, 'TSam'),
      NXPasColumnOf(cSource, 'TSam', 'TSam') + 4, lPrefix),
      'Prefix helper should accept cursor at identifier end.');
    AContext.AssertEquals('TSam', lPrefix,
      'Prefix helper should return the identifier prefix.');
    AContext.AssertTrue(TNXPasCompletionHelper.CompletionPrefixAtPosition(
      lSource, NXPasLineOf(cSource, 'TSam'),
      NXPasColumnOf(cSource, 'TSam', 'TSam'), lPrefix),
      'Prefix helper should accept cursor at identifier start.');
    AContext.AssertEquals('', lPrefix,
      'Cursor at identifier start should return an empty prefix.');
    AContext.AssertTrue(TNXPasCompletionHelper.CompletionPrefixAtPosition(
      lSource, NXPasLineOf(cSource, 'TSam'),
      NXPasColumnOf(cSource, 'TSam', 'TSam') + 2, lPrefix),
      'Prefix helper should accept cursor in the middle of an identifier.');
    AContext.AssertEquals('TS', lPrefix,
      'Cursor in the middle of an identifier should return the partial prefix.');
  finally
    lSource.Free;
  end;
end;

procedure TestCompletionReturnsCurrentDocumentSymbols(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'var Local: TSa' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      'Local: TSa', 'TSa', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'TSample'),
      'Completion should include current document type symbols.');
    AContext.AssertFalse(NXPasHasCompletion(lResult, 'DoWork'),
      'Prefix filtering should exclude nonmatching routine symbols.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionReturnsRoutineSymbol(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  DoW' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  DoW', 'DoW', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'DoWork'),
      'Completion should include routine symbols.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionReturnsIndexedDocumentSymbols(AContext: TNXTestContext);
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
    'var Value: TSh' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/UnitA.pas', cUnitA);
    NXPasOpenDocument(lModel, 'file:///C:/workspace/UnitB.pas', cUnitB);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/UnitB.pas', cUnitB,
      'Value: TSh', 'TSh', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'TShared'),
      'Completion should include indexed open-document symbols.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestPrefixFilteringCaseInsensitive(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    'var Local: tsa' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      'Local: tsa', 'tsa', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'TSample'),
      'Prefix filtering should be case-insensitive.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestEmptyPrefixReturnsSymbols(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  ' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSCompletionParams;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSCompletionParams.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    lParams.textDocument.uri.Value := 'file:///C:/workspace/Sample.pas';
    lParams.position.line.Value := NXPasLineOf(cSource, '  ');
    lParams.position.character.Value := 2;
    lModel.Completion.FillCompletionItems(lParams, lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'TSample'),
      'Empty prefix should return indexed symbols.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestInactiveSymbolsExcluded(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'type THidden = class end;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'implementation' + LineEnding +
    'var Local: TH' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      'Local: TH', 'TH', lResult);
    AContext.AssertFalse(NXPasHasCompletion(lResult, 'THidden'),
      'Inactive symbols should not be completion candidates.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionInsideInactiveRegionReturnsEmpty(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'var Local: TSa' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      'Local: TSa', 'TSa', lResult);
    AContext.AssertEquals(0, lResult.Count,
      'Completion inside inactive code should return empty.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionInsideStringReturnsEmpty(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    'const Text = ''TSa'';' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      'Text =', 'TSa', lResult);
    AContext.AssertEquals(0, lResult.Count,
      'Completion inside strings should return empty.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionInsideCommentReturnsEmpty(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    '// TSa' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '// TSa', 'TSa', lResult);
    AContext.AssertEquals(0, lResult.Count,
      'Completion inside comments should return empty.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestDuplicateSymbolsReduced(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  DoW' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  DoW', 'DoW', lResult);
    AContext.AssertEquals(1, NXPasCompletionLabelCount(lResult, 'DoWork'),
      'Duplicate labels should be reduced.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestKeywordCompletion(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  pub' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  pub', 'pub', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'public'),
      'Keyword completion should include the simple keyword set.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionAfterDotReturnsEmpty(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    'var Item: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  Item.' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  Item.', 'Item.', lResult);
    AContext.AssertEquals(0, lResult.Count,
      'Member completion after dot is intentionally empty in this milestone.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionAfterDotPrefixReturnsEmpty(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'implementation' + LineEnding +
    'var Item: TSample;' + LineEnding +
    'begin' + LineEnding +
    '  Item.Fo' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  Item.Fo', 'Fo', lResult);
    AContext.AssertEquals(0, lResult.Count,
      'Member completion with a typed member prefix is intentionally empty.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionIncludesRoutineParameters(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure Test(AValue: Integer);' + LineEnding +
    'begin' + LineEnding +
    '  AV' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  AV', 'AV', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'AValue'),
      'Completion inside a routine should include parser-owned parameters.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionIncludesLocalVariables(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure Test;' + LineEnding +
    'var' + LineEnding +
    '  LocalValue: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Loc' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  Loc', 'Loc', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'LocalValue'),
      'Completion inside a routine should include local variables.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionFiltersLocalAndParameterPrefixes(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure Test(AValue: Integer);' + LineEnding +
    'var' + LineEnding +
    '  LocalValue: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  AV' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  AV', 'AV', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'AValue'),
      'Parameter should match its prefix.');
    AContext.AssertFalse(NXPasHasCompletion(lResult, 'LocalValue'),
      'Local variable should be excluded by nonmatching prefix.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionExcludesOtherRoutineLocalsAndParameters(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure First(AlphaFirstParam: Integer);' + LineEnding +
    'var' + LineEnding +
    '  AlphaFirstLocal: Integer;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Second(AlphaSecondParam: Integer);' + LineEnding +
    'var' + LineEnding +
    '  AlphaSecondLocal: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Al // complete' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  Al // complete', 'Al', lResult);
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'AlphaSecondParam'),
      'Completion inside a routine should include its own parameter.');
    AContext.AssertTrue(NXPasHasCompletion(lResult, 'AlphaSecondLocal'),
      'Completion inside a routine should include its own local variable.');
    AContext.AssertFalse(NXPasHasCompletion(lResult, 'AlphaFirstParam'),
      'Completion should not include another routine parameter.');
    AContext.AssertFalse(NXPasHasCompletion(lResult, 'AlphaFirstLocal'),
      'Completion should not include another routine local variable.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure TestCompletionOutsideRoutineExcludesLocalsAndParameters(
  AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure Test(AlphaParam: Integer);' + LineEnding +
    'var' + LineEnding +
    '  AlphaLocal: Integer;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Al // complete' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lResult: TNXLSCompletionItemArray;
begin
  lModel := TNXLSLSPModel.Create;
  lResult := TNXLSCompletionItemArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasFillCompletion(lModel, 'file:///C:/workspace/Sample.pas', cSource,
      '  Al // complete', 'Al', lResult);
    AContext.AssertFalse(NXPasHasCompletion(lResult, 'AlphaParam'),
      'Completion outside a routine should not include routine parameters.');
    AContext.AssertFalse(NXPasHasCompletion(lResult, 'AlphaLocal'),
      'Completion outside a routine should not include routine locals.');
  finally
    lResult.Free;
    lModel.Free;
  end;
end;

procedure RegisterNXPasCompletionTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusPas.Completion');
  lSuite.AddTest('PrefixDetection', @TestPrefixDetection);
  lSuite.AddTest('CompletionReturnsCurrentDocumentSymbols',
    @TestCompletionReturnsCurrentDocumentSymbols);
  lSuite.AddTest('CompletionReturnsRoutineSymbol',
    @TestCompletionReturnsRoutineSymbol);
  lSuite.AddTest('CompletionReturnsIndexedDocumentSymbols',
    @TestCompletionReturnsIndexedDocumentSymbols);
  lSuite.AddTest('PrefixFilteringCaseInsensitive',
    @TestPrefixFilteringCaseInsensitive);
  lSuite.AddTest('EmptyPrefixReturnsSymbols', @TestEmptyPrefixReturnsSymbols);
  lSuite.AddTest('InactiveSymbolsExcluded', @TestInactiveSymbolsExcluded);
  lSuite.AddTest('CompletionInsideInactiveRegionReturnsEmpty',
    @TestCompletionInsideInactiveRegionReturnsEmpty);
  lSuite.AddTest('CompletionInsideStringReturnsEmpty',
    @TestCompletionInsideStringReturnsEmpty);
  lSuite.AddTest('CompletionInsideCommentReturnsEmpty',
    @TestCompletionInsideCommentReturnsEmpty);
  lSuite.AddTest('DuplicateSymbolsReduced', @TestDuplicateSymbolsReduced);
  lSuite.AddTest('KeywordCompletion', @TestKeywordCompletion);
  lSuite.AddTest('CompletionAfterDotReturnsEmpty',
    @TestCompletionAfterDotReturnsEmpty);
  lSuite.AddTest('CompletionAfterDotPrefixReturnsEmpty',
    @TestCompletionAfterDotPrefixReturnsEmpty);
  lSuite.AddTest('CompletionIncludesRoutineParameters',
    @TestCompletionIncludesRoutineParameters);
  lSuite.AddTest('CompletionIncludesLocalVariables',
    @TestCompletionIncludesLocalVariables);
  lSuite.AddTest('CompletionFiltersLocalAndParameterPrefixes',
    @TestCompletionFiltersLocalAndParameterPrefixes);
  lSuite.AddTest('CompletionExcludesOtherRoutineLocalsAndParameters',
    @TestCompletionExcludesOtherRoutineLocalsAndParameters);
  lSuite.AddTest('CompletionOutsideRoutineExcludesLocalsAndParameters',
    @TestCompletionOutsideRoutineExcludesLocalsAndParameters);
end;

end.
