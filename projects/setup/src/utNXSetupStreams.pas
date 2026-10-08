(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit utNXSetupStreams;

{$mode delphi}{$H+}

interface

uses Classes;

procedure WriteNumber(AStream: TStream; AValue: QWord);
function ReadNumber(AStream: TStream): QWord;
procedure WriteText(AStream: TStream; const AText: string);
function ReadText(AStream: TStream): string;
function ReadCount(AStream: TStream): Integer;
procedure RequireEnd(AStream: TStream);

implementation

uses SysUtils;

procedure WriteNumber(AStream: TStream; AValue: QWord);
var
  lValue: QWord;
begin
  lValue := NtoLE(AValue);
  AStream.WriteBuffer(lValue, SizeOf(lValue));
end;

function ReadNumber(AStream: TStream): QWord;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
  Result := LEtoN(Result);
end;

procedure WriteText(AStream: TStream; const AText: string);
var
  lText: RawByteString;
begin
  lText := AText;
  WriteNumber(AStream, Length(lText));
  if lText <> '' then AStream.WriteBuffer(lText[1], Length(lText));
end;

function ReadText(AStream: TStream): string;
var
  lText: RawByteString;
  lLength: QWord;
begin
  lLength := ReadNumber(AStream);
  if (lLength > QWord(AStream.Size - AStream.Position)) or (lLength > MaxInt) then
    raise EReadError.Create('Invalid Setup string length.');
  SetLength(lText, lLength);
  if lLength <> 0 then AStream.ReadBuffer(lText[1], lLength);
  Result := lText;
end;

function ReadCount(AStream: TStream): Integer;
var
  lCount: QWord;
begin
  lCount := ReadNumber(AStream);
  if (lCount > MaxInt) or (lCount > QWord(AStream.Size - AStream.Position)) then
    raise EReadError.Create('Invalid Setup collection length.');
  Result := lCount;
end;

procedure RequireEnd(AStream: TStream);
begin
  if AStream.Position <> AStream.Size then
    raise EReadError.Create('Unexpected data after Setup record.');
end;

end.
