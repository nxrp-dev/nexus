unit obNXLSInactiveRegionService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXJSONRPCMessages,
  obNXJSONRPCObjects,
  obNXLSServiceContext;

type
  TNXLSInactiveRegionService = class(TNXLSLSPService)
  public
    procedure CheckDocument(ADocument: TNXLSDocument); virtual;
  end;

implementation

uses
  BasicCodeTools,
  CodeToolManager,
  LinkScanner,
  sourcelog;

type
  TNXLSInactiveRegion = class(TNXJSONObject)
  private
    FstartLine: TNXJSONInteger;
    FstartCol: TNXJSONInteger;
    FendLine: TNXJSONInteger;
    FendCol: TNXJSONInteger;
  published
    property startLine: TNXJSONInteger read FstartLine write FstartLine;
    property startCol: TNXJSONInteger read FstartCol write FstartCol;
    property endLine: TNXJSONInteger read FendLine write FendLine;
    property endCol: TNXJSONInteger read FendCol write FendCol;
  end;

  TNXLSInactiveRegionArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONRPCValueClass; override;
  end;

  TNXLSInactiveRegionsParams = class(TNXJSONRPCObjectParams)
  private
    Furi: TNXJSONString;
    FfileVersion: TNXJSONInteger;
    Fregions: TNXLSInactiveRegionArray;
  published
    property uri: TNXJSONString read Furi write Furi;
    property fileVersion: TNXJSONInteger read FfileVersion write FfileVersion;
    property regions: TNXLSInactiveRegionArray read Fregions write Fregions;
  end;

  TNXLSInactiveRegionsNotification = class(TNXJSONRPCOutboundNotification)
  private
    function GetParams: TNXLSInactiveRegionsParams;
    procedure SetParams(AValue: TNXLSInactiveRegionsParams);
  public
    class function GetFactoryName: string; override;
  published
    property params: TNXLSInactiveRegionsParams read GetParams write SetParams;
  end;

class function TNXLSInactiveRegionArray.ItemClass: TNXJSONRPCValueClass;
begin
  Result := TNXLSInactiveRegion;
end;

class function TNXLSInactiveRegionsNotification.GetFactoryName: string;
begin
  Result := 'pasls.inactiveRegions';
end;

function TNXLSInactiveRegionsNotification.GetParams: TNXLSInactiveRegionsParams;
begin
  Result := TNXLSInactiveRegionsParams(inherited params);
end;

procedure TNXLSInactiveRegionsNotification.SetParams(AValue: TNXLSInactiveRegionsParams);
begin
  inherited params := AValue;
end;

procedure NXLSAddRegion(ARegions: TNXLSInactiveRegionArray; AStartLine, AStartCol, AEndLine,
  AEndCol: Integer);
var
  lRegion: TNXLSInactiveRegion;
begin
  lRegion := TNXLSInactiveRegion(ARegions.AddObject(TNXLSInactiveRegion));
  lRegion.startLine.Value := AStartLine;
  lRegion.startCol.Value := AStartCol;
  lRegion.endLine.Value := AEndLine;
  lRegion.endCol.Value := AEndCol;
  lRegion.Assigned := True;
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
  lNotification: TNXLSInactiveRegionsNotification;
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

  lNotification := TNXLSInactiveRegionsNotification.Create;
  try
    lNotification.params.uri.Value := ADocument.URI;
    lNotification.params.fileVersion.Value := ADocument.Version;
    lNotification.params.regions.Assigned := True;

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
              NXLSAddRegion(lNotification.params.regions, lStartLine, lStartCol, lLine, lCol);
              lHasOpenRegion := False;
            end;
        end;
      end;

      if lHasOpenRegion then
        NXLSAddRegion(lNotification.params.regions, lStartLine, lStartCol, 999999, 0);
    end;

    lNotification.params.Assigned := True;
    Model.SendClientNotification(lNotification);
    lNotification := nil;
  finally
    lNotification.Free;
  end;
end;

end.
