unit obNXLSProtocolBase;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues;

type
  TNXLSPosition = class(TNXJSONObject)
  private
    Fline: TNXJSONInteger;
    Fcharacter: TNXJSONInteger;
  published
    property line: TNXJSONInteger read Fline write Fline;
    property character: TNXJSONInteger read Fcharacter write Fcharacter;
  end;

  TNXLSRange = class(TNXJSONObject)
  private
    Fstart: TNXLSPosition;
    Fend: TNXLSPosition;
  published
    property start: TNXLSPosition read Fstart write Fstart;
    property &end: TNXLSPosition read Fend write Fend;
  end;

  TNXLSTextDocumentIdentifier = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
  end;

  TNXLSVersionedTextDocumentIdentifier = class(TNXLSTextDocumentIdentifier)
  private
    Fversion: TNXJSONInteger;
  published
    property version: TNXJSONInteger read Fversion write Fversion;
  end;

  TNXLSOptionalVersionedTextDocumentIdentifier = class(TNXLSTextDocumentIdentifier)
  private
    Fversion: TNXJSONValue;
  published
    property version: TNXJSONValue read Fversion write Fversion;
  end;

  TNXLSTextDocumentItem = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    FlanguageId: TNXJSONString;
    Fversion: TNXJSONInteger;
    Ftext: TNXJSONString;
  published
    property uri: TNXJSONString read Furi write Furi;
    property languageId: TNXJSONString read FlanguageId write FlanguageId;
    property version: TNXJSONInteger read Fversion write Fversion;
    property text: TNXJSONString read Ftext write Ftext;
  end;

  TNXLSLocation = class(TNXJSONObject)
  private
    Furi: TNXJSONString;
    Frange: TNXLSRange;
  published
    property uri: TNXJSONString read Furi write Furi;
    property range: TNXLSRange read Frange write Frange;
  end;

  TNXLSTextDocumentPositionParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
    Fposition: TNXLSPosition;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
    property position: TNXLSPosition read Fposition write Fposition;
  end;

implementation

end.
