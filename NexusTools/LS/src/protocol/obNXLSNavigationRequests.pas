unit obNXLSNavigationRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues,
  obNXJSONRPCObjects,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSDocumentSyncParams,
  obNXLSProtocolObjects;

type
  TNXLSTextDocumentDeclarationRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLocation;
    procedure SetResult(AValue: TNXLSLocation);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSLocation read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDefinitionRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLocation;
    procedure SetResult(AValue: TNXLSLocation);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSLocation read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentTypeDefinitionRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLocation;
    procedure SetResult(AValue: TNXLSLocation);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSLocation read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentImplementationRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLocation;
    procedure SetResult(AValue: TNXLSLocation);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSLocation read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSRoutineGotoImplementationRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLocation;
    procedure SetResult(AValue: TNXLSLocation);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSLocation read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSRoutineGotoDeclarationRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLocation;
    procedure SetResult(AValue: TNXLSLocation);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSLocation read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentReferencesRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSLocationArray;
    procedure SetResult(AValue: TNXLSLocationArray);
    function GetParams: TNXLSReferenceParams;
    procedure SetParams(AValue: TNXLSReferenceParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSLocationArray read GetResult write SetResult;
    property params: TNXLSReferenceParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSLSPModel,
  tpNXLS;

class function TNXLSTextDocumentDeclarationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/declaration';
end;

class function TNXLSTextDocumentDeclarationRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentDeclarationRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSLocation;
begin
  lResult := TNXLSLocation(PrepareResult);
  if TNXLSLSPModel.Current.Navigation.FillDeclaration(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSTextDocumentDefinitionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/definition';
end;

class function TNXLSTextDocumentDefinitionRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentDefinitionRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSLocation;
begin
  lResult := TNXLSLocation(PrepareResult);
  if TNXLSLSPModel.Current.Navigation.FillDefinition(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSTextDocumentTypeDefinitionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/typeDefinition';
end;

class function TNXLSTextDocumentTypeDefinitionRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentTypeDefinitionRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSLocation;
begin
  lResult := TNXLSLocation(PrepareResult);
  if TNXLSLSPModel.Current.Navigation.FillTypeDefinition(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSTextDocumentImplementationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/implementation';
end;

class function TNXLSTextDocumentImplementationRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentImplementationRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSLocation;
begin
  lResult := TNXLSLocation(PrepareResult);
  if TNXLSLSPModel.Current.Navigation.FillImplementationLocation(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSRoutineGotoImplementationRequest.GetFactoryName: string;
begin
  Result := 'nexusls.routine.gotoImplementation';
end;

class function TNXLSRoutineGotoImplementationRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSRoutineGotoImplementationRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSLocation;
begin
  lResult := TNXLSLocation(PrepareResult);
  if TNXLSLSPModel.Current.Navigation.FillRoutineImplementation(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSRoutineGotoDeclarationRequest.GetFactoryName: string;
begin
  Result := 'nexusls.routine.gotoDeclaration';
end;

class function TNXLSRoutineGotoDeclarationRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSRoutineGotoDeclarationRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSLocation;
begin
  lResult := TNXLSLocation(PrepareResult);
  if TNXLSLSPModel.Current.Navigation.FillRoutineDeclaration(
    TNXLSTextDocumentPositionParams(params), lResult) then
    Result := lResult
  else
  begin
    lResult.Free;
    Result := TNXJSONNull.Create;
  end;
end;

class function TNXLSTextDocumentReferencesRequest.GetFactoryName: string;
begin
  Result := 'textDocument/references';
end;

function TNXLSTextDocumentReferencesRequest.Execute: TNXJSONRPCValue;
var
  lResult: TNXLSLocationArray;
begin
  lResult := TNXLSLocationArray(PrepareResult);
  TNXLSLSPModel.Current.Navigation.FillReferences(TNXLSReferenceParams(params),
    lResult);
  Result := lResult;
end;

function TNXLSTextDocumentImplementationRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentImplementationRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSRoutineGotoImplementationRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSRoutineGotoImplementationRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSRoutineGotoDeclarationRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSRoutineGotoDeclarationRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentTypeDefinitionRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentTypeDefinitionRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentReferencesRequest.GetParams: TNXLSReferenceParams;
begin
  Result := TNXLSReferenceParams(inherited params);
end;

procedure TNXLSTextDocumentReferencesRequest.SetParams(AValue: TNXLSReferenceParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDeclarationRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentDeclarationRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDefinitionRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentDefinitionRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDeclarationRequest.GetResult: TNXLSLocation;
begin
  Result := TNXLSLocation(inherited result);
end;

procedure TNXLSTextDocumentDeclarationRequest.SetResult(AValue: TNXLSLocation);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentDefinitionRequest.GetResult: TNXLSLocation;
begin
  Result := TNXLSLocation(inherited result);
end;

procedure TNXLSTextDocumentDefinitionRequest.SetResult(AValue: TNXLSLocation);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentTypeDefinitionRequest.GetResult: TNXLSLocation;
begin
  Result := TNXLSLocation(inherited result);
end;

procedure TNXLSTextDocumentTypeDefinitionRequest.SetResult(AValue: TNXLSLocation);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentImplementationRequest.GetResult: TNXLSLocation;
begin
  Result := TNXLSLocation(inherited result);
end;

procedure TNXLSTextDocumentImplementationRequest.SetResult(AValue: TNXLSLocation);
begin
  inherited result := AValue;
end;

function TNXLSRoutineGotoImplementationRequest.GetResult: TNXLSLocation;
begin
  Result := TNXLSLocation(inherited result);
end;

procedure TNXLSRoutineGotoImplementationRequest.SetResult(AValue: TNXLSLocation);
begin
  inherited result := AValue;
end;

function TNXLSRoutineGotoDeclarationRequest.GetResult: TNXLSLocation;
begin
  Result := TNXLSLocation(inherited result);
end;

procedure TNXLSRoutineGotoDeclarationRequest.SetResult(AValue: TNXLSLocation);
begin
  inherited result := AValue;
end;

function TNXLSTextDocumentReferencesRequest.GetResult: TNXLSLocationArray;
begin
  Result := TNXLSLocationArray(inherited result);
end;

procedure TNXLSTextDocumentReferencesRequest.SetResult(AValue: TNXLSLocationArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDeclarationRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDefinitionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentTypeDefinitionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentImplementationRequest);
  TNXClassFactory.RegisterClass(TNXLSRoutineGotoImplementationRequest);
  TNXClassFactory.RegisterClass(TNXLSRoutineGotoDeclarationRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentReferencesRequest);

end.
