unit tpNXLuaCanvas;

{$mode objfpc}{$H+}

interface

type
  TNXLuaLine = procedure(AX1, AY1, AX2, AY2: Integer) of object;
  TNXLuaRectangle = procedure(AX, AY, AWidth, AHeight: Integer) of object;
  TNXLuaColor = procedure(AColor: Int64) of object;
  TNXLuaLineWidth = procedure(AWidth: Integer) of object;
  TNXLuaFont = procedure(AFontDesc: string) of object;
  TNXLuaText = procedure(AX, AY: Integer; AText: string) of object;
  TNXLuaTextWidth = function(AText: string): Integer of object;
  TNXLuaFontHeight = function: Integer of object;

implementation

end.

