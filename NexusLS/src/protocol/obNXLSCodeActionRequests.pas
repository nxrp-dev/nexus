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
    function GetResult: TNXLSCodeActionArray;
    procedure SetResult(AValue: TNXLSCodeActionArray);
    function GetParams: TNXLSCodeActionParams;
    procedure SetParams(AValue: TNXLSCodeActionParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSCodeActionArray read GetResult write SetResult;
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

function TNXLSTextDocumentCodeActionRequest.GetResult: TNXLSCodeActionArray;
begin
  Result := TNXLSCodeActionArray(inherited result);
end;

procedure TNXLSTextDocumentCodeActionRequest.SetResult(AValue: TNXLSCodeActionArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentCodeActionRequest);

end.
