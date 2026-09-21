unit utNXXMPPDateTime;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, DateUtils;

function NXXMPPTryParseTimestamp(const AValue: UTF8String;
  out ADateTime: TDateTime): Boolean;
function NXXMPPFormatTimestamp(ADateTime: TDateTime): UTF8String;

implementation

function NXXMPPTryParseTimestamp(const AValue: UTF8String;
  out ADateTime: TDateTime): Boolean;
begin
  ADateTime := 0;
  Result := (AValue <> '') and TryISO8601ToDate(string(AValue),
    ADateTime, True);
end;

function NXXMPPFormatTimestamp(ADateTime: TDateTime): UTF8String;
begin
  Result := UTF8String(DateToISO8601(ADateTime, True));
end;

end.
