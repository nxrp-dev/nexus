unit obNXTestResult;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, tpNXTest;

type
  TNXTestStatus = (tsNotRun, tsPassed, tsFailed, tsError, tsSkipped);

  TNXTestResult = class
  private
    FSuiteName: string;
    FTestName: string;
    FTestId: string;
    FStatus: TNXTestStatus;
    FMessage: string;
    FExpected: string;
    FActual: string;
    FErrorClass: string;
    FErrorMessage: string;
    FDurationMs: Int64;
  public
    constructor Create;
    function StatusText: string;
    function ToJsonObject: TJSONObject;

    property SuiteName: string read FSuiteName write FSuiteName;
    property TestName: string read FTestName write FTestName;
    property TestId: string read FTestId write FTestId;
    property Status: TNXTestStatus read FStatus write FStatus;
    property Message: string read FMessage write FMessage;
    property Expected: string read FExpected write FExpected;
    property Actual: string read FActual write FActual;
    property ErrorClass: string read FErrorClass write FErrorClass;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property DurationMs: Int64 read FDurationMs write FDurationMs;
  end;

implementation

constructor TNXTestResult.Create;
begin
  inherited Create;
  FStatus := tsNotRun;
end;

function TNXTestResult.StatusText: string;
begin
  case FStatus of
    tsPassed: Result := cNXTestStatusPassed;
    tsFailed: Result := cNXTestStatusFailed;
    tsError: Result := cNXTestStatusError;
    tsSkipped: Result := cNXTestStatusSkipped;
  else
    Result := cNXTestStatusNotRun;
  end;
end;

function TNXTestResult.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('suite', FSuiteName);
  Result.Add('test', FTestName);
  Result.Add('id', FTestId);
  Result.Add('status', StatusText);
  Result.Add('durationMs', FDurationMs);

  if FMessage <> '' then
    Result.Add('message', FMessage);
  if FExpected <> '' then
    Result.Add('expected', FExpected);
  if FActual <> '' then
    Result.Add('actual', FActual);
  if FErrorClass <> '' then
    Result.Add('errorClass', FErrorClass);
  if FErrorMessage <> '' then
    Result.Add('errorMessage', FErrorMessage);
end;

end.
