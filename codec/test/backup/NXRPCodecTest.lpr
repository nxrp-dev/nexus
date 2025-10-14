program NXRPCodecTest;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}cthreads,{$ENDIF}{$ENDIF}
  SysUtils,
  fpcunit, testutils, testregistry, GuiTestRunner,
  obNxrpCodecTests;

var
  App: TTestRunner;
begin
  GuiTestRunner.
  App := TTestRunner.Create(nil);
  try
    App.Initialize;   // parses CLI args, etc.
    App.Run;          // runs registered tests, prints to console
  finally
    App.Free;
  end;
end.
