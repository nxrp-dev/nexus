unit obNXLSProtocolObjects;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams;

type
  TNXLSProtocolResult = class(TObject)
  public
    class function CreateValue: TNXJSONValue; virtual;
  end;

  TNXLSNullResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSTextDocumentSyncOptions = class(TNXJSONObject)
  private
    FopenClose: TNXJSONBoolean;
    Fchange: TNXJSONInteger;
    FwillSave: TNXJSONBoolean;
    FwillSaveWaitUntil: TNXJSONBoolean;
    Fsave: TNXJSONBoolean;
  published
    property openClose: TNXJSONBoolean read FopenClose write FopenClose;
    property change: TNXJSONInteger read Fchange write Fchange;
    property willSave: TNXJSONBoolean read FwillSave write FwillSave;
    property willSaveWaitUntil: TNXJSONBoolean read FwillSaveWaitUntil write FwillSaveWaitUntil;
    property save: TNXJSONBoolean read Fsave write Fsave;
  end;

  TNXLSServerInfo = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Fversion: TNXJSONString;
  published
    property name: TNXJSONString read Fname write Fname;
    property version: TNXJSONString read Fversion write Fversion;
  end;

  TNXLSServerCapabilities = class(TNXJSONObject)
  private
    FtextDocumentSync: TNXLSTextDocumentSyncOptions;
    Fworkspace: TNXJSONValue;
    FcompletionProvider: TNXJSONValue;
    FhoverProvider: TNXJSONBoolean;
    FdeclarationProvider: TNXJSONBoolean;
    FdefinitionProvider: TNXJSONBoolean;
    FimplementationProvider: TNXJSONBoolean;
    FreferencesProvider: TNXJSONBoolean;
    FdocumentHighlightProvider: TNXJSONBoolean;
    FdocumentSymbolProvider: TNXJSONBoolean;
    FworkspaceSymbolProvider: TNXJSONBoolean;
    FsignatureHelpProvider: TNXJSONValue;
    FcodeActionProvider: TNXJSONBoolean;
    FexecuteCommandProvider: TNXJSONValue;
    FrenameProvider: TNXJSONValue;
    Fexperimental: TNXJSONValue;
  published
    property textDocumentSync: TNXLSTextDocumentSyncOptions read FtextDocumentSync write FtextDocumentSync;
    property workspace: TNXJSONValue read Fworkspace write Fworkspace;
    property completionProvider: TNXJSONValue read FcompletionProvider write FcompletionProvider;
    property hoverProvider: TNXJSONBoolean read FhoverProvider write FhoverProvider;
    property declarationProvider: TNXJSONBoolean read FdeclarationProvider write FdeclarationProvider;
    property definitionProvider: TNXJSONBoolean read FdefinitionProvider write FdefinitionProvider;
    property implementationProvider: TNXJSONBoolean read FimplementationProvider write FimplementationProvider;
    property referencesProvider: TNXJSONBoolean read FreferencesProvider write FreferencesProvider;
    property documentHighlightProvider: TNXJSONBoolean read FdocumentHighlightProvider write FdocumentHighlightProvider;
    property documentSymbolProvider: TNXJSONBoolean read FdocumentSymbolProvider write FdocumentSymbolProvider;
    property workspaceSymbolProvider: TNXJSONBoolean read FworkspaceSymbolProvider write FworkspaceSymbolProvider;
    property signatureHelpProvider: TNXJSONValue read FsignatureHelpProvider write FsignatureHelpProvider;
    property codeActionProvider: TNXJSONBoolean read FcodeActionProvider write FcodeActionProvider;
    property executeCommandProvider: TNXJSONValue read FexecuteCommandProvider write FexecuteCommandProvider;
    property renameProvider: TNXJSONValue read FrenameProvider write FrenameProvider;
    property experimental: TNXJSONValue read Fexperimental write Fexperimental;
  end;

  TNXLSInitializeResultValue = class(TNXJSONObject)
  private
    Fcapabilities: TNXLSServerCapabilities;
    FserverInfo: TNXLSServerInfo;
  published
    property capabilities: TNXLSServerCapabilities read Fcapabilities write Fcapabilities;
    property serverInfo: TNXLSServerInfo read FserverInfo write FserverInfo;
  end;

  TNXLSInitializeResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSLocationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSTextEditArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSLocationResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSLocationArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCallHierarchyItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSCallHierarchyIncomingCall = class(TNXJSONObject)
  private
    Ffrom: TNXLSCallHierarchyItem;
    FfromRanges: TNXJSONArray;
  published
    property from: TNXLSCallHierarchyItem read Ffrom write Ffrom;
    property fromRanges: TNXJSONArray read FfromRanges write FfromRanges;
  end;

  TNXLSCallHierarchyIncomingCallArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSCallHierarchyOutgoingCall = class(TNXJSONObject)
  private
    Fto: TNXLSCallHierarchyItem;
    FfromRanges: TNXJSONArray;
  published
    property &to: TNXLSCallHierarchyItem read Fto write Fto;
    property fromRanges: TNXJSONArray read FfromRanges write FfromRanges;
  end;

  TNXLSCallHierarchyOutgoingCallArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSTypeHierarchyItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSCallHierarchyItemArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCallHierarchyIncomingCallArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCallHierarchyOutgoingCallArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSTypeHierarchyItemArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSDocumentHighlight = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    Fkind: TNXJSONInteger;
  published
    property range: TNXLSRange read Frange write Frange;
    property kind: TNXJSONInteger read Fkind write Fkind;
  end;

  TNXLSDocumentHighlightArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSDocumentLinkArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSMarkupContent = class(TNXJSONObject)
  private
    Fkind: TNXJSONString;
    Fvalue: TNXJSONString;
  published
    property kind: TNXJSONString read Fkind write Fkind;
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXLSHover = class(TNXJSONObject)
  private
    Fcontents: TNXJSONValue;
    Frange: TNXLSRange;
  published
    property contents: TNXJSONValue read Fcontents write Fcontents;
    property range: TNXLSRange read Frange write Frange;
  end;

  TNXLSCodeLensArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSFoldingRange = class(TNXJSONObject)
  private
    FstartLine: TNXJSONInteger;
    FstartCharacter: TNXJSONInteger;
    FendLine: TNXJSONInteger;
    FendCharacter: TNXJSONInteger;
    Fkind: TNXJSONString;
    FcollapsedText: TNXJSONString;
  published
    property startLine: TNXJSONInteger read FstartLine write FstartLine;
    property startCharacter: TNXJSONInteger read FstartCharacter write FstartCharacter;
    property endLine: TNXJSONInteger read FendLine write FendLine;
    property endCharacter: TNXJSONInteger read FendCharacter write FendCharacter;
    property kind: TNXJSONString read Fkind write Fkind;
    property collapsedText: TNXJSONString read FcollapsedText write FcollapsedText;
  end;

  TNXLSFoldingRangeArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSSelectionRange = class;

  TNXLSSelectionRangeArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSSelectionRange = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    Fparent: TNXLSSelectionRange;
  published
    property range: TNXLSRange read Frange write Frange;
    property parent: TNXLSSelectionRange read Fparent write Fparent;
  end;

  TNXLSSymbolInformation = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Fkind: TNXJSONInteger;
    Ftags: TNXJSONIntegerArray;
    Fdeprecated: TNXJSONBoolean;
    Flocation: TNXLSLocation;
    FcontainerName: TNXJSONString;
  published
    property name: TNXJSONString read Fname write Fname;
    property kind: TNXJSONInteger read Fkind write Fkind;
    property tags: TNXJSONIntegerArray read Ftags write Ftags;
    property deprecated: TNXJSONBoolean read Fdeprecated write Fdeprecated;
    property location: TNXLSLocation read Flocation write Flocation;
    property containerName: TNXJSONString read FcontainerName write FcontainerName;
  end;

  TNXLSDocumentSymbol = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Fdetail: TNXJSONString;
    Fkind: TNXJSONInteger;
    Ftags: TNXJSONIntegerArray;
    Fdeprecated: TNXJSONBoolean;
    Frange: TNXLSRange;
    FselectionRange: TNXLSRange;
    Fchildren: TNXJSONArray;
  published
    property name: TNXJSONString read Fname write Fname;
    property detail: TNXJSONString read Fdetail write Fdetail;
    property kind: TNXJSONInteger read Fkind write Fkind;
    property tags: TNXJSONIntegerArray read Ftags write Ftags;
    property deprecated: TNXJSONBoolean read Fdeprecated write Fdeprecated;
    property range: TNXLSRange read Frange write Frange;
    property selectionRange: TNXLSRange read FselectionRange write FselectionRange;
    property children: TNXJSONArray read Fchildren write Fchildren;
  end;

  TNXLSSemanticTokens = class(TNXJSONObject)
  private
    FresultId: TNXJSONString;
    Fdata: TNXJSONIntegerArray;
  published
    property resultId: TNXJSONString read FresultId write FresultId;
    property data: TNXJSONIntegerArray read Fdata write Fdata;
  end;

  TNXLSSemanticTokensDelta = class(TNXJSONObject)
  private
    FresultId: TNXJSONString;
    Fedits: TNXJSONArray;
  published
    property resultId: TNXJSONString read FresultId write FresultId;
    property edits: TNXJSONArray read Fedits write Fedits;
  end;

  TNXLSInlineValueArray = class(TNXJSONArray)
  end;

  TNXLSInlayHintArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSMoniker = class(TNXJSONObject)
  private
    Fscheme: TNXJSONString;
    Fidentifier: TNXJSONString;
    Funique: TNXJSONInteger;
    Fkind: TNXJSONString;
  published
    property scheme: TNXJSONString read Fscheme write Fscheme;
    property identifier: TNXJSONString read Fidentifier write Fidentifier;
    property unique: TNXJSONInteger read Funique write Funique;
    property kind: TNXJSONString read Fkind write Fkind;
  end;

  TNXLSMonikerArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSCompletionItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSCodeActionArray = class(TNXJSONArray)
  end;

  TNXLSColorInformation = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    Fcolor: TNXLSColor;
  published
    property range: TNXLSRange read Frange write Frange;
    property color: TNXLSColor read Fcolor write Fcolor;
  end;

  TNXLSColorInformationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSColorPresentation = class(TNXJSONObject)
  private
    Flabel: TNXJSONString;
    FtextEdit: TNXLSTextEdit;
    FadditionalTextEdits: TNXLSTextEditArray;
  published
    property &label: TNXJSONString read Flabel write Flabel;
    property textEdit: TNXLSTextEdit read FtextEdit write FtextEdit;
    property additionalTextEdits: TNXLSTextEditArray read FadditionalTextEdits write FadditionalTextEdits;
  end;

  TNXLSColorPresentationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSPrepareRenamePlaceholder = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    Fplaceholder: TNXJSONString;
  published
    property range: TNXLSRange read Frange write Frange;
    property placeholder: TNXJSONString read Fplaceholder write Fplaceholder;
  end;

  TNXLSLinkedEditingRanges = class(TNXJSONObject)
  private
    Franges: TNXJSONArray;
    FwordPattern: TNXJSONString;
  published
    property ranges: TNXJSONArray read Franges write Franges;
    property wordPattern: TNXJSONString read FwordPattern write FwordPattern;
  end;

  TNXLSFullDocumentDiagnosticReport = class(TNXJSONObject)
  private
    Fkind: TNXJSONString;
    FresultId: TNXJSONString;
    Fitems: TNXLSDiagnosticArray;
  published
    property kind: TNXJSONString read Fkind write Fkind;
    property resultId: TNXJSONString read FresultId write FresultId;
    property items: TNXLSDiagnosticArray read Fitems write Fitems;
  end;

  TNXLSWorkspaceDocumentDiagnosticReport = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fversion: TNXJSONValue;
    Fkind: TNXJSONString;
    FresultId: TNXJSONString;
    Fitems: TNXLSDiagnosticArray;
  published
    property uri: TNXJSONString read Furi write Furi;
    property version: TNXJSONValue read Fversion write Fversion;
    property kind: TNXJSONString read Fkind write Fkind;
    property resultId: TNXJSONString read FresultId write FresultId;
    property items: TNXLSDiagnosticArray read Fitems write Fitems;
  end;

  TNXLSWorkspaceDocumentDiagnosticReportArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSWorkspaceDiagnosticReport = class(TNXJSONObject)
  private
    Fitems: TNXLSWorkspaceDocumentDiagnosticReportArray;
  published
    property items: TNXLSWorkspaceDocumentDiagnosticReportArray read Fitems write Fitems;
  end;

  TNXLSConfigurationArray = class(TNXJSONArray)
  end;

  TNXLSApplyWorkspaceEditResultValue = class(TNXJSONObject)
  private
    Fapplied: TNXJSONBoolean;
    FfailureReason: TNXJSONString;
    FfailedChange: TNXJSONInteger;
  published
    property applied: TNXJSONBoolean read Fapplied write Fapplied;
    property failureReason: TNXJSONString read FfailureReason write FfailureReason;
    property failedChange: TNXJSONInteger read FfailedChange write FfailedChange;
  end;

  TNXLSShowDocumentResultValue = class(TNXJSONObject)
  private
    Fsuccess: TNXJSONBoolean;
  published
    property success: TNXJSONBoolean read Fsuccess write Fsuccess;
  end;

  TNXLSDocumentHighlightArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSDocumentLinkArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSDocumentLinkResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSHoverResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCodeLensArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCodeLensResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSFoldingRangeArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSSelectionRangeArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSDocumentSymbolArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSSemanticTokensResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSSemanticTokensDeltaResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSInlineValueArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSInlayHintArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSInlayHintResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSMonikerArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCompletionResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCompletionItemResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSSignatureHelpResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCodeActionArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCodeActionResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSColorInformationArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSColorPresentationArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSWorkspaceEditResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSPrepareRenameResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSLinkedEditingRangesResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSDocumentDiagnosticReportResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDiagnosticReportResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSWorkspaceSymbolArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSWorkspaceSymbolResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSConfigurationArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSWorkspaceFolderArrayResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSCommandResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSApplyWorkspaceEditResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSMessageActionItemResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

  TNXLSShowDocumentResult = class(TNXLSProtocolResult)
  public
    class function CreateValue: TNXJSONValue; override;
  end;

implementation

uses
  fpjson,
  utNXLSCommandNames;

procedure MarkAssigned(AValue: TNXJSONValue);
begin
  if AValue <> nil then
    AValue.Assigned := True;
end;

procedure LoadRawJSON(AValue: TNXJSONValue; AData: TJSONData);
begin
  try
    AValue.FromJSONData(AData);
  finally
    AData.Free;
  end;
end;

function StringArrayJSON(const AValues: array of string): TJSONArray;
var
  lIdx: Integer;
begin
  Result := TJSONArray.Create;
  for lIdx := Low(AValues) to High(AValues) do
    Result.Add(AValues[lIdx]);
end;

function EmptyArray(AClass: TNXJSONValueClass): TNXJSONValue;
begin
  Result := AClass.Create;
  Result.Assigned := True;
end;

class function TNXLSProtocolResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSNullResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSInitializeResult.CreateValue: TNXJSONValue;
var
  lResult: TNXLSInitializeResultValue;
  lWorkspace: TJSONObject;
  lWorkspaceFolders: TJSONObject;
  lCompletionProvider: TJSONObject;
  lSignatureHelpProvider: TJSONObject;
  lExecuteCommandProvider: TJSONObject;
  lRenameProvider: TJSONObject;
begin
  lResult := TNXLSInitializeResultValue.Create;
  lResult.capabilities.textDocumentSync.openClose.Value := True;
  lResult.capabilities.textDocumentSync.change.Value := 1;
  lResult.capabilities.textDocumentSync.save.Value := True;
  MarkAssigned(lResult.capabilities.textDocumentSync);

  lWorkspaceFolders := TJSONObject.Create;
  lWorkspaceFolders.Add('supported', True);
  lWorkspaceFolders.Add('changeNotifications', True);
  lWorkspace := TJSONObject.Create;
  lWorkspace.Add('workspaceFolders', lWorkspaceFolders);
  LoadRawJSON(lResult.capabilities.workspace, lWorkspace);

  lCompletionProvider := TJSONObject.Create;
  lCompletionProvider.Add('triggerCharacters', StringArrayJSON(['.', '^']));
  LoadRawJSON(lResult.capabilities.completionProvider, lCompletionProvider);

  lSignatureHelpProvider := TJSONObject.Create;
  lSignatureHelpProvider.Add('triggerCharacters', StringArrayJSON(['(', ')', ',']));
  LoadRawJSON(lResult.capabilities.signatureHelpProvider, lSignatureHelpProvider);

  lRenameProvider := TJSONObject.Create;
  lRenameProvider.Add('prepareProvider', True);
  LoadRawJSON(lResult.capabilities.renameProvider, lRenameProvider);

  lExecuteCommandProvider := TJSONObject.Create;
  lExecuteCommandProvider.Add('commands', StringArrayJSON([
    cNXLSCommandCompleteCode,
    cNXLSCommandInvertAssignment,
    cNXLSCommandRemoveEmptyMethods,
    cNXLSCommandRemoveUnusedUnits
  ]));
  LoadRawJSON(lResult.capabilities.executeCommandProvider, lExecuteCommandProvider);

  lResult.capabilities.hoverProvider.Value := True;
  lResult.capabilities.declarationProvider.Value := True;
  lResult.capabilities.definitionProvider.Value := True;
  lResult.capabilities.implementationProvider.Value := True;
  lResult.capabilities.referencesProvider.Value := True;
  lResult.capabilities.documentHighlightProvider.Value := True;
  lResult.capabilities.documentSymbolProvider.Value := True;
  lResult.capabilities.workspaceSymbolProvider.Value := True;
  lResult.capabilities.codeActionProvider.Value := True;

  MarkAssigned(lResult.capabilities);
  MarkAssigned(lResult);
  Result := lResult;
end;

class function TNXLSLocationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSLocation;
end;

class function TNXLSCallHierarchyItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyItem;
end;

class function TNXLSCallHierarchyIncomingCallArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyIncomingCall;
end;

class function TNXLSCallHierarchyOutgoingCallArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyOutgoingCall;
end;

class function TNXLSTypeHierarchyItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchyItem;
end;

class function TNXLSDocumentHighlightArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentHighlight;
end;

class function TNXLSDocumentLinkArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentLink;
end;

class function TNXLSCodeLensArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSCodeLens;
end;

class function TNXLSFoldingRangeArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSFoldingRange;
end;

class function TNXLSSelectionRangeArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSSelectionRange;
end;

class function TNXLSInlayHintArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSInlayHint;
end;

class function TNXLSMonikerArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSMoniker;
end;

class function TNXLSCompletionItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSCompletionItem;
end;

class function TNXLSColorInformationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSColorInformation;
end;

class function TNXLSColorPresentationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSColorPresentation;
end;

class function TNXLSWorkspaceDocumentDiagnosticReportArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceDocumentDiagnosticReport;
end;

class function TNXLSTextEditArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSTextEditArray);
end;

class function TNXLSLocationResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSLocationArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSLocationArray);
end;

class function TNXLSCallHierarchyItemArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSCallHierarchyItemArray);
end;

class function TNXLSCallHierarchyIncomingCallArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSCallHierarchyIncomingCallArray);
end;

class function TNXLSCallHierarchyOutgoingCallArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSCallHierarchyOutgoingCallArray);
end;

class function TNXLSTypeHierarchyItemArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSTypeHierarchyItemArray);
end;

class function TNXLSDocumentHighlightArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSDocumentHighlightArray);
end;

class function TNXLSDocumentLinkArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSDocumentLinkArray);
end;

class function TNXLSDocumentLinkResult.CreateValue: TNXJSONValue;
begin
  Result := TNXLSDocumentLink.Create;
  MarkAssigned(Result);
end;

class function TNXLSHoverResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSCodeLensArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSCodeLensArray);
end;

class function TNXLSCodeLensResult.CreateValue: TNXJSONValue;
begin
  Result := TNXLSCodeLens.Create;
  MarkAssigned(Result);
end;

class function TNXLSFoldingRangeArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSFoldingRangeArray);
end;

class function TNXLSSelectionRangeArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSSelectionRangeArray);
end;

class function TNXLSDocumentSymbolArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXJSONArray);
end;

class function TNXLSSemanticTokensResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSSemanticTokensDeltaResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSInlineValueArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSInlineValueArray);
end;

class function TNXLSInlayHintArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSInlayHintArray);
end;

class function TNXLSInlayHintResult.CreateValue: TNXJSONValue;
begin
  Result := TNXLSInlayHint.Create;
  MarkAssigned(Result);
end;

class function TNXLSMonikerArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSMonikerArray);
end;

class function TNXLSCompletionResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSCompletionItemArray);
end;

class function TNXLSCompletionItemResult.CreateValue: TNXJSONValue;
begin
  Result := TNXLSCompletionItem.Create;
  MarkAssigned(Result);
end;

class function TNXLSSignatureHelpResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSCodeActionArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSCodeActionArray);
end;

class function TNXLSCodeActionResult.CreateValue: TNXJSONValue;
begin
  Result := TNXLSCodeAction.Create;
  MarkAssigned(Result);
end;

class function TNXLSColorInformationArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSColorInformationArray);
end;

class function TNXLSColorPresentationArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSColorPresentationArray);
end;

class function TNXLSWorkspaceEditResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSPrepareRenameResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSLinkedEditingRangesResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSDocumentDiagnosticReportResult.CreateValue: TNXJSONValue;
var
  lResult: TNXLSFullDocumentDiagnosticReport;
begin
  lResult := TNXLSFullDocumentDiagnosticReport.Create;
  lResult.kind.Value := 'full';
  lResult.items.Assigned := True;
  MarkAssigned(lResult);
  Result := lResult;
end;

class function TNXLSWorkspaceDiagnosticReportResult.CreateValue: TNXJSONValue;
var
  lResult: TNXLSWorkspaceDiagnosticReport;
begin
  lResult := TNXLSWorkspaceDiagnosticReport.Create;
  lResult.items.Assigned := True;
  MarkAssigned(lResult);
  Result := lResult;
end;

class function TNXLSWorkspaceSymbolArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXJSONArray);
end;

class function TNXLSWorkspaceSymbolResult.CreateValue: TNXJSONValue;
begin
  Result := TNXLSWorkspaceSymbol.Create;
  MarkAssigned(Result);
end;

class function TNXLSConfigurationArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSConfigurationArray);
end;

class function TNXLSWorkspaceFolderArrayResult.CreateValue: TNXJSONValue;
begin
  Result := EmptyArray(TNXLSWorkspaceFolderArray);
end;

class function TNXLSCommandResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSApplyWorkspaceEditResult.CreateValue: TNXJSONValue;
var
  lResult: TNXLSApplyWorkspaceEditResultValue;
begin
  lResult := TNXLSApplyWorkspaceEditResultValue.Create;
  lResult.applied.Value := False;
  MarkAssigned(lResult);
  Result := lResult;
end;

class function TNXLSMessageActionItemResult.CreateValue: TNXJSONValue;
begin
  Result := TNXJSONNull.Create;
end;

class function TNXLSShowDocumentResult.CreateValue: TNXJSONValue;
var
  lResult: TNXLSShowDocumentResultValue;
begin
  lResult := TNXLSShowDocumentResultValue.Create;
  lResult.success.Value := False;
  MarkAssigned(lResult);
  Result := lResult;
end;

end.
