unit obNXLSToolchainProtocol;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProjectProtocol;

type
  TNXLSToolchainConfigureParams = class(TNXJSONRPCObjectParams)
  private
    FandroidNdkDirectory: TNXJSONString;
    FandroidSdkDirectory: TNXJSONString;
    FcompilerPath: TNXJSONString;
    Fenabled: TNXJSONBoolean;
    FfpcDirectory: TNXJSONString;
    FjavaHome: TNXJSONString;
    Fkind: TNXJSONString;
    FlazarusDirectory: TNXJSONString;
  published
    property androidNdkDirectory: TNXJSONString read FandroidNdkDirectory write FandroidNdkDirectory;
    property androidSdkDirectory: TNXJSONString read FandroidSdkDirectory write FandroidSdkDirectory;
    property compilerPath: TNXJSONString read FcompilerPath write FcompilerPath;
    property enabled: TNXJSONBoolean read Fenabled write Fenabled;
    property fpcDirectory: TNXJSONString read FfpcDirectory write FfpcDirectory;
    property javaHome: TNXJSONString read FjavaHome write FjavaHome;
    property kind: TNXJSONString read Fkind write Fkind;
    property lazarusDirectory: TNXJSONString read FlazarusDirectory write FlazarusDirectory;
  end;

  TNXLSToolchainRequestValue = class(TNXJSONObject)
  private
    FandroidNdkDirectory: TNXJSONString;
    FandroidSdkDirectory: TNXJSONString;
    FcompilerPath: TNXJSONString;
    Fenabled: TNXJSONBoolean;
    FfpcDirectory: TNXJSONString;
    FjavaHome: TNXJSONString;
    Fkind: TNXJSONString;
    FlazarusDirectory: TNXJSONString;
  published
    property androidNdkDirectory: TNXJSONString read FandroidNdkDirectory write FandroidNdkDirectory;
    property androidSdkDirectory: TNXJSONString read FandroidSdkDirectory write FandroidSdkDirectory;
    property compilerPath: TNXJSONString read FcompilerPath write FcompilerPath;
    property enabled: TNXJSONBoolean read Fenabled write Fenabled;
    property fpcDirectory: TNXJSONString read FfpcDirectory write FfpcDirectory;
    property javaHome: TNXJSONString read FjavaHome write FjavaHome;
    property kind: TNXJSONString read Fkind write Fkind;
    property lazarusDirectory: TNXJSONString read FlazarusDirectory write FlazarusDirectory;
  end;

  TNXLSToolchainDescriptor = class(TNXJSONObject)
  private
    Fkind: TNXJSONString;
    Flabel: TNXJSONString;
    Fdescription: TNXJSONString;
  published
    property kind: TNXJSONString read Fkind write Fkind;
    property &label: TNXJSONString read Flabel write Flabel;
    property description: TNXJSONString read Fdescription write Fdescription;
  end;

  TNXLSToolchainDescriptorArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSToolchainListSupportedResult = class(TNXJSONObject)
  private
    Ftoolchains: TNXLSToolchainDescriptorArray;
  published
    property toolchains: TNXLSToolchainDescriptorArray read Ftoolchains write Ftoolchains;
  end;

  TNXLSToolchainConfigureWizardResult = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Frequest: TNXLSToolchainRequestValue;
    Ffields: TNXLSProjectFieldArray;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property request: TNXLSToolchainRequestValue read Frequest write Frequest;
    property fields: TNXLSProjectFieldArray read Ffields write Ffields;
  end;

  TNXLSToolchainPlanConfigureResult = class(TNXJSONObject)
  private
    Ftitle: TNXJSONString;
    Fsummary: TNXJSONString;
    FcanExecute: TNXJSONBoolean;
    Fmessages: TNXLSProjectMessageArray;
    Fdetails: TNXLSProjectDetailArray;
    Ffields: TNXLSProjectFieldArray;
    FnormalizedLazarusDirectory: TNXJSONString;
    FnormalizedFpcDirectory: TNXJSONString;
    FnormalizedCompilerPath: TNXJSONString;
    FnormalizedAndroidSdkDirectory: TNXJSONString;
    FnormalizedAndroidNdkDirectory: TNXJSONString;
    FnormalizedJavaHome: TNXJSONString;
  published
    property title: TNXJSONString read Ftitle write Ftitle;
    property summary: TNXJSONString read Fsummary write Fsummary;
    property canExecute: TNXJSONBoolean read FcanExecute write FcanExecute;
    property messages: TNXLSProjectMessageArray read Fmessages write Fmessages;
    property details: TNXLSProjectDetailArray read Fdetails write Fdetails;
    property fields: TNXLSProjectFieldArray read Ffields write Ffields;
    property normalizedLazarusDirectory: TNXJSONString read FnormalizedLazarusDirectory write FnormalizedLazarusDirectory;
    property normalizedFpcDirectory: TNXJSONString read FnormalizedFpcDirectory write FnormalizedFpcDirectory;
    property normalizedCompilerPath: TNXJSONString read FnormalizedCompilerPath write FnormalizedCompilerPath;
    property normalizedAndroidSdkDirectory: TNXJSONString read FnormalizedAndroidSdkDirectory write FnormalizedAndroidSdkDirectory;
    property normalizedAndroidNdkDirectory: TNXJSONString read FnormalizedAndroidNdkDirectory write FnormalizedAndroidNdkDirectory;
    property normalizedJavaHome: TNXJSONString read FnormalizedJavaHome write FnormalizedJavaHome;
  end;

implementation

class function TNXLSToolchainDescriptorArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSToolchainDescriptor;
end;

end.
