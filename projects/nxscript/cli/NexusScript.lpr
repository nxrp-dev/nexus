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
