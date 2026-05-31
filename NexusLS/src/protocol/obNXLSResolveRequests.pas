unit obNXLSResolveRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSDocumentLinkResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCodeLensResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSInlayHintResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCompletionItemResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCodeActionResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceSymbolResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSDocumentLinkResolveRequest.GetFactoryName: string;
begin
  Result := 'documentLink/resolve';
end;

class function TNXLSDocumentLinkResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentLink;
end;

class function TNXLSDocumentLinkResolveRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentLink;
end;

function TNXLSDocumentLinkResolveRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSCodeLensResolveRequest.GetFactoryName: string;
begin
  Result := 'codeLens/resolve';
end;

class function TNXLSCodeLensResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeLens;
end;

class function TNXLSCodeLensResolveRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeLens;
end;

function TNXLSCodeLensResolveRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSInlayHintResolveRequest.GetFactoryName: string;
begin
  Result := 'inlayHint/resolve';
end;

class function TNXLSInlayHintResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInlayHint;
end;

class function TNXLSInlayHintResolveRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSInlayHint;
end;

function TNXLSInlayHintResolveRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSCompletionItemResolveRequest.GetFactoryName: string;
begin
  Result := 'completionItem/resolve';
end;

class function TNXLSCompletionItemResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCompletionItem;
end;

class function TNXLSCompletionItemResolveRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCompletionItem;
end;

function TNXLSCompletionItemResolveRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSCodeActionResolveRequest.GetFactoryName: string;
begin
  Result := 'codeAction/resolve';
end;

class function TNXLSCodeActionResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeAction;
end;

class function TNXLSCodeActionResolveRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeAction;
end;

function TNXLSCodeActionResolveRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSWorkspaceSymbolResolveRequest.GetFactoryName: string;
begin
  Result := 'workspaceSymbol/resolve';
end;

class function TNXLSWorkspaceSymbolResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceSymbol;
end;

class function TNXLSWorkspaceSymbolResolveRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceSymbol;
end;

function TNXLSWorkspaceSymbolResolveRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSDocumentLinkResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeLensResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSInlayHintResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCompletionItemResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeActionResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSymbolResolveRequest);

end.
