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
    function Execute: TNXJSONValue; override;
  end;

  TNXLSTextDocumentDiagnosticRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDiagnosticRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
    class function GetParamClass: TNXJSONValueClass; override;
    function Execute: TNXJSONValue; override;
  end;

  TNXLSWorkspaceDiagnosticRefreshRequest = class(TNXJSONRPCRequest)
  public
    class function GetFactoryName: string; override;
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

function TNXLSTextDocumentDiagnosticRequest.Execute: TNXJSONValue;
begin
  // Method: textDocument/diagnostic; required: Optional; original server: No; category: diagnostics; result: TNXLSDocumentDiagnosticReportResult.
  Result := TNXLSDocumentDiagnosticReportResult.CreateValue;
end;

class function TNXLSWorkspaceDiagnosticRequest.GetFactoryName: string;
begin
  Result := 'workspace/diagnostic';
end;

class function TNXLSWorkspaceDiagnosticRequest.GetParamClass: TNXJSONValueClass;
begin
  Result := TNXLSWorkspaceDiagnosticParams;
end;

function TNXLSWorkspaceDiagnosticRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/diagnostic; required: Optional; original server: No; category: diagnostics; result: TNXLSWorkspaceDiagnosticReportResult.
  Result := TNXLSWorkspaceDiagnosticReportResult.CreateValue;
end;

class function TNXLSWorkspaceDiagnosticRefreshRequest.GetFactoryName: string;
begin
  Result := 'workspace/diagnostic/refresh';
end;

function TNXLSWorkspaceDiagnosticRefreshRequest.Execute: TNXJSONValue;
begin
  // Method: workspace/diagnostic/refresh; required: Client-side; original server: No; category: diagnostics; result: TNXLSNullResult.
  Result := TNXLSNullResult.CreateValue;
end;

initialization
  TNXClassFactory.RegisterClass(TNXLSTextDocumentPublishDiagnosticsRequest);
  TNXClassFactory.RegisterClass(TNXLSTextDocumentDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRequest);
  TNXClassFactory.RegisterClass(TNXLSWorkspaceDiagnosticRefreshRequest);

end.
