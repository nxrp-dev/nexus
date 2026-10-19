(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildDescriptionLoader;

{$mode objfpc}{$H+}

interface

uses
  obNXBuildDescription, obNexusScriptModel, obNexusScriptAnalysis;

type
  TNXBuildDescriptionLoader = class
  public
    function LoadAnalysis(AAnalysis: TNexusScriptAnalysis;
      ASelectedTargets: TNexusScriptTargetSelection): TNXBuildDescription;
    function LoadDescription(const AFileName: string;
      ASelectedTargets: TNexusScriptTargetSelection = nil): TNXBuildDescription;
  end;

implementation

uses
  Classes, SysUtils, TypInfo, obNexusScriptLive,
  tpNexusScriptLive, obNXPersist, obNXBuildEntry, obNXFPCBuildOptions, obNXLLVMBuildOptions,
  obNXBuildRequirement, obNXProcessBuildOptions;

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

procedure NXBuildAssignRequirements(ADescription: TNXBuildDescription;
  AValue: TNexusScriptLiveValue);
var
  lItem: TNexusScriptLiveValue;
  lReference: TNexusScriptLiveDefinition;
  lId, lDescriptor, lLocation: string;
begin
  if AValue.Kind <> nslvArray then
    raise Exception.Create('Project Requires must be an array of project references.');
  for lItem in AValue.Items do
  begin
    if (lItem.Reference = nil) or
      not (lItem.Reference.Target is TNexusScriptLiveDefinition) then
      raise Exception.Create('A project requirement must reference a ProjectReference record.');
    lReference := lItem.Reference.Target as TNexusScriptLiveDefinition;
    if not SameText(lReference.Kind, 'ProjectReference') then
      raise Exception.Create('A project requirement must reference a ProjectReference record.');
    if (lReference.FindProperty('Id') = nil) or
      (lReference.FindProperty('Descriptor') = nil) then
      raise Exception.CreateFmt('%s: ProjectReference %s requires Id and Descriptor.',
        [lReference.SourceRange.SourceName, lReference.Name]);
    lId := lReference.FindProperty('Id').Value.AsText;
    lDescriptor := lReference.FindProperty('Descriptor').Value.AsText;
    if (Trim(lId) = '') or (Trim(lDescriptor) = '') or
      (Pos('://', lDescriptor) <> 0) or (Pos('*', lDescriptor) <> 0) or
      (Pos('?', lDescriptor) <> 0) then
      raise Exception.Create('Project references require a nonempty Id and a local descriptor filename.');
    lDescriptor := TNXBuildEntry.ResolvePath(lDescriptor,
      ExtractFileDir(lReference.SourceRange.SourceName));
    lLocation := Format('%s(%d,%d)', [lItem.SourceRange.SourceName,
      lItem.SourceRange.StartPosition.Line, lItem.SourceRange.StartPosition.Column]);
    ADescription.Requirements.Add(TNXBuildRequirement.Create(lId, lDescriptor, lLocation));
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
    if (AObject is TNXBuildDescription) and SameText(lProperty.Name, 'Requires') then
    begin
      NXBuildAssignRequirements(AObject as TNXBuildDescription, lProperty.Value);
      Continue;
    end;
    lPropInfo := GetPropInfo(AObject.ClassInfo, lProperty.Name);
    if lPropInfo = nil then
      raise Exception.CreateFmt('Unknown %s property %s.',
        [ADefinition.Kind, lProperty.Name]);
    NXBuildAssignValue(AObject, lPropInfo, lProperty.Value);
  end;
  for lChild in ADefinition.Children do
  begin
    if (AObject is TNXBuildDescription) and not SameText(lChild.Kind, 'Publishes') then
    begin
      lDescription := AObject as TNXBuildDescription;
      if SameText(lChild.Kind, 'FPC') then
        lObject := TNXFPCBuildOptions.Create
      else if SameText(lChild.Kind, 'LLVM') then
        lObject := TNXLLVMBuildOptions.Create
      else if SameText(lChild.Kind, 'Process') then
        lObject := TNXProcessBuildOptions.Create
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
begin
  if not FileExists(AFileName) then
    raise Exception.CreateFmt('NexusScript project file was not found: %s', [AFileName]);
  lAnalysis := TNexusScriptAnalysis.Create(ExpandFileName(AFileName), 1, nil, ASelectedTargets);
  try
    lAnalysis.Execute;
    Result := LoadAnalysis(lAnalysis, ASelectedTargets);
  finally
    lAnalysis.Free;
  end;
end;

function TNXBuildDescriptionLoader.LoadAnalysis(AAnalysis: TNexusScriptAnalysis;
  ASelectedTargets: TNexusScriptTargetSelection): TNXBuildDescription;
var
  lLive: TNexusScriptLiveDocument;
begin
  if AAnalysis = nil then raise Exception.Create('Project analysis is required.');
  lLive := nil;
  try
    if not AAnalysis.Succeeded then
      raise Exception.Create(AAnalysis.Session.LastError);
    if AAnalysis.EntryCompiler.CompiledDocument.DialectDocument = nil then
      raise Exception.Create('nxbuild requires a NexusScript dialect declaration.');
    if AAnalysis.Language.DiagnosticCount <> 0 then
      raise Exception.Create(AAnalysis.Language.Diagnostics[0].MessageText);
    if AAnalysis.Validator.Diagnostics.Count <> 0 then
      raise Exception.Create(AAnalysis.Validator.Diagnostics[0].MessageText);

    lLive := TNexusScriptLiveEmitter.Emit(AAnalysis.EntryCompiler.CompiledDocument);
    if (lLive.Roots.Count <> 1) or not SameText(lLive.Roots[0].Kind, 'Project') then
      raise Exception.Create('nxbuild requires exactly one Project root.');

    Result := TNXBuildDescription.Create;
    try
      Result.Kind := lLive.Roots[0].Kind;
      Result.FileName := ExpandFileName(AAnalysis.EntryName);
      NXBuildAssignDefinition(Result, lLive.Roots[0]);
      if Trim(Result.Id) = '' then
        raise Exception.Create('Project Id must not be empty.');
      Result.SelectedTargets.Assign(ASelectedTargets);
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
  end;
end;

end.
