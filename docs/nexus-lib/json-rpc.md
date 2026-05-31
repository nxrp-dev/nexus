# JSON-RPC Protocol Modeling

NexusLib models JSON-RPC protocols as typed Object Pascal object graphs. The JSON wire format is still JSON-RPC 2.0, but application code works with `TNXJSONValue` descendants, request classes, response classes, and published properties instead of hand-walking `TJSONObject` trees.

The current system is used by NexusLS for Language Server Protocol messages and by NexusTest for its test-module command protocol.

## Core Object Model

The JSON-RPC support lives in `NexusLib/src/obNXJSONRPCMessages.pas` and builds on `NexusLib/src/obNXJSONValues.pas`.

The base message lineage is:

```pascal
TNXJSONValue
  TNXJSONObject
    TNXJSONRPCMessage
      TNXJSONRPCCommandMessage
        TNXJSONRPCNotification
        TNXJSONRPCRequest
        TNXJSONRPCOutboundCommand
      TNXJSONRPCResponse
    TNXJSONRPCError
    TNXJSONCommandResult
```

`TNXJSONRPCMessage` owns the shared JSON-RPC envelope:

- `jsonrpc: TNXJSONString`
- `id: TNXJSONValue`
- `MessageType`, computed from the populated envelope fields
- `Kind`, a higher-level classification of request, notification, success response, or error response

`TNXJSONRPCCommandMessage` adds:

- `method: TNXJSONString`
- `params: TNXJSONObjectParams`
- `HasParams`
- `ParamsObject`

`TNXJSONRPCResponse` adds:

- `result: TNXJSONValue`
- `error: TNXJSONValue`

A response is valid only when it has exactly one of `result` or `error`, and it must carry an `id`.

`TNXJSONRPCError` models the JSON-RPC error object:

- `code: TNXJSONInteger`
- `message: TNXJSONString`
- `data: TNXJSONValue`

## Published Properties Are the Contract

Nexus JSON DTOs are regular Pascal classes whose `published` properties define the JSON contract.

For example, an LSP position is modeled as:

```pascal
TNXLSPosition = class(TNXJSONObject)
private
  Fline: TNXJSONInteger;
  Fcharacter: TNXJSONInteger;
published
  property line: TNXJSONInteger read Fline write Fline;
  property character: TNXJSONInteger read Fcharacter write Fcharacter;
end;
```

`TNXJSONObject` uses RTTI over class-type published properties. On construction it auto-creates `TNXJSONValue` properties, on serialization it emits assigned JSON values, and on destruction it frees those property objects. Unknown incoming JSON object properties are ignored unless a matching published property exists.

Arrays are modeled with `TNXJSONArray` descendants. Override `ItemClass` when an array has a known element type:

```pascal
TNXLSCompletionItemArray = class(TNXJSONArray)
public
  class function ItemClass: TNXJSONValueClass; override;
end;

class function TNXLSCompletionItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSCompletionItem;
end;
```

Primitive values use `TNXJSONString`, `TNXJSONInteger`, `TNXJSONFloat`, `TNXJSONBoolean`, and `TNXJSONNull`. Untyped or mixed fields use `TNXJSONValue`.

## Requests and Notifications

Inbound methods are modeled as `TNXJSONRPCRequest` descendants. The class factory key is the JSON-RPC method name, supplied by overriding `GetFactoryName`.

```pascal
TNXLSTextDocumentCompletionRequest = class(TNXJSONRPCRequest)
private
  function GetResult: TNXLSCompletionItemArray;
  procedure SetResult(AValue: TNXLSCompletionItemArray);
  function GetParams: TNXLSCompletionParams;
  procedure SetParams(AValue: TNXLSCompletionParams);
public
  class function GetFactoryName: string; override;
  function Execute: TNXJSONValue; override;
published
  property result: TNXLSCompletionItemArray read GetResult write SetResult;
  property params: TNXLSCompletionParams read GetParams write SetParams;
end;
```

The implementation pattern is:

```pascal
class function TNXLSTextDocumentCompletionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/completion';
end;

function TNXLSTextDocumentCompletionRequest.GetParams: TNXLSCompletionParams;
begin
  Result := TNXLSCompletionParams(inherited params);
end;

procedure TNXLSTextDocumentCompletionRequest.SetParams(AValue: TNXLSCompletionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentCompletionRequest.GetResult: TNXLSCompletionItemArray;
begin
  Result := TNXLSCompletionItemArray(inherited result);
end;

procedure TNXLSTextDocumentCompletionRequest.SetResult(AValue: TNXLSCompletionItemArray);
begin
  inherited result := AValue;
end;
```

The typed `params` and `result` properties deliberately redeclare the base properties. The base classes store the value, while the descendant exposes the protocol-specific type to RTTI and to Pascal callers. This redeclaration is how the JSON layer knows which concrete class to create for `params` and which result class is expected.

Register request classes during unit initialization:

```pascal
initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCompletionRequest);
```

When `TNXJSONRPC.ParseMessage` sees a JSON object with a registered `method`, it creates the registered class and loads the message through its published properties.

The current command model uses object-shaped params through `TNXJSONObjectParams` descendants. `TNXJSONArrayParams` and `TNXJSONPositionalParams` exist in the JSON value layer, but `TNXJSONRPCCommandMessage.params` is currently typed as `TNXJSONObjectParams`, so normal JSON-RPC protocol classes should model params as objects unless the message layer is changed.

Notifications use the same command shape as requests, but have no `id`. A parsed message with a method and no `id` is classified as `rpcNotification`. Dispatchers execute it without returning a response.

## Result Handling

`TNXJSONRPCRequest.Execute` returns a `TNXJSONValue`. The base request class provides result validation and a helper for constructing the typed result.

The default result policy is `rkConcreteResult`. Override `GetResultKind` when a method has different result semantics:

- `rkNoResult`: `Execute` must return `nil`. This is used for notifications or commands that should not produce a JSON-RPC result.
- `rkNullResult`: `Execute` should return `PrepareResult`, which creates `TNXJSONNull`.
- `rkConcreteResult`: `Execute` must return an instance of the typed `result` property class.
- `rkNullableConcreteResult`: `Execute` may return either the typed result class or `TNXJSONNull`.

For concrete results, call `PrepareResult` when the request should populate a typed result object:

```pascal
function TNXLSTextDocumentCompletionRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSCompletionItemArray;
begin
  lResult := TNXLSCompletionItemArray(PrepareResult);
  TNXLSLSPModel.Current.Completion.FillCompletionItems(
    TNXLSCompletionParams(params), lResult);
  Result := lResult;
end;
```

For nullable concrete results, return `TNXJSONNull` when the protocol result is explicitly null:

```pascal
function TNXLSTextDocumentSignatureHelpRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSSignatureHelp;
begin
  lResult := TNXLSSignatureHelp(PrepareResult);
  if TNXLSLSPModel.Current.Completion.FillSignatureHelp(
    TNXLSSignatureHelpParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;
```

The dispatcher owns the returned result after `Execute` returns and frees it after building the response.

## Error Handling

JSON-RPC failures use `ENXJSONRPC`, which carries the JSON-RPC error code.

`TNXJSONRPC` defines the standard codes:

- `ParseError = -32700`
- `InvalidRequest = -32600`
- `MethodNotFound = -32601`
- `InvalidParams = -32602`
- `InternalError = -32603`

`TNXJSONRPC.CreateErrorResponse` builds the response envelope and serializes a `TNXJSONRPCError`. Optional structured error data is passed as a `TNXJSONValue`.

NexusTest extends this pattern with `ENXTestRPC`, adding a NexusTest-specific error code that is serialized under `error.data`:

```pascal
raise ENXTestRPC.CreateCode(
  TNXJSONRPC.InvalidParams,
  cNXTestErrorUnknownTest,
  'Unknown test.');
```

Dispatchers catch `ENXJSONRPC` and use its `Code`. Other exceptions are treated as `InternalError` for requests. Notifications do not receive error responses; NexusLS logs notification failures and returns no response.

## Dispatch Shape

NexusLib parses and validates messages, but each application owns its dispatch policy.

The common inbound dispatch shape is:

1. Parse the raw JSON with `TNXJSONRPC.ParseMessage`.
2. Reject anything that is not a request or notification for inbound command dispatch.
3. Look up the `method` in `TNXClassFactory`.
4. If needed, parse again using the registered request class so typed `params` are materialized.
5. Execute the typed request.
6. Validate the result against `GetResultKind` and the typed `result` property.
7. For requests, create a success or error response.
8. For notifications, return no response.

NexusLS performs this in `TNXLSDispatcher.DispatchMessage`. `TNXLSServer.Execute` routes parsed success and error responses to `TNXLSLSPModel.ReceiveClientResponse` instead of inbound request dispatch.

NexusTest follows the same broad shape in `TNXTestCommandProcessor.ExecuteCommand`, with extra handling for NexusTest-specific error data.

## Outbound Commands

Outbound requests are modeled with `TNXJSONRPCOutboundCommand`. This is for commands the server sends to a peer and later matches with a response.

An outbound command redeclares typed `params` and typed `result`, just like an inbound request:

```pascal
TNXLSWorkspaceApplyEditRequest = class(TNXJSONRPCOutboundCommand)
private
  function GetParams: TNXLSApplyWorkspaceEditParams;
  function GetResult: TNXLSApplyWorkspaceEditResultValue;
  procedure SetParams(AValue: TNXLSApplyWorkspaceEditParams);
  procedure SetResult(AValue: TNXLSApplyWorkspaceEditResultValue);
public
  class function GetFactoryName: string; override;
published
  property params: TNXLSApplyWorkspaceEditParams read GetParams write SetParams;
  property result: TNXLSApplyWorkspaceEditResultValue read GetResult write SetResult;
end;
```

Outbound results must descend from `TNXJSONCommandResult`. For example:

```pascal
TNXLSApplyWorkspaceEditResultValue = class(TNXJSONCommandResult)
private
  Fapplied: TNXJSONBoolean;
  FfailureReason: TNXJSONString;
  FfailedChange: TNXJSONInteger;
published
  property applied: TNXJSONBoolean read Fapplied write Fapplied;
  property failureReason: TNXJSONString read FfailureReason write FfailureReason;
  property failedChange: TNXJSONInteger read FfailedChange write FfailedChange;
end;
```

`TNXLSOutboundDispatcher.SendRequest` owns the lifecycle once a command is sent:

- sets `jsonrpc` to `2.0`
- sets `method` from `GetFactoryName`
- allocates a numeric `id`
- serializes the request to the transport
- stores the original command object in a pending-request list

When a matching response arrives, `ReceiveResponse` calls `LoadOutboundResponse`. Success responses are loaded into the typed `result` property and then `ProcessOutboundResult` is called. Error responses are loaded into `CommandError` and then `ProcessOutboundError` is called. Clearing pending requests calls `ProcessOutboundTimeout`.

Override these processing hooks in command descendants when local state must be updated after the peer responds.

## Ownership and Lifecycle

The current ownership rules are simple and important:

- `TNXJSONObject` owns and frees its auto-created published `TNXJSONValue` properties.
- `TNXJSONArray` owns items added to it.
- `PrepareResult` returns a new `TNXJSONValue`; it does not attach that value to the request object.
- Dispatchers take responsibility for freeing the `TNXJSONValue` returned by `Execute`.
- `TNXJSONRPCRequest` frees its published `result` field only when that property has been assigned on the request object.
- If `Execute` creates a temporary result and decides to return `TNXJSONNull` instead, it must free the temporary result first.
- `TNXJSONRPC.CreateSuccessResponse` and `CreateErrorResponse` return `TJSONObject`; the caller owns and frees that object.
- `IDJSON` returns a new `TJSONData` value; the caller owns and frees it.
- `TNXLSOutboundDispatcher.SendRequest` takes ownership of a successfully sent outbound command by storing it in the pending list. If the command cannot be sent, it frees the request before returning.
- Pending outbound commands are freed when their response is processed or when pending requests are cleared.

For new protocol classes, keep the object graph explicit: model params, results, nested objects, and arrays as `TNXJSONValue` descendants with published properties. Avoid side maps or manual JSON field extraction unless the protocol genuinely has an untyped extension point.

## Current Boundaries

The current parser accepts one JSON object at a time. Although `TNXJSONRPCMessageKind` includes `rpcBatch`, batch JSON-RPC arrays are not currently parsed or dispatched.

NexusLib does not own server policy, transport policy, method implementation, logging, or protocol-specific errors. It provides the typed JSON model, message parsing and validation, response construction, result validation, and outbound response loading. Applications such as NexusLS and NexusTest decide how to route messages, where behavior lives, and how failures are reported.
