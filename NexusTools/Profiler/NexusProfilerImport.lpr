program NexusProfilerImport;

{$mode objfpc}{$H+}

uses
  SysUtils,
  obNXProfileCLI;

begin
  try
    Halt(TNXProfileCLI.Execute);
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      Halt(1);
    end;
  end;
end.
