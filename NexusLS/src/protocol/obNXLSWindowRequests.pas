unit obNXLSWindowRequests;

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
  TNXLSWindowShowMessageActionRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSMessageParams;
    procedure SetParams(AValue: TNXLSMessageParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSMessageParams read GetParams write SetParams;
  end;

  TNXLSWindowShowMessageRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSMessageActionItem;
    procedure SetResult(AValue: TNXLSMessageActionItem);
    function GetParams: TNXLSShowMessageRequestParams;
    procedure SetParams(AValue: TNXLSShowMessageRequestParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSMessageActionItem read GetResult write SetResult;
    property params: TNXLSShowMessageRequestParams read GetParams write SetParams;
  end;

  TNXLSWindowLogMessageRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSMessageParams;
    procedure SetParams(AValue: TNXLSMessageParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSMessageParams read GetParams write SetParams;
  end;

  TNXLSWindowShowDocumentRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSShowDocumentResultValue;
    procedure SetResult(AValue: TNXLSShowDocumentResultValue);
    function GetParams: TNXLSShowDocumentParams;
    procedure SetParams(AValue: TNXLSShowDocumentParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSShowDocumentResultValue read GetResult write SetResult;
    property params: TNXLSShowDocumentParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSWindowShowMessageActionRequest.GetFactoryName: string;
begin
  Result := 'window/showMessage';
end;

class function TNXLSWindowShowMessageActionRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWindowShowMessageActionRequest.Execute: TNXJSONValue;
begin
  // Method: window/showMessage; required: Client-side; original server: No; category: window; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWindowShowMessageRequest.GetFactoryName: string;
begin
  Result := 'window/showMessageRequest';
end;

class function TNXLSWindowShowMessageRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSWindowShowMessageRequest.Execute: TNXJSONValue;
begin
  // Method: window/showMessageRequest; required: Client-side; original server: No; category: window; result: TNXLSMessageActionItemResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWindowLogMessageRequest.GetFactoryName: string;
begin
  Result := 'window/logMessage';
end;

class function TNXLSWindowLogMessageRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWindowLogMessageRequest.Execute: TNXJSONValue;
begin
  // Method: window/logMessage; required: Client-side; original server: No; category: window; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWindowShowDocumentRequest.GetFactoryName: string;
begin
  Result := 'window/showDocument';
end;

function TNXLSWindowShowDocumentRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSWindowShowDocumentRequest.GetParams: TNXLSShowDocumentParams;
begin
  Result := TNXLSShowDocumentParams(inherited params);
end;

procedure TNXLSWindowShowDocumentRequest.SetParams(AValue: TNXLSShowDocumentParams);
begin
  inherited params := AValue;
end;

function TNXLSWindowLogMessageRequest.GetParams: TNXLSMessageParams;
begin
  Result := TNXLSMessageParams(inherited params);
end;

procedure TNXLSWindowLogMessageRequest.SetParams(AValue: TNXLSMessageParams);
begin
  inherited params := AValue;
end;

function TNXLSWindowShowMessageRequest.GetParams: TNXLSShowMessageRequestParams;
begin
  Result := TNXLSShowMessageRequestParams(inherited params);
end;

procedure TNXLSWindowShowMessageRequest.SetParams(AValue: TNXLSShowMessageRequestParams);
begin
  inherited params := AValue;
end;

function TNXLSWindowShowMessageActionRequest.GetParams: TNXLSMessageParams;
begin
  Result := TNXLSMessageParams(inherited params);
end;

procedure TNXLSWindowShowMessageActionRequest.SetParams(AValue: TNXLSMessageParams);
begin
  inherited params := AValue;
end;

function TNXLSWindowShowMessageRequest.GetResult: TNXLSMessageActionItem;
begin
  Result := TNXLSMessageActionItem(inherited result);
end;

procedure TNXLSWindowShowMessageRequest.SetResult(AValue: TNXLSMessageActionItem);
begin
  inherited result := AValue;
end;

function TNXLSWindowShowDocumentRequest.GetResult: TNXLSShowDocumentResultValue;
begin
  Result := TNXLSShowDocumentResultValue(inherited result);
end;

procedure TNXLSWindowShowDocumentRequest.SetResult(AValue: TNXLSShowDocumentResultValue);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageActionRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowLogMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowDocumentRequest);

end.
