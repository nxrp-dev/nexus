unit Lua51;

{$mode objfpc}{$H+}

interface

type
  Plua_State = Pointer;
  lua_Integer = PtrInt;
  lua_Number = Double;
  lua_CFunction = function(L: Plua_State): Integer; cdecl;

  PluaL_Reg = ^luaL_Reg;
  luaL_Reg = record
    name: PChar;
    func: lua_CFunction;
  end;

const
  LUA_MULTRET = -1;

  LUA_TNONE = -1;
  LUA_TNIL = 0;
  LUA_TBOOLEAN = 1;
  LUA_TLIGHTUSERDATA = 2;
  LUA_TNUMBER = 3;
  LUA_TSTRING = 4;
  LUA_TTABLE = 5;
  LUA_TFUNCTION = 6;
  LUA_TUSERDATA = 7;
  LUA_TTHREAD = 8;

  LUA_REGISTRYINDEX = -10000;
  LUA_ENVIRONINDEX = -10001;
  LUA_GLOBALSINDEX = -10002;

  LUA_NOREF = -2;
  LUA_REFNIL = -1;

function lua_upvalueindex(I: Integer): Integer; inline;
function lua_absindex(L: Plua_State; Index: Integer): Integer; inline;

function lua_gettop(L: Plua_State): Integer; cdecl; external name 'lua_gettop';
procedure lua_settop(L: Plua_State; Idx: Integer); cdecl; external name 'lua_settop';
function lua_type(L: Plua_State; Idx: Integer): Integer; cdecl; external name 'lua_type';
function lua_typename(L: Plua_State; Tp: Integer): PChar; cdecl; external name 'lua_typename';
function lua_toboolean(L: Plua_State; Idx: Integer): Integer; cdecl; external name 'lua_toboolean';
function lua_tointeger(L: Plua_State; Idx: Integer): lua_Integer; cdecl; external name 'lua_tointeger';
function lua_tonumber(L: Plua_State; Idx: Integer): lua_Number; cdecl; external name 'lua_tonumber';
function lua_tolstring(L: Plua_State; Idx: Integer; Len: PSizeUInt): PChar; cdecl; external name 'lua_tolstring';
function lua_touserdata(L: Plua_State; Idx: Integer): Pointer; cdecl; external name 'lua_touserdata';

procedure lua_pushnil(L: Plua_State); cdecl; external name 'lua_pushnil';
procedure lua_pushboolean(L: Plua_State; B: Integer); cdecl; external name 'lua_pushboolean';
procedure lua_pushinteger(L: Plua_State; N: lua_Integer); cdecl; external name 'lua_pushinteger';
procedure lua_pushnumber(L: Plua_State; N: lua_Number); cdecl; external name 'lua_pushnumber';
procedure lua_pushlstring(L: Plua_State; S: PChar; Len: SizeUInt); cdecl; external name 'lua_pushlstring';
procedure lua_pushlightuserdata(L: Plua_State; P: Pointer); cdecl; external name 'lua_pushlightuserdata';
procedure lua_pushcclosure(L: Plua_State; Fn: lua_CFunction; N: Integer); cdecl; external name 'lua_pushcclosure';
procedure lua_pushvalue(L: Plua_State; Idx: Integer); cdecl; external name 'lua_pushvalue';

function lua_newuserdata(L: Plua_State; Size: SizeUInt): Pointer; cdecl; external name 'lua_newuserdata';
function lua_getmetatable(L: Plua_State; ObjIndex: Integer): Integer; cdecl; external name 'lua_getmetatable';
function lua_setmetatable(L: Plua_State; ObjIndex: Integer): Integer; cdecl; external name 'lua_setmetatable';

procedure lua_getfield(L: Plua_State; Idx: Integer; K: PChar); cdecl; external name 'lua_getfield';
procedure lua_setfield(L: Plua_State; Idx: Integer; K: PChar); cdecl; external name 'lua_setfield';
procedure lua_rawgeti(L: Plua_State; Idx, N: Integer); cdecl; external name 'lua_rawgeti';
procedure lua_rawseti(L: Plua_State; Idx, N: Integer); cdecl; external name 'lua_rawseti';
function lua_rawequal(L: Plua_State; Idx1, Idx2: Integer): Integer; cdecl; external name 'lua_rawequal';

function lua_error(L: Plua_State): Integer; cdecl; external name 'lua_error';
function lua_pcall(L: Plua_State; NArgs, NResults, ErrFunc: Integer): Integer; cdecl; external name 'lua_pcall';

function luaL_newmetatable(L: Plua_State; TName: PChar): Integer; cdecl; external name 'luaL_newmetatable';
function luaL_checkudata(L: Plua_State; Ud: Integer; TName: PChar): Pointer; cdecl; external name 'luaL_checkudata';
function luaL_ref(L: Plua_State; T: Integer): Integer; cdecl; external name 'luaL_ref';
procedure luaL_unref(L: Plua_State; T, Ref: Integer); cdecl; external name 'luaL_unref';
procedure luaL_getmetatable(L: Plua_State; TName: PChar); inline;

procedure lua_pop(L: Plua_State; N: Integer); inline;
procedure lua_pushcfunction(L: Plua_State; Fn: lua_CFunction); inline;
function lua_isnil(L: Plua_State; Index: Integer): Boolean; inline;
function lua_istable(L: Plua_State; Index: Integer): Boolean; inline;
function lua_isfunction(L: Plua_State; Index: Integer): Boolean; inline;

implementation

function lua_upvalueindex(I: Integer): Integer; inline;
begin
  Result := LUA_GLOBALSINDEX - I;
end;

function lua_absindex(L: Plua_State; Index: Integer): Integer; inline;
begin
  if (Index > 0) or (Index <= LUA_REGISTRYINDEX) then
    Result := Index
  else
    Result := lua_gettop(L) + Index + 1;
end;

procedure lua_pop(L: Plua_State; N: Integer); inline;
begin
  lua_settop(L, -N - 1);
end;

procedure lua_pushcfunction(L: Plua_State; Fn: lua_CFunction); inline;
begin
  lua_pushcclosure(L, Fn, 0);
end;

procedure luaL_getmetatable(L: Plua_State; TName: PChar); inline;
begin
  lua_getfield(L, LUA_REGISTRYINDEX, TName);
end;

function lua_isnil(L: Plua_State; Index: Integer): Boolean; inline;
begin
  Result := lua_type(L, Index) = LUA_TNIL;
end;

function lua_istable(L: Plua_State; Index: Integer): Boolean; inline;
begin
  Result := lua_type(L, Index) = LUA_TTABLE;
end;

function lua_isfunction(L: Plua_State; Index: Integer): Boolean; inline;
begin
  Result := lua_type(L, Index) = LUA_TFUNCTION;
end;

end.
