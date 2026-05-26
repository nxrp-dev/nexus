unit obNXLSTelemetryRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTelemetryEventRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTelemetryEventRequest.GetFactoryName: string;
begin
  Result := 'telemetry/event';
end;

class function TNXLSTelemetryEventRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTelemetryEventParams;
end;

function TNXLSTelemetryEventRequest.Execute: TNXJSONValue;
begin
  // Method: telemetry/event; required: Client-side; original server: No; category: telemetry; result: nil.
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTelemetryEventRequest);

end.
