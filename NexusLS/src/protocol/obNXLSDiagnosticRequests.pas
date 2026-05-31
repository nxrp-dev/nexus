unit obNXLSDiagnosticRequests;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXJSONValues;

type
  TNXLSTextDocumentPublishDiagnosticsRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultKind: TNXJSONRPCResultKind; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentDiagnosticRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDiagnosticRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    class function GetResultClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
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
  obNXLSProtocolBase,
  obNXLSProtocolParams,
  obNXLSProtocolObjects;

class function TNXLSTextDocumentPublishDiagnosticsRequest.GetFactoryName: string;
begin
  Result := 'textDocument/publishDiagnostics';
end;

class function TNXLSTextDocumentPublishDiagnosticsRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSPublishDiagnosticsParams;
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

class function TNXLSTextDocumentDiagnosticRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSDocumentDiagnosticParams;
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

class function TNXLSWorkspaceDiagnosticRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceDiagnosticParams;
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

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPublishDiagnosticsRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRefreshRequest);

end.
