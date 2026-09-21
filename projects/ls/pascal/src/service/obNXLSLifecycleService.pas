unit obNXLSLifecycleService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolParams,
  obNXLSProtocolObjects,
  obNXLSServiceContext;

type
  TNXLSLifecycleService = class(TNXLSLSPService)
  public
    procedure FillInitializeResult(AParams: TNXLSInitializeParams;
      AResult: TNXLSInitializeResultValue); virtual;
    procedure Initialized(AParams: TNXLSInitializedParams); virtual;
    procedure Shutdown; virtual;
    procedure ExitServer; virtual;
    procedure CancelRequest(AParams: TNXLSCancelParams); virtual;
  end;

implementation

procedure TNXLSLifecycleService.FillInitializeResult(AParams: TNXLSInitializeParams;
  AResult: TNXLSInitializeResultValue);
begin
  Model.BeginInitialize(AParams);
  if AResult = nil then
    Exit;

  AResult.capabilities.textDocumentSync.openClose.Value := True;
  AResult.capabilities.textDocumentSync.change.Value := 1;
  AResult.capabilities.textDocumentSync.save.Value := True;

  AResult.capabilities.workspace.workspaceFolders.supported.Value := True;
  AResult.capabilities.workspace.workspaceFolders.changeNotifications.Value := True;

  AResult.capabilities.completionProvider.triggerCharacters.AddString('.');
  AResult.capabilities.completionProvider.triggerCharacters.AddString('^');

  AResult.capabilities.signatureHelpProvider.triggerCharacters.AddString('(');
  AResult.capabilities.signatureHelpProvider.triggerCharacters.AddString(')');
  AResult.capabilities.signatureHelpProvider.triggerCharacters.AddString(',');

  AResult.capabilities.renameProvider.prepareProvider.Value := True;

  AResult.capabilities.hoverProvider.Value := True;
  AResult.capabilities.declarationProvider.Value := True;
  AResult.capabilities.definitionProvider.Value := True;
  AResult.capabilities.implementationProvider.Value := True;
  AResult.capabilities.referencesProvider.Value := True;
  AResult.capabilities.documentHighlightProvider.Value := True;
  AResult.capabilities.documentSymbolProvider.Value := True;
  AResult.capabilities.workspaceSymbolProvider.Value := True;
  AResult.capabilities.codeActionProvider.Value := True;
end;

procedure TNXLSLifecycleService.Initialized(AParams: TNXLSInitializedParams);
begin
  Model.MarkInitialized;
end;

procedure TNXLSLifecycleService.Shutdown;
begin
  Model.RequestShutdown;
end;

procedure TNXLSLifecycleService.ExitServer;
begin
  Model.RequestExit;
end;

procedure TNXLSLifecycleService.CancelRequest(AParams: TNXLSCancelParams);
begin
end;

end.
