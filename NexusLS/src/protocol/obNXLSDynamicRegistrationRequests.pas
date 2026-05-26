unit obNXLSDynamicRegistrationRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSClientRegisterCapabilityRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSClientUnregisterCapabilityRequest = class(TNXJSONRPCRequest)
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

class function TNXLSClientRegisterCapabilityRequest.GetFactoryName: string;
begin
  Result := 'client/registerCapability';
end;

class function TNXLSClientRegisterCapabilityRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSRegistrationParams;
end;

function TNXLSClientRegisterCapabilityRequest.Execute: TNXJSONValue;
begin
  // Method: client/registerCapability; required: Client-side; original server: No; category: dynamic registration; result: TNXLSNullResult.
  Result := TNXLSNullResult.CreateValue;
end;

class function TNXLSClientUnregisterCapabilityRequest.GetFactoryName: string;
begin
  Result := 'client/unregisterCapability';
end;

class function TNXLSClientUnregisterCapabilityRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSUnregistrationParams;
end;

function TNXLSClientUnregisterCapabilityRequest.Execute: TNXJSONValue;
begin
  // Method: client/unregisterCapability; required: Client-side; original server: No; category: dynamic registration; result: TNXLSNullResult.
  Result := TNXLSNullResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSClientRegisterCapabilityRequest);
  TNXClassFactory.RegisterClass(TNXLSClientUnregisterCapabilityRequest);

end.
