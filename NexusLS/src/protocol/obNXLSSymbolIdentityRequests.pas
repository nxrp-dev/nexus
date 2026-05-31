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
    class function GetResultClass: TNXJSONValueClass; override;
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

class function TNXLSTextDocumentMonikerRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSMonikerArray;
end;

function TNXLSTextDocumentMonikerRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentMonikerRequest);

end.
