unit obNXLSProtocolObjects;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams;

type
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

  TNXLSWorkspaceFoldersServerCapabilities = class(TNXJSONObject)
  private
    Fsupported: TNXJSONBoolean;
    FchangeNotifications: TNXJSONBoolean;
  published
    property supported: TNXJSONBoolean read Fsupported write Fsupported;
    property changeNotifications: TNXJSONBoolean read FchangeNotifications write FchangeNotifications;
  end;

  TNXLSWorkspaceServerCapabilities = class(TNXJSONObject)
  private
    FworkspaceFolders: TNXLSWorkspaceFoldersServerCapabilities;
  published
    property workspaceFolders: TNXLSWorkspaceFoldersServerCapabilities read FworkspaceFolders write FworkspaceFolders;
  end;

  TNXLSCompletionOptions = class(TNXJSONObject)
  private
    FtriggerCharacters: TNXJSONStringArray;
  published
    property triggerCharacters: TNXJSONStringArray read FtriggerCharacters write FtriggerCharacters;
  end;

  TNXLSSignatureHelpOptions = class(TNXJSONObject)
  private
    FtriggerCharacters: TNXJSONStringArray;
  published
    property triggerCharacters: TNXJSONStringArray read FtriggerCharacters write FtriggerCharacters;
  end;

  TNXLSRenameOptions = class(TNXJSONObject)
  private
    FprepareProvider: TNXJSONBoolean;
  published
    property prepareProvider: TNXJSONBoolean read FprepareProvider write FprepareProvider;
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
    Fworkspace: TNXLSWorkspaceServerCapabilities;
    FcompletionProvider: TNXLSCompletionOptions;
    FhoverProvider: TNXJSONBoolean;
    FdeclarationProvider: TNXJSONBoolean;
    FdefinitionProvider: TNXJSONBoolean;
    FimplementationProvider: TNXJSONBoolean;
    FreferencesProvider: TNXJSONBoolean;
    FdocumentHighlightProvider: TNXJSONBoolean;
    FdocumentSymbolProvider: TNXJSONBoolean;
    FworkspaceSymbolProvider: TNXJSONBoolean;
    FsignatureHelpProvider: TNXLSSignatureHelpOptions;
    FcodeActionProvider: TNXJSONBoolean;
    FrenameProvider: TNXLSRenameOptions;
    Fexperimental: TNXJSONRPCUnknown;
  published
    property textDocumentSync: TNXLSTextDocumentSyncOptions read FtextDocumentSync write FtextDocumentSync;
    property workspace: TNXLSWorkspaceServerCapabilities read Fworkspace write Fworkspace;
    property completionProvider: TNXLSCompletionOptions read FcompletionProvider write FcompletionProvider;
    property hoverProvider: TNXJSONBoolean read FhoverProvider write FhoverProvider;
    property declarationProvider: TNXJSONBoolean read FdeclarationProvider write FdeclarationProvider;
    property definitionProvider: TNXJSONBoolean read FdefinitionProvider write FdefinitionProvider;
    property implementationProvider: TNXJSONBoolean read FimplementationProvider write FimplementationProvider;
    property referencesProvider: TNXJSONBoolean read FreferencesProvider write FreferencesProvider;
    property documentHighlightProvider: TNXJSONBoolean read FdocumentHighlightProvider write FdocumentHighlightProvider;
    property documentSymbolProvider: TNXJSONBoolean read FdocumentSymbolProvider write FdocumentSymbolProvider;
    property workspaceSymbolProvider: TNXJSONBoolean read FworkspaceSymbolProvider write FworkspaceSymbolProvider;
    property signatureHelpProvider: TNXLSSignatureHelpOptions read FsignatureHelpProvider write FsignatureHelpProvider;
    property codeActionProvider: TNXJSONBoolean read FcodeActionProvider write FcodeActionProvider;
    property renameProvider: TNXLSRenameOptions read FrenameProvider write FrenameProvider;
    property experimental: TNXJSONRPCUnknown read Fexperimental write Fexperimental;
  end;

  TNXLSInitializeResultValue = class(TNXJSONObject)
  private
    Fcapabilities: TNXLSServerCapabilities;
    FserverInfo: TNXLSServerInfo;
  published
    property capabilities: TNXLSServerCapabilities read Fcapabilities write Fcapabilities;
    property serverInfo: TNXLSServerInfo read FserverInfo write FserverInfo;
  end;

  TNXLSProjectField = class(TNXJSONObject)
  private
    Fid: TNXJSONString;
    Flabel: TNXJSONString;
    Ftype: TNXJSONString;
    Fvalue: TNXJSONString;
    Frequired: TNXJSONBoolean;
    Fdescription: TNXJSONString;
    FbrowseLabel: TNXJSONString;
  published
    property id: TNXJSONString read Fid write Fid;
    property &label: TNXJSONString read Flabel write Flabel;
    property &type: TNXJSONString read Ftype write Ftype;
    property value: TNXJSONString read Fvalue write Fvalue;
    property required: TNXJSONBoolean read Frequired write Frequired;
    property description: TNXJSONString read Fdescription write Fdescription;
    property browseLabel: TNXJSONString read FbrowseLabel write FbrowseLabel;
  end;

  TNXLSProjectFieldArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectRequestValue = class(TNXJSONObject)
  private
    FprojectName: TNXJSONString;
    FtargetDir: TNXJSONString;
  published
    property projectName: TNXJSONString read FprojectName write FprojectName;
    property targetDir: TNXJSONString read FtargetDir write FtargetDir;
  end;

  TNXLSProjectMessage = class(TNXJSONObject)
  private
    Fseverity: TNXJSONString;
    Ftext: TNXJSONString;
  published
    property severity: TNXJSONString read Fseverity write Fseverity;
    property text: TNXJSONString read Ftext write Ftext;
  end;

  TNXLSProjectMessageArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectOutput = class(TNXJSONObject)
  private
    Flabel: TNXJSONString;
    Fpath: TNXJSONString;
  published
    property &label: TNXJSONString read Flabel write Flabel;
    property path: TNXJSONString read Fpath write Fpath;
  end;

  TNXLSProjectOutputArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectDetail = class(TNXJSONObject)
  private
    Flabel: TNXJSONString;
    Fvalue: TNXJSONString;
  published
    property &label: TNXJSONString read Flabel write Flabel;
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXLSProjectDetailArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectFile = class(TNXJSONObject)
  private
    Fpath: TNXJSONString;
    Fcontent: TNXJSONString;
  published
    property path: TNXJSONString read Fpath write Fpath;
    property content: TNXJSONString read Fcontent write Fcontent;
  end;

  TNXLSProjectFileArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSProjectCreateWizardResult = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Frequest: TNXLSProjectRequestValue;
    Ffields: TNXLSProjectFieldArray;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property request: TNXLSProjectRequestValue read Frequest write Frequest;
    property fields: TNXLSProjectFieldArray read Ffields write Ffields;
  end;

  TNXLSProjectPlanCreateResult = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Fsummary: TNXJSONString;
    FcanExecute: TNXJSONBoolean;
    Fmessages: TNXLSProjectMessageArray;
    Foutputs: TNXLSProjectOutputArray;
    Fdetails: TNXLSProjectDetailArray;
    Ffields: TNXLSProjectFieldArray;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property summary: TNXJSONString read Fsummary write Fsummary;
    property canExecute: TNXJSONBoolean read FcanExecute write FcanExecute;
    property messages: TNXLSProjectMessageArray read Fmessages write Fmessages;
    property outputs: TNXLSProjectOutputArray read Foutputs write Foutputs;
    property details: TNXLSProjectDetailArray read Fdetails write Fdetails;
    property fields: TNXLSProjectFieldArray read Ffields write Ffields;
  end;

  TNXLSProjectCreateResult = class(TNXJSONObject)
  private
    Fmessage: TNXJSONString;
    Ffiles: TNXLSProjectFileArray;
  published
    property message: TNXJSONString read Fmessage write Fmessage;
    property files: TNXLSProjectFileArray read Ffiles write Ffiles;
  end;

  TNXLSLocationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSCallHierarchyItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSTypeHierarchyItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSDocumentLinkArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSHover = class(TNXJSONObject)
  private
    Fcontents: TNXLSMarkupContent;
    Frange: TNXLSRange;
  published
    property contents: TNXLSMarkupContent read Fcontents write Fcontents;
    property range: TNXLSRange read Frange write Frange;
  end;

  TNXLSCodeLensArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSSelectionRange = class;

  TNXLSSelectionRangeArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSCompletionItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    class function ItemClass: TNXJSONRPCValueClass; override;
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
    Fversion: TNXJSONInteger;
    Fkind: TNXJSONString;
    FresultId: TNXJSONString;
    Fitems: TNXLSDiagnosticArray;
  public
    constructor Create; override;
  published
    property uri: TNXJSONString read Furi write Furi;
    property version: TNXJSONInteger read Fversion write Fversion;
    property kind: TNXJSONString read Fkind write Fkind;
    property resultId: TNXJSONString read FresultId write FresultId;
    property items: TNXLSDiagnosticArray read Fitems write Fitems;
  end;

  TNXLSWorkspaceDocumentDiagnosticReportArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSWorkspaceDiagnosticReport = class(TNXJSONObject)
  private
    Fitems: TNXLSWorkspaceDocumentDiagnosticReportArray;
  published
    property items: TNXLSWorkspaceDocumentDiagnosticReportArray read Fitems write Fitems;
  end;

  TNXLSConfigurationArray = class(TNXJSONArray)
  end;

  TNXLSApplyWorkspaceEditResultValue = class(TNXJSONRPCCommandResult)
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

implementation

constructor TNXLSWorkspaceDocumentDiagnosticReport.Create;
begin
  inherited Create;
  version.AcceptsNull := True;
end;

class function TNXLSProjectFieldArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectField;
end;

class function TNXLSProjectMessageArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectMessage;
end;

class function TNXLSProjectOutputArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectOutput;
end;

class function TNXLSProjectDetailArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectDetail;
end;

class function TNXLSProjectFileArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSProjectFile;
end;

class function TNXLSLocationArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSLocation;
end;

class function TNXLSCallHierarchyItemArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSCallHierarchyItem;
end;

class function TNXLSCallHierarchyIncomingCallArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSCallHierarchyIncomingCall;
end;

class function TNXLSCallHierarchyOutgoingCallArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSCallHierarchyOutgoingCall;
end;

class function TNXLSTypeHierarchyItemArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSTypeHierarchyItem;
end;

class function TNXLSDocumentHighlightArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSDocumentHighlight;
end;

class function TNXLSDocumentLinkArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSDocumentLink;
end;

class function TNXLSCodeLensArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSCodeLens;
end;

class function TNXLSFoldingRangeArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSFoldingRange;
end;

class function TNXLSSelectionRangeArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSSelectionRange;
end;

class function TNXLSInlayHintArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSInlayHint;
end;

class function TNXLSMonikerArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSMoniker;
end;

class function TNXLSCompletionItemArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSCompletionItem;
end;

class function TNXLSColorInformationArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSColorInformation;
end;

class function TNXLSColorPresentationArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSColorPresentation;
end;

class function TNXLSWorkspaceDocumentDiagnosticReportArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSWorkspaceDocumentDiagnosticReport;
end;

end.
