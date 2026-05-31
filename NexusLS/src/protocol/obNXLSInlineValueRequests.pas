unit obNXLSInlineValueRequests;

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
  TNXLSTextDocumentInlineValueRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSInlineValueParams;
    procedure SetParams(AValue: TNXLSInlineValueParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSInlineValueParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSTextDocumentInlineValueRequest.GetFactoryName: string;
begin
  Result := 'textDocument/inlineValue';
end;

class function TNXLSTextDocumentInlineValueRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSInlineValueArray;
end;

function TNXLSTextDocumentInlineValueRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

function TNXLSTextDocumentInlineValueRequest.GetParams: TNXLSInlineValueParams;
begin
  Result := TNXLSInlineValueParams(inherited params);
end;

procedure TNXLSTextDocumentInlineValueRequest.SetParams(AValue: TNXLSInlineValueParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlineValueRequest);

end.
