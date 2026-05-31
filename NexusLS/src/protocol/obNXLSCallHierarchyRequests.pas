unit obNXLSCallHierarchyRequests;

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
  TNXLSTextDocumentPrepareCallHierarchyRequest = class(TNXJSONRPCRequest)
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

  TNXLSCallHierarchyIncomingCallsRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCallHierarchyIncomingCallsParams;
    procedure SetParams(AValue: TNXLSCallHierarchyIncomingCallsParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCallHierarchyIncomingCallsParams read GetParams write SetParams;
  end;

  TNXLSCallHierarchyOutgoingCallsRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSCallHierarchyOutgoingCallsParams;
    procedure SetParams(AValue: TNXLSCallHierarchyOutgoingCallsParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSCallHierarchyOutgoingCallsParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSTextDocumentPrepareCallHierarchyRequest.GetFactoryName: string;
begin
  Result := 'textDocument/prepareCallHierarchy';
end;

class function TNXLSTextDocumentPrepareCallHierarchyRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyItemArray;
end;

function TNXLSTextDocumentPrepareCallHierarchyRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSCallHierarchyIncomingCallsRequest.GetFactoryName: string;
begin
  Result := 'callHierarchy/incomingCalls';
end;

class function TNXLSCallHierarchyIncomingCallsRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyIncomingCallArray;
end;

function TNXLSCallHierarchyIncomingCallsRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

class function TNXLSCallHierarchyOutgoingCallsRequest.GetFactoryName: string;
begin
  Result := 'callHierarchy/outgoingCalls';
end;

class function TNXLSCallHierarchyOutgoingCallsRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyOutgoingCallArray;
end;

function TNXLSCallHierarchyOutgoingCallsRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

function TNXLSCallHierarchyOutgoingCallsRequest.GetParams: TNXLSCallHierarchyOutgoingCallsParams;
begin
  Result := TNXLSCallHierarchyOutgoingCallsParams(inherited params);
end;

procedure TNXLSCallHierarchyOutgoingCallsRequest.SetParams(AValue: TNXLSCallHierarchyOutgoingCallsParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentPrepareCallHierarchyRequest.GetParams: TNXLSTextDocumentPositionParams;
begin
  Result := TNXLSTextDocumentPositionParams(inherited params);
end;

procedure TNXLSTextDocumentPrepareCallHierarchyRequest.SetParams(AValue: TNXLSTextDocumentPositionParams);
begin
  inherited params := AValue;
end;

function TNXLSCallHierarchyIncomingCallsRequest.GetParams: TNXLSCallHierarchyIncomingCallsParams;
begin
  Result := TNXLSCallHierarchyIncomingCallsParams(inherited params);
end;

procedure TNXLSCallHierarchyIncomingCallsRequest.SetParams(AValue: TNXLSCallHierarchyIncomingCallsParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareCallHierarchyRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyIncomingCallsRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyOutgoingCallsRequest);

end.
