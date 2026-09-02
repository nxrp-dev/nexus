unit obNexusScriptLSDocument;

{$mode delphi}{$H+}

interface

type
  TNexusScriptLSDocument = class
  private
    FURI: string;
    FLanguageID: string;
    FVersion: Integer;
    FText: string;
  public
    constructor Create(const AURI, ALanguageID: string; AVersion: Integer;
      const AText: string);
    property URI: string read FURI;
    property LanguageID: string read FLanguageID;
    property Version: Integer read FVersion write FVersion;
    property Text: string read FText write FText;
  end;

implementation

constructor TNexusScriptLSDocument.Create(const AURI, ALanguageID: string;
  AVersion: Integer; const AText: string);
begin
  inherited Create;
  FURI := AURI;
  FLanguageID := ALanguageID;
  FVersion := AVersion;
  FText := AText;
end;

end.
