unit obNexusSchemaTypes;

{$mode delphi}{$H+}

interface

type
  TNexusSchemaCharSet = set of Char;

  TTokenType = (ttNone, ttIdentifier, ttKeyword, ttOperator, ttString, ttComment);
  TTokenSet = set of TTokenType;

const
  nxOpAssign: string = '=';
  nxOpBlockOpen: string = '{';
  nxOpBlockClose: string = '}';
  nxOpParamOpen: string = '(';
  nxOpParamClose: string = ')';
  nxOpParamNext: string = ',';
  nxOpLineTerm: string = ';';
  nxOpReference: string = '@';
  nxOpQualifier: string = '.';
  nxOpDefine: string = ':';

  cOperators: TNexusSchemaCharSet = [
    '=',
    '{',
    '}',
    '(',
    ')',
    ',',
    ';',
    '@',
    '.',
    ':'
  ];

  cLineTerminators = [#10, #13];
  cTerminators = [#0];
  cWhiteSpace = [' ', #13, #10, #09];

type
  TNexusSchemaKeywords = array[0..8] of string;

const
  kwModule = 'module';
  kwUses = 'uses';
  kwData = 'data';
  kwVar = 'var';
  kwTable = 'table';
  kwTemplate = 'template';
  kwType = 'type';
  kwAttributes = 'attributes';
  kwChildren = 'children';

  cKeywords: TNexusSchemaKeywords = (
    kwModule,
    kwUses,
    kwData,
    kwVar,
    kwTable,
    kwTemplate,
    kwType,
    kwAttributes,
    kwChildren
  );

implementation

end.
