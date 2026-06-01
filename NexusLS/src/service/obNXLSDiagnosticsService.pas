unit obNXLSDiagnosticsService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXPasDiagnostics;

type
  TNXLSDiagnosticsService = class(TNXLSLSPService)
  private
    procedure AddDiagnostic(AParams: TNXLSPublishDiagnosticsParams;
      ADiagnostic: TNXPasDiagnostic);
    procedure PublishDiagnostics(var AParams: TNXLSPublishDiagnosticsParams);
  public
    procedure CheckDocument(ADocument: TNXLSDocument); virtual;
  end;

implementation

uses
  obNXLSDocumentParse,
  obNXLSDiagnosticRequests;

procedure TNXLSDiagnosticsService.AddDiagnostic(
  AParams: TNXLSPublishDiagnosticsParams; ADiagnostic: TNXPasDiagnostic);
var
  lDiagnostic: TNXLSDiagnostic;
begin
  if (AParams = nil) or (ADiagnostic = nil) then
    Exit;

  lDiagnostic := TNXLSDiagnostic(AParams.diagnostics.AddObject(TNXLSDiagnostic));
  lDiagnostic.range.start.line.Value := ADiagnostic.Range.StartPos.Line;
  lDiagnostic.range.start.character.Value := ADiagnostic.Range.StartPos.Column;
  lDiagnostic.range.&end.line.Value := ADiagnostic.Range.EndPos.Line;
  lDiagnostic.range.&end.character.Value := ADiagnostic.Range.EndPos.Column;
  lDiagnostic.range.Assigned := True;
  case ADiagnostic.Severity of
    pdsWarning:
      lDiagnostic.severity.Value := 2;
    pdsInfo:
      lDiagnostic.severity.Value := 3;
  else
    lDiagnostic.severity.Value := 1;
  end;
  lDiagnostic.source.Value := 'NexusPas';
  lDiagnostic.message.Value := ADiagnostic.Message;
  if ADiagnostic.Code <> '' then
    lDiagnostic.code.StringValue := ADiagnostic.Code;
end;

procedure TNXLSDiagnosticsService.PublishDiagnostics(
  var AParams: TNXLSPublishDiagnosticsParams);
var
  lNotification: TNXLSTextDocumentPublishDiagnosticsNotification;
begin
  if (AParams = nil) or (not Model.PublishDiagnosticsEnabled) then
    Exit;

  lNotification := TNXLSTextDocumentPublishDiagnosticsNotification.Create;
  try
    lNotification.params := AParams;
    AParams := nil;
    Model.SendClientNotification(lNotification);
    lNotification := nil;
  finally
    lNotification.Free;
  end;
end;

procedure TNXLSDiagnosticsService.CheckDocument(ADocument: TNXLSDocument);
var
  lIdx: Integer;
  lParams: TNXLSPublishDiagnosticsParams;
  lParseResult: TNXLSDocumentParseResult;
begin
  if ADocument = nil then
    Exit;

  if not Model.CheckSyntaxEnabled then
    Exit;

  if not Model.PublishDiagnosticsEnabled then
    Exit;

  lParams := TNXLSPublishDiagnosticsParams.Create;
  lParseResult := nil;
  try
    lParseResult := TNXLSDocumentParseResult.Create(ADocument);
    lParams.uri.Value := ADocument.URI;
    lParams.version.Value := ADocument.Version;
    lParams.diagnostics.Assigned := True;
    for lIdx := 0 to lParseResult.Diagnostics.Count - 1 do
      AddDiagnostic(lParams, lParseResult.Diagnostics.DiagnosticAt(lIdx));
    PublishDiagnostics(lParams);
  finally
    lParseResult.Free;
    lParams.Free;
  end;
end;

end.
