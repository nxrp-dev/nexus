(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit utNXForgePackageFiles;

{$mode delphi}{$H+}

interface

uses Classes, fpjson;

procedure WriteText(const AFileName, AText: string);
function FileHash(const AFileName: string): string;
procedure CollectFiles(const ADirectory: string; ARecursive: Boolean; AFiles: TStrings);
function ReadIdentity(const AFileName: string): TJSONObject;
procedure RequireHexIdentity(const AValue: string; ALength: Integer);
function NewPackageBuildIdentity: string;

implementation

uses SysUtils, jsonparser, HlpHashFactory;

function NewPackageBuildIdentity: string;
var
  lGUID: TGUID;
begin
  if CreateGUID(lGUID) <> 0 then raise Exception.Create('Cannot create package build identity');
  Result := UpperCase(StringReplace(Copy(GUIDToString(lGUID), 2, 36), '-', '', [rfReplaceAll]));
end;

procedure WriteText(const AFileName, AText: string);
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFileName, fmCreate);
  try
    if AText <> '' then lStream.WriteBuffer(AText[1], Length(AText));
  finally
    lStream.Free;
  end;
end;

function FileHash(const AFileName: string): string;
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := UpperCase(THashFactory.TCrypto.CreateSHA2_256.ComputeStream(lStream).ToString(False));
  finally
    lStream.Free;
  end;
end;

procedure CollectFiles(const ADirectory: string; ARecursive: Boolean;
  AFiles: TStrings);
var
  lSearch: TSearchRec;
  lPath: string;
begin
  if not DirectoryExists(ADirectory) then
    raise Exception.Create('Missing package SDK input directory: ' + ADirectory);
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, lSearch) <> 0 then Exit;
  try
    repeat
      if (lSearch.Name = '.') or (lSearch.Name = '..') then Continue;
      lPath := IncludeTrailingPathDelimiter(ADirectory) + lSearch.Name;
      if (lSearch.Attr and faDirectory) <> 0 then
      begin
        if ARecursive then CollectFiles(lPath, True, AFiles);
      end
      else AFiles.Add(lPath);
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;
end;

function ReadIdentity(const AFileName: string): TJSONObject;
var
  lStream: TFileStream;
  lData: TJSONData;
begin
  lStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    lData := GetJSON(lStream);
  finally
    lStream.Free;
  end;
  if not (lData is TJSONObject) then
  begin
    lData.Free;
    raise Exception.Create('Invalid package SDK identity record: ' + AFileName);
  end;
  Result := TJSONObject(lData);
end;

procedure RequireHexIdentity(const AValue: string; ALength: Integer);
var
  lCharacter: Char;
begin
  if Length(AValue) <> ALength then raise Exception.Create('Invalid package SDK/build identity');
  for lCharacter in AValue do
    if not (lCharacter in ['0'..'9', 'A'..'F', 'a'..'f']) then
      raise Exception.Create('Invalid package SDK/build identity');
end;

end.
