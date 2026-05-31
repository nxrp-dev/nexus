unit obNXLSLifecycleService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext;

type
  TNXLSLifecycleService = class(TNXLSLSPService)
  public
    procedure FillInitializeResult(AParams: TNXLSInitializeParams;
      AResult: TNXLSInitializeResultValue); virtual;
    procedure Initialized(AParams: TNXLSInitializedParams); virtual;
    procedure Shutdown; virtual;
    procedure ExitServer; virtual;
    procedure CancelRequest(AParams: TNXLSCancelParams); virtual;
  end;

implementation

procedure TNXLSLifecycleService.FillInitializeResult(AParams: TNXLSInitializeParams;
  AResult: TNXLSInitializeResultValue);
var
  lValue: TNXJSONValue;
begin
  Model.BeginInitialize(AParams);
  if AResult = nil then
    Exit;

  lValue := TNXLSInitializeResult.CreateValue;
  try
    AResult.Assign(lValue);
  finally
    lValue.Free;
  end;
end;

procedure TNXLSLifecycleService.Initialized(AParams: TNXLSInitializedParams);
begin
  Model.MarkInitialized;
end;

procedure TNXLSLifecycleService.Shutdown;
begin
  Model.RequestShutdown;
end;

procedure TNXLSLifecycleService.ExitServer;
begin
  Model.RequestExit;
end;

procedure TNXLSLifecycleService.CancelRequest(AParams: TNXLSCancelParams);
begin
end;

end.
