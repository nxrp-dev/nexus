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
    function GetResult: TNXLSDocumentLink;
    procedure SetResult(AValue: TNXLSDocumentLink);
    function GetParams: TNXLSDocumentLink;
    procedure SetParams(AValue: TNXLSDocumentLink);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSDocumentLink read GetResult write SetResult;
    property params: TNXLSDocumentLink read GetParams write SetParams;
  end;

  TNXLSCodeLensResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCodeLens;
    procedure SetResult(AValue: TNXLSCodeLens);
    function GetParams: TNXLSCodeLens;
    procedure SetParams(AValue: TNXLSCodeLens);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSCodeLens read GetResult write SetResult;
    property params: TNXLSCodeLens read GetParams write SetParams;
  end;

  TNXLSInlayHintResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSInlayHint;
    procedure SetResult(AValue: TNXLSInlayHint);
    function GetParams: TNXLSInlayHint;
    procedure SetParams(AValue: TNXLSInlayHint);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSInlayHint read GetResult write SetResult;
    property params: TNXLSInlayHint read GetParams write SetParams;
  end;

  TNXLSCompletionItemResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCompletionItem;
    procedure SetResult(AValue: TNXLSCompletionItem);
    function GetParams: TNXLSCompletionItem;
    procedure SetParams(AValue: TNXLSCompletionItem);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSCompletionItem read GetResult write SetResult;
    property params: TNXLSCompletionItem read GetParams write SetParams;
  end;

  TNXLSCodeActionResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCodeAction;
    procedure SetResult(AValue: TNXLSCodeAction);
    function GetParams: TNXLSCodeAction;
    procedure SetParams(AValue: TNXLSCodeAction);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSCodeAction read GetResult write SetResult;
    property params: TNXLSCodeAction read GetParams write SetParams;
  end;

  TNXLSWorkspaceSymbolResolveRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSWorkspaceSymbol;
    procedure SetResult(AValue: TNXLSWorkspaceSymbol);
    function GetParams: TNXLSWorkspaceSymbol;
    procedure SetParams(AValue: TNXLSWorkspaceSymbol);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSWorkspaceSymbol read GetResult write SetResult;
    property params: TNXLSWorkspaceSymbol read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSDocumentLinkResolveRequest.GetFactoryName: string;
begin
  Result := 'documentLink/resolve';
end;

function TNXLSDocumentLinkResolveRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSCodeLensResolveRequest.GetFactoryName: string;
begin
  Result := 'codeLens/resolve';
end;

function TNXLSCodeLensResolveRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSInlayHintResolveRequest.GetFactoryName: string;
begin
  Result := 'inlayHint/resolve';
end;

function TNXLSInlayHintResolveRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSCompletionItemResolveRequest.GetFactoryName: string;
begin
  Result := 'completionItem/resolve';
end;

function TNXLSCompletionItemResolveRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSCodeActionResolveRequest.GetFactoryName: string;
begin
  Result := 'codeAction/resolve';
end;

function TNXLSCodeActionResolveRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSWorkspaceSymbolResolveRequest.GetFactoryName: string;
begin
  Result := 'workspaceSymbol/resolve';
end;

function TNXLSWorkspaceSymbolResolveRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
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

function TNXLSDocumentLinkResolveRequest.GetResult: TNXLSDocumentLink;
begin
  Result := TNXLSDocumentLink(inherited result);
end;

procedure TNXLSDocumentLinkResolveRequest.SetResult(AValue: TNXLSDocumentLink);
begin
  inherited result := AValue;
end;

function TNXLSCodeLensResolveRequest.GetResult: TNXLSCodeLens;
begin
  Result := TNXLSCodeLens(inherited result);
end;

procedure TNXLSCodeLensResolveRequest.SetResult(AValue: TNXLSCodeLens);
begin
  inherited result := AValue;
end;

function TNXLSInlayHintResolveRequest.GetResult: TNXLSInlayHint;
begin
  Result := TNXLSInlayHint(inherited result);
end;

procedure TNXLSInlayHintResolveRequest.SetResult(AValue: TNXLSInlayHint);
begin
  inherited result := AValue;
end;

function TNXLSCompletionItemResolveRequest.GetResult: TNXLSCompletionItem;
begin
  Result := TNXLSCompletionItem(inherited result);
end;

procedure TNXLSCompletionItemResolveRequest.SetResult(AValue: TNXLSCompletionItem);
begin
  inherited result := AValue;
end;

function TNXLSCodeActionResolveRequest.GetResult: TNXLSCodeAction;
begin
  Result := TNXLSCodeAction(inherited result);
end;

procedure TNXLSCodeActionResolveRequest.SetResult(AValue: TNXLSCodeAction);
begin
  inherited result := AValue;
end;

function TNXLSWorkspaceSymbolResolveRequest.GetResult: TNXLSWorkspaceSymbol;
begin
  Result := TNXLSWorkspaceSymbol(inherited result);
end;

procedure TNXLSWorkspaceSymbolResolveRequest.SetResult(AValue: TNXLSWorkspaceSymbol);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSDocumentLinkResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeLensResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSInlayHintResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCompletionItemResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSCodeActionResolveRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceSymbolResolveRequest);

end.
