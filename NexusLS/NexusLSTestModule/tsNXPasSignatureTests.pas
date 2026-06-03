unit tsNXPasSignatureTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasSignatureTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXPasDocumentAnalysis,
  obNXPasSignatures,
  obNXPasSource,
  obNXPasWorkspaceIndex,
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

function NXPasIndexSource(AIndex: TNXPasWorkspaceIndex;
  ASource: TNXPasSourceFile): TNXPasIndexedFile;
var
  lAnalysis: TNXPasDocumentAnalysis;
  lAnalyzer: TNXPasAnalyzer;
begin
  Result := nil;
  if (AIndex = nil) or (ASource = nil) then
    Exit;

  lAnalyzer := TNXPasAnalyzer.Create;
  lAnalysis := nil;
  try
    lAnalysis := lAnalyzer.Analyze(TNXPasSourceFile.Create(ASource.FileName,
      ASource.URI, ASource.Text));
    Result := AIndex.UpdateAnalyzedFile(lAnalysis);
  finally
    lAnalysis.Free;
    lAnalyzer.Free;
  end;
end;

function NXPasExtractFirstSignature(const AText, AName: string;
  ASignature: TNXPasRoutineSignature): Boolean;
var
  lIndex: TNXPasWorkspaceIndex;
  lMatches: TNXPasWorkspaceSymbolMatchList;
  lSource: TNXPasSourceFile;
begin
  Result := False;
  lIndex := TNXPasWorkspaceIndex.Create;
  lMatches := TNXPasWorkspaceSymbolMatchList.Create(True);
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', AText);
  try
    NXPasIndexSource(lIndex, lSource);
    lIndex.FindSymbolsByName(AName, lSource.URI, lMatches);
    if lMatches.Count = 0 then
      Exit;

    Result := TNXPasSignatureHelper.ExtractSignature(
      lMatches.MatchAt(0).FileRef, lMatches.MatchAt(0).Symbol, ASignature);
  finally
    lSource.Free;
    lMatches.Free;
    lIndex.Free;
  end;
end;

procedure TestExtractProcedureNoParameters(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lSignature: TNXPasRoutineSignature;
begin
  lSignature := TNXPasRoutineSignature.Create;
  try
    AContext.AssertTrue(NXPasExtractFirstSignature(cSource, 'DoWork',
      lSignature), 'Procedure signature should be extracted.');
    AContext.AssertEquals('procedure DoWork', lSignature.&Label,
      'Signature label should not include the terminating semicolon.');
    AContext.AssertEquals(0, lSignature.Parameters.Count,
      'No-parameter procedure should have no parameter labels.');
  finally
    lSignature.Free;
  end;
end;

procedure TestExtractProcedureParameters(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure Test(A, B: Integer; const C: string);' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lSignature: TNXPasRoutineSignature;
begin
  lSignature := TNXPasRoutineSignature.Create;
  try
    AContext.AssertTrue(NXPasExtractFirstSignature(cSource, 'Test',
      lSignature), 'Procedure signature should be extracted.');
    AContext.AssertEquals('procedure Test(A, B: Integer; const C: string)',
      lSignature.&Label, 'Signature label should include parameters.');
    AContext.AssertEquals(2, lSignature.Parameters.Count,
      'Semicolon-separated parameter groups should be split.');
    AContext.AssertEquals('A, B: Integer',
      lSignature.Parameters.ParameterAt(0).&Label,
      'First parameter group should preserve shared type.');
    AContext.AssertEquals('const C: string',
      lSignature.Parameters.ParameterAt(1).&Label,
      'Second parameter group should preserve const modifier.');
  finally
    lSignature.Free;
  end;
end;

procedure TestExtractFunctionReturnType(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'function GetValue(const AName: string): Integer;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lSignature: TNXPasRoutineSignature;
begin
  lSignature := TNXPasRoutineSignature.Create;
  try
    AContext.AssertTrue(NXPasExtractFirstSignature(cSource, 'GetValue',
      lSignature), 'Function signature should be extracted.');
    AContext.AssertEquals('Integer', lSignature.ReturnType,
      'Function return type should be extracted.');
    AContext.AssertEquals('function GetValue(const AName: string): Integer',
      lSignature.&Label, 'Function label should include return type.');
  finally
    lSignature.Free;
  end;
end;

procedure TestExtractParameterModes(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure Modes(const A: string; var B: Integer; out C: Boolean);' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lSignature: TNXPasRoutineSignature;
begin
  lSignature := TNXPasRoutineSignature.Create;
  try
    AContext.AssertTrue(NXPasExtractFirstSignature(cSource, 'Modes',
      lSignature), 'Mode parameters should be extracted.');
    AContext.AssertEquals(3, lSignature.Parameters.Count,
      'Parameter modes should not prevent group splitting.');
    AContext.AssertEquals('const A: string',
      lSignature.Parameters.ParameterAt(0).&Label, 'const should be retained.');
    AContext.AssertEquals('var B: Integer',
      lSignature.Parameters.ParameterAt(1).&Label, 'var should be retained.');
    AContext.AssertEquals('out C: Boolean',
      lSignature.Parameters.ParameterAt(2).&Label, 'out should be retained.');
  finally
    lSignature.Free;
  end;
end;

procedure TestDetectSimpleCall(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  DoWork(123, ''abc'');' + LineEnding +
    'end.';
var
  lCall: TNXPasCallContext;
  lSource: TNXPasSourceFile;
begin
  lCall := TNXPasCallContext.Create;
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', cSource);
  try
    AContext.AssertTrue(TNXPasSignatureHelper.FindCallAtPosition(lSource,
      NXPasLineOf(cSource, 'DoWork'), NXPasColumnOf(cSource, 'DoWork', '123'),
      lCall), 'Cursor inside argument list should identify the call.');
    AContext.AssertEquals('DoWork', lCall.Name,
      'Call context should contain the routine name.');
    AContext.AssertEquals(0, lCall.ActiveParameter,
      'First argument should be active parameter 0.');
  finally
    lSource.Free;
    lCall.Free;
  end;
end;

procedure TestActiveParameterAfterComma(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  DoWork(123, ''abc'');' + LineEnding +
    'end.';
var
  lCall: TNXPasCallContext;
  lSource: TNXPasSourceFile;
begin
  lCall := TNXPasCallContext.Create;
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', cSource);
  try
    AContext.AssertTrue(TNXPasSignatureHelper.FindCallAtPosition(lSource,
      NXPasLineOf(cSource, 'DoWork'), NXPasColumnOf(cSource, 'DoWork', 'abc'),
      lCall), 'Cursor after a comma should still identify the call.');
    AContext.AssertEquals(1, lCall.ActiveParameter,
      'Second argument should be active parameter 1.');
  finally
    lSource.Free;
    lCall.Free;
  end;
end;

procedure TestNestedParenthesesDoNotIncrementParameter(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  DoWork(Other(1, 2), 3);' + LineEnding +
    'end.';
var
  lCall: TNXPasCallContext;
  lSource: TNXPasSourceFile;
begin
  lCall := TNXPasCallContext.Create;
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', cSource);
  try
    AContext.AssertTrue(TNXPasSignatureHelper.FindCallAtPosition(lSource,
      NXPasLineOf(cSource, 'DoWork'), NXPasColumnOf(cSource, 'DoWork', '2'),
      lCall), 'Nested call argument should identify the innermost call.');
    AContext.AssertEquals('Other', lCall.Name,
      'Nested call should become the active call context.');
    AContext.AssertEquals(1, lCall.ActiveParameter,
      'Comma inside the nested call should advance the nested parameter.');
  finally
    lSource.Free;
    lCall.Free;
  end;
end;

procedure TestOuterCallParameterAfterNestedCall(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  DoWork(Other(1, 2), 3);' + LineEnding +
    'end.';
var
  lCall: TNXPasCallContext;
  lSource: TNXPasSourceFile;
begin
  lCall := TNXPasCallContext.Create;
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', cSource);
  try
    AContext.AssertTrue(TNXPasSignatureHelper.FindCallAtPosition(lSource,
      NXPasLineOf(cSource, 'DoWork'), NXPasColumnOf(cSource, 'DoWork', '3'),
      lCall), 'Cursor after a nested call should return the outer call.');
    AContext.AssertEquals('DoWork', lCall.Name,
      'Outer call should be active after nested call closes.');
    AContext.AssertEquals(1, lCall.ActiveParameter,
      'Top-level comma should advance the outer active parameter.');
  finally
    lSource.Free;
    lCall.Free;
  end;
end;

procedure TestBracketCommasDoNotIncrementParameter(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  DoWork(Values[1, 2], 3);' + LineEnding +
    'end.';
var
  lCall: TNXPasCallContext;
  lSource: TNXPasSourceFile;
begin
  lCall := TNXPasCallContext.Create;
  lSource := TNXPasSourceFile.Create('Sample.pas',
    'file:///C:/workspace/Sample.pas', cSource);
  try
    AContext.AssertTrue(TNXPasSignatureHelper.FindCallAtPosition(lSource,
      NXPasLineOf(cSource, 'DoWork'), NXPasColumnOf(cSource, 'DoWork', '2'),
      lCall), 'Cursor inside index brackets should keep the enclosing call.');
    AContext.AssertEquals('DoWork', lCall.Name,
      'Bracket expressions should not create a new call context.');
    AContext.AssertEquals(0, lCall.ActiveParameter,
      'Comma inside brackets should not advance the active parameter.');
  finally
    lSource.Free;
    lCall.Free;
  end;
end;

procedure TestSignatureHelpSimpleProcedure(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork(AValue: Integer; const AName: string);' + LineEnding +
    'implementation' + LineEnding +
    'procedure Caller;' + LineEnding +
    'begin' + LineEnding +
    '  DoWork(1, ''abc'');' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSSignatureHelpParams;
  lResult: TNXLSSignatureHelp;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSSignatureHelpParams.Create;
  lResult := TNXLSSignatureHelp.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    lParams.textDocument.uri.Value := 'file:///C:/workspace/Sample.pas';
    lParams.position.line.Value := NXPasLineOf(cSource, 'DoWork(1');
    lParams.position.character.Value := NXPasColumnOf(cSource, 'DoWork(1', 'abc');

    AContext.AssertTrue(lModel.Completion.FillSignatureHelp(lParams, lResult),
      'Signature help should resolve a simple procedure call.');
    AContext.AssertTrue(lResult.signatures.Count > 0,
      'Signature help should include at least one candidate.');
    AContext.AssertEquals(1, lResult.activeParameter.Value,
      'Signature help should report the active parameter.');
    AContext.AssertEquals('procedure DoWork(AValue: Integer; const AName: string)',
      TNXLSSignatureInformation(lResult.signatures[0]).&label.Value,
      'Signature help should include the routine label.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestSignatureHelpUnknownRoutine(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure Caller;' + LineEnding +
    'begin' + LineEnding +
    '  Missing(1);' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSSignatureHelpParams;
  lResult: TNXLSSignatureHelp;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSSignatureHelpParams.Create;
  lResult := TNXLSSignatureHelp.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    lParams.textDocument.uri.Value := 'file:///C:/workspace/Sample.pas';
    lParams.position.line.Value := NXPasLineOf(cSource, 'Missing');
    lParams.position.character.Value := NXPasColumnOf(cSource, 'Missing', '1');

    AContext.AssertFalse(lModel.Completion.FillSignatureHelp(lParams, lResult),
      'Unknown routine should not produce signature help.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestInactiveRoutineIsNotCandidate(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'procedure Hidden(AValue: Integer);' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'implementation' + LineEnding +
    'procedure Caller;' + LineEnding +
    'begin' + LineEnding +
    '  Hidden(1);' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSSignatureHelpParams;
  lResult: TNXLSSignatureHelp;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSSignatureHelpParams.Create;
  lResult := TNXLSSignatureHelp.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    lParams.textDocument.uri.Value := 'file:///C:/workspace/Sample.pas';
    lParams.position.line.Value := NXPasLineOf(cSource, 'Hidden(1)');
    lParams.position.character.Value := NXPasColumnOf(cSource, 'Hidden(1)', '1');

    AContext.AssertFalse(lModel.Completion.FillSignatureHelp(lParams, lResult),
      'Inactive routine declarations should not become candidates.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestInactiveCallReturnsNoSignatureHelp(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure Visible(AValue: Integer);' + LineEnding +
    'implementation' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'procedure Caller;' + LineEnding +
    'begin' + LineEnding +
    '  Visible(1);' + LineEnding +
    'end;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'end.';
var
  lModel: TNXLSLSPModel;
  lParams: TNXLSSignatureHelpParams;
  lResult: TNXLSSignatureHelp;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSSignatureHelpParams.Create;
  lResult := TNXLSSignatureHelp.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    lParams.textDocument.uri.Value := 'file:///C:/workspace/Sample.pas';
    lParams.position.line.Value := NXPasLineOf(cSource, 'Visible(1)');
    lParams.position.character.Value := NXPasColumnOf(cSource, 'Visible(1)', '1');

    AContext.AssertFalse(lModel.Completion.FillSignatureHelp(lParams, lResult),
      'Calls inside inactive regions should not produce signature help.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure RegisterNXPasSignatureTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusPas.Signatures');
  lSuite.AddTest('ExtractProcedureNoParameters',
    @TestExtractProcedureNoParameters);
  lSuite.AddTest('ExtractProcedureParameters',
    @TestExtractProcedureParameters);
  lSuite.AddTest('ExtractFunctionReturnType', @TestExtractFunctionReturnType);
  lSuite.AddTest('ExtractParameterModes', @TestExtractParameterModes);
  lSuite.AddTest('DetectSimpleCall', @TestDetectSimpleCall);
  lSuite.AddTest('ActiveParameterAfterComma', @TestActiveParameterAfterComma);
  lSuite.AddTest('NestedParenthesesDoNotIncrementParameter',
    @TestNestedParenthesesDoNotIncrementParameter);
  lSuite.AddTest('OuterCallParameterAfterNestedCall',
    @TestOuterCallParameterAfterNestedCall);
  lSuite.AddTest('BracketCommasDoNotIncrementParameter',
    @TestBracketCommasDoNotIncrementParameter);
  lSuite.AddTest('SignatureHelpSimpleProcedure',
    @TestSignatureHelpSimpleProcedure);
  lSuite.AddTest('SignatureHelpUnknownRoutine',
    @TestSignatureHelpUnknownRoutine);
  lSuite.AddTest('InactiveRoutineIsNotCandidate',
    @TestInactiveRoutineIsNotCandidate);
  lSuite.AddTest('InactiveCallReturnsNoSignatureHelp',
    @TestInactiveCallReturnsNoSignatureHelp);
end;

end.
