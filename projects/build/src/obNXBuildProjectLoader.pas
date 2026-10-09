(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

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
