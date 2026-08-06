program NexusLSTestClient;

{$mode objfpc}{$H+}

uses
  Interfaces,
  Forms,
  frmNexusLSTestClient;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TNexusLSTestClientForm, NexusLSTestClientForm);
  Application.Run;
end.
