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
    function GetParams: TNXLSShowMessageRequestParams;
    procedure SetParams(AValue: TNXLSShowMessageRequestParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
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
    function GetParams: TNXLSShowDocumentParams;
    procedure SetParams(AValue: TNXLSShowDocumentParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSShowDocumentParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory;

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
  Result := nil;
end;

class function TNXLSWindowShowMessageRequest.GetFactoryName: string;
begin
  Result := 'window/showMessageRequest';
end;

class function TNXLSWindowShowMessageRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSMessageActionItem;
end;

class function TNXLSWindowShowMessageRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSWindowShowMessageRequest.Execute: TNXJSONValue;
begin
  // Method: window/showMessageRequest; required: Client-side; original server: No; category: window; result: TNXLSMessageActionItemResult.
  Result := TNXJSONNull.Create;
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
  Result := nil;
end;

class function TNXLSWindowShowDocumentRequest.GetFactoryName: string;
begin
  Result := 'window/showDocument';
end;

class function TNXLSWindowShowDocumentRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSShowDocumentResultValue;
end;

function TNXLSWindowShowDocumentRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSShowDocumentResultValue;
begin
  lResult := TNXLSShowDocumentResultValue(PrepareResult);
  lResult.success.Value := False;
  lResult.Assigned := True;
  Result := lResult;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageActionRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowLogMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowDocumentRequest);

end.
