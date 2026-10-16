// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program NexusTestTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  obNXTestRegistry, utNXTestConsole,
  tsNXTestContext;
var
  lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterContextTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
