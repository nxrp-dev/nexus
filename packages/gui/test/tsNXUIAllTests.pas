unit tsNXUIAllTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXUITests(ARegistry: TNXTestRegistry);

implementation

uses
  tsNXPersistTests,
  tsNXSkinTests;

procedure RegisterNXUITests(ARegistry: TNXTestRegistry);
begin
  RegisterNXPersistTests(ARegistry);
  RegisterNXSkinTests(ARegistry);
end;

end.
