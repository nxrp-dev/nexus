unit obNXLSCallHierarchyRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentPrepareCallHierarchyRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCallHierarchyIncomingCallsRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCallHierarchyOutgoingCallsRequest = class(TNXJSONRPCRequest)
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

class function TNXLSTextDocumentPrepareCallHierarchyRequest.GetFactoryName: string;
begin
  Result := 'textDocument/prepareCallHierarchy';
end;

class function TNXLSTextDocumentPrepareCallHierarchyRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSTextDocumentPositionParams;
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

class function TNXLSCallHierarchyIncomingCallsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyIncomingCallsParams;
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

class function TNXLSCallHierarchyOutgoingCallsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyOutgoingCallsParams;
end;

class function TNXLSCallHierarchyOutgoingCallsRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyOutgoingCallArray;
end;

function TNXLSCallHierarchyOutgoingCallsRequest.Execute: TNXJSONValue;
begin
  Result := PrepareResult;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareCallHierarchyRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyIncomingCallsRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyOutgoingCallsRequest);

end.
