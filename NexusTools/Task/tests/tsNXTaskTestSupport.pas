(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tsNXTaskTestSupport;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, obNXTestContext, obNXTaskModel;

function NXTaskSamplePath(const AName: string): string;
function NXTaskFindDiagnostic(ADiagnostics: TNXTaskDiagnostics;
  const ACode: string): TNXTaskDiagnostic;
procedure NXTaskAssertContains(AContext: TNXTestContext; const AText,
  AExpected, AMessage: string);
procedure NXTaskAssertDiagnostic(AContext: TNXTestContext;
  ADiagnostics: TNXTaskDiagnostics; const ACode, AMessage: string);

implementation

function NXTaskSamplePath(const AName: string): string;
begin
  Result := ExpandFileName(IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    '..\..\..\NexusTools\Task\samples\' + AName);
  if not FileExists(Result) then
    Result := ExpandFileName(IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
      '..\..\samples\' + AName);
  if not FileExists(Result) then
    Result := ExpandFileName('samples\' + AName);
  if not FileExists(Result) then
    Result := ExpandFileName('NexusTools\Task\samples\' + AName);
end;

function NXTaskFindDiagnostic(ADiagnostics: TNXTaskDiagnostics;
  const ACode: string): TNXTaskDiagnostic;
var
  lIndex: Integer;
begin
  Result := nil;
  for lIndex := 0 to ADiagnostics.Count - 1 do
    if ADiagnostics.Item(lIndex).Code = ACode then
      Exit(ADiagnostics.Item(lIndex));
end;

procedure NXTaskAssertContains(AContext: TNXTestContext; const AText,
  AExpected, AMessage: string);
begin
  AContext.AssertTrue(Pos(AExpected, AText) > 0, AMessage + ' Missing: ' +
    AExpected);
end;

procedure NXTaskAssertDiagnostic(AContext: TNXTestContext;
  ADiagnostics: TNXTaskDiagnostics; const ACode, AMessage: string);
begin
  if NXTaskFindDiagnostic(ADiagnostics, ACode) <> nil then
    Exit;
  AContext.Fail(AMessage + ' Missing diagnostic: ' + ACode);
end;

end.
