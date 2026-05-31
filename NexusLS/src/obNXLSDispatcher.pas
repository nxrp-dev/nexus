unit obNXLSDispatcher;

{$mode objfpc}{$H+}

interface

type
  TNXLSDispatcher = class
  public
    class function DispatchMessage(const AMessage: string; out AResponse: string): Boolean; static;
  end;

implementation

uses
  SysUtils,
  fpjson,
  jsonparser,
  obNXClassFactory,
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSLogger,
  obNXLSAllRequests;

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

class function TNXLSDispatcher.DispatchMessage(const AMessage: string; out AResponse: string): Boolean;
var
  lMessage: TNXJSONRPCMessage;
  lRequest: TNXJSONRPCRequest;
  lID: TJSONData;
  lMethod: string;
  lRequestClass: TNXJSONRPCRequestClass;
  lResult: TNXJSONValue;
  lResponse: TJSONObject;
  lIsRequest: Boolean;
begin
  AResponse := '';
  Result := False;
  lMessage := nil;
  lRequest := nil;
  lID := nil;
  lResult := nil;
  lResponse := nil;
  lIsRequest := False;

  try
    try
      try
        lMessage := TNXJSONRPC.ParseMessage(AMessage);
      except
        on E: ENXJSONRPC do
        begin
          lID := ExtractErrorID(AMessage);
          AResponse := CreateErrorResponse(lID, E.Code, E.Message);
          Exit(True);
        end;
        on E: Exception do
        begin
          AResponse := CreateErrorResponse(nil, TNXJSONRPC.ParseError, E.Message);
          Exit(True);
        end;
      end;

      lIsRequest := lMessage.Kind = rpcRequest;
      if not (lMessage.Kind in [rpcRequest, rpcNotification]) then
        Exit(False);

      lMethod := lMessage.method.Value;
      if not TNXClassFactory.Registered(lMethod) then
      begin
        if lIsRequest then
        begin
          lID := lMessage.IDJSON;
          AResponse := CreateErrorResponse(lID, TNXJSONRPC.MethodNotFound, 'Method not found: ' + lMethod);
          Exit(True);
        end;

        Exit(False);
      end;

      lRequestClass := TNXJSONRPCRequestClass(TNXClassFactory.FindClass(lMethod));
      if lIsRequest then
        lID := lMessage.IDJSON;

      try
        FreeAndNil(lMessage);
        lRequest := TNXJSONRPCRequest(TNXJSONRPC.ParseMessage(AMessage, lRequestClass));
      except
        on E: ENXJSONRPC do
        begin
          if lIsRequest then
          begin
            AResponse := CreateErrorResponse(lID, E.Code, E.Message);
            Exit(True);
          end;

          Exit(False);
        end;
        on E: Exception do
        begin
          if lIsRequest then
          begin
            AResponse := CreateErrorResponse(lID, TNXJSONRPC.InvalidParams, E.Message);
            Exit(True);
          end;

          Exit(False);
        end;
      end;

      lResult := lRequest.Execute;
      lRequest.ValidateResult(lResult);

      if lIsRequest then
      begin
        FreeAndNil(lID);
        lID := lRequest.IDJSON;
        lResponse := TNXJSONRPC.CreateSuccessResponse(lID, lResult);
        try
          AResponse := lResponse.AsJSON;
          Exit(True);
        finally
          lResponse.Free;
        end;
      end;
    except
      on E: Exception do
      begin
        if lIsRequest then
        begin
          FreeAndNil(lID);
          if lRequest <> nil then
            lID := lRequest.IDJSON;
          AResponse := CreateErrorResponse(lID, TNXJSONRPC.InternalError, E.Message);
          Exit(True);
        end;

        TNXLSLogger.Error('Notification "' + lMethod + '" failed: ' + E.Message);
        Exit(False);
      end;
    end;
  finally
    lResult.Free;
    lID.Free;
    lRequest.Free;
    lMessage.Free;
  end;
end;

end.
