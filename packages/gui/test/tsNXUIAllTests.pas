unit tsNXUIAllTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXUITests(ARegistry: TNXTestRegistry);

implementation

uses
  tsNXPersistTests;

procedure RegisterNXUITests(ARegistry: TNXTestRegistry);
begin
  RegisterNXPersistTests(ARegistry);
end;

end.
