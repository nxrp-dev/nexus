unit obNXLSToolchainContracts;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXJSONRPCObjects,
  obNXJSONValues,
  obNXLSProtocolObjects,
  obNXLSProtocolParams;

type
  TNXLSToolchainField = class(TNXLSProjectField)
  private
    FValidators: TStringList;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure AddSuggestion(const AKind, ALabel, AValue, AReason: string);
    procedure AddValidator(const AValidatorName: string);
    procedure ApplyValidators;
    procedure Configure(const AId, ALabel, AType, AValue: string;
      ARequired: Boolean; const ADescription: string;
      const ABrowseLabel: string = '');
    function NormalizedValue: string; virtual;
    procedure SetInvalid(const ASeverity, AMessage: string);
    procedure SetValid;
  end;

  TNXLSToolchainFieldClass = class of TNXLSToolchainField;

  TNXLSToolchainKindField = class(TNXLSToolchainField)
  public
    procedure AddOption(const AValue, ALabel: string);
  end;

  TNXLSToolchainFieldValidator = class
  public
    class function Name: string; virtual; abstract;
    procedure Validate(AField: TNXLSToolchainField); virtual; abstract;
  end;

  TNXLSToolchainFieldValidatorClass = class of TNXLSToolchainFieldValidator;

  TNXLSExistingFolderValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSExistingFileValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSLazarusInstallValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSFreePascalInstallValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSAndroidSdkInstallValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSAndroidNdkInstallValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSJavaHomeInstallValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSLazarusInstallSuggestionValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSFreePascalInstallSuggestionValidator = class(
    TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSFreePascalCompilerSuggestionValidator = class(
    TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSAndroidSdkSuggestionValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSAndroidNdkInstallSuggestionValidator = class(
    TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSAndroidNdkDownloadSuggestionValidator = class(
    TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSJavaHomeSuggestionValidator = class(TNXLSToolchainFieldValidator)
  public
    class function Name: string; override;
    procedure Validate(AField: TNXLSToolchainField); override;
  end;

  TNXLSToolchain = class(TNXJSONRPCObjectParams)
  private
    Fenabled: TNXJSONRPCBoolean;
    Fkind: TNXJSONRPCString;
  public
    class function DescriptionText: string; virtual; abstract;
    class function KindText: string; virtual; abstract;
    class function LabelText: string; virtual; abstract;
    class function MatchesKind(const AKind: string): Boolean; virtual;
    class function CreateFromParams(
      AParams: TNXLSToolchainConfigureParams): TNXLSToolchain; virtual;

    function EnabledValue: Boolean;
    procedure LoadFromParams(AParams: TNXLSToolchainConfigureParams);
    procedure FillDescriptor(ADescriptor: TNXLSToolchainDescriptor); virtual;
    procedure FillFields(AFields: TNXLSProjectFieldArray); virtual;
    procedure FillRequestValue(AValue: TNXLSToolchainRequestValue); virtual;
    procedure FillDetails(ADetails: TNXLSProjectDetailArray); virtual;
    procedure FillNormalizedValues(
      AResult: TNXLSToolchainPlanConfigureResult); virtual;
    procedure ValidateFields(AFields: TNXLSProjectFieldArray); virtual;
    procedure Validate(AResult: TNXLSToolchainPlanConfigureResult;
      var ACanExecute: Boolean); virtual;
  published
    property enabled: TNXJSONRPCBoolean read Fenabled write Fenabled;
    property kind: TNXJSONRPCString read Fkind write Fkind;
  end;

  TNXLSToolchainClass = class of TNXLSToolchain;

  TNXLSLazarusToolchain = class(TNXLSToolchain)
  private
    FbundledFpcDirectory: TNXJSONRPCString;
    FlazarusDirectory: TNXJSONRPCString;
    FlazarusSourceDirectory: TNXJSONRPCString;
    FlazbuildPath: TNXJSONRPCString;
  public
    class function DescriptionText: string; override;
    class function KindText: string; override;
    class function LabelText: string; override;

    procedure ResolveDerivedValues;
    procedure FillFields(AFields: TNXLSProjectFieldArray); override;
    procedure FillRequestValue(AValue: TNXLSToolchainRequestValue); override;
    procedure FillDetails(ADetails: TNXLSProjectDetailArray); override;
    procedure FillNormalizedValues(
      AResult: TNXLSToolchainPlanConfigureResult); override;
    procedure Validate(AResult: TNXLSToolchainPlanConfigureResult;
      var ACanExecute: Boolean); override;
  published
    property bundledFpcDirectory: TNXJSONRPCString read FbundledFpcDirectory
      write FbundledFpcDirectory;
    property lazarusDirectory: TNXJSONRPCString read FlazarusDirectory
      write FlazarusDirectory;
    property lazarusSourceDirectory: TNXJSONRPCString read FlazarusSourceDirectory
      write FlazarusSourceDirectory;
    property lazbuildPath: TNXJSONRPCString read FlazbuildPath write FlazbuildPath;
  end;

  TNXLSFreePascalToolchain = class(TNXLSToolchain)
  private
    FcompilerPath: TNXJSONRPCString;
    FfpcDirectory: TNXJSONRPCString;
    FfpcSourceDirectory: TNXJSONRPCString;
    FresolvedCompilerPath: TNXJSONRPCString;
  public
    class function DescriptionText: string; override;
    class function KindText: string; override;
    class function LabelText: string; override;

    procedure ResolveDerivedValues;
    procedure FillFields(AFields: TNXLSProjectFieldArray); override;
    procedure FillRequestValue(AValue: TNXLSToolchainRequestValue); override;
    procedure FillDetails(ADetails: TNXLSProjectDetailArray); override;
    procedure FillNormalizedValues(
      AResult: TNXLSToolchainPlanConfigureResult); override;
    procedure Validate(AResult: TNXLSToolchainPlanConfigureResult;
      var ACanExecute: Boolean); override;
  published
    property compilerPath: TNXJSONRPCString read FcompilerPath write FcompilerPath;
    property fpcDirectory: TNXJSONRPCString read FfpcDirectory write FfpcDirectory;
    property fpcSourceDirectory: TNXJSONRPCString read FfpcSourceDirectory
      write FfpcSourceDirectory;
    property resolvedCompilerPath: TNXJSONRPCString read FresolvedCompilerPath
      write FresolvedCompilerPath;
  end;

  TNXLSAndroidToolchain = class(TNXLSToolchain)
  private
    FandroidNdkDirectory: TNXJSONRPCString;
    FandroidSdkDirectory: TNXJSONRPCString;
    FjavaHome: TNXJSONRPCString;
  public
    class function DescriptionText: string; override;
    class function KindText: string; override;
    class function LabelText: string; override;

    procedure FillFields(AFields: TNXLSProjectFieldArray); override;
    procedure FillRequestValue(AValue: TNXLSToolchainRequestValue); override;
    procedure FillDetails(ADetails: TNXLSProjectDetailArray); override;
    procedure FillNormalizedValues(
      AResult: TNXLSToolchainPlanConfigureResult); override;
    procedure Validate(AResult: TNXLSToolchainPlanConfigureResult;
      var ACanExecute: Boolean); override;
  published
    property androidNdkDirectory: TNXJSONRPCString read FandroidNdkDirectory
      write FandroidNdkDirectory;
    property androidSdkDirectory: TNXJSONRPCString read FandroidSdkDirectory
      write FandroidSdkDirectory;
    property javaHome: TNXJSONRPCString read FjavaHome write FjavaHome;
  end;

function NXLSFindToolchainClass(const AKind: string): TNXLSToolchainClass;
function NXLSFirstToolchainClass: TNXLSToolchainClass;
function NXLSToolchainClassCount: Integer;
function NXLSToolchainClassAt(AIndex: Integer): TNXLSToolchainClass;

implementation

uses
  SysUtils,
  fpjson,
  obNXLSToolchainSupport;

const
  cNXLSToolchainClasses: array[0..2] of TNXLSToolchainClass = (
    TNXLSLazarusToolchain,
    TNXLSFreePascalToolchain,
    TNXLSAndroidToolchain
  );

  cNXLSToolchainValidatorClasses: array[0..13] of TNXLSToolchainFieldValidatorClass = (
    TNXLSExistingFolderValidator,
    TNXLSExistingFileValidator,
    TNXLSLazarusInstallValidator,
    TNXLSFreePascalInstallValidator,
    TNXLSAndroidSdkInstallValidator,
    TNXLSAndroidNdkInstallValidator,
    TNXLSJavaHomeInstallValidator,
    TNXLSLazarusInstallSuggestionValidator,
    TNXLSFreePascalInstallSuggestionValidator,
    TNXLSFreePascalCompilerSuggestionValidator,
    TNXLSAndroidSdkSuggestionValidator,
    TNXLSAndroidNdkInstallSuggestionValidator,
    TNXLSAndroidNdkDownloadSuggestionValidator,
    TNXLSJavaHomeSuggestionValidator
  );

function NXLSCleanToolchainKind(const AKind: string): string;
begin
  Result := LowerCase(Trim(AKind));
end;

function NXLSFindToolchainValidatorClass(
  const AName: string): TNXLSToolchainFieldValidatorClass;
var
  lValidatorClass: TNXLSToolchainFieldValidatorClass;
begin
  Result := nil;
  for lValidatorClass in cNXLSToolchainValidatorClasses do
    if lValidatorClass.Name = AName then
      Exit(lValidatorClass);
end;

function NXLSToolchainFieldEmptyMessage(AField: TNXLSToolchainField): string;
begin
  if AField.id.Value = 'lazarusDirectory' then
    Result := 'Select a Lazarus install directory.'
  else if AField.id.Value = 'fpcDirectory' then
    Result := 'Select a Free Pascal directory.'
  else if AField.id.Value = 'androidSdkDirectory' then
    Result := 'Select an Android SDK directory.'
  else if AField.id.Value = 'androidNdkDirectory' then
    Result := 'Select an Android NDK directory.'
  else if AField.id.Value = 'javaHome' then
    Result := 'Select a Java Home directory.'
  else
    Result := 'Select a folder.';
end;

function NXLSToolchainFieldMissingFolderMessage(
  AField: TNXLSToolchainField): string;
begin
  if AField.id.Value = 'lazarusDirectory' then
    Result := 'The Lazarus directory does not exist.'
  else if AField.id.Value = 'fpcDirectory' then
    Result := 'The Free Pascal directory does not exist.'
  else if AField.id.Value = 'androidSdkDirectory' then
    Result := 'The Android SDK directory does not exist.'
  else if AField.id.Value = 'androidNdkDirectory' then
    Result := 'The Android NDK directory does not exist.'
  else if AField.id.Value = 'javaHome' then
    Result := 'The Java Home directory does not exist.'
  else
    Result := 'The selected folder does not exist.';
end;

function NXLSToolchainFieldMissingFileMessage(
  AField: TNXLSToolchainField): string;
begin
  if AField.id.Value = 'compilerPath' then
    Result := 'The compiler executable does not exist.'
  else
    Result := 'The selected file does not exist.';
end;

function NXLSAddToolchainField(AFields: TNXLSProjectFieldArray;
  AFieldClass: TNXLSToolchainFieldClass; const AId, ALabel, AType,
  AValue: string; ARequired: Boolean; const ADescription: string;
  const ABrowseLabel: string = ''): TNXLSToolchainField;
begin
  Result := TNXLSToolchainField(AFields.AddObject(AFieldClass));
  Result.Configure(AId, ALabel, AType, AValue, ARequired, ADescription,
    ABrowseLabel);
end;

procedure NXLSAddToolchainKindField(AFields: TNXLSProjectFieldArray;
  const AKind: string);
var
  lField: TNXLSToolchainKindField;
  lToolchainClass: TNXLSToolchainClass;
begin
  lField := TNXLSToolchainKindField(NXLSAddToolchainField(AFields,
    TNXLSToolchainKindField, 'kind', 'Toolchain', 'select', AKind, True,
    'Select the toolchain to configure.'));
  for lToolchainClass in cNXLSToolchainClasses do
    lField.AddOption(lToolchainClass.KindText,
      lToolchainClass.LabelText);
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

constructor TNXLSToolchainField.Create;
begin
  inherited Create;
  FValidators := TStringList.Create;
end;

destructor TNXLSToolchainField.Destroy;
begin
  FValidators.Free;
  inherited Destroy;
end;

procedure TNXLSToolchainField.AddSuggestion(const AKind, ALabel, AValue,
  AReason: string);
var
  lSuggestion: TNXLSProjectFieldSuggestion;
begin
  lSuggestion := TNXLSProjectFieldSuggestion(
    suggestions.AddObject(TNXLSProjectFieldSuggestion));
  lSuggestion.kind.Value := AKind;
  lSuggestion.&label.Value := ALabel;
  lSuggestion.value.Value := AValue;
  lSuggestion.reason.Value := AReason;
  lSuggestion.Assigned := True;
  suggestions.Assigned := True;
end;

procedure TNXLSToolchainField.AddValidator(const AValidatorName: string);
begin
  if FValidators.IndexOf(AValidatorName) < 0 then
    FValidators.Add(AValidatorName);
end;

procedure TNXLSToolchainField.ApplyValidators;
var
  lIndex: Integer;
  lValidator: TNXLSToolchainFieldValidator;
  lValidatorClass: TNXLSToolchainFieldValidatorClass;
begin
  SetValid;
  for lIndex := 0 to FValidators.Count - 1 do
  begin
    lValidatorClass := NXLSFindToolchainValidatorClass(FValidators[lIndex]);
    if lValidatorClass = nil then
      raise Exception.Create('Unknown toolchain field validator: ' +
        FValidators[lIndex]);

    lValidator := lValidatorClass.Create;
    try
      lValidator.Validate(Self);
    finally
      lValidator.Free;
    end;
  end;
end;

procedure TNXLSToolchainField.Configure(const AId, ALabel, AType,
  AValue: string; ARequired: Boolean; const ADescription: string;
  const ABrowseLabel: string);
begin
  id.Value := AId;
  &label.Value := ALabel;
  &type.Value := AType;
  value.Value := AValue;
  required.Value := ARequired;
  description.Value := ADescription;
  if ABrowseLabel <> '' then
    browseLabel.Value := ABrowseLabel;
  SetValid;
  Assigned := True;
end;

function TNXLSToolchainField.NormalizedValue: string;
begin
  if &type.Value = 'folder' then
    Result := NXLSCleanDirectory(value.Value)
  else if &type.Value = 'file' then
    Result := NXLSCleanFileName(value.Value)
  else
    Result := Trim(value.Value);
end;

procedure TNXLSToolchainField.SetInvalid(const ASeverity, AMessage: string);
begin
  valid.Value := False;
  severity.Value := ASeverity;
  message.Value := AMessage;
  Assigned := True;
end;

procedure TNXLSToolchainField.SetValid;
begin
  valid.Value := True;
  severity.Clear;
  message.Clear;
  Assigned := True;
end;

procedure TNXLSToolchainKindField.AddOption(const AValue, ALabel: string);
var
  lOption: TNXLSProjectFieldOption;
begin
  lOption := TNXLSProjectFieldOption(
    options.AddObject(TNXLSProjectFieldOption));
  lOption.value.Value := AValue;
  lOption.&label.Value := ALabel;
  lOption.Assigned := True;
  options.Assigned := True;
end;

class function TNXLSExistingFolderValidator.Name: string;
begin
  Result := 'existing-folder';
end;

procedure TNXLSExistingFolderValidator.Validate(AField: TNXLSToolchainField);
begin
  if AField.NormalizedValue = '' then
  begin
    if AField.required.Value then
      AField.SetInvalid('error', NXLSToolchainFieldEmptyMessage(AField));
    Exit;
  end;

  if not DirectoryExists(AField.NormalizedValue) then
    AField.SetInvalid('error', NXLSToolchainFieldMissingFolderMessage(AField));
end;

class function TNXLSExistingFileValidator.Name: string;
begin
  Result := 'existing-file';
end;

procedure TNXLSExistingFileValidator.Validate(AField: TNXLSToolchainField);
begin
  if AField.NormalizedValue = '' then
    Exit;

  if not FileExists(AField.NormalizedValue) then
    AField.SetInvalid('error', NXLSToolchainFieldMissingFileMessage(AField));
end;

class function TNXLSLazarusInstallValidator.Name: string;
begin
  Result := 'lazarus-install';
end;

procedure TNXLSLazarusInstallValidator.Validate(
  AField: TNXLSToolchainField);
var
  lLazbuildFile: string;
begin
  if (not AField.valid.Value) or (AField.NormalizedValue = '') then
    Exit;

  lLazbuildFile := NXLSToolchainLazbuildFile(AField.NormalizedValue);
  if not FileExists(lLazbuildFile) then
    AField.SetInvalid('error',
      'lazbuild was not found in the selected Lazarus directory.');
end;

class function TNXLSFreePascalInstallValidator.Name: string;
begin
  Result := 'freepascal-install';
end;

procedure TNXLSFreePascalInstallValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if (not AField.valid.Value) or (AField.NormalizedValue = '') then
    Exit;

  if NXLSToolchainFpcFile(AField.NormalizedValue) = '' then
    AField.SetInvalid('error',
      'fpc was not found in the selected Free Pascal directory.');
end;

class function TNXLSAndroidSdkInstallValidator.Name: string;
begin
  Result := 'android-sdk-install';
end;

procedure TNXLSAndroidSdkInstallValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if (not AField.valid.Value) or (AField.NormalizedValue = '') then
    Exit;

  if not FileExists(NXLSToolchainAndroidAdbFile(AField.NormalizedValue)) then
    AField.SetInvalid('error',
      'adb was not found under platform-tools in the selected Android SDK directory.');
end;

class function TNXLSAndroidNdkInstallValidator.Name: string;
begin
  Result := 'android-ndk-install';
end;

procedure TNXLSAndroidNdkInstallValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if (not AField.valid.Value) or (AField.NormalizedValue = '') then
    Exit;

  if (not FileExists(NXLSToolchainAndroidNdkBuildFile(
    AField.NormalizedValue))) or (not FileExists(NXLSToolchainFileInDirectory(
    AField.NormalizedValue, 'source.properties'))) then
    AField.SetInvalid('error',
      'ndk-build and source.properties were not found in the selected Android NDK directory.');
end;

class function TNXLSJavaHomeInstallValidator.Name: string;
begin
  Result := 'java-home-install';
end;

procedure TNXLSJavaHomeInstallValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if (not AField.valid.Value) or (AField.NormalizedValue = '') then
    Exit;

  if not FileExists(NXLSToolchainJavaFile(AField.NormalizedValue)) then
    AField.SetInvalid('error',
      'java was not found under bin in the selected Java Home directory.');
end;

class function TNXLSLazarusInstallSuggestionValidator.Name: string;
begin
  Result := 'lazarus-install-suggestion';
end;

procedure TNXLSLazarusInstallSuggestionValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if not AField.valid.Value then
    NXLSSuggestCommonLazarusInstallPaths(AField);
end;

class function TNXLSFreePascalInstallSuggestionValidator.Name: string;
begin
  Result := 'freepascal-install-suggestion';
end;

procedure TNXLSFreePascalInstallSuggestionValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if (AField.NormalizedValue = '') or (not AField.valid.Value) then
  begin
    NXLSSuggestCommonFpcInstallPaths(AField);
    NXLSAddDownloadSuggestion(AField, 'Download Free Pascal',
      cFpcDownloadsURL, 'No Free Pascal install directory was found.');
  end;
end;

class function TNXLSFreePascalCompilerSuggestionValidator.Name: string;
begin
  Result := 'freepascal-compiler-suggestion';
end;

procedure TNXLSFreePascalCompilerSuggestionValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if (AField.NormalizedValue = '') or (not AField.valid.Value) then
    NXLSSuggestCommonFpcCompilerPaths(AField);
end;

class function TNXLSAndroidSdkSuggestionValidator.Name: string;
begin
  Result := 'android-sdk-suggestion';
end;

procedure TNXLSAndroidSdkSuggestionValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if not AField.valid.Value then
  begin
    NXLSSuggestCommonAndroidSdkPaths(AField);
    NXLSAddDownloadSuggestion(AField, 'Download Android Studio',
      cAndroidSdkDownloadsURL,
      'No Android SDK was found. Android Studio can install and manage the SDK.');
  end;
end;

class function TNXLSAndroidNdkInstallSuggestionValidator.Name: string;
begin
  Result := 'android-ndk-install-suggestion';
end;

procedure TNXLSAndroidNdkInstallSuggestionValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if not AField.valid.Value then
    NXLSSuggestCommonAndroidNdkPaths(AField);
end;

class function TNXLSAndroidNdkDownloadSuggestionValidator.Name: string;
begin
  Result := 'android-ndk-download-suggestion';
end;

procedure TNXLSAndroidNdkDownloadSuggestionValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if not AField.valid.Value then
    AField.AddSuggestion('url', 'Download Android NDK', cAndroidNDKDownloadsURL,
      'No Android NDK was found in the selected directory.');
end;

class function TNXLSJavaHomeSuggestionValidator.Name: string;
begin
  Result := 'java-home-suggestion';
end;

procedure TNXLSJavaHomeSuggestionValidator.Validate(
  AField: TNXLSToolchainField);
begin
  if not AField.valid.Value then
  begin
    NXLSSuggestCommonJavaHomePaths(AField);
    NXLSAddDownloadSuggestion(AField, 'Download Microsoft OpenJDK',
      cJavaDownloadsURL, 'No Java Home directory was found.');
  end;
end;

function NXLSFindToolchainClass(const AKind: string): TNXLSToolchainClass;
var
  lKind: string;
  lToolchainClass: TNXLSToolchainClass;
begin
  Result := nil;
  lKind := NXLSCleanToolchainKind(AKind);
  if lKind = '' then
    Exit;

  for lToolchainClass in cNXLSToolchainClasses do
    if lToolchainClass.MatchesKind(lKind) then
      Exit(lToolchainClass);
end;

function NXLSFirstToolchainClass: TNXLSToolchainClass;
begin
  Result := cNXLSToolchainClasses[Low(cNXLSToolchainClasses)];
end;

function NXLSToolchainClassCount: Integer;
begin
  Result := Length(cNXLSToolchainClasses);
end;

function NXLSToolchainClassAt(AIndex: Integer): TNXLSToolchainClass;
begin
  if (AIndex < Low(cNXLSToolchainClasses)) or
    (AIndex > High(cNXLSToolchainClasses)) then
    raise Exception.Create('Toolchain class index is out of range.');

  Result := cNXLSToolchainClasses[AIndex];
end;

class function TNXLSToolchain.MatchesKind(const AKind: string): Boolean;
begin
  Result := AKind = KindText;
end;

class function TNXLSToolchain.CreateFromParams(
  AParams: TNXLSToolchainConfigureParams): TNXLSToolchain;
begin
  Result := Create;
  Result.LoadFromParams(AParams);
  if not Result.enabled.Assigned then
    Result.enabled.Value := True;
  Result.kind.Value := KindText;
end;

function TNXLSToolchain.EnabledValue: Boolean;
begin
  Result := True;
  if enabled.Assigned then
    Result := enabled.Value;
end;

procedure TNXLSToolchain.LoadFromParams(AParams: TNXLSToolchainConfigureParams);
var
  lData: TJSONData;
begin
  if AParams = nil then
    Exit;

  lData := AParams.ToJSONData;
  try
    FromJSONData(lData);
  finally
    lData.Free;
  end;
end;

procedure TNXLSToolchain.FillDescriptor(ADescriptor: TNXLSToolchainDescriptor);
begin
  ADescriptor.kind.Value := KindText;
  ADescriptor.&label.Value := LabelText;
  ADescriptor.description.Value := DescriptionText;
  ADescriptor.Assigned := True;
end;

procedure TNXLSToolchain.FillFields(AFields: TNXLSProjectFieldArray);
begin
  NXLSAddToolchainKindField(AFields, KindText);
  NXLSAddToolchainField(AFields, TNXLSToolchainField, 'enabled', 'Enabled',
    'checkbox',
    LowerCase(BoolToStr(EnabledValue, True)), False,
    'Enable this toolchain for Nexus Pascal operations.');
end;

procedure TNXLSToolchain.FillRequestValue(AValue: TNXLSToolchainRequestValue);
begin
  AValue.enabled.Value := EnabledValue;
  AValue.kind.Value := KindText;
  AValue.Assigned := True;
end;

procedure TNXLSToolchain.FillDetails(ADetails: TNXLSProjectDetailArray);
begin
  NXLSAddToolchainDetail(ADetails, 'Toolchain', KindText);
end;

procedure TNXLSToolchain.FillNormalizedValues(
  AResult: TNXLSToolchainPlanConfigureResult);
begin
  if AResult = nil then
    Exit;
end;

procedure TNXLSToolchain.ValidateFields(AFields: TNXLSProjectFieldArray);
var
  lField: TNXJSONValue;
  lIndex: Integer;
begin
  for lIndex := 0 to AFields.Count - 1 do
  begin
    lField := AFields[lIndex];
    if lField is TNXLSToolchainField then
      TNXLSToolchainField(lField).ApplyValidators;
  end;
end;

procedure TNXLSToolchain.Validate(AResult: TNXLSToolchainPlanConfigureResult;
  var ACanExecute: Boolean);
begin
  FillFields(AResult.fields);
  ValidateFields(AResult.fields);
end;

class function TNXLSLazarusToolchain.DescriptionText: string;
begin
  Result := 'Lazarus install root. Nexus Pascal derives lazbuild and bundled FPC paths from this toolchain.';
end;

class function TNXLSLazarusToolchain.KindText: string;
begin
  Result := 'lazarus';
end;

class function TNXLSLazarusToolchain.LabelText: string;
begin
  Result := 'Lazarus';
end;

procedure TNXLSLazarusToolchain.ResolveDerivedValues;
var
  lLazarusDirectory: string;
begin
  lLazarusDirectory := NXLSCleanDirectory(lazarusDirectory.Value);
  lazarusDirectory.Value := lLazarusDirectory;

  if lazarusSourceDirectory.Value = '' then
  begin
    if lLazarusDirectory <> '' then
      lazarusSourceDirectory.Value := lLazarusDirectory;
  end
  else
    lazarusSourceDirectory.Value := NXLSCleanDirectory(
      lazarusSourceDirectory.Value);

  if lazbuildPath.Value = '' then
  begin
    if lLazarusDirectory <> '' then
      lazbuildPath.Value := NXLSToolchainLazbuildFile(lLazarusDirectory);
  end
  else
    lazbuildPath.Value := NXLSCleanFileName(lazbuildPath.Value);

  if bundledFpcDirectory.Value = '' then
  begin
    if lLazarusDirectory <> '' then
      bundledFpcDirectory.Value :=
        NXLSToolchainBundledFpcDirectory(lLazarusDirectory);
  end
  else
    bundledFpcDirectory.Value := NXLSCleanDirectory(
      bundledFpcDirectory.Value);
end;

procedure TNXLSLazarusToolchain.FillFields(AFields: TNXLSProjectFieldArray);
var
  lField: TNXLSToolchainField;
begin
  ResolveDerivedValues;
  inherited FillFields(AFields);
  lField := NXLSAddToolchainField(AFields, TNXLSToolchainField,
    'lazarusDirectory', 'Lazarus Directory', 'folder',
    NXLSCleanDirectory(lazarusDirectory.Value), True,
    'The Lazarus install directory. Nexus Pascal derives lazbuild and bundled FPC paths from this location.',
    'Select Lazarus Directory');
  lField.AddValidator('existing-folder');
  lField.AddValidator('lazarus-install');
  lField.AddValidator('lazarus-install-suggestion');
  AFields.Assigned := True;
end;

procedure TNXLSLazarusToolchain.FillRequestValue(
  AValue: TNXLSToolchainRequestValue);
begin
  ResolveDerivedValues;
  inherited FillRequestValue(AValue);
  AValue.lazarusDirectory.Value := lazarusDirectory.Value;
end;

procedure TNXLSLazarusToolchain.FillDetails(
  ADetails: TNXLSProjectDetailArray);
begin
  ResolveDerivedValues;
  inherited FillDetails(ADetails);
  if lazarusDirectory.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Lazarus directory',
      lazarusDirectory.Value);
  if lazarusSourceDirectory.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Lazarus source directory',
      lazarusSourceDirectory.Value);
  if lazbuildPath.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'lazbuild', lazbuildPath.Value);
  if bundledFpcDirectory.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Bundled Free Pascal directory',
      bundledFpcDirectory.Value);
end;

procedure TNXLSLazarusToolchain.FillNormalizedValues(
  AResult: TNXLSToolchainPlanConfigureResult);
begin
  ResolveDerivedValues;
  AResult.normalizedLazarusDirectory.Value :=
    NXLSNormalizedPath(lazarusDirectory.Value);
end;

procedure TNXLSLazarusToolchain.Validate(
  AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean);
begin
  ResolveDerivedValues;
  inherited Validate(AResult, ACanExecute);
end;

class function TNXLSFreePascalToolchain.DescriptionText: string;
begin
  Result := 'Standalone Free Pascal install root or compiler executable.';
end;

class function TNXLSFreePascalToolchain.KindText: string;
begin
  Result := 'freepascal';
end;

class function TNXLSFreePascalToolchain.LabelText: string;
begin
  Result := 'Free Pascal';
end;

procedure TNXLSFreePascalToolchain.ResolveDerivedValues;
var
  lCompilerPath: string;
  lFpcDirectory: string;
begin
  lCompilerPath := NXLSCleanFileName(compilerPath.Value);
  lFpcDirectory := NXLSCleanDirectory(fpcDirectory.Value);

  if (lFpcDirectory = '') and (lCompilerPath <> '') then
    lFpcDirectory := NXLSToolchainFpcDirectoryFromCompilerPath(lCompilerPath);

  fpcDirectory.Value := lFpcDirectory;

  if resolvedCompilerPath.Value = '' then
  begin
    if lCompilerPath <> '' then
      resolvedCompilerPath.Value := lCompilerPath
    else
      resolvedCompilerPath.Value := NXLSToolchainFpcFile(lFpcDirectory);
  end
  else
    resolvedCompilerPath.Value := NXLSCleanFileName(resolvedCompilerPath.Value);

  if fpcSourceDirectory.Value = '' then
  begin
    if lFpcDirectory <> '' then
      fpcSourceDirectory.Value :=
        IncludeTrailingPathDelimiter(lFpcDirectory) + 'source';
  end
  else
    fpcSourceDirectory.Value := NXLSCleanDirectory(fpcSourceDirectory.Value);
end;

procedure TNXLSFreePascalToolchain.FillFields(AFields: TNXLSProjectFieldArray);
var
  lField: TNXLSToolchainField;
begin
  ResolveDerivedValues;
  inherited FillFields(AFields);
  lField := NXLSAddToolchainField(AFields, TNXLSToolchainField,
    'fpcDirectory', 'Free Pascal Directory', 'folder',
    NXLSCleanDirectory(fpcDirectory.Value), False,
    'The Free Pascal install directory. Nexus Pascal derives compiler and source paths from this location when possible.',
    'Select Free Pascal Directory');
  lField.AddValidator('existing-folder');
  lField.AddValidator('freepascal-install');
  lField.AddValidator('freepascal-install-suggestion');
  lField := NXLSAddToolchainField(AFields, TNXLSToolchainField,
    'compilerPath', 'Compiler Path', 'file',
    NXLSCleanFileName(compilerPath.Value), False,
    'Optional explicit fpc compiler executable for nonstandard installs.',
    'Select fpc');
  lField.AddValidator('existing-file');
  lField.AddValidator('freepascal-compiler-suggestion');
  AFields.Assigned := True;
end;

procedure TNXLSFreePascalToolchain.FillRequestValue(
  AValue: TNXLSToolchainRequestValue);
begin
  ResolveDerivedValues;
  inherited FillRequestValue(AValue);
  AValue.fpcDirectory.Value := fpcDirectory.Value;
  AValue.compilerPath.Value := compilerPath.Value;
end;

procedure TNXLSFreePascalToolchain.FillDetails(
  ADetails: TNXLSProjectDetailArray);
begin
  ResolveDerivedValues;
  inherited FillDetails(ADetails);
  if fpcDirectory.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Free Pascal directory',
      fpcDirectory.Value);
  if compilerPath.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Compiler path', compilerPath.Value);
  if fpcSourceDirectory.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Free Pascal source directory',
      fpcSourceDirectory.Value);
  if resolvedCompilerPath.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Resolved compiler path',
      resolvedCompilerPath.Value);
end;

procedure TNXLSFreePascalToolchain.FillNormalizedValues(
  AResult: TNXLSToolchainPlanConfigureResult);
begin
  ResolveDerivedValues;
  AResult.normalizedFpcDirectory.Value := NXLSNormalizedPath(fpcDirectory.Value);
  AResult.normalizedCompilerPath.Value := NXLSNormalizedPath(compilerPath.Value);
end;

procedure TNXLSFreePascalToolchain.Validate(
  AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean);
var
  lCompilerPath: string;
  lFpcDirectory: string;
begin
  ResolveDerivedValues;
  inherited Validate(AResult, ACanExecute);
  lCompilerPath := NXLSCleanFileName(compilerPath.Value);
  lFpcDirectory := NXLSCleanDirectory(fpcDirectory.Value);
  if (lFpcDirectory = '') and (lCompilerPath = '') then
    NXLSAddToolchainMessage(AResult.messages, 'warning',
      'Select a Free Pascal directory or compiler executable.');
end;

class function TNXLSAndroidToolchain.DescriptionText: string;
begin
  Result := 'Android SDK, NDK, and Java paths for future Android build/debug support.';
end;

class function TNXLSAndroidToolchain.KindText: string;
begin
  Result := 'android';
end;

class function TNXLSAndroidToolchain.LabelText: string;
begin
  Result := 'Android';
end;

procedure TNXLSAndroidToolchain.FillFields(AFields: TNXLSProjectFieldArray);
var
  lField: TNXLSToolchainField;
begin
  inherited FillFields(AFields);
  lField := NXLSAddToolchainField(AFields, TNXLSToolchainField,
    'androidSdkDirectory', 'Android SDK Directory', 'folder',
    NXLSCleanDirectory(androidSdkDirectory.Value), True,
    'The Android SDK install directory.',
    'Select Android SDK Directory');
  lField.AddValidator('existing-folder');
  lField.AddValidator('android-sdk-install');
  lField.AddValidator('android-sdk-suggestion');
  lField := NXLSAddToolchainField(AFields, TNXLSToolchainField,
    'androidNdkDirectory', 'Android NDK Directory', 'folder',
    NXLSCleanDirectory(androidNdkDirectory.Value), True,
    'The Android NDK install directory used for native builds.',
    'Select Android NDK Directory');
  lField.AddValidator('existing-folder');
  lField.AddValidator('android-ndk-install');
  lField.AddValidator('android-ndk-install-suggestion');
  lField.AddValidator('android-ndk-download-suggestion');
  lField := NXLSAddToolchainField(AFields, TNXLSToolchainField,
    'javaHome', 'Java Home', 'folder', NXLSCleanDirectory(javaHome.Value), True,
    'The JDK root used by Android build tooling.',
    'Select Java Home');
  lField.AddValidator('existing-folder');
  lField.AddValidator('java-home-install');
  lField.AddValidator('java-home-suggestion');
  AFields.Assigned := True;
end;

procedure TNXLSAndroidToolchain.FillRequestValue(
  AValue: TNXLSToolchainRequestValue);
begin
  inherited FillRequestValue(AValue);
  AValue.androidSdkDirectory.Value := androidSdkDirectory.Value;
  AValue.androidNdkDirectory.Value := androidNdkDirectory.Value;
  AValue.javaHome.Value := javaHome.Value;
end;

procedure TNXLSAndroidToolchain.FillDetails(ADetails: TNXLSProjectDetailArray);
begin
  inherited FillDetails(ADetails);
  if androidSdkDirectory.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Android SDK', androidSdkDirectory.Value);
  if androidNdkDirectory.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Android NDK', androidNdkDirectory.Value);
  if javaHome.Value <> '' then
    NXLSAddToolchainDetail(ADetails, 'Java Home', javaHome.Value);
end;

procedure TNXLSAndroidToolchain.FillNormalizedValues(
  AResult: TNXLSToolchainPlanConfigureResult);
begin
  AResult.normalizedAndroidSdkDirectory.Value :=
    NXLSNormalizedPath(androidSdkDirectory.Value);
  AResult.normalizedAndroidNdkDirectory.Value :=
    NXLSNormalizedPath(androidNdkDirectory.Value);
  AResult.normalizedJavaHome.Value := NXLSNormalizedPath(javaHome.Value);
end;

procedure TNXLSAndroidToolchain.Validate(
  AResult: TNXLSToolchainPlanConfigureResult; var ACanExecute: Boolean);
begin
  inherited Validate(AResult, ACanExecute);
end;

end.
