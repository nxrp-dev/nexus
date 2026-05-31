unit obNXLSTypeHierarchyRequests;

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
  TNXLSTextDocumentPrepareTypeHierarchyRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSTypeHierarchyItemArray;
    procedure SetResult(AValue: TNXLSTypeHierarchyItemArray);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSTypeHierarchyItemArray read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSTypeHierarchySupertypesRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSTypeHierarchyItemArray;
    procedure SetResult(AValue: TNXLSTypeHierarchyItemArray);
    function GetParams: TNXLSTypeHierarchySupertypesParams;
    procedure SetParams(AValue: TNXLSTypeHierarchySupertypesParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSTypeHierarchyItemArray read GetResult write SetResult;
    property params: TNXLSTypeHierarchySupertypesParams read GetParams write SetParams;
  end;

  TNXLSTypeHierarchySubtypesRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSTypeHierarchyItemArray;
    procedure SetResult(AValue: TNXLSTypeHierarchyItemArray);
    function GetParams: TNXLSTypeHierarchySubtypesParams;
    procedure SetParams(AValue: TNXLSTypeHierarchySubtypesParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSTypeHierarchyItemArray read GetResult write SetResult;
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

function TNXLSTextDocumentPrepareTypeHierarchyRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTypeHierarchySupertypesRequest.GetFactoryName: string;
begin
  Result := 'typeHierarchy/supertypes';
end;

function TNXLSTypeHierarchySupertypesRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTypeHierarchySubtypesRequest.GetFactoryName: string;
begin
  Result := 'typeHierarchy/subtypes';
end;

function TNXLSTypeHierarchySubtypesRequest.Execute: TNXJSONRPCValue;
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

function TNXLSTextDocumentPrepareTypeHierarchyRequest.GetResult: TNXLSTypeHierarchyItemArray;
begin
  Result := TNXLSTypeHierarchyItemArray(inherited result);
end;

procedure TNXLSTextDocumentPrepareTypeHierarchyRequest.SetResult(AValue: TNXLSTypeHierarchyItemArray);
begin
  inherited result := AValue;
end;

function TNXLSTypeHierarchySupertypesRequest.GetResult: TNXLSTypeHierarchyItemArray;
begin
  Result := TNXLSTypeHierarchyItemArray(inherited result);
end;

procedure TNXLSTypeHierarchySupertypesRequest.SetResult(AValue: TNXLSTypeHierarchyItemArray);
begin
  inherited result := AValue;
end;

function TNXLSTypeHierarchySubtypesRequest.GetResult: TNXLSTypeHierarchyItemArray;
begin
  Result := TNXLSTypeHierarchyItemArray(inherited result);
end;

procedure TNXLSTypeHierarchySubtypesRequest.SetResult(AValue: TNXLSTypeHierarchyItemArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareTypeHierarchyRequest);
  TNXClassFactory.RegisterClass(TNXLSTypeHierarchySupertypesRequest);
  TNXClassFactory.RegisterClass(TNXLSTypeHierarchySubtypesRequest);

end.
