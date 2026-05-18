unit obMustacheRenderer;

{$mode delphi}{$H+}

interface

procedure RenderMustacheFile(const AJSONFile, ATemplateFile, AOutputFile: string);

implementation

uses
  Classes,
  SysUtils,
  SynCommons,
  SynMustache;

function LoadRawUTF8File(const AFilename: string): RawUTF8;
var
  lFile: TStringList;
begin
  lFile := TStringList.Create;
  try
    lFile.LoadFromFile(AFilename);
    Result := RawUTF8(lFile.Text);
  finally
    lFile.Free;
  end;
end;

procedure SaveRawUTF8File(const AFilename: string; const AContent: RawUTF8);
var
  lFile: TStringList;
  lPath: string;
begin
  lPath := ExtractFilePath(AFilename);
  if (lPath <> '') and not DirectoryExists(lPath) then
    ForceDirectories(lPath);

  lFile := TStringList.Create;
  try
    lFile.Text := string(AContent);
    lFile.SaveToFile(AFilename);
  finally
    lFile.Free;
  end;
end;

procedure RenderMustacheFile(const AJSONFile, ATemplateFile, AOutputFile: string);
var
  lJSON: RawUTF8;
  lTemplate: RawUTF8;
  lOutput: RawUTF8;
begin
  lJSON := LoadRawUTF8File(AJSONFile);
  lTemplate := LoadRawUTF8File(ATemplateFile);
  if not TSynMustache.TryRenderJson(lTemplate, lJSON, lOutput) then
    raise Exception.CreateFmt('Unable to render Mustache template [%s]', [ATemplateFile]);
  SaveRawUTF8File(AOutputFile, lOutput);
end;

end.
