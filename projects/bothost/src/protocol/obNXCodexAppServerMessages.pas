unit obNXCodexAppServerMessages;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXCodexAppServerTypes;

type
  TNXCodexInitializeCommand = class(TNXJSONRPCOutboundCommand)
  private
    function GetParams: TNXCodexInitializeParams;
    function GetResult: TNXCodexInitializeResponse;
    procedure SetParams(AValue: TNXCodexInitializeParams);
    procedure SetResult(AValue: TNXCodexInitializeResponse);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexInitializeParams read GetParams write SetParams;
    property result: TNXCodexInitializeResponse read GetResult write SetResult;
  end;

  TNXCodexInitializedNotification = class(TNXJSONRPCOutboundNotification)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexModelListCommand = class(TNXJSONRPCOutboundCommand)
  private
    function GetParams: TNXCodexModelListParams;
    function GetResult: TNXCodexModelListResponse;
    procedure SetParams(AValue: TNXCodexModelListParams);
    procedure SetResult(AValue: TNXCodexModelListResponse);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexModelListParams read GetParams write SetParams;
    property result: TNXCodexModelListResponse read GetResult write SetResult;
  end;

  TNXCodexThreadStartCommand = class(TNXJSONRPCOutboundCommand)
  private
    function GetParams: TNXCodexThreadStartParams;
    function GetResult: TNXCodexThreadStartResponse;
    procedure SetParams(AValue: TNXCodexThreadStartParams);
    procedure SetResult(AValue: TNXCodexThreadStartResponse);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexThreadStartParams read GetParams write SetParams;
    property result: TNXCodexThreadStartResponse read GetResult write SetResult;
  end;

  TNXCodexTurnStartCommand = class(TNXJSONRPCOutboundCommand)
  private
    function GetParams: TNXCodexTurnStartParams;
    function GetResult: TNXCodexTurnStartResponse;
    procedure SetParams(AValue: TNXCodexTurnStartParams);
    procedure SetResult(AValue: TNXCodexTurnStartResponse);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexTurnStartParams read GetParams write SetParams;
    property result: TNXCodexTurnStartResponse read GetResult write SetResult;
  end;

  TNXCodexTurnInterruptCommand = class(TNXJSONRPCOutboundCommand)
  private
    function GetParams: TNXCodexTurnInterruptParams;
    function GetResult: TNXCodexEmptyResult;
    procedure SetParams(AValue: TNXCodexTurnInterruptParams);
    procedure SetResult(AValue: TNXCodexEmptyResult);
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
  published
    property params: TNXCodexTurnInterruptParams read GetParams write SetParams;
    property result: TNXCodexEmptyResult read GetResult write SetResult;
  end;

  TNXCodexThreadUnsubscribeCommand = class(TNXJSONRPCOutboundCommand)
  private
    function GetParams: TNXCodexThreadUnsubscribeParams;
    function GetResult: TNXCodexThreadUnsubscribeResponse;
    procedure SetParams(AValue: TNXCodexThreadUnsubscribeParams);
    procedure SetResult(AValue: TNXCodexThreadUnsubscribeResponse);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexThreadUnsubscribeParams read GetParams
      write SetParams;
    property result: TNXCodexThreadUnsubscribeResponse read GetResult
      write SetResult;
  end;

  TNXCodexItemStartedNotification = class(TNXJSONRPCNotification)
  private
    function GetParams: TNXCodexItemNotificationParams;
    procedure SetParams(AValue: TNXCodexItemNotificationParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexItemNotificationParams read GetParams
      write SetParams;
  end;

  TNXCodexItemCompletedNotification = class(TNXCodexItemStartedNotification)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexTurnStartedNotification = class(TNXJSONRPCNotification)
  private
    function GetParams: TNXCodexTurnNotificationParams;
    procedure SetParams(AValue: TNXCodexTurnNotificationParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexTurnNotificationParams read GetParams
      write SetParams;
  end;

  TNXCodexTurnCompletedNotification = class(TNXCodexTurnStartedNotification)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexErrorNotification = class(TNXJSONRPCNotification)
  private
    function GetParams: TNXCodexErrorNotificationParams;
    procedure SetParams(AValue: TNXCodexErrorNotificationParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexErrorNotificationParams read GetParams
      write SetParams;
  end;

  TNXCodexApprovalRequest = class(TNXJSONRPCCommandMessage)
  private
    function GetParams: TNXCodexApprovalParams;
    procedure SetParams(AValue: TNXCodexApprovalParams);
  published
    property params: TNXCodexApprovalParams read GetParams write SetParams;
  end;

  TNXCodexCommandApprovalRequest = class(TNXCodexApprovalRequest)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexFileChangeApprovalRequest = class(TNXCodexApprovalRequest)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexPermissionsApprovalRequest = class(TNXCodexApprovalRequest)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexUserInputRequest = class(TNXCodexApprovalRequest)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexMCPElicitationRequest = class(TNXCodexApprovalRequest)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexLegacyApplyPatchApprovalRequest = class(TNXCodexApprovalRequest)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexLegacyExecCommandApprovalRequest = class(TNXCodexApprovalRequest)
  public
    class function GetFactoryName: string; override;
  end;

  TNXCodexDynamicToolCallRequest = class(TNXJSONRPCCommandMessage)
  private
    function GetParams: TNXCodexDynamicToolCallParams;
    procedure SetParams(AValue: TNXCodexDynamicToolCallParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexDynamicToolCallParams read GetParams
      write SetParams;
  end;

  TNXCodexAuthRefreshRequest = class(TNXJSONRPCCommandMessage)
  private
    function GetParams: TNXCodexAuthRefreshParams;
    procedure SetParams(AValue: TNXCodexAuthRefreshParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexAuthRefreshParams read GetParams write SetParams;
  end;

  TNXCodexAttestationRequest = class(TNXJSONRPCCommandMessage)
  private
    function GetParams: TNXCodexAttestationParams;
    procedure SetParams(AValue: TNXCodexAttestationParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXCodexAttestationParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory;

class function TNXCodexInitializeCommand.GetFactoryName: string;
begin
  Result := 'initialize';
end;

function TNXCodexInitializeCommand.GetParams: TNXCodexInitializeParams;
begin
  Result := TNXCodexInitializeParams(inherited params);
end;

function TNXCodexInitializeCommand.GetResult: TNXCodexInitializeResponse;
begin
  Result := TNXCodexInitializeResponse(inherited result);
end;

procedure TNXCodexInitializeCommand.SetParams(AValue: TNXCodexInitializeParams);
begin
  inherited params := AValue;
end;

procedure TNXCodexInitializeCommand.SetResult(AValue: TNXCodexInitializeResponse);
begin
  inherited result := AValue;
end;

class function TNXCodexInitializedNotification.GetFactoryName: string;
begin
  Result := 'initialized';
end;

class function TNXCodexModelListCommand.GetFactoryName: string;
begin
  Result := 'model/list';
end;

function TNXCodexModelListCommand.GetParams: TNXCodexModelListParams;
begin
  Result := TNXCodexModelListParams(inherited params);
end;

function TNXCodexModelListCommand.GetResult: TNXCodexModelListResponse;
begin
  Result := TNXCodexModelListResponse(inherited result);
end;

procedure TNXCodexModelListCommand.SetParams(AValue: TNXCodexModelListParams);
begin
  inherited params := AValue;
end;

procedure TNXCodexModelListCommand.SetResult(AValue: TNXCodexModelListResponse);
begin
  inherited result := AValue;
end;

class function TNXCodexThreadStartCommand.GetFactoryName: string;
begin
  Result := 'thread/start';
end;

function TNXCodexThreadStartCommand.GetParams: TNXCodexThreadStartParams;
begin
  Result := TNXCodexThreadStartParams(inherited params);
end;

function TNXCodexThreadStartCommand.GetResult: TNXCodexThreadStartResponse;
begin
  Result := TNXCodexThreadStartResponse(inherited result);
end;

procedure TNXCodexThreadStartCommand.SetParams(AValue: TNXCodexThreadStartParams);
begin
  inherited params := AValue;
end;

procedure TNXCodexThreadStartCommand.SetResult(AValue: TNXCodexThreadStartResponse);
begin
  inherited result := AValue;
end;

class function TNXCodexTurnStartCommand.GetFactoryName: string;
begin
  Result := 'turn/start';
end;

function TNXCodexTurnStartCommand.GetParams: TNXCodexTurnStartParams;
begin
  Result := TNXCodexTurnStartParams(inherited params);
end;

function TNXCodexTurnStartCommand.GetResult: TNXCodexTurnStartResponse;
begin
  Result := TNXCodexTurnStartResponse(inherited result);
end;

procedure TNXCodexTurnStartCommand.SetParams(AValue: TNXCodexTurnStartParams);
begin
  inherited params := AValue;
end;

procedure TNXCodexTurnStartCommand.SetResult(AValue: TNXCodexTurnStartResponse);
begin
  inherited result := AValue;
end;

class function TNXCodexTurnInterruptCommand.GetFactoryName: string;
begin
  Result := 'turn/interrupt';
end;

class function TNXCodexTurnInterruptCommand.GetResultKind:
  TNXJSONRPCResultKind;
begin
  Result := rkConcreteResult;
end;

function TNXCodexTurnInterruptCommand.GetParams: TNXCodexTurnInterruptParams;
begin
  Result := TNXCodexTurnInterruptParams(inherited params);
end;

function TNXCodexTurnInterruptCommand.GetResult: TNXCodexEmptyResult;
begin
  Result := TNXCodexEmptyResult(inherited result);
end;

procedure TNXCodexTurnInterruptCommand.SetParams(
  AValue: TNXCodexTurnInterruptParams);
begin
  inherited params := AValue;
end;

procedure TNXCodexTurnInterruptCommand.SetResult(AValue: TNXCodexEmptyResult);
begin
  inherited result := AValue;
end;

class function TNXCodexThreadUnsubscribeCommand.GetFactoryName: string;
begin
  Result := 'thread/unsubscribe';
end;

function TNXCodexThreadUnsubscribeCommand.GetParams:
  TNXCodexThreadUnsubscribeParams;
begin
  Result := TNXCodexThreadUnsubscribeParams(inherited params);
end;

function TNXCodexThreadUnsubscribeCommand.GetResult:
  TNXCodexThreadUnsubscribeResponse;
begin
  Result := TNXCodexThreadUnsubscribeResponse(inherited result);
end;

procedure TNXCodexThreadUnsubscribeCommand.SetParams(
  AValue: TNXCodexThreadUnsubscribeParams);
begin
  inherited params := AValue;
end;

procedure TNXCodexThreadUnsubscribeCommand.SetResult(
  AValue: TNXCodexThreadUnsubscribeResponse);
begin
  inherited result := AValue;
end;

class function TNXCodexItemStartedNotification.GetFactoryName: string;
begin
  Result := 'item/started';
end;

function TNXCodexItemStartedNotification.GetParams:
  TNXCodexItemNotificationParams;
begin
  Result := TNXCodexItemNotificationParams(inherited params);
end;

procedure TNXCodexItemStartedNotification.SetParams(
  AValue: TNXCodexItemNotificationParams);
begin
  inherited params := AValue;
end;

class function TNXCodexItemCompletedNotification.GetFactoryName: string;
begin
  Result := 'item/completed';
end;

class function TNXCodexTurnStartedNotification.GetFactoryName: string;
begin
  Result := 'turn/started';
end;

function TNXCodexTurnStartedNotification.GetParams:
  TNXCodexTurnNotificationParams;
begin
  Result := TNXCodexTurnNotificationParams(inherited params);
end;

procedure TNXCodexTurnStartedNotification.SetParams(
  AValue: TNXCodexTurnNotificationParams);
begin
  inherited params := AValue;
end;

class function TNXCodexTurnCompletedNotification.GetFactoryName: string;
begin
  Result := 'turn/completed';
end;

class function TNXCodexErrorNotification.GetFactoryName: string;
begin
  Result := 'error';
end;

function TNXCodexErrorNotification.GetParams:
  TNXCodexErrorNotificationParams;
begin
  Result := TNXCodexErrorNotificationParams(inherited params);
end;

procedure TNXCodexErrorNotification.SetParams(
  AValue: TNXCodexErrorNotificationParams);
begin
  inherited params := AValue;
end;

function TNXCodexApprovalRequest.GetParams: TNXCodexApprovalParams;
begin
  Result := TNXCodexApprovalParams(inherited params);
end;

procedure TNXCodexApprovalRequest.SetParams(AValue: TNXCodexApprovalParams);
begin
  inherited params := AValue;
end;

class function TNXCodexCommandApprovalRequest.GetFactoryName: string;
begin
  Result := 'item/commandExecution/requestApproval';
end;

class function TNXCodexFileChangeApprovalRequest.GetFactoryName: string;
begin
  Result := 'item/fileChange/requestApproval';
end;

class function TNXCodexPermissionsApprovalRequest.GetFactoryName: string;
begin
  Result := 'item/permissions/requestApproval';
end;

class function TNXCodexUserInputRequest.GetFactoryName: string;
begin
  Result := 'item/tool/requestUserInput';
end;

class function TNXCodexMCPElicitationRequest.GetFactoryName: string;
begin
  Result := 'mcpServer/elicitation/request';
end;

class function TNXCodexLegacyApplyPatchApprovalRequest.GetFactoryName: string;
begin
  Result := 'applyPatchApproval';
end;

class function TNXCodexLegacyExecCommandApprovalRequest.GetFactoryName: string;
begin
  Result := 'execCommandApproval';
end;

class function TNXCodexDynamicToolCallRequest.GetFactoryName: string;
begin
  Result := 'item/tool/call';
end;

function TNXCodexDynamicToolCallRequest.GetParams:
  TNXCodexDynamicToolCallParams;
begin
  Result := TNXCodexDynamicToolCallParams(inherited params);
end;

procedure TNXCodexDynamicToolCallRequest.SetParams(
  AValue: TNXCodexDynamicToolCallParams);
begin
  inherited params := AValue;
end;

class function TNXCodexAuthRefreshRequest.GetFactoryName: string;
begin
  Result := 'account/chatgptAuthTokens/refresh';
end;

function TNXCodexAuthRefreshRequest.GetParams: TNXCodexAuthRefreshParams;
begin
  Result := TNXCodexAuthRefreshParams(inherited params);
end;

procedure TNXCodexAuthRefreshRequest.SetParams(
  AValue: TNXCodexAuthRefreshParams);
begin
  inherited params := AValue;
end;

class function TNXCodexAttestationRequest.GetFactoryName: string;
begin
  Result := 'attestation/generate';
end;

function TNXCodexAttestationRequest.GetParams: TNXCodexAttestationParams;
begin
  Result := TNXCodexAttestationParams(inherited params);
end;

procedure TNXCodexAttestationRequest.SetParams(
  AValue: TNXCodexAttestationParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXCodexItemStartedNotification);
  TNXClassFactory.RegisterClass(TNXCodexItemCompletedNotification);
  TNXClassFactory.RegisterClass(TNXCodexTurnStartedNotification);
  TNXClassFactory.RegisterClass(TNXCodexTurnCompletedNotification);
  TNXClassFactory.RegisterClass(TNXCodexErrorNotification);
  TNXClassFactory.RegisterClass(TNXCodexCommandApprovalRequest);
  TNXClassFactory.RegisterClass(TNXCodexFileChangeApprovalRequest);
  TNXClassFactory.RegisterClass(TNXCodexPermissionsApprovalRequest);
  TNXClassFactory.RegisterClass(TNXCodexUserInputRequest);
  TNXClassFactory.RegisterClass(TNXCodexMCPElicitationRequest);
  TNXClassFactory.RegisterClass(TNXCodexLegacyApplyPatchApprovalRequest);
  TNXClassFactory.RegisterClass(TNXCodexLegacyExecCommandApprovalRequest);
  TNXClassFactory.RegisterClass(TNXCodexDynamicToolCallRequest);
  TNXClassFactory.RegisterClass(TNXCodexAuthRefreshRequest);
  TNXClassFactory.RegisterClass(TNXCodexAttestationRequest);

end.
