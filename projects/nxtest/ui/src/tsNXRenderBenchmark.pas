(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXRenderBenchmark;

{$mode objfpc}{$H+}

interface

procedure RunNXRenderBenchmark(AIterations: Integer; const AReportPath: string);

implementation

uses
  SysUtils, Math, Windows, fpg_main, fpg_panel, Lua51, obNXRender,
  obNXPanelRender, obNXLuaRender, obNXPascalSkin, obNXLuaSkin,
  obNXRenderRecordingCanvas;

type
  TBenchmarkVariant = (bvDirect, bvSubscribedPascal, bvSubscribedLua, bvProjection);

  TNXRenderBenchmark = class
  private
    FState: TNXPanelFrameState;
    FColors: TNXPanelFrameColors;
    FDirect: TNXPanelFrameRenderer;
    FPascalSkin: TNXPascalSkin;
    FLuaSkin: TNXLuaSkin;
    FPascal, FLua: TNXRenderSubscription;
    FStateSchema, FColorSchema: TNXLuaStateSchema;
    FCanvas: TNXRenderRecordingCanvas;
  public
    constructor Create;
    destructor Destroy; override;
    function TimeBatch(AVariant: TBenchmarkVariant; AIterations: Integer): Int64;
  end;

const
  cVariantNames: array[TBenchmarkVariant] of string =
    ('direct_pascal', 'subscribed_pascal', 'subscribed_lua', 'projection_only');

constructor TNXRenderBenchmark.Create;
begin
  inherited Create;
  FState := TNXPanelFrameState.Create;
  FState.Left := 2;
  FState.Top := 3;
  FState.Width := 80;
  FState.Height := 32;
  FState.States := [];
  FState.Style := bsRaised;
  FState.BorderStyle := bsDouble;
  FPascalSkin := TNXPascalSkin.Create;
  FLuaSkin := TNXLuaSkin.Create;
  FColors := TNXPanelFrameColors.Create(FPascalSkin.Colors);
  FDirect := TNXPanelFrameRenderer.Create(FPascalSkin.Colors);
  FPascal := FPascalSkin.Subscribe(cNXPanelFrame, FState);
  FLua := FLuaSkin.Subscribe(cNXPanelFrame, FState);
  FStateSchema := TNXLuaStateSchema.Create(FState.ClassType);
  FColorSchema := TNXLuaStateSchema.Create(FColors.ClassType);
  FCanvas := TNXRenderRecordingCanvas.Create;
  FCanvas.RecordCommands := False;
end;

destructor TNXRenderBenchmark.Destroy;
begin
  FCanvas.Free;
  FColorSchema.Free;
  FStateSchema.Free;
  FLua.Free;
  FPascal.Free;
  FDirect.Free;
  FColors.Free;
  FLuaSkin.Free;
  FPascalSkin.Free;
  FState.Free;
  inherited Destroy;
end;

function TNXRenderBenchmark.TimeBatch(AVariant: TBenchmarkVariant;
  AIterations: Integer): Int64;
var
  lIndex, lTop, lExpectedLines: Integer;
  lStart, lStop: Int64;
  lMask: TFPUExceptionMask;
begin
  FCanvas.Reset;
  lTop := lua_gettop(FLuaSkin.LuaState);
  lMask := GetExceptionMask;
  if AVariant = bvProjection then
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
      exOverflow, exUnderflow, exPrecision]);
  try
    QueryPerformanceCounter(lStart);
    case AVariant of
      bvDirect:
        for lIndex := 1 to AIterations do FDirect.Draw(FCanvas, FState, cNXPanelFrame);
      bvSubscribedPascal:
        for lIndex := 1 to AIterations do FPascal.Render(FCanvas);
      bvSubscribedLua:
        for lIndex := 1 to AIterations do FLua.Render(FCanvas);
      bvProjection:
        for lIndex := 1 to AIterations do
        begin
          FStateSchema.Push(FLuaSkin.LuaState, FState);
          FColors.Prepare(cNXPanelFrame, FState);
          FColorSchema.Push(FLuaSkin.LuaState, FColors);
          lua_settop(FLuaSkin.LuaState, lTop);
        end;
    end;
    QueryPerformanceCounter(lStop);
    if lua_gettop(FLuaSkin.LuaState) <> lTop then
      raise Exception.Create('Benchmark leaked Lua stack entries.');
  finally
    lua_settop(FLuaSkin.LuaState, lTop);
    if AVariant = bvProjection then
      SetExceptionMask(lMask);
  end;
  if AVariant = bvProjection then
    lExpectedLines := 0
  else
    lExpectedLines := AIterations * 4;
  if FCanvas.LineCount <> lExpectedLines then
    raise Exception.CreateFmt('%s: expected %d lines, received %d.',
      [cVariantNames[AVariant], lExpectedLines, FCanvas.LineCount]);
  Result := lStop - lStart;
end;

procedure RunNXRenderBenchmark(AIterations: Integer; const AReportPath: string);
var
  lBenchmark: TNXRenderBenchmark;
  lReport: TextFile;
  lPair: Integer;
  lVariant: TBenchmarkVariant;
  lFrequency, lTicks: Int64;

  procedure WriteBatch(AVariant: TBenchmarkVariant);
  begin
    lTicks := lBenchmark.TimeBatch(AVariant, AIterations);
    WriteLn(lReport, lPair, ',', cVariantNames[AVariant], ',', AIterations,
      ',', lTicks, ',', lFrequency);
    Flush(lReport);
  end;

begin
  if (AIterations < 1) or (AIterations > High(Integer) div 4) then
    raise Exception.Create('Benchmark iterations are outside the supported range.');
  fpgApplication.Initialize;
  lBenchmark := TNXRenderBenchmark.Create;
  try
    QueryPerformanceFrequency(lFrequency);
    for lVariant := Low(TBenchmarkVariant) to High(TBenchmarkVariant) do
      lBenchmark.TimeBatch(lVariant, 2000);
    for lVariant := High(TBenchmarkVariant) downto Low(TBenchmarkVariant) do
      lBenchmark.TimeBatch(lVariant, 2000);
    AssignFile(lReport, AReportPath);
    Rewrite(lReport);
    try
      WriteLn(lReport, 'pair,variant,iterations,ticks,frequency');
      for lPair := 1 to 10 do
        if Odd(lPair) then
          for lVariant := Low(TBenchmarkVariant) to High(TBenchmarkVariant) do
            WriteBatch(lVariant)
        else
          for lVariant := High(TBenchmarkVariant) downto Low(TBenchmarkVariant) do
            WriteBatch(lVariant);
    finally
      CloseFile(lReport);
    end;
  finally
    lBenchmark.Free;
  end;
end;

end.
