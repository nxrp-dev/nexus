(*
  Copyright (c) 2026 Kevin Collins.
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
