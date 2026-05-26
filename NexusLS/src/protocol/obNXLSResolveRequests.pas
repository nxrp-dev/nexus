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
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCodeLensResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSInlayHintResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCompletionItemResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCodeActionResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceSymbolResolveRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
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

function TNXLSDocumentLinkResolveRequest.Execute: TNXJSONValue;
begin
  // Method: documentLink/resolve; required: Optional; original server: No; category: resolve; result: TNXLSDocumentLinkResult.
  Result := TNXLSDocumentLinkResult.CreateValue;
end;

class function TNXLSCodeLensResolveRequest.GetFactoryName: string;
begin
  Result := 'codeLens/resolve';
end;

class function TNXLSCodeLensResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeLens;
end;

function TNXLSCodeLensResolveRequest.Execute: TNXJSONValue;
begin
  // Method: codeLens/resolve; required: Optional; original server: No; category: resolve; result: TNXLSCodeLensResult.
  Result := TNXLSCodeLensResult.CreateValue;
end;

class function TNXLSInlayHintResolveRequest.GetFactoryName: string;
begin
  Result := 'inlayHint/resolve';
end;

class function TNXLSInlayHintResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInlayHint;
end;

function TNXLSInlayHintResolveRequest.Execute: TNXJSONValue;
begin
  // Method: inlayHint/resolve; required: Optional; original server: No; category: resolve; result: TNXLSInlayHintResult.
  Result := TNXLSInlayHintResult.CreateValue;
end;

class function TNXLSCompletionItemResolveRequest.GetFactoryName: string;
begin
  Result := 'completionItem/resolve';
end;

class function TNXLSCompletionItemResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCompletionItem;
end;

function TNXLSCompletionItemResolveRequest.Execute: TNXJSONValue;
begin
  // Method: completionItem/resolve; required: Optional; original server: No; category: resolve; result: TNXLSCompletionItemResult.
  Result := TNXLSCompletionItemResult.CreateValue;
end;

class function TNXLSCodeActionResolveRequest.GetFactoryName: string;
begin
  Result := 'codeAction/resolve';
end;

class function TNXLSCodeActionResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeAction;
end;

function TNXLSCodeActionResolveRequest.Execute: TNXJSONValue;
begin
  // Method: codeAction/resolve; required: Optional; original server: No; category: resolve; result: TNXLSCodeActionResult.
  Result := TNXLSCodeActionResult.CreateValue;
end;

class function TNXLSWorkspaceSymbolResolveRequest.GetFactoryName: string;
begin
  Result := 'workspaceSymbol/resolve';
end;

class function TNXLSWorkspaceSymbolResolveRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceSymbol;
end;

function TNXLSWorkspaceSymbolResolveRequest.Execute: TNXJSONValue;
begin
  // Method: workspaceSymbol/resolve; required: Optional; original server: No; category: resolve; result: TNXLSWorkspaceSymbolResult.
  Result := TNXLSWorkspaceSymbolResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSDocumentLinkResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeLensResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSInlayHintResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCompletionItemResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeActionResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSymbolResolveRequest);

end.
