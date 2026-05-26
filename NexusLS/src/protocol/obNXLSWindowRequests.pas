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
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWindowShowMessageRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWindowLogMessageRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWindowShowDocumentRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
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

function TNXLSWindowShowMessageRequest.Execute: TNXJSONValue;
begin
  // Method: window/showMessageRequest; required: Client-side; original server: No; category: window; result: TNXLSMessageActionItemResult.
  Result := TNXLSMessageActionItemResult.CreateValue;
end;

class function TNXLSWindowLogMessageRequest.GetFactoryName: string;
begin
  Result := 'window/logMessage';
end;

class function TNXLSWindowLogMessageRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSMessageParams;
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

function TNXLSWindowShowDocumentRequest.Execute: TNXJSONValue;
begin
  // Method: window/showDocument; required: Client-side; original server: No; category: window; result: TNXLSShowDocumentResult.
  Result := TNXLSShowDocumentResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageActionRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowLogMessageRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowShowDocumentRequest);

end.
