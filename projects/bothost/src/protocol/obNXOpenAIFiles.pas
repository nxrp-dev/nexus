(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXOpenAIFiles;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues;

type
  TNXOpenAIFileObject = class(TNXJSONObject)
  private
    Fbytes: TNXJSONInteger;
    Ffilename: TNXJSONString;
    Fid: TNXJSONString;
    Fpurpose: TNXJSONString;
    Fstatus: TNXJSONString;
  published
    property bytes: TNXJSONInteger read Fbytes write Fbytes;
    property filename: TNXJSONString read Ffilename write Ffilename;
    property id: TNXJSONString read Fid write Fid;
    property purpose: TNXJSONString read Fpurpose write Fpurpose;
    property status: TNXJSONString read Fstatus write Fstatus;
  end;

implementation

end.
