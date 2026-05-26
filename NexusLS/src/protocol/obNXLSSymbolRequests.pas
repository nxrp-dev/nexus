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
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceSymbolRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentDocumentSymbolRequest.GetFactoryName: string;
begin
  Result := 'textDocument/documentSymbol';
end;

class function TNXLSTextDocumentDocumentSymbolRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentSymbolParams;
end;

function TNXLSTextDocumentDocumentSymbolRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Symbols.DocumentSymbol(TNXLSDocumentSymbolParams(params));
end;

class function TNXLSWorkspaceSymbolRequest.GetFactoryName: string;
begin
  Result := 'workspace/symbol';
end;

class function TNXLSWorkspaceSymbolRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceSymbolParams;
end;

function TNXLSWorkspaceSymbolRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Symbols.WorkspaceSymbol(TNXLSWorkspaceSymbolParams(params));
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDocumentSymbolRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSymbolRequest);

end.
