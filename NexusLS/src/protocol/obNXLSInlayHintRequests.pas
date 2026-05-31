unit obNXLSInlayHintRequests;

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
  TNXLSTextDocumentInlayHintRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSInlayHintParams;
    procedure SetParams(AValue: TNXLSInlayHintParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSInlayHintParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel;

class function TNXLSTextDocumentInlayHintRequest.GetFactoryName: string;
begin
  Result := 'textDocument/inlayHint';
end;

class function TNXLSTextDocumentInlayHintRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSInlayHintArray;
end;

function TNXLSTextDocumentInlayHintRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSInlayHintArray;
begin
  lResult := TNXLSInlayHintArray(PrepareResult);
  TNXLSLSPModel.Current.Editor.FillInlayHints(TNXLSInlayHintParams(params),
    lResult);
  Result := lResult;
end;

function TNXLSTextDocumentInlayHintRequest.GetParams: TNXLSInlayHintParams;
begin
  Result := TNXLSInlayHintParams(inherited params);
end;

procedure TNXLSTextDocumentInlayHintRequest.SetParams(AValue: TNXLSInlayHintParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlayHintRequest);

end.
