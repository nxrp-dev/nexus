unit obNXLSDiagnosticsService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSServiceContext;

type
  TNXLSDiagnosticsService = class(TNXLSLSPService)
  private
    procedure PublishDiagnostics(ADocument: TNXLSDocument; const AMessage: string; ALine, AColumn: Integer);
    procedure ClearDiagnostics(ADocument: TNXLSDocument);
  public
    procedure CheckDocument(ADocument: TNXLSDocument); virtual;
  end;

implementation

uses
  SysUtils,
  fpjson,
  CodeToolManager;

procedure TNXLSDiagnosticsService.PublishDiagnostics(ADocument: TNXLSDocument; const AMessage: string; ALine, AColumn: Integer);
var
  lParams: TJSONObject;
  lDiagnostics: TJSONArray;
  lDiagnostic: TJSONObject;
  lRange: TJSONObject;
  lStart: TJSONObject;
  lEnd: TJSONObject;
begin
  if ADocument = nil then
    Exit;

  if ALine < 0 then
    ALine := 0;
  if AColumn < 0 then
    AColumn := 0;

  lParams := TJSONObject.Create;
  try
    lDiagnostics := TJSONArray.Create;
    lParams.Add('uri', ADocument.URI);
    lParams.Add('diagnostics', lDiagnostics);

    if AMessage <> '' then
    begin
      lDiagnostic := TJSONObject.Create;
      lDiagnostics.Add(lDiagnostic);

      lRange := TJSONObject.Create;
      lDiagnostic.Add('range', lRange);

      lStart := TJSONObject.Create;
      lStart.Add('line', ALine);
      lStart.Add('character', AColumn);
      lRange.Add('start', lStart);

      lEnd := TJSONObject.Create;
      lEnd.Add('line', ALine);
      lEnd.Add('character', AColumn + 1);
      lRange.Add('end', lEnd);

      lDiagnostic.Add('severity', 1);
      lDiagnostic.Add('source', 'nexusls');
      lDiagnostic.Add('message', AMessage);
    end;

    Model.SendNotification('textDocument/publishDiagnostics', lParams);
  finally
    lParams.Free;
  end;
end;

procedure TNXLSDiagnosticsService.ClearDiagnostics(ADocument: TNXLSDocument);
begin
  PublishDiagnostics(ADocument, '', 0, 0);
end;

procedure TNXLSDiagnosticsService.CheckDocument(ADocument: TNXLSDocument);
var
  lTool: TCodeTool;
  lLine: Integer;
  lColumn: Integer;
begin
  if (ADocument = nil) or (ADocument.CodeBuffer = nil) then
    Exit;

  try
    lTool := nil;
    if CodeToolBoss.Explore(ADocument.CodeBuffer, lTool, True) then
      ClearDiagnostics(ADocument)
    else
    begin
      lLine := CodeToolBoss.ErrorLine - 1;
      lColumn := CodeToolBoss.ErrorColumn - 1;
      PublishDiagnostics(ADocument, CodeToolBoss.ErrorMessage, lLine, lColumn);
    end;
  except
    on E: Exception do
      PublishDiagnostics(ADocument, E.Message, 0, 0);
  end;
end;

end.
