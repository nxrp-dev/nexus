(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

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
