(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXProfileCLI;

{$mode objfpc}{$H+}

interface

type
  TNXProfileCLI = class
  private
    class function Arg(AIndex: Integer): string;
    class function RunNameArg: string;
    class procedure PrintUsage;
  public
    class function Execute: Integer;
  end;

implementation

uses
  SysUtils,
  obNXProfileImporter;

class function TNXProfileCLI.Arg(AIndex: Integer): string;
begin
  if ParamCount >= AIndex then
    Result := ParamStr(AIndex)
  else
    Result := '';
end;

class function TNXProfileCLI.RunNameArg: string;
var
  lIndex: Integer;
begin
  Result := ExpandFileName(Arg(3));
  lIndex := 4;
  while lIndex <= ParamCount do
  begin
    if ParamStr(lIndex) = '-run' then
    begin
      if lIndex >= ParamCount then
        raise EArgumentException.Create('-run requires a name');
      Result := ParamStr(lIndex + 1);
      Exit;
    end;
    raise EArgumentException.CreateFmt('Unknown argument: %s',
      [ParamStr(lIndex)]);
  end;
end;

class procedure TNXProfileCLI.PrintUsage;
begin
  WriteLn('NexusProfilerImport import <database.sqlite> <trace-or-directory> [-run <name>]');
end;

class function TNXProfileCLI.Execute: Integer;
var
  lCount: Integer;
begin
  if (Arg(1) <> 'import') or (Arg(2) = '') or (Arg(3) = '') then
  begin
    PrintUsage;
    Exit(1);
  end;
  lCount := TNXProfileImporter.ImportPath(Arg(2), Arg(3), RunNameArg);
  WriteLn(Format('Imported %d trace file(s) into %s',
    [lCount, ExpandFileName(Arg(2))]));
  Result := 0;
end;

end.
