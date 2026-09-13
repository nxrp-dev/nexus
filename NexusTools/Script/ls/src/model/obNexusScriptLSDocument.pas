unit obNexusScriptLSDocument;

{$mode delphi}{$H+}

interface

type
  TNexusScriptLSDocument = class
  private
    FURI: string;
    FSourceName: string;
    FLanguageID: string;
    FVersion: Integer;
    FText: string;
  public
    constructor Create(const AURI, ASourceName, ALanguageID: string;
      AVersion: Integer; const AText: string);
    property URI: string read FURI;
    property SourceName: string read FSourceName;
    property LanguageID: string read FLanguageID;
    property Version: Integer read FVersion write FVersion;
    property Text: string read FText write FText;
  end;

implementation

constructor TNexusScriptLSDocument.Create(const AURI, ASourceName,
  ALanguageID: string; AVersion: Integer; const AText: string);
begin
  inherited Create;
  FURI := AURI;
  FSourceName := ASourceName;
  FLanguageID := ALanguageID;
  FVersion := AVersion;
  FText := AText;
end;

end.
