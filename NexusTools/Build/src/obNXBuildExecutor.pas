unit obNXBuildExecutor;

{$mode objfpc}{$H+}

interface

uses
  obNXBuildPlanner;

type
  TNXBuildExecutor = class
  public
    procedure Execute(APlan: TNXBuildPlan);
  end;

implementation

uses
  Classes,
  SysUtils,
  LazFileUtils,
  Process;

procedure NXBuildEnsureDirectory(const ADirectory: string);
begin
  if ADirectory <> '' then
    ForceDirectories(ADirectory);
end;

procedure TNXBuildExecutor.Execute(APlan: TNXBuildPlan);
var
  lProcess: TProcess;
  lIndex: Integer;
begin
  if APlan = nil then
    raise Exception.Create('Build plan is required.');

  lProcess := TProcess.Create(nil);
  try
    NXBuildEnsureDirectory(APlan.Project.ResolvePath(APlan.Project.OutputRoot));
    NXBuildEnsureDirectory(APlan.Project.FPCBuildOptions.Files.ExecutableOutputPath);
    NXBuildEnsureDirectory(APlan.Project.FPCBuildOptions.Files.UnitOutputPath);

    lProcess.Executable := APlan.Executable;
    lProcess.CurrentDirectory := APlan.WorkingDirectory;
    for lIndex := 0 to APlan.Arguments.Count - 1 do
      lProcess.Parameters.Add(APlan.Arguments[lIndex]);
    lProcess.Options := [poWaitOnExit];
    lProcess.Execute;
    if lProcess.ExitStatus <> 0 then
      Halt(lProcess.ExitStatus);
  finally
    lProcess.Free;
  end;
end;

end.
