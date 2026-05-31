unit obNXLSDynamicRegistrationRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSClientRegisterCapabilityRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSRegistrationParams;
    procedure SetParams(AValue: TNXLSRegistrationParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSRegistrationParams read GetParams write SetParams;
  end;

  TNXLSClientUnregisterCapabilityRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSUnregistrationParams;
    procedure SetParams(AValue: TNXLSUnregistrationParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSUnregistrationParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSClientRegisterCapabilityRequest.GetFactoryName: string;
begin
  Result := 'client/registerCapability';
end;

class function TNXLSClientRegisterCapabilityRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSClientRegisterCapabilityRequest.Execute: TNXJSONValue;
begin
  // Method: client/registerCapability; required: Client-side; original server: No; category: dynamic registration; result: TNXLSNullResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSClientUnregisterCapabilityRequest.GetFactoryName: string;
begin
  Result := 'client/unregisterCapability';
end;

class function TNXLSClientUnregisterCapabilityRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSClientUnregisterCapabilityRequest.Execute: TNXJSONValue;
begin
  // Method: client/unregisterCapability; required: Client-side; original server: No; category: dynamic registration; result: TNXLSNullResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSClientRegisterCapabilityRequest.GetParams: TNXLSRegistrationParams;
begin
  Result := TNXLSRegistrationParams(inherited params);
end;

procedure TNXLSClientRegisterCapabilityRequest.SetParams(AValue: TNXLSRegistrationParams);
begin
  inherited params := AValue;
end;

function TNXLSClientUnregisterCapabilityRequest.GetParams: TNXLSUnregistrationParams;
begin
  Result := TNXLSUnregistrationParams(inherited params);
end;

procedure TNXLSClientUnregisterCapabilityRequest.SetParams(AValue: TNXLSUnregistrationParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSClientRegisterCapabilityRequest);
  TNXClassFactory.RegisterClass(TNXLSClientUnregisterCapabilityRequest);

end.
