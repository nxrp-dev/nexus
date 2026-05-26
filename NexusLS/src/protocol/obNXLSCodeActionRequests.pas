unit obNXLSCodeActionRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentCodeActionRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentCodeActionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/codeAction';
end;

class function TNXLSTextDocumentCodeActionRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeActionParams;
end;

function TNXLSTextDocumentCodeActionRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Editor.CodeAction(TNXLSCodeActionParams(params));
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeActionRequest);

end.
