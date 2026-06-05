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
    function ResolveLazbuild(AProject: TNXPascalProject): string;
    procedure CreateFPCPlan(APlan: TNXBuildPlan);
    procedure CreateLazarusPlan(APlan: TNXBuildPlan);
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

function TNXBuildPlanner.ResolveLazbuild(AProject: TNXPascalProject): string;
var
  lLazarusRoot: string;
begin
  lLazarusRoot := AProject.ResolvePath(AProject.Toolchain.LazarusRoot);
  if lLazarusRoot = '' then
    lLazarusRoot := GetEnvironmentVariable('LAZARUSDIR');
  if lLazarusRoot <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(lLazarusRoot) + 'lazbuild';
    {$IFDEF MSWINDOWS}
    Result := Result + '.exe';
    {$ENDIF}
    if FileExists(Result) then
      Exit;
  end;

  Result := GetEnvironmentVariable('LAZBUILD');
  if Result = '' then
    Result := 'lazbuild';
end;

procedure TNXBuildPlanner.CreateFPCPlan(APlan: TNXBuildPlan);
begin
  APlan.Executable := ResolveCompiler(APlan.Project);
  APlan.WorkingDirectory := APlan.Project.ProjectRoot;
  APlan.Project.FPCBuildOptions.AppendArguments(APlan.Arguments);
end;

procedure TNXBuildPlanner.CreateLazarusPlan(APlan: TNXBuildPlan);
var
  lProjectFile: string;
begin
  lProjectFile := APlan.Project.ResolvePath(APlan.Project.LazarusProjectFile);
  if lProjectFile = '' then
    raise Exception.Create('Lazarus project file is required.');

  APlan.Executable := ResolveLazbuild(APlan.Project);
  APlan.WorkingDirectory := ExtractFileDir(lProjectFile);
  APlan.Arguments.Add('--quiet');
  APlan.Arguments.Add(lProjectFile);
end;

function TNXBuildPlanner.CreatePlan(AProject: TNXPascalProject): TNXBuildPlan;
begin
  if AProject = nil then
    raise Exception.Create('Project is required.');

  Result := TNXBuildPlan.Create(AProject);
  try
    if AProject.ProjectKind = ppkLazarusProject then
      CreateLazarusPlan(Result)
    else
      CreateFPCPlan(Result);
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
