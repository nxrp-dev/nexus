unit obNXLSProtocolParams;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase;

type
  TNXLSCompletionContext = class;
  TNXLSSignatureHelpContext = class;
  TNXLSInlineValueContext = class;
  TNXLSWorkspaceEdit = class;
  TNXLSMessageActionItemArray = class;
  TNXLSCompletionItemLabelDetails = class;
  TNXLSCodeActionDisabled = class;

  TNXJSONStringArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXJSONIntegerArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSPositionArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSTextDocumentItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSTextDocumentIdentifierArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSClientInfo = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Fversion: TNXJSONString;
  published
    property name: TNXJSONString read Fname write Fname;
    property version: TNXJSONString read Fversion write Fversion;
  end;

  TNXLSWorkspaceFolder = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fname: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
    property name: TNXJSONString read Fname write Fname;
  end;

  TNXLSWorkspaceFolderArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSClientCapabilities = class(TNXJSONObject)
  private
    Fworkspace: TNXJSONObject;
    FtextDocument: TNXJSONObject;
    FnotebookDocument: TNXJSONObject;
    Fwindow: TNXJSONObject;
    Fgeneral: TNXJSONObject;
    Fexperimental: TNXJSONValue;
  published
    property workspace: TNXJSONObject read Fworkspace write Fworkspace;
    property textDocument: TNXJSONObject read FtextDocument write FtextDocument;
    property notebookDocument: TNXJSONObject read FnotebookDocument write FnotebookDocument;
    property window: TNXJSONObject read Fwindow write Fwindow;
    property general: TNXJSONObject read Fgeneral write Fgeneral;
    property experimental: TNXJSONValue read Fexperimental write Fexperimental;
  end;

  TNXLSInitializeParams = class(TNXJSONObject)
  private
    FprocessId: TNXJSONValue;
    FclientInfo: TNXLSClientInfo;
    Flocale: TNXJSONString;
    FrootPath: TNXJSONValue;
    FrootUri: TNXJSONValue;
    FinitializationOptions: TNXJSONValue;
    Fcapabilities: TNXLSClientCapabilities;
    Ftrace: TNXJSONString;
    FworkspaceFolders: TNXLSWorkspaceFolderArray;
  published
    property processId: TNXJSONValue read FprocessId write FprocessId;
    property clientInfo: TNXLSClientInfo read FclientInfo write FclientInfo;
    property locale: TNXJSONString read Flocale write Flocale;
    property rootPath: TNXJSONValue read FrootPath write FrootPath;
    property rootUri: TNXJSONValue read FrootUri write FrootUri;
    property initializationOptions: TNXJSONValue read FinitializationOptions write FinitializationOptions;
    property capabilities: TNXLSClientCapabilities read Fcapabilities write Fcapabilities;
    property trace: TNXJSONString read Ftrace write Ftrace;
    property workspaceFolders: TNXLSWorkspaceFolderArray read FworkspaceFolders write FworkspaceFolders;
  end;

  TNXLSInitializedParams = class(TNXJSONObject)
  end;

  TNXLSCancelParams = class(TNXJSONObject)
  private
    Fid: TNXJSONValue;
  published
    property id: TNXJSONValue read Fid write Fid;
  end;

  TNXLSProgressParams = class(TNXJSONObject)
  private
    Ftoken: TNXJSONValue;
    Fvalue: TNXJSONValue;
  published
    property token: TNXJSONValue read Ftoken write Ftoken;
    property value: TNXJSONValue read Fvalue write Fvalue;
  end;

  TNXLSSetTraceParams = class(TNXJSONObject)
  private
    Fvalue: TNXJSONString;
  published
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXLSLogTraceParams = class(TNXJSONObject)
  private
    Fmessage: TNXJSONString;
    Fverbose: TNXJSONString;
  published
    property message: TNXJSONString read Fmessage write Fmessage;
    property verbose: TNXJSONString read Fverbose write Fverbose;
  end;

  TNXLSFormattingOptions = class(TNXJSONObject)
  private
    FtabSize: TNXJSONInteger;
    FinsertSpaces: TNXJSONBoolean;
    FtrimTrailingWhitespace: TNXJSONBoolean;
    FinsertFinalNewline: TNXJSONBoolean;
    FtrimFinalNewlines: TNXJSONBoolean;
  published
    property tabSize: TNXJSONInteger read FtabSize write FtabSize;
    property insertSpaces: TNXJSONBoolean read FinsertSpaces write FinsertSpaces;
    property trimTrailingWhitespace: TNXJSONBoolean read FtrimTrailingWhitespace write FtrimTrailingWhitespace;
    property insertFinalNewline: TNXJSONBoolean read FinsertFinalNewline write FinsertFinalNewline;
    property trimFinalNewlines: TNXJSONBoolean read FtrimFinalNewlines write FtrimFinalNewlines;
  end;

  TNXLSDocumentFormattingParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
    Foptions: TNXLSFormattingOptions;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
    property options: TNXLSFormattingOptions read Foptions write Foptions;
  end;

  TNXLSDocumentRangeFormattingParams = class(TNXLSDocumentFormattingParams)
  private
    Frange: TNXLSRange;
  published
    property range: TNXLSRange read Frange write Frange;
  end;

  TNXLSDocumentOnTypeFormattingParams = class(TNXLSTextDocumentPositionParams)
  private
    Fch: TNXJSONString;
    Foptions: TNXLSFormattingOptions;
  published
    property ch: TNXJSONString read Fch write Fch;
    property options: TNXLSFormattingOptions read Foptions write Foptions;
  end;

  TNXLSReferenceContext = class(TNXJSONObject)
  private
    FincludeDeclaration: TNXJSONBoolean;
  published
    property includeDeclaration: TNXJSONBoolean read FincludeDeclaration write FincludeDeclaration;
  end;

  TNXLSReferenceParams = class(TNXLSTextDocumentPositionParams)
  private
    Fcontext: TNXLSReferenceContext;
  published
    property context: TNXLSReferenceContext read Fcontext write Fcontext;
  end;

  TNXLSCommand = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Fcommand: TNXJSONString;
    Farguments: TNXJSONArray;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property command: TNXJSONString read Fcommand write Fcommand;
    property arguments: TNXJSONArray read Farguments write Farguments;
  end;

  TNXLSCallHierarchyItem = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Fkind: TNXJSONInteger;
    Ftags: TNXJSONIntegerArray;
    Fdetail: TNXJSONString;
    Furi: TNXJSONString;
    Frange: TNXLSRange;
    FselectionRange: TNXLSRange;
    Fdata: TNXJSONValue;
  published
    property name: TNXJSONString read Fname write Fname;
    property kind: TNXJSONInteger read Fkind write Fkind;
    property tags: TNXJSONIntegerArray read Ftags write Ftags;
    property detail: TNXJSONString read Fdetail write Fdetail;
    property uri: TNXJSONString read Furi write Furi;
    property range: TNXLSRange read Frange write Frange;
    property selectionRange: TNXLSRange read FselectionRange write FselectionRange;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSTypeHierarchyItem = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Fkind: TNXJSONInteger;
    Ftags: TNXJSONIntegerArray;
    Fdetail: TNXJSONString;
    Furi: TNXJSONString;
    Frange: TNXLSRange;
    FselectionRange: TNXLSRange;
    Fdata: TNXJSONValue;
  published
    property name: TNXJSONString read Fname write Fname;
    property kind: TNXJSONInteger read Fkind write Fkind;
    property tags: TNXJSONIntegerArray read Ftags write Ftags;
    property detail: TNXJSONString read Fdetail write Fdetail;
    property uri: TNXJSONString read Furi write Furi;
    property range: TNXLSRange read Frange write Frange;
    property selectionRange: TNXLSRange read FselectionRange write FselectionRange;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSCallHierarchyIncomingCallsParams = class(TNXJSONObject)
  private
    Fitem: TNXLSCallHierarchyItem;
  published
    property item: TNXLSCallHierarchyItem read Fitem write Fitem;
  end;

  TNXLSCallHierarchyOutgoingCallsParams = class(TNXJSONObject)
  private
    Fitem: TNXLSCallHierarchyItem;
  published
    property item: TNXLSCallHierarchyItem read Fitem write Fitem;
  end;

  TNXLSTypeHierarchySupertypesParams = class(TNXJSONObject)
  private
    Fitem: TNXLSTypeHierarchyItem;
  published
    property item: TNXLSTypeHierarchyItem read Fitem write Fitem;
  end;

  TNXLSTypeHierarchySubtypesParams = class(TNXJSONObject)
  private
    Fitem: TNXLSTypeHierarchyItem;
  published
    property item: TNXLSTypeHierarchyItem read Fitem write Fitem;
  end;

  TNXLSDocumentLinkParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
  end;

  TNXLSCodeLensParams = class(TNXLSDocumentLinkParams)
  end;

  TNXLSFoldingRangeParams = class(TNXLSDocumentLinkParams)
  end;

  TNXLSDocumentSymbolParams = class(TNXLSDocumentLinkParams)
  end;

  TNXLSSemanticTokensParams = class(TNXLSDocumentLinkParams)
  end;

  TNXLSSemanticTokensDeltaParams = class(TNXLSSemanticTokensParams)
  private
    FpreviousResultId: TNXJSONString;
  published
    property previousResultId: TNXJSONString read FpreviousResultId write FpreviousResultId;
  end;

  TNXLSSemanticTokensRangeParams = class(TNXLSSemanticTokensParams)
  private
    Frange: TNXLSRange;
  published
    property range: TNXLSRange read Frange write Frange;
  end;

  TNXLSSelectionRangeParams = class(TNXLSDocumentLinkParams)
  private
    Fpositions: TNXLSPositionArray;
  published
    property positions: TNXLSPositionArray read Fpositions write Fpositions;
  end;

  TNXLSDiagnosticCodeDescription = class(TNXJSONObject)
  private
    Fhref: TNXJSONString;
  published
    property href: TNXJSONString read Fhref write Fhref;
  end;

  TNXLSDiagnosticRelatedInformation = class(TNXJSONObject)
  private
    Flocation: TNXLSLocation;
    Fmessage: TNXJSONString;
  published
    property location: TNXLSLocation read Flocation write Flocation;
    property message: TNXJSONString read Fmessage write Fmessage;
  end;

  TNXLSDiagnosticRelatedInformationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSDiagnostic = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    Fseverity: TNXJSONInteger;
    Fcode: TNXJSONValue;
    FcodeDescription: TNXLSDiagnosticCodeDescription;
    Fsource: TNXJSONString;
    Fmessage: TNXJSONString;
    Ftags: TNXJSONIntegerArray;
    FrelatedInformation: TNXLSDiagnosticRelatedInformationArray;
    Fdata: TNXJSONValue;
  published
    property range: TNXLSRange read Frange write Frange;
    property severity: TNXJSONInteger read Fseverity write Fseverity;
    property code: TNXJSONValue read Fcode write Fcode;
    property codeDescription: TNXLSDiagnosticCodeDescription read FcodeDescription write FcodeDescription;
    property source: TNXJSONString read Fsource write Fsource;
    property message: TNXJSONString read Fmessage write Fmessage;
    property tags: TNXJSONIntegerArray read Ftags write Ftags;
    property relatedInformation: TNXLSDiagnosticRelatedInformationArray read FrelatedInformation write FrelatedInformation;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSDiagnosticArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSCodeActionContext = class(TNXJSONObject)
  private
    Fdiagnostics: TNXLSDiagnosticArray;
    Fonly: TNXJSONStringArray;
    FtriggerKind: TNXJSONInteger;
  published
    property diagnostics: TNXLSDiagnosticArray read Fdiagnostics write Fdiagnostics;
    property only: TNXJSONStringArray read Fonly write Fonly;
    property triggerKind: TNXJSONInteger read FtriggerKind write FtriggerKind;
  end;

  TNXLSCodeActionParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
    Frange: TNXLSRange;
    Fcontext: TNXLSCodeActionContext;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
    property range: TNXLSRange read Frange write Frange;
    property context: TNXLSCodeActionContext read Fcontext write Fcontext;
  end;

  TNXLSDocumentColorParams = class(TNXLSDocumentLinkParams)
  end;

  TNXLSColor = class(TNXJSONObject)
  private
    Fred: TNXJSONFloat;
    Fgreen: TNXJSONFloat;
    Fblue: TNXJSONFloat;
    Falpha: TNXJSONFloat;
  published
    property red: TNXJSONFloat read Fred write Fred;
    property green: TNXJSONFloat read Fgreen write Fgreen;
    property blue: TNXJSONFloat read Fblue write Fblue;
    property alpha: TNXJSONFloat read Falpha write Falpha;
  end;

  TNXLSColorPresentationParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
    Fcolor: TNXLSColor;
    Frange: TNXLSRange;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
    property color: TNXLSColor read Fcolor write Fcolor;
    property range: TNXLSRange read Frange write Frange;
  end;

  TNXLSCompletionParams = class(TNXLSTextDocumentPositionParams)
  private
    Fcontext: TNXLSCompletionContext;
  published
    property context: TNXLSCompletionContext read Fcontext write Fcontext;
  end;

  TNXLSCompletionContext = class(TNXJSONObject)
  private
    FtriggerKind: TNXJSONInteger;
    FtriggerCharacter: TNXJSONString;
  published
    property triggerKind: TNXJSONInteger read FtriggerKind write FtriggerKind;
    property triggerCharacter: TNXJSONString read FtriggerCharacter write FtriggerCharacter;
  end;

  TNXLSParameterInformation = class(TNXJSONObject)
  private
    FLabel: TNXJSONValue;
    Fdocumentation: TNXJSONValue;
  published
    property &label: TNXJSONValue read FLabel write FLabel;
    property documentation: TNXJSONValue read Fdocumentation write Fdocumentation;
  end;

  TNXLSParameterInformationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSSignatureInformation = class(TNXJSONObject)
  private
    FLabel: TNXJSONString;
    Fdocumentation: TNXJSONValue;
    Fparameters: TNXLSParameterInformationArray;
    FactiveParameter: TNXJSONInteger;
  published
    property &label: TNXJSONString read FLabel write FLabel;
    property documentation: TNXJSONValue read Fdocumentation write Fdocumentation;
    property parameters: TNXLSParameterInformationArray read Fparameters write Fparameters;
    property activeParameter: TNXJSONInteger read FactiveParameter write FactiveParameter;
  end;

  TNXLSSignatureInformationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSSignatureHelp = class(TNXJSONObject)
  private
    Fsignatures: TNXLSSignatureInformationArray;
    FactiveSignature: TNXJSONInteger;
    FactiveParameter: TNXJSONInteger;
  published
    property signatures: TNXLSSignatureInformationArray read Fsignatures write Fsignatures;
    property activeSignature: TNXJSONInteger read FactiveSignature write FactiveSignature;
    property activeParameter: TNXJSONInteger read FactiveParameter write FactiveParameter;
  end;

  TNXLSSignatureHelpContext = class(TNXJSONObject)
  private
    FtriggerKind: TNXJSONInteger;
    FtriggerCharacter: TNXJSONString;
    FisRetrigger: TNXJSONBoolean;
    FactiveSignatureHelp: TNXLSSignatureHelp;
  published
    property triggerKind: TNXJSONInteger read FtriggerKind write FtriggerKind;
    property triggerCharacter: TNXJSONString read FtriggerCharacter write FtriggerCharacter;
    property isRetrigger: TNXJSONBoolean read FisRetrigger write FisRetrigger;
    property activeSignatureHelp: TNXLSSignatureHelp read FactiveSignatureHelp write FactiveSignatureHelp;
  end;

  TNXLSSignatureHelpParams = class(TNXLSTextDocumentPositionParams)
  private
    Fcontext: TNXLSSignatureHelpContext;
  published
    property context: TNXLSSignatureHelpContext read Fcontext write Fcontext;
  end;

  TNXLSWorkspaceSymbolParams = class(TNXJSONObject)
  private
    Fquery: TNXJSONString;
  published
    property query: TNXJSONString read Fquery write Fquery;
  end;

  TNXLSConfigurationItem = class(TNXJSONObject)
  private
    FscopeUri: TNXJSONString;
    Fsection: TNXJSONString;
  published
    property scopeUri: TNXJSONString read FscopeUri write FscopeUri;
    property section: TNXJSONString read Fsection write Fsection;
  end;

  TNXLSConfigurationItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSConfigurationParams = class(TNXJSONObject)
  private
    Fitems: TNXLSConfigurationItemArray;
  published
    property items: TNXLSConfigurationItemArray read Fitems write Fitems;
  end;

  TNXLSDidChangeConfigurationParams = class(TNXJSONObject)
  private
    Fsettings: TNXJSONValue;
  published
    property settings: TNXJSONValue read Fsettings write Fsettings;
  end;

  TNXLSRegistration = class(TNXJSONObject)
  private
    Fid: TNXJSONString;
    Fmethod: TNXJSONString;
    FregisterOptions: TNXJSONValue;
  published
    property id: TNXJSONString read Fid write Fid;
    property method: TNXJSONString read Fmethod write Fmethod;
    property registerOptions: TNXJSONValue read FregisterOptions write FregisterOptions;
  end;

  TNXLSRegistrationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSRegistrationParams = class(TNXJSONObject)
  private
    Fregistrations: TNXLSRegistrationArray;
  published
    property registrations: TNXLSRegistrationArray read Fregistrations write Fregistrations;
  end;

  TNXLSUnregistration = class(TNXJSONObject)
  private
    Fid: TNXJSONString;
    Fmethod: TNXJSONString;
  published
    property id: TNXJSONString read Fid write Fid;
    property method: TNXJSONString read Fmethod write Fmethod;
  end;

  TNXLSUnregistrationArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSUnregistrationParams = class(TNXJSONObject)
  private
    Funregisterations: TNXLSUnregistrationArray;
  published
    property unregisterations: TNXLSUnregistrationArray read Funregisterations write Funregisterations;
  end;

  TNXLSFileCreate = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
  end;

  TNXLSFileCreateArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSCreateFilesParams = class(TNXJSONObject)
  private
    Ffiles: TNXLSFileCreateArray;
  published
    property files: TNXLSFileCreateArray read Ffiles write Ffiles;
  end;

  TNXLSFileRename = class(TNXJSONObject)
  private
    FoldUri: TNXJSONString;
    FnewUri: TNXJSONString;
  published
    property oldUri: TNXJSONString read FoldUri write FoldUri;
    property newUri: TNXJSONString read FnewUri write FnewUri;
  end;

  TNXLSFileRenameArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSRenameFilesParams = class(TNXJSONObject)
  private
    Ffiles: TNXLSFileRenameArray;
  published
    property files: TNXLSFileRenameArray read Ffiles write Ffiles;
  end;

  TNXLSFileDelete = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
  end;

  TNXLSFileDeleteArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSDeleteFilesParams = class(TNXJSONObject)
  private
    Ffiles: TNXLSFileDeleteArray;
  published
    property files: TNXLSFileDeleteArray read Ffiles write Ffiles;
  end;

  TNXLSFileEvent = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    FType: TNXJSONInteger;
  published
    property uri: TNXJSONString read Furi write Furi;
    property &type: TNXJSONInteger read FType write FType;
  end;

  TNXLSFileEventArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSDidChangeWatchedFilesParams = class(TNXJSONObject)
  private
    Fchanges: TNXLSFileEventArray;
  published
    property changes: TNXLSFileEventArray read Fchanges write Fchanges;
  end;

  TNXLSCompleteCodeParams = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fposition: TNXLSPosition;
  published
    property uri: TNXJSONString read Furi write Furi;
    property position: TNXLSPosition read Fposition write Fposition;
  end;

  TNXLSInvertAssignmentParams = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fstart: TNXLSPosition;
    Fend: TNXLSPosition;
  published
    property uri: TNXJSONString read Furi write Furi;
    property start: TNXLSPosition read Fstart write Fstart;
    property &end: TNXLSPosition read Fend write Fend;
  end;

  TNXLSRemoveEmptyMethodsParams = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fposition: TNXLSPosition;
  published
    property uri: TNXJSONString read Furi write Furi;
    property position: TNXLSPosition read Fposition write Fposition;
  end;

  TNXLSRemoveUnusedUnitsParams = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
  end;

  TNXLSProjectCreateWizardParams = class(TNXJSONObject)
  private
    FworkspaceRoot: TNXJSONString;
  published
    property workspaceRoot: TNXJSONString read FworkspaceRoot write FworkspaceRoot;
  end;

  TNXLSProjectCreateParams = class(TNXJSONObject)
  private
    FprojectName: TNXJSONString;
    FtargetDir: TNXJSONString;
  published
    property projectName: TNXJSONString read FprojectName write FprojectName;
    property targetDir: TNXJSONString read FtargetDir write FtargetDir;
  end;

  TNXLSInlayHintParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
    Frange: TNXLSRange;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
    property range: TNXLSRange read Frange write Frange;
  end;

  TNXLSInlineValueParams = class(TNXLSInlayHintParams)
  private
    Fcontext: TNXLSInlineValueContext;
  published
    property context: TNXLSInlineValueContext read Fcontext write Fcontext;
  end;

  TNXLSInlineValueContext = class(TNXJSONObject)
  private
    FframeId: TNXJSONInteger;
    FstoppedLocation: TNXLSRange;
  published
    property frameId: TNXJSONInteger read FframeId write FframeId;
    property stoppedLocation: TNXLSRange read FstoppedLocation write FstoppedLocation;
  end;

  TNXLSNotebookDocumentIdentifier = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
  end;

  TNXLSNotebookCellExecutionSummary = class(TNXJSONObject)
  private
    FexecutionOrder: TNXJSONInteger;
    Fsuccess: TNXJSONBoolean;
  published
    property executionOrder: TNXJSONInteger read FexecutionOrder write FexecutionOrder;
    property success: TNXJSONBoolean read Fsuccess write Fsuccess;
  end;

  TNXLSNotebookCell = class(TNXJSONObject)
  private
    Fkind: TNXJSONInteger;
    Fdocument: TNXJSONString;
    Fmetadata: TNXJSONValue;
    FexecutionSummary: TNXLSNotebookCellExecutionSummary;
  published
    property kind: TNXJSONInteger read Fkind write Fkind;
    property document: TNXJSONString read Fdocument write Fdocument;
    property metadata: TNXJSONValue read Fmetadata write Fmetadata;
    property executionSummary: TNXLSNotebookCellExecutionSummary read FexecutionSummary write FexecutionSummary;
  end;

  TNXLSNotebookCellArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSNotebookDocument = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    FnotebookType: TNXJSONString;
    Fversion: TNXJSONInteger;
    Fmetadata: TNXJSONValue;
    Fcells: TNXLSNotebookCellArray;
  published
    property uri: TNXJSONString read Furi write Furi;
    property notebookType: TNXJSONString read FnotebookType write FnotebookType;
    property version: TNXJSONInteger read Fversion write Fversion;
    property metadata: TNXJSONValue read Fmetadata write Fmetadata;
    property cells: TNXLSNotebookCellArray read Fcells write Fcells;
  end;

  TNXLSVersionedNotebookDocumentIdentifier = class(TNXLSNotebookDocumentIdentifier)
  private
    Fversion: TNXJSONInteger;
  published
    property version: TNXJSONInteger read Fversion write Fversion;
  end;

  TNXLSNotebookDocumentParams = class(TNXJSONObject)
  private
    FnotebookDocument: TNXLSNotebookDocumentIdentifier;
  published
    property notebookDocument: TNXLSNotebookDocumentIdentifier read FnotebookDocument write FnotebookDocument;
  end;

  TNXLSDidOpenNotebookDocumentParams = class(TNXJSONObject)
  private
    FnotebookDocument: TNXLSNotebookDocument;
    FcellTextDocuments: TNXLSTextDocumentItemArray;
  published
    property notebookDocument: TNXLSNotebookDocument read FnotebookDocument write FnotebookDocument;
    property cellTextDocuments: TNXLSTextDocumentItemArray read FcellTextDocuments write FcellTextDocuments;
  end;

  TNXLSNotebookDocumentChangeEvent = class(TNXJSONObject)
  private
    Fmetadata: TNXJSONValue;
    Fcells: TNXJSONObject;
  published
    property metadata: TNXJSONValue read Fmetadata write Fmetadata;
    property cells: TNXJSONObject read Fcells write Fcells;
  end;

  TNXLSDidChangeNotebookDocumentParams = class(TNXJSONObject)
  private
    FnotebookDocument: TNXLSVersionedNotebookDocumentIdentifier;
    Fchange: TNXLSNotebookDocumentChangeEvent;
  published
    property notebookDocument: TNXLSVersionedNotebookDocumentIdentifier read FnotebookDocument write FnotebookDocument;
    property change: TNXLSNotebookDocumentChangeEvent read Fchange write Fchange;
  end;

  TNXLSDidCloseNotebookDocumentParams = class(TNXLSNotebookDocumentParams)
  private
    FcellTextDocuments: TNXLSTextDocumentIdentifierArray;
  published
    property cellTextDocuments: TNXLSTextDocumentIdentifierArray read FcellTextDocuments write FcellTextDocuments;
  end;

  TNXLSWorkDoneProgressCreateParams = class(TNXJSONObject)
  private
    Ftoken: TNXJSONValue;
  published
    property token: TNXJSONValue read Ftoken write Ftoken;
  end;

  TNXLSWorkDoneProgressCancelParams = class(TNXJSONObject)
  private
    Ftoken: TNXJSONValue;
  published
    property token: TNXJSONValue read Ftoken write Ftoken;
  end;

  TNXLSRenameParams = class(TNXLSTextDocumentPositionParams)
  private
    FnewName: TNXJSONString;
  published
    property newName: TNXJSONString read FnewName write FnewName;
  end;

  TNXLSDocumentDiagnosticParams = class(TNXLSDocumentLinkParams)
  private
    Fidentifier: TNXJSONString;
    FpreviousResultId: TNXJSONString;
  published
    property identifier: TNXJSONString read Fidentifier write Fidentifier;
    property previousResultId: TNXJSONString read FpreviousResultId write FpreviousResultId;
  end;

  TNXLSDiagnosticPreviousResultId = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fvalue: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
    property value: TNXJSONString read Fvalue write Fvalue;
  end;

  TNXLSDiagnosticPreviousResultIdArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSWorkspaceDiagnosticParams = class(TNXJSONObject)
  private
    Fidentifier: TNXJSONString;
    FpreviousResultIds: TNXLSDiagnosticPreviousResultIdArray;
  published
    property identifier: TNXJSONString read Fidentifier write Fidentifier;
    property previousResultIds: TNXLSDiagnosticPreviousResultIdArray read FpreviousResultIds write FpreviousResultIds;
  end;

  TNXLSPublishDiagnosticsParams = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fversion: TNXJSONValue;
    Fdiagnostics: TNXLSDiagnosticArray;
  published
    property uri: TNXJSONString read Furi write Furi;
    property version: TNXJSONValue read Fversion write Fversion;
    property diagnostics: TNXLSDiagnosticArray read Fdiagnostics write Fdiagnostics;
  end;

  TNXLSWorkspaceFoldersChangeEvent = class(TNXJSONObject)
  private
    Fadded: TNXLSWorkspaceFolderArray;
    Fremoved: TNXLSWorkspaceFolderArray;
  published
    property added: TNXLSWorkspaceFolderArray read Fadded write Fadded;
    property removed: TNXLSWorkspaceFolderArray read Fremoved write Fremoved;
  end;

  TNXLSDidChangeWorkspaceFoldersParams = class(TNXJSONObject)
  private
    Fevent: TNXLSWorkspaceFoldersChangeEvent;
  published
    property event: TNXLSWorkspaceFoldersChangeEvent read Fevent write Fevent;
  end;

  TNXLSApplyWorkspaceEditParams = class(TNXJSONObject)
  private
    FLabel: TNXJSONString;
    Fedit: TNXLSWorkspaceEdit;
  published
    property &label: TNXJSONString read FLabel write FLabel;
    property edit: TNXLSWorkspaceEdit read Fedit write Fedit;
  end;

  TNXLSAnnotatedTextEdit = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    FnewText: TNXJSONString;
    FannotationId: TNXJSONString;
  published
    property range: TNXLSRange read Frange write Frange;
    property newText: TNXJSONString read FnewText write FnewText;
    property annotationId: TNXJSONString read FannotationId write FannotationId;
  end;

  TNXLSTextEdit = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    FnewText: TNXJSONString;
  published
    property range: TNXLSRange read Frange write Frange;
    property newText: TNXJSONString read FnewText write FnewText;
  end;

  TNXLSTextEditArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSWorkspaceEdit = class(TNXJSONObject)
  private
    Fchanges: TNXJSONObject;
    FdocumentChanges: TNXJSONArray;
    FchangeAnnotations: TNXJSONObject;
  published
    property changes: TNXJSONObject read Fchanges write Fchanges;
    property documentChanges: TNXJSONArray read FdocumentChanges write FdocumentChanges;
    property changeAnnotations: TNXJSONObject read FchangeAnnotations write FchangeAnnotations;
  end;

  TNXLSMessageParams = class(TNXJSONObject)
  private
    FType: TNXJSONInteger;
    Fmessage: TNXJSONString;
  published
    property &type: TNXJSONInteger read FType write FType;
    property message: TNXJSONString read Fmessage write Fmessage;
  end;

  TNXLSShowMessageRequestParams = class(TNXLSMessageParams)
  private
    Factions: TNXLSMessageActionItemArray;
  published
    property actions: TNXLSMessageActionItemArray read FActions write FActions;
  end;

  TNXLSMessageActionItem = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
  end;

  TNXLSMessageActionItemArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSShowDocumentParams = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Fexternal: TNXJSONBoolean;
    FtakeFocus: TNXJSONBoolean;
    Fselection: TNXLSRange;
  published
    property uri: TNXJSONString read Furi write Furi;
    property external: TNXJSONBoolean read Fexternal write Fexternal;
    property takeFocus: TNXJSONBoolean read FtakeFocus write FtakeFocus;
    property selection: TNXLSRange read Fselection write Fselection;
  end;

  TNXLSTelemetryEventParams = class(TNXJSONValue)
  end;

  TNXLSDocumentLink = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    Ftarget: TNXJSONString;
    Ftooltip: TNXJSONString;
    Fdata: TNXJSONValue;
  published
    property range: TNXLSRange read Frange write Frange;
    property target: TNXJSONString read Ftarget write Ftarget;
    property tooltip: TNXJSONString read Ftooltip write Ftooltip;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSCodeLens = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    Fcommand: TNXLSCommand;
    Fdata: TNXJSONValue;
  published
    property range: TNXLSRange read Frange write Frange;
    property command: TNXLSCommand read Fcommand write Fcommand;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSInlayHint = class(TNXJSONObject)
  private
    Fposition: TNXLSPosition;
    FLabel: TNXJSONValue;
    Fkind: TNXJSONInteger;
    FtextEdits: TNXLSTextEditArray;
    Ftooltip: TNXJSONValue;
    FpaddingLeft: TNXJSONBoolean;
    FpaddingRight: TNXJSONBoolean;
    Fdata: TNXJSONValue;
  published
    property position: TNXLSPosition read Fposition write Fposition;
    property &label: TNXJSONValue read FLabel write FLabel;
    property kind: TNXJSONInteger read Fkind write Fkind;
    property textEdits: TNXLSTextEditArray read FtextEdits write FtextEdits;
    property tooltip: TNXJSONValue read Ftooltip write Ftooltip;
    property paddingLeft: TNXJSONBoolean read FpaddingLeft write FpaddingLeft;
    property paddingRight: TNXJSONBoolean read FpaddingRight write FpaddingRight;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSCompletionItem = class(TNXJSONObject)
  private
    FLabel: TNXJSONString;
    FLabelDetails: TNXLSCompletionItemLabelDetails;
    Fkind: TNXJSONInteger;
    Ftags: TNXJSONIntegerArray;
    Fdetail: TNXJSONString;
    Fdocumentation: TNXJSONValue;
    Fdeprecated: TNXJSONBoolean;
    Fpreselect: TNXJSONBoolean;
    FsortText: TNXJSONString;
    FfilterText: TNXJSONString;
    FinsertText: TNXJSONString;
    FinsertTextFormat: TNXJSONInteger;
    FinsertTextMode: TNXJSONInteger;
    FtextEdit: TNXJSONValue;
    FtextEditText: TNXJSONString;
    FadditionalTextEdits: TNXLSTextEditArray;
    FcommitCharacters: TNXJSONStringArray;
    Fcommand: TNXLSCommand;
    Fdata: TNXJSONValue;
  published
    property &label: TNXJSONString read FLabel write FLabel;
    property labelDetails: TNXLSCompletionItemLabelDetails read FLabelDetails write FLabelDetails;
    property kind: TNXJSONInteger read Fkind write Fkind;
    property tags: TNXJSONIntegerArray read Ftags write Ftags;
    property detail: TNXJSONString read Fdetail write Fdetail;
    property documentation: TNXJSONValue read Fdocumentation write Fdocumentation;
    property deprecated: TNXJSONBoolean read Fdeprecated write Fdeprecated;
    property preselect: TNXJSONBoolean read Fpreselect write Fpreselect;
    property sortText: TNXJSONString read FsortText write FsortText;
    property filterText: TNXJSONString read FfilterText write FfilterText;
    property insertText: TNXJSONString read FinsertText write FinsertText;
    property insertTextFormat: TNXJSONInteger read FinsertTextFormat write FinsertTextFormat;
    property insertTextMode: TNXJSONInteger read FinsertTextMode write FinsertTextMode;
    property textEdit: TNXJSONValue read FtextEdit write FtextEdit;
    property textEditText: TNXJSONString read FtextEditText write FtextEditText;
    property additionalTextEdits: TNXLSTextEditArray read FadditionalTextEdits write FadditionalTextEdits;
    property commitCharacters: TNXJSONStringArray read FcommitCharacters write FcommitCharacters;
    property command: TNXLSCommand read Fcommand write Fcommand;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSCompletionItemLabelDetails = class(TNXJSONObject)
  private
    Fdetail: TNXJSONString;
    Fdescription: TNXJSONString;
  published
    property detail: TNXJSONString read Fdetail write Fdetail;
    property description: TNXJSONString read Fdescription write Fdescription;
  end;

  TNXLSCodeAction = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Fkind: TNXJSONString;
    Fdiagnostics: TNXLSDiagnosticArray;
    FisPreferred: TNXJSONBoolean;
    Fdisabled: TNXLSCodeActionDisabled;
    Fedit: TNXLSWorkspaceEdit;
    Fcommand: TNXLSCommand;
    Fdata: TNXJSONValue;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property kind: TNXJSONString read Fkind write Fkind;
    property diagnostics: TNXLSDiagnosticArray read Fdiagnostics write Fdiagnostics;
    property isPreferred: TNXJSONBoolean read FisPreferred write FisPreferred;
    property disabled: TNXLSCodeActionDisabled read Fdisabled write Fdisabled;
    property edit: TNXLSWorkspaceEdit read Fedit write Fedit;
    property command: TNXLSCommand read Fcommand write Fcommand;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

  TNXLSCodeActionDisabled = class(TNXJSONObject)
  private
    Freason: TNXJSONString;
  published
    property reason: TNXJSONString read Freason write Freason;
  end;

  TNXLSWorkspaceSymbol = class(TNXJSONObject)
  private
    Fname: TNXJSONString;
    Fkind: TNXJSONInteger;
    Ftags: TNXJSONIntegerArray;
    FcontainerName: TNXJSONString;
    Flocation: TNXJSONValue;
    Fdata: TNXJSONValue;
  published
    property name: TNXJSONString read Fname write Fname;
    property kind: TNXJSONInteger read Fkind write Fkind;
    property tags: TNXJSONIntegerArray read Ftags write Ftags;
    property containerName: TNXJSONString read FcontainerName write FcontainerName;
    property location: TNXJSONValue read Flocation write Flocation;
    property data: TNXJSONValue read Fdata write Fdata;
  end;

implementation

class function TNXJSONStringArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXJSONString;
end;

class function TNXJSONIntegerArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXJSONInteger;
end;

class function TNXLSPositionArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSPosition;
end;

class function TNXLSTextDocumentItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentItem;
end;

class function TNXLSTextDocumentIdentifierArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentIdentifier;
end;

class function TNXLSWorkspaceFolderArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceFolder;
end;

class function TNXLSDiagnosticRelatedInformationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSDiagnosticRelatedInformation;
end;

class function TNXLSDiagnosticArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSDiagnostic;
end;

class function TNXLSParameterInformationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSParameterInformation;
end;

class function TNXLSSignatureInformationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSSignatureInformation;
end;

class function TNXLSConfigurationItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSConfigurationItem;
end;

class function TNXLSRegistrationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSRegistration;
end;

class function TNXLSUnregistrationArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSUnregistration;
end;

class function TNXLSFileCreateArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSFileCreate;
end;

class function TNXLSFileRenameArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSFileRename;
end;

class function TNXLSFileDeleteArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSFileDelete;
end;

class function TNXLSFileEventArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSFileEvent;
end;

class function TNXLSNotebookCellArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSNotebookCell;
end;

class function TNXLSDiagnosticPreviousResultIdArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSDiagnosticPreviousResultId;
end;

class function TNXLSTextEditArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSTextEdit;
end;

class function TNXLSMessageActionItemArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSMessageActionItem;
end;

end.
