program NXRPCodecTest;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, tcNxrpCodecTests;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

