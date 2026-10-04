(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXRenderRecordingCanvas;

{$mode objfpc}{$H+}

interface

uses Classes, fpg_base, fpg_main;

type
  TNXRenderRecordingCanvas = class(TfpgCanvas)
  private
    FCommands: TStringList;
    FRecordedColor: TfpgColor;
    FRecordedWidth: Integer;
    FLineCount: Integer;
    FRecordCommands: Boolean;
  protected
    procedure DoSetColor(AColor: TfpgColor); override;
    procedure DoSetLineStyle(AWidth: Integer; AStyle: TfpgLineStyle); override;
    procedure DoDrawLine(AX1, AY1, AX2, AY2: TfpgCoord); override;
    procedure DoDrawRectangle(AX, AY, AWidth, AHeight: TfpgCoord); override;
    procedure DoFillRectangle(AX, AY, AWidth, AHeight: TfpgCoord); override;
    procedure DoSetFontRes(AFont: TfpgFontResourceBase); override;
    procedure DoSetTextColor(AColor: TfpgColor); override;
    procedure DoDrawString(AX, AY: TfpgCoord; const AText: string); override;
    procedure DoDrawArc(AX, AY, AWidth, AHeight: TfpgCoord;
      AStart, AExtent: Double); override;
    procedure DoFillArc(AX, AY, AWidth, AHeight: TfpgCoord;
      AStart, AExtent: Double); override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure Reset;
    property Commands: TStringList read FCommands;
    property LineCount: Integer read FLineCount;
    property RecordCommands: Boolean read FRecordCommands write FRecordCommands;
  end;

implementation

uses SysUtils;

constructor TNXRenderRecordingCanvas.Create;
begin
  inherited Create(nil);
  FCommands := TStringList.Create;
  FRecordCommands := True;
end;

destructor TNXRenderRecordingCanvas.Destroy;
begin
  FCommands.Free;
  inherited Destroy;
end;

procedure TNXRenderRecordingCanvas.Reset;
begin
  FCommands.Clear;
  FLineCount := 0;
end;

procedure TNXRenderRecordingCanvas.DoSetColor(AColor: TfpgColor);
begin
  FRecordedColor := AColor;
end;

procedure TNXRenderRecordingCanvas.DoSetLineStyle(AWidth: Integer; AStyle: TfpgLineStyle);
begin
  FRecordedWidth := AWidth;
end;

procedure TNXRenderRecordingCanvas.DoDrawLine(AX1, AY1, AX2, AY2: TfpgCoord);
begin
  Inc(FLineCount);
  if FRecordCommands then
    FCommands.Add(Format('%d,%d,%d,%d;%s;%d',
      [AX1, AY1, AX2, AY2, IntToHex(LongWord(FRecordedColor), 8), FRecordedWidth]));
end;

procedure TNXRenderRecordingCanvas.DoDrawRectangle(AX, AY, AWidth,
  AHeight: TfpgCoord);
begin
  if FRecordCommands then
    FCommands.Add(Format('rect:%d,%d,%d,%d;%s;%d',
      [AX, AY, AWidth, AHeight, IntToHex(LongWord(FRecordedColor), 8), FRecordedWidth]));
end;

procedure TNXRenderRecordingCanvas.DoFillRectangle(AX, AY, AWidth,
  AHeight: TfpgCoord);
begin
  if FRecordCommands then
    FCommands.Add(Format('fill:%d,%d,%d,%d;%s',
      [AX, AY, AWidth, AHeight, IntToHex(LongWord(FRecordedColor), 8)]));
end;

procedure TNXRenderRecordingCanvas.DoSetFontRes(AFont: TfpgFontResourceBase);
begin
  // The base canvas keeps the font; this canvas has no native drawing surface.
end;

procedure TNXRenderRecordingCanvas.DoSetTextColor(AColor: TfpgColor);
begin
  // The base canvas keeps TextColor.
end;

procedure TNXRenderRecordingCanvas.DoDrawString(AX, AY: TfpgCoord;
  const AText: string);
begin
  if FRecordCommands then
    FCommands.Add(Format('text:%d,%d;%s;%s;%s',
      [AX, AY, IntToHex(LongWord(TextColor), 8), Font.FontDesc, AText]));
end;

procedure TNXRenderRecordingCanvas.DoDrawArc(AX, AY, AWidth,
  AHeight: TfpgCoord; AStart, AExtent: Double);
begin
  if FRecordCommands then
    FCommands.Add(Format('arc:%d,%d,%d,%d;%.0f,%.0f;%s;%d',
      [AX, AY, AWidth, AHeight, AStart, AExtent,
       IntToHex(LongWord(FRecordedColor), 8), FRecordedWidth]));
end;

procedure TNXRenderRecordingCanvas.DoFillArc(AX, AY, AWidth,
  AHeight: TfpgCoord; AStart, AExtent: Double);
begin
  if FRecordCommands then
    FCommands.Add(Format('fillarc:%d,%d,%d,%d;%.0f,%.0f;%s',
      [AX, AY, AWidth, AHeight, AStart, AExtent,
       IntToHex(LongWord(FRecordedColor), 8)]));
end;

end.
