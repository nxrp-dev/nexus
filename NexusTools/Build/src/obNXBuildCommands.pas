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
  obNXCommandLine,
  obNXBuildExecutor,
  obNXBuildPlanner,
  obNXBuildProjectLoader;

function NXBuildProjectArgument: string;
begin
  Result := TNXCommandLine.GetValueDefault('project', '');
end;

function NXBuildRequestedAction: string;
begin
  Result := TNXCommandLine.GetValueDefault('action', '');
end;

class procedure TNXBuildCommands.RegisterCommandLineFlags;
begin
  TNXCommandLine.RegisterFlag('project', False, True, '', 'Nexus project file', 'Path to the .nxp project file.');
  TNXCommandLine.RegisterFlag('action', False, True, '', 'Build action', 'Use /action=plan or /action=build with /project=project.nxp.');
end;

class procedure TNXBuildCommands.Execute;
var
  lAction: string;
  lProjectFile: string;
  lLoader: TNXBuildProjectLoader;
  lPlanner: TNXBuildPlanner;
  lExecutor: TNXBuildExecutor;
  lPlan: TNXBuildPlan;
begin
  lAction := LowerCase(NXBuildRequestedAction);
  lProjectFile := NXBuildProjectArgument;

  if lAction = '' then
    raise Exception.Create('Specify /action=plan or /action=build.');
  if lProjectFile = '' then
    raise Exception.Create('Project file is required.');

  lLoader := TNXBuildProjectLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  try
    lPlan := lPlanner.CreatePlan(lLoader.LoadProject(lProjectFile));
    try
      if lAction = 'plan' then
        lPlanner.WritePlan(lPlan)
      else if lAction = 'build' then
      begin
        lExecutor := TNXBuildExecutor.Create;
        try
          lExecutor.Execute(lPlan);
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
    lPlanner.Free;
    lLoader.Free;
  end;
end;

end.
