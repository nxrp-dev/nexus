unit obNXLSInlineValueRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentInlineValueRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentInlineValueRequest.GetFactoryName: string;
begin
  Result := 'textDocument/inlineValue';
end;

class function TNXLSTextDocumentInlineValueRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInlineValueParams;
end;

function TNXLSTextDocumentInlineValueRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/inlineValue; required: Optional; original server: No; category: inline values; result: TNXLSInlineValueArrayResult.
  Result := TNXLSInlineValueArrayResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlineValueRequest);

end.
