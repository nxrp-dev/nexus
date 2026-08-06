unit obNXLSInlineValueRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSTextDocumentInlineValueRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSInlineValueArray;
    procedure SetResult(AValue: TNXLSInlineValueArray);
    function GetParams: TNXLSInlineValueParams;
    procedure SetParams(AValue: TNXLSInlineValueParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSInlineValueArray read GetResult write SetResult;
    property params: TNXLSInlineValueParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentInlineValueRequest.GetFactoryName: string;
begin
  Result := 'textDocument/inlineValue';
end;

function TNXLSTextDocumentInlineValueRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentInlineValueRequest.GetParams: TNXLSInlineValueParams;
begin
  Result := TNXLSInlineValueParams(inherited params);
end;

procedure TNXLSTextDocumentInlineValueRequest.SetParams(AValue: TNXLSInlineValueParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentInlineValueRequest.GetResult: TNXLSInlineValueArray;
begin
  Result := TNXLSInlineValueArray(inherited result);
end;

procedure TNXLSTextDocumentInlineValueRequest.SetResult(AValue: TNXLSInlineValueArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlineValueRequest);

end.
