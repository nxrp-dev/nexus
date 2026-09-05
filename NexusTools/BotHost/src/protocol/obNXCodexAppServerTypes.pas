unit obNXCodexAppServerTypes;

{$mode objfpc}{$H+}

interface

uses
  fpjson,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXJSONRPCMessages;

type
  TNXCodexStringArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXCodexClientInfo = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Ftitle: TNXJSONString;
    Fversion: TNXJSONString;
  public
    constructor Create; override;
  published
    property name: TNXJSONString read Fname write Fname;
    property title: TNXJSONString read Ftitle write Ftitle;
    property version: TNXJSONString read Fversion write Fversion;
  end;

  TNXCodexInitializeCapabilities = class(TNXJSONObject)
  private
    FexperimentalApi: TNXJSONBoolean;
    FrequestAttestation: TNXJSONBoolean;
    FmcpServerOpenaiFormElicitation: TNXJSONBoolean;
    FoptOutNotificationMethods: TNXCodexStringArray;
  public
    constructor Create; override;
  published
    property experimentalApi: TNXJSONBoolean read FexperimentalApi
      write FexperimentalApi;
    property requestAttestation: TNXJSONBoolean read FrequestAttestation
      write FrequestAttestation;
    property mcpServerOpenaiFormElicitation: TNXJSONBoolean
      read FmcpServerOpenaiFormElicitation write FmcpServerOpenaiFormElicitation;
    property optOutNotificationMethods: TNXCodexStringArray
      read FoptOutNotificationMethods write FoptOutNotificationMethods;
  end;

  TNXCodexInitializeParams = class(TNXJSONRPCObjectParams)
  private
    FclientInfo: TNXCodexClientInfo;
    Fcapabilities: TNXCodexInitializeCapabilities;
  public
    constructor Create; override;
  published
    property clientInfo: TNXCodexClientInfo read FclientInfo write FclientInfo;
    property capabilities: TNXCodexInitializeCapabilities read Fcapabilities
      write Fcapabilities;
  end;

  TNXCodexInitializeResponse = class(TNXJSONRPCCommandResult)
  private
    FuserAgent: TNXJSONString;
    FcodexHome: TNXJSONString;
    FplatformFamily: TNXJSONString;
    FplatformOs: TNXJSONString;
  published
    property userAgent: TNXJSONString read FuserAgent write FuserAgent;
    property codexHome: TNXJSONString read FcodexHome write FcodexHome;
    property platformFamily: TNXJSONString read FplatformFamily
      write FplatformFamily;
    property platformOs: TNXJSONString read FplatformOs write FplatformOs;
  end;

  TNXCodexEmptyParams = class(TNXJSONRPCObjectParams)
  end;

  TNXCodexEmptyResult = class(TNXJSONRPCCommandResult)
  end;

  TNXCodexModelReasoningEffort = class(TNXJSONObject)
  private
    FreasoningEffort: TNXJSONString;
    Fdescription: TNXJSONString;
  published
    property reasoningEffort: TNXJSONString read FreasoningEffort
      write FreasoningEffort;
    property description: TNXJSONString read Fdescription write Fdescription;
  end;

  TNXCodexModelReasoningEffortArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXCodexModelServiceTier = class(TNXJSONObject)
  private
    Fid: TNXJSONString;
    Fname: TNXJSONString;
    Fdescription: TNXJSONString;
  published
    property id: TNXJSONString read Fid write Fid;
    property name: TNXJSONString read Fname write Fname;
    property description: TNXJSONString read Fdescription write Fdescription;
  end;

  TNXCodexModelServiceTierArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXCodexModelUpgradeInfo = class(TNXJSONObject)
  private
    Fmodel: TNXJSONString;
    FupgradeCopy: TNXJSONString;
    FmodelLink: TNXJSONString;
    FmigrationMarkdown: TNXJSONString;
    FretirementAt: TNXJSONInteger;
  public
    constructor Create; override;
  published
    property model: TNXJSONString read Fmodel write Fmodel;
    property upgradeCopy: TNXJSONString read FupgradeCopy write FupgradeCopy;
    property modelLink: TNXJSONString read FmodelLink write FmodelLink;
    property migrationMarkdown: TNXJSONString read FmigrationMarkdown
      write FmigrationMarkdown;
    property retirementAt: TNXJSONInteger read FretirementAt write FretirementAt;
  end;

  TNXCodexModelAvailability = class(TNXJSONObject)
  private
    Fmessage: TNXJSONString;
  published
    property message: TNXJSONString read Fmessage write Fmessage;
  end;

  TNXCodexModel = class(TNXJSONObject)
  private
    Fid: TNXJSONString;
    Fmodel: TNXJSONString;
    Fupgrade: TNXJSONString;
    FupgradeInfo: TNXCodexModelUpgradeInfo;
    FavailabilityNux: TNXCodexModelAvailability;
    FdisplayName: TNXJSONString;
    Fdescription: TNXJSONString;
    FmodelSpecialty: TNXJSONString;
    Fhidden: TNXJSONBoolean;
    FsupportedReasoningEfforts: TNXCodexModelReasoningEffortArray;
    FdefaultReasoningEffort: TNXJSONString;
    FinputModalities: TNXCodexStringArray;
    FsupportsPersonality: TNXJSONBoolean;
    FmultiAgentVersion: TNXJSONString;
    FadditionalSpeedTiers: TNXCodexStringArray;
    FserviceTiers: TNXCodexModelServiceTierArray;
    FdefaultServiceTier: TNXJSONString;
    FisDefault: TNXJSONBoolean;
  public
    constructor Create; override;
  published
    property id: TNXJSONString read Fid write Fid;
    property model: TNXJSONString read Fmodel write Fmodel;
    property upgrade: TNXJSONString read Fupgrade write Fupgrade;
    property upgradeInfo: TNXCodexModelUpgradeInfo read FupgradeInfo
      write FupgradeInfo;
    property availabilityNux: TNXCodexModelAvailability read FavailabilityNux
      write FavailabilityNux;
    property displayName: TNXJSONString read FdisplayName write FdisplayName;
    property description: TNXJSONString read Fdescription write Fdescription;
    property modelSpecialty: TNXJSONString read FmodelSpecialty
      write FmodelSpecialty;
    property hidden: TNXJSONBoolean read Fhidden write Fhidden;
    property supportedReasoningEfforts: TNXCodexModelReasoningEffortArray
      read FsupportedReasoningEfforts write FsupportedReasoningEfforts;
    property defaultReasoningEffort: TNXJSONString read FdefaultReasoningEffort
      write FdefaultReasoningEffort;
    property inputModalities: TNXCodexStringArray read FinputModalities
      write FinputModalities;
    property supportsPersonality: TNXJSONBoolean read FsupportsPersonality
      write FsupportsPersonality;
    property multiAgentVersion: TNXJSONString read FmultiAgentVersion
      write FmultiAgentVersion;
    property additionalSpeedTiers: TNXCodexStringArray read FadditionalSpeedTiers
      write FadditionalSpeedTiers;
    property serviceTiers: TNXCodexModelServiceTierArray read FserviceTiers
      write FserviceTiers;
    property defaultServiceTier: TNXJSONString read FdefaultServiceTier
      write FdefaultServiceTier;
    property isDefault: TNXJSONBoolean read FisDefault write FisDefault;
  end;

  TNXCodexModelArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXCodexModelListParams = class(TNXJSONRPCObjectParams)
  private
    Fcursor: TNXJSONString;
    Flimit: TNXJSONInteger;
    FincludeHidden: TNXJSONBoolean;
  public
    constructor Create; override;
  published
    property cursor: TNXJSONString read Fcursor write Fcursor;
    property limit: TNXJSONInteger read Flimit write Flimit;
    property includeHidden: TNXJSONBoolean read FincludeHidden write FincludeHidden;
  end;

  TNXCodexModelListResponse = class(TNXJSONRPCCommandResult)
  private
    Fdata: TNXCodexModelArray;
    FnextCursor: TNXJSONString;
  public
    constructor Create; override;
  published
    property data: TNXCodexModelArray read Fdata write Fdata;
    property nextCursor: TNXJSONString read FnextCursor write FnextCursor;
  end;

  TNXCodexThreadStatus = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
    FactiveFlags: TNXCodexStringArray;
  published
    property &type: TNXJSONString read Ftype write Ftype;
    property activeFlags: TNXCodexStringArray read FactiveFlags write FactiveFlags;
  end;

  TNXCodexThread = class(TNXJSONObject)
  private
    Fid: TNXJSONString;
    FsessionId: TNXJSONString;
    Fpreview: TNXJSONString;
    Fephemeral: TNXJSONBoolean;
    FmodelProvider: TNXJSONString;
    FcreatedAt: TNXJSONInteger;
    FupdatedAt: TNXJSONInteger;
    Fstatus: TNXCodexThreadStatus;
    Fcwd: TNXJSONString;
    FcliVersion: TNXJSONString;
  published
    property id: TNXJSONString read Fid write Fid;
    property sessionId: TNXJSONString read FsessionId write FsessionId;
    property preview: TNXJSONString read Fpreview write Fpreview;
    property ephemeral: TNXJSONBoolean read Fephemeral write Fephemeral;
    property modelProvider: TNXJSONString read FmodelProvider write FmodelProvider;
    property createdAt: TNXJSONInteger read FcreatedAt write FcreatedAt;
    property updatedAt: TNXJSONInteger read FupdatedAt write FupdatedAt;
    property status: TNXCodexThreadStatus read Fstatus write Fstatus;
    property cwd: TNXJSONString read Fcwd write Fcwd;
    property cliVersion: TNXJSONString read FcliVersion write FcliVersion;
  end;

  TNXCodexThreadStartParams = class(TNXJSONRPCObjectParams)
  private
    Fmodel: TNXJSONString;
    Fcwd: TNXJSONString;
    FapprovalPolicy: TNXJSONString;
    FapprovalsReviewer: TNXJSONString;
    Fsandbox: TNXJSONString;
    FdeveloperInstructions: TNXJSONString;
    Fephemeral: TNXJSONBoolean;
    FdynamicTools: TNXJSONArray;
  public
    constructor Create; override;
  published
    property model: TNXJSONString read Fmodel write Fmodel;
    property cwd: TNXJSONString read Fcwd write Fcwd;
    property approvalPolicy: TNXJSONString read FapprovalPolicy
      write FapprovalPolicy;
    property approvalsReviewer: TNXJSONString read FapprovalsReviewer
      write FapprovalsReviewer;
    property sandbox: TNXJSONString read Fsandbox write Fsandbox;
    property developerInstructions: TNXJSONString read FdeveloperInstructions
      write FdeveloperInstructions;
    property ephemeral: TNXJSONBoolean read Fephemeral write Fephemeral;
    property dynamicTools: TNXJSONArray read FdynamicTools write FdynamicTools;
  end;

  TNXCodexThreadStartResponse = class(TNXJSONRPCCommandResult)
  private
    Fthread: TNXCodexThread;
    Fmodel: TNXJSONString;
    FmodelProvider: TNXJSONString;
    FserviceTier: TNXJSONString;
    Fcwd: TNXJSONString;
    FapprovalPolicy: TNXJSONString;
    FapprovalsReviewer: TNXJSONString;
    FreasoningEffort: TNXJSONString;
  public
    constructor Create; override;
  published
    property thread: TNXCodexThread read Fthread write Fthread;
    property model: TNXJSONString read Fmodel write Fmodel;
    property modelProvider: TNXJSONString read FmodelProvider write FmodelProvider;
    property serviceTier: TNXJSONString read FserviceTier write FserviceTier;
    property cwd: TNXJSONString read Fcwd write Fcwd;
    property approvalPolicy: TNXJSONString read FapprovalPolicy
      write FapprovalPolicy;
    property approvalsReviewer: TNXJSONString read FapprovalsReviewer
      write FapprovalsReviewer;
    property reasoningEffort: TNXJSONString read FreasoningEffort
      write FreasoningEffort;
  end;

  TNXCodexTextInput = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
    Ftext: TNXJSONString;
    Ftext_elements: TNXJSONArray;
  published
    property &type: TNXJSONString read Ftype write Ftype;
    property text: TNXJSONString read Ftext write Ftext;
    property text_elements: TNXJSONArray read Ftext_elements write Ftext_elements;
  end;

  TNXCodexUserInputArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXCodexTurnStartParams = class(TNXJSONRPCObjectParams)
  private
    FthreadId: TNXJSONString;
    FclientUserMessageId: TNXJSONString;
    Finput: TNXCodexUserInputArray;
  public
    constructor Create; override;
  published
    property threadId: TNXJSONString read FthreadId write FthreadId;
    property clientUserMessageId: TNXJSONString read FclientUserMessageId
      write FclientUserMessageId;
    property input: TNXCodexUserInputArray read Finput write Finput;
  end;

  TNXCodexThreadItemObject = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
    Fid: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
    property id: TNXJSONString read Fid write Fid;
  end;

  TNXCodexAgentMessageItem = class(TNXCodexThreadItemObject)
  private
    Ftext: TNXJSONString;
    Fphase: TNXJSONString;
  public
    constructor Create; override;
  published
    property text: TNXJSONString read Ftext write Ftext;
    property phase: TNXJSONString read Fphase write Fphase;
  end;

  TNXCodexUserMessageItem = class(TNXCodexThreadItemObject);
  TNXCodexHookPromptItem = class(TNXCodexThreadItemObject);
  TNXCodexFunctionCallOutputItem = class(TNXCodexThreadItemObject);
  TNXCodexPlanItem = class(TNXCodexThreadItemObject);
  TNXCodexReasoningItem = class(TNXCodexThreadItemObject);
  TNXCodexCommandExecutionItem = class(TNXCodexThreadItemObject);
  TNXCodexFileChangeItem = class(TNXCodexThreadItemObject);
  TNXCodexMCPToolCallItem = class(TNXCodexThreadItemObject);
  TNXCodexDynamicToolCallItem = class(TNXCodexThreadItemObject);
  TNXCodexCollabAgentToolCallItem = class(TNXCodexThreadItemObject);
  TNXCodexSubAgentActivityItem = class(TNXCodexThreadItemObject);
  TNXCodexWebSearchItem = class(TNXCodexThreadItemObject);
  TNXCodexImageViewItem = class(TNXCodexThreadItemObject);
  TNXCodexSleepItem = class(TNXCodexThreadItemObject);
  TNXCodexImageGenerationItem = class(TNXCodexThreadItemObject);
  TNXCodexEnteredReviewModeItem = class(TNXCodexThreadItemObject);
  TNXCodexExitedReviewModeItem = class(TNXCodexThreadItemObject);
  TNXCodexContextCompactionItem = class(TNXCodexThreadItemObject);

  TNXCodexThreadItem = class(TNXJSONRPCVariant)
  protected
    class function ValueClassForJSON(AData: TJSONData): TNXJSONRPCValueClass;
      override;
    class function SupportedValueClasses: TNXJSONRPCValueClassArray; override;
  end;

  TNXCodexThreadItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXCodexTurnError = class(TNXJSONObject)
  private
    Fmessage: TNXJSONString;
    FadditionalDetails: TNXJSONString;
  public
    constructor Create; override;
  published
    property message: TNXJSONString read Fmessage write Fmessage;
    property additionalDetails: TNXJSONString read FadditionalDetails
      write FadditionalDetails;
  end;

  TNXCodexTurn = class(TNXJSONObject)
  private
    Fid: TNXJSONString;
    Fitems: TNXCodexThreadItemArray;
    FitemsView: TNXJSONString;
    Fstatus: TNXJSONString;
    Ferror: TNXCodexTurnError;
    FstartedAt: TNXJSONInteger;
    FcompletedAt: TNXJSONInteger;
    FdurationMs: TNXJSONInteger;
  public
    constructor Create; override;
  published
    property id: TNXJSONString read Fid write Fid;
    property items: TNXCodexThreadItemArray read Fitems write Fitems;
    property itemsView: TNXJSONString read FitemsView write FitemsView;
    property status: TNXJSONString read Fstatus write Fstatus;
    property error: TNXCodexTurnError read Ferror write Ferror;
    property startedAt: TNXJSONInteger read FstartedAt write FstartedAt;
    property completedAt: TNXJSONInteger read FcompletedAt write FcompletedAt;
    property durationMs: TNXJSONInteger read FdurationMs write FdurationMs;
  end;

  TNXCodexTurnStartResponse = class(TNXJSONRPCCommandResult)
  private
    Fturn: TNXCodexTurn;
  published
    property turn: TNXCodexTurn read Fturn write Fturn;
  end;

  TNXCodexTurnInterruptParams = class(TNXJSONRPCObjectParams)
  private
    FthreadId: TNXJSONString;
    FturnId: TNXJSONString;
  published
    property threadId: TNXJSONString read FthreadId write FthreadId;
    property turnId: TNXJSONString read FturnId write FturnId;
  end;

  TNXCodexThreadUnsubscribeParams = class(TNXJSONRPCObjectParams)
  private
    FthreadId: TNXJSONString;
  published
    property threadId: TNXJSONString read FthreadId write FthreadId;
  end;

  TNXCodexThreadUnsubscribeResponse = class(TNXJSONRPCCommandResult)
  private
    Fstatus: TNXJSONString;
  published
    property status: TNXJSONString read Fstatus write Fstatus;
  end;

  TNXCodexItemNotificationParams = class(TNXJSONRPCObjectParams)
  private
    Fitem: TNXCodexThreadItem;
    FthreadId: TNXJSONString;
    FturnId: TNXJSONString;
    FstartedAtMs: TNXJSONInteger;
    FcompletedAtMs: TNXJSONInteger;
  published
    property item: TNXCodexThreadItem read Fitem write Fitem;
    property threadId: TNXJSONString read FthreadId write FthreadId;
    property turnId: TNXJSONString read FturnId write FturnId;
    property startedAtMs: TNXJSONInteger read FstartedAtMs write FstartedAtMs;
    property completedAtMs: TNXJSONInteger read FcompletedAtMs write FcompletedAtMs;
  end;

  TNXCodexTurnNotificationParams = class(TNXJSONRPCObjectParams)
  private
    FthreadId: TNXJSONString;
    Fturn: TNXCodexTurn;
  published
    property threadId: TNXJSONString read FthreadId write FthreadId;
    property turn: TNXCodexTurn read Fturn write Fturn;
  end;

  TNXCodexErrorNotificationParams = class(TNXJSONRPCObjectParams)
  private
    Ferror: TNXCodexTurnError;
    FwillRetry: TNXJSONBoolean;
    FthreadId: TNXJSONString;
    FturnId: TNXJSONString;
  published
    property error: TNXCodexTurnError read Ferror write Ferror;
    property willRetry: TNXJSONBoolean read FwillRetry write FwillRetry;
    property threadId: TNXJSONString read FthreadId write FthreadId;
    property turnId: TNXJSONString read FturnId write FturnId;
  end;

  TNXCodexApprovalParams = class(TNXJSONRPCObjectParams)
  private
    FthreadId: TNXJSONString;
    FturnId: TNXJSONString;
    FitemId: TNXJSONString;
  published
    property threadId: TNXJSONString read FthreadId write FthreadId;
    property turnId: TNXJSONString read FturnId write FturnId;
    property itemId: TNXJSONString read FitemId write FitemId;
  end;

  TNXCodexDecisionResult = class(TNXJSONObject)
  private
    Fdecision: TNXJSONString;
  published
    property decision: TNXJSONString read Fdecision write Fdecision;
  end;

  TNXCodexElicitationResult = class(TNXJSONObject)
  private
    Faction: TNXJSONString;
  published
    property action: TNXJSONString read Faction write Faction;
  end;

  TNXCodexUserInputResult = class(TNXJSONObject)
  private
    Fanswers: TNXJSONObject;
  published
    property answers: TNXJSONObject read Fanswers write Fanswers;
  end;

  TNXCodexPermissionsResult = class(TNXJSONObject)
  private
    Fpermissions: TNXJSONObject;
    Fscope: TNXJSONString;
    FstrictAutoReview: TNXJSONBoolean;
  published
    property permissions: TNXJSONObject read Fpermissions write Fpermissions;
    property scope: TNXJSONString read Fscope write Fscope;
    property strictAutoReview: TNXJSONBoolean read FstrictAutoReview
      write FstrictAutoReview;
  end;

  TNXCodexBotControlArguments = class(TNXJSONObject)
  private
    Fbot: TNXJSONString;
    Foperation: TNXJSONString;
    Froom: TNXJSONString;
  published
    property bot: TNXJSONString read Fbot write Fbot;
    property operation: TNXJSONString read Foperation write Foperation;
    property room: TNXJSONString read Froom write Froom;
  end;

  TNXCodexBotControlOperationSchema = class(TNXJSONObject)
  private
    Fenum: TNXCodexStringArray;
    Ftype: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
    property &enum: TNXCodexStringArray read Fenum write Fenum;
  end;

  TNXCodexBotControlStringSchema = class(TNXJSONObject)
  private
    Ftype: TNXJSONString;
  published
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXCodexBotControlSchemaProperties = class(TNXJSONObject)
  private
    Fbot: TNXCodexBotControlStringSchema;
    Foperation: TNXCodexBotControlOperationSchema;
    Froom: TNXCodexBotControlStringSchema;
  published
    property bot: TNXCodexBotControlStringSchema read Fbot write Fbot;
    property operation: TNXCodexBotControlOperationSchema read Foperation
      write Foperation;
    property room: TNXCodexBotControlStringSchema read Froom write Froom;
  end;

  TNXCodexBotControlInputSchema = class(TNXJSONObject)
  private
    FadditionalProperties: TNXJSONBoolean;
    Fproperties: TNXCodexBotControlSchemaProperties;
    Frequired: TNXCodexStringArray;
    Ftype: TNXJSONString;
  published
    property additionalProperties: TNXJSONBoolean read FadditionalProperties
      write FadditionalProperties;
    property properties: TNXCodexBotControlSchemaProperties read Fproperties
      write Fproperties;
    property required: TNXCodexStringArray read Frequired write Frequired;
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXCodexDynamicToolSpec = class(TNXJSONObject)
  private
    Fdescription: TNXJSONString;
    FinputSchema: TNXCodexBotControlInputSchema;
    Fname: TNXJSONString;
    Ftype: TNXJSONString;
  published
    property description: TNXJSONString read Fdescription write Fdescription;
    property inputSchema: TNXCodexBotControlInputSchema read FinputSchema
      write FinputSchema;
    property name: TNXJSONString read Fname write Fname;
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXCodexDynamicToolTextContent = class(TNXJSONObject)
  private
    Ftext: TNXJSONString;
    Ftype: TNXJSONString;
  published
    property text: TNXJSONString read Ftext write Ftext;
    property &type: TNXJSONString read Ftype write Ftype;
  end;

  TNXCodexAnyJSONValue = class(TNXJSONRPCVariant)
  protected
    class function ValueClassForJSON(AData: TJSONData):
      TNXJSONRPCValueClass; override;
    class function SupportedValueClasses: TNXJSONRPCValueClassArray; override;
  end;

  TNXCodexDynamicToolCallParams = class(TNXJSONRPCObjectParams)
  private
    Farguments: TNXCodexAnyJSONValue;
    FcallId: TNXJSONString;
    Fnamespace: TNXJSONString;
    FthreadId: TNXJSONString;
    Ftool: TNXJSONString;
    FturnId: TNXJSONString;
  public
    constructor Create; override;
  published
    property arguments: TNXCodexAnyJSONValue read Farguments write Farguments;
    property callId: TNXJSONString read FcallId write FcallId;
    property namespace: TNXJSONString read Fnamespace write Fnamespace;
    property threadId: TNXJSONString read FthreadId write FthreadId;
    property tool: TNXJSONString read Ftool write Ftool;
    property turnId: TNXJSONString read FturnId write FturnId;
  end;

  TNXCodexDynamicToolCallResult = class(TNXJSONObject)
  private
    FcontentItems: TNXJSONArray;
    Fsuccess: TNXJSONBoolean;
  published
    property contentItems: TNXJSONArray read FcontentItems write FcontentItems;
    property success: TNXJSONBoolean read Fsuccess write Fsuccess;
  end;

  TNXCodexAuthRefreshParams = class(TNXJSONRPCObjectParams)
  private
    FpreviousAccountId: TNXJSONString;
    Freason: TNXJSONString;
  public
    constructor Create; override;
  published
    property previousAccountId: TNXJSONString read FpreviousAccountId
      write FpreviousAccountId;
    property reason: TNXJSONString read Freason write Freason;
  end;

  TNXCodexAttestationParams = class(TNXJSONRPCObjectParams)
  end;

implementation

uses
  SysUtils;

class function TNXCodexStringArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXJSONString;
end;

constructor TNXCodexClientInfo.Create;
begin
  inherited Create;
  title.AcceptsNull := True;
end;

constructor TNXCodexInitializeCapabilities.Create;
begin
  inherited Create;
  optOutNotificationMethods.AcceptsNull := True;
end;

constructor TNXCodexInitializeParams.Create;
begin
  inherited Create;
  capabilities.AcceptsNull := True;
end;

class function TNXCodexModelReasoningEffortArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXCodexModelReasoningEffort;
end;

class function TNXCodexModelServiceTierArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXCodexModelServiceTier;
end;

constructor TNXCodexModelUpgradeInfo.Create;
begin
  inherited Create;
  upgradeCopy.AcceptsNull := True;
  modelLink.AcceptsNull := True;
  migrationMarkdown.AcceptsNull := True;
  retirementAt.AcceptsNull := True;
end;

constructor TNXCodexModel.Create;
begin
  inherited Create;
  upgrade.AcceptsNull := True;
  upgradeInfo.AcceptsNull := True;
  availabilityNux.AcceptsNull := True;
  modelSpecialty.AcceptsNull := True;
  multiAgentVersion.AcceptsNull := True;
  defaultServiceTier.AcceptsNull := True;
end;

class function TNXCodexModelArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXCodexModel;
end;

constructor TNXCodexModelListParams.Create;
begin
  inherited Create;
  cursor.AcceptsNull := True;
  limit.AcceptsNull := True;
  includeHidden.AcceptsNull := True;
end;

constructor TNXCodexModelListResponse.Create;
begin
  inherited Create;
  nextCursor.AcceptsNull := True;
end;

constructor TNXCodexThreadStartParams.Create;
begin
  inherited Create;
  model.AcceptsNull := True;
  cwd.AcceptsNull := True;
end;

constructor TNXCodexThreadStartResponse.Create;
begin
  inherited Create;
  serviceTier.AcceptsNull := True;
  reasoningEffort.AcceptsNull := True;
end;

class function TNXCodexUserInputArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXCodexTextInput;
end;

constructor TNXCodexTurnStartParams.Create;
begin
  inherited Create;
  clientUserMessageId.AcceptsNull := True;
end;

constructor TNXCodexAgentMessageItem.Create;
begin
  inherited Create;
  phase.AcceptsNull := True;
end;

class function TNXCodexThreadItem.ValueClassForJSON(
  AData: TJSONData): TNXJSONRPCValueClass;
var
  lTypeData: TJSONData;
  lTypeName: string;
begin
  Result := nil;
  if not (AData is TJSONObject) then
    Exit;
  lTypeData := TJSONObject(AData).Find('type');
  if (lTypeData = nil) or (lTypeData.JSONType <> jtString) then
    Exit;
  lTypeName := lTypeData.AsString;
  case lTypeName of
    'userMessage': Result := TNXCodexUserMessageItem;
    'hookPrompt': Result := TNXCodexHookPromptItem;
    'agentMessage': Result := TNXCodexAgentMessageItem;
    'functionCallOutput': Result := TNXCodexFunctionCallOutputItem;
    'plan': Result := TNXCodexPlanItem;
    'reasoning': Result := TNXCodexReasoningItem;
    'commandExecution': Result := TNXCodexCommandExecutionItem;
    'fileChange': Result := TNXCodexFileChangeItem;
    'mcpToolCall': Result := TNXCodexMCPToolCallItem;
    'dynamicToolCall': Result := TNXCodexDynamicToolCallItem;
    'collabAgentToolCall': Result := TNXCodexCollabAgentToolCallItem;
    'subAgentActivity': Result := TNXCodexSubAgentActivityItem;
    'webSearch': Result := TNXCodexWebSearchItem;
    'imageView': Result := TNXCodexImageViewItem;
    'sleep': Result := TNXCodexSleepItem;
    'imageGeneration': Result := TNXCodexImageGenerationItem;
    'enteredReviewMode': Result := TNXCodexEnteredReviewModeItem;
    'exitedReviewMode': Result := TNXCodexExitedReviewModeItem;
    'contextCompaction': Result := TNXCodexContextCompactionItem;
  end;
end;

class function TNXCodexThreadItem.SupportedValueClasses:
  TNXJSONRPCValueClassArray;
begin
  Result := nil;
  SetLength(Result, 19);
  Result[0] := TNXCodexUserMessageItem;
  Result[1] := TNXCodexHookPromptItem;
  Result[2] := TNXCodexAgentMessageItem;
  Result[3] := TNXCodexFunctionCallOutputItem;
  Result[4] := TNXCodexPlanItem;
  Result[5] := TNXCodexReasoningItem;
  Result[6] := TNXCodexCommandExecutionItem;
  Result[7] := TNXCodexFileChangeItem;
  Result[8] := TNXCodexMCPToolCallItem;
  Result[9] := TNXCodexDynamicToolCallItem;
  Result[10] := TNXCodexCollabAgentToolCallItem;
  Result[11] := TNXCodexSubAgentActivityItem;
  Result[12] := TNXCodexWebSearchItem;
  Result[13] := TNXCodexImageViewItem;
  Result[14] := TNXCodexSleepItem;
  Result[15] := TNXCodexImageGenerationItem;
  Result[16] := TNXCodexEnteredReviewModeItem;
  Result[17] := TNXCodexExitedReviewModeItem;
  Result[18] := TNXCodexContextCompactionItem;
end;

class function TNXCodexThreadItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXCodexThreadItem;
end;

constructor TNXCodexTurnError.Create;
begin
  inherited Create;
  additionalDetails.AcceptsNull := True;
end;

class function TNXCodexAnyJSONValue.SupportedValueClasses:
  TNXJSONRPCValueClassArray;
begin
  Result := nil;
  SetLength(Result, 7);
  Result[0] := TNXJSONNull;
  Result[1] := TNXJSONString;
  Result[2] := TNXJSONInteger;
  Result[3] := TNXJSONFloat;
  Result[4] := TNXJSONBoolean;
  Result[5] := TNXJSONArray;
  Result[6] := TNXJSONObject;
end;

class function TNXCodexAnyJSONValue.ValueClassForJSON(AData: TJSONData):
  TNXJSONRPCValueClass;
begin
  if (AData <> nil) and (AData.JSONType = jtObject) then
    Result := TNXCodexBotControlArguments
  else
    Result := inherited ValueClassForJSON(AData);
end;

constructor TNXCodexDynamicToolCallParams.Create;
begin
  inherited Create;
  namespace.AcceptsNull := True;
end;

constructor TNXCodexAuthRefreshParams.Create;
begin
  inherited Create;
  previousAccountId.AcceptsNull := True;
end;

constructor TNXCodexTurn.Create;
begin
  inherited Create;
  error.AcceptsNull := True;
  startedAt.AcceptsNull := True;
  completedAt.AcceptsNull := True;
  durationMs.AcceptsNull := True;
end;

end.
