unit tsNXLSLegacySymbolTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSLegacySymbolTests(ARegistry: TNXTestRegistry);

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
  cWorkspaceUnit =
    'unit TestWorkspace;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TMyClass = class' + LineEnding +
    '    procedure MethodA;' + LineEnding +
    '    function MethodB: Integer;' + LineEnding +
    '  end;' + LineEnding +
    '  TMyRecord = record' + LineEnding +
    '    Field1: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'function GlobalFunc: Boolean;' + LineEnding +
    'procedure GlobalProc;' + LineEnding +
    'implementation' + LineEnding +
    'procedure TMyClass.MethodA;' + LineEnding +
    'begin end;' + LineEnding +
    'function TMyClass.MethodB: Integer;' + LineEnding +
    'begin Result := 0; end;' + LineEnding +
    'function GlobalFunc: Boolean;' + LineEnding +
    'begin Result := True; end;' + LineEnding +
    'procedure GlobalProc;' + LineEnding +
    'begin end;' + LineEnding +
    'end.';

  cSublimeUnit =
    'unit TestUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TForward = class;' + LineEnding +
    '  TMyClass = class' + LineEnding +
    '    procedure MethodA;' + LineEnding +
    '    function MethodB: Integer;' + LineEnding +
    '  end;' + LineEnding +
    '  TMyRecord = record' + LineEnding +
    '    Field1: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'function GlobalFunc: Boolean;' + LineEnding +
    'implementation' + LineEnding +
    'type' + LineEnding +
    '  TImplOnlyClass = class' + LineEnding +
    '    procedure ImplMethod;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TMyClass.MethodA;' + LineEnding +
    '  procedure NestedProc;' + LineEnding +
    '  begin end;' + LineEnding +
    'begin NestedProc; end;' + LineEnding +
    'function TMyClass.MethodB: Integer;' + LineEnding +
    'begin Result := 0; end;' + LineEnding +
    'procedure TImplOnlyClass.ImplMethod;' + LineEnding +
    'begin end;' + LineEnding +
    'function GlobalFunc: Boolean;' + LineEnding +
    'begin Result := True; end;' + LineEnding +
    'end.';

  cEnumUnit =
    'unit TestEnumUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TColor = (clRed, clGreen, clBlue);' + LineEnding +
    '  TStatus = (stPending, stActive, stDone);' + LineEnding +
    'implementation end.';

  cTypeAliasUnit =
    'unit TestTypeAliasUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TMyInteger = Integer;' + LineEnding +
    '  PInteger = ^Integer;' + LineEnding +
    '  TMySet = set of Byte;' + LineEnding +
    'implementation end.';

  cConstUnit =
    'unit TestConstUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'const' + LineEnding +
    '  MAX_SIZE = 100;' + LineEnding +
    '  DEFAULT_NAME = ''Test'';' + LineEnding +
    'implementation end.';

  cVarUnit =
    'unit TestVarUnit;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'interface' + LineEnding +
    'var' + LineEnding +
    '  GlobalCounter: Integer;' + LineEnding +
    '  AppName: String;' + LineEnding +
    'implementation end.';

  cProgramFile =
    'program TestProgram;' + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding +
    'procedure DoWork;' + LineEnding +
    'begin end;' + LineEnding +
    'begin DoWork; end.';

function NXLSCreateTempSource(const AText: string; const AExt: string = '.pas'): string;
var
  lTempFile: string;
  lFile: TextFile;
begin
  lTempFile := GetTempFileName('', 'nxls');
  Result := ChangeFileExt(lTempFile, AExt);
  if (lTempFile <> Result) and FileExists(lTempFile) then
    DeleteFile(lTempFile);

  AssignFile(lFile, Result);
  try
    Rewrite(lFile);
    Write(lFile, AText);
  finally
    CloseFile(lFile);
  end;
end;

function NXLSCreateTempDir(const APrefix: string): string;
var
  lTempFile: string;
begin
  lTempFile := GetTempFileName('', APrefix);
  if FileExists(lTempFile) then
    DeleteFile(lTempFile);

  Result := lTempFile + '_dir';
  ForceDirectories(Result);
end;

function NXLSOpenModelWithDocument(const AText: string; out AModel: TNXLSLSPModel;
  out AFileName: string): string;
var
  lItem: TNXLSTextDocumentItem;
begin
  AFileName := NXLSCreateTempSource(AText);
  Result := NXLSPathToFileURI(AFileName);
  AModel := TNXLSLSPModel.Create;
  TNXLSLSPModel.SetCurrent(AModel);
  lItem := TNXLSTextDocumentItem.Create;
  try
    lItem.uri.Value := Result;
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value := AText;
    AModel.OpenDocument(lItem);
    AModel.ReindexDocument(AModel.RequireDocument(Result));
  finally
    lItem.Free;
  end;
end;

function NXLSDocumentSymbols(const AText: string): TJSONArray;
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSDocumentSymbolParams;
  lValue: TNXJSONValue;
  lJSON: TJSONData;
begin
  Result := nil;
  lURI := NXLSOpenModelWithDocument(AText, lModel, lFileName);
  try
    lParams := TNXLSDocumentSymbolParams.Create;
    try
      lParams.textDocument.uri.Value := lURI;
      lValue := lModel.Symbols.DocumentSymbol(lParams);
      try
        lJSON := lValue.ToJSONData;
        if lJSON is TJSONArray then
          Result := TJSONArray(lJSON)
        else
          lJSON.Free;
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
  end;
end;

function NXLSWorkspaceSymbols(const AText, AQuery: string): TJSONArray;
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lParams: TNXLSWorkspaceSymbolParams;
  lValue: TNXJSONValue;
  lJSON: TJSONData;
begin
  Result := nil;
  lURI := NXLSOpenModelWithDocument(AText, lModel, lFileName);
  try
    lParams := TNXLSWorkspaceSymbolParams.Create;
    try
      lParams.query.Value := AQuery;
      lValue := lModel.Symbols.WorkspaceSymbol(lParams);
      try
        lJSON := lValue.ToJSONData;
        if lJSON is TJSONArray then
          Result := TJSONArray(lJSON)
        else
          lJSON.Free;
      finally
        lValue.Free;
      end;
    finally
      lParams.Free;
    end;
  finally
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
  end;
end;

function NXLSJSONName(AObject: TJSONObject): string;
var
  lValue: TJSONData;
begin
  Result := '';
  if AObject = nil then
    Exit;
  lValue := AObject.Find('name');
  if lValue <> nil then
    Result := lValue.AsString;
end;

function NXLSHasField(AObject: TJSONObject; const AName: string): Boolean;
begin
  Result := (AObject <> nil) and (AObject.Find(AName) <> nil);
end;

function NXLSFindSymbol(AArray: TJSONArray; const AName: string): TJSONObject;
var
  lIdx: Integer;
  lObj: TJSONObject;
  lChildren: TJSONData;
begin
  Result := nil;
  if AArray = nil then
    Exit;
  for lIdx := 0 to AArray.Count - 1 do
    if AArray.Items[lIdx] is TJSONObject then
    begin
      lObj := TJSONObject(AArray.Items[lIdx]);
      if SameText(NXLSJSONName(lObj), AName) then
        Exit(lObj);
      lChildren := lObj.Find('children');
      if lChildren is TJSONArray then
      begin
        Result := NXLSFindSymbol(TJSONArray(lChildren), AName);
        if Result <> nil then
          Exit;
      end;
    end;
end;

function NXLSCountSymbol(AArray: TJSONArray; const AName: string): Integer;
var
  lIdx: Integer;
  lObj: TJSONObject;
  lChildren: TJSONData;
begin
  Result := 0;
  if AArray = nil then
    Exit;
  for lIdx := 0 to AArray.Count - 1 do
    if AArray.Items[lIdx] is TJSONObject then
    begin
      lObj := TJSONObject(AArray.Items[lIdx]);
      if SameText(NXLSJSONName(lObj), AName) then
        Inc(Result);
      lChildren := lObj.Find('children');
      if lChildren is TJSONArray then
        Inc(Result, NXLSCountSymbol(TJSONArray(lChildren), AName));
    end;
end;

procedure NXLSAssertHasSymbol(AContext: TNXTestContext; AArray: TJSONArray;
  const AName: string);
begin
  AContext.AssertTrue(NXLSFindSymbol(AArray, AName) <> nil,
    'Expected symbol: ' + AName);
end;

procedure NXLSAssertNoSymbol(AContext: TNXTestContext; AArray: TJSONArray;
  const AName: string);
begin
  AContext.AssertTrue(NXLSFindSymbol(AArray, AName) = nil,
    'Unexpected symbol: ' + AName);
end;

procedure TestDocumentSymbolExtractionHierarchical(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cWorkspaceUnit);
  try
    AContext.AssertTrue(lSymbols <> nil, 'Document symbols should return an array.');
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyClass');
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyRecord');
    NXLSAssertHasSymbol(AContext, lSymbols, 'GlobalFunc');
  finally
    lSymbols.Free;
  end;
end;

procedure TestDocumentSymbolExtractionFlat(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lJSON: string;
begin
  lSymbols := NXLSDocumentSymbols(cWorkspaceUnit);
  try
    lJSON := lSymbols.AsJSON;
    AContext.AssertFalse(Pos('"children"', lJSON) > 0,
      'Legacy flat output should not contain children fields.');
  finally
    lSymbols.Free;
  end;
end;

procedure TestForwardDeclarationSkipped(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    AContext.AssertEquals(0, NXLSCountSymbol(lSymbols, 'TForward'),
      'Forward declarations should not be reported as document symbols.');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSelectionRangeHasNonZeroWidth(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lSymbol: TJSONObject;
  lRange: TJSONObject;
  lStartChar: Integer;
  lEndChar: Integer;
begin
  lSymbols := NXLSDocumentSymbols(cWorkspaceUnit);
  try
    lSymbol := NXLSFindSymbol(lSymbols, 'TMyClass');
    AContext.AssertTrue(lSymbol <> nil, 'TMyClass should exist.');
    lRange := TJSONObject(lSymbol.Find('selectionRange'));
    AContext.AssertTrue(lRange <> nil, 'Symbol should include selectionRange.');
    lStartChar := lRange.Objects['start'].Integers['character'];
    lEndChar := lRange.Objects['end'].Integers['character'];
    AContext.AssertTrue(lEndChar > lStartChar,
      'Selection range should identify the symbol name, not a zero-width point.');
  finally
    lSymbols.Free;
  end;
end;

procedure TestRangeValidity(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lIdx: Integer;
  lSymbol: TJSONObject;
  lRange: TJSONObject;
begin
  lSymbols := NXLSDocumentSymbols(cWorkspaceUnit);
  try
    for lIdx := 0 to lSymbols.Count - 1 do
      if lSymbols.Items[lIdx] is TJSONObject then
      begin
        lSymbol := TJSONObject(lSymbols.Items[lIdx]);
        lRange := TJSONObject(lSymbol.Find('range'));
        AContext.AssertTrue(lRange <> nil, 'Every top-level symbol should have a range.');
        AContext.AssertTrue(lRange.Objects['end'].Integers['line'] >=
          lRange.Objects['start'].Integers['line'], 'Range end should not precede start.');
      end;
  finally
    lSymbols.Free;
  end;
end;

procedure TestEnumSymbolsHierarchical(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cEnumUnit);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'TColor');
    NXLSAssertHasSymbol(AContext, lSymbols, 'clRed');
    NXLSAssertHasSymbol(AContext, lSymbols, 'TStatus');
  finally
    lSymbols.Free;
  end;
end;

procedure TestTypeAliasSymbolsHierarchical(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cTypeAliasUnit);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyInteger');
    NXLSAssertHasSymbol(AContext, lSymbols, 'PInteger');
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMySet');
  finally
    lSymbols.Free;
  end;
end;

procedure TestConstantSymbolsHierarchical(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cConstUnit);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'MAX_SIZE');
    NXLSAssertHasSymbol(AContext, lSymbols, 'DEFAULT_NAME');
  finally
    lSymbols.Free;
  end;
end;

procedure TestGlobalVarSymbolsHierarchical(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cVarUnit);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'GlobalCounter');
    NXLSAssertHasSymbol(AContext, lSymbols, 'AppName');
  finally
    lSymbols.Free;
  end;
end;

procedure TestProgramFileSymbols(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cProgramFile);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'DoWork');
  finally
    lSymbols.Free;
  end;
end;

procedure TestWorkspaceReturnsSymbolInformationFormat(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lSymbol: TJSONObject;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, '');
  try
    AContext.AssertTrue(lSymbols <> nil, 'Workspace symbols should return an array.');
    AContext.AssertTrue(lSymbols.Count > 0, 'Workspace symbol index should not be empty.');
    lSymbol := TJSONObject(lSymbols.Items[0]);
    AContext.AssertTrue(NXLSHasField(lSymbol, 'name'), 'Workspace symbol should have name.');
    AContext.AssertTrue(NXLSHasField(lSymbol, 'kind'), 'Workspace symbol should have kind.');
  finally
    lSymbols.Free;
  end;
end;

procedure TestWorkspaceHasLocationField(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lIdx: Integer;
  lSymbol: TJSONObject;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, '');
  try
    for lIdx := 0 to lSymbols.Count - 1 do
    begin
      lSymbol := TJSONObject(lSymbols.Items[lIdx]);
      AContext.AssertTrue(NXLSHasField(lSymbol, 'location'),
        'WorkspaceSymbol should expose SymbolInformation.location.');
    end;
  finally
    lSymbols.Free;
  end;
end;

procedure TestWorkspaceNoChildrenField(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lIdx: Integer;
  lSymbol: TJSONObject;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, '');
  try
    for lIdx := 0 to lSymbols.Count - 1 do
    begin
      lSymbol := TJSONObject(lSymbols.Items[lIdx]);
      AContext.AssertFalse(NXLSHasField(lSymbol, 'children'),
        'WorkspaceSymbol items should not contain DocumentSymbol.children.');
    end;
  finally
    lSymbols.Free;
  end;
end;

procedure TestWorkspaceNoSelectionRangeField(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lIdx: Integer;
  lSymbol: TJSONObject;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, '');
  try
    for lIdx := 0 to lSymbols.Count - 1 do
    begin
      lSymbol := TJSONObject(lSymbols.Items[lIdx]);
      AContext.AssertFalse(NXLSHasField(lSymbol, 'selectionRange'),
        'WorkspaceSymbol items should not contain DocumentSymbol.selectionRange.');
    end;
  finally
    lSymbols.Free;
  end;
end;

procedure TestWorkspaceQueryFilterByName(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, 'MyClass');
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyClass');
    NXLSAssertNoSymbol(AContext, lSymbols, 'GlobalFunc');
  finally
    lSymbols.Free;
  end;
end;

procedure TestWorkspaceQueryFilterCaseInsensitive(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, 'myclass');
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyClass');
  finally
    lSymbols.Free;
  end;
end;

procedure TestWorkspaceEmptyQueryReturnsAll(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, '');
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyClass');
    NXLSAssertHasSymbol(AContext, lSymbols, 'GlobalFunc');
    NXLSAssertHasSymbol(AContext, lSymbols, 'GlobalProc');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSublimeFlatModeHasLocation(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lJSON: string;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    lJSON := lSymbols.AsJSON;
    AContext.AssertTrue(Pos('"location"', lJSON) > 0,
      'Legacy Sublime flat output should expose SymbolInformation.location.');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSublimeFlatModeNoChildren(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    AContext.AssertFalse(Pos('"children"', lSymbols.AsJSON) > 0,
      'Legacy Sublime flat output should not contain children.');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSublimeMethodNaming(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyClass.MethodA');
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyClass.MethodB');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSublimeNoContainers(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    NXLSAssertNoSymbol(AContext, lSymbols, 'interface');
    NXLSAssertNoSymbol(AContext, lSymbols, 'implementation');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSublimeClassesAtTopLevel(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
  lIdx: Integer;
  lFound: Boolean;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    lFound := False;
    for lIdx := 0 to lSymbols.Count - 1 do
      if (lSymbols.Items[lIdx] is TJSONObject) and
        SameText(NXLSJSONName(TJSONObject(lSymbols.Items[lIdx])), 'TMyClass') then
        lFound := True;
    AContext.AssertTrue(lFound, 'TMyClass should appear at top level.');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSublimeGlobalFuncPreserved(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'GlobalFunc');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSublimeNestedProcPreserved(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSDocumentSymbols(cSublimeUnit);
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'TMyClass.MethodA.NestedProc');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSymbolPersistenceReindexDocument(AContext: TNXTestContext);
var
  lSymbols: TJSONArray;
begin
  lSymbols := NXLSWorkspaceSymbols(cWorkspaceUnit, 'GlobalFunc');
  try
    NXLSAssertHasSymbol(AContext, lSymbols, 'GlobalFunc');
  finally
    lSymbols.Free;
  end;
end;

procedure TestSymbolPersistenceModifiedDocument(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lFileName: string;
  lURI: string;
  lDoc: TNXLSDocument;
  lParams: TNXLSWorkspaceSymbolParams;
  lValue: TNXJSONValue;
  lJSON: TJSONData;
  lSymbols: TJSONArray;
begin
  lURI := NXLSOpenModelWithDocument(cWorkspaceUnit, lModel, lFileName);
  try
    lDoc := lModel.RequireDocument(lURI);
    lDoc.SaveText(StringReplace(cWorkspaceUnit, 'end.', 'procedure AddedProc; begin end;' + LineEnding + 'end.', []));
    lModel.ReindexDocument(lDoc);
    lParams := TNXLSWorkspaceSymbolParams.Create;
    try
      lParams.query.Value := 'AddedProc';
      lValue := lModel.Symbols.WorkspaceSymbol(lParams);
      try
        lJSON := lValue.ToJSONData;
        try
          AContext.AssertTrue(lJSON is TJSONArray, 'WorkspaceSymbol should return an array.');
          lSymbols := TJSONArray(lJSON);
          NXLSAssertHasSymbol(AContext, lSymbols, 'AddedProc');
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
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
  end;
end;

procedure TestScanAllFiles(AContext: TNXTestContext);
var
  lDir: string;
  lFileName: string;
  lFile: TextFile;
  lModel: TNXLSLSPModel;
  lInitParams: TNXLSInitializeParams;
  lWorkspaceParams: TNXLSWorkspaceSymbolParams;
  lObject: TJSONObject;
  lValue: TNXJSONValue;
  lJSON: TJSONData;
  lSymbols: TJSONArray;
begin
  lDir := NXLSCreateTempDir('nxls');
  lFileName := IncludeTrailingPathDelimiter(lDir) + 'scanned_unit.pas';
  AssignFile(lFile, lFileName);
  try
    Rewrite(lFile);
    Write(lFile, 'unit ScannedUnit; interface type TScannedClass = class end; implementation end.');
  finally
    CloseFile(lFile);
  end;

  lModel := TNXLSLSPModel.Create;
  try
    lInitParams := TNXLSInitializeParams.Create;
    lObject := TJSONObject.Create;
    try
      lObject.Add('rootPath', lDir);
      lInitParams.FromJSONData(lObject);
      lModel.BeginInitialize(lInitParams);
    finally
      lObject.Free;
      lInitParams.Free;
    end;

    lWorkspaceParams := TNXLSWorkspaceSymbolParams.Create;
    try
      lWorkspaceParams.query.Value := 'TScannedClass';
      lValue := lModel.Symbols.WorkspaceSymbol(lWorkspaceParams);
      try
        lJSON := lValue.ToJSONData;
        try
          AContext.AssertTrue(lJSON is TJSONArray, 'WorkspaceSymbol should return an array.');
          lSymbols := TJSONArray(lJSON);
          NXLSAssertHasSymbol(AContext, lSymbols, 'TScannedClass');
        finally
          lJSON.Free;
        end;
      finally
        lValue.Free;
      end;
    finally
      lWorkspaceParams.Free;
    end;
  finally
    lModel.Free;
    if FileExists(lFileName) then
      DeleteFile(lFileName);
    RemoveDir(lDir);
  end;
end;

procedure RegisterNXLSLegacySymbolTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.Legacy.DocumentSymbol');
  lSuite.AddTest('SymbolExtractionHierarchical', @TestDocumentSymbolExtractionHierarchical);
  lSuite.AddTest('SymbolExtractionFlat', @TestDocumentSymbolExtractionFlat);
  lSuite.AddTest('ForwardDeclarationSkipped', @TestForwardDeclarationSkipped);
  lSuite.AddTest('SelectionRangeHasNonZeroWidth', @TestSelectionRangeHasNonZeroWidth);
  lSuite.AddTest('RangeValidity', @TestRangeValidity);
  lSuite.AddTest('EnumSymbolsHierarchical', @TestEnumSymbolsHierarchical);
  lSuite.AddTest('TypeAliasSymbolsHierarchical', @TestTypeAliasSymbolsHierarchical);
  lSuite.AddTest('ConstantSymbolsHierarchical', @TestConstantSymbolsHierarchical);
  lSuite.AddTest('GlobalVarSymbolsHierarchical', @TestGlobalVarSymbolsHierarchical);
  lSuite.AddTest('ProgramFileSymbols', @TestProgramFileSymbols);

  lSuite := ARegistry.AddSuite('NexusLS.Legacy.WorkspaceSymbol');
  lSuite.AddTest('ReturnsSymbolInformationFormat', @TestWorkspaceReturnsSymbolInformationFormat);
  lSuite.AddTest('HasLocationField', @TestWorkspaceHasLocationField);
  lSuite.AddTest('NoChildrenField', @TestWorkspaceNoChildrenField);
  lSuite.AddTest('NoSelectionRangeField', @TestWorkspaceNoSelectionRangeField);
  lSuite.AddTest('QueryFilterByName', @TestWorkspaceQueryFilterByName);
  lSuite.AddTest('QueryFilterCaseInsensitive', @TestWorkspaceQueryFilterCaseInsensitive);
  lSuite.AddTest('EmptyQueryReturnsAll', @TestWorkspaceEmptyQueryReturnsAll);

  lSuite := ARegistry.AddSuite('NexusLS.Legacy.SublimeProfile');
  lSuite.AddTest('FlatModeHasLocation', @TestSublimeFlatModeHasLocation);
  lSuite.AddTest('FlatModeNoChildren', @TestSublimeFlatModeNoChildren);
  lSuite.AddTest('FlatModeMethodNaming', @TestSublimeMethodNaming);
  lSuite.AddTest('NoInterfaceOrImplementationContainers', @TestSublimeNoContainers);
  lSuite.AddTest('ClassesAtTopLevel', @TestSublimeClassesAtTopLevel);
  lSuite.AddTest('GlobalFuncPreserved', @TestSublimeGlobalFuncPreserved);
  lSuite.AddTest('NestedProcPreserved', @TestSublimeNestedProcPreserved);

  lSuite := ARegistry.AddSuite('NexusLS.Legacy.SymbolPersistence');
  lSuite.AddTest('ReindexDocument', @TestSymbolPersistenceReindexDocument);
  lSuite.AddTest('ModifiedDocumentUpdatesIndex', @TestSymbolPersistenceModifiedDocument);

  lSuite := ARegistry.AddSuite('NexusLS.Legacy.ScanExamples');
  lSuite.AddTest('ScanAllFiles', @TestScanAllFiles);
end;

end.
