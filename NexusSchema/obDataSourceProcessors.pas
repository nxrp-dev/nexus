unit obDataSourceProcessors;

{$mode delphi}{$H+}

interface

type
  TDataSourceProcessor = class(TObject)
  public
    function SupportsFile(const AFilename: string): boolean; virtual; abstract;
    function BuildMustacheJSON(const AFilename, ATableName: string): string; virtual; abstract;
  end;

function TryBuildMustacheDataSource(const ADataFile, ATableName, AJSONFile: string): boolean;

implementation

uses
  Classes,
  fpjson,
  SysUtils;

type
  TDelimitedTextDataSourceProcessor = class(TDataSourceProcessor)
  private
    FDelimiter: char;
    FExtensions: TStringList;

    function Comma(AIndex, ACount: integer): string;
    function SQLStringValue(const AValue: string): string;
    procedure ParseLine(const ALine: string; AValues: TStrings);
  public
    constructor Create(ADelimiter: char; const AExtensions: array of string);
    destructor Destroy; override;

    function SupportsFile(const AFilename: string): boolean; override;
    function BuildMustacheJSON(const AFilename, ATableName: string): string; override;
  end;

procedure SaveTextFile(const AFilename, AText: string);
var
  lFile: TStringList;
  lPath: string;
begin
  lPath := ExtractFilePath(AFilename);
  if (lPath <> '') and not DirectoryExists(lPath) then
    ForceDirectories(lPath);

  lFile := TStringList.Create;
  try
    lFile.Text := AText;
    lFile.SaveToFile(AFilename);
  finally
    lFile.Free;
  end;
end;

function TryBuildMustacheDataSource(const ADataFile, ATableName, AJSONFile: string): boolean;
var
  lCSVProcessor: TDelimitedTextDataSourceProcessor;
  lTabProcessor: TDelimitedTextDataSourceProcessor;
  lJSON: string;
begin
  Result := False;

  lCSVProcessor := TDelimitedTextDataSourceProcessor.Create(',', ['csv', 'jcsv']);
  lTabProcessor := TDelimitedTextDataSourceProcessor.Create(#9, ['tsv', 'tab']);
  try
    if lCSVProcessor.SupportsFile(ADataFile) then
      lJSON := lCSVProcessor.BuildMustacheJSON(ADataFile, ATableName)
    else if lTabProcessor.SupportsFile(ADataFile) then
      lJSON := lTabProcessor.BuildMustacheJSON(ADataFile, ATableName)
    else
      Exit;

    SaveTextFile(AJSONFile, lJSON);
    Result := True;
  finally
    lTabProcessor.Free;
    lCSVProcessor.Free;
  end;
end;

{ TDelimitedTextDataSourceProcessor }

constructor TDelimitedTextDataSourceProcessor.Create(ADelimiter: char; const AExtensions: array of string);
var
  lIdx: integer;
begin
  inherited Create;

  FDelimiter := ADelimiter;
  FExtensions := TStringList.Create;
  FExtensions.CaseSensitive := False;
  for lIdx := Low(AExtensions) to High(AExtensions) do
    FExtensions.Add(AExtensions[lIdx]);
end;

destructor TDelimitedTextDataSourceProcessor.Destroy;
begin
  FExtensions.Free;

  inherited;
end;

function TDelimitedTextDataSourceProcessor.SupportsFile(const AFilename: string): boolean;
var
  lFileExtension: string;
begin
  lFileExtension := ExtractFileExt(AFilename);
  if Length(lFileExtension) > 0 then
    Delete(lFileExtension, 1, 1);

  Result := FExtensions.IndexOf(lFileExtension) > -1;
end;

function TDelimitedTextDataSourceProcessor.Comma(AIndex, ACount: integer): string;
begin
  if AIndex < ACount - 1 then
    Result := ','
  else
    Result := '';
end;

function TDelimitedTextDataSourceProcessor.SQLStringValue(const AValue: string): string;
begin
  Result := StringReplace(AValue, '''', '''''', [rfReplaceAll]);
end;

procedure TDelimitedTextDataSourceProcessor.ParseLine(const ALine: string; AValues: TStrings);
var
  lIdx: integer;
  lInQuote: boolean;
  lValue: string;
begin
  AValues.Clear;
  lInQuote := False;
  lValue := '';
  lIdx := 1;
  while lIdx <= Length(ALine) do
  begin
    if ALine[lIdx] = '"' then
    begin
      if lInQuote and (lIdx < Length(ALine)) and (ALine[lIdx + 1] = '"') then
      begin
        lValue := lValue + '"';
        Inc(lIdx);
      end
      else
        lInQuote := not lInQuote;
    end
    else if (ALine[lIdx] = FDelimiter) and not lInQuote then
    begin
      AValues.Add(lValue);
      lValue := '';
    end
    else
      lValue := lValue + ALine[lIdx];

    Inc(lIdx);
  end;

  AValues.Add(lValue);
end;

function TDelimitedTextDataSourceProcessor.BuildMustacheJSON(const AFilename, ATableName: string): string;
var
  lDataFile: TStringList;
  lHeaders: TStringList;
  lValues: TStringList;
  lRoot: TJSONObject;
  lHeaderArray: TJSONArray;
  lRowArray: TJSONArray;
  lValueArray: TJSONArray;
  lItem: TJSONObject;
  lRow: TJSONObject;
  lIdx: integer;
  lRowIdx: integer;
begin
  lDataFile := TStringList.Create;
  lHeaders := TStringList.Create;
  lValues := TStringList.Create;
  lRoot := TJSONObject.Create;
  try
    lDataFile.LoadFromFile(AFilename);
    if lDataFile.Count = 0 then
      raise Exception.CreateFmt('Data source file [%s] is empty.', [AFilename]);

    ParseLine(lDataFile[0], lHeaders);

    lRoot.Add('TABLE_NAME', ATableName);

    lHeaderArray := TJSONArray.Create;
    lRoot.Add('Headers', lHeaderArray);
    for lIdx := 0 to lHeaders.Count - 1 do
    begin
      lItem := TJSONObject.Create;
      lItem.Add('Name', lHeaders[lIdx]);
      lItem.Add('Comma', Comma(lIdx, lHeaders.Count));
      lHeaderArray.Add(lItem);
    end;

    lRowArray := TJSONArray.Create;
    lRoot.Add('Rows', lRowArray);
    for lRowIdx := 1 to lDataFile.Count - 1 do
    begin
      if Trim(lDataFile[lRowIdx]) = '' then
        Continue;

      ParseLine(lDataFile[lRowIdx], lValues);
      lRow := TJSONObject.Create;
      lValueArray := TJSONArray.Create;
      lRow.Add('Values', lValueArray);

      for lIdx := 0 to lHeaders.Count - 1 do
      begin
        lItem := TJSONObject.Create;
        lItem.Add('Name', lHeaders[lIdx]);
        if lIdx < lValues.Count then
          lItem.Add('Value', SQLStringValue(lValues[lIdx]))
        else
          lItem.Add('Value', '');
        lItem.Add('Comma', Comma(lIdx, lHeaders.Count));
        lValueArray.Add(lItem);
      end;

      lRowArray.Add(lRow);
    end;

    Result := lRoot.FormatJSON;
  finally
    lRoot.Free;
    lValues.Free;
    lHeaders.Free;
    lDataFile.Free;
  end;
end;

end.
