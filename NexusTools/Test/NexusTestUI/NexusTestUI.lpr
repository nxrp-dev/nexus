program NexusTestUI;

{$mode objfpc}{$H+}
{$apptype GUI}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  uiNXTestMain;

begin
  RunNexusTestUI;
end.
