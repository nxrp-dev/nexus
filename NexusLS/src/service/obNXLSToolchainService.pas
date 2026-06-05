unit obNXLSToolchainService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolObjects,
  obNXLSProtocolParams;

type
  TNXLSToolchainService = class
  public
    class procedure FillListSupported(AResult: TNXLSToolchainListSupportedResult);
    class procedure FillConfigureWizard(AParams: TNXLSToolchainConfigureParams;
      AResult: TNXLSToolchainConfigureWizardResult);
    class procedure FillPlanConfigure(AParams: TNXLSToolchainConfigureParams;
      AResult: TNXLSToolchainPlanConfigureResult);
  end;

implementation

uses
  SysUtils;

type
  TNXLSToolchainRequestData = record
    AndroidNdkDirectory: string;
    AndroidSdkDirectory: string;
    CompilerPath: string;
    Enabled: Boolean;
    FpcDirectory: string;
    JavaHome: string;
    Kind: string;
    LazarusDirectory: string;
  end;

  TNXLSToolchainDefinition = class
  public
    class function Kind: string; virtual; abstract;
    class function LabelText: string; virtual; abstract;
    class function DescriptionText: string; virtual; abstract;
    class function MatchesKind(const AKind: string): Boolean; virtual;
    class procedure FillFields(AFields: TNXLSProjectFieldArray;
      const ARequest: TNXLSToolchainRequestData); virtual; abstract;
    class procedure Validate(const ARequest: TNXLSToolchainRequestData;
      AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean); virtual; abstract;
  end;

  TNXLSToolchainDefinitionClass = class of TNXLSToolchainDefinition;

  TNXLSLazarusToolchainDefinition = class(TNXLSToolchainDefinition)
  public
    class function Kind: string; override;
    class function LabelText: string; override;
    class function DescriptionText: string; override;
    class procedure FillFields(AFields: TNXLSProjectFieldArray;
      const ARequest: TNXLSToolchainRequestData); override;
    class procedure Validate(const ARequest: TNXLSToolchainRequestData;
      AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean); override;
  end;

  TNXLSFreePascalToolchainDefinition = class(TNXLSToolchainDefinition)
  public
    class function Kind: string; override;
    class function LabelText: string; override;
    class function DescriptionText: string; override;
    class function MatchesKind(const AKind: string): Boolean; override;
    class procedure FillFields(AFields: TNXLSProjectFieldArray;
      const ARequest: TNXLSToolchainRequestData); override;
    class procedure Validate(const ARequest: TNXLSToolchainRequestData;
      AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean); override;
  end;

  TNXLSAndroidToolchainDefinition = class(TNXLSToolchainDefinition)
  public
    class function Kind: string; override;
    class function LabelText: string; override;
    class function DescriptionText: string; override;
    class procedure FillFields(AFields: TNXLSProjectFieldArray;
      const ARequest: TNXLSToolchainRequestData); override;
    class procedure Validate(const ARequest: TNXLSToolchainRequestData;
      AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean); override;
  end;

const
  cNXLSToolchainDefinitions: array[0..2] of TNXLSToolchainDefinitionClass = (
    TNXLSLazarusToolchainDefinition,
    TNXLSFreePascalToolchainDefinition,
    TNXLSAndroidToolchainDefinition
  );

procedure NXLSAddToolchainField(AFields: TNXLSProjectFieldArray; const AId,
  ALabel, AType, AValue: string; ARequired: Boolean; const ADescription: string;
  const ABrowseLabel: string = '');
var
  lField: TNXLSProjectField;
begin
  lField := TNXLSProjectField(AFields.AddObject(TNXLSProjectField));
  lField.id.Value := AId;
  lField.&label.Value := ALabel;
  lField.&type.Value := AType;
  lField.value.Value := AValue;
  lField.required.Value := ARequired;
  lField.description.Value := ADescription;
  if ABrowseLabel <> '' then
    lField.browseLabel.Value := ABrowseLabel;
  lField.Assigned := True;
end;

procedure NXLSAddToolchainOption(AField: TNXLSProjectField; const AValue,
  ALabel: string);
var
  lOption: TNXLSProjectFieldOption;
begin
  lOption := TNXLSProjectFieldOption(
    AField.options.AddObject(TNXLSProjectFieldOption));
  lOption.value.Value := AValue;
  lOption.&label.Value := ALabel;
  lOption.Assigned := True;
  AField.options.Assigned := True;
end;

procedure NXLSAddToolchainKindField(AFields: TNXLSProjectFieldArray;
  const AKind: string);
var
  lField: TNXLSProjectField;
begin
  lField := TNXLSProjectField(AFields.AddObject(TNXLSProjectField));
  lField.id.Value := 'kind';
  lField.&label.Value := 'Toolchain';
  lField.&type.Value := 'select';
  lField.value.Value := AKind;
  lField.required.Value := True;
  lField.description.Value := 'Select the toolchain to configure.';
  NXLSAddToolchainOption(lField, 'lazarus', 'Lazarus');
  NXLSAddToolchainOption(lField, 'freepascal', 'Free Pascal');
  NXLSAddToolchainOption(lField, 'android', 'Android');
  lField.Assigned := True;
end;

procedure NXLSAddToolchainMessage(AMessages: TNXLSProjectMessageArray;
  const ASeverity, AText: string);
var
  lMessage: TNXLSProjectMessage;
begin
  lMessage := TNXLSProjectMessage(AMessages.AddObject(TNXLSProjectMessage));
  lMessage.severity.Value := ASeverity;
  lMessage.text.Value := AText;
  lMessage.Assigned := True;
end;

procedure NXLSAddToolchainDetail(ADetails: TNXLSProjectDetailArray;
  const ALabel, AValue: string);
var
  lDetail: TNXLSProjectDetail;
begin
  lDetail := TNXLSProjectDetail(ADetails.AddObject(TNXLSProjectDetail));
  lDetail.&label.Value := ALabel;
  lDetail.value.Value := AValue;
  lDetail.Assigned := True;
end;

procedure NXLSAddToolchainDescriptor(AToolchains: TNXLSToolchainDescriptorArray;
  const AKind, ALabel, ADescription: string);
var
  lToolchain: TNXLSToolchainDescriptor;
begin
  lToolchain := TNXLSToolchainDescriptor(
    AToolchains.AddObject(TNXLSToolchainDescriptor));
  lToolchain.kind.Value := AKind;
  lToolchain.&label.Value := ALabel;
  lToolchain.description.Value := ADescription;
  lToolchain.Assigned := True;
end;

function NXLSCleanToolchainKind(const AKind: string): string;
var
  lDefinition: TNXLSToolchainDefinitionClass;
begin
  Result := LowerCase(Trim(AKind));
  if Result = '' then
    Exit(TNXLSLazarusToolchainDefinition.Kind);

  for lDefinition in cNXLSToolchainDefinitions do
  begin
    if lDefinition.MatchesKind(Result) then
      Exit(lDefinition.Kind);
  end;

  Result := TNXLSLazarusToolchainDefinition.Kind;
end;

function NXLSCleanDirectory(const ADirectory: string): string;
begin
  Result := Trim(ADirectory);
  if Result <> '' then
    Result := ExpandFileName(Result);
end;

function NXLSCleanFileName(const AFileName: string): string;
begin
  Result := Trim(AFileName);
  if Result <> '' then
    Result := ExpandFileName(Result);
end;

function NXLSToolchainLazbuildFile(const ALazarusDirectory: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ALazarusDirectory) + 'lazbuild';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

procedure NXLSFillCommonToolchainFields(AFields: TNXLSProjectFieldArray;
  const AKind: string; AEnabled: Boolean);
begin
  NXLSAddToolchainKindField(AFields, AKind);
  NXLSAddToolchainField(AFields, 'enabled', 'Enabled', 'checkbox',
    LowerCase(BoolToStr(AEnabled, True)), False,
    'Enable this toolchain for Nexus Pascal operations.');
end;

procedure NXLSFillLazarusToolchainFields(AFields: TNXLSProjectFieldArray;
  AEnabled: Boolean; const ALazarusDirectory: string);
begin
  NXLSFillCommonToolchainFields(AFields, 'lazarus', AEnabled);
  NXLSAddToolchainField(AFields, 'lazarusDirectory', 'Lazarus Directory',
    'folder', ALazarusDirectory, True,
    'The Lazarus install directory. Nexus Pascal derives lazbuild and bundled FPC paths from this location.',
    'Select Lazarus Directory');
  AFields.Assigned := True;
end;

procedure NXLSFillFreePascalToolchainFields(AFields: TNXLSProjectFieldArray;
  AEnabled: Boolean; const AFpcDirectory, ACompilerPath: string);
begin
  NXLSFillCommonToolchainFields(AFields, 'freepascal', AEnabled);
  NXLSAddToolchainField(AFields, 'fpcDirectory', 'Free Pascal Directory',
    'folder', AFpcDirectory, False,
    'The Free Pascal install directory. Nexus Pascal derives compiler and source paths from this location when possible.',
    'Select Free Pascal Directory');
  NXLSAddToolchainField(AFields, 'compilerPath', 'Compiler Path',
    'file', ACompilerPath, False,
    'Optional explicit fpc compiler executable for nonstandard installs.',
    'Select fpc');
  AFields.Assigned := True;
end;

procedure NXLSFillAndroidToolchainFields(AFields: TNXLSProjectFieldArray;
  AEnabled: Boolean; const ASdkDirectory, ANdkDirectory, AJavaHome: string);
begin
  NXLSFillCommonToolchainFields(AFields, 'android', AEnabled);
  NXLSAddToolchainField(AFields, 'androidSdkDirectory', 'Android SDK Directory',
    'folder', ASdkDirectory, True,
    'The Android SDK install directory.',
    'Select Android SDK Directory');
  NXLSAddToolchainField(AFields, 'androidNdkDirectory', 'Android NDK Directory',
    'folder', ANdkDirectory, True,
    'The Android NDK install directory used for native builds.',
    'Select Android NDK Directory');
  NXLSAddToolchainField(AFields, 'javaHome', 'Java Home',
    'folder', AJavaHome, True,
    'The JDK root used by Android build tooling.',
    'Select Java Home');
  AFields.Assigned := True;
end;

function NXLSParamEnabled(AParams: TNXLSToolchainConfigureParams): Boolean;
begin
  Result := True;
  if (AParams <> nil) and AParams.enabled.Assigned then
    Result := AParams.enabled.Value;
end;

function NXLSFindToolchainDefinition(
  const AKind: string): TNXLSToolchainDefinitionClass;
var
  lKind: string;
  lDefinition: TNXLSToolchainDefinitionClass;
begin
  lKind := NXLSCleanToolchainKind(AKind);
  for lDefinition in cNXLSToolchainDefinitions do
  begin
    if lDefinition.Kind = lKind then
      Exit(lDefinition);
  end;

  Result := TNXLSLazarusToolchainDefinition;
end;

function NXLSReadToolchainRequest(
  AParams: TNXLSToolchainConfigureParams): TNXLSToolchainRequestData;
begin
  Result.AndroidNdkDirectory := '';
  Result.AndroidSdkDirectory := '';
  Result.CompilerPath := '';
  Result.FpcDirectory := '';
  Result.JavaHome := '';
  Result.LazarusDirectory := '';
  Result.Kind := TNXLSLazarusToolchainDefinition.Kind;
  Result.Enabled := NXLSParamEnabled(AParams);
  if AParams <> nil then
  begin
    Result.Kind := NXLSCleanToolchainKind(AParams.kind.Value);
    Result.LazarusDirectory := NXLSCleanDirectory(AParams.lazarusDirectory.Value);
    Result.FpcDirectory := NXLSCleanDirectory(AParams.fpcDirectory.Value);
    Result.CompilerPath := NXLSCleanFileName(AParams.compilerPath.Value);
    Result.AndroidSdkDirectory := NXLSCleanDirectory(AParams.androidSdkDirectory.Value);
    Result.AndroidNdkDirectory := NXLSCleanDirectory(AParams.androidNdkDirectory.Value);
    Result.JavaHome := NXLSCleanDirectory(AParams.javaHome.Value);
  end;
end;

procedure NXLSFillToolchainRequestValue(AValue: TNXLSToolchainRequestValue;
  const ARequest: TNXLSToolchainRequestData);
begin
  AValue.enabled.Value := ARequest.Enabled;
  AValue.kind.Value := ARequest.Kind;
  AValue.lazarusDirectory.Value := ARequest.LazarusDirectory;
  AValue.fpcDirectory.Value := ARequest.FpcDirectory;
  AValue.compilerPath.Value := ARequest.CompilerPath;
  AValue.androidSdkDirectory.Value := ARequest.AndroidSdkDirectory;
  AValue.androidNdkDirectory.Value := ARequest.AndroidNdkDirectory;
  AValue.javaHome.Value := ARequest.JavaHome;
  AValue.Assigned := True;
end;

procedure NXLSFillToolchainFields(ADefinition: TNXLSToolchainDefinitionClass;
  AFields: TNXLSProjectFieldArray; const ARequest: TNXLSToolchainRequestData);
begin
  ADefinition.FillFields(AFields, ARequest);
end;

procedure NXLSFillToolchainDetails(AResult: TNXLSToolchainPlanConfigureResult;
  const ARequest: TNXLSToolchainRequestData);
begin
  NXLSAddToolchainDetail(AResult.details, 'Toolchain', ARequest.Kind);
  if ARequest.LazarusDirectory <> '' then
    NXLSAddToolchainDetail(AResult.details, 'Lazarus directory',
      ARequest.LazarusDirectory);
  if ARequest.FpcDirectory <> '' then
    NXLSAddToolchainDetail(AResult.details, 'Free Pascal directory',
      ARequest.FpcDirectory);
  if ARequest.CompilerPath <> '' then
    NXLSAddToolchainDetail(AResult.details, 'Compiler path', ARequest.CompilerPath);
  if ARequest.AndroidSdkDirectory <> '' then
    NXLSAddToolchainDetail(AResult.details, 'Android SDK',
      ARequest.AndroidSdkDirectory);
  if ARequest.AndroidNdkDirectory <> '' then
    NXLSAddToolchainDetail(AResult.details, 'Android NDK',
      ARequest.AndroidNdkDirectory);
  if ARequest.JavaHome <> '' then
    NXLSAddToolchainDetail(AResult.details, 'Java Home', ARequest.JavaHome);
end;

class function TNXLSToolchainDefinition.MatchesKind(const AKind: string): Boolean;
begin
  Result := AKind = Kind;
end;

class function TNXLSLazarusToolchainDefinition.Kind: string;
begin
  Result := 'lazarus';
end;

class function TNXLSLazarusToolchainDefinition.LabelText: string;
begin
  Result := 'Lazarus';
end;

class function TNXLSLazarusToolchainDefinition.DescriptionText: string;
begin
  Result := 'Lazarus install root. Nexus Pascal derives lazbuild and bundled FPC paths from this toolchain.';
end;

class procedure TNXLSLazarusToolchainDefinition.FillFields(
  AFields: TNXLSProjectFieldArray; const ARequest: TNXLSToolchainRequestData);
begin
  NXLSFillLazarusToolchainFields(AFields, ARequest.Enabled,
    ARequest.LazarusDirectory);
end;

class procedure TNXLSLazarusToolchainDefinition.Validate(
  const ARequest: TNXLSToolchainRequestData;
  AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean);
var
  lLazbuildFile: string;
begin
  if ARequest.LazarusDirectory = '' then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'Select a Lazarus install directory.');
    ACanExecute := False;
  end
  else if not DirectoryExists(ARequest.LazarusDirectory) then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'The Lazarus directory does not exist.');
    ACanExecute := False;
  end
  else
  begin
    lLazbuildFile := NXLSToolchainLazbuildFile(ARequest.LazarusDirectory);
    if not FileExists(lLazbuildFile) then
    begin
      NXLSAddToolchainMessage(AResult.messages, 'error',
        'lazbuild was not found in the selected Lazarus directory.');
      ACanExecute := False;
    end
    else
      NXLSAddToolchainDetail(AResult.details, 'lazbuild', lLazbuildFile);
  end;
end;

class function TNXLSFreePascalToolchainDefinition.Kind: string;
begin
  Result := 'freepascal';
end;

class function TNXLSFreePascalToolchainDefinition.LabelText: string;
begin
  Result := 'Free Pascal';
end;

class function TNXLSFreePascalToolchainDefinition.DescriptionText: string;
begin
  Result := 'Standalone Free Pascal install root or compiler executable.';
end;

class function TNXLSFreePascalToolchainDefinition.MatchesKind(
  const AKind: string): Boolean;
begin
  Result := inherited MatchesKind(AKind) or (AKind = 'fpc') or
    (AKind = 'free-pascal');
end;

class procedure TNXLSFreePascalToolchainDefinition.FillFields(
  AFields: TNXLSProjectFieldArray; const ARequest: TNXLSToolchainRequestData);
begin
  NXLSFillFreePascalToolchainFields(AFields, ARequest.Enabled,
    ARequest.FpcDirectory, ARequest.CompilerPath);
end;

class procedure TNXLSFreePascalToolchainDefinition.Validate(
  const ARequest: TNXLSToolchainRequestData;
  AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean);
begin
  if (ARequest.FpcDirectory = '') and (ARequest.CompilerPath = '') then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'Select a Free Pascal directory or compiler executable.');
    ACanExecute := False;
  end;
  if (ARequest.FpcDirectory <> '') and not DirectoryExists(ARequest.FpcDirectory) then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'The Free Pascal directory does not exist.');
    ACanExecute := False;
  end;
  if (ARequest.CompilerPath <> '') and not FileExists(ARequest.CompilerPath) then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'The compiler executable does not exist.');
    ACanExecute := False;
  end;
end;

class function TNXLSAndroidToolchainDefinition.Kind: string;
begin
  Result := 'android';
end;

class function TNXLSAndroidToolchainDefinition.LabelText: string;
begin
  Result := 'Android';
end;

class function TNXLSAndroidToolchainDefinition.DescriptionText: string;
begin
  Result := 'Android SDK, NDK, and Java paths for future Android build/debug support.';
end;

class procedure TNXLSAndroidToolchainDefinition.FillFields(
  AFields: TNXLSProjectFieldArray; const ARequest: TNXLSToolchainRequestData);
begin
  NXLSFillAndroidToolchainFields(AFields, ARequest.Enabled,
    ARequest.AndroidSdkDirectory, ARequest.AndroidNdkDirectory, ARequest.JavaHome);
end;

class procedure TNXLSAndroidToolchainDefinition.Validate(
  const ARequest: TNXLSToolchainRequestData;
  AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean);
begin
  if (ARequest.AndroidSdkDirectory = '') or
    not DirectoryExists(ARequest.AndroidSdkDirectory) then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'Select an existing Android SDK directory.');
    ACanExecute := False;
  end;
  if (ARequest.AndroidNdkDirectory = '') or
    not DirectoryExists(ARequest.AndroidNdkDirectory) then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'Select an existing Android NDK directory.');
    ACanExecute := False;
  end;
  if (ARequest.JavaHome = '') or not DirectoryExists(ARequest.JavaHome) then
  begin
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'Select an existing Java Home directory.');
    ACanExecute := False;
  end;
end;

class procedure TNXLSToolchainService.FillListSupported(
  AResult: TNXLSToolchainListSupportedResult);
var
  lDefinition: TNXLSToolchainDefinitionClass;
begin
  if AResult = nil then
    Exit;

  for lDefinition in cNXLSToolchainDefinitions do
    NXLSAddToolchainDescriptor(AResult.toolchains, lDefinition.Kind,
      lDefinition.LabelText, lDefinition.DescriptionText);
  AResult.toolchains.Assigned := True;
  AResult.Assigned := True;
end;

class procedure TNXLSToolchainService.FillConfigureWizard(
  AParams: TNXLSToolchainConfigureParams;
  AResult: TNXLSToolchainConfigureWizardResult);
var
  lDefinition: TNXLSToolchainDefinitionClass;
  lRequest: TNXLSToolchainRequestData;
begin
  if AResult = nil then
    Exit;

  lRequest := NXLSReadToolchainRequest(AParams);
  lDefinition := NXLSFindToolchainDefinition(lRequest.Kind);

  AResult.title.Value := 'Configure Toolchain';
  NXLSFillToolchainRequestValue(AResult.request, lRequest);
  NXLSFillToolchainFields(lDefinition, AResult.fields, lRequest);

  AResult.Assigned := True;
end;

class procedure TNXLSToolchainService.FillPlanConfigure(
  AParams: TNXLSToolchainConfigureParams;
  AResult: TNXLSToolchainPlanConfigureResult);
var
  lCanExecute: Boolean;
  lDefinition: TNXLSToolchainDefinitionClass;
  lRequest: TNXLSToolchainRequestData;
begin
  if AResult = nil then
    Exit;

  lRequest := NXLSReadToolchainRequest(AParams);
  lDefinition := NXLSFindToolchainDefinition(lRequest.Kind);
  lCanExecute := True;
  if not lRequest.Enabled then
    NXLSAddToolchainMessage(AResult.messages, 'info',
    'The selected toolchain will be disabled.')
  else
    lDefinition.Validate(lRequest, AResult, lCanExecute);

  if lCanExecute then
    NXLSAddToolchainMessage(AResult.messages, 'info',
      'The selected toolchain settings are ready to save.');

  AResult.title.Value := 'Configure Toolchain';
  AResult.summary.Value := 'Save toolchain settings for Nexus Pascal.';
  AResult.canExecute.Value := lCanExecute;
  AResult.normalizedLazarusDirectory.Value := lRequest.LazarusDirectory;
  AResult.normalizedFpcDirectory.Value := lRequest.FpcDirectory;
  AResult.normalizedCompilerPath.Value := lRequest.CompilerPath;
  AResult.normalizedAndroidSdkDirectory.Value := lRequest.AndroidSdkDirectory;
  AResult.normalizedAndroidNdkDirectory.Value := lRequest.AndroidNdkDirectory;
  AResult.normalizedJavaHome.Value := lRequest.JavaHome;

  NXLSFillToolchainFields(lDefinition, AResult.fields, lRequest);
  NXLSFillToolchainDetails(AResult, lRequest);

  AResult.messages.Assigned := True;
  AResult.details.Assigned := True;
  AResult.Assigned := True;
end;

end.
