(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXLSWorkspaceSymbolTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXLSWorkspaceSymbolTests(ARegistry: TNXTestRegistry);

implementation

uses
  Classes,
  SysUtils,
  obNXLSSymbolCache,
  obNXJSONValues,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXTestContext,
  obNXTestSuite;

const
  cWorkspaceUnit =
    'unit WorkspaceSample;' + LineEnding +
    'interface' + LineEnding +
    'uses SysUtils, Classes;' + LineEnding +
    'type' + LineEnding +
    '  TWorkspaceSample = class' + LineEnding +
    '  public' + LineEnding +
    '    procedure Run;' + LineEnding +
    '  private' + LineEnding +
    '    FValue: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'procedure DoWorkspaceWork;' + LineEnding +
    'implementation' + LineEnding +
    'end.';

function NXLSOpenWorkspaceDocument(AModel: TNXLSLSPModel;
  const AURI, AText: string): TNXLSDocument;
var
  lItem: TNXLSTextDocumentItem;
begin
  lItem := TNXLSTextDocumentItem.Create;
  try
    lItem.uri.Value := AURI;
    lItem.languageId.Value := 'pascal';
    lItem.version.Value := 1;
    lItem.text.Value := AText;
    Result := AModel.OpenDocument(lItem);
    AModel.ReindexDocument(Result);
  finally
    lItem.Free;
  end;
end;

function NXLSWorkspaceSymbols(AModel: TNXLSLSPModel;
  const AQuery: string): TNXJSONArray;
var
  lParams: TNXLSWorkspaceSymbolParams;
begin
  Result := TNXJSONArray.Create;
  lParams := TNXLSWorkspaceSymbolParams.Create;
  try
    lParams.query.Value := AQuery;
    AModel.Symbols.FillWorkspaceSymbols(lParams, Result);
  finally
    lParams.Free;
  end;
end;

function NXLSFindWorkspaceSymbol(AResult: TNXJSONArray;
  const AName: string): TNXLSWorkspaceSymbol;
var
  lIdx: Integer;
  lSymbol: TNXLSWorkspaceSymbol;
begin
  Result := nil;
  if AResult = nil then
    Exit;

  for lIdx := 0 to AResult.Count - 1 do
  begin
    lSymbol := TNXLSWorkspaceSymbol(AResult[lIdx]);
    if lSymbol.name.Value = AName then
      Exit(lSymbol);
  end;
end;

function NXLSHasWorkspaceSymbol(AResult: TNXJSONArray;
  const AName: string): Boolean;
begin
  Result := NXLSFindWorkspaceSymbol(AResult, AName) <> nil;
end;

procedure TestWorkspaceSymbolsUseNexusPasIndex(AContext: TNXTestContext);
var
  lLocation: TNXLSLocation;
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
  lSymbol: TNXLSWorkspaceSymbol;
begin
  lModel := TNXLSLSPModel.Create;
  try
    NXLSOpenWorkspaceDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cWorkspaceUnit);

    lResult := NXLSWorkspaceSymbols(lModel, 'Workspace');
    try
      AContext.AssertTrue(lResult.Assigned,
        'Workspace symbol result should be assigned.');
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'WorkspaceSample'),
        'Workspace symbols should include the unit symbol.');
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'TWorkspaceSample'),
        'Workspace symbols should include the class symbol.');
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'DoWorkspaceWork'),
        'Workspace symbols should include the routine symbol.');

      lSymbol := NXLSFindWorkspaceSymbol(lResult, 'TWorkspaceSample');
      AContext.AssertTrue(lSymbol <> nil, 'Class workspace symbol should exist.');
      AContext.AssertEquals(5, lSymbol.kind.Value,
        'Class workspace symbol should use LSP class kind.');
      AContext.AssertTrue(lSymbol.location.Value is TNXLSLocation,
        'Workspace symbol should include a full Location.');
      lLocation := TNXLSLocation(lSymbol.location.Value);
      AContext.AssertEquals('file:///C:/workspace/Sample.pas',
        lLocation.uri.Value, 'Workspace symbol location should preserve URI.');
      AContext.AssertTrue(lLocation.range.Assigned,
        'Workspace symbol location range should be assigned.');
    finally
      lResult.Free;
    end;
  finally
    lModel.Free;
  end;
end;

procedure TestWorkspaceSymbolQueryFiltersByName(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  try
    NXLSOpenWorkspaceDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cWorkspaceUnit);

    lResult := NXLSWorkspaceSymbols(lModel, 'DoWorkspace');
    try
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'DoWorkspaceWork'),
        'Matching symbol should be returned.');
      AContext.AssertFalse(NXLSHasWorkspaceSymbol(lResult, 'TWorkspaceSample'),
        'Non-matching symbol should not be returned.');
    finally
      lResult.Free;
    end;
  finally
    lModel.Free;
  end;
end;

procedure TestWorkspaceSymbolEmptyQueryReturnsIndexedSymbols(
  AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  try
    NXLSOpenWorkspaceDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cWorkspaceUnit);

    lResult := NXLSWorkspaceSymbols(lModel, '');
    try
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'WorkspaceSample'),
        'Empty workspace symbol query should return indexed unit symbols.');
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'TWorkspaceSample'),
        'Empty workspace symbol query should return indexed type symbols.');
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'Run'),
        'Empty workspace symbol query should return indexed member symbols.');
    finally
      lResult.Free;
    end;
  finally
    lModel.Free;
  end;
end;

procedure TestInactiveDeclarationsAreNotWorkspaceSymbols(
  AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  try
    NXLSOpenWorkspaceDocument(lModel, 'file:///C:/workspace/Sample.pas',
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      '{$IFDEF UNKNOWN}' + LineEnding +
      'type THidden = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      '{$IFNDEF UNKNOWN}' + LineEnding +
      'type TVisible = class end;' + LineEnding +
      '{$ENDIF}' + LineEnding +
      'implementation' + LineEnding +
      'end.');

    lResult := NXLSWorkspaceSymbols(lModel, 'T');
    try
      AContext.AssertFalse(NXLSHasWorkspaceSymbol(lResult, 'THidden'),
        'Inactive declarations should not be workspace symbols.');
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'TVisible'),
        'Active declarations should remain workspace symbols.');
    finally
      lResult.Free;
    end;
  finally
    lModel.Free;
  end;
end;

procedure TestReindexRefreshesWorkspaceSymbols(AContext: TNXTestContext);
var
  lDocument: TNXLSDocument;
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  try
    lDocument := NXLSOpenWorkspaceDocument(lModel,
      'file:///C:/workspace/Sample.pas',
      'unit Sample; interface type TFirst = class end; implementation end.');
    lDocument.SaveText(
      'unit Sample; interface type TSecond = class end; implementation end.');
    lModel.ReindexDocument(lDocument);

    lResult := NXLSWorkspaceSymbols(lModel, 'T');
    try
      AContext.AssertFalse(NXLSHasWorkspaceSymbol(lResult, 'TFirst'),
        'Reindexed document should remove stale symbols.');
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'TSecond'),
        'Reindexed document should expose updated symbols.');
    finally
      lResult.Free;
    end;
  finally
    lModel.Free;
  end;
end;

procedure TestClosedDocumentKeepsLastIndexedWorkspaceSymbols(
  AContext: TNXTestContext);
var
  lIdentifier: TNXLSTextDocumentIdentifier;
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  lIdentifier := TNXLSTextDocumentIdentifier.Create;
  try
    NXLSOpenWorkspaceDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cWorkspaceUnit);
    lIdentifier.uri.Value := 'file:///C:/workspace/Sample.pas';
    lModel.CloseDocument(lIdentifier);

    lResult := NXLSWorkspaceSymbols(lModel, 'TWorkspaceSample');
    try
      AContext.AssertTrue(NXLSHasWorkspaceSymbol(lResult, 'TWorkspaceSample'),
        'Closed documents keep their last indexed workspace symbols.');
    finally
      lResult.Free;
    end;
  finally
    lIdentifier.Free;
    lModel.Free;
  end;
end;

procedure TestUsesUnitsAreNotWorkspaceSymbols(AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  try
    NXLSOpenWorkspaceDocument(lModel, 'file:///C:/workspace/Sample.pas',
      cWorkspaceUnit);

    lResult := NXLSWorkspaceSymbols(lModel, 'SysUtils');
    try
      AContext.AssertFalse(NXLSHasWorkspaceSymbol(lResult, 'SysUtils'),
        'Uses-clause units should not appear as workspace symbols.');
    finally
      lResult.Free;
    end;
  finally
    lModel.Free;
  end;
end;

procedure TestRoutineLocalsAndParametersAreNotWorkspaceSymbols(
  AContext: TNXTestContext);
var
  lModel: TNXLSLSPModel;
  lResult: TNXJSONArray;
begin
  lModel := TNXLSLSPModel.Create;
  try
    NXLSOpenWorkspaceDocument(lModel, 'file:///C:/workspace/Sample.pas',
      'unit Sample;' + LineEnding +
      'interface' + LineEnding +
      'implementation' + LineEnding +
      'procedure DoWork(AlphaParam: Integer);' + LineEnding +
      'var' + LineEnding +
      '  AlphaLocal: Integer;' + LineEnding +
      'begin' + LineEnding +
      'end;' + LineEnding +
      'end.');

    lResult := NXLSWorkspaceSymbols(lModel, 'Alpha');
    try
      AContext.AssertFalse(NXLSHasWorkspaceSymbol(lResult, 'AlphaParam'),
        'Routine parameters should not appear as workspace symbols.');
      AContext.AssertFalse(NXLSHasWorkspaceSymbol(lResult, 'AlphaLocal'),
        'Routine-local variables should not appear as workspace symbols.');
    finally
      lResult.Free;
    end;
  finally
    lModel.Free;
  end;
end;

procedure TestSymbolCacheSQLitePersistence(AContext: TNXTestContext);
var
  lID: TGUID;
  lDirectory, lSourceFile, lDatabaseFile, lURI: string;
  lSource: TStringList;
  lCache, lLoaded: TNXLSSymbolCache;
  lFile: TNXLSSymbolCacheFile;
  lSymbol: TNXLSSymbolCacheSymbol;
begin
  CreateGUID(lID);
  lDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nexusls-sqlite-' + GUIDToString(lID) + DirectorySeparator;
  ForceDirectories(lDirectory);
  lSourceFile := lDirectory + 'Quoted.pas';
  lDatabaseFile := lDirectory + 'symbols.sqlite';
  lURI := 'file:///' + StringReplace(lSourceFile, '\', '/', [rfReplaceAll]);
  lSource := TStringList.Create;
  lCache := TNXLSSymbolCache.Create;
  lLoaded := TNXLSSymbolCache.Create;
  try
    lSource.Text := 'unit Quoted; interface implementation end.';
    lSource.SaveToFile(lSourceFile);
    lFile := lCache.ReplaceFile(lSourceFile, lURI);
    lFile.FileSize := Int64(1) shl 40;
    lSymbol := TNXLSSymbolCacheSymbol.Create;
    lFile.Symbols.Add(lSymbol);
    lSymbol.Name := 'O''Brien';
    lSymbol.Kind := 12;
    lSymbol.RangeStartLine := 7;
    lSymbol.RangeEndLine := 9;
    lSymbol.ContainerName := 'Quoted';
    lCache.Save(lDatabaseFile);
    AContext.AssertTrue(lCache.StoreAvailable, 'Saving the SQLite cache failed.');
    AContext.AssertFalse(lCache.Dirty, 'Saving should clear the dirty flag.');

    lLoaded.Load(lDatabaseFile);
    AContext.AssertTrue(lLoaded.StoreAvailable, 'Loading the SQLite cache failed.');
    lFile := lLoaded.FileByURI(lURI);
    AContext.AssertTrue(lFile <> nil, 'The persisted file was not loaded.');
    if lFile = nil then Exit;
    AContext.AssertTrue(lFile.FileSize = Int64(1) shl 40,
      'The persisted 64-bit file size changed.');
    AContext.AssertTrue(lFile.Symbols.Count = 1, 'The persisted symbol was not loaded.');
    if lFile.Symbols.Count <> 1 then Exit;
    lSymbol := TNXLSSymbolCacheSymbol(lFile.Symbols[0]);
    AContext.AssertTrue(lSymbol.Name = 'O''Brien', 'The quoted symbol name changed.');
    AContext.AssertTrue(lSymbol.URI = lURI, 'The symbol URI changed.');
    AContext.AssertTrue(lSymbol.RangeStartLine = 7, 'The symbol range changed.');
    AContext.AssertTrue(lSymbol.RangeEndLine = 9, 'The symbol range changed.');
    AContext.AssertTrue(lSymbol.ContainerName = 'Quoted', 'The symbol container changed.');

    lLoaded.RemoveFile(lURI);
    lLoaded.Save(lDatabaseFile);
    AContext.AssertTrue(lLoaded.StoreAvailable, 'Saving the removed file failed.');
    lCache.Load(lDatabaseFile);
    AContext.AssertTrue(lCache.StoreAvailable, 'Reloading the cache failed.');
    AContext.AssertTrue(lCache.FileByURI(lURI) = nil, 'The removed file was reloaded.');
  finally
    lLoaded.Free;
    lCache.Free;
    lSource.Free;
    DeleteFile(lDatabaseFile);
    DeleteFile(lSourceFile);
    RemoveDir(lDirectory);
  end;
end;

procedure RegisterNXLSWorkspaceSymbolTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('NexusLS.WorkspaceSymbols');
  lSuite.AddTest('SymbolCacheSQLitePersistence', @TestSymbolCacheSQLitePersistence);
  lSuite.AddTest('UseNexusPasIndex', @TestWorkspaceSymbolsUseNexusPasIndex);
  lSuite.AddTest('QueryFiltersByName', @TestWorkspaceSymbolQueryFiltersByName);
  lSuite.AddTest('EmptyQueryReturnsIndexedSymbols',
    @TestWorkspaceSymbolEmptyQueryReturnsIndexedSymbols);
  lSuite.AddTest('InactiveDeclarationsAreNotWorkspaceSymbols',
    @TestInactiveDeclarationsAreNotWorkspaceSymbols);
  lSuite.AddTest('ReindexRefreshesWorkspaceSymbols',
    @TestReindexRefreshesWorkspaceSymbols);
  lSuite.AddTest('ClosedDocumentKeepsLastIndexedWorkspaceSymbols',
    @TestClosedDocumentKeepsLastIndexedWorkspaceSymbols);
  lSuite.AddTest('UsesUnitsAreNotWorkspaceSymbols',
    @TestUsesUnitsAreNotWorkspaceSymbols);
  lSuite.AddTest('RoutineLocalsAndParametersAreNotWorkspaceSymbols',
    @TestRoutineLocalsAndParametersAreNotWorkspaceSymbols);
end;

end.
