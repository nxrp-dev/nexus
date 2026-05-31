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
    class function GetResultClass: TNXJSONValueClass; override;
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

class function TNXLSTextDocumentInlineValueRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSInlineValueArray;
end;

function TNXLSTextDocumentInlineValueRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlineValueRequest);

end.
