(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPCBuildOptions;

{$mode objfpc}{$H+}

interface

uses obNXFPCBuildOptions;

type
  TNXPCBuildOptions = class(TNXFPCBuildOptions)
  public
    function BuildType: string; override;
    function DefaultCompiler: string; override;
  end;

implementation

uses SysUtils, obNXPersist;

function TNXPCBuildOptions.BuildType: string;
begin
  Result := 'NXPC';
end;

function TNXPCBuildOptions.DefaultCompiler: string;
begin
  Result := GetEnvironmentVariable('NXPC');
  if Result = '' then Result := 'nxpc';
end;

initialization
  TNXPersistObject.RegisterPersistClass(TNXPCBuildOptions);

end.
