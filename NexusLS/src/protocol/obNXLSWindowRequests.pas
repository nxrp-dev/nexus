unit obNXLSWindowRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSWindowShowMessageActionRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWindowShowMessageRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWindowLogMessageRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWindowShowDocumentRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSWindowShowMessageActionRequest.GetFactoryName: string;
begin
  Result := 'window/showMessage';
end;

class function TNXLSWindowShowMessageActionRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSMessageParams;
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

class function TNXLSWindowShowMessageRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSShowMessageRequestParams;
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

class function TNXLSWindowLogMessageRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSMessageParams;
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

class function TNXLSWindowShowDocumentRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSShowDocumentParams;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageActionRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowLogMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowDocumentRequest);

end.
