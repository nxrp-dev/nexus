unit obNXLSLifecycleRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSInitializeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSInitializedRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSShutdownRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSExitRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSDollarcancelRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSDollarprogressRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSDollarsetTraceRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSDollarlogTraceRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSInitializeRequest.GetFactoryName: string;
begin
  Result := 'initialize';
end;

class function TNXLSInitializeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInitializeParams;
end;

class function TNXLSInitializeRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSInitializeResultValue;
end;

function TNXLSInitializeRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSInitializeResultValue;
begin
  lResult := TNXLSInitializeResultValue(PrepareResult);
  TNXLSLSPModel.Current.Lifecycle.FillInitializeResult(TNXLSInitializeParams(params),
    lResult);
  Result := lResult;
end;

class function TNXLSInitializedRequest.GetFactoryName: string;
begin
  Result := 'initialized';
end;

class function TNXLSInitializedRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInitializedParams;
end;

class function TNXLSInitializedRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSInitializedRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Lifecycle.Initialized(TNXLSInitializedParams(params));
  Result := nil;
end;

class function TNXLSShutdownRequest.GetFactoryName: string;
begin
  Result := 'shutdown';
end;

class function TNXLSShutdownRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSShutdownRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Lifecycle.Shutdown;
  Result := PrepareResult;
end;

class function TNXLSExitRequest.GetFactoryName: string;
begin
  Result := 'exit';
end;

class function TNXLSExitRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSExitRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Lifecycle.ExitServer;
  Result := nil;
end;

class function TNXLSDollarcancelRequest.GetFactoryName: string;
begin
  Result := '$/cancelRequest';
end;

class function TNXLSDollarcancelRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCancelParams;
end;

class function TNXLSDollarcancelRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSDollarcancelRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Lifecycle.CancelRequest(TNXLSCancelParams(params));
  Result := nil;
end;

class function TNXLSDollarprogressRequest.GetFactoryName: string;
begin
  Result := '$/progress';
end;

class function TNXLSDollarprogressRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSProgressParams;
end;

class function TNXLSDollarprogressRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSDollarprogressRequest.Execute: TNXJSONValue;
begin
  // Method: $/progress; required: Optional; original server: No; category: lifecycle; result: nil.
  Result := nil;
end;

class function TNXLSDollarsetTraceRequest.GetFactoryName: string;
begin
  Result := '$/setTrace';
end;

class function TNXLSDollarsetTraceRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSSetTraceParams;
end;

class function TNXLSDollarsetTraceRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSDollarsetTraceRequest.Execute: TNXJSONValue;
begin
  // Method: $/setTrace; required: Optional; original server: No; category: lifecycle; result: nil.
  Result := nil;
end;

class function TNXLSDollarlogTraceRequest.GetFactoryName: string;
begin
  Result := '$/logTrace';
end;

class function TNXLSDollarlogTraceRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSLogTraceParams;
end;

class function TNXLSDollarlogTraceRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSDollarlogTraceRequest.Execute: TNXJSONValue;
begin
  // Method: $/logTrace; required: Client-side; original server: No; category: lifecycle; result: nil.
  Result := nil;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSInitializeRequest);
  TNXClassFactory.RegisterClass(TNXLSInitializedRequest);
  TNXClassFactory.RegisterClass(TNXLSShutdownRequest);
  TNXClassFactory.RegisterClass(TNXLSExitRequest);
  TNXClassFactory.RegisterClass(TNXLSDollarcancelRequest);
  TNXClassFactory.RegisterClass(TNXLSDollarprogressRequest);
  TNXClassFactory.RegisterClass(TNXLSDollarsetTraceRequest);
  TNXClassFactory.RegisterClass(TNXLSDollarlogTraceRequest);

end.
