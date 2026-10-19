// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program ConfigurationTests;
{$mode objfpc}{$H+}
{$link ConfigurationObject.o}
uses SysUtils, obNXTestRegistry, obNXTestContext, obNXTestSuite, obNXTestResult,
  ConfigurationValues;

function nx_configuration_object: LongInt; cdecl; external;
function nx_configuration_library: LongInt; cdecl; external 'nxconfiguration';

function ExpectedValue: Integer;
begin
  if ParamStr(1) = 'Debug' then Result := 101
  else if ParamStr(1) = 'Release' then Result := 202
  else raise Exception.Create('Pass the expected configuration: Debug or Release.');
end;

procedure TestCommonSource(AContext: TNXTestContext);
begin
  AContext.AssertEquals(7, cCommonValue);
end;

procedure TestSelectedHeader(AContext: TNXTestContext);
begin
  AContext.AssertEquals(ExpectedValue, cConfigurationValue);
end;

procedure TestSelectedObject(AContext: TNXTestContext);
begin
  AContext.AssertEquals(ExpectedValue + 7, nx_configuration_object);
end;

procedure TestSelectedLibrary(AContext: TNXTestContext);
begin
  AContext.AssertEquals(ExpectedValue + 7, nx_configuration_library);
end;

procedure RunTests;
var
  lRegistry: TNXTestRegistry;
  lSuite: TNXTestSuite;
  lResult: TNXTestResult;
  lIndex, lFailed: Integer;
begin
  lFailed := 0;
  lRegistry := TNXTestRegistry.Create;
  try
    lSuite := lRegistry.AddSuite('NXBuild.Configuration');
    lSuite.AddTest('CommonSource', @TestCommonSource);
    lSuite.AddTest('SelectedHeader', @TestSelectedHeader);
    lSuite.AddTest('SelectedObject', @TestSelectedObject);
    lSuite.AddTest('SelectedLibrary', @TestSelectedLibrary);
    for lIndex := 0 to lSuite.TestCount - 1 do
    begin
      lResult := lSuite.Tests[lIndex].Execute(lSuite.Name);
      try
        WriteLn(lResult.StatusText, ' ', lResult.TestId, ' ', lResult.Message, ' ', lResult.ErrorMessage);
        if lResult.Status <> tsPassed then Inc(lFailed);
      finally
        lResult.Free;
      end;
    end;
    WriteLn(lSuite.TestCount - lFailed, ' passed; ', lFailed, ' failed');
    if lFailed <> 0 then ExitCode := 1;
  finally
    lRegistry.Free;
  end;
end;

begin
  RunTests;
end.
