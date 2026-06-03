unit obNXFastPascal;
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, obNXFastParse, obNXMeasuredStructure;

type
  TNXPascalKeywordSet = class sealed
  private
    class var FKeywordSet: TNXFastStringSet;

  public
    class constructor Create;
    class destructor Destroy;

    class function Contains(const AText: string): Boolean; static; inline;
    class function GetMetrics: TNXFastStringSetMetrics; static;
    class function MetricsAsJSON: string; static;
  end;

const
  cPascalKeywords: array[0..78] of string = (
    'absolute', 'and', 'array', 'as', 'asm', 'begin', 'bitpacked',
    'case', 'class', 'const', 'constructor', 'destructor', 'dispinterface',
    'div', 'do', 'downto', 'else', 'end', 'except', 'exports', 'file',
    'false', 'finalization', 'finally', 'for', 'function', 'generic', 'goto',
    'helper', 'if', 'implementation', 'in', 'inherited', 'initialization',
    'inline', 'interface', 'is', 'label', 'library', 'mod', 'nil', 'not',
    'object', 'of', 'on', 'operator', 'or', 'out', 'package', 'packed',
    'private', 'procedure', 'program', 'property', 'protected', 'public',
    'published', 'raise', 'record', 'repeat', 'resourcestring', 'set',
    'shl', 'shr', 'specialize', 'string', 'then', 'threadvar', 'to', 'try',
    'true', 'type', 'unit', 'until', 'uses', 'var', 'while', 'with', 'xor'
  );

implementation

class constructor TNXPascalKeywordSet.Create;
begin
  FKeywordSet := TNXFastStringSet.Create(cPascalKeywords);
end;

class destructor TNXPascalKeywordSet.Destroy;
begin
  FreeAndNil(FKeywordSet);
end;

class function TNXPascalKeywordSet.Contains(const AText: string): Boolean;
begin
  Result := FKeywordSet.Contains(AText);
end;

class function TNXPascalKeywordSet.GetMetrics: TNXFastStringSetMetrics;
begin
  Result := FKeywordSet.Metrics;
end;

class function TNXPascalKeywordSet.MetricsAsJSON: string;
begin
  Result := NXMetricsToJSON(FKeywordSet.Metrics);
end;

end.
