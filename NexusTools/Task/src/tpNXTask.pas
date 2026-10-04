(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit tpNXTask;

{$mode objfpc}{$H+}

interface

type
  TNXTaskValueKind = (tvkString, tvkInteger, tvkFloat, tvkBoolean, tvkReference);
  TNXTaskReferenceKind = (trkValue, trkNode);
  TNXTaskSeverity = (tdsInfo, tdsWarning, tdsError);
  TNXTaskApplicability = (taaAppliesExplicit, taaAppliesInherited,
    taaSkippedOwnTarget, taaSkippedParent);

function NXTaskValueKindName(AKind: TNXTaskValueKind): string;
function NXTaskSeverityName(ASeverity: TNXTaskSeverity): string;
function NXTaskApplicabilityName(AApplicability: TNXTaskApplicability): string;

implementation

function NXTaskValueKindName(AKind: TNXTaskValueKind): string;
begin
  case AKind of
    tvkString: Result := 'string';
    tvkInteger: Result := 'integer';
    tvkFloat: Result := 'float';
    tvkBoolean: Result := 'boolean';
    tvkReference: Result := 'reference';
  end;
end;

function NXTaskSeverityName(ASeverity: TNXTaskSeverity): string;
begin
  case ASeverity of
    tdsInfo: Result := 'info';
    tdsWarning: Result := 'warning';
    tdsError: Result := 'error';
  end;
end;

function NXTaskApplicabilityName(AApplicability: TNXTaskApplicability): string;
begin
  case AApplicability of
    taaAppliesExplicit: Result := 'applies-explicit';
    taaAppliesInherited: Result := 'applies-inherited';
    taaSkippedOwnTarget: Result := 'skipped-own-target';
    taaSkippedParent: Result := 'skipped-parent';
  end;
end;

end.
