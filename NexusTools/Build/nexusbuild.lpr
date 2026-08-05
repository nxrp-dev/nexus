program nexusbuild;

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
