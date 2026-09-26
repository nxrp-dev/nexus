unit nxSDL2Patch;

{$mode objfpc}{$H+}

interface

uses
  SDL2;

type
  TSDLEventFilter = function(AUserData: Pointer; AEvent: PSDL_Event): LongInt; cdecl;

procedure SDL_AddEventWatch(AFilter: TSDLEventFilter; AUserData: Pointer); cdecl;
procedure SDL_DelEventWatch(AFilter: TSDLEventFilter; AUserData: Pointer); cdecl;

implementation

procedure SDL_AddEventWatch(AFilter: TSDLEventFilter; AUserData: Pointer); cdecl;
  external SDL_LibName name 'SDL_AddEventWatch';

procedure SDL_DelEventWatch(AFilter: TSDLEventFilter; AUserData: Pointer); cdecl;
  external SDL_LibName name 'SDL_DelEventWatch';

end.
