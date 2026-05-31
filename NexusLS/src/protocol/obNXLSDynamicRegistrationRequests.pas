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
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSClientUnregisterCapabilityRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams;

class function TNXLSClientRegisterCapabilityRequest.GetFactoryName: string;
begin
  Result := 'client/registerCapability';
end;

class function TNXLSClientRegisterCapabilityRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSRegistrationParams;
end;

class function TNXLSClientRegisterCapabilityRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSClientRegisterCapabilityRequest.Execute: TNXJSONValue;
begin
  // Method: client/registerCapability; required: Client-side; original server: No; category: dynamic registration; result: TNXLSNullResult.
  Result := PrepareResult;
end;

class function TNXLSClientUnregisterCapabilityRequest.GetFactoryName: string;
begin
  Result := 'client/unregisterCapability';
end;

class function TNXLSClientUnregisterCapabilityRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSUnregistrationParams;
end;

class function TNXLSClientUnregisterCapabilityRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSClientUnregisterCapabilityRequest.Execute: TNXJSONValue;
begin
  // Method: client/unregisterCapability; required: Client-side; original server: No; category: dynamic registration; result: TNXLSNullResult.
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSClientRegisterCapabilityRequest);
  TNXClassFactory.RegisterClass(TNXLSClientUnregisterCapabilityRequest);

end.
