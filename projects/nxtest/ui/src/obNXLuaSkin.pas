(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLuaSkin;

{$mode objfpc}{$H+}

interface

uses
  fpg_base,
  fpg_main,
  obNXSkin,
  Lua51,
  obNXLuaCanvas;

type
  TNXLuaSkin = class(TNXSkin)
  private
    FCanvasBridge: TNXLuaCanvas;
    FCanvasRef: Integer;
    FLuaState: Plua_State;
    function LuaError: string;
    procedure LoadScript(const AName: string);
  public
    constructor Create; override;
    destructor Destroy; override;
    property LuaState: Plua_State read FLuaState;
    property CanvasBridge: TNXLuaCanvas read FCanvasBridge;
    property CanvasRef: Integer read FCanvasRef;
    procedure DrawControlFrame(ACanvas: TfpgCanvas;
      AX, AY, AWidth, AHeight: TfpgCoord);
      override;
  end;

implementation

uses
  SysUtils,
  Math,
  fpg_stylemanager,
  tpNXSkin,
  obNXPanelRender,
  obNXLuaRender;

constructor TNXLuaSkin.Create;
var
  lExceptionMask: TFPUExceptionMask;
begin
  inherited Create;
  FCanvasRef := LUA_NOREF;
  lExceptionMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  try
    FLuaState := luaL_newstate;
    if FLuaState = nil then
      raise Exception.Create('Could not create the Lua skin state.');
    luaL_openlibs(FLuaState);

    LoadScript('ControlFrame.lua');
    LoadScript('PanelFrame.lua');

    FCanvasBridge := TNXLuaCanvas.Create;
    try
      FCanvasBridge.Push(FLuaState);
    except
      FreeAndNil(FCanvasBridge);
      raise;
    end;
    FCanvasRef := luaL_ref(FLuaState, LUA_REGISTRYINDEX);
    RegisterRenderer(cNXPanelFrame, TNXLuaRenderer.Create(FLuaState,
      'drawPanelFrame', TNXPanelFrameState, FCanvasBridge, FCanvasRef,
      TNXPanelFrameColors.Create(Colors)));
  finally
    SetExceptionMask(lExceptionMask);
  end;
end;

destructor TNXLuaSkin.Destroy;
var
  lExceptionMask: TFPUExceptionMask;
begin
  if FLuaState <> nil then
  begin
    lExceptionMask := GetExceptionMask;
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
      exOverflow, exUnderflow, exPrecision]);
    try
      ClearRenderers;
      if FCanvasRef <> LUA_NOREF then
        luaL_unref(FLuaState, LUA_REGISTRYINDEX, FCanvasRef);
      lua_close(FLuaState);
      FLuaState := nil;
      FCanvasBridge := nil;
    finally
      SetExceptionMask(lExceptionMask);
    end;
  end;
  inherited Destroy;
end;

procedure TNXLuaSkin.LoadScript(const AName: string);
var
  lPath: string;
begin
  lPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + AName);
  if luaL_loadfile(FLuaState, PChar(lPath)) <> 0 then
    raise Exception.Create('Lua skin load failed: ' + LuaError);
  if lua_pcall(FLuaState, 0, 0, 0) <> 0 then
    raise Exception.Create('Lua skin initialization failed: ' + LuaError);
end;

function TNXLuaSkin.LuaError: string;
var
  lMessage: PChar;
begin
  lMessage := lua_tostring(FLuaState, -1);
  if lMessage = nil then
    Result := 'unknown Lua error'
  else
    Result := string(lMessage);
end;

procedure TNXLuaSkin.DrawControlFrame(ACanvas: TfpgCanvas;
  AX, AY, AWidth, AHeight: TfpgCoord);
var
  lExceptionMask: TFPUExceptionMask;
  lTop: Integer;
begin
  lTop := lua_gettop(FLuaState);
  lExceptionMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  try
    lua_getglobal(FLuaState, 'drawControlFrame');
    if not lua_isfunction(FLuaState, -1) then
    begin
      lua_pop(FLuaState, 1);
      raise Exception.Create('Lua skin must define drawControlFrame.');
    end;

    FCanvasBridge.AttachCanvas(ACanvas);
    lua_rawgeti(FLuaState, LUA_REGISTRYINDEX, FCanvasRef);
    lua_pushinteger(FLuaState, AX);
    lua_pushinteger(FLuaState, AY);
    lua_pushinteger(FLuaState, AWidth);
    lua_pushinteger(FLuaState, AHeight);
    lua_pushnumber(FLuaState, LongWord(Colors[scrWidgetFrame]));
    if lua_pcall(FLuaState, 6, 0, 0) <> 0 then
      raise Exception.Create('Lua skin drawing failed: ' + LuaError);
  finally
    FCanvasBridge.AttachCanvas(nil);
    lua_settop(FLuaState, lTop);
    SetExceptionMask(lExceptionMask);
  end;
end;

initialization
  fpgStyleManager.RegisterClass('NexusLua', TNXLuaSkin);

end.
