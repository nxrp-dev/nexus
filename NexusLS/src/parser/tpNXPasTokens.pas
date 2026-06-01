unit tpNXPasTokens;

{$mode objfpc}{$H+}

interface

type
  TNXPasTokenKind = (
    ptkUnknown,
    ptkEndOfFile,
    ptkWhitespace,
    ptkIdentifier,
    ptkKeyword,
    ptkNumber,
    ptkString,
    ptkSymbol,
    ptkComment,
    ptkDirective
  );

  TNXPasSourcePosition = record
    Offset: Integer;
    Line: Integer;
    Column: Integer;
  end;

  TNXPasToken = record
    Kind: TNXPasTokenKind;
    Text: string;
    StartPos: TNXPasSourcePosition;
    EndPos: TNXPasSourcePosition;
  end;

function NXPasTokenKindName(AKind: TNXPasTokenKind): string;

implementation

function NXPasTokenKindName(AKind: TNXPasTokenKind): string;
begin
  case AKind of
    ptkUnknown:
      Result := 'Unknown';
    ptkEndOfFile:
      Result := 'EndOfFile';
    ptkWhitespace:
      Result := 'Whitespace';
    ptkIdentifier:
      Result := 'Identifier';
    ptkKeyword:
      Result := 'Keyword';
    ptkNumber:
      Result := 'Number';
    ptkString:
      Result := 'String';
    ptkSymbol:
      Result := 'Symbol';
    ptkComment:
      Result := 'Comment';
    ptkDirective:
      Result := 'Directive';
  else
    Result := '';
  end;
end;

end.
