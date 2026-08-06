unit tpNXPasTokens;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

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

  TNXPasKeywordKind = (
    pkwNone = -1,
    pkwAbsolute = 0,
    pkwAnd,
    pkwArray,
    pkwAs,
    pkwAsm,
    pkwBegin,
    pkwBitpacked,
    pkwCase,
    pkwClass,
    pkwConst,
    pkwConstructor,
    pkwDestructor,
    pkwDispinterface,
    pkwDiv,
    pkwDo,
    pkwDownto,
    pkwElse,
    pkwEnd,
    pkwExcept,
    pkwExports,
    pkwFile,
    pkwFalse,
    pkwFinalization,
    pkwFinally,
    pkwFor,
    pkwFunction,
    pkwGeneric,
    pkwGoto,
    pkwHelper,
    pkwIf,
    pkwImplementation,
    pkwIn,
    pkwInherited,
    pkwInitialization,
    pkwInline,
    pkwInterface,
    pkwIs,
    pkwLabel,
    pkwLibrary,
    pkwMod,
    pkwNil,
    pkwNot,
    pkwObject,
    pkwOf,
    pkwOn,
    pkwOperator,
    pkwOr,
    pkwOut,
    pkwPackage,
    pkwPacked,
    pkwPrivate,
    pkwProcedure,
    pkwProgram,
    pkwProperty,
    pkwProtected,
    pkwPublic,
    pkwPublished,
    pkwRaise,
    pkwRecord,
    pkwRepeat,
    pkwResourcestring,
    pkwSet,
    pkwShl,
    pkwShr,
    pkwSpecialize,
    pkwString,
    pkwThen,
    pkwThreadvar,
    pkwTo,
    pkwTry,
    pkwTrue,
    pkwType,
    pkwUnit,
    pkwUntil,
    pkwUses,
    pkwVar,
    pkwWhile,
    pkwWith,
    pkwXor
  );

  TNXPasTokenSymbolKind = (
    psyNone,
    psyUnknown,
    psyPlus,
    psyMinus,
    psyStar,
    psySlash,
    psyEquals,
    psyColon,
    psySemicolon,
    psyComma,
    psyDot,
    psyDotDot,
    psyAssign,
    psyLess,
    psyLessEqual,
    psyGreater,
    psyGreaterEqual,
    psyNotEqual,
    psyOpenParen,
    psyCloseParen,
    psyOpenBracket,
    psyCloseBracket,
    psyOpenBrace,
    psyCloseBrace,
    psyCaret,
    psyAt
  );

  TNXPasSourcePosition = record
    Offset: Integer;
    Line: Integer;
    Column: Integer;
  end;

  TNXPasToken = record
    Kind: TNXPasTokenKind;
    Keyword: TNXPasKeywordKind;
    Symbol: TNXPasTokenSymbolKind;
    StartPos: TNXPasSourcePosition;
    EndPos: TNXPasSourcePosition;
    StartOffset: Integer;
    EndOffset: Integer;
    function Length: Integer;
    function Text(const ASource: string): string;
  end;

function NXPasTokenKindName(AKind: TNXPasTokenKind): string;
function NXPasKeywordKindName(AKind: TNXPasKeywordKind): string;
function NXPasSymbolKindName(AKind: TNXPasTokenSymbolKind): string;
procedure NXPasClearToken(out AToken: TNXPasToken);

implementation

uses
  SysUtils;

function TNXPasToken.Length: Integer;
begin
  Result := EndOffset - StartOffset;
end;

function TNXPasToken.Text(const ASource: string): string;
begin
  Result := '';
  if (StartOffset <= 0) or (EndOffset <= StartOffset) then
    Exit;
  Result := Copy(ASource, StartOffset, EndOffset - StartOffset);
end;

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

function NXPasKeywordKindName(AKind: TNXPasKeywordKind): string;
begin
  case AKind of
    pkwNone: Result := '';
    pkwAbsolute: Result := 'absolute';
    pkwAnd: Result := 'and';
    pkwArray: Result := 'array';
    pkwAs: Result := 'as';
    pkwAsm: Result := 'asm';
    pkwBegin: Result := 'begin';
    pkwBitpacked: Result := 'bitpacked';
    pkwCase: Result := 'case';
    pkwClass: Result := 'class';
    pkwConst: Result := 'const';
    pkwConstructor: Result := 'constructor';
    pkwDestructor: Result := 'destructor';
    pkwDispinterface: Result := 'dispinterface';
    pkwDiv: Result := 'div';
    pkwDo: Result := 'do';
    pkwDownto: Result := 'downto';
    pkwElse: Result := 'else';
    pkwEnd: Result := 'end';
    pkwExcept: Result := 'except';
    pkwExports: Result := 'exports';
    pkwFile: Result := 'file';
    pkwFalse: Result := 'false';
    pkwFinalization: Result := 'finalization';
    pkwFinally: Result := 'finally';
    pkwFor: Result := 'for';
    pkwFunction: Result := 'function';
    pkwGeneric: Result := 'generic';
    pkwGoto: Result := 'goto';
    pkwHelper: Result := 'helper';
    pkwIf: Result := 'if';
    pkwImplementation: Result := 'implementation';
    pkwIn: Result := 'in';
    pkwInherited: Result := 'inherited';
    pkwInitialization: Result := 'initialization';
    pkwInline: Result := 'inline';
    pkwInterface: Result := 'interface';
    pkwIs: Result := 'is';
    pkwLabel: Result := 'label';
    pkwLibrary: Result := 'library';
    pkwMod: Result := 'mod';
    pkwNil: Result := 'nil';
    pkwNot: Result := 'not';
    pkwObject: Result := 'object';
    pkwOf: Result := 'of';
    pkwOn: Result := 'on';
    pkwOperator: Result := 'operator';
    pkwOr: Result := 'or';
    pkwOut: Result := 'out';
    pkwPackage: Result := 'package';
    pkwPacked: Result := 'packed';
    pkwPrivate: Result := 'private';
    pkwProcedure: Result := 'procedure';
    pkwProgram: Result := 'program';
    pkwProperty: Result := 'property';
    pkwProtected: Result := 'protected';
    pkwPublic: Result := 'public';
    pkwPublished: Result := 'published';
    pkwRaise: Result := 'raise';
    pkwRecord: Result := 'record';
    pkwRepeat: Result := 'repeat';
    pkwResourcestring: Result := 'resourcestring';
    pkwSet: Result := 'set';
    pkwShl: Result := 'shl';
    pkwShr: Result := 'shr';
    pkwSpecialize: Result := 'specialize';
    pkwString: Result := 'string';
    pkwThen: Result := 'then';
    pkwThreadvar: Result := 'threadvar';
    pkwTo: Result := 'to';
    pkwTry: Result := 'try';
    pkwTrue: Result := 'true';
    pkwType: Result := 'type';
    pkwUnit: Result := 'unit';
    pkwUntil: Result := 'until';
    pkwUses: Result := 'uses';
    pkwVar: Result := 'var';
    pkwWhile: Result := 'while';
    pkwWith: Result := 'with';
    pkwXor: Result := 'xor';
  else
    Result := '';
  end;
end;

function NXPasSymbolKindName(AKind: TNXPasTokenSymbolKind): string;
begin
  case AKind of
    psyNone: Result := '';
    psyUnknown: Result := '?';
    psyPlus: Result := '+';
    psyMinus: Result := '-';
    psyStar: Result := '*';
    psySlash: Result := '/';
    psyEquals: Result := '=';
    psyColon: Result := ':';
    psySemicolon: Result := ';';
    psyComma: Result := ',';
    psyDot: Result := '.';
    psyDotDot: Result := '..';
    psyAssign: Result := ':=';
    psyLess: Result := '<';
    psyLessEqual: Result := '<=';
    psyGreater: Result := '>';
    psyGreaterEqual: Result := '>=';
    psyNotEqual: Result := '<>';
    psyOpenParen: Result := '(';
    psyCloseParen: Result := ')';
    psyOpenBracket: Result := '[';
    psyCloseBracket: Result := ']';
    psyOpenBrace: Result := '{';
    psyCloseBrace: Result := '}';
    psyCaret: Result := '^';
    psyAt: Result := '@';
  else
    Result := '';
  end;
end;

procedure NXPasClearToken(out AToken: TNXPasToken);
begin
  FillChar(AToken, SizeOf(AToken), 0);
  AToken.Kind := ptkUnknown;
  AToken.Keyword := pkwNone;
  AToken.Symbol := psyNone;
end;

end.

