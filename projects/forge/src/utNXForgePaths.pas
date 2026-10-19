(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit utNXForgePaths;

{$mode delphi}{$H+}

interface

uses obNexusScriptLive, fpjson;

function IsInternalReference(AValue: TNexusScriptLiveValue): Boolean;

function ForgeValuePath(AValue: TNexusScriptLiveValue;
  const AWorkingDirectory: string; AUseOrigin: Boolean = False): string;
procedure NormalizeForgeCommandPaths(AOperation: TNexusScriptLiveDefinition;
  AContext: TJSONObject; const AWorkingDirectory: string);

implementation

uses SysUtils, tpNexusScriptLive;

function IsInternalReference(AValue: TNexusScriptLiveValue): Boolean;
begin
  Result := (AValue.Reference <> nil) and
    (AValue.Reference.Kind = nslrInternal);
end;

function PathOrigin(AValue: TNexusScriptLiveValue;
  var AUseOrigin: Boolean): TNexusScriptLiveValue;
var
  lTarget: TNexusScriptLiveNode;
begin
  Result := AValue;
  while IsInternalReference(Result) do
  begin
    AUseOrigin := True;
    lTarget := Result.Reference.Target;
    if lTarget is TNexusScriptLiveProperty then
      Result := (lTarget as TNexusScriptLiveProperty).Value
    else if lTarget is TNexusScriptLiveValue then
      Result := lTarget as TNexusScriptLiveValue
    else Break;
  end;
end;

function ForgeValuePath(AValue: TNexusScriptLiveValue;
  const AWorkingDirectory: string; AUseOrigin: Boolean): string;
var
  lValue: TNexusScriptLiveValue;
  lBase: string;
begin
  lValue := PathOrigin(AValue, AUseOrigin);
  Result := AValue.AsText;
  if (Result = '') then Exit;
  if (ExtractFileDrive(Result) <> '') or IsPathDelimiter(Result, 1) then Exit;
  lBase := AWorkingDirectory;
  if AUseOrigin then lBase := ExtractFileDir(lValue.SourceRange.SourceName);
  Result := ExpandFileName(IncludeTrailingPathDelimiter(lBase) + Result);
end;

procedure NormalizeForgeCommandPaths(AOperation: TNexusScriptLiveDefinition;
  AContext: TJSONObject; const AWorkingDirectory: string);
const
  cArrays: array[0..8] of string = ('Source', 'UnitPaths', 'IncludePaths',
    'LibraryPaths', 'ObjectPaths', 'Objects', 'SystemIncludePaths', 'PackagePaths', 'ResponseFiles');
  cScalars: array[0..3] of string = ('Output', 'UnitOutput', 'CompilerUtilitiesPath', 'ExecutableOutput');
var
  lName: string;
  lProperty: TNexusScriptLiveProperty;
  lArray, lItem: TNexusScriptLiveValue;
  lJSON: TJSONData;
  lIndex: Integer;
  lOrigin: Boolean;
begin
  for lName in cArrays do
  begin
    lProperty := AOperation.FindProperty(lName);
    lJSON := AContext.Find(lName);
    if (lProperty = nil) or (lJSON = nil) or (lJSON.JSONType <> jtArray) then Continue;
    // Source selections always retain their declaring file. Other literal
    // tool paths retain working-directory semantics; references retain origin.
    lOrigin := SameText(lName, 'Source');
    lArray := PathOrigin(lProperty.Value, lOrigin);
    for lIndex := 0 to lArray.Items.Count - 1 do
    begin
      lItem := lArray.Items[lIndex];
      if lOrigin or IsInternalReference(lItem) then
        TJSONArray(lJSON).Strings[lIndex] := ForgeValuePath(lItem, AWorkingDirectory, lOrigin);
    end;
  end;
  for lName in cScalars do
  begin
    lProperty := AOperation.FindProperty(lName);
    if (lProperty <> nil) and (AContext.Find(lName) <> nil) and
      IsInternalReference(lProperty.Value) then
      AContext.Strings[lName] := ForgeValuePath(lProperty.Value, AWorkingDirectory);
  end;
end;

end.
