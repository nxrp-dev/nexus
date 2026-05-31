unit obNXLSLifecycleRequests;

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
  TNXLSInitializeRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSInitializeParams;
    procedure SetParams(AValue: TNXLSInitializeParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSInitializeParams read GetParams write SetParams;
  end;

  TNXLSInitializedRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSInitializedParams;
    procedure SetParams(AValue: TNXLSInitializedParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSInitializedParams read GetParams write SetParams;
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
    private
    function GetParams: TNXLSCancelParams;
    procedure SetParams(AValue: TNXLSCancelParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCancelParams read GetParams write SetParams;
  end;

  TNXLSDollarprogressRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSProgressParams;
    procedure SetParams(AValue: TNXLSProgressParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSProgressParams read GetParams write SetParams;
  end;

  TNXLSDollarsetTraceRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSSetTraceParams;
    procedure SetParams(AValue: TNXLSSetTraceParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSSetTraceParams read GetParams write SetParams;
  end;

  TNXLSDollarlogTraceRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSLogTraceParams;
    procedure SetParams(AValue: TNXLSLogTraceParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSLogTraceParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  tpNXLS;

class function TNXLSInitializeRequest.GetFactoryName: string;
begin
  Result := 'initialize';
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

class function TNXLSDollarprogressRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSDollarprogressRequest.Execute: TNXJSONValue;
begin
  // Method: $/progress; required: Optional; original server: No; category: lifecycle; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSDollarsetTraceRequest.GetFactoryName: string;
begin
  Result := '$/setTrace';
end;

class function TNXLSDollarsetTraceRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSDollarsetTraceRequest.Execute: TNXJSONValue;
begin
  // Method: $/setTrace; required: Optional; original server: No; category: lifecycle; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSDollarlogTraceRequest.GetFactoryName: string;
begin
  Result := '$/logTrace';
end;

class function TNXLSDollarlogTraceRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSDollarlogTraceRequest.Execute: TNXJSONValue;
begin
  // Method: $/logTrace; required: Client-side; original server: No; category: lifecycle; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSInitializeRequest.GetParams: TNXLSInitializeParams;
begin
  Result := TNXLSInitializeParams(inherited params);
end;

procedure TNXLSInitializeRequest.SetParams(AValue: TNXLSInitializeParams);
begin
  inherited params := AValue;
end;

function TNXLSDollarsetTraceRequest.GetParams: TNXLSSetTraceParams;
begin
  Result := TNXLSSetTraceParams(inherited params);
end;

procedure TNXLSDollarsetTraceRequest.SetParams(AValue: TNXLSSetTraceParams);
begin
  inherited params := AValue;
end;

function TNXLSDollarcancelRequest.GetParams: TNXLSCancelParams;
begin
  Result := TNXLSCancelParams(inherited params);
end;

procedure TNXLSDollarcancelRequest.SetParams(AValue: TNXLSCancelParams);
begin
  inherited params := AValue;
end;

function TNXLSDollarprogressRequest.GetParams: TNXLSProgressParams;
begin
  Result := TNXLSProgressParams(inherited params);
end;

procedure TNXLSDollarprogressRequest.SetParams(AValue: TNXLSProgressParams);
begin
  inherited params := AValue;
end;

function TNXLSInitializedRequest.GetParams: TNXLSInitializedParams;
begin
  Result := TNXLSInitializedParams(inherited params);
end;

procedure TNXLSInitializedRequest.SetParams(AValue: TNXLSInitializedParams);
begin
  inherited params := AValue;
end;

function TNXLSDollarlogTraceRequest.GetParams: TNXLSLogTraceParams;
begin
  Result := TNXLSLogTraceParams(inherited params);
end;

procedure TNXLSDollarlogTraceRequest.SetParams(AValue: TNXLSLogTraceParams);
begin
  inherited params := AValue;
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
