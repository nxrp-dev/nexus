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

implementation

end.
