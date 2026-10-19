(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildPlanner;

{$mode objfpc}{$H+}

interface

uses Classes, Generics.Collections, obNXBuildDescription, obNXBuildEntry,
  obNXBuildDirectories;

type
  TNXBuildStep = class
  private
    FName: string;
    FProjectId: string;
    FDirectory: string;
    FBuildType: string;
    FExecutable: string;
    FArguments: TStringList;
    FSourceFiles: TStringList;
    FSourceArgumentIndex: Integer;
    FCompileEachSource: Boolean;
    FOutputPath: string;
  protected
    function GetWorkingDirectory: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure FillArguments(ASources: TStrings; ASourceIndex: Integer; AArguments: TStrings);
    property Name: string read FName write FName;
    property ProjectId: string read FProjectId write FProjectId;
    property WorkingDirectory: string read GetWorkingDirectory write FDirectory;
    property BuildType: string read FBuildType write FBuildType;
    property Executable: string read FExecutable write FExecutable;
    property Arguments: TStringList read FArguments;
    property SourceFiles: TStringList read FSourceFiles;
    property SourceArgumentIndex: Integer read FSourceArgumentIndex write FSourceArgumentIndex;
    property CompileEachSource: Boolean read FCompileEachSource write FCompileEachSource;
    property OutputPath: string read FOutputPath write FOutputPath;
  end;

  TNXBuildPlannedProject = class
  private
    FId: string;
    FFileName: string;
    FDependencies: TStringList;
    FDirectories: TNXBuildDirectories;
  public
    constructor Create;
    destructor Destroy; override;
    property Id: string read FId write FId;
    property FileName: string read FFileName write FFileName;
    property Dependencies: TStringList read FDependencies;
    property Directories: TNXBuildDirectories read FDirectories;
  end;

  TNXBuildPlan = class
  private
    FName: string;
    FKind: string;
    FSteps: specialize TObjectList<TNXBuildStep>;
    FProjects: specialize TObjectList<TNXBuildPlannedProject>;
  public
    constructor Create;
    destructor Destroy; override;
    property Name: string read FName write FName;
    property Kind: string read FKind write FKind;
    property Steps: specialize TObjectList<TNXBuildStep> read FSteps;
    property Projects: specialize TObjectList<TNXBuildPlannedProject> read FProjects;
  end;

  TNXBuildPlanner = class
  private
    function ResolveCompiler(AEntry: TNXBuildEntry;
      const ARoot: string; APlan: TNXBuildPlan; ACheckTools: Boolean): string;
  public
    function CreatePlan(ADescription: TNXBuildDescription;
      ACheckTools: Boolean = True): TNXBuildPlan;
    procedure WriteProjects(APlan: TNXBuildPlan);
    procedure WritePlan(APlan: TNXBuildPlan);
  end;

implementation

uses SysUtils, obNXBuildProjectGraph, obNexusScriptModel;

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

function TNXBuildStep.GetWorkingDirectory: string;
begin
  if FDirectory = '' then Result := FOutputPath
  else Result := FDirectory;
end;

constructor TNXBuildPlannedProject.Create;
begin
  inherited Create;
  FDependencies := TStringList.Create;
  FDirectories := TNXBuildDirectories.Create;
end;

destructor TNXBuildPlannedProject.Destroy;
begin
  FDirectories.Free;
  FDependencies.Free;
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
  FProjects := specialize TObjectList<TNXBuildPlannedProject>.Create(True);
end;

destructor TNXBuildPlan.Destroy;
begin
  FProjects.Free;
  FSteps.Free;
  inherited Destroy;
end;

function TNXBuildPlanner.ResolveCompiler(AEntry: TNXBuildEntry;
  const ARoot: string; APlan: TNXBuildPlan; ACheckTools: Boolean): string;
var
  lCompiler, lOutput: string;
  lIndex: Integer;
  lProduced: Boolean;
begin
  lCompiler := AEntry.CompilerPath;
  if lCompiler = '' then
    lCompiler := AEntry.DefaultCompiler;
  {$IFDEF MSWINDOWS}
  if ExtractFileExt(lCompiler) = '' then
    lCompiler := lCompiler + '.exe';
  {$ENDIF}
  if not ACheckTools then
  begin
    if ExtractFilePath(lCompiler) <> '' then
      Result := TNXBuildEntry.ResolvePath(lCompiler, ARoot)
    else
      Result := lCompiler;
    Exit;
  end;
  if ExtractFilePath(lCompiler) <> '' then
  begin
    Result := TNXBuildEntry.ResolvePath(lCompiler, ARoot);
    if not FileExists(Result) then
    begin
      { An earlier producer may create an explicitly named tool. Planning does
        not run it or require its output files to exist already. }
      lProduced := False;
      for lIndex := 0 to APlan.Steps.Count - 2 do
      begin
        lOutput := IncludeTrailingPathDelimiter(APlan.Steps[lIndex].OutputPath);
        if SameFileName(Copy(Result, 1, Length(lOutput)), lOutput) then
        begin
          lProduced := True;
          Break;
        end;
      end;
      if not lProduced then Result := '';
    end;
  end
  else
    Result := ExeSearch(lCompiler);
  if Result = '' then
    raise Exception.CreateFmt('Build "%s" (%s): tool not found: %s.',
      [AEntry.Name, AEntry.BuildType, lCompiler]);
  Result := ExpandFileName(Result);
end;

function TNXBuildPlanner.CreatePlan(ADescription: TNXBuildDescription;
  ACheckTools: Boolean): TNXBuildPlan;
var
  lIndex, lSourceArgumentIndex: Integer;
  lEntry: TNXBuildEntry;
  lStep: TNXBuildStep;
  lGraph: TNXBuildProjectGraph;
  lNode, lDependency: TNXBuildProjectNode;
  lProject: TNXBuildPlannedProject;
  lTarget: TNexusScriptSelectedTarget;
  lOS, lCPU: string;
begin
  if ADescription = nil then
    raise Exception.Create('Build description is required.');
  lGraph := TNXBuildProjectGraph.Create(ADescription);
  try
    Result := TNXBuildPlan.Create;
    try
      Result.Name := ADescription.Name;
      Result.Kind := ADescription.Kind;
      for lNode in lGraph.Order do
      begin
        lProject := TNXBuildPlannedProject.Create;
        Result.Projects.Add(lProject);
        lProject.Id := lNode.Description.Id;
        lProject.FileName := lNode.Description.FileName;
        lProject.Directories.Include(lNode.Directories);
        for lDependency in lNode.Dependencies do
          lProject.Dependencies.Add(lDependency.Description.Id);
        lOS := '';
        lCPU := '';
        lTarget := lNode.Description.SelectedTargets.Find('TargetOS');
        if lTarget <> nil then lOS := lTarget.Value;
        lTarget := lNode.Description.SelectedTargets.Find('TargetCPU');
        if lTarget <> nil then lCPU := lTarget.Value;
        for lIndex := 0 to lNode.Description.Builds.Count - 1 do
        begin
          lEntry := lNode.Description.Builds[lIndex] as TNXBuildEntry;
          try
            lEntry.ValidateTarget(lOS, lCPU);
          except
            on E: Exception do
              raise Exception.CreateFmt('Project "%s", build "%s": %s',
                [lProject.Id, lEntry.Name, E.Message]);
          end;
          if lEntry.RequiresSources and (lEntry.SourceFiles.Count = 0) then
            raise Exception.CreateFmt('Project "%s", build "%s" (%s): SourceFiles must contain at least one file.',
              [lProject.Id, lEntry.Name, lEntry.BuildType]);
          lStep := TNXBuildStep.Create;
          Result.Steps.Add(lStep);
          lStep.Name := lEntry.Name;
          lStep.ProjectId := lProject.Id;
          lStep.BuildType := lEntry.BuildType;
          lStep.OutputPath := lEntry.OutputPath;
          lStep.WorkingDirectory := lEntry.WorkingDirectory;
          lStep.Executable := ResolveCompiler(lEntry, lNode.Description.RootDirectory, Result, ACheckTools);
          lStep.CompileEachSource := lEntry.CompileEachSource;
          lStep.SourceFiles.Assign(lEntry.SourceFiles);
          lEntry.AppendArguments(lStep.Arguments, lSourceArgumentIndex);
          lEntry.AppendEnvironment(lNode.Directories, lStep.Arguments, lSourceArgumentIndex);
          lStep.SourceArgumentIndex := lSourceArgumentIndex;
        end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    lGraph.Free;
  end;
end;

procedure WriteDirectories(const ACategory: string; ADirectories: TStrings);
var
  lDirectory: string;
begin
  for lDirectory in ADirectories do
    WriteLn('  ', ACategory, ': ', lDirectory);
end;

procedure TNXBuildPlanner.WriteProjects(APlan: TNXBuildPlan);
var
  lValue: string;
  lProject: TNXBuildPlannedProject;
begin
  if APlan = nil then
    raise Exception.Create('Build plan is required.');
  WriteLn(APlan.Kind, ': ', APlan.Name);
  for lProject in APlan.Projects do
  begin
    WriteLn('Project: ', lProject.Id, ' (', lProject.FileName, ')');
    for lValue in lProject.Dependencies do WriteLn('  Requires: ', lValue);
    WriteDirectories('Sources', lProject.Directories.Sources);
    WriteDirectories('Headers', lProject.Directories.Headers);
    WriteDirectories('Objects', lProject.Directories.Objects);
    WriteDirectories('Libraries', lProject.Directories.Libraries);
  end;
end;

procedure TNXBuildPlanner.WritePlan(APlan: TNXBuildPlan);
var
  lIndex: Integer;
  lValue: string;
  lStep: TNXBuildStep;
begin
  WriteProjects(APlan);
  for lIndex := 0 to APlan.Steps.Count - 1 do
  begin
    lStep := APlan.Steps[lIndex];
    WriteLn(lIndex + 1, '. ', lStep.ProjectId, '/', lStep.Name, ' (', lStep.BuildType, ')');
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
