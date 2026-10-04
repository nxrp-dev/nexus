unit tsNXLuaSkinBenchmark;

{$mode objfpc}{$H+}

interface

procedure RunNXLuaSkinBenchmark(AIterations: Integer;
  const AReportPath: string);

implementation

uses
  SysUtils,
  Windows,
  fpg_base,
  fpg_main,
  obNXSkin,
  obNXLuaSkin,
  tpNXSkin;

type
  TRecordingCanvas = class(TfpgCanvas)
  private
    FLineCount: Integer;
    FRectangleCount: Integer;
  protected
    procedure DoSetColor(AColor: TfpgColor); override;
    procedure DoSetLineStyle(AWidth: Integer; AStyle: TfpgLineStyle); override;
    procedure DoDrawRectangle(AX, AY, AWidth, AHeight: TfpgCoord); override;
    procedure DoDrawLine(AX1, AY1, AX2, AY2: TfpgCoord); override;
  public
    procedure ResetCounts;
    property LineCount: Integer read FLineCount;
    property RectangleCount: Integer read FRectangleCount;
  end;

  TDirectFrameSkin = class(TNXSkin)
  public
    procedure DrawControlFrame(ACanvas: TfpgCanvas;
      AX, AY, AWidth, AHeight: TfpgCoord); override;
  end;

procedure TRecordingCanvas.DoSetColor(AColor: TfpgColor);
begin
end;

procedure TRecordingCanvas.DoSetLineStyle(AWidth: Integer;
  AStyle: TfpgLineStyle);
begin
end;

procedure TRecordingCanvas.DoDrawRectangle(AX, AY, AWidth,
  AHeight: TfpgCoord);
begin
  Inc(FRectangleCount);
end;

procedure TRecordingCanvas.DoDrawLine(AX1, AY1, AX2,
  AY2: TfpgCoord);
begin
  Inc(FLineCount);
end;

procedure TRecordingCanvas.ResetCounts;
begin
  FLineCount := 0;
  FRectangleCount := 0;
end;

procedure TDirectFrameSkin.DrawControlFrame(ACanvas: TfpgCanvas;
  AX, AY, AWidth, AHeight: TfpgCoord);
begin
  ACanvas.SetColor(Colors[scrWidgetFrame]);
  ACanvas.SetLineStyle(1, lsSolid);
  ACanvas.DrawRectangle(AX, AY, AWidth, AHeight);
  if (AWidth > 3) and (AHeight > 3) then
  begin
    ACanvas.SetColor($FF3DAEE9);
    ACanvas.SetLineStyle(1, lsSolid);
    ACanvas.DrawLine(AX + 1, AY + 1, AX + 1, AY + AHeight - 2);
  end;
end;

function TimeBatch(ASkin: TNXSkin; ACanvas: TRecordingCanvas;
  AIterations: Integer): Int64;
var
  lIndex: Integer;
  lStart: Int64;
  lStop: Int64;
begin
  ACanvas.ResetCounts;
  QueryPerformanceCounter(lStart);
  for lIndex := 1 to AIterations do
    ASkin.DrawControlFrame(ACanvas, 2, 3, 20, 15);
  QueryPerformanceCounter(lStop);
  if (ACanvas.RectangleCount <> AIterations) or
    (ACanvas.LineCount <> AIterations) then
    raise Exception.Create('Drawing command count did not match the iteration count.');
  Result := lStop - lStart;
end;

procedure WriteBatch(var AReport: TextFile; APair: Integer;
  const AVariant: string; ASkin: TNXSkin; ACanvas: TRecordingCanvas;
  AIterations: Integer; AFrequency: Int64);
var
  lTicks: Int64;
begin
  lTicks := TimeBatch(ASkin, ACanvas, AIterations);
  WriteLn(AReport, APair, ',', AVariant, ',', AIterations, ',',
    lTicks, ',', AFrequency);
  Flush(AReport);
end;

procedure RunNXLuaSkinBenchmark(AIterations: Integer;
  const AReportPath: string);
var
  lCanvas: TRecordingCanvas;
  lDirectSkin: TDirectFrameSkin;
  lFrequency: Int64;
  lLuaSkin: TNXLuaSkin;
  lPair: Integer;
  lReport: TextFile;
begin
  if AIterations < 1 then
    raise Exception.Create('Benchmark iterations must be positive.');
  fpgApplication.Initialize;
  lDirectSkin := TDirectFrameSkin.Create;
  lLuaSkin := TNXLuaSkin.Create;
  lCanvas := TRecordingCanvas.Create(nil);
  try
    QueryPerformanceFrequency(lFrequency);
    TimeBatch(lDirectSkin, lCanvas, 2000);
    TimeBatch(lLuaSkin, lCanvas, 2000);
    TimeBatch(lLuaSkin, lCanvas, 2000);
    TimeBatch(lDirectSkin, lCanvas, 2000);

    AssignFile(lReport, AReportPath);
    Rewrite(lReport);
    try
      WriteLn(lReport, 'pair,variant,iterations,ticks,frequency');
      for lPair := 1 to 10 do
        if Odd(lPair) then
        begin
          WriteBatch(lReport, lPair, 'pascal', lDirectSkin, lCanvas,
            AIterations, lFrequency);
          WriteBatch(lReport, lPair, 'lua', lLuaSkin, lCanvas,
            AIterations, lFrequency);
        end
        else
        begin
          WriteBatch(lReport, lPair, 'lua', lLuaSkin, lCanvas,
            AIterations, lFrequency);
          WriteBatch(lReport, lPair, 'pascal', lDirectSkin, lCanvas,
            AIterations, lFrequency);
        end;
    finally
      CloseFile(lReport);
    end;
  finally
    lCanvas.Free;
    lLuaSkin.Free;
    lDirectSkin.Free;
  end;
end;

end.
