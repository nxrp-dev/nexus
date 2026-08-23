unit obNexusScriptExternalSource;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  obNexusScriptModel;

type
  ENexusScriptExternalSource = class(Exception);

  TNexusScriptExternalSourceCompilerRegistry = class
  private
    class function CompileDelimited(const ACompilerName: string;
      ASource: TNexusScriptExternalSource; ADelimiter: Char): string; static;
  public
    class function SupportsCompiler(const ACompilerName: string): Boolean;
      static;
    class function CompilerSupportsType(const ACompilerName,
      ASourceType: string): Boolean; static;
    class function Compile(const ACompilerName: string;
      ASource: TNexusScriptExternalSource): string; static;
  end;

implementation

uses
  fpjson;

procedure ParseDelimitedLine(const AFileName, ALine: string;
  ALineNumber: Integer; ADelimiter: Char; AValues: TStrings);
var
  lIndex: Integer;
  lInQuote: Boolean;
  lValue: string;
begin
  AValues.Clear;
  lIndex := 1;
  lInQuote := False;
  lValue := '';
  while lIndex <= Length(ALine) do
  begin
    if ALine[lIndex] = '"' then
    begin
      if lInQuote and (lIndex < Length(ALine)) and
        (ALine[lIndex + 1] = '"') then
      begin
        lValue := lValue + '"';
        Inc(lIndex);
      end
      else
        lInQuote := not lInQuote;
    end
    else if (ALine[lIndex] = ADelimiter) and not lInQuote then
    begin
      AValues.Add(lValue);
      lValue := '';
    end
    else
      lValue := lValue + ALine[lIndex];
    Inc(lIndex);
  end;
  if lInQuote then
    raise ENexusScriptExternalSource.CreateFmt(
      'Malformed quoted field in %s at line %d.',
      [AFileName, ALineNumber]);
  AValues.Add(lValue);
end;

class function TNexusScriptExternalSourceCompilerRegistry.SupportsCompiler(
  const ACompilerName: string): Boolean;
begin
  Result := SameText(ACompilerName, 'CommaDelimited') or
    SameText(ACompilerName, 'TabDelimited');
end;

class function TNexusScriptExternalSourceCompilerRegistry.CompilerSupportsType(
  const ACompilerName, ASourceType: string): Boolean;
begin
  if SameText(ACompilerName, 'CommaDelimited') then
    Result := SameText(ASourceType, 'csv') or SameText(ASourceType, 'jcsv')
  else if SameText(ACompilerName, 'TabDelimited') then
    Result := SameText(ASourceType, 'tsv') or SameText(ASourceType, 'tab')
  else
    Result := False;
end;

class function TNexusScriptExternalSourceCompilerRegistry.CompileDelimited(
  const ACompilerName: string; ASource: TNexusScriptExternalSource;
  ADelimiter: Char): string;
var
  lLines: TStringList;
  lFields: TStringList;
  lValues: TStringList;
  lFieldNames: TStringList;
  lRoot: TJSONObject;
  lDataSource: TJSONObject;
  lMetaData: TJSONObject;
  lFieldArray: TJSONArray;
  lRecordArray: TJSONArray;
  lRecord: TJSONArray;
  lIndex: Integer;
  lLineIndex: Integer;
begin
  if not FileExists(ASource.FileName) then
    raise ENexusScriptExternalSource.CreateFmt(
      'External data source file not found: %s', [ASource.FileName]);
  if not CompilerSupportsType(ACompilerName, ASource.SourceType) then
    raise ENexusScriptExternalSource.CreateFmt(
      'Compiler %s does not support source type %s.',
      [ACompilerName, ASource.SourceType]);

  lLines := TStringList.Create;
  lFields := TStringList.Create;
  lValues := TStringList.Create;
  lFieldNames := TStringList.Create;
  lRoot := TJSONObject.Create;
  try
    lFieldNames.CaseSensitive := False;
    lFieldNames.Sorted := True;
    lFieldNames.Duplicates := dupError;
    lLines.LoadFromFile(ASource.FileName);
    if lLines.Count = 0 then
      raise ENexusScriptExternalSource.CreateFmt(
        'External data source file is empty: %s', [ASource.FileName]);

    ParseDelimitedLine(ASource.FileName, lLines[0], 1, ADelimiter, lFields);
    for lIndex := 0 to lFields.Count - 1 do
    begin
      if Trim(lFields[lIndex]) = '' then
        raise ENexusScriptExternalSource.CreateFmt(
          'Blank field name in %s at column %d.',
          [ASource.FileName, lIndex + 1]);
      if lFieldNames.IndexOf(lFields[lIndex]) >= 0 then
        raise ENexusScriptExternalSource.CreateFmt(
          'Duplicate field name %s in %s.',
          [lFields[lIndex], ASource.FileName]);
      lFieldNames.Add(lFields[lIndex]);
    end;

    lDataSource := TJSONObject.Create;
    lRoot.Add('DataSource', lDataSource);
    lMetaData := TJSONObject.Create;
    lMetaData.Add('Kind', 'DataSource');
    lMetaData.Add('Name', ASource.Name);
    lMetaData.Add('Type', ASource.SourceType);
    lMetaData.Add('Source', ASource.DeclaredPath);
    lDataSource.Add('_nx', lMetaData);

    lFieldArray := TJSONArray.Create;
    lDataSource.Add('Fields', lFieldArray);
    for lIndex := 0 to lFields.Count - 1 do
      lFieldArray.Add(lFields[lIndex]);

    lRecordArray := TJSONArray.Create;
    lDataSource.Add('Records', lRecordArray);
    for lLineIndex := 1 to lLines.Count - 1 do
    begin
      if Trim(lLines[lLineIndex]) = '' then
        Continue;
      ParseDelimitedLine(ASource.FileName, lLines[lLineIndex],
        lLineIndex + 1, ADelimiter, lValues);
      if lValues.Count <> lFields.Count then
        raise ENexusScriptExternalSource.CreateFmt(
          'Field count mismatch in %s at line %d: expected %d, found %d.',
          [ASource.FileName, lLineIndex + 1, lFields.Count, lValues.Count]);
      lRecord := TJSONArray.Create;
      lRecordArray.Add(lRecord);
      for lIndex := 0 to lValues.Count - 1 do
        lRecord.Add(lValues[lIndex]);
    end;
    Result := lRoot.FormatJSON;
  finally
    lRoot.Free;
    lFieldNames.Free;
    lValues.Free;
    lFields.Free;
    lLines.Free;
  end;
end;

class function TNexusScriptExternalSourceCompilerRegistry.Compile(
  const ACompilerName: string; ASource: TNexusScriptExternalSource): string;
begin
  if SameText(ACompilerName, 'CommaDelimited') then
    Result := CompileDelimited(ACompilerName, ASource, ',')
  else if SameText(ACompilerName, 'TabDelimited') then
    Result := CompileDelimited(ACompilerName, ASource, #9)
  else
    raise ENexusScriptExternalSource.CreateFmt(
      'Unknown external source compiler: %s', [ACompilerName]);
end;

end.
