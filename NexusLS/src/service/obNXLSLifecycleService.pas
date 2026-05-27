unit obNXLSLifecycleService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolParams,
  obNXLSServiceContext;

type
  TNXLSLifecycleService = class(TNXLSLSPService)
  public
    function Initialize(AParams: TNXLSInitializeParams): TNXJSONValue; virtual;
    procedure Initialized(AParams: TNXLSInitializedParams); virtual;
    function Shutdown: TNXJSONValue; virtual;
    procedure ExitServer; virtual;
    procedure CancelRequest(AParams: TNXLSCancelParams); virtual;
  end;

implementation

uses
  obNXLSProtocolObjects;

function TNXLSLifecycleService.Initialize(AParams: TNXLSInitializeParams): TNXJSONValue;
begin
  Model.BeginInitialize(AParams);
  Result := TNXLSInitializeResult.CreateValue;
end;

procedure TNXLSLifecycleService.Initialized(AParams: TNXLSInitializedParams);
begin
  Model.MarkInitialized;
end;

function TNXLSLifecycleService.Shutdown: TNXJSONValue;
begin
  Model.RequestShutdown;
  Result := TNXLSNullResult.CreateValue;
end;

procedure TNXLSLifecycleService.ExitServer;
begin
  Model.RequestExit;
end;

procedure TNXLSLifecycleService.CancelRequest(AParams: TNXLSCancelParams);
begin
end;

end.
