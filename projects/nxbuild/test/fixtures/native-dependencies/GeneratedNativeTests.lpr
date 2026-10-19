// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program GeneratedNativeTests;
{$mode objfpc}{$H+}
{$link GeneratedValue.o}
uses obNXTestRegistry, obNXTestContext, obNXTestSuite, obNXTestResult, GeneratedValues;
function nx_generated_value: LongInt; cdecl; external;
procedure TestPublishedSource(AContext: TNXTestContext);
begin AContext.AssertEquals(42, cGeneratedValue); end;
procedure TestNativeObject(AContext: TNXTestContext);
begin AContext.AssertEquals(42, nx_generated_value); end;
var
  lRegistry: TNXTestRegistry;
  lSuite: TNXTestSuite;
  lResult: TNXTestResult;
  lIndex, lFailed: Integer;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lSuite := lRegistry.AddSuite('NXBuild.GeneratedNative');
    lSuite.AddTest('PublishedSourceAndHeader', @TestPublishedSource);
    lSuite.AddTest('NativeObject', @TestNativeObject);
    for lIndex := 0 to lSuite.TestCount - 1 do
    begin
      lResult := lSuite.Tests[lIndex].Execute(lSuite.Name);
      try
        WriteLn(lResult.StatusText, ' ', lResult.TestId, ' ', lResult.Message, ' ', lResult.ErrorMessage);
        if lResult.Status <> tsPassed then Inc(lFailed);
      finally lResult.Free; end;
    end;
    if lFailed <> 0 then ExitCode := 1;
  finally lRegistry.Free; end;
end.
