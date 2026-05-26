unit obNXLSProgressRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWindowWorkDoneProgressCreateRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWindowWorkDoneProgressCancelRequest = class(TNXJSONRPCRequest)
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

class function TNXLSWindowWorkDoneProgressCreateRequest.GetFactoryName: string;
begin
  Result := 'window/workDoneProgress/create';
end;

class function TNXLSWindowWorkDoneProgressCreateRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkDoneProgressCreateParams;
end;

function TNXLSWindowWorkDoneProgressCreateRequest.Execute: TNXJSONValue;
begin
  // Method: window/workDoneProgress/create; required: Client-side; original server: No; category: progress; result: TNXLSNullResult.
  Result := TNXLSNullResult.CreateValue;
end;

class function TNXLSWindowWorkDoneProgressCancelRequest.GetFactoryName: string;
begin
  Result := 'window/workDoneProgress/cancel';
end;

class function TNXLSWindowWorkDoneProgressCancelRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkDoneProgressCancelParams;
end;

function TNXLSWindowWorkDoneProgressCancelRequest.Execute: TNXJSONValue;
begin
  // Method: window/workDoneProgress/cancel; required: Client-side; original server: No; category: progress; result: nil.
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWindowWorkDoneProgressCreateRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowWorkDoneProgressCancelRequest);

end.
