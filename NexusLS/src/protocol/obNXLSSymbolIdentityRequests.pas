unit obNXLSSymbolIdentityRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentMonikerRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentMonikerRequest.GetFactoryName: string;
begin
  Result := 'textDocument/moniker';
end;

class function TNXLSTextDocumentMonikerRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentMonikerRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/moniker; required: Optional; original server: No; category: symbol identity; result: TNXLSMonikerArrayResult.
  Result := TNXLSMonikerArrayResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentMonikerRequest);

end.
