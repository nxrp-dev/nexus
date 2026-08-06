unit obNXLSTelemetryRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects;

type
  TNXLSTelemetryEventRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSTelemetryEventRequest.GetFactoryName: string;
begin
  Result := 'telemetry/event';
end;

class function TNXLSTelemetryEventRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSTelemetryEventRequest.Execute: TNXJSONRPCValue;
begin
  // Method: telemetry/event; required: Client-side; original server: No; category: telemetry; result: nil.
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTelemetryEventRequest);

end.
