(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXLSDocumentParse;

{$mode objfpc}{$H+}

interface

uses
  obNXLSServiceContext,
  obNXPasSource;

function NXLSCreatePascalSource(ADocument: TNXLSDocument): TNXPasSourceFile;

implementation

uses
  SysUtils;

function NXLSCreatePascalSource(ADocument: TNXLSDocument): TNXPasSourceFile;
begin
  if ADocument = nil then
    raise Exception.Create('Document is required.');

  Result := TNXPasSourceFile.Create(ADocument.LocalPath, ADocument.URI,
    ADocument.Text);
end;

end.
