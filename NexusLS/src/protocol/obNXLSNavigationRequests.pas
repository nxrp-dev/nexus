unit obNXLSNavigationRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentDeclarationRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentDefinitionRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentTypeDefinitionRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentImplementationRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentReferencesRequest = class(TNXJSONRPCRequest)
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
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentDeclarationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/declaration';
end;

class function TNXLSTextDocumentDeclarationRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentDeclarationRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Navigation.Declaration(TNXLSTextDocumentPositionParams(params));
end;

class function TNXLSTextDocumentDefinitionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/definition';
end;

class function TNXLSTextDocumentDefinitionRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentDefinitionRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Navigation.Definition(TNXLSTextDocumentPositionParams(params));
end;

class function TNXLSTextDocumentTypeDefinitionRequest.GetFactoryName: string;
begin
  Result := 'textDocument/typeDefinition';
end;

class function TNXLSTextDocumentTypeDefinitionRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentTypeDefinitionRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/typeDefinition; required: Optional; original server: No; category: navigation; result: TNXLSLocationResult.
  Result := TNXLSLocationResult.CreateValue;
end;

class function TNXLSTextDocumentImplementationRequest.GetFactoryName: string;
begin
  Result := 'textDocument/implementation';
end;

class function TNXLSTextDocumentImplementationRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

function TNXLSTextDocumentImplementationRequest.Execute: TNXJSONValue;
begin
  Result := TNXLSLSPModel.Current.Navigation.ImplementationLocation(TNXLSTextDocumentPositionParams(params));
end;

class function TNXLSTextDocumentReferencesRequest.GetFactoryName: string;
begin
  Result := 'textDocument/references';
end;

class function TNXLSTextDocumentReferencesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSReferenceParams;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDeclarationRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDefinitionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentTypeDefinitionRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentImplementationRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentReferencesRequest);

end.
