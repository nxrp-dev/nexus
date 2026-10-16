// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXTestContext;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterContextTests(ARegistry: TNXTestRegistry);
implementation
uses SysUtils, obNXTestContext, obNXTestCase, obNXTestResult, obNXTestSuite;
type
  EProbe = class(Exception);
  EProbeChild = class(EProbe);
  TProbe = class
  private
    FContext: TNXTestContext;
  public
    constructor Create(AContext: TNXTestContext);
    procedure RaiseChild;
    procedure FailAssertion;
  end;
constructor TProbe.Create(AContext: TNXTestContext);
begin
  inherited Create;
  FContext := AContext;
end;
procedure TProbe.RaiseChild;
begin
  raise EProbeChild.Create('probe');
end;
procedure TProbe.FailAssertion;
begin
  FContext.AssertEquals('expected', 'actual', 'deliberate failure');
end;
procedure RaiseProbe;
begin
  raise EProbe.Create('probe');
end;
procedure RaiseWrong;
begin
  raise ERangeError.Create('wrong exception');
end;
procedure ReturnNormally;
begin
end;
procedure TestRoutine(AContext: TNXTestContext);
begin
  AContext.AssertRaises(EProbe, @RaiseProbe);
end;
procedure TestMethodSubclass(AContext: TNXTestContext);
var lProbe: TProbe;
begin
  lProbe := TProbe.Create(AContext);
  try AContext.AssertRaises(EProbe, @lProbe.RaiseChild);
  finally lProbe.Free; end;
end;
procedure MissingException(AContext: TNXTestContext);
begin
  AContext.AssertRaises(EProbe, @ReturnNormally);
end;
procedure WrongException(AContext: TNXTestContext);
begin
  AContext.AssertRaises(EProbe, @RaiseWrong, 'context');
end;
procedure TestMissingException(AContext: TNXTestContext);
var
  lCase: TNXTestCase;
  lResult: TNXTestResult;
begin
  lCase := TNXTestCase.Create('probe', 'probe', @MissingException);
  try
    lResult := lCase.Execute('probe');
    try
      AContext.AssertTrue(lResult.Status = tsFailed);
      AContext.AssertTrue(Pos('EProbe', lResult.Message) > 0);
    finally lResult.Free; end;
  finally lCase.Free; end;
end;
procedure TestWrongException(AContext: TNXTestContext);
var
  lCase: TNXTestCase;
  lResult: TNXTestResult;
begin
  lCase := TNXTestCase.Create('probe', 'probe', @WrongException);
  try
    lResult := lCase.Execute('probe');
    try
      AContext.AssertTrue(lResult.Status = tsFailed);
      AContext.AssertTrue(Pos('ERangeError: wrong exception', lResult.Message) > 0);
      AContext.AssertTrue(Pos('context', lResult.Message) > 0);
    finally lResult.Free; end;
  finally lCase.Free; end;
end;
procedure TestPreserveResult(AContext: TNXTestContext);
var
  lProbe: TProbe;
  lResult: TNXTestResult;
  lContext: TNXTestContext;
begin
  lResult := TNXTestResult.Create;
  lContext := TNXTestContext.Create(lResult);
  try
    lResult.Message := 'prior message';
    lResult.Expected := 'prior expected';
    lResult.Actual := 'prior actual';
    lProbe := TProbe.Create(lContext);
    try lContext.AssertRaises(ENXTestFailure, @lProbe.FailAssertion);
    finally lProbe.Free; end;
    AContext.AssertEquals('prior message', lResult.Message);
    AContext.AssertEquals('prior expected', lResult.Expected);
    AContext.AssertEquals('prior actual', lResult.Actual);
  finally
    lContext.Free;
    lResult.Free;
  end;
end;
procedure FailDirectly(AContext: TNXTestContext);
begin
  raise ENXTestFailure.Create('direct failure');
end;
procedure SkipDirectly(AContext: TNXTestContext);
begin
  raise ENXTestSkip.Create('direct skip');
end;
procedure TestFailureMessage(AContext: TNXTestContext);
var lCase: TNXTestCase; lResult: TNXTestResult;
begin
  lCase := TNXTestCase.Create('probe', 'probe', @FailDirectly);
  try
    lResult := lCase.Execute('probe');
    try
      AContext.AssertTrue(lResult.Status = tsFailed);
      AContext.AssertEquals('direct failure', lResult.Message);
    finally lResult.Free; end;
  finally lCase.Free; end;
end;
procedure TestSkipMessage(AContext: TNXTestContext);
var lCase: TNXTestCase; lResult: TNXTestResult;
begin
  lCase := TNXTestCase.Create('probe', 'probe', @SkipDirectly);
  try
    lResult := lCase.Execute('probe');
    try
      AContext.AssertTrue(lResult.Status = tsSkipped);
      AContext.AssertEquals('direct skip', lResult.Message);
    finally lResult.Free; end;
  finally lCase.Free; end;
end;
procedure RegisterContextTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('nxtest.context');
  lSuite.AddTest('Routine', @TestRoutine);
  lSuite.AddTest('MethodSubclass', @TestMethodSubclass);
  lSuite.AddTest('MissingException', @TestMissingException);
  lSuite.AddTest('WrongException', @TestWrongException);
  lSuite.AddTest('PreserveResult', @TestPreserveResult);
  lSuite.AddTest('FailureMessage', @TestFailureMessage);
  lSuite.AddTest('SkipMessage', @TestSkipMessage);
end;
end.
