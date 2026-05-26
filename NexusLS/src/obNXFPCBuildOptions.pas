unit obNXFPCBuildOptions;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils;

type
  TNXFPCSwitchState = (
    fssUnset,
    fssEnabled,
    fssDisabled
  );

  TNXFPCLanguageMode = (
    flmUnset,
    flmFPC,
    flmObjFPC,
    flmDelphi,
    flmTP,
    flmMacPas,
    flmISO,
    flmExtendedPascal,
    flmDelphiUnicode
  );

  TNXFPCDebugFormat = (
    fdfUnset,
    fdfDefault,
    fdfStabs,
    fdfDwarf2,
    fdfDwarf3,
    fdfDwarf4,
    fdfCodeView
  );

  TNXFPCOptimizationLevel = (
    folUnset,
    folDisabled,
    folLevel1,
    folLevel2,
    folLevel3,
    folLevel4
  );

  TNXFPCApplicationType = (
    fatUnset,
    fatNative,
    fatConsole,
    fatGraphic
  );

  TNXFPCBuildKind = (
    fbkUnset,
    fbkProgram,
    fbkLibrary,
    fbkUnit,
    fbkPackage
  );

  TNXFPCOptionSection = class
  public
    procedure AppendArguments(AArguments: TStrings); virtual;
  end;

  TNXFPCConfigOptions = class(TNXFPCOptionSection)
  private
    FDisableDefaultConfigFiles: Boolean;
    FOptionFiles: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property DisableDefaultConfigFiles: Boolean read FDisableDefaultConfigFiles write FDisableDefaultConfigFiles;
    property OptionFiles: TStringList read FOptionFiles;
  end;

  TNXFPCAssemblerOptions = class(TNXFPCOptionSection)
  private
    FPreserveAssemblerFile: TNXFPCSwitchState;
    FGenerateBigObjCOFF: TNXFPCSwitchState;
    FListSourceLines: TNXFPCSwitchState;
    FListNodeInfo: TNXFPCSwitchState;
    FExternalAssemblerOptions: TStringList;
    FUsePipes: TNXFPCSwitchState;
    FListRegisterInfo: TNXFPCSwitchState;
    FListTempInfo: TNXFPCSwitchState;
    FOutputFormat: string;
    FReadingStyle: string;
    FSkipRegisterAllocation: TNXFPCSwitchState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property PreserveAssemblerFile: TNXFPCSwitchState read FPreserveAssemblerFile write FPreserveAssemblerFile;
    property GenerateBigObjCOFF: TNXFPCSwitchState read FGenerateBigObjCOFF write FGenerateBigObjCOFF;
    property ListSourceLines: TNXFPCSwitchState read FListSourceLines write FListSourceLines;
    property ListNodeInfo: TNXFPCSwitchState read FListNodeInfo write FListNodeInfo;
    property ExternalAssemblerOptions: TStringList read FExternalAssemblerOptions;
    property UsePipes: TNXFPCSwitchState read FUsePipes write FUsePipes;
    property ListRegisterInfo: TNXFPCSwitchState read FListRegisterInfo write FListRegisterInfo;
    property ListTempInfo: TNXFPCSwitchState read FListTempInfo write FListTempInfo;
    property OutputFormat: string read FOutputFormat write FOutputFormat;
    property ReadingStyle: string read FReadingStyle write FReadingStyle;
    property SkipRegisterAllocation: TNXFPCSwitchState read FSkipRegisterAllocation write FSkipRegisterAllocation;
  end;

  TNXFPCBuildControlOptions = class(TNXFPCOptionSection)
  private
    FBuildAllModules: TNXFPCSwitchState;
    FBrowserInfo: TNXFPCSwitchState;
    FBrowserLocalSymbols: TNXFPCSwitchState;
    FWriteLogo: TNXFPCSwitchState;
    FGenerateProfileCode: TNXFPCSwitchState;
  public
    procedure AppendArguments(AArguments: TStrings); override;

    property BuildAllModules: TNXFPCSwitchState read FBuildAllModules write FBuildAllModules;
    property BrowserInfo: TNXFPCSwitchState read FBrowserInfo write FBrowserInfo;
    property BrowserLocalSymbols: TNXFPCSwitchState read FBrowserLocalSymbols write FBrowserLocalSymbols;
    property WriteLogo: TNXFPCSwitchState read FWriteLogo write FWriteLogo;
    property GenerateProfileCode: TNXFPCSwitchState read FGenerateProfileCode write FGenerateProfileCode;
  end;

  TNXFPCDefinitionOptions = class(TNXFPCOptionSection)
  private
    FDefines: TStringList;
    FUndefines: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property Defines: TStringList read FDefines;
    property Undefines: TStringList read FUndefines;
  end;

  TNXFPCDefFileOptions = class(TNXFPCOptionSection)
  private
    FGenerateDefFile: TNXFPCSwitchState;
    FDescription: string;
    FDllVersion: string;
  public
    procedure AppendArguments(AArguments: TStrings); override;

    property GenerateDefFile: TNXFPCSwitchState read FGenerateDefFile write FGenerateDefFile;
    property Description: string read FDescription write FDescription;
    property DllVersion: string read FDllVersion write FDllVersion;
  end;

  TNXFPCCodeGenerationOptions = class(TNXFPCOptionSection)
  private
    FIEEEConstantChecks: TNXFPCSwitchState;
    FABI: string;
    FBigEndianCode: TNXFPCSwitchState;
    FCallingConvention: string;
    FDynamicLibrary: TNXFPCSwitchState;
    FEmulatedFloatingPoint: TNXFPCSwitchState;
    FFloatingPointExceptions: TNXFPCSwitchState;
    FFPUInstructionSet: string;
    FMinimumFloatConstantPrecision: string;
    FPositionIndependentCode: TNXFPCSwitchState;
    FMinimumHeapSize: Integer;
    FMaximumHeapSize: Integer;
    FIOChecking: TNXFPCSwitchState;
    FOmitLinkingStage: TNXFPCSwitchState;
    FOverflowChecking: TNXFPCSwitchState;
    FPossibleOverflowChecking: TNXFPCSwitchState;
    FInstructionSet: string;
    FPackingOptions: TStringList;
    FRangeChecking: TNXFPCSwitchState;
    FObjectMethodCallValidityChecking: TNXFPCSwitchState;
    FStackCheckingSize: Integer;
    FStackChecking: TNXFPCSwitchState;
    FTargetSpecificOptions: TStringList;
    FSmartLinkedLibrary: TNXFPCSwitchState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property IEEEConstantChecks: TNXFPCSwitchState read FIEEEConstantChecks write FIEEEConstantChecks;
    property ABI: string read FABI write FABI;
    property BigEndianCode: TNXFPCSwitchState read FBigEndianCode write FBigEndianCode;
    property CallingConvention: string read FCallingConvention write FCallingConvention;
    property DynamicLibrary: TNXFPCSwitchState read FDynamicLibrary write FDynamicLibrary;
    property EmulatedFloatingPoint: TNXFPCSwitchState read FEmulatedFloatingPoint write FEmulatedFloatingPoint;
    property FloatingPointExceptions: TNXFPCSwitchState read FFloatingPointExceptions write FFloatingPointExceptions;
    property FPUInstructionSet: string read FFPUInstructionSet write FFPUInstructionSet;
    property MinimumFloatConstantPrecision: string read FMinimumFloatConstantPrecision write FMinimumFloatConstantPrecision;
    property PositionIndependentCode: TNXFPCSwitchState read FPositionIndependentCode write FPositionIndependentCode;
    property MinimumHeapSize: Integer read FMinimumHeapSize write FMinimumHeapSize;
    property MaximumHeapSize: Integer read FMaximumHeapSize write FMaximumHeapSize;
    property IOChecking: TNXFPCSwitchState read FIOChecking write FIOChecking;
    property OmitLinkingStage: TNXFPCSwitchState read FOmitLinkingStage write FOmitLinkingStage;
    property OverflowChecking: TNXFPCSwitchState read FOverflowChecking write FOverflowChecking;
    property PossibleOverflowChecking: TNXFPCSwitchState read FPossibleOverflowChecking write FPossibleOverflowChecking;
    property InstructionSet: string read FInstructionSet write FInstructionSet;
    property PackingOptions: TStringList read FPackingOptions;
    property RangeChecking: TNXFPCSwitchState read FRangeChecking write FRangeChecking;
    property ObjectMethodCallValidityChecking: TNXFPCSwitchState read FObjectMethodCallValidityChecking write FObjectMethodCallValidityChecking;
    property StackCheckingSize: Integer read FStackCheckingSize write FStackCheckingSize;
    property StackChecking: TNXFPCSwitchState read FStackChecking write FStackChecking;
    property TargetSpecificOptions: TStringList read FTargetSpecificOptions;
    property SmartLinkedLibrary: TNXFPCSwitchState read FSmartLinkedLibrary write FSmartLinkedLibrary;
  end;

  TNXFPCFileOptions = class(TNXFPCOptionSection)
  private
    FExecutableSearchPath: string;
    FPreloadUnits: TStringList;
    FInputCodePage: string;
    FRCCompilerBinary: string;
    FDisableInternalDirectoryCache: TNXFPCSwitchState;
    FCompilerUtilitiesPath: string;
    FErrorOutputFile: string;
    FFrameworkPaths: TStringList;
    FExecutableOutputPath: string;
    FIncludePaths: TStringList;
    FLibraryPaths: TStringList;
    FDynamicLinker: string;
    FUnicodeConversionTable: string;
    FUnicodeBinaryPath: string;
    FDefaultUnitScopes: TStringList;
    FObjectPaths: TStringList;
    FErrorMessageFile: string;
    FResourceLinker: string;
    FUnitPaths: TStringList;
    FUnitOutputPath: string;
    FWholeProgramFeedbackOutput: string;
    FWholeProgramFeedbackInput: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property ExecutableSearchPath: string read FExecutableSearchPath write FExecutableSearchPath;
    property PreloadUnits: TStringList read FPreloadUnits;
    property InputCodePage: string read FInputCodePage write FInputCodePage;
    property RCCompilerBinary: string read FRCCompilerBinary write FRCCompilerBinary;
    property DisableInternalDirectoryCache: TNXFPCSwitchState read FDisableInternalDirectoryCache write FDisableInternalDirectoryCache;
    property CompilerUtilitiesPath: string read FCompilerUtilitiesPath write FCompilerUtilitiesPath;
    property ErrorOutputFile: string read FErrorOutputFile write FErrorOutputFile;
    property FrameworkPaths: TStringList read FFrameworkPaths;
    property ExecutableOutputPath: string read FExecutableOutputPath write FExecutableOutputPath;
    property IncludePaths: TStringList read FIncludePaths;
    property LibraryPaths: TStringList read FLibraryPaths;
    property DynamicLinker: string read FDynamicLinker write FDynamicLinker;
    property UnicodeConversionTable: string read FUnicodeConversionTable write FUnicodeConversionTable;
    property UnicodeBinaryPath: string read FUnicodeBinaryPath write FUnicodeBinaryPath;
    property DefaultUnitScopes: TStringList read FDefaultUnitScopes;
    property ObjectPaths: TStringList read FObjectPaths;
    property ErrorMessageFile: string read FErrorMessageFile write FErrorMessageFile;
    property ResourceLinker: string read FResourceLinker write FResourceLinker;
    property UnitPaths: TStringList read FUnitPaths;
    property UnitOutputPath: string read FUnitOutputPath write FUnitOutputPath;
    property WholeProgramFeedbackOutput: string read FWholeProgramFeedbackOutput write FWholeProgramFeedbackOutput;
    property WholeProgramFeedbackInput: string read FWholeProgramFeedbackInput write FWholeProgramFeedbackInput;
  end;

  TNXFPCDebugOptions = class(TNXFPCOptionSection)
  private
    FGenerateDebugInfo: TNXFPCSwitchState;
    FPointerChecks: TNXFPCSwitchState;
    FHeapTrace: TNXFPCSwitchState;
    FLineInfo: TNXFPCSwitchState;
    FFormat: TNXFPCDebugFormat;
    FOptions: TStringList;
    FPreserveStabsCase: TNXFPCSwitchState;
    FTrashLocalVariables: Integer;
    FValgrind: TNXFPCSwitchState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property GenerateDebugInfo: TNXFPCSwitchState read FGenerateDebugInfo write FGenerateDebugInfo;
    property PointerChecks: TNXFPCSwitchState read FPointerChecks write FPointerChecks;
    property HeapTrace: TNXFPCSwitchState read FHeapTrace write FHeapTrace;
    property LineInfo: TNXFPCSwitchState read FLineInfo write FLineInfo;
    property Format: TNXFPCDebugFormat read FFormat write FFormat;
    property Options: TStringList read FOptions;
    property PreserveStabsCase: TNXFPCSwitchState read FPreserveStabsCase write FPreserveStabsCase;
    property TrashLocalVariables: Integer read FTrashLocalVariables write FTrashLocalVariables;
    property Valgrind: TNXFPCSwitchState read FValgrind write FValgrind;
  end;

  TNXFPCInformationOptions = class(TNXFPCOptionSection)
  private
    FCompilerDate: TNXFPCSwitchState;
    FCompilerOS: TNXFPCSwitchState;
    FHostProcessor: TNXFPCSwitchState;
    FTargetOS: TNXFPCSwitchState;
    FTargetProcessor: TNXFPCSwitchState;
    FShortCompilerVersion: TNXFPCSwitchState;
    FFullCompilerVersion: TNXFPCSwitchState;
    FSupportedABITargets: TNXFPCSwitchState;
    FSupportedCPUInstructionSets: TNXFPCSwitchState;
    FSupportedFPUInstructionSets: TNXFPCSwitchState;
    FSupportedInlineAssemblerModes: TNXFPCSwitchState;
    FSupportedOptimizations: TNXFPCSwitchState;
    FRecognizedFeatures: TNXFPCSwitchState;
    FSupportedTargets: TNXFPCSwitchState;
    FSupportedMicrocontrollerTypes: TNXFPCSwitchState;
    FSupportedWholeProgramOptimizations: TNXFPCSwitchState;
  public
    procedure AppendArguments(AArguments: TStrings); override;

    property CompilerDate: TNXFPCSwitchState read FCompilerDate write FCompilerDate;
    property CompilerOS: TNXFPCSwitchState read FCompilerOS write FCompilerOS;
    property HostProcessor: TNXFPCSwitchState read FHostProcessor write FHostProcessor;
    property TargetOS: TNXFPCSwitchState read FTargetOS write FTargetOS;
    property TargetProcessor: TNXFPCSwitchState read FTargetProcessor write FTargetProcessor;
    property ShortCompilerVersion: TNXFPCSwitchState read FShortCompilerVersion write FShortCompilerVersion;
    property FullCompilerVersion: TNXFPCSwitchState read FFullCompilerVersion write FFullCompilerVersion;
    property SupportedABITargets: TNXFPCSwitchState read FSupportedABITargets write FSupportedABITargets;
    property SupportedCPUInstructionSets: TNXFPCSwitchState read FSupportedCPUInstructionSets write FSupportedCPUInstructionSets;
    property SupportedFPUInstructionSets: TNXFPCSwitchState read FSupportedFPUInstructionSets write FSupportedFPUInstructionSets;
    property SupportedInlineAssemblerModes: TNXFPCSwitchState read FSupportedInlineAssemblerModes write FSupportedInlineAssemblerModes;
    property SupportedOptimizations: TNXFPCSwitchState read FSupportedOptimizations write FSupportedOptimizations;
    property RecognizedFeatures: TNXFPCSwitchState read FRecognizedFeatures write FRecognizedFeatures;
    property SupportedTargets: TNXFPCSwitchState read FSupportedTargets write FSupportedTargets;
    property SupportedMicrocontrollerTypes: TNXFPCSwitchState read FSupportedMicrocontrollerTypes write FSupportedMicrocontrollerTypes;
    property SupportedWholeProgramOptimizations: TNXFPCSwitchState read FSupportedWholeProgramOptimizations write FSupportedWholeProgramOptimizations;
  end;

  TNXFPCLanguageOptions = class(TNXFPCOptionSection)
  private
    FMode: TNXFPCLanguageMode;
    FEnabledModeSwitches: TStringList;
    FDisabledModeSwitches: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property Mode: TNXFPCLanguageMode read FMode write FMode;
    property EnabledModeSwitches: TStringList read FEnabledModeSwitches;
    property DisabledModeSwitches: TStringList read FDisabledModeSwitches;
  end;

  TNXFPCOptimizationOptions = class(TNXFPCOptionSection)
  private
    FLevel: TNXFPCOptimizationLevel;
    FOptimizeForSize: TNXFPCSwitchState;
    FTargetCPU: string;
    FAlignmentOptions: TStringList;
    FEnabledOptimizations: TStringList;
    FDisabledOptimizations: TStringList;
    FWholeProgramFeedbackOptimizations: TStringList;
    FWholeProgramUseOptimizations: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property Level: TNXFPCOptimizationLevel read FLevel write FLevel;
    property OptimizeForSize: TNXFPCSwitchState read FOptimizeForSize write FOptimizeForSize;
    property TargetCPU: string read FTargetCPU write FTargetCPU;
    property AlignmentOptions: TStringList read FAlignmentOptions;
    property EnabledOptimizations: TStringList read FEnabledOptimizations;
    property DisabledOptimizations: TStringList read FDisabledOptimizations;
    property WholeProgramFeedbackOptimizations: TStringList read FWholeProgramFeedbackOptimizations;
    property WholeProgramUseOptimizations: TStringList read FWholeProgramUseOptimizations;
  end;

  TNXFPCSyntaxOptions = class(TNXFPCOptionSection)
  private
    FObjFPCModeShortcut: TNXFPCSwitchState;
    FDelphiModeShortcut: TNXFPCSwitchState;
    FTurboPascalModeShortcut: TNXFPCSwitchState;
    FAssertions: TNXFPCSwitchState;
    FCOperators: TNXFPCSwitchState;
    FErrorLimit: Integer;
    FHaltAfterWarnings: TNXFPCSwitchState;
    FHaltAfterNotes: TNXFPCSwitchState;
    FHaltAfterHints: TNXFPCSwitchState;
    FFeatures: TStringList;
    FLabelAndGoto: TNXFPCSwitchState;
    FReferenceCountedStrings: TNXFPCSwitchState;
    FInlining: TNXFPCSwitchState;
    FWriteableTypedConstants: TNXFPCSwitchState;
    FLoadFpcylixUnit: TNXFPCSwitchState;
    FInterfaceStyle: string;
    FMacros: TNXFPCSwitchState;
    FTransparentFileNames: TNXFPCSwitchState;
    FConstructorDestructorNameRules: TNXFPCSwitchState;
    FVectorProcessing: TNXFPCSwitchState;
    FExceptions: TNXFPCSwitchState;
    FTypedAddressOperator: TNXFPCSwitchState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property ObjFPCModeShortcut: TNXFPCSwitchState read FObjFPCModeShortcut write FObjFPCModeShortcut;
    property DelphiModeShortcut: TNXFPCSwitchState read FDelphiModeShortcut write FDelphiModeShortcut;
    property TurboPascalModeShortcut: TNXFPCSwitchState read FTurboPascalModeShortcut write FTurboPascalModeShortcut;
    property Assertions: TNXFPCSwitchState read FAssertions write FAssertions;
    property COperators: TNXFPCSwitchState read FCOperators write FCOperators;
    property ErrorLimit: Integer read FErrorLimit write FErrorLimit;
    property HaltAfterWarnings: TNXFPCSwitchState read FHaltAfterWarnings write FHaltAfterWarnings;
    property HaltAfterNotes: TNXFPCSwitchState read FHaltAfterNotes write FHaltAfterNotes;
    property HaltAfterHints: TNXFPCSwitchState read FHaltAfterHints write FHaltAfterHints;
    property Features: TStringList read FFeatures;
    property LabelAndGoto: TNXFPCSwitchState read FLabelAndGoto write FLabelAndGoto;
    property ReferenceCountedStrings: TNXFPCSwitchState read FReferenceCountedStrings write FReferenceCountedStrings;
    property Inlining: TNXFPCSwitchState read FInlining write FInlining;
    property WriteableTypedConstants: TNXFPCSwitchState read FWriteableTypedConstants write FWriteableTypedConstants;
    property LoadFpcylixUnit: TNXFPCSwitchState read FLoadFpcylixUnit write FLoadFpcylixUnit;
    property InterfaceStyle: string read FInterfaceStyle write FInterfaceStyle;
    property Macros: TNXFPCSwitchState read FMacros write FMacros;
    property TransparentFileNames: TNXFPCSwitchState read FTransparentFileNames write FTransparentFileNames;
    property ConstructorDestructorNameRules: TNXFPCSwitchState read FConstructorDestructorNameRules write FConstructorDestructorNameRules;
    property VectorProcessing: TNXFPCSwitchState read FVectorProcessing write FVectorProcessing;
    property Exceptions: TNXFPCSwitchState read FExceptions write FExceptions;
    property TypedAddressOperator: TNXFPCSwitchState read FTypedAddressOperator write FTypedAddressOperator;
  end;

  TNXFPCTargetOptions = class(TNXFPCOptionSection)
  private
    FOperatingSystem: string;
    FApplicationType: TNXFPCApplicationType;
    FCreateBundle: TNXFPCSwitchState;
    FRelocatableImage: TNXFPCSwitchState;
    FImageBase: string;
    FUseDefFileExports: TNXFPCSwitchState;
    FUseExternalResources: TNXFPCSwitchState;
    FUseInternalResources: TNXFPCSwitchState;
    FUseImportSections: TNXFPCSwitchState;
    FMinimumMacOSVersion: string;
    FNoRelocationCode: TNXFPCSwitchState;
    FMinimumIOSVersion: string;
    FGenerateRelocationCode: TNXFPCSwitchState;
    FExecutableStack: TNXFPCSwitchState;
    FRawTargetOptions: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property OperatingSystem: string read FOperatingSystem write FOperatingSystem;
    property ApplicationType: TNXFPCApplicationType read FApplicationType write FApplicationType;
    property CreateBundle: TNXFPCSwitchState read FCreateBundle write FCreateBundle;
    property RelocatableImage: TNXFPCSwitchState read FRelocatableImage write FRelocatableImage;
    property ImageBase: string read FImageBase write FImageBase;
    property UseDefFileExports: TNXFPCSwitchState read FUseDefFileExports write FUseDefFileExports;
    property UseExternalResources: TNXFPCSwitchState read FUseExternalResources write FUseExternalResources;
    property UseInternalResources: TNXFPCSwitchState read FUseInternalResources write FUseInternalResources;
    property UseImportSections: TNXFPCSwitchState read FUseImportSections write FUseImportSections;
    property MinimumMacOSVersion: string read FMinimumMacOSVersion write FMinimumMacOSVersion;
    property NoRelocationCode: TNXFPCSwitchState read FNoRelocationCode write FNoRelocationCode;
    property MinimumIOSVersion: string read FMinimumIOSVersion write FMinimumIOSVersion;
    property GenerateRelocationCode: TNXFPCSwitchState read FGenerateRelocationCode write FGenerateRelocationCode;
    property ExecutableStack: TNXFPCSwitchState read FExecutableStack write FExecutableStack;
    property RawTargetOptions: TStringList read FRawTargetOptions;
  end;

  TNXFPCUnitOptions = class(TNXFPCOptionSection)
  private
    FDoNotCheckUnitNameMatchesFileName: TNXFPCSwitchState;
    FGenerateReleaseUnitFiles: TNXFPCSwitchState;
    FCompileSystemUnit: TNXFPCSwitchState;
  public
    procedure AppendArguments(AArguments: TStrings); override;

    property DoNotCheckUnitNameMatchesFileName: TNXFPCSwitchState read FDoNotCheckUnitNameMatchesFileName write FDoNotCheckUnitNameMatchesFileName;
    property GenerateReleaseUnitFiles: TNXFPCSwitchState read FGenerateReleaseUnitFiles write FGenerateReleaseUnitFiles;
    property CompileSystemUnit: TNXFPCSwitchState read FCompileSystemUnit write FCompileSystemUnit;
  end;

  TNXFPCVerbosityOptions = class(TNXFPCOptionSection)
  private
    FShowErrors: TNXFPCSwitchState;
    FShowWarnings: TNXFPCSwitchState;
    FShowNotes: TNXFPCSwitchState;
    FShowHints: TNXFPCSwitchState;
    FShowGeneralInfo: TNXFPCSwitchState;
    FShowLineNumbers: TNXFPCSwitchState;
    FShowEverything: TNXFPCSwitchState;
    FWriteFileNamesWithFullPath: TNXFPCSwitchState;
    FShowNothingExceptErrors: TNXFPCSwitchState;
    FShowUnitInfo: TNXFPCSwitchState;
    FShowTriedFiles: TNXFPCSwitchState;
    FShowConditionals: TNXFPCSwitchState;
    FShowDebugInfo: TNXFPCSwitchState;
    FRhideGCCCompatibilityMode: TNXFPCSwitchState;
    FShowTimeStamps: TNXFPCSwitchState;
    FShowMessageNumbers: TNXFPCSwitchState;
    FShowInvokedTools: TNXFPCSwitchState;
    FWriteParseTreeLog: TNXFPCSwitchState;
    FWriteFPCDebugFile: TNXFPCSwitchState;
    FWriteOutputToStdErr: TNXFPCSwitchState;
    FSuppressedMessages: TStringList;
  protected
    function BuildVerbosityValue: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property ShowErrors: TNXFPCSwitchState read FShowErrors write FShowErrors;
    property ShowWarnings: TNXFPCSwitchState read FShowWarnings write FShowWarnings;
    property ShowNotes: TNXFPCSwitchState read FShowNotes write FShowNotes;
    property ShowHints: TNXFPCSwitchState read FShowHints write FShowHints;
    property ShowGeneralInfo: TNXFPCSwitchState read FShowGeneralInfo write FShowGeneralInfo;
    property ShowLineNumbers: TNXFPCSwitchState read FShowLineNumbers write FShowLineNumbers;
    property ShowEverything: TNXFPCSwitchState read FShowEverything write FShowEverything;
    property WriteFileNamesWithFullPath: TNXFPCSwitchState read FWriteFileNamesWithFullPath write FWriteFileNamesWithFullPath;
    property ShowNothingExceptErrors: TNXFPCSwitchState read FShowNothingExceptErrors write FShowNothingExceptErrors;
    property ShowUnitInfo: TNXFPCSwitchState read FShowUnitInfo write FShowUnitInfo;
    property ShowTriedFiles: TNXFPCSwitchState read FShowTriedFiles write FShowTriedFiles;
    property ShowConditionals: TNXFPCSwitchState read FShowConditionals write FShowConditionals;
    property ShowDebugInfo: TNXFPCSwitchState read FShowDebugInfo write FShowDebugInfo;
    property RhideGCCCompatibilityMode: TNXFPCSwitchState read FRhideGCCCompatibilityMode write FRhideGCCCompatibilityMode;
    property ShowTimeStamps: TNXFPCSwitchState read FShowTimeStamps write FShowTimeStamps;
    property ShowMessageNumbers: TNXFPCSwitchState read FShowMessageNumbers write FShowMessageNumbers;
    property ShowInvokedTools: TNXFPCSwitchState read FShowInvokedTools write FShowInvokedTools;
    property WriteParseTreeLog: TNXFPCSwitchState read FWriteParseTreeLog write FWriteParseTreeLog;
    property WriteFPCDebugFile: TNXFPCSwitchState read FWriteFPCDebugFile write FWriteFPCDebugFile;
    property WriteOutputToStdErr: TNXFPCSwitchState read FWriteOutputToStdErr write FWriteOutputToStdErr;
    property SuppressedMessages: TStringList read FSuppressedMessages;
  end;

  TNXFPCLinkingOptions = class(TNXFPCOptionSection)
  private
    FDoNotCallAssemblerAndLinker: TNXFPCSwitchState;
    FGenerateHostLinkScript: TNXFPCSwitchState;
    FGenerateTargetLinkScript: TNXFPCSwitchState;
    FLinkerOptions: TStringList;
    FGenerateOldBinutilsLinkScript: TNXFPCSwitchState;
    FSharedDynamicLinking: TNXFPCSwitchState;
    FDoNotSearchDefaultLibraryPath: TNXFPCSwitchState;
    FExternalLinker: TNXFPCSwitchState;
    FSubstitutePThreadLibrary: TNXFPCSwitchState;
    FSeparateDebugInfo: TNXFPCSwitchState;
    FDynamicUnits: TNXFPCSwitchState;
    FInternalLinker: TNXFPCSwitchState;
    FLibrarySubstitutions: TStringList;
    FLibraryOrder: TStringList;
    FExcludeDefaultLibraryOrder: TNXFPCSwitchState;
    FLinkMap: TNXFPCSwitchState;
    FMainRoutineName: string;
    FNativeLinker: TNXFPCSwitchState;
    FBinUtilsPrefix: string;
    FRuntimeLinkPath: string;
    FLinkerSearchRoot: string;
    FStripSymbols: TNXFPCSwitchState;
    FStaticLibraryLinking: TNXFPCSwitchState;
    FStaticUnits: TNXFPCSwitchState;
    FVirtualEntryCallTable: TNXFPCSwitchState;
    FVLinkExternalLinker: TNXFPCSwitchState;
    FSmartLinkedUnits: TNXFPCSwitchState;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;

    property DoNotCallAssemblerAndLinker: TNXFPCSwitchState read FDoNotCallAssemblerAndLinker write FDoNotCallAssemblerAndLinker;
    property GenerateHostLinkScript: TNXFPCSwitchState read FGenerateHostLinkScript write FGenerateHostLinkScript;
    property GenerateTargetLinkScript: TNXFPCSwitchState read FGenerateTargetLinkScript write FGenerateTargetLinkScript;
    property LinkerOptions: TStringList read FLinkerOptions;
    property GenerateOldBinutilsLinkScript: TNXFPCSwitchState read FGenerateOldBinutilsLinkScript write FGenerateOldBinutilsLinkScript;
    property SharedDynamicLinking: TNXFPCSwitchState read FSharedDynamicLinking write FSharedDynamicLinking;
    property DoNotSearchDefaultLibraryPath: TNXFPCSwitchState read FDoNotSearchDefaultLibraryPath write FDoNotSearchDefaultLibraryPath;
    property ExternalLinker: TNXFPCSwitchState read FExternalLinker write FExternalLinker;
    property SubstitutePThreadLibrary: TNXFPCSwitchState read FSubstitutePThreadLibrary write FSubstitutePThreadLibrary;
    property SeparateDebugInfo: TNXFPCSwitchState read FSeparateDebugInfo write FSeparateDebugInfo;
    property DynamicUnits: TNXFPCSwitchState read FDynamicUnits write FDynamicUnits;
    property InternalLinker: TNXFPCSwitchState read FInternalLinker write FInternalLinker;
    property LibrarySubstitutions: TStringList read FLibrarySubstitutions;
    property LibraryOrder: TStringList read FLibraryOrder;
    property ExcludeDefaultLibraryOrder: TNXFPCSwitchState read FExcludeDefaultLibraryOrder write FExcludeDefaultLibraryOrder;
    property LinkMap: TNXFPCSwitchState read FLinkMap write FLinkMap;
    property MainRoutineName: string read FMainRoutineName write FMainRoutineName;
    property NativeLinker: TNXFPCSwitchState read FNativeLinker write FNativeLinker;
    property BinUtilsPrefix: string read FBinUtilsPrefix write FBinUtilsPrefix;
    property RuntimeLinkPath: string read FRuntimeLinkPath write FRuntimeLinkPath;
    property LinkerSearchRoot: string read FLinkerSearchRoot write FLinkerSearchRoot;
    property StripSymbols: TNXFPCSwitchState read FStripSymbols write FStripSymbols;
    property StaticLibraryLinking: TNXFPCSwitchState read FStaticLibraryLinking write FStaticLibraryLinking;
    property StaticUnits: TNXFPCSwitchState read FStaticUnits write FStaticUnits;
    property VirtualEntryCallTable: TNXFPCSwitchState read FVirtualEntryCallTable write FVirtualEntryCallTable;
    property VLinkExternalLinker: TNXFPCSwitchState read FVLinkExternalLinker write FVLinkExternalLinker;
    property SmartLinkedUnits: TNXFPCSwitchState read FSmartLinkedUnits write FSmartLinkedUnits;
  end;

  TNXFPCBuildOptions = class(TNXFPCOptionSection)
  private
    FCompilerPath: string;
    FInputFile: string;
    FOutputFile: string;
    FBuildKind: TNXFPCBuildKind;
    FConfig: TNXFPCConfigOptions;
    FAssembler: TNXFPCAssemblerOptions;
    FBuildControl: TNXFPCBuildControlOptions;
    FDefinitions: TNXFPCDefinitionOptions;
    FDefFile: TNXFPCDefFileOptions;
    FCodeGeneration: TNXFPCCodeGenerationOptions;
    FFiles: TNXFPCFileOptions;
    FDebug: TNXFPCDebugOptions;
    FInformation: TNXFPCInformationOptions;
    FLanguage: TNXFPCLanguageOptions;
    FOptimization: TNXFPCOptimizationOptions;
    FSyntax: TNXFPCSyntaxOptions;
    FTarget: TNXFPCTargetOptions;
    FUnits: TNXFPCUnitOptions;
    FVerbosity: TNXFPCVerbosityOptions;
    FLinking: TNXFPCLinkingOptions;
    FRawOptions: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AppendArguments(AArguments: TStrings); override;
    function BuildArguments: TStringList;

    property CompilerPath: string read FCompilerPath write FCompilerPath;
    property InputFile: string read FInputFile write FInputFile;
    property OutputFile: string read FOutputFile write FOutputFile;
    property BuildKind: TNXFPCBuildKind read FBuildKind write FBuildKind;
    property Config: TNXFPCConfigOptions read FConfig;
    property Assembler: TNXFPCAssemblerOptions read FAssembler;
    property BuildControl: TNXFPCBuildControlOptions read FBuildControl;
    property Definitions: TNXFPCDefinitionOptions read FDefinitions;
    property DefFile: TNXFPCDefFileOptions read FDefFile;
    property CodeGeneration: TNXFPCCodeGenerationOptions read FCodeGeneration;
    property Files: TNXFPCFileOptions read FFiles;
    property Debug: TNXFPCDebugOptions read FDebug;
    property Information: TNXFPCInformationOptions read FInformation;
    property Language: TNXFPCLanguageOptions read FLanguage;
    property Optimization: TNXFPCOptimizationOptions read FOptimization;
    property Syntax: TNXFPCSyntaxOptions read FSyntax;
    property Target: TNXFPCTargetOptions read FTarget;
    property Units: TNXFPCUnitOptions read FUnits;
    property Verbosity: TNXFPCVerbosityOptions read FVerbosity;
    property Linking: TNXFPCLinkingOptions read FLinking;
    property RawOptions: TStringList read FRawOptions;
  end;

function NXFPCSwitchSuffix(AState: TNXFPCSwitchState): string;
function NXFPCSwitchEnabled(AState: TNXFPCSwitchState): Boolean;
function NXFPCSwitchDisabled(AState: TNXFPCSwitchState): Boolean;
function NXFPCOperatingSystemWin64: string;
function NXFPCOperatingSystemLinux: string;
function NXFPCOperatingSystemDarwin: string;

implementation

procedure NXAddSwitch(AArguments: TStrings; const AOption: string; AState: TNXFPCSwitchState);
begin
  if AState = fssEnabled then
    AArguments.Add(AOption)
  else if AState = fssDisabled then
    AArguments.Add(AOption + '-');
end;

procedure NXAddBooleanSwitch(AArguments: TStrings; const AOption: string; AState: TNXFPCSwitchState);
begin
  if AState <> fssUnset then
    AArguments.Add(AOption + NXFPCSwitchSuffix(AState));
end;

procedure NXAddValue(AArguments: TStrings; const APrefix: string; const AValue: string);
begin
  if AValue <> '' then
    AArguments.Add(APrefix + AValue);
end;

procedure NXAddListValues(AArguments: TStrings; const APrefix: string; AValues: TStrings);
var
  lIndex: Integer;
begin
  for lIndex := 0 to AValues.Count - 1 do
    if AValues[lIndex] <> '' then
      AArguments.Add(APrefix + AValues[lIndex]);
end;

procedure NXAddRawList(AArguments: TStrings; AValues: TStrings);
var
  lIndex: Integer;
begin
  for lIndex := 0 to AValues.Count - 1 do
    if AValues[lIndex] <> '' then
      AArguments.Add(AValues[lIndex]);
end;

function NXFPCSwitchSuffix(AState: TNXFPCSwitchState): string;
begin
  Result := '';
  if AState = fssEnabled then
    Result := '+'
  else if AState = fssDisabled then
    Result := '-';
end;

function NXFPCSwitchEnabled(AState: TNXFPCSwitchState): Boolean;
begin
  Result := AState = fssEnabled;
end;

function NXFPCSwitchDisabled(AState: TNXFPCSwitchState): Boolean;
begin
  Result := AState = fssDisabled;
end;

function NXFPCOperatingSystemWin64: string;
begin
  Result := 'win64';
end;

function NXFPCOperatingSystemLinux: string;
begin
  Result := 'linux';
end;

function NXFPCOperatingSystemDarwin: string;
begin
  Result := 'darwin';
end;

procedure TNXFPCOptionSection.AppendArguments(AArguments: TStrings);
begin
end;

constructor TNXFPCConfigOptions.Create;
begin
  inherited Create;
  FOptionFiles := TStringList.Create;
end;

destructor TNXFPCConfigOptions.Destroy;
begin
  FOptionFiles.Free;
  inherited Destroy;
end;

procedure TNXFPCConfigOptions.AppendArguments(AArguments: TStrings);
begin
  if FDisableDefaultConfigFiles then
    AArguments.Add('-n');
  NXAddListValues(AArguments, '@', FOptionFiles);
end;

constructor TNXFPCAssemblerOptions.Create;
begin
  inherited Create;
  FExternalAssemblerOptions := TStringList.Create;
end;

destructor TNXFPCAssemblerOptions.Destroy;
begin
  FExternalAssemblerOptions.Free;
  inherited Destroy;
end;

procedure TNXFPCAssemblerOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-a', FPreserveAssemblerFile);
  NXAddSwitch(AArguments, '-a5', FGenerateBigObjCOFF);
  NXAddSwitch(AArguments, '-al', FListSourceLines);
  NXAddSwitch(AArguments, '-an', FListNodeInfo);
  NXAddListValues(AArguments, '-ao', FExternalAssemblerOptions);
  NXAddSwitch(AArguments, '-ap', FUsePipes);
  NXAddSwitch(AArguments, '-ar', FListRegisterInfo);
  NXAddSwitch(AArguments, '-at', FListTempInfo);
  NXAddValue(AArguments, '-A', FOutputFormat);
  NXAddValue(AArguments, '-R', FReadingStyle);
  NXAddSwitch(AArguments, '-sr', FSkipRegisterAllocation);
end;

procedure TNXFPCBuildControlOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-B', FBuildAllModules);
  NXAddSwitch(AArguments, '-b', FBrowserInfo);
  NXAddSwitch(AArguments, '-bl', FBrowserLocalSymbols);
  NXAddSwitch(AArguments, '-l', FWriteLogo);
  NXAddSwitch(AArguments, '-pg', FGenerateProfileCode);
end;

constructor TNXFPCDefinitionOptions.Create;
begin
  inherited Create;
  FDefines := TStringList.Create;
  FUndefines := TStringList.Create;
end;

destructor TNXFPCDefinitionOptions.Destroy;
begin
  FUndefines.Free;
  FDefines.Free;
  inherited Destroy;
end;

procedure TNXFPCDefinitionOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddListValues(AArguments, '-d', FDefines);
  NXAddListValues(AArguments, '-u', FUndefines);
end;

procedure TNXFPCDefFileOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-D', FGenerateDefFile);
  NXAddValue(AArguments, '-Dd', FDescription);
  NXAddValue(AArguments, '-Dv', FDllVersion);
end;

constructor TNXFPCCodeGenerationOptions.Create;
begin
  inherited Create;
  FPackingOptions := TStringList.Create;
  FTargetSpecificOptions := TStringList.Create;
end;

destructor TNXFPCCodeGenerationOptions.Destroy;
begin
  FTargetSpecificOptions.Free;
  FPackingOptions.Free;
  inherited Destroy;
end;

procedure TNXFPCCodeGenerationOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-C3', FIEEEConstantChecks);
  NXAddValue(AArguments, '-Ca', FABI);
  NXAddSwitch(AArguments, '-Cb', FBigEndianCode);
  NXAddValue(AArguments, '-Cc', FCallingConvention);
  NXAddSwitch(AArguments, '-CD', FDynamicLibrary);
  NXAddSwitch(AArguments, '-Ce', FEmulatedFloatingPoint);
  NXAddSwitch(AArguments, '-CE', FFloatingPointExceptions);
  NXAddValue(AArguments, '-Cf', FFPUInstructionSet);
  NXAddValue(AArguments, '-CF', FMinimumFloatConstantPrecision);
  NXAddSwitch(AArguments, '-Cg', FPositionIndependentCode);
  if FMinimumHeapSize > 0 then
  begin
    if FMaximumHeapSize > 0 then
      AArguments.Add('-Ch' + IntToStr(FMinimumHeapSize) + ',' + IntToStr(FMaximumHeapSize))
    else
      AArguments.Add('-Ch' + IntToStr(FMinimumHeapSize));
  end;
  NXAddSwitch(AArguments, '-Ci', FIOChecking);
  NXAddSwitch(AArguments, '-Cn', FOmitLinkingStage);
  NXAddSwitch(AArguments, '-Co', FOverflowChecking);
  NXAddSwitch(AArguments, '-CO', FPossibleOverflowChecking);
  NXAddValue(AArguments, '-Cp', FInstructionSet);
  NXAddListValues(AArguments, '-CP', FPackingOptions);
  NXAddSwitch(AArguments, '-Cr', FRangeChecking);
  NXAddSwitch(AArguments, '-CR', FObjectMethodCallValidityChecking);
  if FStackCheckingSize > 0 then
    AArguments.Add('-Cs' + IntToStr(FStackCheckingSize));
  NXAddSwitch(AArguments, '-Ct', FStackChecking);
  NXAddListValues(AArguments, '-CT', FTargetSpecificOptions);
  NXAddSwitch(AArguments, '-CX', FSmartLinkedLibrary);
end;

constructor TNXFPCFileOptions.Create;
begin
  inherited Create;
  FPreloadUnits := TStringList.Create;
  FFrameworkPaths := TStringList.Create;
  FIncludePaths := TStringList.Create;
  FLibraryPaths := TStringList.Create;
  FDefaultUnitScopes := TStringList.Create;
  FObjectPaths := TStringList.Create;
  FUnitPaths := TStringList.Create;
end;

destructor TNXFPCFileOptions.Destroy;
begin
  FUnitPaths.Free;
  FObjectPaths.Free;
  FDefaultUnitScopes.Free;
  FLibraryPaths.Free;
  FIncludePaths.Free;
  FFrameworkPaths.Free;
  FPreloadUnits.Free;
  inherited Destroy;
end;

procedure TNXFPCFileOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddValue(AArguments, '-e', FExecutableSearchPath);
  NXAddListValues(AArguments, '-Fa', FPreloadUnits);
  NXAddValue(AArguments, '-Fc', FInputCodePage);
  NXAddValue(AArguments, '-FC', FRCCompilerBinary);
  NXAddSwitch(AArguments, '-Fd', FDisableInternalDirectoryCache);
  NXAddValue(AArguments, '-FD', FCompilerUtilitiesPath);
  NXAddValue(AArguments, '-Fe', FErrorOutputFile);
  NXAddListValues(AArguments, '-Ff', FFrameworkPaths);
  NXAddValue(AArguments, '-FE', FExecutableOutputPath);
  NXAddListValues(AArguments, '-Fi', FIncludePaths);
  NXAddListValues(AArguments, '-I', FIncludePaths);
  NXAddListValues(AArguments, '-Fl', FLibraryPaths);
  NXAddValue(AArguments, '-FL', FDynamicLinker);
  NXAddValue(AArguments, '-Fm', FUnicodeConversionTable);
  NXAddValue(AArguments, '-FM', FUnicodeBinaryPath);
  NXAddListValues(AArguments, '-FN', FDefaultUnitScopes);
  NXAddListValues(AArguments, '-Fo', FObjectPaths);
  NXAddValue(AArguments, '-Fr', FErrorMessageFile);
  NXAddValue(AArguments, '-FR', FResourceLinker);
  NXAddListValues(AArguments, '-Fu', FUnitPaths);
  NXAddValue(AArguments, '-FU', FUnitOutputPath);
  NXAddValue(AArguments, '-FW', FWholeProgramFeedbackOutput);
  NXAddValue(AArguments, '-Fw', FWholeProgramFeedbackInput);
end;

constructor TNXFPCDebugOptions.Create;
begin
  inherited Create;
  FOptions := TStringList.Create;
end;

destructor TNXFPCDebugOptions.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

procedure TNXFPCDebugOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-g', FGenerateDebugInfo);
  NXAddSwitch(AArguments, '-gc', FPointerChecks);
  NXAddSwitch(AArguments, '-gh', FHeapTrace);
  NXAddSwitch(AArguments, '-gl', FLineInfo);
  if FFormat = fdfDefault then
    AArguments.Add('-g')
  else if FFormat = fdfStabs then
    AArguments.Add('-gs')
  else if FFormat = fdfDwarf2 then
    AArguments.Add('-gw2')
  else if FFormat = fdfDwarf3 then
    AArguments.Add('-gw3')
  else if FFormat = fdfDwarf4 then
    AArguments.Add('-gw4')
  else if FFormat = fdfCodeView then
    AArguments.Add('-gm');
  NXAddListValues(AArguments, '-go', FOptions);
  NXAddSwitch(AArguments, '-gp', FPreserveStabsCase);
  if FTrashLocalVariables > 0 then
    AArguments.Add('-g' + StringOfChar('t', FTrashLocalVariables));
  NXAddSwitch(AArguments, '-gv', FValgrind);
end;

procedure TNXFPCInformationOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-iD', FCompilerDate);
  NXAddSwitch(AArguments, '-iSO', FCompilerOS);
  NXAddSwitch(AArguments, '-iSP', FHostProcessor);
  NXAddSwitch(AArguments, '-iTO', FTargetOS);
  NXAddSwitch(AArguments, '-iTP', FTargetProcessor);
  NXAddSwitch(AArguments, '-iV', FShortCompilerVersion);
  NXAddSwitch(AArguments, '-iW', FFullCompilerVersion);
  NXAddSwitch(AArguments, '-ia', FSupportedABITargets);
  NXAddSwitch(AArguments, '-ic', FSupportedCPUInstructionSets);
  NXAddSwitch(AArguments, '-if', FSupportedFPUInstructionSets);
  NXAddSwitch(AArguments, '-ii', FSupportedInlineAssemblerModes);
  NXAddSwitch(AArguments, '-io', FSupportedOptimizations);
  NXAddSwitch(AArguments, '-ir', FRecognizedFeatures);
  NXAddSwitch(AArguments, '-it', FSupportedTargets);
  NXAddSwitch(AArguments, '-iu', FSupportedMicrocontrollerTypes);
  NXAddSwitch(AArguments, '-iw', FSupportedWholeProgramOptimizations);
end;

constructor TNXFPCLanguageOptions.Create;
begin
  inherited Create;
  FEnabledModeSwitches := TStringList.Create;
  FDisabledModeSwitches := TStringList.Create;
end;

destructor TNXFPCLanguageOptions.Destroy;
begin
  FDisabledModeSwitches.Free;
  FEnabledModeSwitches.Free;
  inherited Destroy;
end;

procedure TNXFPCLanguageOptions.AppendArguments(AArguments: TStrings);
var
  lIndex: Integer;
begin
  case FMode of
    flmFPC: AArguments.Add('-Mfpc');
    flmObjFPC: AArguments.Add('-Mobjfpc');
    flmDelphi: AArguments.Add('-Mdelphi');
    flmTP: AArguments.Add('-Mtp');
    flmMacPas: AArguments.Add('-Mmacpas');
    flmISO: AArguments.Add('-Miso');
    flmExtendedPascal: AArguments.Add('-Mextendedpascal');
    flmDelphiUnicode: AArguments.Add('-Mdelphiunicode');
  end;
  NXAddListValues(AArguments, '-M', FEnabledModeSwitches);
  for lIndex := 0 to FDisabledModeSwitches.Count - 1 do
    if FDisabledModeSwitches[lIndex] <> '' then
      AArguments.Add('-M' + FDisabledModeSwitches[lIndex] + '-');
end;

constructor TNXFPCOptimizationOptions.Create;
begin
  inherited Create;
  FAlignmentOptions := TStringList.Create;
  FEnabledOptimizations := TStringList.Create;
  FDisabledOptimizations := TStringList.Create;
  FWholeProgramFeedbackOptimizations := TStringList.Create;
  FWholeProgramUseOptimizations := TStringList.Create;
end;

destructor TNXFPCOptimizationOptions.Destroy;
begin
  FWholeProgramUseOptimizations.Free;
  FWholeProgramFeedbackOptimizations.Free;
  FDisabledOptimizations.Free;
  FEnabledOptimizations.Free;
  FAlignmentOptions.Free;
  inherited Destroy;
end;

procedure TNXFPCOptimizationOptions.AppendArguments(AArguments: TStrings);
var
  lIndex: Integer;
begin
  case FLevel of
    folDisabled: AArguments.Add('-O-');
    folLevel1: AArguments.Add('-O1');
    folLevel2: AArguments.Add('-O2');
    folLevel3: AArguments.Add('-O3');
    folLevel4: AArguments.Add('-O4');
  end;
  NXAddListValues(AArguments, '-Oa', FAlignmentOptions);
  for lIndex := 0 to FEnabledOptimizations.Count - 1 do
    if FEnabledOptimizations[lIndex] <> '' then
      AArguments.Add('-Oo' + FEnabledOptimizations[lIndex]);
  for lIndex := 0 to FDisabledOptimizations.Count - 1 do
    if FDisabledOptimizations[lIndex] <> '' then
      AArguments.Add('-OoNO' + FDisabledOptimizations[lIndex]);
  NXAddValue(AArguments, '-Op', FTargetCPU);
  NXAddListValues(AArguments, '-OW', FWholeProgramFeedbackOptimizations);
  NXAddListValues(AArguments, '-Ow', FWholeProgramUseOptimizations);
  NXAddSwitch(AArguments, '-Os', FOptimizeForSize);
end;

constructor TNXFPCSyntaxOptions.Create;
begin
  inherited Create;
  FFeatures := TStringList.Create;
end;

destructor TNXFPCSyntaxOptions.Destroy;
begin
  FFeatures.Free;
  inherited Destroy;
end;

procedure TNXFPCSyntaxOptions.AppendArguments(AArguments: TStrings);
var
  lErrorOptions: string;
begin
  NXAddSwitch(AArguments, '-S2', FObjFPCModeShortcut);
  NXAddSwitch(AArguments, '-Sd', FDelphiModeShortcut);
  NXAddSwitch(AArguments, '-So', FTurboPascalModeShortcut);
  NXAddSwitch(AArguments, '-Sa', FAssertions);
  NXAddSwitch(AArguments, '-Sc', FCOperators);
  lErrorOptions := '';
  if FErrorLimit > 0 then
    lErrorOptions := IntToStr(FErrorLimit);
  if FHaltAfterWarnings = fssEnabled then
    lErrorOptions := lErrorOptions + 'w';
  if FHaltAfterNotes = fssEnabled then
    lErrorOptions := lErrorOptions + 'n';
  if FHaltAfterHints = fssEnabled then
    lErrorOptions := lErrorOptions + 'h';
  if lErrorOptions <> '' then
    AArguments.Add('-Se' + lErrorOptions);
  NXAddListValues(AArguments, '-Sf', FFeatures);
  NXAddSwitch(AArguments, '-Sg', FLabelAndGoto);
  NXAddSwitch(AArguments, '-Sh', FReferenceCountedStrings);
  NXAddSwitch(AArguments, '-Si', FInlining);
  NXAddSwitch(AArguments, '-Sj', FWriteableTypedConstants);
  NXAddSwitch(AArguments, '-Sk', FLoadFpcylixUnit);
  NXAddValue(AArguments, '-SI', FInterfaceStyle);
  NXAddSwitch(AArguments, '-Sm', FMacros);
  NXAddSwitch(AArguments, '-Sr', FTransparentFileNames);
  NXAddSwitch(AArguments, '-Ss', FConstructorDestructorNameRules);
  NXAddSwitch(AArguments, '-Sv', FVectorProcessing);
  NXAddSwitch(AArguments, '-Sx', FExceptions);
  NXAddSwitch(AArguments, '-Sy', FTypedAddressOperator);
end;

constructor TNXFPCTargetOptions.Create;
begin
  inherited Create;
  FRawTargetOptions := TStringList.Create;
end;

destructor TNXFPCTargetOptions.Destroy;
begin
  FRawTargetOptions.Free;
  inherited Destroy;
end;

procedure TNXFPCTargetOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddValue(AArguments, '-T', FOperatingSystem);
  case FApplicationType of
    fatNative: AArguments.Add('-WA');
    fatConsole: AArguments.Add('-WC');
    fatGraphic: AArguments.Add('-WG');
  end;
  NXAddSwitch(AArguments, '-Wb', FCreateBundle);
  NXAddSwitch(AArguments, '-WB', FRelocatableImage);
  NXAddValue(AArguments, '-WB', FImageBase);
  NXAddSwitch(AArguments, '-WD', FUseDefFileExports);
  NXAddSwitch(AArguments, '-We', FUseExternalResources);
  NXAddSwitch(AArguments, '-Wi', FUseInternalResources);
  NXAddBooleanSwitch(AArguments, '-WI', FUseImportSections);
  NXAddValue(AArguments, '-WM', FMinimumMacOSVersion);
  NXAddSwitch(AArguments, '-WN', FNoRelocationCode);
  NXAddValue(AArguments, '-WP', FMinimumIOSVersion);
  NXAddSwitch(AArguments, '-WR', FGenerateRelocationCode);
  NXAddSwitch(AArguments, '-WX', FExecutableStack);
  NXAddRawList(AArguments, FRawTargetOptions);
end;

procedure TNXFPCUnitOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-Un', FDoNotCheckUnitNameMatchesFileName);
  NXAddSwitch(AArguments, '-Ur', FGenerateReleaseUnitFiles);
  NXAddSwitch(AArguments, '-Us', FCompileSystemUnit);
end;

constructor TNXFPCVerbosityOptions.Create;
begin
  inherited Create;
  FSuppressedMessages := TStringList.Create;
end;

destructor TNXFPCVerbosityOptions.Destroy;
begin
  FSuppressedMessages.Free;
  inherited Destroy;
end;

function TNXFPCVerbosityOptions.BuildVerbosityValue: string;
var
  lIndex: Integer;
begin
  Result := '';
  if FShowErrors = fssEnabled then Result := Result + 'e';
  if FShowWarnings = fssEnabled then Result := Result + 'w';
  if FShowNotes = fssEnabled then Result := Result + 'n';
  if FShowHints = fssEnabled then Result := Result + 'h';
  if FShowGeneralInfo = fssEnabled then Result := Result + 'i';
  if FShowLineNumbers = fssEnabled then Result := Result + 'l';
  if FShowEverything = fssEnabled then Result := Result + 'a';
  if FWriteFileNamesWithFullPath = fssEnabled then Result := Result + 'b';
  if FShowNothingExceptErrors = fssEnabled then Result := Result + '0';
  if FShowUnitInfo = fssEnabled then Result := Result + 'u';
  if FShowTriedFiles = fssEnabled then Result := Result + 't';
  if FShowConditionals = fssEnabled then Result := Result + 'c';
  if FShowDebugInfo = fssEnabled then Result := Result + 'd';
  if FRhideGCCCompatibilityMode = fssEnabled then Result := Result + 'r';
  if FShowTimeStamps = fssEnabled then Result := Result + 's';
  if FShowMessageNumbers = fssEnabled then Result := Result + 'q';
  if FShowInvokedTools = fssEnabled then Result := Result + 'x';
  if FWriteParseTreeLog = fssEnabled then Result := Result + 'p';
  if FWriteFPCDebugFile = fssEnabled then Result := Result + 'v';
  if FWriteOutputToStdErr = fssEnabled then Result := Result + 'z';
  for lIndex := 0 to FSuppressedMessages.Count - 1 do
    if FSuppressedMessages[lIndex] <> '' then
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + 'm' + FSuppressedMessages[lIndex];
    end;
end;

procedure TNXFPCVerbosityOptions.AppendArguments(AArguments: TStrings);
var
  lVerbosityValue: string;
begin
  lVerbosityValue := BuildVerbosityValue;
  if lVerbosityValue <> '' then
    AArguments.Add('-v' + lVerbosityValue);
end;

constructor TNXFPCLinkingOptions.Create;
begin
  inherited Create;
  FLinkerOptions := TStringList.Create;
  FLibrarySubstitutions := TStringList.Create;
  FLibraryOrder := TStringList.Create;
end;

destructor TNXFPCLinkingOptions.Destroy;
begin
  FLibraryOrder.Free;
  FLibrarySubstitutions.Free;
  FLinkerOptions.Free;
  inherited Destroy;
end;

procedure TNXFPCLinkingOptions.AppendArguments(AArguments: TStrings);
begin
  NXAddSwitch(AArguments, '-s', FDoNotCallAssemblerAndLinker);
  NXAddSwitch(AArguments, '-sh', FGenerateHostLinkScript);
  NXAddSwitch(AArguments, '-st', FGenerateTargetLinkScript);
  NXAddListValues(AArguments, '-k', FLinkerOptions);
  NXAddSwitch(AArguments, '-X9', FGenerateOldBinutilsLinkScript);
  NXAddSwitch(AArguments, '-Xc', FSharedDynamicLinking);
  NXAddSwitch(AArguments, '-Xd', FDoNotSearchDefaultLibraryPath);
  NXAddSwitch(AArguments, '-Xe', FExternalLinker);
  NXAddSwitch(AArguments, '-Xf', FSubstitutePThreadLibrary);
  NXAddSwitch(AArguments, '-Xg', FSeparateDebugInfo);
  NXAddSwitch(AArguments, '-XD', FDynamicUnits);
  NXAddSwitch(AArguments, '-Xi', FInternalLinker);
  NXAddListValues(AArguments, '-XLA', FLibrarySubstitutions);
  NXAddListValues(AArguments, '-XLO', FLibraryOrder);
  NXAddSwitch(AArguments, '-XLD', FExcludeDefaultLibraryOrder);
  NXAddSwitch(AArguments, '-Xm', FLinkMap);
  NXAddValue(AArguments, '-XM', FMainRoutineName);
  NXAddSwitch(AArguments, '-Xn', FNativeLinker);
  NXAddValue(AArguments, '-XP', FBinUtilsPrefix);
  NXAddValue(AArguments, '-Xr', FRuntimeLinkPath);
  NXAddValue(AArguments, '-XR', FLinkerSearchRoot);
  NXAddSwitch(AArguments, '-Xs', FStripSymbols);
  NXAddSwitch(AArguments, '-Xt', FStaticLibraryLinking);
  NXAddSwitch(AArguments, '-XS', FStaticUnits);
  NXAddSwitch(AArguments, '-Xv', FVirtualEntryCallTable);
  NXAddSwitch(AArguments, '-XV', FVLinkExternalLinker);
  NXAddSwitch(AArguments, '-XX', FSmartLinkedUnits);
end;

constructor TNXFPCBuildOptions.Create;
begin
  inherited Create;
  FConfig := TNXFPCConfigOptions.Create;
  FAssembler := TNXFPCAssemblerOptions.Create;
  FBuildControl := TNXFPCBuildControlOptions.Create;
  FDefinitions := TNXFPCDefinitionOptions.Create;
  FDefFile := TNXFPCDefFileOptions.Create;
  FCodeGeneration := TNXFPCCodeGenerationOptions.Create;
  FFiles := TNXFPCFileOptions.Create;
  FDebug := TNXFPCDebugOptions.Create;
  FInformation := TNXFPCInformationOptions.Create;
  FLanguage := TNXFPCLanguageOptions.Create;
  FOptimization := TNXFPCOptimizationOptions.Create;
  FSyntax := TNXFPCSyntaxOptions.Create;
  FTarget := TNXFPCTargetOptions.Create;
  FUnits := TNXFPCUnitOptions.Create;
  FVerbosity := TNXFPCVerbosityOptions.Create;
  FLinking := TNXFPCLinkingOptions.Create;
  FRawOptions := TStringList.Create;
end;

destructor TNXFPCBuildOptions.Destroy;
begin
  FRawOptions.Free;
  FLinking.Free;
  FVerbosity.Free;
  FUnits.Free;
  FTarget.Free;
  FSyntax.Free;
  FOptimization.Free;
  FLanguage.Free;
  FInformation.Free;
  FDebug.Free;
  FFiles.Free;
  FCodeGeneration.Free;
  FDefFile.Free;
  FDefinitions.Free;
  FBuildControl.Free;
  FAssembler.Free;
  FConfig.Free;
  inherited Destroy;
end;

procedure TNXFPCBuildOptions.AppendArguments(AArguments: TStrings);
begin
  FConfig.AppendArguments(AArguments);
  FAssembler.AppendArguments(AArguments);
  FBuildControl.AppendArguments(AArguments);
  FDefinitions.AppendArguments(AArguments);
  FDefFile.AppendArguments(AArguments);
  FCodeGeneration.AppendArguments(AArguments);
  FFiles.AppendArguments(AArguments);
  FDebug.AppendArguments(AArguments);
  FInformation.AppendArguments(AArguments);
  FLanguage.AppendArguments(AArguments);
  FOptimization.AppendArguments(AArguments);
  FSyntax.AppendArguments(AArguments);
  FTarget.AppendArguments(AArguments);
  FUnits.AppendArguments(AArguments);
  FVerbosity.AppendArguments(AArguments);
  FLinking.AppendArguments(AArguments);
  NXAddValue(AArguments, '-o', FOutputFile);
  NXAddRawList(AArguments, FRawOptions);
  if FInputFile <> '' then
    AArguments.Add(FInputFile);
end;

function TNXFPCBuildOptions.BuildArguments: TStringList;
begin
  Result := TStringList.Create;
  AppendArguments(Result);
end;

end.
