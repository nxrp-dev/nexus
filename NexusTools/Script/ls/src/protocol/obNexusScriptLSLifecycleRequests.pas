unit obNexusScriptLSLifecycleRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

type
  TNexusScriptLSInitializeRequest = class(TNXJSONRPCRequest)
  private
    function GetParams: TNXLSInitializeParams;
    procedure SetParams(AValue: TNXLSInitializeParams);
    function GetResult: TNXLSInitializeResultValue;
    procedure SetResult(AValue: TNXLSInitializeResultValue);
  public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property params: TNXLSInitializeParams read GetParams write SetParams;
    property result: TNXLSInitializeResultValue read GetResult write SetResult;
  end;

  TNexusScriptLSInitializedRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

  TNexusScriptLSShutdownRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

  TNexusScriptLSExitRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNexusScriptLSModel;

class function TNexusScriptLSInitializeRequest.GetFactoryName: string;
begin
  Result := 'initialize';
end;

function TNexusScriptLSInitializeRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSInitializeResultValue;
begin
  TNexusScriptLSModel.Current.BeginInitialize;
  lResult := TNXLSInitializeResultValue(PrepareResult);
  lResult.capabilities.textDocumentSync.openClose.Value := True;
  lResult.capabilities.textDocumentSync.change.Value := 1;
  lResult.capabilities.textDocumentSync.save.Value := True;
  lResult.serverInfo.name.Value := 'NexusScriptLS';
  Result := lResult;
end;

class function TNexusScriptLSInitializedRequest.GetFactoryName: string;
begin
  Result := 'initialized';
end;

class function TNexusScriptLSInitializedRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNexusScriptLSInitializedRequest.Execute: TNXJSONRPCValue;
begin
  TNexusScriptLSModel.Current.MarkInitialized;
  Result := nil;
end;

class function TNexusScriptLSShutdownRequest.GetFactoryName: string;
begin
  Result := 'shutdown';
end;

class function TNexusScriptLSShutdownRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNexusScriptLSShutdownRequest.Execute: TNXJSONRPCValue;
begin
  TNexusScriptLSModel.Current.RequestShutdown;
  Result := PrepareResult;
end;

class function TNexusScriptLSExitRequest.GetFactoryName: string;
begin
  Result := 'exit';
end;

class function TNexusScriptLSExitRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNexusScriptLSExitRequest.Execute: TNXJSONRPCValue;
begin
  TNexusScriptLSModel.Current.RequestExit;
  Result := nil;
end;

function TNexusScriptLSInitializeRequest.GetParams: TNXLSInitializeParams;
begin
  Result := TNXLSInitializeParams(inherited params);
end;

procedure TNexusScriptLSInitializeRequest.SetParams(AValue: TNXLSInitializeParams);
begin
  inherited params := AValue;
end;

function TNexusScriptLSInitializeRequest.GetResult: TNXLSInitializeResultValue;
begin
  Result := TNXLSInitializeResultValue(inherited result);
end;

procedure TNexusScriptLSInitializeRequest.SetResult(
  AValue: TNXLSInitializeResultValue);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNexusScriptLSInitializeRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSInitializedRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSShutdownRequest);
  TNXClassFactory.RegisterClass(TNexusScriptLSExitRequest);

end.
