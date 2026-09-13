unit obNexusScriptLSDiagnostics;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONRPCMessages,
  obNXLSProtocolParams;

type
  TNexusScriptLSPublishDiagnostics = class(TNXJSONRPCOutboundNotification)
  private
    function GetParams: TNXLSPublishDiagnosticsParams;
    procedure SetParams(AValue: TNXLSPublishDiagnosticsParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXLSPublishDiagnosticsParams read GetParams write SetParams;
  end;

implementation

class function TNexusScriptLSPublishDiagnostics.GetFactoryName: string;
begin
  Result := 'textDocument/publishDiagnostics';
end;

function TNexusScriptLSPublishDiagnostics.GetParams:
  TNXLSPublishDiagnosticsParams;
begin
  Result := TNXLSPublishDiagnosticsParams(inherited params);
end;

procedure TNexusScriptLSPublishDiagnostics.SetParams(
  AValue: TNXLSPublishDiagnosticsParams);
begin
  inherited params := AValue;
end;

end.
