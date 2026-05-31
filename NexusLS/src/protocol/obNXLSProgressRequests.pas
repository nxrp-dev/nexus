unit obNXLSProgressRequests;

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
  TNXLSWindowWorkDoneProgressCreateRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSWorkDoneProgressCreateParams;
    procedure SetParams(AValue: TNXLSWorkDoneProgressCreateParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSWorkDoneProgressCreateParams read GetParams write SetParams;
  end;

  TNXLSWindowWorkDoneProgressCancelRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSWorkDoneProgressCancelParams;
    procedure SetParams(AValue: TNXLSWorkDoneProgressCancelParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSWorkDoneProgressCancelParams read GetParams write SetParams;
  end;

implementation

uses
  obNXClassFactory;

class function TNXLSWindowWorkDoneProgressCreateRequest.GetFactoryName: string;
begin
  Result := 'window/workDoneProgress/create';
end;

class function TNXLSWindowWorkDoneProgressCreateRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWindowWorkDoneProgressCreateRequest.Execute: TNXJSONValue;
begin
  // Method: window/workDoneProgress/create; required: Client-side; original server: No; category: progress; result: TNXLSNullResult.
  Result := PrepareResult;
end;

class function TNXLSWindowWorkDoneProgressCancelRequest.GetFactoryName: string;
begin
  Result := 'window/workDoneProgress/cancel';
end;

class function TNXLSWindowWorkDoneProgressCancelRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSWindowWorkDoneProgressCancelRequest.Execute: TNXJSONValue;
begin
  // Method: window/workDoneProgress/cancel; required: Client-side; original server: No; category: progress; result: nil.
  Result := nil;
end;

function TNXLSWindowWorkDoneProgressCancelRequest.GetParams: TNXLSWorkDoneProgressCancelParams;
begin
  Result := TNXLSWorkDoneProgressCancelParams(inherited params);
end;

procedure TNXLSWindowWorkDoneProgressCancelRequest.SetParams(AValue: TNXLSWorkDoneProgressCancelParams);
begin
  inherited params := AValue;
end;

function TNXLSWindowWorkDoneProgressCreateRequest.GetParams: TNXLSWorkDoneProgressCreateParams;
begin
  Result := TNXLSWorkDoneProgressCreateParams(inherited params);
end;

procedure TNXLSWindowWorkDoneProgressCreateRequest.SetParams(AValue: TNXLSWorkDoneProgressCreateParams);
begin
  inherited params := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSWindowWorkDoneProgressCreateRequest);
  TNXClassFactory.RegisterClass(TNXLSWindowWorkDoneProgressCancelRequest);

end.
