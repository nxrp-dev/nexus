(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit utNXForgePaths;

{$mode delphi}{$H+}

interface

uses obNexusScriptModel, fpjson;

function ForgeValuePath(AValue: TNexusScriptCompiledValue;
  const AWorkingDirectory: string; AUseOrigin: Boolean = False): string;
procedure NormalizeForgeCommandPaths(AOperation: TNexusScriptCompiledDefinition;
  AContext: TJSONObject; const AWorkingDirectory: string);

implementation

uses SysUtils, obNexusScriptArtifactModel, tpNexusScript;

function PathOrigin(AValue: TNexusScriptCompiledValue;
  var AUseOrigin: Boolean): TNexusScriptCompiledValue;
begin
  if AValue.Kind = nsvReference then AUseOrigin := True;
  Result := AValue.ArtifactValue;
  while Result.Kind = nsvReference do
  begin
    AUseOrigin := True;
    if Result.ResolvedProperty <> nil then Result := Result.ResolvedProperty.Value.ArtifactValue
    else if Result.ResolvedValue <> nil then Result := Result.ResolvedValue.ArtifactValue
    else Break;
  end;
end;

function ForgeValuePath(AValue: TNexusScriptCompiledValue;
  const AWorkingDirectory: string; AUseOrigin: Boolean): string;
var
  lValue: TNexusScriptCompiledValue;
  lBase: string;
begin
  lValue := PathOrigin(AValue, AUseOrigin);
  Result := AValue.EffectiveText;
  if (Result = '') then Exit;
  if (ExtractFileDrive(Result) <> '') or IsPathDelimiter(Result, 1) then Exit;
  lBase := AWorkingDirectory;
  if AUseOrigin then lBase := ExtractFileDir(lValue.SourceRange.SourceName);
  Result := ExpandFileName(IncludeTrailingPathDelimiter(lBase) + Result);
end;

procedure NormalizeForgeCommandPaths(AOperation: TNexusScriptCompiledDefinition;
  AContext: TJSONObject; const AWorkingDirectory: string);
const
  cArrays: array[0..5] of string = ('Source', 'UnitPaths', 'IncludePaths',
    'LibraryPaths', 'ObjectPaths', 'Objects');
  cScalars: array[0..2] of string = ('Output', 'UnitOutput', 'CompilerUtilitiesPath');
var
  lName: string;
  lProperty: TNexusScriptCompiledProperty;
  lArray, lItem: TNexusScriptCompiledValue;
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
      if lOrigin or (lItem.Kind = nsvReference) then
        TJSONArray(lJSON).Strings[lIndex] := ForgeValuePath(lItem, AWorkingDirectory, lOrigin);
    end;
  end;
  for lName in cScalars do
  begin
    lProperty := AOperation.FindProperty(lName);
    if (lProperty <> nil) and (AContext.Find(lName) <> nil) and
      (lProperty.Value.Kind = nsvReference) then
      AContext.Strings[lName] := ForgeValuePath(lProperty.Value, AWorkingDirectory);
  end;
end;

end.
