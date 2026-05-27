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
    FResults: TList;
    procedure ClearResults;
    procedure AddResult(AResult: TNXTestResult);
  public
    constructor Create(ARegistry: TNXTestRegistry);
    destructor Destroy; override;

    function RunAll: TJSONArray;
    function RunSuite(const ASuiteName: string): TJSONArray;
    function RunTest(const ATestId: string): TNXTestResult;

    property Registry: TNXTestRegistry read FRegistry;
  end;

implementation

constructor TNXTestRunner.Create(ARegistry: TNXTestRegistry);
begin
  inherited Create;
  FRegistry := ARegistry;
  FResults := TList.Create;
end;

destructor TNXTestRunner.Destroy;
begin
  ClearResults;
  FResults.Free;
  inherited Destroy;
end;

procedure TNXTestRunner.ClearResults;
var
  lIndex: Integer;
begin
  for lIndex := 0 to FResults.Count - 1 do
    TObject(FResults[lIndex]).Free;
  FResults.Clear;
end;

procedure TNXTestRunner.AddResult(AResult: TNXTestResult);
begin
  FResults.Add(AResult);
end;

function TNXTestRunner.RunAll: TJSONArray;
var
  lSuiteIndex: Integer;
  lTestIndex: Integer;
  lSuite: TNXTestSuite;
  lResult: TNXTestResult;
begin
  ClearResults;
  Result := TJSONArray.Create;

  for lSuiteIndex := 0 to FRegistry.SuiteCount - 1 do
  begin
    lSuite := FRegistry.Suites[lSuiteIndex];
    for lTestIndex := 0 to lSuite.TestCount - 1 do
    begin
      lResult := lSuite.Tests[lTestIndex].Execute(lSuite.Name);
      Result.Add(lResult.ToJsonObject);
      AddResult(lResult);
    end;
  end;
end;

function TNXTestRunner.RunSuite(const ASuiteName: string): TJSONArray;
var
  lTestIndex: Integer;
  lSuite: TNXTestSuite;
  lResult: TNXTestResult;
begin
  ClearResults;
  Result := TJSONArray.Create;

  lSuite := FRegistry.FindSuite(ASuiteName);
  if not Assigned(lSuite) then
    Exit;

  for lTestIndex := 0 to lSuite.TestCount - 1 do
  begin
    lResult := lSuite.Tests[lTestIndex].Execute(lSuite.Name);
    Result.Add(lResult.ToJsonObject);
    AddResult(lResult);
  end;
end;

function TNXTestRunner.RunTest(const ATestId: string): TNXTestResult;
var
  lSuite: TNXTestSuite;
  lTest: TNXTestCase;
begin
  ClearResults;
  lTest := FRegistry.FindTest(ATestId, lSuite);
  if not Assigned(lTest) then
    Exit(nil);

  Result := lTest.Execute(lSuite.Name);
  AddResult(Result);
end;

end.
