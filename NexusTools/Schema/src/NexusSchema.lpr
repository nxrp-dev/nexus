program NexusSchema;

{$mode delphi}{$H+}
{$apptype console}

uses
  SysUtils,
  obNexusSchemaParser,
  obDataSourceProcessors,
  obMetaDataModuleList,
  obMetaDataTransformations,  
  obCommandLine,  
  obMetaDataJSON,
  obMustacheRenderer;

procedure ProcessFile(const AFilename, ATemplate, AOutput, ATableName : string);
var
  lJSONFile : string;
begin
  if SameText(ExtractFileExt(ATemplate), '.mustache') then
  begin
    lJSONFile := ChangeFileExt(AOutput, '.data.json');
    if TryBuildMustacheDataSource(AFilename, ATableName, lJSONFile) then
    begin
      RenderMustacheFile(lJSONFile, ATemplate, AOutput);
    end
    else
      RenderMustacheFile(AFilename, ATemplate, AOutput);
  end;
end;

function GetCleanFileExt(const AFilename : string) : string;
begin
  Result := ExtractFileExt(AFilename);

  if Length(Result) = 0 then
    raise Exception.CreateFmt('Unable to determine file type [%s]', [AFilename]);

  if Result[1] = '.' then
    Delete(Result, 1, 1);
end;

function GetTargetFile(const ADataFile, ATemplateFile, AOutputPath : string) : string;
begin
  Result := IncludeTrailingPathDelimiter(AOutputPath)+ChangeFileExt(ExtractFileName(ADataFile), ExtractFileExt(ChangeFileExt(ATemplateFile, '')));
end;

procedure CompileScripts;
var
  lIdx : integer;
  lDataFile : string;
  lJSONFile : string;

  lOutputFolder : string;
  lCommandLine : TCommandLine;
  lFileExtension : string;
  lParser : TNexusSchemaParser;
  lMetaData : TMetaDataModuleList;
  lTargetFile : string;
  lTemplateFile : string;
  lTransform : TMetaDataTransform;
begin
  lCommandLine := TCommandLine.Create;
  lMetaData := TMetaDataModuleList.Create;
  lParser := TNexusSchemaParser.Create(lMetaData);
  try
    lOutputFolder := IncludeTrailingPathDelimiter(lCommandLine.Value['Output']);
    lDataFile := lCommandLine.Value['metadata'];
    lFileExtension := GetCleanFileExt(lDataFile);
    lTemplateFile := lCommandLine.Value[lFileExtension];
    lTargetFile := GetTargetFile(lDataFile, lTemplateFile, lOutputFolder);
    lJSONFile := ChangeFileExt(lTargetFile, '.schema.json');
    lParser.ExecuteFile(lDataFile);

    lTransform := TMetaDataTransform.Create;
    try
      lTransform.Transform(lMetaData);
    finally
      lTransform.Free;
    end;

    SaveMetaDataMustacheJSON(lMetaData, lJSONFile);
    ProcessFile(lJSONFile, lTemplateFile, lTargetFile, '');

    for lIdx := 0 to lMetaData.Data.Count - 1 do
    begin
      lDataFile := lMetaData.Data.Items[lIdx].Value;
      lFileExtension := GetCleanFileExt(lDataFile);
      lTemplateFile := lCommandLine.Value[lFileExtension];
      lTargetFile := GetTargetFile(lDataFile, lTemplateFile, lOutputFolder);

      ProcessFile(lDataFile, lTemplateFile, lTargetFile, lMetaData.Data.Items[lIdx].Name);
    end;
  finally
    lCommandLine.Free;
    lParser.Free;
    lMetaData.Free;
  end;
end;

var
  lCommandLine : TCommandLine;
begin
  try
    lCommandLine := TCommandLine.Create;
    try
      WriteLn('- NexusSchema using the following options:');
      WriteLn(lCommandLine.Text);
      CompileScripts;
    finally
      lCommandLine.Free;
    end;
    WriteLn('- NexusSchema process completed successfully.');
  except
    on E:Exception do
    begin
      WriteLn(E.Message);
    end;
  end;
end.
