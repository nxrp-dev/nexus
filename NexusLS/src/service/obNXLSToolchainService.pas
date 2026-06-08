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
  SysUtils,
  obNXLSToolchainContracts;

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

function NXLSHasInvalidToolchainField(
  AFields: TNXLSProjectFieldArray): Boolean;
var
  lField: TNXLSProjectField;
  lIndex: Integer;
begin
  Result := False;
  if AFields = nil then
    Exit;

  for lIndex := 0 to AFields.Count - 1 do
  begin
    lField := TNXLSProjectField(AFields[lIndex]);
    if lField.valid.Assigned and (not lField.valid.Value) then
      Exit(True);
  end;
end;

function NXLSToolchainClassForParams(
  AParams: TNXLSToolchainConfigureParams): TNXLSToolchainClass;
var
  lHasKind: Boolean;
begin
  Result := nil;
  lHasKind := (AParams <> nil) and AParams.kind.Assigned and
    (Trim(AParams.kind.Value) <> '');
  if lHasKind then
    Result := NXLSFindToolchainClass(AParams.kind.Value);

  if (not lHasKind) and (Result = nil) then
    Result := NXLSFirstToolchainClass;
end;

class procedure TNXLSToolchainService.FillListSupported(
  AResult: TNXLSToolchainListSupportedResult);
var
  lIndex: Integer;
  lToolchain: TNXLSToolchain;
  lToolchainDescriptor: TNXLSToolchainDescriptor;
begin
  if AResult = nil then
    Exit;

  for lIndex := 0 to NXLSToolchainClassCount - 1 do
  begin
    lToolchain := NXLSToolchainClassAt(lIndex).Create;
    try
      lToolchainDescriptor := TNXLSToolchainDescriptor(
        AResult.toolchains.AddObject(TNXLSToolchainDescriptor));
      lToolchain.FillDescriptor(lToolchainDescriptor);
    finally
      lToolchain.Free;
    end;
  end;

  AResult.toolchains.Assigned := True;
  AResult.Assigned := True;
end;

class procedure TNXLSToolchainService.FillConfigureWizard(
  AParams: TNXLSToolchainConfigureParams;
  AResult: TNXLSToolchainConfigureWizardResult);
var
  lToolchain: TNXLSToolchain;
  lToolchainClass: TNXLSToolchainClass;
begin
  if AResult = nil then
    Exit;

  lToolchainClass := NXLSToolchainClassForParams(AParams);
  if lToolchainClass = nil then
  begin
    AResult.title.Value := 'Configure Toolchain';
    AResult.Assigned := True;
    Exit;
  end;

  lToolchain := lToolchainClass.CreateFromParams(AParams);
  try
    AResult.title.Value := 'Configure Toolchain';
    lToolchain.FillRequestValue(AResult.request);
    lToolchain.FillFields(AResult.fields);
    AResult.Assigned := True;
  finally
    lToolchain.Free;
  end;
end;

class procedure TNXLSToolchainService.FillPlanConfigure(
  AParams: TNXLSToolchainConfigureParams;
  AResult: TNXLSToolchainPlanConfigureResult);
var
  lCanExecute: Boolean;
  lToolchain: TNXLSToolchain;
  lToolchainClass: TNXLSToolchainClass;
begin
  if AResult = nil then
    Exit;

  lToolchainClass := NXLSToolchainClassForParams(AParams);
  if lToolchainClass = nil then
  begin
    AResult.title.Value := 'Configure Toolchain';
    AResult.summary.Value := 'Unknown toolchain.';
    AResult.canExecute.Value := False;
    NXLSAddToolchainMessage(AResult.messages, 'error',
      'The selected toolchain is not supported.');
    AResult.messages.Assigned := True;
    AResult.Assigned := True;
    Exit;
  end;

  lToolchain := lToolchainClass.CreateFromParams(AParams);
  try
    lCanExecute := True;
    if not lToolchain.EnabledValue then
    begin
      NXLSAddToolchainMessage(AResult.messages, 'info',
        'The selected toolchain will be disabled.');
      lToolchain.FillFields(AResult.fields);
    end
    else
      lToolchain.Validate(AResult, lCanExecute);

    if lCanExecute then
    begin
      if NXLSHasInvalidToolchainField(AResult.fields) then
        NXLSAddToolchainMessage(AResult.messages, 'warning',
          'The selected toolchain settings can be saved, but some fields need attention.')
      else
        NXLSAddToolchainMessage(AResult.messages, 'info',
          'The selected toolchain settings are ready to save.');
    end;

    AResult.title.Value := 'Configure Toolchain';
    AResult.summary.Value := 'Save toolchain settings for Nexus Pascal.';
    AResult.canExecute.Value := lCanExecute;

    lToolchain.FillNormalizedValues(AResult);
    lToolchain.FillDetails(AResult.details);

    AResult.messages.Assigned := True;
    AResult.details.Assigned := True;
    AResult.Assigned := True;
  finally
    lToolchain.Free;
  end;
end;

end.
