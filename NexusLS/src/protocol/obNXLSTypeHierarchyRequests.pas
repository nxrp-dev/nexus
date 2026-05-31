unit obNXLSTypeHierarchyRequests;

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
  TNXLSTextDocumentPrepareTypeHierarchyRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTypeHierarchySupertypesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTypeHierarchySupertypesParams;
    procedure SetParams(AValue: TNXLSTypeHierarchySupertypesParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTypeHierarchySupertypesParams read GetParams write SetParams;
  end;

  TNXLSTypeHierarchySubtypesRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSTypeHierarchySubtypesParams;
    procedure SetParams(AValue: TNXLSTypeHierarchySubtypesParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSTypeHierarchySubtypesParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentPrepareTypeHierarchyRequest.GetFactoryName: string;
begin
  Result := 'textDocument/prepareTypeHierarchy';
end;

class function TNXLSTextDocumentPrepareTypeHierarchyRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchyItemArray;
end;

function TNXLSTextDocumentPrepareTypeHierarchyRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTypeHierarchySupertypesRequest.GetFactoryName: string;
begin
  Result := 'typeHierarchy/supertypes';
end;

class function TNXLSTypeHierarchySupertypesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchyItemArray;
end;

function TNXLSTypeHierarchySupertypesRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTypeHierarchySubtypesRequest.GetFactoryName: string;
begin
  Result := 'typeHierarchy/subtypes';
end;

class function TNXLSTypeHierarchySubtypesRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSTypeHierarchyItemArray;
end;

function TNXLSTypeHierarchySubtypesRequest.Execute: TNXJSONValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTypeHierarchySubtypesRequest.GetParams: TNXLSTypeHierarchySubtypesParams;
begin
  Result := TNXLSTypeHierarchySubtypesParams(inherited params);
end;

procedure TNXLSTypeHierarchySubtypesRequest.SetParams(AValue: TNXLSTypeHierarchySubtypesParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentPrepareTypeHierarchyRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentPrepareTypeHierarchyRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSTypeHierarchySupertypesRequest.GetParams: TNXLSTypeHierarchySupertypesParams;
begin
  Result := TNXLSTypeHierarchySupertypesParams(inherited params);
end;

procedure TNXLSTypeHierarchySupertypesRequest.SetParams(AValue: TNXLSTypeHierarchySupertypesParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareTypeHierarchyRequest);
  TNXClassFactory.RegisterClass(TNXLSTypeHierarchySupertypesRequest);
  TNXClassFactory.RegisterClass(TNXLSTypeHierarchySubtypesRequest);

end.
