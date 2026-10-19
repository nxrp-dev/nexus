(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program nxbuild;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  obNXCommandLine,
  obNXBuildCommands;

begin
  try
    TNXBuildCommands.RegisterCommandLineFlags;
    TNXCommandLine.AllowUnknownFlags := False;
    TNXCommandLine.Parse;
    TNXCommandLine.Validate;
    TNXBuildCommands.Execute;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      Halt(1);
    end;
  end;
end.
