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
  fpjson,
  jsonparser,
  obNXJSONRPCMessages,
  obNXLSDispatcher,
  obNXLSLogger;

function ExtractErrorID(const AMessage: string): TJSONData;
var
  lJSON: TJSONData;
  lID: TJSONData;
begin
  Result := nil;
  lJSON := nil;
  try
    try
      lJSON := GetJSON(AMessage);
      if not (lJSON is TJSONObject) then
        Exit;

      lID := TJSONObject(lJSON).Find('id');
      if lID = nil then
        Exit;

      if not (lID.JSONType in [jtNull, jtString, jtNumber]) then
        Exit;

      if (lID.JSONType = jtNumber) and (Pos('.', lID.AsJSON) > 0) then
        Exit;

      Result := lID.Clone;
    except
      FreeAndNil(Result);
    end;
  finally
    lJSON.Free;
  end;
end;

function CreateErrorResponse(const AID: TJSONData; const ACode: Integer; const AMessage: string): string;
var
  lResponse: TJSONObject;
begin
  lResponse := TNXJSONRPC.CreateErrorResponse(AID, ACode, AMessage);
  try
    Result := lResponse.AsJSON;
  finally
    lResponse.Free;
  end;
end;

constructor TNXLSServer.Create(ATransport: TNXLSTransport);
begin
  inherited Create;
  FTransport := ATransport;
  FModel := TNXLSLSPModel.Create;
  FModel.Transport := FTransport;
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
  lID: TJSONData;
  lMessage: string;
  lResponse: string;
  lRPCMessage: TNXJSONRPCMessage;
begin
  if FTransport = nil then
    raise Exception.Create('Transport has not been assigned.');

  FTransport.Open;
  try
    TNXLSLogger.Info('NexusLS started using ' + FTransport.GetFactoryName + ' transport.');

    while FTransport.ReadMessage(lMessage) do
    begin
      lRPCMessage := nil;
      try
        try
          lRPCMessage := TNXJSONRPC.ParseMessage(lMessage);
        except
          on E: ENXJSONRPC do
          begin
            lID := ExtractErrorID(lMessage);
            try
              FTransport.WriteMessage(CreateErrorResponse(lID, E.Code, E.Message));
            finally
              lID.Free;
            end;
            Continue;
          end;
          on E: Exception do
          begin
            FTransport.WriteMessage(CreateErrorResponse(nil, TNXJSONRPC.ParseError, E.Message));
            Continue;
          end;
        end;

        case lRPCMessage.MessageType of
          rpcmtRequest,
          rpcmtNotification:
            if TNXLSDispatcher.DispatchMessage(lRPCMessage, lResponse) and
              (lResponse <> '') then
              FTransport.WriteMessage(lResponse);

          rpcmtSuccessResponse,
          rpcmtErrorResponse:
            FModel.ReceiveClientResponse(lRPCMessage);
        end;
      finally
        lRPCMessage.Free;
      end;
    end;
  finally
    FTransport.Close;
  end;
end;

end.
