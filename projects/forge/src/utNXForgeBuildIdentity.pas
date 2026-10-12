(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit utNXForgeBuildIdentity;

{$mode delphi}{$H+}

interface

function WriteForgeBuildIdentity(const ARepository, AOutputDirectory,
  AEpochOverride: string): string;

implementation

uses Classes, SysUtils, DateUtils, fpjson, obNXForgeInvocation, obNXForgeProcess;

function ReadGit(const ARepository, AArguments: string): string;
var
  lInvocation: TNXForgeInvocation;
  lError: string;
begin
  lInvocation := TNXForgeInvocation.Create;
  try
    lInvocation.WorkingDirectory := ARepository;
    lInvocation.Command := 'git ' + AArguments;
    ExecuteForgeProcess(lInvocation);
    if not lInvocation.Succeeded then
    begin
      lError := lInvocation.Diagnostic;
      if lError = '' then lError := Trim(lInvocation.StdErr);
      raise Exception.CreateFmt('BuildIdentity: git %s failed in "%s" (exit %d): %s',
        [AArguments, ARepository, lInvocation.ExitStatus, lError]);
    end;
    Result := Trim(lInvocation.StdOut);
  finally
    lInvocation.Free;
  end;
end;

function ParseEpoch(const AText: string): Int64;
var
  lText: string;
  lCharacter: Char;
begin
  lText := Trim(AText);
  for lCharacter in lText do
    if not (lCharacter in ['0'..'9']) then
      raise Exception.Create('BuildIdentity: SOURCE_DATE_EPOCH/commit timestamp must be non-negative integer seconds');
  if not TryStrToInt64(lText, Result) or (Result < 0) or
    (Result > 253402300799) then
    raise Exception.Create('BuildIdentity: SOURCE_DATE_EPOCH/commit timestamp must be integer seconds between 0 and 253402300799');
end;

procedure WriteText(const AFileName, AText: string);
var
  lFile: TFileStream;
begin
  lFile := TFileStream.Create(AFileName, fmCreate);
  try
    if AText <> '' then lFile.WriteBuffer(AText[1], Length(AText));
  finally
    lFile.Free;
  end;
end;

function WriteForgeBuildIdentity(const ARepository, AOutputDirectory,
  AEpochOverride: string): string;
var
  lOutput, lSource, lRevision, lIdentity, lEpoch, lDate, lTime: string;
  lDirty: Boolean;
  lSeconds: Int64;
  lTimestamp: TDateTime;
  lRecord: TJSONObject;
begin
  // This bounded operation currently owns the FPC bootstrap's three file formats.
  lOutput := IncludeTrailingPathDelimiter(AOutputDirectory);
  lSource := lOutput + 'source' + PathDelim;
  if not FileExists(lSource + 'version.pas') then
    raise Exception.Create('Compiler source must be staged before writing its identity: ' + lSource);
  lRevision := ReadGit(ARepository, 'rev-parse --verify HEAD');
  lDirty := ReadGit(ARepository, 'status --porcelain --untracked-files=normal') <> '';
  lEpoch := AEpochOverride;
  if lEpoch = '' then lEpoch := ReadGit(ARepository, 'show -s --format=%ct ' + lRevision);
  lSeconds := ParseEpoch(lEpoch);
  lTimestamp := UnixToDateTime(lSeconds, True);
  lDate := FormatDateTime('yyyy"/"mm"/"dd', lTimestamp);
  lTime := FormatDateTime('hh":"nn":"ss', lTimestamp);
  lIdentity := lRevision;
  if lDirty then lIdentity := lIdentity + '-dirty';
  lRecord := TJSONObject.Create;
  try
    lRecord.Add('Revision', lRevision);
    lRecord.Add('Dirty', lDirty);
    lRecord.Add('Identity', lIdentity);
    lRecord.Add('Date', lDate);
    lRecord.Add('Time', lTime);
    lRecord.Add('SourceDateEpoch', lSeconds);
    WriteText(lSource + 'revision.inc', QuotedStr(lIdentity) + #10);
    WriteText(lOutput + 'build-options.cfg', '-DD' + lDate + #10 + '-DT' + lTime + #10);
    WriteText(lOutput + 'build-identity.json', lRecord.AsJSON + #10);
  finally
    lRecord.Free;
  end;
  Result := 'Build identity: ' + lIdentity + '; compiler date: ' + lDate + ' ' + lTime + ' UTC' + LineEnding;
end;

end.
