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

  TNXPascalRoutineDirectiveSet = class sealed
  private
    class var FDirectiveSet: TNXFastStringSet;

  public
    class constructor Create;
    class destructor Destroy;

    class function Contains(const AText: string): Boolean; static; inline;
    class function GetMetrics: TNXFastStringSetMetrics; static;
    class function MetricsAsJSON: string; static;
  end;

  TNXPascalDeclarationTailKeywordSet = class sealed
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

  cPascalRoutineDirectives: array[0..35] of string = (
    'abstract', 'alias', 'assembler', 'cdecl', 'compilerproc', 'deprecated',
    'dynamic', 'experimental', 'export', 'external', 'far', 'final',
    'forward', 'hardfloat', 'inline', 'message', 'ms_abi_cdecl',
    'ms_abi_default', 'mwpascal', 'noreturn', 'oldfpccall', 'overload',
    'override', 'pascal', 'platform', 'public', 'reintroduce', 'safecall',
    'static', 'stdcall', 'sysv_abi_cdecl', 'sysv_abi_default',
    'unimplemented', 'varargs', 'vectorcall', 'virtual'
  );

  cPascalDeclarationTailKeywords: array[0..7] of string = (
    'absolute', 'cvar', 'deprecated', 'experimental', 'external', 'name',
    'platform', 'public'
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

class constructor TNXPascalRoutineDirectiveSet.Create;
begin
  FDirectiveSet := TNXFastStringSet.Create(cPascalRoutineDirectives);
end;

class destructor TNXPascalRoutineDirectiveSet.Destroy;
begin
  FreeAndNil(FDirectiveSet);
end;

class function TNXPascalRoutineDirectiveSet.Contains(
  const AText: string): Boolean;
begin
  Result := FDirectiveSet.Contains(AText);
end;

class function TNXPascalRoutineDirectiveSet.GetMetrics:
  TNXFastStringSetMetrics;
begin
  Result := FDirectiveSet.Metrics;
end;

class function TNXPascalRoutineDirectiveSet.MetricsAsJSON: string;
begin
  Result := NXMetricsToJSON(FDirectiveSet.Metrics);
end;

class constructor TNXPascalDeclarationTailKeywordSet.Create;
begin
  FKeywordSet := TNXFastStringSet.Create(cPascalDeclarationTailKeywords);
end;

class destructor TNXPascalDeclarationTailKeywordSet.Destroy;
begin
  FreeAndNil(FKeywordSet);
end;

class function TNXPascalDeclarationTailKeywordSet.Contains(
  const AText: string): Boolean;
begin
  Result := FKeywordSet.Contains(AText);
end;

class function TNXPascalDeclarationTailKeywordSet.GetMetrics:
  TNXFastStringSetMetrics;
begin
  Result := FKeywordSet.Metrics;
end;

class function TNXPascalDeclarationTailKeywordSet.MetricsAsJSON: string;
begin
  Result := NXMetricsToJSON(FKeywordSet.Metrics);
end;

end.
