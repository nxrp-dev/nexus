unit tsSampleTests;

{$mode objfpc}{$H+}

interface

uses
  obNXTestRegistry, obNXTestSuite, obNXTestContext;

procedure RegisterSampleTests(ARegistry: TNXTestRegistry);

implementation

procedure TestPassingString(AContext: TNXTestContext);
begin
  AContext.AssertEquals('Nexus', 'Nexus', 'Strings should match.');
end;

procedure TestPassingInteger(AContext: TNXTestContext);
begin
  AContext.AssertEquals(42, 40 + 2, 'Integers should match.');
end;

procedure TestFailingValue(AContext: TNXTestContext);
begin
  AContext.AssertEquals('expected', 'actual', 'This sample failure is intentional.');
end;

procedure TestSkipped(AContext: TNXTestContext);
begin
  AContext.Skip('This sample skip is intentional.');
end;

procedure RegisterSampleTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('Sample');
  lSuite.AddTest('PassingString', @TestPassingString);
  lSuite.AddTest('PassingInteger', @TestPassingInteger);
  lSuite.AddTest('FailingValue', @TestFailingValue);
  lSuite.AddTest('Skipped', @TestSkipped);
end;

end.
