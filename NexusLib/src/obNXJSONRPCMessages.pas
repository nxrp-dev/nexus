unit obNXJSONRPCMessages;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpjson,
  obNXJSONValues;

type
  ENXJSONRPC = class(Exception)
  private
    FCode: Integer;
  public
    constructor CreateCode(const ACode: Integer; const AMessage: string);
    property Code: Integer read FCode;
  end;

  TNXJSONRPCMessageKind = (
    rpcUnknown,
    rpcRequest,
    rpcNotification,
    rpcSuccessResponse,
    rpcErrorResponse,
    rpcBatch
  );

  TNXJSONRPCMessage = class;
  TNXJSONRPCMessageClass = class of TNXJSONRPCMessage;
  TNXJSONRPCRequest = class;
  TNXJSONRPCRequestClass = class of TNXJSONRPCRequest;

  TNXJSONRPCMessage = class(TNXJSONObject)
  private
    Fjsonrpc: TNXJSONString;
    Fid: TNXJSONValue;
    Fmethod: TNXJSONString;
    Fparams: TNXJSONValue;
    Fresult: TNXJSONValue;
    Ferror: TNXJSONValue;
  public
    function Kind: TNXJSONRPCMessageKind;

    function HasID: Boolean;
    function HasParams: Boolean;
    function IDJSON: TJSONData;
    function ParamsObject: TNXJSONObject;

  published
    property jsonrpc: TNXJSONString read Fjsonrpc write Fjsonrpc;
    property id: TNXJSONValue read Fid write Fid;
    property method: TNXJSONString read Fmethod write Fmethod;
    property params: TNXJSONValue read Fparams write Fparams;
    property result: TNXJSONValue read Fresult write Fresult;
    property error: TNXJSONValue read Ferror write Ferror;
  end;

  TNXJSONRPCError = class(TNXJSONObject)
  private
    Fcode: TNXJSONInteger;
    Fmessage: TNXJSONString;
    Fdata: TNXJSONValue;
  published
    property code: TNXJSONInteger read Fcode write Fcode;
    property message: TNXJSONString read Fmessage write Fmessage;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXJSONRPCRequest = class(TNXJSONRPCMessage)
  protected
    function PrepareResult: TNXJSONValue; virtual;
  public
    class function GetParamClass: TNXJSONValueClass; virtual;
    class function GetResultClass: TNXJSONValueClass; virtual;
    function Execute: TNXJSONValue; virtual; abstract;
    procedure ValidateResult(AResult: TNXJSONValue); virtual;
    procedure FromJSONData(AData: TJSONData); override;
  end;

  TNXJSONRPC = class
  public
    const Version = '2.0';
    const ParseError = -32700;
    const InvalidRequest = -32600;
    const MethodNotFound = -32601;
    const InvalidParams = -32602;
    const InternalError = -32603;

    class function ParseMessage(const AJSON: string): TNXJSONRPCMessage; overload; static;
    class function ParseMessage(const AJSON: string; AMessageClass: TNXJSONRPCMessageClass): TNXJSONRPCMessage; overload; static;
    class procedure ValidateMessage(AMessage: TNXJSONRPCMessage); static;
    class function CreateSuccessResponse(AID: TJSONData; AResult: TNXJSONValue): TJSONObject; static;
    class function CreateErrorResponse(AID: TJSONData; const ACode: Integer; const AMessage: string; AData: TNXJSONValue = nil): TJSONObject; static;
  end;

implementation

uses
  jsonparser;

constructor ENXJSONRPC.CreateCode(const ACode: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FCode := ACode;
end;

function TNXJSONRPCMessage.Kind: TNXJSONRPCMessageKind;
begin
  if (Self.method <> nil) and Self.method.Assigned then
  begin
    if HasID then
      Result := rpcRequest
    else
      Result := rpcNotification;
  end
  else if (Self.result <> nil) and Self.result.Assigned then
    Result := rpcSuccessResponse
  else if (Self.error <> nil) and Self.error.Assigned then
    Result := rpcErrorResponse
  else
    Result := rpcUnknown;
end;

function TNXJSONRPCMessage.HasID: Boolean;
begin
  Result := (id <> nil) and id.Assigned;
end;

function TNXJSONRPCMessage.HasParams: Boolean;
begin
  Result := (params <> nil) and params.Assigned;
end;

function TNXJSONRPCMessage.IDJSON: TJSONData;
begin
  if HasID then
    Result := id.ToJSONData
  else
    Result := TJSONNull.Create;
end;

function TNXJSONRPCMessage.ParamsObject: TNXJSONObject;
begin
  if (params <> nil) and (params is TNXJSONObject) then
    Result := TNXJSONObject(params)
  else
    Result := nil;
end;

class function TNXJSONRPCRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := nil;
end;

class function TNXJSONRPCRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := nil;
end;

function TNXJSONRPCRequest.PrepareResult: TNXJSONValue;
var
  lResultClass: TNXJSONValueClass;
begin
  lResultClass := GetResultClass;
  if lResultClass = nil then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.GetResultClass returned nil.');

  Result := lResultClass.Create;
  try
    ValidateResult(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TNXJSONRPCRequest.ValidateResult(AResult: TNXJSONValue);
var
  lResultClass: TNXJSONValueClass;
begin
  lResultClass := GetResultClass;

  if AResult = nil then
  begin
    if lResultClass = nil then
      Exit;

    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned nil result.');
  end;

  if AResult.ClassType = TNXJSONValue then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned raw TNXJSONValue result. This should never happen.');

  if (lResultClass <> nil) and (not AResult.InheritsFrom(lResultClass)) then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned ' + AResult.ClassName +
      ' but expected ' + lResultClass.ClassName + '.');
end;

procedure TNXJSONRPCRequest.FromJSONData(AData: TJSONData);
var
  lObject: TJSONObject;
  lParamsJSON: TJSONData;
  lParamClass: TNXJSONValueClass;
begin
  inherited FromJSONData(AData);

  lParamClass := GetParamClass;
  if (AData = nil) or (AData.JSONType <> jtObject) then
    Exit;

  lObject := TJSONObject(AData);
  lParamsJSON := lObject.Find('params');
  if lParamsJSON = nil then
    Exit;

  if lParamClass = nil then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InvalidParams, 'JSON-RPC method does not accept params.');

  FreeAndNil(Fparams);
  Fparams := lParamClass.Create;
  Fparams.FromJSONData(lParamsJSON);
end;

class function TNXJSONRPC.ParseMessage(const AJSON: string): TNXJSONRPCMessage;
begin
  Result := ParseMessage(AJSON, TNXJSONRPCMessage);
end;

class function TNXJSONRPC.ParseMessage(const AJSON: string; AMessageClass: TNXJSONRPCMessageClass): TNXJSONRPCMessage;
var
  lJSON: TJSONData;
begin
  if AMessageClass = nil then
    AMessageClass := TNXJSONRPCMessage;

  lJSON := nil;
  try
    try
      lJSON := GetJSON(AJSON);
    except
      on E: Exception do
        raise ENXJSONRPC.CreateCode(ParseError, E.Message);
    end;

    if not (lJSON is TJSONObject) then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC message must be a JSON object.');

    Result := AMessageClass.Create;
    try
      Result.FromJSONData(lJSON);
      ValidateMessage(Result);
    except
      Result.Free;
      raise;
    end;
  finally
    lJSON.Free;
  end;
end;

class procedure TNXJSONRPC.ValidateMessage(AMessage: TNXJSONRPCMessage);
var
  lIDJSON: TJSONData;
  lParamsJSON: TJSONData;
  lErrorJSON: TJSONData;
  lErrorObject: TJSONObject;
  lKind: TNXJSONRPCMessageKind;
begin
  if AMessage = nil then
    raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC message cannot be nil.');

  if (AMessage.jsonrpc = nil) or (not AMessage.jsonrpc.Assigned) or (AMessage.jsonrpc.Value <> Version) then
    raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC message must contain jsonrpc = "2.0".');

  lKind := AMessage.Kind;
  if not (lKind in [rpcRequest, rpcNotification, rpcSuccessResponse, rpcErrorResponse]) then
    raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC message shape is invalid.');

  if lKind in [rpcRequest, rpcNotification] then
  begin
    if (AMessage.method = nil) or (not AMessage.method.Assigned) or (AMessage.method.Value = '') then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC request must contain a non-empty method string.');

    if (AMessage.result <> nil) and AMessage.result.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC request cannot contain result.');

    if (AMessage.error <> nil) and AMessage.error.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC request cannot contain error.');

    if AMessage.HasParams then
    begin
      lParamsJSON := AMessage.params.ToJSONData;
      try
        if not (lParamsJSON.JSONType in [jtArray, jtObject]) then
          raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC params must be an object or array.');
      finally
        lParamsJSON.Free;
      end;
    end;
  end
  else
  begin
    if (AMessage.method <> nil) and AMessage.method.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response cannot contain method.');

    if (AMessage.params <> nil) and AMessage.params.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response cannot contain params.');

    if not AMessage.HasID then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response must contain id.');
  end;

  if lKind = rpcSuccessResponse then
  begin
    if (AMessage.error <> nil) and AMessage.error.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response cannot contain both result and error.');
  end;

  if lKind = rpcErrorResponse then
  begin
    if (AMessage.result <> nil) and AMessage.result.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response cannot contain both result and error.');

    lErrorJSON := AMessage.error.ToJSONData;
    try
      if not (lErrorJSON is TJSONObject) then
        raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC error must be an object.');

      lErrorObject := TJSONObject(lErrorJSON);
      if (lErrorObject.Find('code') = nil) or
        (lErrorObject.Find('code').JSONType <> jtNumber) or
        (Pos('.', lErrorObject.Find('code').AsJSON) > 0) then
        raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC error code must be an integer.');

      if (lErrorObject.Find('message') = nil) or
        (lErrorObject.Find('message').JSONType <> jtString) then
        raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC error message must be a string.');
    finally
      lErrorJSON.Free;
    end;
  end;

  if AMessage.HasID then
  begin
    lIDJSON := AMessage.IDJSON;
    try
      if not (lIDJSON.JSONType in [jtNull, jtString, jtNumber]) then
        raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC id must be a string, number, or null.');

      if (lIDJSON.JSONType = jtNumber) and (Pos('.', lIDJSON.AsJSON) > 0) then
        raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC numeric id must not contain a fractional part.');
    finally
      lIDJSON.Free;
    end;
  end;
end;

class function TNXJSONRPC.CreateSuccessResponse(AID: TJSONData; AResult: TNXJSONValue): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('jsonrpc', Version);

    if AID = nil then
      Result.Add('id', TJSONNull.Create)
    else
      Result.Add('id', AID.Clone);

    if AResult = nil then
      Result.Add('result', TJSONNull.Create)
    else
      Result.Add('result', AResult.ToJSONData);
  except
    Result.Free;
    raise;
  end;
end;

class function TNXJSONRPC.CreateErrorResponse(AID: TJSONData; const ACode: Integer; const AMessage: string; AData: TNXJSONValue): TJSONObject;
var
  lError: TNXJSONRPCError;
begin
  Result := TJSONObject.Create;
  lError := nil;
  try
    Result.Add('jsonrpc', Version);

    if AID = nil then
      Result.Add('id', TJSONNull.Create)
    else
      Result.Add('id', AID.Clone);

    lError := TNXJSONRPCError.Create;
    lError.code.Value := ACode;
    lError.message.Value := AMessage;
    if AData <> nil then
      lError.data.Assign(AData);

    Result.Add('error', lError.ToJSONData);
    FreeAndNil(lError);
  except
    lError.Free;
    Result.Free;
    raise;
  end;
end;

end.
