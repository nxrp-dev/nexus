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

class function TNXLSTextDocumentCodeActionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/codeAction';
end;

class function TNXLSTextDocumentCodeActionRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeActionParams;
end;

class function TNXLSTextDocumentCodeActionRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeActionArray;
end;

function TNXLSTextDocumentCodeActionRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSCodeActionArray;
begin
  lResult := TNXLSCodeActionArray(PrepareResult);
  TNXLSLSPModel.Current.Editor.FillCodeActions(TNXLSCodeActionParams(params),
    lResult);
  Result := lResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeActionRequest);

end.
