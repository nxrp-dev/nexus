(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program Tiny;

{$mode delphi}{$H+}

uses Classes, SysUtils, fpjson, jsonparser, DOM, XMLRead, utTinyMessage;

procedure Run;
var
  lJSON: TJSONData;
  lXML: TXMLDocument;
  lInput: TStringStream;
begin
  lJSON := GetJSON('{"message":"hello"}');
  try
    lInput := TStringStream.Create('<message>world</message>');
    try
      ReadXMLFile(lXML, lInput);
      try
        WriteLn(TinyMessage(lJSON.FindPath('message').AsString,
          string(lXML.DocumentElement.TextContent)));
      finally
        lXML.Free;
      end;
    finally
      lInput.Free;
    end;
  finally
    lJSON.Free;
  end;
end;

begin
  Run;
end.
