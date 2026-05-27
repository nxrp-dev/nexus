unit obNXTestRPCValues;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpjson,
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  ENXTestRPC = class(ENXJSONRPC)
  private
    FNXTestCode: Integer;
  public
    constructor CreateCode(const ACode: Integer; const ANXTestCode: Integer; const AMessage: string);
    property NXTestCode: Integer read FNXTestCode;
  end;

  TNXTestErrorData = class(TNXJSONObject)
  private
    FnxtestCode: TNXJSONInteger;
  published
    property nxtestCode: TNXJSONInteger read FnxtestCode write FnxtestCode;
  end;

  TNXTestRunSuiteParams = class(TNXJSONObjectParams)
  private
    Fsuite: TNXJSONString;
  published
    property suite: TNXJSONString read Fsuite write Fsuite;
  end;

  TNXTestRunTestParams = class(TNXJSONObjectParams)
  private
    Ftest: TNXJSONString;
  published
    property test: TNXJSONString read Ftest write Ftest;
  end;

function NXTestJSONValueFromData(AData: TJSONData): TNXJSONValue;
function NXTestJSONValueFromObject(AObject: TJSONObject): TNXJSONValue;
function NXTestJSONValueFromArray(AArray: TJSONArray): TNXJSONValue;
function NXTestErrorData(const ANXTestCode: Integer): TNXTestErrorData;

implementation

constructor ENXTestRPC.CreateCode(const ACode: Integer; const ANXTestCode: Integer; const AMessage: string);
begin
  inherited CreateCode(ACode, AMessage);
  FNXTestCode := ANXTestCode;
end;

function NXTestJSONValueFromData(AData: TJSONData): TNXJSONValue;
begin
  Result := TNXJSONValue.Create;
  try
    Result.FromJSONData(AData);
  except
    Result.Free;
    raise;
  end;
end;

function NXTestJSONValueFromObject(AObject: TJSONObject): TNXJSONValue;
begin
  try
    Result := NXTestJSONValueFromData(AObject);
  finally
    AObject.Free;
  end;
end;

function NXTestJSONValueFromArray(AArray: TJSONArray): TNXJSONValue;
begin
  try
    Result := NXTestJSONValueFromData(AArray);
  finally
    AArray.Free;
  end;
end;

function NXTestErrorData(const ANXTestCode: Integer): TNXTestErrorData;
begin
  Result := TNXTestErrorData.Create;
  Result.nxtestCode.Value := ANXTestCode;
end;

end.
