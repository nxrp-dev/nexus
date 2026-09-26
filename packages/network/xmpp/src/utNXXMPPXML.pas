unit utNXXMPPXML;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils;

function NXXMPPEscapeText(const AValue: UTF8String): UTF8String;
function NXXMPPEscapeAttribute(const AValue: UTF8String): UTF8String;

implementation

function NXXMPPEscapeText(const AValue: UTF8String): UTF8String;
var
  lIndex: Integer;
begin
  Result := '';
  for lIndex := 1 to Length(AValue) do
    case AValue[lIndex] of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
    else
      Result := Result + AValue[lIndex];
    end;
end;

function NXXMPPEscapeAttribute(const AValue: UTF8String): UTF8String;
var
  lIndex: Integer;
begin
  Result := '';
  for lIndex := 1 to Length(AValue) do
    case AValue[lIndex] of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
      '''': Result := Result + '&apos;';
    else
      Result := Result + AValue[lIndex];
    end;
end;

end.
