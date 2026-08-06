unit obNXFastPascal;
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, obNXFastParse, obNXMeasuredStructure, tpNXPasTokens;

type
  TNXPasRoutineDirectiveKind = (
    prdAbstract,
    prdAlias,
    prdAssembler,
    prdCdecl,
    prdCompilerproc,
    prdDeprecated,
    prdDynamic,
    prdExperimental,
    prdExport,
    prdExternal,
    prdFar,
    prdFinal,
    prdForward,
    prdHardfloat,
    prdInline,
    prdMessage,
    prdMsAbiCdecl,
    prdMsAbiDefault,
    prdMwpascal,
    prdNoreturn,
    prdOldfpccall,
    prdOverload,
    prdOverride,
    prdPascal,
    prdPlatform,
    prdPublic,
    prdReintroduce,
    prdSafecall,
    prdStatic,
    prdStdcall,
    prdSysvAbiCdecl,
    prdSysvAbiDefault,
    prdUnimplemented,
    prdVarargs,
    prdVectorcall,
    prdVirtual
  );

  TNXPasDeclarationTailKind = (
    pdtAbsolute,
    pdtCvar,
    pdtDeprecated,
    pdtExperimental,
    pdtExternal,
    pdtName,
    pdtPlatform,
    pdtPublic
  );

  TNXPasPropertySpecifierKind = (
    ppsRead,
    ppsWrite,
    ppsIndex,
    ppsStored,
    ppsDefault,
    ppsNodefault,
    ppsImplements
  );

  TNXPasParameterModifierKind = (
    ppmConstref
  );

  TNXPascalKeywordSet = class sealed
  private
    class var FKeywordSet: TNXFastStringSet;

  public
    class constructor Create;
    class destructor Destroy;

    class function Contains(const AText: string): Boolean; static; inline;
    class function TryIndexOf(const AText: string;
      out AIndex: Integer): Boolean; static; inline;
    class function TryKindOf(const AText: string;
      out AKind: TNXPasKeywordKind): Boolean; static; inline;
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
    class function TryKindOf(const AText: string;
      out AKind: TNXPasRoutineDirectiveKind): Boolean; static; inline;
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
    class function TryKindOf(const AText: string;
      out AKind: TNXPasDeclarationTailKind): Boolean; static; inline;
    class function GetMetrics: TNXFastStringSetMetrics; static;
    class function MetricsAsJSON: string; static;
  end;

  TNXPascalPropertySpecifierSet = class sealed
  private
    class var FSpecifierSet: TNXFastStringSet;

  public
    class constructor Create;
    class destructor Destroy;

    class function Contains(const AText: string): Boolean; static; inline;
    class function TryKindOf(const AText: string;
      out AKind: TNXPasPropertySpecifierKind): Boolean; static; inline;
    class function GetMetrics: TNXFastStringSetMetrics; static;
    class function MetricsAsJSON: string; static;
  end;

  TNXPascalParameterModifierSet = class sealed
  private
    class var FModifierSet: TNXFastStringSet;

  public
    class constructor Create;
    class destructor Destroy;

    class function Contains(const AText: string): Boolean; static; inline;
    class function TryKindOf(const AText: string;
      out AKind: TNXPasParameterModifierKind): Boolean; static; inline;
    class function GetMetrics: TNXFastStringSetMetrics; static;
    class function MetricsAsJSON: string; static;
  end;

const
  cPascalKeywords: array[pkwAbsolute..pkwXor] of string = (
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

  cPascalPropertySpecifiers: array[0..6] of string = (
    'read', 'write', 'index', 'stored', 'default', 'nodefault', 'implements'
  );

  cPascalParameterModifiers: array[0..0] of string = (
    'constref'
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
  Result := FKeywordSet.Contains(LowerCase(AText));
end;

class function TNXPascalKeywordSet.TryIndexOf(const AText: string;
  out AIndex: Integer): Boolean;
begin
  Result := FKeywordSet.TryIndexOf(LowerCase(AText), AIndex);
end;

class function TNXPascalKeywordSet.TryKindOf(const AText: string;
  out AKind: TNXPasKeywordKind): Boolean;
var
  lIndex: Integer;
begin
  Result := FKeywordSet.TryIndexOf(LowerCase(AText), lIndex);
  if Result then
    AKind := TNXPasKeywordKind(lIndex)
  else
    AKind := pkwNone;
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
  Result := FDirectiveSet.Contains(LowerCase(AText));
end;

class function TNXPascalRoutineDirectiveSet.TryKindOf(const AText: string;
  out AKind: TNXPasRoutineDirectiveKind): Boolean;
var
  lIndex: Integer;
begin
  Result := FDirectiveSet.TryIndexOf(LowerCase(AText), lIndex);
  if Result then
    AKind := TNXPasRoutineDirectiveKind(lIndex);
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
  Result := FKeywordSet.Contains(LowerCase(AText));
end;

class function TNXPascalDeclarationTailKeywordSet.TryKindOf(
  const AText: string; out AKind: TNXPasDeclarationTailKind): Boolean;
var
  lIndex: Integer;
begin
  Result := FKeywordSet.TryIndexOf(LowerCase(AText), lIndex);
  if Result then
    AKind := TNXPasDeclarationTailKind(lIndex);
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

class constructor TNXPascalPropertySpecifierSet.Create;
begin
  FSpecifierSet := TNXFastStringSet.Create(cPascalPropertySpecifiers);
end;

class destructor TNXPascalPropertySpecifierSet.Destroy;
begin
  FreeAndNil(FSpecifierSet);
end;

class function TNXPascalPropertySpecifierSet.Contains(
  const AText: string): Boolean;
begin
  Result := FSpecifierSet.Contains(LowerCase(AText));
end;

class function TNXPascalPropertySpecifierSet.TryKindOf(const AText: string;
  out AKind: TNXPasPropertySpecifierKind): Boolean;
var
  lIndex: Integer;
begin
  Result := FSpecifierSet.TryIndexOf(LowerCase(AText), lIndex);
  if Result then
    AKind := TNXPasPropertySpecifierKind(lIndex);
end;

class function TNXPascalPropertySpecifierSet.GetMetrics:
  TNXFastStringSetMetrics;
begin
  Result := FSpecifierSet.Metrics;
end;

class function TNXPascalPropertySpecifierSet.MetricsAsJSON: string;
begin
  Result := NXMetricsToJSON(FSpecifierSet.Metrics);
end;

class constructor TNXPascalParameterModifierSet.Create;
begin
  FModifierSet := TNXFastStringSet.Create(cPascalParameterModifiers);
end;

class destructor TNXPascalParameterModifierSet.Destroy;
begin
  FreeAndNil(FModifierSet);
end;

class function TNXPascalParameterModifierSet.Contains(
  const AText: string): Boolean;
begin
  Result := FModifierSet.Contains(LowerCase(AText));
end;

class function TNXPascalParameterModifierSet.TryKindOf(const AText: string;
  out AKind: TNXPasParameterModifierKind): Boolean;
var
  lIndex: Integer;
begin
  Result := FModifierSet.TryIndexOf(LowerCase(AText), lIndex);
  if Result then
    AKind := TNXPasParameterModifierKind(lIndex);
end;

class function TNXPascalParameterModifierSet.GetMetrics:
  TNXFastStringSetMetrics;
begin
  Result := FModifierSet.Metrics;
end;

class function TNXPascalParameterModifierSet.MetricsAsJSON: string;
begin
  Result := NXMetricsToJSON(FModifierSet.Metrics);
end;

end.
