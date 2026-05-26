unit obNXLSDocumentSyncParams;

{$mode objfpc}{$H+}

interface

uses
  obNXJSONValues,
  obNXLSProtocolBase;

type
  TNXLSContentChange = class(TNXJSONObject)
  private
    Frange: TNXLSRange;
    FrangeLength: TNXJSONInteger;
    Ftext: TNXJSONString;
  published
    property range: TNXLSRange read Frange write Frange;
    property rangeLength: TNXJSONInteger read FrangeLength write FrangeLength;
    property text: TNXJSONString read Ftext write Ftext;
  end;

  TNXLSContentChangeArray = class(TNXJSONArray)
  public
    class function ItemClass: TNXJSONValueClass; override;
  end;

  TNXLSDidOpenTextDocumentParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentItem;
  published
    property textDocument: TNXLSTextDocumentItem read FtextDocument write FtextDocument;
  end;

  TNXLSDidChangeTextDocumentParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSVersionedTextDocumentIdentifier;
    FcontentChanges: TNXLSContentChangeArray;
  published
    property textDocument: TNXLSVersionedTextDocumentIdentifier read FtextDocument write FtextDocument;
    property contentChanges: TNXLSContentChangeArray read FcontentChanges write FcontentChanges;
  end;

  TNXLSWillSaveTextDocumentParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
    Freason: TNXJSONInteger;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
    property reason: TNXJSONInteger read Freason write Freason;
  end;

  TNXLSDidSaveTextDocumentParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
    Ftext: TNXJSONString;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
    property text: TNXJSONString read Ftext write Ftext;
  end;

  TNXLSDidCloseTextDocumentParams = class(TNXJSONObject)
  private
    FtextDocument: TNXLSTextDocumentIdentifier;
  published
    property textDocument: TNXLSTextDocumentIdentifier read FtextDocument write FtextDocument;
  end;

implementation

class function TNXLSContentChangeArray.ItemClass: TNXJSONValueClass;
begin
  Result := TNXLSContentChange;
end;

end.
