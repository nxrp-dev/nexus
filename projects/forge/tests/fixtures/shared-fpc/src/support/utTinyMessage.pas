unit utTinyMessage;

{$mode delphi}{$H+}

interface

function TinyMessage(const AFirst, ASecond: string): string;

implementation

function TinyMessage(const AFirst, ASecond: string): string;
const
  cPrefix = {$I greeting.inc};
begin
  Result := cPrefix + AFirst + ' ' + ASecond;
end;

end.
