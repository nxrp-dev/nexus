(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit utNXSetupPaths;

{$mode delphi}{$H+}

interface

function IsAbsolutePath(const APath: string): Boolean;
function PathContains(const AFolder, APath: string): Boolean;

implementation

uses SysUtils;

function IsAbsolutePath(const APath: string): Boolean;
{$ifdef windows}var lDrive: string;{$endif}
begin
  {$ifdef windows}
  lDrive := ExtractFileDrive(APath);
  Result := (lDrive <> '') and
    (((Length(APath) > Length(lDrive)) and IsPathDelimiter(APath, Length(lDrive) + 1)) or
      ((Length(lDrive) > 2) and IsPathDelimiter(lDrive, 1)));
  {$else}
  Result := (ExtractFileDrive(APath) <> '') or
    ((APath <> '') and IsPathDelimiter(APath, 1));
  {$endif}
end;

function PathContains(const AFolder, APath: string): Boolean;
var
  lFolder: string;
begin
  lFolder := IncludeTrailingPathDelimiter(ExpandFileName(AFolder));
  Result := SameFileName(ExcludeTrailingPathDelimiter(lFolder), ExpandFileName(APath)) or
    SameFileName(lFolder, Copy(ExpandFileName(APath), 1, Length(lFolder)));
end;

end.
