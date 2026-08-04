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
