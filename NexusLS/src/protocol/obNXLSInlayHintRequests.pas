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

function TNXLSTextDocumentInlayHintRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Editor.InlayHint(TNXLSInlayHintParams(params));
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentInlayHintRequest);

end.
