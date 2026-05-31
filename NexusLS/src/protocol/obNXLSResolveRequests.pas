unit obNXLSResolveRequests;

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
  TNXLSDocumentLinkResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSDocumentLink;
    procedure SetParams(AValue: TNXLSDocumentLink);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDocumentLink read GetParams write SetParams;
  end;

  TNXLSCodeLensResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCodeLens;
    procedure SetParams(AValue: TNXLSCodeLens);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCodeLens read GetParams write SetParams;
  end;

  TNXLSInlayHintResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSInlayHint;
    procedure SetParams(AValue: TNXLSInlayHint);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSInlayHint read GetParams write SetParams;
  end;

  TNXLSCompletionItemResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCompletionItem;
    procedure SetParams(AValue: TNXLSCompletionItem);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCompletionItem read GetParams write SetParams;
  end;

  TNXLSCodeActionResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCodeAction;
    procedure SetParams(AValue: TNXLSCodeAction);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCodeAction read GetParams write SetParams;
  end;

  TNXLSWorkspaceSymbolResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSWorkspaceSymbol;
    procedure SetParams(AValue: TNXLSWorkspaceSymbol);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSWorkspaceSymbol read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSDocumentLinkResolveRequest.GetFactoryName: string;
begin
  Result := 'documentLink/resolve';
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

class function TNXLSWorkspaceSymbolResolveRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceSymbol;
end;

function TNXLSWorkspaceSymbolResolveRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

function TNXLSDocumentLinkResolveRequest.GetParams: TNXLSDocumentLink;
begin
  Result := TNXLSDocumentLink(inherited params);
end;

procedure TNXLSDocumentLinkResolveRequest.SetParams(AValue: TNXLSDocumentLink);
begin
  inherited params := AValue;
end;

function TNXLSCompletionItemResolveRequest.GetParams: TNXLSCompletionItem;
begin
  Result := TNXLSCompletionItem(inherited params);
end;

procedure TNXLSCompletionItemResolveRequest.SetParams(AValue: TNXLSCompletionItem);
begin
  inherited params := AValue;
end;

function TNXLSCodeActionResolveRequest.GetParams: TNXLSCodeAction;
begin
  Result := TNXLSCodeAction(inherited params);
end;

procedure TNXLSCodeActionResolveRequest.SetParams(AValue: TNXLSCodeAction);
begin
  inherited params := AValue;
end;

function TNXLSInlayHintResolveRequest.GetParams: TNXLSInlayHint;
begin
  Result := TNXLSInlayHint(inherited params);
end;

procedure TNXLSInlayHintResolveRequest.SetParams(AValue: TNXLSInlayHint);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceSymbolResolveRequest.GetParams: TNXLSWorkspaceSymbol;
begin
  Result := TNXLSWorkspaceSymbol(inherited params);
end;

procedure TNXLSWorkspaceSymbolResolveRequest.SetParams(AValue: TNXLSWorkspaceSymbol);
begin
  inherited params := AValue;
end;

function TNXLSCodeLensResolveRequest.GetParams: TNXLSCodeLens;
begin
  Result := TNXLSCodeLens(inherited params);
end;

procedure TNXLSCodeLensResolveRequest.SetParams(AValue: TNXLSCodeLens);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSDocumentLinkResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeLensResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSInlayHintResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCompletionItemResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeActionResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSymbolResolveRequest);

end.
