(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program NexusScript;

{$mode delphi}{$H+}

uses
  Classes,
  SysUtils,
  obNXCommandLine,
  obNexusScriptCommand;

var
  lStdOut: THandleStream;
begin
  try
    TNexusScriptCommand.RegisterCommandLineFlags;
    TNXCommandLine.AllowUnknownFlags := False;
    TNXCommandLine.Parse;
    TNXCommandLine.Validate;
    lStdOut := THandleStream.Create(TTextRec(Output).Handle);
    try
      TNexusScriptCommand.Execute(lStdOut);
    finally
      lStdOut.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      Halt(1);
    end;
  end;
end.
