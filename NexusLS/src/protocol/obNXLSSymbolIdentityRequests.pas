unit obNXLSSymbolIdentityRequests;

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
  TNXLSTextDocumentMonikerRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentMonikerRequest.GetFactoryName: string;
begin
  Result := 'textDocument/moniker';
end;

class function TNXLSTextDocumentMonikerRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSMonikerArray;
end;

function TNXLSTextDocumentMonikerRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentMonikerRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentMonikerRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentMonikerRequest);

end.
