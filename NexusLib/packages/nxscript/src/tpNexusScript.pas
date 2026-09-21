unit tpNexusScript;

{$mode delphi}{$H+}

interface

type
  TNexusScriptPosition = record
    Offset: Integer;
    Line: Integer;
    Column: Integer;
  end;

  TNexusScriptRange = record
    SourceName: string;
    StartPosition: TNexusScriptPosition;
    EndPosition: TNexusScriptPosition;
  end;

  TNexusScriptValueKind = (
    nsvText,
    nsvArray,
    nsvReference,
    nsvTextComposition,
    nsvDefinition
  );

  TNexusScriptValueEvaluationState = (
    nsvesPending,
    nsvesResolving,
    nsvesCompleted,
    nsvesFailed
  );

  TNexusScriptArrayPreparationState = (
    nsapsUnprepared,
    nsapsPreparing,
    nsapsPrepared,
    nsapsFailed
  );

implementation

end.
