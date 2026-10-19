(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildExecutor;

{$mode objfpc}{$H+}

interface

uses Classes, obNXBuildPlanner;

type
  TNXBuildExecutor = class
  private
    function ExecuteInvocation(AStep: TNXBuildStep; ASources: TStrings;
      ASourceIndex: Integer): Integer;
    function ExecuteStep(AStep: TNXBuildStep): Integer;
  public
    function Execute(APlan: TNXBuildPlan): Integer;
  end;

implementation

uses SysUtils, Process, obNXBuildEntry;

function TNXBuildExecutor.ExecuteInvocation(AStep: TNXBuildStep;
  ASources: TStrings; ASourceIndex: Integer): Integer;
var
  lProcess: TProcess;
begin
  lProcess := TProcess.Create(nil);
  try
    lProcess.Executable := AStep.Executable;
    lProcess.CurrentDirectory := AStep.WorkingDirectory;
    AStep.FillArguments(ASources, ASourceIndex, lProcess.Parameters);
    lProcess.Options := [poWaitOnExit];
    lProcess.Execute;
    Result := lProcess.ExitStatus;
  finally
    lProcess.Free;
  end;
end;

function TNXBuildExecutor.ExecuteStep(AStep: TNXBuildStep): Integer;
var
  lSources: TStringList;
  lIndex, lCount: Integer;
begin
  Result := 0;
  lSources := TStringList.Create;
  try
    TNXBuildEntry.ExpandSourceFiles(AStep.SourceFiles, lSources);
    if not ForceDirectories(AStep.OutputPath) then
      raise Exception.CreateFmt('Cannot create directory: %s.', [AStep.OutputPath]);
    lCount := 1;
    if AStep.CompileEachSource then lCount := lSources.Count;
    for lIndex := 0 to lCount - 1 do
    begin
      Result := ExecuteInvocation(AStep, lSources, lIndex);
      if Result <> 0 then Exit;
    end;
  finally
    lSources.Free;
  end;
end;

function TNXBuildExecutor.Execute(APlan: TNXBuildPlan): Integer;
var
  lStep: TNXBuildStep;
begin
  if APlan = nil then
    raise Exception.Create('Build plan is required.');
  Result := 0;
  for lStep in APlan.Steps do
  begin
    try
      Result := ExecuteStep(lStep);
    except
      on E: Exception do
        raise Exception.CreateFmt('Build "%s" (%s): %s',
          [lStep.Name, lStep.BuildType, 'Project "' + lStep.ProjectId + '": ' + E.Message]);
    end;
    if Result <> 0 then
    begin
      WriteLn(StdErr, 'Build "', lStep.Name, '" (',
        lStep.BuildType, ') in project "', lStep.ProjectId, '" failed with exit code ', Result, '.');
      Exit;
    end;
  end;
end;

end.
