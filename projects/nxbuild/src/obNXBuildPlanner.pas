(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildPlanner;

{$mode objfpc}{$H+}

interface

uses Classes, Generics.Collections, obNXBuildDescription, obNXBuildEntry;

type
  TNXBuildStep = class
  private
    FName: string;
    FBuildType: string;
    FExecutable: string;
    FArguments: TStringList;
    FSourceFiles: TStringList;
    FSourceArgumentIndex: Integer;
    FCompileEachSource: Boolean;
    FOutputPath: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure FillArguments(ASources: TStrings; ASourceIndex: Integer; AArguments: TStrings);
    property Name: string read FName write FName;
    property BuildType: string read FBuildType write FBuildType;
    property Executable: string read FExecutable write FExecutable;
    property Arguments: TStringList read FArguments;
    property SourceFiles: TStringList read FSourceFiles;
    property SourceArgumentIndex: Integer read FSourceArgumentIndex write FSourceArgumentIndex;
    property CompileEachSource: Boolean read FCompileEachSource write FCompileEachSource;
    property OutputPath: string read FOutputPath write FOutputPath;
  end;

  TNXBuildPlan = class
  private
    FName: string;
    FKind: string;
    FSteps: specialize TObjectList<TNXBuildStep>;
  public
    constructor Create;
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Kind: string read FKind write FKind;
    property Steps: specialize TObjectList<TNXBuildStep> read FSteps;
  end;

  TNXBuildPlanner = class
  private
    function ResolveCompiler(AEntry: TNXBuildEntry;
      const ARoot: string): string;
  public
    function CreatePlan(ADescription: TNXBuildDescription): TNXBuildPlan;
    procedure WritePlan(APlan: TNXBuildPlan);
  end;

implementation

uses SysUtils;

function NXBuildQuoteArgument(const AValue: string): string;
begin
  if (AValue = '') or (Pos(' ', AValue) > 0) then
    Result := '"' + AValue + '"'
  else
    Result := AValue;
end;

constructor TNXBuildStep.Create;
begin
  inherited Create;
  FArguments := TStringList.Create;
  FSourceFiles := TStringList.Create;
end;

destructor TNXBuildStep.Destroy;
begin
  FSourceFiles.Free;
  FArguments.Free;
  inherited Destroy;
end;

procedure TNXBuildStep.FillArguments(ASources: TStrings; ASourceIndex: Integer;
  AArguments: TStrings);
var
  lIndex: Integer;
begin
  AArguments.Assign(FArguments);
  if FCompileEachSource then
    AArguments.Insert(FSourceArgumentIndex, ASources[ASourceIndex])
  else
    for lIndex := 0 to ASources.Count - 1 do
      AArguments.Insert(FSourceArgumentIndex + lIndex, ASources[lIndex]);
end;

constructor TNXBuildPlan.Create;
begin
  inherited Create;
  FSteps := specialize TObjectList<TNXBuildStep>.Create(True);
end;

destructor TNXBuildPlan.Destroy;
begin
  FSteps.Free;
  inherited Destroy;
end;

function TNXBuildPlanner.ResolveCompiler(AEntry: TNXBuildEntry;
  const ARoot: string): string;
var
  lCompiler: string;
begin
  lCompiler := AEntry.CompilerPath;
  if lCompiler = '' then
    lCompiler := AEntry.DefaultCompiler;
  {$IFDEF MSWINDOWS}
  if ExtractFileExt(lCompiler) = '' then
    lCompiler := lCompiler + '.exe';
  {$ENDIF}
  if ExtractFilePath(lCompiler) <> '' then
  begin
    Result := TNXBuildEntry.ResolvePath(lCompiler, ARoot);
    if not FileExists(Result) then
      Result := '';
  end
  else
    Result := ExeSearch(lCompiler);
  if Result = '' then
    raise Exception.CreateFmt('Build "%s" (%s): tool not found: %s.',
      [AEntry.Name, AEntry.BuildType, lCompiler]);
  Result := ExpandFileName(Result);
end;

function TNXBuildPlanner.CreatePlan(ADescription: TNXBuildDescription): TNXBuildPlan;
var
  lIndex, lSourceArgumentIndex: Integer;
  lEntry: TNXBuildEntry;
  lStep: TNXBuildStep;
begin
  if ADescription = nil then
    raise Exception.Create('Build description is required.');
  if ADescription.Builds.Count = 0 then
    raise Exception.Create('The description must contain at least one build.');

  Result := TNXBuildPlan.Create;
  try
    Result.Name := ADescription.Name;
    Result.Kind := ADescription.Kind;
    for lIndex := 0 to ADescription.Builds.Count - 1 do
    begin
      lEntry := ADescription.Builds[lIndex] as TNXBuildEntry;
      if lEntry.SourceFiles.Count = 0 then
        raise Exception.CreateFmt('Build "%s" (%s): SourceFiles must contain at least one file.',
          [lEntry.Name, lEntry.BuildType]);
      lStep := TNXBuildStep.Create;
      Result.Steps.Add(lStep);
      lStep.Name := lEntry.Name;
      lStep.BuildType := lEntry.BuildType;
      lStep.OutputPath := lEntry.OutputPath;
      lStep.Executable := ResolveCompiler(lEntry, ADescription.RootDirectory);
      lStep.CompileEachSource := lEntry.CompileEachSource;
      lStep.SourceFiles.Assign(lEntry.SourceFiles);
      lEntry.AppendArguments(lStep.Arguments, lSourceArgumentIndex);
      lStep.SourceArgumentIndex := lSourceArgumentIndex;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TNXBuildPlanner.WritePlan(APlan: TNXBuildPlan);
var
  lIndex: Integer;
  lValue: string;
  lStep: TNXBuildStep;
begin
  if APlan = nil then
    raise Exception.Create('Build plan is required.');
  WriteLn(APlan.Kind, ': ', APlan.Name);
  for lIndex := 0 to APlan.Steps.Count - 1 do
  begin
    lStep := APlan.Steps[lIndex];
    WriteLn(lIndex + 1, '. ', lStep.Name, ' (', lStep.BuildType, ')');
    WriteLn('Tool: ', lStep.Executable);
    WriteLn('Output path: ', lStep.OutputPath);
    if lStep.CompileEachSource then
      WriteLn('Sources (one invocation per file):')
    else
      WriteLn('Sources (one invocation for all files):');
    for lValue in lStep.SourceFiles do
      WriteLn('  ', lValue);
    Write('Options:');
    for lValue in lStep.Arguments do
      Write(' ', NXBuildQuoteArgument(lValue));
    WriteLn;
  end;
end;

end.
