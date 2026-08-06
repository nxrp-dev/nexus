unit obNXLSInactiveRegionService;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXJSONRPCMessages,
  obNXJSONRPCObjects,
  obNXLSDocumentParse,
  obNXLSServiceContext,
  obNXPasDocumentAnalysis;

type
  TNXLSInactiveRegionService = class(TNXLSLSPService)
  public
    procedure CheckAnalysis(ADocument: TNXLSDocument;
      AAnalysis: TNXPasDocumentAnalysis); virtual;
    procedure CheckDocument(ADocument: TNXLSDocument); virtual;
  end;

implementation

uses
  SysUtils,
  obNXPasSource;

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
  Result := 'nexusls.inactiveRegions';
end;

function TNXLSInactiveRegionsNotification.GetParams: TNXLSInactiveRegionsParams;
begin
  Result := TNXLSInactiveRegionsParams(inherited params);
end;

procedure TNXLSInactiveRegionsNotification.SetParams(AValue: TNXLSInactiveRegionsParams);
begin
  inherited params := AValue;
end;

procedure TNXLSInactiveRegionService.CheckAnalysis(ADocument: TNXLSDocument;
  AAnalysis: TNXPasDocumentAnalysis);
var
  lIdx: Integer;
  lNotification: TNXLSInactiveRegionsNotification;
  lRegion: TNXLSInactiveRegion;
  lSourceRegion: TNXPasInactiveRegion;
begin
  if (ADocument = nil) or (AAnalysis = nil) then
    Exit;

  lNotification := TNXLSInactiveRegionsNotification.Create;
  try
    lNotification.params.uri.Value := ADocument.URI;
    lNotification.params.fileVersion.Value := ADocument.Version;
    lNotification.params.regions.Assigned := True;
    for lIdx := 0 to AAnalysis.InactiveRegions.Count - 1 do
    begin
      lSourceRegion := AAnalysis.InactiveRegions.RegionAt(lIdx);
      lRegion := TNXLSInactiveRegion(
        lNotification.params.regions.AddObject(TNXLSInactiveRegion));
      lRegion.startLine.Value := lSourceRegion.Range.StartPos.Line;
      lRegion.startCol.Value := lSourceRegion.Range.StartPos.Column;
      lRegion.endLine.Value := lSourceRegion.Range.EndPos.Line;
      lRegion.endCol.Value := lSourceRegion.Range.EndPos.Column;
    end;
    lNotification.params.Assigned := True;
    Model.SendClientNotification(lNotification);
    lNotification := nil;
  finally
    lNotification.Free;
  end;
end;

procedure TNXLSInactiveRegionService.CheckDocument(ADocument: TNXLSDocument);
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
