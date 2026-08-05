unit tsNXTaskAllTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry;

procedure RegisterNXTaskTests(ARegistry: TNXTestRegistry);

implementation

uses
  tsNXTaskParserTests, tsNXTaskValidationTests, tsNXTaskResolverTests,
  tsNXTaskTargetTests, tsNXTaskExecutionTests;

procedure RegisterNXTaskTests(ARegistry: TNXTestRegistry);
begin
  RegisterNXTaskParserTests(ARegistry);
  RegisterNXTaskValidationTests(ARegistry);
  RegisterNXTaskResolverTests(ARegistry);
  RegisterNXTaskTargetTests(ARegistry);
  RegisterNXTaskExecutionTests(ARegistry);
end;

end.
