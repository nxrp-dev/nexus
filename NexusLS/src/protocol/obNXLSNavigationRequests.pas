unit obNXLSNavigationRequests;

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
  TNXLSTextDocumentDeclarationRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDefinitionRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentTypeDefinitionRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentImplementationRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentReferencesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSReferenceParams;
    procedure SetParams(AValue: TNXLSReferenceParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
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

class function TNXLSTextDocumentDeclarationRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSLocation;
end;

class function TNXLSTextDocumentDeclarationRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentDeclarationRequest.Execute: TNXJSONValue;
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

class function TNXLSTextDocumentDefinitionRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSLocation;
end;

class function TNXLSTextDocumentDefinitionRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentDefinitionRequest.Execute: TNXJSONValue;
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

class function TNXLSTextDocumentTypeDefinitionRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSLocation;
end;

class function TNXLSTextDocumentTypeDefinitionRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentTypeDefinitionRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/typeDefinition; required: Optional; original server: No; category: navigation; result: TNXLSLocationResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentImplementationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/implementation';
end;

class function TNXLSTextDocumentImplementationRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSLocation;
end;

class function TNXLSTextDocumentImplementationRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullableConcreteResult;
end;

function TNXLSTextDocumentImplementationRequest.Execute: TNXJSONValue;
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

class function TNXLSTextDocumentReferencesRequest.GetFactoryName: string;
begin
  Result := 'textDocument/references';
end;

class function TNXLSTextDocumentReferencesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSLocationArray;
end;

function TNXLSTextDocumentReferencesRequest.Execute: TNXJSONValue;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDeclarationRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDefinitionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentTypeDefinitionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentImplementationRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentReferencesRequest);

end.
