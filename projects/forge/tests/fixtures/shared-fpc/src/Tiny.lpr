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
