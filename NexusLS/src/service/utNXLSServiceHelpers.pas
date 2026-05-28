unit utNXLSServiceHelpers;

{$mode objfpc}{$H+}

interface

uses
  CodeCache,
  obNXLSProtocolBase,
  obNXLSServiceContext;

procedure NXLSSetRange(ARange: TNXLSRange; AStartLine, AStartCharacter,
  AEndLine, AEndCharacter: Integer);
procedure NXLSSetIdentifierRange(ALocation: TNXLSLocation; ACode: TCodeBuffer;
  AX, AY: Integer);
function NXLSIsIdentChar(AChar: Char): Boolean;
function NXLSIdentifierAt(ACode: TCodeBuffer; AX, AY: Integer): string;
function NXLSIdentifierNear(ACode: TCodeBuffer; AX, AY: Integer): string;
function NXLSWholeIdentifierAt(const ALine, AIdentifier: string;
  APos: Integer): Boolean;
function NXLSIdentifierAfterKeyword(const ALine, AKeyword: string): string;
function NXLSProcNameFromHead(const AHead: string): string;
function NXLSParamTextFromHead(const AHead: string): string;

implementation

uses
  SysUtils,
  BasicCodeTools;

procedure NXLSSetRange(ARange: TNXLSRange; AStartLine, AStartCharacter,
  AEndLine, AEndCharacter: Integer);
begin
  NXLSSetPosition(ARange.start, AStartLine, AStartCharacter);
  NXLSSetPosition(ARange.&end, AEndLine, AEndCharacter);
  ARange.Assigned := True;
end;

procedure NXLSSetIdentifierRange(ALocation: TNXLSLocation; ACode: TCodeBuffer;
  AX, AY: Integer);
var
  lLine: string;
  lIdentStart: Integer;
  lIdentEnd: Integer;
begin
  if (ALocation = nil) or (ACode = nil) or (AY < 0) or
    (AY >= ACode.LineCount) then
    Exit;

  lLine := ACode.GetLine(AY);
  GetIdentStartEndAtPosition(lLine, AX, lIdentStart, lIdentEnd);
  NXLSSetRange(ALocation.range, AY, lIdentStart - 1, AY, lIdentEnd - 1);
end;

function NXLSIsIdentChar(AChar: Char): Boolean;
begin
  Result := AChar in ['A'..'Z', 'a'..'z', '_', '0'..'9'];
end;

function NXLSIdentifierAt(ACode: TCodeBuffer; AX, AY: Integer): string;
var
  lLine: string;
  lIdentStart: Integer;
  lIdentEnd: Integer;
begin
  Result := '';
  if (ACode = nil) or (AY < 0) or (AY >= ACode.LineCount) then
    Exit;

  lLine := ACode.GetLine(AY);
  GetIdentStartEndAtPosition(lLine, AX, lIdentStart, lIdentEnd);
  if (lIdentStart > 0) and (lIdentEnd >= lIdentStart) then
    Result := Copy(lLine, lIdentStart, lIdentEnd - lIdentStart);
end;

function NXLSIdentifierNear(ACode: TCodeBuffer; AX, AY: Integer): string;
var
  lLine: string;
  lPos: Integer;
  lStart: Integer;
  lEnd: Integer;
begin
  Result := NXLSIdentifierAt(ACode, AX, AY);
  if (Result <> '') or (ACode = nil) or (AY < 0) or
    (AY >= ACode.LineCount) then
    Exit;

  lLine := ACode.GetLine(AY);
  lPos := AX;
  if lPos > Length(lLine) then
    lPos := Length(lLine);

  while (lPos >= 1) and (not NXLSIsIdentChar(lLine[lPos])) do
    Dec(lPos);
  if lPos < 1 then
    Exit;

  lStart := lPos;
  while (lStart > 1) and NXLSIsIdentChar(lLine[lStart - 1]) do
    Dec(lStart);
  lEnd := lPos;
  while (lEnd < Length(lLine)) and NXLSIsIdentChar(lLine[lEnd + 1]) do
    Inc(lEnd);

  Result := Copy(lLine, lStart, lEnd - lStart + 1);
end;

function NXLSWholeIdentifierAt(const ALine, AIdentifier: string;
  APos: Integer): Boolean;
var
  lBefore: Integer;
  lAfter: Integer;
begin
  lBefore := APos - 1;
  lAfter := APos + Length(AIdentifier);
  Result := ((lBefore < 1) or (not NXLSIsIdentChar(ALine[lBefore]))) and
    ((lAfter > Length(ALine)) or (not NXLSIsIdentChar(ALine[lAfter])));
end;

function NXLSIdentifierAfterKeyword(const ALine, AKeyword: string): string;
var
  lText: string;
  lIdx: Integer;
begin
  Result := '';
  lText := Trim(ALine);
  if Pos(LowerCase(AKeyword) + ' ', LowerCase(lText)) <> 1 then
    Exit;

  lText := Trim(Copy(lText, Length(AKeyword) + 2, MaxInt));
  lIdx := 1;
  while (lIdx <= Length(lText)) and
    (lText[lIdx] in ['A'..'Z', 'a'..'z', '_', '.', '0'..'9']) do
    Inc(lIdx);
  Result := Copy(lText, 1, lIdx - 1);
  if Pos('.', Result) > 0 then
    Result := Copy(Result, LastDelimiter('.', Result) + 1, MaxInt);
end;

function NXLSProcNameFromHead(const AHead: string): string;
var
  lName: string;
  lIdx: Integer;
begin
  Result := '';
  lName := NXLSIdentifierAfterKeyword(AHead, 'procedure');
  if lName = '' then
    lName := NXLSIdentifierAfterKeyword(AHead, 'function');
  if lName = '' then
    Exit;

  lIdx := Pos('.', lName);
  while lIdx > 0 do
  begin
    Delete(lName, 1, lIdx);
    lIdx := Pos('.', lName);
  end;
  Result := lName;
end;

function NXLSParamTextFromHead(const AHead: string): string;
var
  lOpenPos: Integer;
  lClosePos: Integer;
begin
  Result := '';
  lOpenPos := Pos('(', AHead);
  lClosePos := LastDelimiter(')', AHead);
  if (lOpenPos > 0) and (lClosePos > lOpenPos) then
    Result := Copy(AHead, lOpenPos + 1, lClosePos - lOpenPos - 1);
end;

end.
