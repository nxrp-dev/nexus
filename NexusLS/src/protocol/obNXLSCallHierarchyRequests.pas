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
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCallHierarchyIncomingCallsRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSCallHierarchyOutgoingCallsRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
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

function TNXLSTextDocumentPrepareCallHierarchyRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/prepareCallHierarchy; required: Optional; original server: No; category: call hierarchy; result: TNXLSCallHierarchyItemArrayResult.
  Result := TNXLSCallHierarchyItemArrayResult.CreateValue;
end;

class function TNXLSCallHierarchyIncomingCallsRequest.GetFactoryName: string;
begin
  Result := 'callHierarchy/incomingCalls';
end;

class function TNXLSCallHierarchyIncomingCallsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyIncomingCallsParams;
end;

function TNXLSCallHierarchyIncomingCallsRequest.Execute: TNXJSONValue;
begin
  // Method: callHierarchy/incomingCalls; required: Optional; original server: No; category: call hierarchy; result: TNXLSCallHierarchyIncomingCallArrayResult.
  Result := TNXLSCallHierarchyIncomingCallArrayResult.CreateValue;
end;

class function TNXLSCallHierarchyOutgoingCallsRequest.GetFactoryName: string;
begin
  Result := 'callHierarchy/outgoingCalls';
end;

class function TNXLSCallHierarchyOutgoingCallsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSCallHierarchyOutgoingCallsParams;
end;

function TNXLSCallHierarchyOutgoingCallsRequest.Execute: TNXJSONValue;
begin
  // Method: callHierarchy/outgoingCalls; required: Optional; original server: No; category: call hierarchy; result: TNXLSCallHierarchyOutgoingCallArrayResult.
  Result := TNXLSCallHierarchyOutgoingCallArrayResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareCallHierarchyRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyIncomingCallsRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyOutgoingCallsRequest);

end.
