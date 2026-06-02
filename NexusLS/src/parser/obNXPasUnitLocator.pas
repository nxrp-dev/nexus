unit obNXPasUnitLocator;

{$mode objfpc}{$H+}

interface

uses
  Classes;

type
  TNXPasUnitLocator = class
  private
    class function FindCaseInsensitive(const ADirectory,
      AFileName: string; out AMatch: string): Boolean; static;
  public
    class function FindUnitFile(const AUnitName: string; ASearchPaths: TStrings;
      out AFileName: string): Boolean; static;
    class function PathToFileURI(const AFileName: string): string; static;
  end;

implementation

uses
  SysUtils;

class function TNXPasUnitLocator.FindCaseInsensitive(const ADirectory,
  AFileName: string; out AMatch: string): Boolean;
var
  lInfo: TSearchRec;
begin
  Result := False;
  AMatch := '';
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile,
    lInfo) <> 0 then
    Exit;
  try
    repeat
      if SameText(lInfo.Name, AFileName) then
      begin
        AMatch := IncludeTrailingPathDelimiter(ADirectory) + lInfo.Name;
        Exit(True);
      end;
    until FindNext(lInfo) <> 0;
  finally
    FindClose(lInfo);
  end;
end;

class function TNXPasUnitLocator.FindUnitFile(const AUnitName: string;
  ASearchPaths: TStrings; out AFileName: string): Boolean;
const
  cExts: array[0..1] of string = ('.pas', '.pp');
var
  lCandidate: string;
  lDir: string;
  lExtIdx: Integer;
  lPathIdx: Integer;
begin
  Result := False;
  AFileName := '';
  if (Trim(AUnitName) = '') or (ASearchPaths = nil) then
    Exit;

  for lPathIdx := 0 to ASearchPaths.Count - 1 do
  begin
    lDir := ASearchPaths[lPathIdx];
    if not DirectoryExists(lDir) then
      Continue;

    for lExtIdx := Low(cExts) to High(cExts) do
    begin
      lCandidate := IncludeTrailingPathDelimiter(lDir) + AUnitName + cExts[lExtIdx];
      if FileExists(lCandidate) then
      begin
        AFileName := ExpandFileName(lCandidate);
        Exit(True);
      end;

      if FindCaseInsensitive(lDir, AUnitName + cExts[lExtIdx], lCandidate) then
      begin
        AFileName := ExpandFileName(lCandidate);
        Exit(True);
      end;
    end;
  end;
end;

class function TNXPasUnitLocator.PathToFileURI(const AFileName: string): string;
var
  lIdx: Integer;
  lPath: string;

  function EncodeChar(AChar: Char): string;
  const
    cHex = '0123456789ABCDEF';
  var
    lValue: Byte;
  begin
    if AChar in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~', '/', ':'] then
      Result := AChar
    else
    begin
      lValue := Ord(AChar);
      Result := '%' + cHex[(lValue shr 4) + 1] + cHex[(lValue and $0F) + 1];
    end;
  end;

begin
  lPath := StringReplace(ExpandFileName(AFileName), DirectorySeparator, '/',
    [rfReplaceAll]);
  Result := 'file:///';
  for lIdx := 1 to Length(lPath) do
    Result := Result + EncodeChar(lPath[lIdx]);
end;

end.
