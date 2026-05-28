unit obNXLSInactiveRegionService;

{$mode objfpc}{$H+}

interface

uses
  obNXLSServiceContext;

type
  TNXLSInactiveRegionService = class(TNXLSLSPService)
  public
    procedure CheckDocument(ADocument: TNXLSDocument); virtual;
  end;

implementation

uses
  fpjson,
  BasicCodeTools,
  CodeToolManager,
  LinkScanner,
  sourcelog;

const
  cNXLSInactiveRegionsNotification = 'pasls.inactiveRegions';

procedure NXLSAddRegion(ARegions: TJSONArray; AStartLine, AStartCol, AEndLine,
  AEndCol: Integer);
var
  lRegion: TJSONObject;
begin
  lRegion := TJSONObject.Create;
  lRegion.Add('startLine', AStartLine);
  lRegion.Add('startCol', AStartCol);
  lRegion.Add('endLine', AEndLine);
  lRegion.Add('endCol', AEndCol);
  ARegions.Add(lRegion);
end;

procedure NXLSDirectivePos(AScanner: TLinkScanner; ADirective: PLSDirective;
  out ALine, ACol: Integer);
var
  lCode: Pointer;
  lCursorPos: Integer;
begin
  AScanner.CleanedPosToCursor(ADirective^.CleanPos, lCursorPos, lCode);
  TSourceLog(lCode).AbsoluteToLineCol(lCursorPos, ALine, ACol);
end;

procedure TNXLSInactiveRegionService.CheckDocument(ADocument: TNXLSDocument);
var
  lParams: TJSONObject;
  lRegions: TJSONArray;
  lScanner: TLinkScanner;
  lDirective: PLSDirective;
  lIdx: Integer;
  lLine: Integer;
  lCol: Integer;
  lStartLine: Integer;
  lStartCol: Integer;
  lHasOpenRegion: Boolean;
  lDirectiveText: string;
begin
  if (ADocument = nil) or (ADocument.CodeBuffer = nil) then
    Exit;

  lParams := TJSONObject.Create;
  try
    lRegions := TJSONArray.Create;
    lParams.Add('uri', ADocument.URI);
    lParams.Add('fileVersion', ADocument.Version);
    lParams.Add('regions', lRegions);

    if CodeToolBoss.ExploreUnitDirectives(ADocument.CodeBuffer, lScanner) then
    begin
      lHasOpenRegion := False;
      lStartLine := 0;
      lStartCol := 0;

      for lIdx := 0 to lScanner.DirectiveCount - 1 do
      begin
        lDirective := lScanner.Directives[lIdx];
        if lDirective^.Code <> Pointer(ADocument.CodeBuffer) then
          Continue;

        NXLSDirectivePos(lScanner, lDirective, lLine, lCol);
        lDirectiveText := ExtractCommentContent(lScanner.CleanedSrc,
          lDirective^.CleanPos, lScanner.NestedComments);

        case lDirective^.State of
          lsdsInactive:
            if not lHasOpenRegion then
            begin
              lStartLine := lLine;
              lStartCol := lCol + Length(lDirectiveText) + 2;
              lHasOpenRegion := True;
            end;
          lsdsActive:
            if lHasOpenRegion then
            begin
              NXLSAddRegion(lRegions, lStartLine, lStartCol, lLine, lCol);
              lHasOpenRegion := False;
            end;
        end;
      end;

      if lHasOpenRegion then
        NXLSAddRegion(lRegions, lStartLine, lStartCol, 999999, 0);
    end;

    Model.SendNotification(cNXLSInactiveRegionsNotification, lParams);
  finally
    lParams.Free;
  end;
end;

end.
