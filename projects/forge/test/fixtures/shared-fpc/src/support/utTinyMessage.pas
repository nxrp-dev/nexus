(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit utTinyMessage;

{$mode delphi}{$H+}

interface

function TinyMessage(const AFirst, ASecond: string): string;

implementation

function TinyMessage(const AFirst, ASecond: string): string;
const
  cPrefix = {$I greeting.inc};
begin
  Result := cPrefix + AFirst + ' ' + ASecond;
end;

end.
