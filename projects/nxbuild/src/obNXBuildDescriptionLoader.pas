(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildDescriptionLoader;

{$mode objfpc}{$H+}

interface

uses
  obNXBuildDescription, obNexusScriptModel;

type
  TNXBuildDescriptionLoader = class
  public
    function LoadDescription(const AFileName: string;
      ASelectedTargets: TNexusScriptTargetSelection = nil): TNXBuildDescription;
  end;

implementation

uses
  Classes, SysUtils, TypInfo, obNexusScriptAnalysis, obNexusScriptLive,
  tpNexusScriptLive, obNXPersist, obNXBuildEntry, obNXFPCBuildOptions, obNXLLVMBuildOptions;

function NXBuildEnumValue(ATypeInfo: PTypeInfo; const AText: string): Integer;
var
  lName: string;
begin
  { The existing build-model enums use three-letter Pascal prefixes. }
  lName := GetEnumName(ATypeInfo, GetTypeData(ATypeInfo)^.MinValue);
  Result := GetEnumValue(ATypeInfo, Copy(lName, 1, 3) + AText);
  if Result < 0 then
    raise Exception.CreateFmt('Invalid %s value "%s".', [ATypeInfo^.Name, AText]);
end;

procedure NXBuildAssignValue(AObject: TObject; AProperty: PPropInfo;
  AValue: TNexusScriptLiveValue);
var
  lText: string;
  lInteger: Integer;
  lBoolean: Boolean;
  lObject: TObject;
  lItem: TNexusScriptLiveValue;
begin
  if AProperty^.PropType^.Kind = tkClass then
  begin
    lObject := GetObjectProp(AObject, AProperty);
    if not (lObject is TStrings) or (AValue.Kind <> nslvArray) then
      raise Exception.CreateFmt('Expected a text array for %s.', [AProperty^.Name]);
    (lObject as TStrings).Clear;
    for lItem in AValue.Items do
      (lObject as TStrings).Add(lItem.AsText);
    Exit;
  end;

  lText := AValue.AsText;
  case AProperty^.PropType^.Kind of
    tkSString, tkLString, tkAString, tkWString, tkUString:
      SetStrProp(AObject, AProperty, lText);
    tkInteger:
      begin
        if not TryStrToInt(lText, lInteger) then
          raise Exception.CreateFmt('Invalid Integer for %s: %s.',
            [AProperty^.Name, lText]);
        SetOrdProp(AObject, AProperty, lInteger);
      end;
    tkBool:
      begin
        if not TryStrToBool(lText, lBoolean) then
          raise Exception.CreateFmt('Invalid Boolean for %s: %s.',
            [AProperty^.Name, lText]);
        SetOrdProp(AObject, AProperty, Ord(lBoolean));
      end;
    tkEnumeration:
      SetOrdProp(AObject, AProperty,
        NXBuildEnumValue(AProperty^.PropType, lText));
  else
    raise Exception.CreateFmt('Unsupported build property %s.', [AProperty^.Name]);
  end;
end;

procedure NXBuildAssignDefinition(AObject: TObject;
  ADefinition: TNexusScriptLiveDefinition);
var
  lProperty: TNexusScriptLiveProperty;
  lChild: TNexusScriptLiveDefinition;
  lPropInfo: PPropInfo;
  lObject: TObject;
  lDescription: TNXBuildDescription;
begin
  if AObject is TNXPersistObject then
    (AObject as TNXPersistObject).Name := ADefinition.Name;
  for lProperty in ADefinition.Properties do
  begin
    lPropInfo := GetPropInfo(AObject.ClassInfo, lProperty.Name);
    if lPropInfo = nil then
      raise Exception.CreateFmt('Unknown %s property %s.',
        [ADefinition.Kind, lProperty.Name]);
    NXBuildAssignValue(AObject, lPropInfo, lProperty.Value);
  end;
  for lChild in ADefinition.Children do
  begin
    if AObject is TNXBuildDescription then
    begin
      lDescription := AObject as TNXBuildDescription;
      if SameText(lChild.Kind, 'FPC') then
        lObject := TNXFPCBuildOptions.Create
      else if SameText(lChild.Kind, 'LLVM') then
        lObject := TNXLLVMBuildOptions.Create
      else
        raise Exception.CreateFmt('Unsupported build type: %s.', [lChild.Kind]);
      try
        NXBuildAssignDefinition(lObject, lChild);
        if lDescription.Builds.IndexOf((lObject as TNXBuildEntry).Name) >= 0 then
          raise Exception.CreateFmt('Duplicate build name: %s.',
            [(lObject as TNXBuildEntry).Name]);
        lDescription.Builds.Add(lObject as TNXBuildEntry);
      except
        lObject.Free;
        raise;
      end;
      Continue;
    end;
    lPropInfo := GetPropInfo(AObject.ClassInfo, lChild.Kind);
    if (lPropInfo = nil) or (lPropInfo^.PropType^.Kind <> tkClass) then
      raise Exception.CreateFmt('Unknown %s section %s.',
        [ADefinition.Kind, lChild.Kind]);
    lObject := GetObjectProp(AObject, lPropInfo);
    if (lObject = nil) or (lObject is TStrings) then
      raise Exception.CreateFmt('Invalid build section %s.', [lChild.Kind]);
    NXBuildAssignDefinition(lObject, lChild);
  end;
end;

function TNXBuildDescriptionLoader.LoadDescription(const AFileName: string;
  ASelectedTargets: TNexusScriptTargetSelection): TNXBuildDescription;
var
  lAnalysis: TNexusScriptAnalysis;
  lLive: TNexusScriptLiveDocument;
begin
  if not FileExists(AFileName) then
    raise Exception.CreateFmt('NexusScript project file was not found: %s', [AFileName]);

  lAnalysis := TNexusScriptAnalysis.Create(ExpandFileName(AFileName), 1, nil, ASelectedTargets);
  lLive := nil;
  try
    lAnalysis.Execute;
    if not lAnalysis.Succeeded then
      raise Exception.Create(lAnalysis.Session.LastError);
    if lAnalysis.EntryCompiler.CompiledDocument.DialectDocument = nil then
      raise Exception.Create('nxbuild requires a NexusScript dialect declaration.');
    if lAnalysis.Language.DiagnosticCount <> 0 then
      raise Exception.Create(lAnalysis.Language.Diagnostics[0].MessageText);
    if lAnalysis.Validator.Diagnostics.Count <> 0 then
      raise Exception.Create(lAnalysis.Validator.Diagnostics[0].MessageText);

    lLive := TNexusScriptLiveEmitter.Emit(lAnalysis.EntryCompiler.CompiledDocument);
    if (lLive.Roots.Count <> 1) or
      (not SameText(lLive.Roots[0].Kind, 'Project') and
       not SameText(lLive.Roots[0].Kind, 'Package')) then
      raise Exception.Create('nxbuild requires exactly one Project or Package root.');

    Result := TNXBuildDescription.Create;
    try
      Result.Kind := lLive.Roots[0].Kind;
      Result.FileName := ExpandFileName(AFileName);
      NXBuildAssignDefinition(Result, lLive.Roots[0]);
      if Result.RootDirectory = '' then
        Result.RootDirectory := ExtractFileDir(Result.FileName)
      else
        Result.RootDirectory := TNXBuildEntry.ResolvePath(Result.RootDirectory,
          ExtractFileDir(Result.FileName));
      Result.ResolvePaths;
    except
      Result.Free;
      raise;
    end;
  finally
    lLive.Free;
    lAnalysis.Free;
  end;
end;

end.
