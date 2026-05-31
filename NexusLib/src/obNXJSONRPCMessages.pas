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

  TNXJSONRPCResultKind = (
    rkNoResult,
    rkNullResult,
    rkConcreteResult,
    rkNullableConcreteResult
  );

  TNXJSONRPCMessage = class;
  TNXJSONRPCMessageClass = class of TNXJSONRPCMessage;
  TNXJSONRPCCommandMessage = class;
  TNXJSONRPCNotification = class;
  TNXJSONRPCResponse = class;
  TNXJSONCommandResult = class;
  TNXJSONCommandResultClass = class of TNXJSONCommandResult;
  TNXJSONRPCRequest = class;
  TNXJSONRPCRequestClass = class of TNXJSONRPCRequest;
  TNXJSONRPCOutboundCommand = class;
  TNXJSONRPCOutboundCommandClass = class of TNXJSONRPCOutboundCommand;

  TNXJSONRPCMessage = class(TNXJSONObject)
  private
    Fjsonrpc: TNXJSONString;
    Fid: TNXJSONValue;
  public
    function Kind: TNXJSONRPCMessageKind;

    function HasID: Boolean;
    function IDJSON: TJSONData;

  published
    property jsonrpc: TNXJSONString read Fjsonrpc write Fjsonrpc;
    property id: TNXJSONValue read Fid write Fid;
  end;

  TNXJSONRPCCommandMessage = class(TNXJSONRPCMessage)
  private
    Fmethod: TNXJSONString;
    Fparams: TNXJSONObjectParams;
  public
    function HasParams: Boolean;
    function ParamsObject: TNXJSONObject;
  published
    property method: TNXJSONString read Fmethod write Fmethod;
    property params: TNXJSONObjectParams read Fparams write Fparams;
  end;

  TNXJSONRPCNotification = class(TNXJSONRPCCommandMessage)
  end;

  TNXJSONRPCResponse = class(TNXJSONRPCMessage)
  private
    Fresult: TNXJSONValue;
    Ferror: TNXJSONValue;
  published
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

  TNXJSONCommandResult = class(TNXJSONObject)
  end;

  TNXJSONRPCRequest = class(TNXJSONRPCCommandMessage)
  protected
    function PrepareResult: TNXJSONValue; virtual;
  public
    class function GetParamClass: TNXJSONValueClass; virtual;
    class function GetResultClass: TNXJSONValueClass; virtual;
    class function GetResultKind: TNXJSONRPCResultKind; virtual;
    function Execute: TNXJSONValue; virtual; abstract;
    procedure ValidateResult(AResult: TNXJSONValue); virtual;
  end;

  TNXJSONRPCOutboundCommand = class(TNXJSONRPCCommandMessage)
  private
    FCommandResult: TNXJSONCommandResult;
    FCommandError: TNXJSONRPCError;
  public
    destructor Destroy; override;
    class function GetResultClass: TNXJSONCommandResultClass; virtual;
    class function GetResultKind: TNXJSONRPCResultKind; virtual;
    procedure LoadOutboundResponse(AResponse: TNXJSONRPCResponse); virtual;
    procedure ProcessOutboundResult; virtual;
    procedure ProcessOutboundError; virtual;
    procedure ProcessOutboundTimeout; virtual;
    procedure ValidateResult(AResult: TNXJSONValue); virtual;
    property CommandError: TNXJSONRPCError read FCommandError;
    property CommandResult: TNXJSONCommandResult read FCommandResult;
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
  if Self is TNXJSONRPCCommandMessage then
  begin
    if HasID then
      Result := rpcRequest
    else
      Result := rpcNotification;
  end
  else if (Self is TNXJSONRPCResponse) and
    (TNXJSONRPCResponse(Self).result <> nil) and
    TNXJSONRPCResponse(Self).result.Assigned then
    Result := rpcSuccessResponse
  else if (Self is TNXJSONRPCResponse) and
    (TNXJSONRPCResponse(Self).error <> nil) and
    TNXJSONRPCResponse(Self).error.Assigned then
    Result := rpcErrorResponse
  else
    Result := rpcUnknown;
end;

function TNXJSONRPCMessage.HasID: Boolean;
begin
  Result := (id <> nil) and id.Assigned;
end;

function TNXJSONRPCCommandMessage.HasParams: Boolean;
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

function TNXJSONRPCCommandMessage.ParamsObject: TNXJSONObject;
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

class function TNXJSONRPCRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkConcreteResult;
end;

function TNXJSONRPCRequest.PrepareResult: TNXJSONValue;
var
  lResultClass: TNXJSONValueClass;
  lResultKind: TNXJSONRPCResultKind;
begin
  lResultKind := GetResultKind;
  if lResultKind = rkNoResult then
    Exit(nil);
  if lResultKind = rkNullResult then
    Exit(TNXJSONNull.Create);

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
  lResultKind: TNXJSONRPCResultKind;
begin
  lResultKind := GetResultKind;

  if AResult = nil then
  begin
    if lResultKind = rkNoResult then
      Exit;

    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned nil result.');
  end;

  if AResult.ClassType = TNXJSONValue then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned raw TNXJSONValue result. This should never happen.');

  if AResult is TNXJSONNull then
  begin
    if lResultKind in [rkNullResult, rkNullableConcreteResult] then
      Exit;

    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned null but null is not allowed for this result.');
  end;

  if not (lResultKind in [rkConcreteResult, rkNullableConcreteResult]) then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned ' + AResult.ClassName +
      ' but this result kind does not allow a concrete result.');

  lResultClass := GetResultClass;
  if lResultClass = nil then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.GetResultClass returned nil.');

  if not AResult.InheritsFrom(lResultClass) then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.Execute returned ' + AResult.ClassName +
      ' but expected ' + lResultClass.ClassName + '.');
end;

destructor TNXJSONRPCOutboundCommand.Destroy;
begin
  FreeAndNil(FCommandError);
  FreeAndNil(FCommandResult);
  inherited Destroy;
end;

class function TNXJSONRPCOutboundCommand.GetResultClass: TNXJSONCommandResultClass;
begin
  Result := nil;
end;

class function TNXJSONRPCOutboundCommand.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkConcreteResult;
end;

procedure TNXJSONRPCOutboundCommand.ValidateResult(AResult: TNXJSONValue);
var
  lResultClass: TNXJSONCommandResultClass;
  lResultKind: TNXJSONRPCResultKind;
begin
  lResultKind := GetResultKind;

  if AResult = nil then
  begin
    if lResultKind = rkNoResult then
      Exit;

    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + ' received nil result.');
  end;

  if AResult.ClassType = TNXJSONValue then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + ' received raw TNXJSONValue result. This should never happen.');

  if AResult is TNXJSONNull then
  begin
    if lResultKind in [rkNullResult, rkNullableConcreteResult] then
      Exit;

    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + ' received null but null is not allowed for this result.');
  end;

  if not (lResultKind in [rkConcreteResult, rkNullableConcreteResult]) then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + ' received ' + AResult.ClassName +
      ' but this result kind does not allow a concrete result.');

  lResultClass := GetResultClass;
  if lResultClass = nil then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + '.GetResultClass returned nil.');

  if not AResult.InheritsFrom(lResultClass) then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
      ClassName + ' received ' + AResult.ClassName +
      ' but expected ' + lResultClass.ClassName + '.');
end;

procedure TNXJSONRPCOutboundCommand.LoadOutboundResponse(AResponse: TNXJSONRPCResponse);
var
  lJSON: TJSONData;
  lNullResult: TNXJSONNull;
  lResultClass: TNXJSONCommandResultClass;
begin
  if AResponse = nil then
    raise ENXJSONRPC.CreateCode(TNXJSONRPC.InvalidRequest,
      'JSON-RPC response cannot be nil.');

  if AResponse.Kind = rpcSuccessResponse then
  begin
    if (AResponse.result = nil) or (not AResponse.result.Assigned) then
      raise ENXJSONRPC.CreateCode(TNXJSONRPC.InvalidRequest,
        'JSON-RPC success response is missing result.');

    if AResponse.result is TNXJSONNull then
    begin
      lNullResult := TNXJSONNull.Create;
      try
        ValidateResult(lNullResult);
      finally
        lNullResult.Free;
      end;
      Exit;
    end;

    lResultClass := GetResultClass;
    if lResultClass = nil then
      raise ENXJSONRPC.CreateCode(TNXJSONRPC.InternalError,
        ClassName + '.GetResultClass returned nil.');

    FreeAndNil(FCommandResult);
    FCommandResult := lResultClass.Create;

    lJSON := AResponse.result.ToJSONData;
    try
      FCommandResult.FromJSONData(lJSON);
    finally
      lJSON.Free;
    end;

    ValidateResult(FCommandResult);
    Exit;
  end;

  if AResponse.Kind = rpcErrorResponse then
  begin
    if (AResponse.error = nil) or (not AResponse.error.Assigned) then
      raise ENXJSONRPC.CreateCode(TNXJSONRPC.InvalidRequest,
        'JSON-RPC error response is missing error.');

    FreeAndNil(FCommandError);
    lJSON := AResponse.error.ToJSONData;
    try
      FCommandError := TNXJSONRPCError.Create;
      FCommandError.FromJSONData(lJSON);
    finally
      lJSON.Free;
    end;
    Exit;
  end;

  raise ENXJSONRPC.CreateCode(TNXJSONRPC.InvalidRequest,
    'JSON-RPC message is not a response.');
end;

procedure TNXJSONRPCOutboundCommand.ProcessOutboundResult;
begin
end;

procedure TNXJSONRPCOutboundCommand.ProcessOutboundError;
begin
end;

procedure TNXJSONRPCOutboundCommand.ProcessOutboundTimeout;
begin
end;

class function TNXJSONRPC.ParseMessage(const AJSON: string): TNXJSONRPCMessage;
begin
  Result := ParseMessage(AJSON, TNXJSONRPCMessage);
end;

class function TNXJSONRPC.ParseMessage(const AJSON: string; AMessageClass: TNXJSONRPCMessageClass): TNXJSONRPCMessage;
var
  lJSON: TJSONData;
  lObject: TJSONObject;
begin
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

    if AMessageClass = nil then
      AMessageClass := TNXJSONRPCMessage;

    if AMessageClass = TNXJSONRPCMessage then
    begin
      lObject := TJSONObject(lJSON);
      if lObject.Find('method') <> nil then
      begin
        if lObject.Find('id') = nil then
          AMessageClass := TNXJSONRPCNotification
        else
          AMessageClass := TNXJSONRPCCommandMessage;
      end
      else if (lObject.Find('result') <> nil) or (lObject.Find('error') <> nil) then
        AMessageClass := TNXJSONRPCResponse;
    end;

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
  lCommandMessage: TNXJSONRPCCommandMessage;
  lResponse: TNXJSONRPCResponse;
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
    if not (AMessage is TNXJSONRPCCommandMessage) then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC request must be a command message.');

    lCommandMessage := TNXJSONRPCCommandMessage(AMessage);
    if (lCommandMessage.method = nil) or (not lCommandMessage.method.Assigned) or (lCommandMessage.method.Value = '') then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC request must contain a non-empty method string.');

    if lCommandMessage.HasParams then
    begin
      lParamsJSON := lCommandMessage.params.ToJSONData;
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
    if not (AMessage is TNXJSONRPCResponse) then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response must be a response message.');

    lResponse := TNXJSONRPCResponse(AMessage);

    if not AMessage.HasID then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response must contain id.');
  end;

  if lKind = rpcSuccessResponse then
  begin
    lResponse := TNXJSONRPCResponse(AMessage);
    if (lResponse.error <> nil) and lResponse.error.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response cannot contain both result and error.');
  end;

  if lKind = rpcErrorResponse then
  begin
    lResponse := TNXJSONRPCResponse(AMessage);
    if (lResponse.result <> nil) and lResponse.result.Assigned then
      raise ENXJSONRPC.CreateCode(InvalidRequest, 'JSON-RPC response cannot contain both result and error.');

    lErrorJSON := lResponse.error.ToJSONData;
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
