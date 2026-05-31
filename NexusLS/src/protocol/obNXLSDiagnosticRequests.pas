unit obNXLSDiagnosticRequests;

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
  TNXLSTextDocumentPublishDiagnosticsRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSPublishDiagnosticsParams;
    procedure SetParams(AValue: TNXLSPublishDiagnosticsParams);
public
    class function GetFactoryName: string; override;
class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSPublishDiagnosticsParams read GetParams write SetParams;
  end;

  TNXLSTextDocumentDiagnosticRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSFullDocumentDiagnosticReport;
    procedure SetResult(AValue: TNXLSFullDocumentDiagnosticReport);
    function GetParams: TNXLSDocumentDiagnosticParams;
    procedure SetParams(AValue: TNXLSDocumentDiagnosticParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSFullDocumentDiagnosticReport read GetResult write SetResult;
    property params: TNXLSDocumentDiagnosticParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceDiagnosticRequest = class(TNXJSONRPCRequest)
    private
    function GetResult: TNXLSWorkspaceDiagnosticReport;
    procedure SetResult(AValue: TNXLSWorkspaceDiagnosticReport);
    function GetParams: TNXLSWorkspaceDiagnosticParams;
    procedure SetParams(AValue: TNXLSWorkspaceDiagnosticParams);
public
    class function GetFactoryName: string; override;
    function Execute: TNXJSONValue; override;
  published
    property result: TNXLSWorkspaceDiagnosticReport read GetResult write SetResult;
    property params: TNXLSWorkspaceDiagnosticParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceDiagnosticRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

implementation

uses
  obNXClassFactory,
  tpNXLS;

class function TNXLSTextDocumentPublishDiagnosticsRequest.GetFactoryName: string;
begin
  Result := 'textDocument/publishDiagnostics';
end;

class function TNXLSTextDocumentPublishDiagnosticsRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNoResult;
end;

function TNXLSTextDocumentPublishDiagnosticsRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/publishDiagnostics; required: Client-side; original server: No; category: diagnostics; result: nil.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

class function TNXLSTextDocumentDiagnosticRequest.GetFactoryName: string;
begin
  Result := 'textDocument/diagnostic';
end;

function TNXLSTextDocumentDiagnosticRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSFullDocumentDiagnosticReport;
begin
  lResult := TNXLSFullDocumentDiagnosticReport(PrepareResult);
  lResult.kind.Value := 'full';
  lResult.items.Assigned := True;
  lResult.Assigned := True;
  Result := lResult;
end;

class function TNXLSWorkspaceDiagnosticRequest.GetFactoryName: string;
begin
  Result := 'workspace/diagnostic';
end;

function TNXLSWorkspaceDiagnosticRequest.Execute: TNXJSONValue;
var
  lResult: TNXLSWorkspaceDiagnosticReport;
begin
  lResult := TNXLSWorkspaceDiagnosticReport(PrepareResult);
  lResult.items.Assigned := True;
  lResult.Assigned := True;
  Result := lResult;
end;

class function TNXLSWorkspaceDiagnosticRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/diagnostic/refresh';
end;

class function TNXLSWorkspaceDiagnosticRefreshRequest.GetResultKind: TNXJSONRPCResultKind;
begin
  Result := rkNullResult;
end;

function TNXLSWorkspaceDiagnosticRefreshRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/diagnostic/refresh; required: Client-side; original server: No; category: diagnostics; result: TNXLSNullResult.
  NXLSRaiseNotImplemented(GetFactoryName);
  Result := nil;
end;

function TNXLSTextDocumentDiagnosticRequest.GetParams: TNXLSDocumentDiagnosticParams;
begin
  Result := TNXLSDocumentDiagnosticParams(inherited params);
end;

procedure TNXLSTextDocumentDiagnosticRequest.SetParams(AValue: TNXLSDocumentDiagnosticParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentPublishDiagnosticsRequest.GetParams: TNXLSPublishDiagnosticsParams;
begin
  Result := TNXLSPublishDiagnosticsParams(inherited params);
end;

procedure TNXLSTextDocumentPublishDiagnosticsRequest.SetParams(AValue: TNXLSPublishDiagnosticsParams);
begin
  inherited params := AValue;
end;

function TNXLSWorkspaceDiagnosticRequest.GetParams: TNXLSWorkspaceDiagnosticParams;
begin
  Result := TNXLSWorkspaceDiagnosticParams(inherited params);
end;

procedure TNXLSWorkspaceDiagnosticRequest.SetParams(AValue: TNXLSWorkspaceDiagnosticParams);
begin
  inherited params := AValue;
end;

function TNXLSTextDocumentDiagnosticRequest.GetResult: TNXLSFullDocumentDiagnosticReport;
begin
  Result := TNXLSFullDocumentDiagnosticReport(inherited result);
end;

procedure TNXLSTextDocumentDiagnosticRequest.SetResult(AValue: TNXLSFullDocumentDiagnosticReport);
begin
  inherited result := AValue;
end;

function TNXLSWorkspaceDiagnosticRequest.GetResult: TNXLSWorkspaceDiagnosticReport;
begin
  Result := TNXLSWorkspaceDiagnosticReport(inherited result);
end;

procedure TNXLSWorkspaceDiagnosticRequest.SetResult(AValue: TNXLSWorkspaceDiagnosticReport);
begin
  inherited result := AValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPublishDiagnosticsRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRefreshRequest);

end.
