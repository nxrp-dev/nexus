unit obNXLSCallHierarchyRequests;

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
  TNXLSTextDocumentPrepareCallHierarchyRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCallHierarchyItemArray;
    procedure SetResult(AValue: TNXLSCallHierarchyItemArray);
    function GetParams: TNXLSTextDocumentPositionParams;
    procedure SetParams(AValue: TNXLSTextDocumentPositionParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSCallHierarchyItemArray read GetResult write SetResult;
    property params: TNXLSTextDocumentPositionParams read GetParams write SetParams;
  end;

  TNXLSCallHierarchyIncomingCallsRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCallHierarchyIncomingCallArray;
    procedure SetResult(AValue: TNXLSCallHierarchyIncomingCallArray);
    function GetParams: TNXLSCallHierarchyIncomingCallsParams;
    procedure SetParams(AValue: TNXLSCallHierarchyIncomingCallsParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSCallHierarchyIncomingCallArray read GetResult write SetResult;
    property params: TNXLSCallHierarchyIncomingCallsParams read GetParams write SetParams;
  end;

  TNXLSCallHierarchyOutgoingCallsRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSCallHierarchyOutgoingCallArray;
    procedure SetResult(AValue: TNXLSCallHierarchyOutgoingCallArray);
    function GetParams: TNXLSCallHierarchyOutgoingCallsParams;
    procedure SetParams(AValue: TNXLSCallHierarchyOutgoingCallsParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONRPCValue; override;
  published
    property result: TNXLSCallHierarchyOutgoingCallArray read GetResult write SetResult;
    property params: TNXLSCallHierarchyOutgoingCallsParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentPrepareCallHierarchyRequest.GetFactoryName: string;
begin
  Result := 'textDocument/prepareCallHierarchy';
end;

function TNXLSTextDocumentPrepareCallHierarchyRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSCallHierarchyIncomingCallsRequest.GetFactoryName: string;
begin
  Result := 'callHierarchy/incomingCalls';
end;

function TNXLSCallHierarchyIncomingCallsRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSCallHierarchyOutgoingCallsRequest.GetFactoryName: string;
begin
  Result := 'callHierarchy/outgoingCalls';
end;

function TNXLSCallHierarchyOutgoingCallsRequest.Execute: TNXJSONRPCValue;
begin
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
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

function TNXLSTextDocumentPrepareCallHierarchyRequest.GetResult: TNXLSCallHierarchyItemArray;
begin
  Result := TNXLSCallHierarchyItemArray(inherited result);
end;

procedure TNXLSTextDocumentPrepareCallHierarchyRequest.SetResult(AValue: TNXLSCallHierarchyItemArray);
begin
  inherited result := AValue;
end;

function TNXLSCallHierarchyIncomingCallsRequest.GetResult: TNXLSCallHierarchyIncomingCallArray;
begin
  Result := TNXLSCallHierarchyIncomingCallArray(inherited result);
end;

procedure TNXLSCallHierarchyIncomingCallsRequest.SetResult(AValue: TNXLSCallHierarchyIncomingCallArray);
begin
  inherited result := AValue;
end;

function TNXLSCallHierarchyOutgoingCallsRequest.GetResult: TNXLSCallHierarchyOutgoingCallArray;
begin
  Result := TNXLSCallHierarchyOutgoingCallArray(inherited result);
end;

procedure TNXLSCallHierarchyOutgoingCallsRequest.SetResult(AValue: TNXLSCallHierarchyOutgoingCallArray);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPrepareCallHierarchyRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyIncomingCallsRequest);
  TNXClassFactory.RegisterClass(TNXLSCallHierarchyOutgoingCallsRequest);

end.
