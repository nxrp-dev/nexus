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
    function GetParams: TNXLSDocumentDiagnosticParams;
    procedure SetParams(AValue: TNXLSDocumentDiagnosticParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
    property params: TNXLSDocumentDiagnosticParams read GetParams write SetParams;
  end;

  TNXLSWorkspaceDiagnosticRequest = class(TNXJSONRPCRequest)
    private
    function GetParams: TNXLSWorkspaceDiagnosticParams;
    procedure SetParams(AValue: TNXLSWorkspaceDiagnosticParams);
public
    class function GetFactoryName: string; override;
class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  published
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
  obNXClassFactory;

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
  Result := nil;
end;

class function TNXLSTextDocumentDiagnosticRequest.GetFactoryName: string;
begin
  Result := 'textDocument/diagnostic';
end;

class function TNXLSTextDocumentDiagnosticRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSFullDocumentDiagnosticReport;
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

class function TNXLSWorkspaceDiagnosticRequest.GetResultClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceDiagnosticReport;
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
  Result := PrepareResult;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPublishDiagnosticsRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRefreshRequest);

end.
