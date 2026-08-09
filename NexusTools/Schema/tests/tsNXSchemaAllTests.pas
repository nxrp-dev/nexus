unit tsNXSchemaAllTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXSchemaTests(ARegistry: TNXTestRegistry);

implementation

uses
  tsNXSchemaCoreTests;

procedure RegisterNXSchemaTests(ARegistry: TNXTestRegistry);
begin
  RegisterNXSchemaCoreTests(ARegistry);
end;

end.
