unit obNXTestRunner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, obNXTestRegistry, obNXTestSuite, obNXTestCase,
  obNXTestResult;

type
  TNXTestRunner = class
  private
    FRegistry: TNXTestRegistry;
  public
    constructor Create(ARegistry: TNXTestRegistry);

    function RunAll: TJSONArray;
    function RunSuite(const ASuiteName: string): TJSONArray;
    function RunTest(const ATestId: string): TJSONObject;

    property Registry: TNXTestRegistry read FRegistry;
  end;

implementation

constructor TNXTestRunner.Create(ARegistry: TNXTestRegistry);
begin
  inherited Create;
  FRegistry := ARegistry;
end;

function TNXTestRunner.RunAll: TJSONArray;
var
  lSuiteIndex: Integer;
  lTestIndex: Integer;
  lSuite: TNXTestSuite;
  lResult: TNXTestResult;
begin
  Result := TJSONArray.Create;

  for lSuiteIndex := 0 to FRegistry.SuiteCount - 1 do
  begin
    lSuite := FRegistry.Suites[lSuiteIndex];
    for lTestIndex := 0 to lSuite.TestCount - 1 do
    begin
      lResult := lSuite.Tests[lTestIndex].Execute(lSuite.Name);
      try
        Result.Add(lResult.ToJsonObject);
      finally
        lResult.Free;
      end;
    end;
  end;
end;

function TNXTestRunner.RunSuite(const ASuiteName: string): TJSONArray;
var
  lTestIndex: Integer;
  lSuite: TNXTestSuite;
  lResult: TNXTestResult;
begin
  Result := TJSONArray.Create;

  lSuite := FRegistry.FindSuite(ASuiteName);
  if not Assigned(lSuite) then
    Exit;

  for lTestIndex := 0 to lSuite.TestCount - 1 do
  begin
    lResult := lSuite.Tests[lTestIndex].Execute(lSuite.Name);
    try
      Result.Add(lResult.ToJsonObject);
    finally
      lResult.Free;
    end;
  end;
end;

function TNXTestRunner.RunTest(const ATestId: string): TJSONObject;
var
  lSuite: TNXTestSuite;
  lTest: TNXTestCase;
  lResult: TNXTestResult;
begin
  Result := nil;

  lTest := FRegistry.FindTest(ATestId, lSuite);
  if not Assigned(lTest) then
    Exit;

  lResult := lTest.Execute(lSuite.Name);
  try
    Result := lResult.ToJsonObject;
  finally
    lResult.Free;
  end;
end;

end.
