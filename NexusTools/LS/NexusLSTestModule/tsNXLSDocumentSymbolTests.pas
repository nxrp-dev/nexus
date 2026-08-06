unit tsNXLSDocumentSymbolTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSDocumentSymbolTests(ARegistry: TNXTestRegistry);

implementation

uses
  obNXJSONValues,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  obNXTestContext,
  obNXTestSuite;

const
  cSymbolUnit =
    'unit Sample;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TSample = class' + LineEnding +
    '  end;' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'implementation' + LineEnding +
    'end.';

function NXLSHasDocumentSymbol(AResult: TNXJSONArray; const AName: string): Boolean;
var
  lIdx: Integer;
  lSymbol: TNXLSDocumentSymbol;
begin
  Result := False;
  for lIdx := 0 to AResult.Count - 1 do
  begin
    lSymbol := TNXLSDocumentSymbol(AResult[lIdx]);
    if lSymbol.name.Value = AName then
      Exit(True);
  end;
end;

function NXLSFindDocumentSymbol(AResult: TNXJSONArray;
  const AName: string): TNXLSDocumentSymbol;
var
  lIdx: Integer;
  lSymbol: TNXLSDocumentSymbol;
begin
  Result := nil;
  for lIdx := 0 to AResult.Count - 1 do
  begin
    lSymbol := TNXLSDocumentSymbol(AResult[lIdx]);
    if lSymbol.name.Value = AName then
      Exit(lSymbol);
  end;
end;

function NXLSCountDocumentSymbols(AResult: TNXJSONArray;
  const AName: string): Integer;
var
  lIdx: Integer;
  lSymbol: TNXLSDocumentSymbol;
begin
  Result := 0;
  for lIdx := 0 to AResult.Count - 1 do
  begin
    lSymbol := TNXLSDocumentSymbol(AResult[lIdx]);
    if lSymbol.name.Value = AName then
      Inc(Result);
  end;
end;

function NXLSFindChildDocumentSymbol(AParent: TNXLSDocumentSymbol;
  const AName: string): TNXLSDocumentSymbol;
var
  lIdx: Integer;
  lSymbol: TNXLSDocumentSymbol;
begin
  Result := nil;
  if AParent = nil then
    Exit;

  for lIdx := 0 to AParent.children.Count - 1 do
  begin
    lSymbol := TNXLSDocumentSymbol(AParent.children[lIdx]);
    if lSymbol.name.Value = AName then
      Exit(lSymbol);
  end;
end;

procedure TestDocumentSymbolsUseNexusPas(AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value := cSymbolUnit;
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    AContext.AssertTrue(lResult.Assigned,
      'Document symbol result should be an assigned array.');
    AContext.AssertTrue(NXLSHasDocumentSymbol(lResult, 'Sample'),
      'Document symbols should include the NexusPas unit symbol.');
    AContext.AssertTrue(NXLSHasDocumentSymbol(lResult, 'TSample'),
      'Document symbols should include the NexusPas type/class symbol.');
    AContext.AssertTrue(NXLSHasDocumentSymbol(lResult, 'DoWork'),
      'Document symbols should include the NexusPas routine symbol.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestDocumentSymbolRangesUseSourceTokens(AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
  lSymbol: TNXLSDocumentSymbol;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value := cSymbolUnit;
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    lSymbol := NXLSFindDocumentSymbol(lResult, 'TSample');
    AContext.AssertTrue(lSymbol <> nil, 'TSample symbol should exist.');
    AContext.AssertEquals(3, lSymbol.range.start.line.Value,
      'TSample range should start on the type declaration line.');
    AContext.AssertEquals(2, lSymbol.range.start.character.Value,
      'TSample range should start at the identifier column.');
    AContext.AssertTrue(
      (lSymbol.range.&end.line.Value > lSymbol.range.start.line.Value) or
      (lSymbol.range.&end.character.Value > lSymbol.range.start.character.Value),
      'TSample range should not be zero-width.');

    lSymbol := NXLSFindDocumentSymbol(lResult, 'DoWork');
    AContext.AssertTrue(lSymbol <> nil, 'DoWork symbol should exist.');
    AContext.AssertEquals(5, lSymbol.range.start.line.Value,
      'DoWork range should start on the procedure declaration line.');
    AContext.AssertEquals(0, lSymbol.range.start.character.Value,
      'DoWork range should start at the procedure keyword.');
    AContext.AssertTrue(
      lSymbol.range.&end.character.Value > lSymbol.range.start.character.Value,
      'DoWork range should not be zero-width.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestDocumentSymbolNamesAndSpecificKinds(AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
  lSymbol: TNXLSDocumentSymbol;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value := cSymbolUnit;
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    AContext.AssertTrue(NXLSHasDocumentSymbol(lResult, 'Sample'),
      'Unit symbol name should be the declared identifier only.');
    AContext.AssertFalse(NXLSHasDocumentSymbol(lResult, 'unit Sample'),
      'Unit symbol name should not include the unit keyword.');
    AContext.AssertTrue(NXLSHasDocumentSymbol(lResult, 'DoWork'),
      'Routine symbol name should be the declared identifier only.');
    AContext.AssertFalse(NXLSHasDocumentSymbol(lResult, 'procedure DoWork'),
      'Routine symbol name should not include the declaration keyword.');

    AContext.AssertEquals(1, NXLSCountDocumentSymbols(lResult, 'TSample'),
      'Class type declaration should emit one TSample document symbol.');
    lSymbol := NXLSFindDocumentSymbol(lResult, 'TSample');
    AContext.AssertTrue(lSymbol <> nil, 'TSample symbol should exist.');
    AContext.AssertEquals(5, lSymbol.kind.Value,
      'TSample = class should emit LSP class kind.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestClassMembersAreNested(AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
  lSymbol: TNXLSDocumentSymbol;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value :=
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TSample = class' + LineEnding +
      '  public' + LineEnding +
      '    procedure Run(A: Integer; const B: string);' + LineEnding +
      '    property Items[Index: Integer; const Name: string]: string read GetItem;' + LineEnding +
      '  private' + LineEnding +
      '    FValue: Integer;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    AContext.AssertEquals(1, NXLSCountDocumentSymbols(lResult, 'TSample'),
      'Class declaration should emit one top-level TSample symbol.');
    lSymbol := NXLSFindDocumentSymbol(lResult, 'TSample');
    AContext.AssertTrue(lSymbol <> nil, 'Class symbol should exist.');
    AContext.AssertEquals(5, lSymbol.kind.Value,
      'TSample should use LSP class kind.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'Run') <> nil,
      'Class method should be nested under the class symbol.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'Items') <> nil,
      'Indexed class property should be nested under the class symbol.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'FValue') <> nil,
      'Class field should be nested under the class symbol.');
    AContext.AssertEquals(9, lSymbol.range.&end.line.Value,
      'Class range should extend through the final end semicolon.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestRecordMembersAreNested(AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
  lSymbol: TNXLSDocumentSymbol;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value :=
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TPoint = record' + LineEnding +
      '    X, Y: Integer;' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    lSymbol := NXLSFindDocumentSymbol(lResult, 'TPoint');
    AContext.AssertTrue(lSymbol <> nil, 'Record symbol should exist.');
    AContext.AssertEquals(23, lSymbol.kind.Value,
      'TPoint should use LSP struct kind.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'X') <> nil,
      'First record field should be nested under the record symbol.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'Y') <> nil,
      'Second record field should be nested under the record symbol.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestInterfaceMembersAreNested(AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
  lSymbol: TNXLSDocumentSymbol;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value :=
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  ISample = interface' + LineEnding +
      '    procedure Run(A: Integer; const B: string);' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    lSymbol := NXLSFindDocumentSymbol(lResult, 'ISample');
    AContext.AssertTrue(lSymbol <> nil, 'Interface symbol should exist.');
    AContext.AssertEquals(11, lSymbol.kind.Value,
      'ISample should use LSP interface kind.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'Run') <> nil,
      'Interface method should be nested under the interface symbol.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestUsesUnitsDoNotBecomeDocumentSymbols(AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value :=
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'uses SysUtils, Classes;' + LineEnding +
      'type' + LineEnding +
      '  TSample = class end;' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    AContext.AssertFalse(NXLSHasDocumentSymbol(lResult, 'SysUtils'),
      'Uses unit SysUtils should not appear as a document symbol.');
    AContext.AssertFalse(NXLSHasDocumentSymbol(lResult, 'Classes'),
      'Uses unit Classes should not appear as a document symbol.');
    AContext.AssertTrue(NXLSHasDocumentSymbol(lResult, 'TSample'),
      'Real declarations should still appear as document symbols.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestInactiveDeclarationsAreNotDocumentSymbols(
  AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value :=
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type' + LineEnding +
      '  THidden = class end;' + LineEnding +
      'procedure Hidden;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      '{$IFNDEF UNKNOWN}' + LineEnding +
      'type' + LineEnding +
      '  TVisible = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    AContext.AssertFalse(NXLSHasDocumentSymbol(lResult, 'THidden'),
      'Inactive type declarations should not be document symbols.');
    AContext.AssertFalse(NXLSHasDocumentSymbol(lResult, 'Hidden'),
      'Inactive routines should not be document symbols.');
    AContext.AssertTrue(NXLSHasDocumentSymbol(lResult, 'TVisible'),
      'Active branch declarations should remain document symbols.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure TestInactiveClassMembersAreNotDocumentSymbols(
  AContext: TNXTestContext);
var
  lItem: TNXLSTextDocumentItem;
  lModel: TNXLSLSPModel;
  lParams: TNXLSDocumentSymbolParams;
  lResult: TNXJSONArray;
  lSymbol: TNXLSDocumentSymbol;
begin
  lModel := TNXLSLSPModel.Create;
  lItem := TNXLSTextDocumentItem.Create;
  lParams := TNXLSDocumentSymbolParams.Create;
  lResult := TNXJSONArray.Create;
  try
    lItem.uri.Value := 'file:///C:/workspace/Sample.pas';
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value :=
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TSample = class' + LineEnding +
      '  {$IFDEF UNKNOWN}' + LineEnding +
      '    procedure Hidden;' + LineEnding +
      '  {$ELSE}' + LineEnding +
      '    procedure Visible;' + LineEnding +
      '  {$ENDIF}' + LineEnding +
      '  end;' + LineEnding +
      'implementation' + LineEnding +
      'end.';
    lModel.OpenDocument(lItem);

    lParams.textDocument.uri.Value := lItem.uri.Value;
    lModel.Symbols.FillDocumentSymbols(lParams, lResult);

    lSymbol := NXLSFindDocumentSymbol(lResult, 'TSample');
    AContext.AssertTrue(lSymbol <> nil, 'Class symbol should exist.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'Visible') <> nil,
      'Active branch class member should be a child document symbol.');
    AContext.AssertTrue(NXLSFindChildDocumentSymbol(lSymbol, 'Hidden') = nil,
      'Inactive class member should not be a child document symbol.');
  finally
    lResult.Free;
    lParams.Free;
    lItem.Free;
    lModel.Free;
  end;
end;

procedure RegisterNXLSDocumentSymbolTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.DocumentSymbols');
  lSuite.AddTest('UsesNexusPas', @TestDocumentSymbolsUseNexusPas);
  lSuite.AddTest('RangesUseSourceTokens',
    @TestDocumentSymbolRangesUseSourceTokens);
  lSuite.AddTest('NamesAndSpecificKinds',
    @TestDocumentSymbolNamesAndSpecificKinds);
  lSuite.AddTest('ClassMembersAreNested', @TestClassMembersAreNested);
  lSuite.AddTest('RecordMembersAreNested', @TestRecordMembersAreNested);
  lSuite.AddTest('InterfaceMembersAreNested', @TestInterfaceMembersAreNested);
  lSuite.AddTest('UsesUnitsDoNotBecomeDocumentSymbols',
    @TestUsesUnitsDoNotBecomeDocumentSymbols);
  lSuite.AddTest('InactiveDeclarationsAreNotDocumentSymbols',
    @TestInactiveDeclarationsAreNotDocumentSymbols);
  lSuite.AddTest('InactiveClassMembersAreNotDocumentSymbols',
    @TestInactiveClassMembersAreNotDocumentSymbols);
end;

end.
