unit utNXLSServiceHelpers;

{$mode objfpc}{$H+}

interface

uses
  CodeCache,
  obNXLSProtocolBase,
  obNXLSServiceContext;

procedure NXLSSetRange(ARange: TNXLSRange; AStartLine, AStartCharacter,
  AEndLine, AEndCharacter: Integer);
procedure NXLSSetIdentifierRange(ARange: TNXLSRange; ACode: TCodeBuffer;
  AX, AY: Integer);
procedure NXLSSetIdentifierRange(ALocation: TNXLSLocation; ACode: TCodeBuffer;
  AX, AY: Integer);
function NXLSIsIdentChar(AChar: Char): Boolean;
function NXLSIdentifierAt(ACode: TCodeBuffer; AX, AY: Integer): string;
function NXLSIdentifierNear(ACode: TCodeBuffer; AX, AY: Integer): string;
function NXLSWholeIdentifierAt(const ALine, AIdentifier: string;
  APos: Integer): Boolean;
function NXLSIdentifierAfterKeyword(const ALine, AKeyword: string): string;
function NXLSFindTypeDeclaration(ACode: TCodeBuffer; const AIdentifier: string;
  out AX, AY: Integer): Boolean;
function NXLSFindRoutineDeclarationInUses(ACode: TCodeBuffer;
  const AIdentifier: string; out ADeclCode: TCodeBuffer; out AX,
  AY: Integer): Boolean;
function NXLSProcNameFromHead(const AHead: string): string;
function NXLSParamTextFromHead(const AHead: string): string;

implementation

uses
  Classes,
  SysUtils,
  CodeToolManager,
  BasicCodeTools;

procedure NXLSSetRange(ARange: TNXLSRange; AStartLine, AStartCharacter,
  AEndLine, AEndCharacter: Integer);
begin
  if ARange = nil then
    Exit;

  NXLSSetPosition(ARange.start, AStartLine, AStartCharacter);
  NXLSSetPosition(ARange.&end, AEndLine, AEndCharacter);
  ARange.Assigned := True;
end;

procedure NXLSSetIdentifierRange(ARange: TNXLSRange; ACode: TCodeBuffer;
  AX, AY: Integer);
var
  lLine: string;
  lIdentStart: Integer;
  lIdentEnd: Integer;
begin
  if (ARange = nil) or (ACode = nil) or (AY < 0) or
    (AY >= ACode.LineCount) then
    Exit;

  lLine := ACode.GetLine(AY);
  GetIdentStartEndAtPosition(lLine, AX, lIdentStart, lIdentEnd);
  NXLSSetRange(ARange, AY, lIdentStart - 1, AY, lIdentEnd - 1);
end;

procedure NXLSSetIdentifierRange(ALocation: TNXLSLocation; ACode: TCodeBuffer;
  AX, AY: Integer);
begin
  if ALocation = nil then
    Exit;

  NXLSSetIdentifierRange(ALocation.range, ACode, AX, AY);
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

function NXLSFindTypeDeclaration(ACode: TCodeBuffer; const AIdentifier: string;
  out AX, AY: Integer): Boolean;
var
  lIdx: Integer;
  lLine: string;
  lTrimmed: string;
  lLower: string;
  lNameEnd: Integer;
  lInTypeSection: Boolean;
begin
  Result := False;
  AX := 0;
  AY := 0;
  if (ACode = nil) or (AIdentifier = '') then
    Exit;

  lInTypeSection := False;
  for lIdx := 0 to ACode.LineCount - 1 do
  begin
    lLine := ACode.GetLine(lIdx);
    lTrimmed := TrimLeft(lLine);
    lLower := LowerCase(Trim(lLine));
    if (lLower = 'type') then
    begin
      lInTypeSection := True;
      Continue;
    end;

    if lLower = '' then
      Continue;

    if (lLower = 'implementation') or (lLower = 'initialization') or
      (lLower = 'finalization') or (lLower = 'begin') or
      (Pos('procedure ', lLower) = 1) or (Pos('function ', lLower) = 1) or
      (Pos('constructor ', lLower) = 1) or
      (Pos('destructor ', lLower) = 1) or (Pos('const', lLower) = 1) or
      (Pos('var', lLower) = 1) or (Pos('resourcestring', lLower) = 1) then
      lInTypeSection := False;

    if not lInTypeSection then
      Continue;

    if not SameText(Copy(lTrimmed, 1, Length(AIdentifier)), AIdentifier) then
      Continue;

    lNameEnd := Length(AIdentifier) + 1;
    if (lNameEnd <= Length(lTrimmed)) and
      (lTrimmed[lNameEnd] in [' ', #9, '=', '<']) then
    begin
      AX := Pos(AIdentifier, lLine);
      AY := lIdx + 1;
      Exit(True);
    end;
  end;
end;

procedure NXLSCollectUsedUnits(ACode: TCodeBuffer; AUnits: TStrings);
var
  lIdx: Integer;
  lPartIdx: Integer;
  lText: string;
  lLine: string;
  lLower: string;
  lPart: string;
  lInUses: Boolean;
  lParts: TStringList;
begin
  if (ACode = nil) or (AUnits = nil) then
    Exit;

  lText := '';
  lInUses := False;
  for lIdx := 0 to ACode.LineCount - 1 do
  begin
    lLine := Trim(ACode.GetLine(lIdx));
    lLower := LowerCase(lLine);
    if Pos('uses', lLower) = 1 then
    begin
      lInUses := True;
      Delete(lLine, 1, 4);
    end
    else if not lInUses then
      Continue;

    lText := lText + ' ' + lLine;
    if Pos(';', lLine) > 0 then
    begin
      lInUses := False;
      lText := StringReplace(lText, ';', ',', [rfReplaceAll]);
      lParts := TStringList.Create;
      try
        lParts.StrictDelimiter := True;
        lParts.Delimiter := ',';
        lParts.DelimitedText := lText;
        for lPartIdx := 0 to lParts.Count - 1 do
        begin
          lPart := Trim(lParts[lPartIdx]);
          if Pos(' in ', LowerCase(lPart)) > 0 then
            lPart := Trim(Copy(lPart, 1, Pos(' in ', LowerCase(lPart)) - 1));
          lPart := StringReplace(lPart, '''', '', [rfReplaceAll]);
          lPart := StringReplace(lPart, '"', '', [rfReplaceAll]);
          if lPart <> '' then
            AUnits.Add(lPart);
        end;
      finally
        lParts.Free;
      end;
      lText := '';
    end;
  end;
end;

function NXLSLoadUsedUnit(ACode: TCodeBuffer; const AUnitName: string): TCodeBuffer;
const
  cUnitExts: array[0..2] of string = ('.pas', '.pp', '.p');
var
  lIdx: Integer;
  lCandidate: string;
  lFoundCode: TCodeBuffer;
begin
  Result := nil;
  if (ACode = nil) or (AUnitName = '') then
    Exit;

  for lIdx := Low(cUnitExts) to High(cUnitExts) do
  begin
    lCandidate := IncludeTrailingPathDelimiter(ExtractFileDir(ACode.Filename)) +
      AUnitName + cUnitExts[lIdx];
    if FileExists(lCandidate) then
      Exit(CodeToolBoss.LoadFile(lCandidate, False, False));
  end;

  for lIdx := Low(cUnitExts) to High(cUnitExts) do
  begin
    lFoundCode := CodeToolBoss.FindFile(AUnitName + cUnitExts[lIdx]);
    if lFoundCode <> nil then
      Exit(lFoundCode);
  end;
end;

function NXLSFindRoutineDeclaration(ACode: TCodeBuffer; const AIdentifier: string;
  out AX, AY: Integer): Boolean;
var
  lIdx: Integer;
  lLine: string;
  lName: string;
begin
  Result := False;
  AX := 0;
  AY := 0;
  if (ACode = nil) or (AIdentifier = '') then
    Exit;

  for lIdx := 0 to ACode.LineCount - 1 do
  begin
    lLine := ACode.GetLine(lIdx);
    lName := NXLSIdentifierAfterKeyword(lLine, 'function');
    if lName = '' then
      lName := NXLSIdentifierAfterKeyword(lLine, 'procedure');
    if SameText(lName, AIdentifier) then
    begin
      AX := Pos(AIdentifier, lLine);
      AY := lIdx + 1;
      Exit(True);
    end;
  end;
end;

function NXLSFindRoutineDeclarationInUses(ACode: TCodeBuffer;
  const AIdentifier: string; out ADeclCode: TCodeBuffer; out AX,
  AY: Integer): Boolean;
var
  lIdx: Integer;
  lUnits: TStringList;
  lUnitCode: TCodeBuffer;
begin
  Result := False;
  ADeclCode := nil;
  AX := 0;
  AY := 0;
  if (ACode = nil) or (AIdentifier = '') then
    Exit;

  lUnits := TStringList.Create;
  try
    lUnits.Sorted := True;
    lUnits.Duplicates := dupIgnore;
    NXLSCollectUsedUnits(ACode, lUnits);
    for lIdx := 0 to lUnits.Count - 1 do
    begin
      lUnitCode := NXLSLoadUsedUnit(ACode, lUnits[lIdx]);
      if NXLSFindRoutineDeclaration(lUnitCode, AIdentifier, AX, AY) then
      begin
        ADeclCode := lUnitCode;
        Exit(True);
      end;
    end;
  finally
    lUnits.Free;
  end;
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
