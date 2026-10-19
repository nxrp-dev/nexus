(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildCommands;

{$mode objfpc}{$H+}

interface

type
  TNXBuildCommands = class
  public
    class procedure RegisterCommandLineFlags; static;
    class procedure Execute; static;
  end;

implementation

uses
  SysUtils,
  obNXCommandLine, obNexusScriptModel,
  obNXBuildExecutor,
  obNXBuildPlanner,
  obNXBuildDescriptionLoader, obNXBuildDescription;

function NXBuildProjectArgument: string;
begin
  Result := TNXCommandLine.GetValueDefault('project', '');
end;

function NXBuildRequestedAction: string;
begin
  Result := TNXCommandLine.GetValueDefault('action', '');
end;

function NXBuildTargetArgument(const AName: string): string;
begin
  if TNXCommandLine.Supplied(AName) and not TNXCommandLine.SuppliedWithValue(AName) then
    raise Exception.CreateFmt('Command line flag "%s" requires a value.', [AName]);
  Result := LowerCase(Trim(TNXCommandLine.Value[AName]));
  if Result = '' then
    raise Exception.CreateFmt('Command line flag "%s" requires a value.', [AName]);
end;

class procedure TNXBuildCommands.RegisterCommandLineFlags;
begin
  TNXCommandLine.RegisterFlag('project', False, True, '', 'NexusScript build description', 'Path to an nxproject build description.');
  TNXCommandLine.RegisterFlag('action', False, True, '', 'Build action', 'Use /action=validate, /action=plan or /action=build with /project=project.nxproject.');
  TNXCommandLine.RegisterFlag('targetos', False, True, {$I %FPCTARGETOS%},
    'Target operating system', 'Requested target OS; defaults to the native nxbuild platform.');
  TNXCommandLine.RegisterFlag('targetcpu', False, True, {$I %FPCTARGETCPU%},
    'Target CPU', 'Requested target CPU; defaults to the native nxbuild platform.');
end;

class procedure TNXBuildCommands.Execute;
var
  lAction: string;
  lProjectFile: string;
  lTargetOS, lTargetCPU: string;
  lTargets: TNexusScriptTargetSelection;
  lLoader: TNXBuildDescriptionLoader;
  lPlanner: TNXBuildPlanner;
  lExecutor: TNXBuildExecutor;
  lPlan: TNXBuildPlan;
  lDescription: TNXBuildDescription;
begin
  lAction := LowerCase(NXBuildRequestedAction);
  lProjectFile := NXBuildProjectArgument;
  lTargetOS := NXBuildTargetArgument('targetos');
  lTargetCPU := NXBuildTargetArgument('targetcpu');

  if lAction = '' then
    raise Exception.Create('Specify /action=validate, /action=plan or /action=build.');
  if lProjectFile = '' then
    raise Exception.Create('Project file is required.');

  lLoader := TNXBuildDescriptionLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  lDescription := nil;
  lTargets := TNexusScriptTargetSelection.Create;
  try
    lTargets.Add('TargetOS', lTargetOS);
    lTargets.Add('TargetCPU', lTargetCPU);
    lDescription := lLoader.LoadDescription(lProjectFile, lTargets);
    lPlan := lPlanner.CreatePlan(lDescription, lAction <> 'validate');
    try
      if lAction = 'validate' then
        WriteLn('Validated ', lDescription.Id, ': ', lPlan.Projects.Count,
          ' projects, ', lPlan.Steps.Count, ' builds; target ', lTargetOS, '/', lTargetCPU, '.')
      else if lAction = 'plan' then
      begin
        WriteLn('Requested target: ', lTargetOS, '/', lTargetCPU);
        lPlanner.WritePlan(lPlan);
      end
      else if lAction = 'build' then
      begin
        lExecutor := TNXBuildExecutor.Create;
        try
          ExitCode := lExecutor.Execute(lPlan);
        finally
          lExecutor.Free;
        end;
      end
      else
        raise Exception.CreateFmt('Unknown build action "%s".', [lAction]);
    finally
      lPlan.Free;
    end;
  finally
    lTargets.Free;
    lDescription.Free;
    lPlanner.Free;
    lLoader.Free;
  end;
end;

end.
