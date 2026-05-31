unit obNXLSTypeHierarchyRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentPrepareTypeHierarchyRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTypeHierarchySupertypesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTypeHierarchySubtypesRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentPrepareTypeHierarchyRequest.GetFactoryName: string;
begin
  Result := 'textDocument/prepareTypeHierarchy';
end;

class function TNXLSTextDocumentPrepareTypeHierarchyRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
end;

class function TNXLSTextDocumentPrepareTypeHierarchyRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchyItemArray;
end;

function TNXLSTextDocumentPrepareTypeHierarchyRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSTypeHierarchySupertypesRequest.GetFactoryName: string;
begin
  Result := 'typeHierarchy/supertypes';
end;

class function TNXLSTypeHierarchySupertypesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchySupertypesParams;
end;

class function TNXLSTypeHierarchySupertypesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchyItemArray;
end;

function TNXLSTypeHierarchySupertypesRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSTypeHierarchySubtypesRequest.GetFactoryName: string;
begin
  Result := 'typeHierarchy/subtypes';
end;

class function TNXLSTypeHierarchySubtypesRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchySubtypesParams;
end;

class function TNXLSTypeHierarchySubtypesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchyItemArray;
end;

function TNXLSTypeHierarchySubtypesRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareTypeHierarchyRequest);
  TNXClassFactory.RegisterClass(TNXLSTypeHierarchySupertypesRequest);
  TNXClassFactory.RegisterClass(TNXLSTypeHierarchySubtypesRequest);

end.
