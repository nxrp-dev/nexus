(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXLuaSkinSmoke;

{$mode objfpc}{$H+}

interface

procedure RunNXLuaSkinSmoke;

implementation

uses
  SysUtils,
  fpg_base,
  fpg_main,
  obNXLuaSkin;

type
  TNXRecordingCanvas = class(TfpgCanvas)
  private
    FRecordedColor: TfpgColor;
    FLineCount: Integer;
    FRectangleCount: Integer;
  protected
    procedure DoSetColor(AColor: TfpgColor); override;
    procedure DoSetLineStyle(AWidth: Integer; AStyle: TfpgLineStyle); override;
    procedure DoDrawRectangle(AX, AY, AWidth, AHeight: TfpgCoord); override;
    procedure DoDrawLine(AX1, AY1, AX2, AY2: TfpgCoord); override;
  public
    property Color: TfpgColor read FRecordedColor;
    property LineCount: Integer read FLineCount;
    property RectangleCount: Integer read FRectangleCount;
  end;

procedure TNXRecordingCanvas.DoSetColor(AColor: TfpgColor);
begin
  FRecordedColor := AColor;
end;

procedure TNXRecordingCanvas.DoSetLineStyle(AWidth: Integer;
  AStyle: TfpgLineStyle);
begin
end;

procedure TNXRecordingCanvas.DoDrawRectangle(AX, AY, AWidth,
  AHeight: TfpgCoord);
begin
  Inc(FRectangleCount);
end;

procedure TNXRecordingCanvas.DoDrawLine(AX1, AY1, AX2,
  AY2: TfpgCoord);
begin
  Inc(FLineCount);
end;

procedure RunNXLuaSkinSmoke;
var
  lCanvas: TNXRecordingCanvas;
  lSkin: TNXLuaSkin;
begin
  fpgApplication.Initialize;
  lSkin := TNXLuaSkin.Create;
  lCanvas := TNXRecordingCanvas.Create(nil);
  try
    lSkin.DrawControlFrame(lCanvas, 2, 3, 20, 15);
    if (lCanvas.RectangleCount <> 1) or
      (lCanvas.LineCount <> 1) or
      (LongWord(lCanvas.Color) <> $FF3DAEE9) then
      raise Exception.Create('Lua skin did not execute the expected drawing commands.');
  finally
    lCanvas.Free;
    lSkin.Free;
  end;
end;

end.
