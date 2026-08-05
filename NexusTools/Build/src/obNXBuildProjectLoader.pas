unit obNXBuildProjectLoader;

{$mode objfpc}{$H+}

interface

uses
  obNXPascalProject;

type
  TNXBuildProjectLoader = class
  public
    function LoadProject(const AFileName: string): TNXPascalProject;
  end;

implementation

uses
  SysUtils;

function TNXBuildProjectLoader.LoadProject(const AFileName: string): TNXPascalProject;
begin
  if not FileExists(AFileName) then
    raise Exception.CreateFmt('Nexus project file was not found: %s', [AFileName]);

  Result := TNXPascalProject.Create;
  try
    Result.LoadFromJSONFile(AFileName);
    if Result.ProjectFileName = '' then
      Result.ProjectFileName := ExpandFileName(AFileName);
    if Result.ProjectRoot = '' then
      Result.ProjectRoot := ExtractFileDir(ExpandFileName(AFileName));
    Result.ApplyToBuildOptions;
  except
    Result.Free;
    raise;
  end;
end;

end.
