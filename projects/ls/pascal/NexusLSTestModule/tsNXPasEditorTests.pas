unit tsNXPasEditorTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXPasEditorTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
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

procedure NXPasSetTextPosition(AParams: TNXLSTextDocumentPositionParams;
  const AURI, AText, ALineNeedle, AColumnNeedle: string);
begin
  AParams.textDocument.uri.Value := AURI;
  AParams.position.line.Value := NXPasLineOf(AText, ALineNeedle);
  AParams.position.character.Value := NXPasColumnOf(AText, ALineNeedle,
    AColumnNeedle);
end;

function NXPasHasHighlightOnLine(AResult: TNXLSDocumentHighlightArray;
  ALine: Integer): Boolean;
var
  lHighlight: TNXLSDocumentHighlight;
  lIdx: Integer;
begin
  Result := False;
  if AResult = nil then
    Exit;

  for lIdx := 0 to AResult.Count - 1 do
  begin
    lHighlight := TNXLSDocumentHighlight(AResult[lIdx]);
    if lHighlight.range.start.line.Value = ALine then
      Exit(True);
  end;
end;

procedure TestHoverReturnsClassText(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'var Local: TSample;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'Local: TSample', 'TSample');

    AContext.AssertTrue(lModel.Editor.FillHover(lParams, lHover),
      'Hover should resolve a type symbol.');
    AContext.AssertEquals('class TSample', lHover.contents.value.Value,
      'Hover should describe the class symbol.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverReturnsRoutineSignature(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork(AValue: Integer);' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  DoWork(1);' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'DoWork(1)', 'DoWork');

    AContext.AssertTrue(lModel.Editor.FillHover(lParams, lHover),
      'Hover should resolve a routine symbol.');
    AContext.AssertEquals('procedure DoWork(AValue: Integer)',
      lHover.contents.value.Value, 'Hover should show the routine signature.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverVariableIncludesDeclaredType(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type TSample = class end;' + LineEnding +
    'var Value: TSample;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'Value: TSample', 'Value');

    AContext.AssertTrue(lModel.Editor.FillHover(lParams, lHover),
      'Hover should resolve a variable symbol.');
    AContext.AssertEquals('variable Value: TSample',
      lHover.contents.value.Value, 'Hover should include variable type.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverFieldIncludesDeclaredType(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type THolder = class' + LineEnding +
    'private' + LineEnding +
    '  FValue: Integer;' + LineEnding +
    'end;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'FValue: Integer', 'FValue');

    AContext.AssertTrue(lModel.Editor.FillHover(lParams, lHover),
      'Hover should resolve a field symbol.');
    AContext.AssertEquals('field FValue: Integer',
      lHover.contents.value.Value, 'Hover should include field type.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverMemberIncludesDeclaredType(AContext: TNXTestContext);
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
    '  Value.FCount;' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'Value.FCount', 'FCount');

    AContext.AssertTrue(lModel.Editor.FillHover(lParams, lHover),
      'Hover should resolve a direct declared-type member.');
    AContext.AssertEquals('field FCount: Integer',
      lHover.contents.value.Value, 'Hover should include member declared type.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverParameterIncludesDeclaredType(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'procedure DoWork(AValue: Integer);' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'AValue: Integer', 'AValue');

    AContext.AssertTrue(lModel.Editor.FillHover(lParams, lHover),
      'Hover should resolve a parameter symbol.');
    AContext.AssertEquals('parameter AValue: Integer',
      lHover.contents.value.Value, 'Hover should include parameter type.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverUnknownReturnsEmpty(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'begin' + LineEnding +
    '  Missing;' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'Missing', 'Missing');

    AContext.AssertFalse(lModel.Editor.FillHover(lParams, lHover),
      'Unknown symbols should not produce hover text.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverIgnoresInactiveDeclaration(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    '{$IFDEF UNKNOWN}' + LineEnding +
    'type THidden = class end;' + LineEnding +
    '{$ENDIF}' + LineEnding +
    'var Local: THidden;' + LineEnding +
    'implementation' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'Local: THidden', 'THidden');

    AContext.AssertFalse(lModel.Editor.FillHover(lParams, lHover),
      'Inactive declarations should not produce hover text.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverPrefersCurrentRoutineLocal(AContext: TNXTestContext);
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
    '  Local: string;' + LineEnding +
    'begin' + LineEnding +
    '  Local; // second' + LineEnding +
    'end;' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, '  Local; // second', 'Local');

    AContext.AssertTrue(lModel.Editor.FillHover(lParams, lHover),
      'Hover should resolve the local symbol visible at the cursor.');
    AContext.AssertEquals('variable Local: string',
      lHover.contents.value.Value,
      'Hover should prefer the local declared in the current routine.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestHoverOutsideRoutineIgnoresLocal(AContext: TNXTestContext);
const
  cSource =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'implementation' + LineEnding +
    'procedure Test;' + LineEnding +
    'var' + LineEnding +
    '  Local: Integer;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'begin' + LineEnding +
    '  Local;' + LineEnding +
    'end.';
var
  lHover: TNXLSHover;
  lModel: TNXLSLSPModel;
  lParams: TNXLSTextDocumentPositionParams;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lHover := TNXLSHover.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, '  Local;', 'Local');

    AContext.AssertFalse(lModel.Editor.FillHover(lParams, lHover),
      'Hover outside a routine should not resolve routine-local symbols.');
  finally
    lHover.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure TestDocumentHighlightsExcludeCommentsStringsAndInactive(
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
  lParams: TNXLSTextDocumentPositionParams;
  lResult: TNXLSDocumentHighlightArray;
begin
  lModel := TNXLSLSPModel.Create;
  lParams := TNXLSTextDocumentPositionParams.Create;
  lResult := TNXLSDocumentHighlightArray.Create;
  try
    NXPasOpenDocument(lModel, 'file:///C:/workspace/Sample.pas', cSource);
    NXPasSetTextPosition(lParams, 'file:///C:/workspace/Sample.pas',
      cSource, 'Visible: TSample', 'TSample');

    lModel.Editor.FillDocumentHighlights(lParams, lResult);

    AContext.AssertTrue(NXPasHasHighlightOnLine(lResult, 2),
      'Highlights should include the active declaration.');
    AContext.AssertTrue(NXPasHasHighlightOnLine(lResult, 8),
      'Highlights should include active usage.');
    AContext.AssertFalse(NXPasHasHighlightOnLine(lResult, 3),
      'Highlights should exclude comments.');
    AContext.AssertFalse(NXPasHasHighlightOnLine(lResult, 4),
      'Highlights should exclude strings.');
    AContext.AssertFalse(NXPasHasHighlightOnLine(lResult, 6),
      'Highlights should exclude inactive regions.');
  finally
    lResult.Free;
    lParams.Free;
    lModel.Free;
  end;
end;

procedure RegisterNXPasEditorTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusPas.Editor');
  lSuite.AddTest('HoverReturnsClassText', @TestHoverReturnsClassText);
  lSuite.AddTest('HoverReturnsRoutineSignature',
    @TestHoverReturnsRoutineSignature);
  lSuite.AddTest('HoverVariableIncludesDeclaredType',
    @TestHoverVariableIncludesDeclaredType);
  lSuite.AddTest('HoverFieldIncludesDeclaredType',
    @TestHoverFieldIncludesDeclaredType);
  lSuite.AddTest('HoverMemberIncludesDeclaredType',
    @TestHoverMemberIncludesDeclaredType);
  lSuite.AddTest('HoverParameterIncludesDeclaredType',
    @TestHoverParameterIncludesDeclaredType);
  lSuite.AddTest('HoverUnknownReturnsEmpty', @TestHoverUnknownReturnsEmpty);
  lSuite.AddTest('HoverIgnoresInactiveDeclaration',
    @TestHoverIgnoresInactiveDeclaration);
  lSuite.AddTest('HoverPrefersCurrentRoutineLocal',
    @TestHoverPrefersCurrentRoutineLocal);
  lSuite.AddTest('HoverOutsideRoutineIgnoresLocal',
    @TestHoverOutsideRoutineIgnoresLocal);
  lSuite.AddTest('DocumentHighlightsExcludeCommentsStringsAndInactive',
    @TestDocumentHighlightsExcludeCommentsStringsAndInactive);
end;

end.
