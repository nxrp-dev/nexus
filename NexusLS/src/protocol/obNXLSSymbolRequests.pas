unit obNXLSSymbolRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentDocumentSymbolRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceSymbolRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentDocumentSymbolRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentSymbol';
end;

class function TNXLSTextDocumentDocumentSymbolRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentSymbolParams;
end;

class function TNXLSTextDocumentDocumentSymbolRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXJSONArray;
end;

function TNXLSTextDocumentDocumentSymbolRequest.Execute: TNXJSONValue;
var
  lResult: TNXJSONArray;
begin
  lResult := TNXJSONArray(PrepareResult);
  TNXLSLSPModel.Current.Symbols.FillDocumentSymbols(
    TNXLSDocumentSymbolParams(params), lResult);
  Result := lResult;
end;

class function TNXLSWorkspaceSymbolRequest.GetFactoryName: string;
begin
  Result := 'workspace/symbol';
end;

class function TNXLSWorkspaceSymbolRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceSymbolParams;
end;

class function TNXLSWorkspaceSymbolRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXJSONArray;
end;

function TNXLSWorkspaceSymbolRequest.Execute: TNXJSONValue;
var
  lResult: TNXJSONArray;
begin
  lResult := TNXJSONArray(PrepareResult);
  TNXLSLSPModel.Current.Symbols.FillWorkspaceSymbols(
    TNXLSWorkspaceSymbolParams(params), lResult);
  Result := lResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentSymbolRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSymbolRequest);

end.
