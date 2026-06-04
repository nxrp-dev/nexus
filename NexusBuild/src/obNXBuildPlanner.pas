unit obNXBuildPlanner;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXPascalProject;

type
  TNXBuildPlan = class
  private
    FProject: TNXPascalProject;
    FExecutable: string;
    FArguments: TStringList;
    FWorkingDirectory: string;
  public
    constructor Create(AProject: TNXPascalProject);
    destructor Destroy; override;

    property Project: TNXPascalProject read FProject;
    property Executable: string read FExecutable write FExecutable;
    property Arguments: TStringList read FArguments;
    property WorkingDirectory: string read FWorkingDirectory write FWorkingDirectory;
  end;

  TNXBuildPlanner = class
  private
    function ResolveCompiler(AProject: TNXPascalProject): string;
  public
    function CreatePlan(AProject: TNXPascalProject): TNXBuildPlan;
    procedure WritePlan(APlan: TNXBuildPlan);
  end;

implementation

uses
  SysUtils;

function NXBuildQuoteArgument(const AValue: string): string;
begin
  if Pos(' ', AValue) > 0 then
    Result := '"' + AValue + '"'
  else
    Result := AValue;
end;

constructor TNXBuildPlan.Create(AProject: TNXPascalProject);
begin
  inherited Create;
  FProject := AProject;
  FArguments := TStringList.Create;
end;

destructor TNXBuildPlan.Destroy;
begin
  FArguments.Free;
  FProject.Free;
  inherited Destroy;
end;

function TNXBuildPlanner.ResolveCompiler(AProject: TNXPascalProject): string;
begin
  Result := AProject.FPCBuildOptions.CompilerPath;
  if Result = '' then
    Result := GetEnvironmentVariable('PP');
  if Result = '' then
    Result := 'fpc';
end;

function TNXBuildPlanner.CreatePlan(AProject: TNXPascalProject): TNXBuildPlan;
begin
  if AProject = nil then
    raise Exception.Create('Project is required.');

  Result := TNXBuildPlan.Create(AProject);
  try
    Result.Executable := ResolveCompiler(AProject);
    Result.WorkingDirectory := AProject.ProjectRoot;
    AProject.FPCBuildOptions.AppendArguments(Result.Arguments);
  except
    Result.Free;
    raise;
  end;
end;

procedure TNXBuildPlanner.WritePlan(APlan: TNXBuildPlan);
var
  lIndex: Integer;
begin
  if APlan = nil then
    raise Exception.Create('Build plan is required.');

  WriteLn('Project: ', APlan.Project.Name);
  WriteLn('Working directory: ', APlan.WorkingDirectory);
  WriteLn('Executable: ', APlan.Executable);
  Write('Command: ', NXBuildQuoteArgument(APlan.Executable));
  for lIndex := 0 to APlan.Arguments.Count - 1 do
    Write(' ', NXBuildQuoteArgument(APlan.Arguments[lIndex]));
  WriteLn;
end;

end.
