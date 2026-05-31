unit obNXLSCodeActionRequests;

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
  TNXLSTextDocumentCodeActionRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCodeActionParams;
    procedure SetParams(AValue: TNXLSCodeActionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCodeActionParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel;

class function TNXLSTextDocumentCodeActionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/codeAction';
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

function TNXLSTextDocumentCodeActionRequest.GetParams: TNXLSCodeActionParams;
begin
  Result := TNXLSCodeActionParams(inherited params);
end;

procedure TNXLSTextDocumentCodeActionRequest.SetParams(AValue: TNXLSCodeActionParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeActionRequest);

end.
