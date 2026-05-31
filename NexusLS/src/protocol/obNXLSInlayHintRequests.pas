unit obNXLSInlayHintRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentInlayHintRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentInlayHintRequest.GetFactoryName: string;
begin
  Result := 'textDocument/inlayHint';
end;

class function TNXLSTextDocumentInlayHintRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInlayHintParams;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlayHintRequest);

end.
