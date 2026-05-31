unit obNXLSCommandRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSCompleteCodeRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCompleteCodeParams;
    procedure SetParams(AValue: TNXLSCompleteCodeParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCompleteCodeParams read GetParams write SetParams;
  end;

  TNXLSInvertAssignmentRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSInvertAssignmentParams;
    procedure SetParams(AValue: TNXLSInvertAssignmentParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSInvertAssignmentParams read GetParams write SetParams;
  end;

  TNXLSRemoveEmptyMethodsRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSRemoveEmptyMethodsParams;
    procedure SetParams(AValue: TNXLSRemoveEmptyMethodsParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSRemoveEmptyMethodsParams read GetParams write SetParams;
  end;

  TNXLSRemoveUnusedUnitsRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSRemoveUnusedUnitsParams;
    procedure SetParams(AValue: TNXLSRemoveUnusedUnitsParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSRemoveUnusedUnitsParams read GetParams write SetParams;
  end;

  TNXLSProjectCreateWizardRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSProjectCreateWizardResult;
    procedure SetResult(AValue: TNXLSProjectCreateWizardResult);
    function GetParams: TNXLSProjectCreateWizardParams;
    procedure SetParams(AValue: TNXLSProjectCreateWizardParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSProjectCreateWizardResult read GetResult write SetResult;
    property params: TNXLSProjectCreateWizardParams read GetParams write SetParams;
  end;

  TNXLSProjectPlanCreateRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSProjectPlanCreateResult;
    procedure SetResult(AValue: TNXLSProjectPlanCreateResult);
    function GetParams: TNXLSProjectCreateParams;
    procedure SetParams(AValue: TNXLSProjectCreateParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSProjectPlanCreateResult read GetResult write SetResult;
    property params: TNXLSProjectCreateParams read GetParams write SetParams;
  end;

  TNXLSProjectCreateRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSProjectCreateResult;
    procedure SetResult(AValue: TNXLSProjectCreateResult);
    function GetParams: TNXLSProjectCreateParams;
    procedure SetParams(AValue: TNXLSProjectCreateParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSProjectCreateResult read GetResult write SetResult;
    property params: TNXLSProjectCreateParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  obNXLSProjectService,
  utNXLSCommandNames;

class function TNXLSCompleteCodeRequest.GetFactoryName: string;
begin
  Result := cNXLSCommandCompleteCode;
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

function TNXLSProjectCreateRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSProjectCreateResult;
begin
  lResult := TNXLSProjectCreateResult(PrepareResult);
  TNXLSProjectService.FillCreateNexusProject(TNXLSProjectCreateParams(params),
    lResult);
  Result := lResult;
end;

function TNXLSProjectPlanCreateRequest.GetParams: TNXLSProjectCreateParams;
begin
  Result := TNXLSProjectCreateParams(inherited params);
end;

procedure TNXLSProjectPlanCreateRequest.SetParams(AValue: TNXLSProjectCreateParams);
begin
  inherited params := AValue;
end;

function TNXLSRemoveUnusedUnitsRequest.GetParams: TNXLSRemoveUnusedUnitsParams;
begin
  Result := TNXLSRemoveUnusedUnitsParams(inherited params);
end;

procedure TNXLSRemoveUnusedUnitsRequest.SetParams(AValue: TNXLSRemoveUnusedUnitsParams);
begin
  inherited params := AValue;
end;

function TNXLSCompleteCodeRequest.GetParams: TNXLSCompleteCodeParams;
begin
  Result := TNXLSCompleteCodeParams(inherited params);
end;

procedure TNXLSCompleteCodeRequest.SetParams(AValue: TNXLSCompleteCodeParams);
begin
  inherited params := AValue;
end;

function TNXLSProjectCreateWizardRequest.GetParams: TNXLSProjectCreateWizardParams;
begin
  Result := TNXLSProjectCreateWizardParams(inherited params);
end;

procedure TNXLSProjectCreateWizardRequest.SetParams(AValue: TNXLSProjectCreateWizardParams);
begin
  inherited params := AValue;
end;

function TNXLSInvertAssignmentRequest.GetParams: TNXLSInvertAssignmentParams;
begin
  Result := TNXLSInvertAssignmentParams(inherited params);
end;

procedure TNXLSInvertAssignmentRequest.SetParams(AValue: TNXLSInvertAssignmentParams);
begin
  inherited params := AValue;
end;

function TNXLSRemoveEmptyMethodsRequest.GetParams: TNXLSRemoveEmptyMethodsParams;
begin
  Result := TNXLSRemoveEmptyMethodsParams(inherited params);
end;

procedure TNXLSRemoveEmptyMethodsRequest.SetParams(AValue: TNXLSRemoveEmptyMethodsParams);
begin
  inherited params := AValue;
end;

function TNXLSProjectCreateRequest.GetParams: TNXLSProjectCreateParams;
begin
  Result := TNXLSProjectCreateParams(inherited params);
end;

procedure TNXLSProjectCreateRequest.SetParams(AValue: TNXLSProjectCreateParams);
begin
  inherited params := AValue;
end;

function TNXLSProjectCreateWizardRequest.GetResult: TNXLSProjectCreateWizardResult;
begin
  Result := TNXLSProjectCreateWizardResult(inherited result);
end;

procedure TNXLSProjectCreateWizardRequest.SetResult(AValue: TNXLSProjectCreateWizardResult);
begin
  inherited result := AValue;
end;

function TNXLSProjectPlanCreateRequest.GetResult: TNXLSProjectPlanCreateResult;
begin
  Result := TNXLSProjectPlanCreateResult(inherited result);
end;

procedure TNXLSProjectPlanCreateRequest.SetResult(AValue: TNXLSProjectPlanCreateResult);
begin
  inherited result := AValue;
end;

function TNXLSProjectCreateRequest.GetResult: TNXLSProjectCreateResult;
begin
  Result := TNXLSProjectCreateResult(inherited result);
end;

procedure TNXLSProjectCreateRequest.SetResult(AValue: TNXLSProjectCreateResult);
begin
  inherited result := AValue;
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
