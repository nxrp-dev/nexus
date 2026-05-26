unit obNXLSServer;

{$mode objfpc}{$H+}

interface

uses
  obNXLSTransport,
  obNXLSLSPModel;

type
  TNXLSServer = class
  private
    FTransport: TNXLSTransport;
    FModel: TNXLSLSPModel;
  public
    constructor Create(ATransport: TNXLSTransport);
    destructor Destroy; override;
    procedure Execute;
    property Transport: TNXLSTransport read FTransport;
    property Model: TNXLSLSPModel read FModel;
  end;

implementation

uses
  SysUtils,
  obNXLSDispatcher,
  obNXLSLogger;

constructor TNXLSServer.Create(ATransport: TNXLSTransport);
begin
  inherited Create;
  FTransport := ATransport;
  FModel := TNXLSLSPModel.Create;
  TNXLSLSPModel.SetCurrent(FModel);
end;

destructor TNXLSServer.Destroy;
begin
  TNXLSLSPModel.SetCurrent(nil);
  FModel.Free;
  FTransport.Free;
  inherited Destroy;
end;

procedure TNXLSServer.Execute;
var
  lMessage: string;
  lResponse: string;
begin
  if FTransport = nil then
    raise Exception.Create('Transport has not been assigned.');

  FTransport.Open;
  try
    TNXLSLogger.Info('NexusLS started using ' + FTransport.GetFactoryName + ' transport.');

    while FTransport.ReadMessage(lMessage) do
    begin
      if TNXLSDispatcher.DispatchMessage(lMessage, lResponse) then
        FTransport.WriteMessage(lResponse);
    end;
  finally
    FTransport.Close;
  end;
end;

end.
