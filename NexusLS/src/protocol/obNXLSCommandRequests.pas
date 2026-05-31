unit obNXLSCommandRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSCompleteCodeRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSInvertAssignmentRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSRemoveEmptyMethodsRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSRemoveUnusedUnitsRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSProjectCreateWizardRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSProjectPlanCreateRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSProjectCreateRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProjectService,
  obNXLSProtocolObjects,
  obNXLSProtocolParams,
  utNXLSCommandNames;

class function TNXLSCompleteCodeRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandCompleteCode;
end;

class function TNXLSCompleteCodeRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCompleteCodeParams;
end;

class function TNXLSCompleteCodeRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSCompleteCodeRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Commands.CompleteCode(TNXLSCompleteCodeParams(params));
  Result := PrepareResult;
end;

class function TNXLSInvertAssignmentRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandInvertAssignment;
end;

class function TNXLSInvertAssignmentRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSInvertAssignmentParams;
end;

class function TNXLSInvertAssignmentRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSInvertAssignmentRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Commands.InvertAssignment(
    TNXLSInvertAssignmentParams(params));
  Result := PrepareResult;
end;

class function TNXLSRemoveEmptyMethodsRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandRemoveEmptyMethods;
end;

class function TNXLSRemoveEmptyMethodsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSRemoveEmptyMethodsParams;
end;

class function TNXLSRemoveEmptyMethodsRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSRemoveEmptyMethodsRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Commands.RemoveEmptyMethods(
    TNXLSRemoveEmptyMethodsParams(params));
  Result := PrepareResult;
end;

class function TNXLSRemoveUnusedUnitsRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandRemoveUnusedUnits;
end;

class function TNXLSRemoveUnusedUnitsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSRemoveUnusedUnitsParams;
end;

class function TNXLSRemoveUnusedUnitsRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSRemoveUnusedUnitsRequest.Execute: TNXJSONValue;
begin
  TNXLSLSPModel.Current.Commands.RemoveUnusedUnits(
    TNXLSRemoveUnusedUnitsParams(params));
  Result := PrepareResult;
end;

class function TNXLSProjectCreateWizardRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandNexusProjectCreateWizard;
end;

class function TNXLSProjectCreateWizardRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSProjectCreateWizardParams;
end;

class function TNXLSProjectCreateWizardRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSProjectCreateWizardResult;
end;

function TNXLSProjectCreateWizardRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSProjectCreateWizardResult;
begin
  lResult := TNXLSProjectCreateWizardResult(PrepareResult);
  TNXLSProjectService.FillCreateNexusProjectWizard(
    TNXLSProjectCreateWizardParams(params), lResult);
  Result := lResult;
end;

class function TNXLSProjectPlanCreateRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandNexusProjectPlanCreate;
end;

class function TNXLSProjectPlanCreateRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSProjectCreateParams;
end;

class function TNXLSProjectPlanCreateRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSProjectPlanCreateResult;
end;

function TNXLSProjectPlanCreateRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSProjectPlanCreateResult;
begin
  lResult := TNXLSProjectPlanCreateResult(PrepareResult);
  TNXLSProjectService.FillPlanNexusProjectCreate(
    TNXLSProjectCreateParams(params), lResult);
  Result := lResult;
end;

class function TNXLSProjectCreateRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandNexusProjectCreate;
end;

class function TNXLSProjectCreateRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSProjectCreateParams;
end;

class function TNXLSProjectCreateRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSProjectCreateResult;
end;

function TNXLSProjectCreateRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSProjectCreateResult;
begin
  lResult := TNXLSProjectCreateResult(PrepareResult);
  TNXLSProjectService.FillCreateNexusProject(TNXLSProjectCreateParams(params),
    lResult);
  Result := lResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSCompleteCodeRequest);
  TNXClassFactory.RegisterClass(TNXLSInvertAssignmentRequest);
  TNXClassFactory.RegisterClass(TNXLSRemoveEmptyMethodsRequest);
  TNXClassFactory.RegisterClass(TNXLSRemoveUnusedUnitsRequest);
  TNXClassFactory.RegisterClass(TNXLSProjectCreateWizardRequest);
  TNXClassFactory.RegisterClass(TNXLSProjectPlanCreateRequest);
  TNXClassFactory.RegisterClass(TNXLSProjectCreateRequest);

end.
