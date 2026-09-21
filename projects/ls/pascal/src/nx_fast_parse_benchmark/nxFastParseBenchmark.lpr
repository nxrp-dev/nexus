program nxFastParseBenchmark;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  obNXFastParse;

type
  TStringArray = array of string;
  TNXKeywordTester = function(const AText: string): Boolean;

function IsPascalKeywordOld(const AText: string): Boolean;
begin
  Result := (AText = 'absolute') or (AText = 'and') or (AText = 'array') or (AText = 'as') or
    (AText = 'asm') or (AText = 'begin') or (AText = 'bitpacked') or
    (AText = 'case') or
    (AText = 'class') or (AText = 'const') or (AText = 'constructor') or
    (AText = 'destructor') or (AText = 'dispinterface') or
    (AText = 'div') or (AText = 'do') or (AText = 'downto') or
    (AText = 'else') or (AText = 'end') or (AText = 'except') or
    (AText = 'exports') or (AText = 'file') or
    (AText = 'false') or (AText = 'finalization') or
    (AText = 'finally') or (AText = 'for') or (AText = 'function') or (AText = 'generic') or (AText = 'goto') or
    (AText = 'helper') or (AText = 'if') or
    (AText = 'implementation') or (AText = 'in') or
    (AText = 'inherited') or (AText = 'initialization') or
    (AText = 'inline') or (AText = 'interface') or (AText = 'is') or
    (AText = 'label') or (AText = 'library') or (AText = 'mod') or
    (AText = 'nil') or (AText = 'not') or (AText = 'object') or
    (AText = 'of') or (AText = 'on') or (AText = 'operator') or (AText = 'or') or
    (AText = 'out') or (AText = 'package') or (AText = 'packed') or (AText = 'private') or
    (AText = 'procedure') or (AText = 'program') or
    (AText = 'property') or (AText = 'protected') or
    (AText = 'public') or (AText = 'published') or (AText = 'raise') or
    (AText = 'record') or (AText = 'repeat') or
    (AText = 'resourcestring') or (AText = 'set') or (AText = 'shl') or
    (AText = 'shr') or (AText = 'specialize') or (AText = 'string') or (AText = 'then') or
    (AText = 'threadvar') or (AText = 'to') or (AText = 'try') or
    (AText = 'true') or (AText = 'type') or (AText = 'unit') or (AText = 'until') or
    (AText = 'uses') or (AText = 'var') or (AText = 'while') or
    (AText = 'with') or (AText = 'xor');
end;

function IsPascalKeywordNew(const AText: string): Boolean;
begin
  Result := TNXPascalKeywordSet.Contains(AText);
end;

function IsIdentStart(const AChar: Char): Boolean; inline;
begin
  Result := (AChar = '_') or ((AChar >= 'A') and (AChar <= 'Z')) or ((AChar >= 'a') and (AChar <= 'z'));
end;

function IsIdentChar(const AChar: Char): Boolean; inline;
begin
  Result := IsIdentStart(AChar) or ((AChar >= '0') and (AChar <= '9'));
end;

function LowerAscii(const AText: string): string;
var
  lIndex: SizeInt;
begin
  Result := AText;

  for lIndex := 1 to Length(Result) do
  begin
    if (Result[lIndex] >= 'A') and (Result[lIndex] <= 'Z') then
      Result[lIndex] := Chr(Ord(Result[lIndex]) + 32);
  end;
end;

procedure AddToken(var ATokens: TStringArray; var ACount: SizeInt; const AToken: string);
begin
  if ACount >= Length(ATokens) then
    SetLength(ATokens, Length(ATokens) + 65536);

  ATokens[ACount] := AToken;
  Inc(ACount);
end;

procedure ExtractTokensFromText(const AText: string; var ATokens: TStringArray; var ACount: SizeInt);
var
  lIndex: SizeInt;
  lStart: SizeInt;
  lLength: SizeInt;
  lToken: string;
begin
  lIndex := 1;

  while lIndex <= Length(AText) do
  begin
    if IsIdentStart(AText[lIndex]) then
    begin
      lStart := lIndex;
      Inc(lIndex);

      while (lIndex <= Length(AText)) and IsIdentChar(AText[lIndex]) do
        Inc(lIndex);

      lLength := lIndex - lStart;
      SetString(lToken, PChar(@AText[lStart]), lLength);
      AddToken(ATokens, ACount, LowerAscii(lToken));
    end
    else
      Inc(lIndex);
  end;
end;

function ReadFileText(const AFileName: string): string;
var
  lStream: TFileStream;
begin
  Result := '';
  lStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);

  try
    SetLength(Result, lStream.Size);

    if lStream.Size > 0 then
      lStream.ReadBuffer(Result[1], lStream.Size);
  finally
    lStream.Free;
  end;
end;

procedure CollectPasFiles(const AFolder: string; AFiles: TStrings);
var
  lSearch: TSearchRec;
  lResult: LongInt;
  lPath: string;
  lName: string;
begin
  lPath := IncludeTrailingPathDelimiter(AFolder);
  lResult := FindFirst(lPath + '*', faAnyFile, lSearch);

  try
    while lResult = 0 do
    begin
      lName := lSearch.Name;

      if (lName <> '.') and (lName <> '..') then
      begin
        if (lSearch.Attr and faDirectory) <> 0 then
          CollectPasFiles(lPath + lName, AFiles)
        else if SameText(ExtractFileExt(lName), '.pas') then
          AFiles.Add(lPath + lName);
      end;

      lResult := FindNext(lSearch);
    end;
  finally
    FindClose(lSearch);
  end;
end;

procedure LoadTokens(const AFolder: string; var ATokens: TStringArray; var ATokenCount: SizeInt; out AFileCount: SizeInt);
var
  lFiles: TStringList;
  lIndex: Integer;
  lText: string;
begin
  ATokenCount := 0;
  AFileCount := 0;
  lFiles := TStringList.Create;

  try
    CollectPasFiles(AFolder, lFiles);
    AFileCount := lFiles.Count;

    for lIndex := 0 to lFiles.Count - 1 do
    begin
      lText := ReadFileText(lFiles[lIndex]);
      ExtractTokensFromText(lText, ATokens, ATokenCount);
    end;
  finally
    lFiles.Free;
  end;
end;

function RunBenchmark(const ATokens: array of string; const ATokenCount: SizeInt; const ARepetitions: LongInt; const ATester: TNXKeywordTester; out AHits: QWord): QWord;
var
  lStart: QWord;
  lStop: QWord;
  lRep: LongInt;
  lIndex: SizeInt;
begin
  AHits := 0;
  lStart := GetTickCount64;

  for lRep := 1 to ARepetitions do
  begin
    for lIndex := 0 to ATokenCount - 1 do
    begin
      if ATester(ATokens[lIndex]) then
        Inc(AHits);
    end;
  end;

  lStop := GetTickCount64;
  Result := lStop - lStart;
end;

procedure WriteUsage;
begin
  WriteLn('Usage: nxFastParseBenchmark <folder> [repetitions]');
  WriteLn('Example: nxFastParseBenchmark c:\dev\nexus 10');
end;

var
  lFolder: string;
  lRepetitions: LongInt;
  lTokens: array of string;
  lTokenCount: SizeInt;
  lFileCount: SizeInt;
  lScanStart: QWord;
  lScanTicks: QWord;
  lOldTicks: QWord;
  lNewTicks: QWord;
  lOldHits: QWord;
  lNewHits: QWord;
  lTotalChecks: QWord;
begin
  if ParamCount < 1 then
  begin
    WriteUsage;
    Halt(1);
  end;

  lFolder := ParamStr(1);
  lRepetitions := 1;

  if ParamCount >= 2 then
    lRepetitions := StrToIntDef(ParamStr(2), 1);

  if lRepetitions < 1 then
    lRepetitions := 1;

  SetLength(lTokens, 65536);

  lScanStart := GetTickCount64;
  LoadTokens(lFolder, lTokens, lTokenCount, lFileCount);
  lScanTicks := GetTickCount64 - lScanStart;
  SetLength(lTokens, lTokenCount);

  if lTokenCount = 0 then
  begin
    WriteLn('No Pascal tokens found.');
    Halt(0);
  end;

  lOldTicks := RunBenchmark(lTokens, lTokenCount, lRepetitions, @IsPascalKeywordOld, lOldHits);
  lNewTicks := RunBenchmark(lTokens, lTokenCount, lRepetitions, @IsPascalKeywordNew, lNewHits);
  lTotalChecks := QWord(lTokenCount) * QWord(lRepetitions);

  WriteLn('Files:       ', lFileCount);
  WriteLn('Tokens:      ', lTokenCount);
  WriteLn('Repetitions: ', lRepetitions);
  WriteLn('Checks:      ', lTotalChecks);
  WriteLn('Scan ms:     ', lScanTicks);
  WriteLn;
  WriteLn('Old hits:    ', lOldHits);
  WriteLn('Old ms:      ', lOldTicks);
  WriteLn;
  WriteLn('New hits:    ', lNewHits);
  WriteLn('New ms:      ', lNewTicks);

  if lOldHits <> lNewHits then
    WriteLn('WARNING: hit counts differ. Keyword lists are not identical.');
  ReadLn;
end.
