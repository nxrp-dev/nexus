(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSDiagnosticsService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSProtocolParams,
  obNXLSServiceContext,
  obNXLSDocumentParse,
  obNXPasDocumentAnalysis,
  obNXPasDiagnostics;

type
  TNXLSDiagnosticsService = class(TNXLSLSPService)
  private
    procedure AddDiagnostic(AParams: TNXLSPublishDiagnosticsParams;
      ADiagnostic: TNXPasDiagnostic);
    procedure PublishDiagnostics(var AParams: TNXLSPublishDiagnosticsParams);
  public
    procedure CheckAnalysis(ADocument: TNXLSDocument;
      AAnalysis: TNXPasDocumentAnalysis); virtual;
    procedure CheckDocument(ADocument: TNXLSDocument); virtual;
  end;

implementation

uses
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

procedure TNXLSDiagnosticsService.CheckAnalysis(ADocument: TNXLSDocument;
  AAnalysis: TNXPasDocumentAnalysis);
var
  lIdx: Integer;
  lParams: TNXLSPublishDiagnosticsParams;
begin
  if (ADocument = nil) or (AAnalysis = nil) then
    Exit;

  if not Model.CheckSyntaxEnabled then
    Exit;

  if not Model.PublishDiagnosticsEnabled then
    Exit;

  lParams := TNXLSPublishDiagnosticsParams.Create;
  try
    lParams.uri.Value := ADocument.URI;
    lParams.version.Value := ADocument.Version;
    lParams.diagnostics.Assigned := True;
    for lIdx := 0 to AAnalysis.Diagnostics.Count - 1 do
      AddDiagnostic(lParams, AAnalysis.Diagnostics.DiagnosticAt(lIdx));
    PublishDiagnostics(lParams);
  finally
    lParams.Free;
  end;
end;

procedure TNXLSDiagnosticsService.CheckDocument(ADocument: TNXLSDocument);
var
  lAnalysis: TNXPasDocumentAnalysis;
begin
  if ADocument = nil then
    Exit;

  lAnalysis := Model.PascalLanguage.AnalyzeSource(NXLSCreatePascalSource(ADocument));
  try
    CheckAnalysis(ADocument, lAnalysis);
  finally
    lAnalysis.Free;
  end;
end;

end.
