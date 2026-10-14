(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program Mixed;

{$mode objfpc}{$H+}
{$link native.o}
{$link twice.o}

function nx_add(ALeft, ARight: LongInt): LongInt; cdecl; external;
function nx_twice(AValue: LongInt): LongInt; cdecl; external;

begin
  if nx_twice(nx_add(19, 2)) <> 42 then
    Halt(1);
  WriteLn('C, C++, and Pascal built in declaration order.');
end.
