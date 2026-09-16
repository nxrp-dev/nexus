unit obNXForgeSources;

{$mode delphi}{$H+}

interface

uses Classes, SysUtils, fpjson;

type
  TNXForgeSources = class
  private
    FFiles, FPaths: TStringList;
    procedure AddSelection(const ABase, ASelection: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Resolve(AContext: TJSONObject; const ABase: string);
  end;

implementation

uses obNexusScriptSourceProvider;

constructor TNXForgeSources.Create;
begin
  inherited Create;
  FFiles := TStringList.Create;
  FPaths := TStringList.Create;
  {$IFNDEF WINDOWS}
  FFiles.CaseSensitive := True;
  FPaths.CaseSensitive := True;
  {$ENDIF}
end;

destructor TNXForgeSources.Destroy;
begin
  FPaths.Free;
  FFiles.Free;
  inherited Destroy;
end;

procedure TNXForgeSources.AddSelection(const ABase, ASelection: string);
var
  lProvider: TNexusScriptFileSourceProvider;
  lMatches: TStringList;
  lSelection, lFolder, lMask, lFile, lPath: string;
  lRecursive: Boolean;
begin
  lSelection := StringReplace(ASelection, '/', DirectorySeparator, [rfReplaceAll]);
  if (ExtractFileDrive(lSelection) = '') and
    ((lSelection = '') or not IsPathDelimiter(lSelection, 1)) then
    lSelection := IncludeTrailingPathDelimiter(ABase) + lSelection;
  lFolder := ExtractFileDir(lSelection);
  lMask := ExtractFileName(lSelection);
  lRecursive := ExtractFileName(lFolder) = '**';
  if lRecursive then lFolder := ExtractFileDir(lFolder);
  if (lMask = '') or (Pos('*', lFolder) > 0) or (Pos('?', lFolder) > 0) then
    raise Exception.Create('Expected a source file or filename mask: ' + ASelection);
  if not DirectoryExists(lFolder) then
    raise Exception.Create('Source directory not found: ' + lFolder);
  lProvider := TNexusScriptFileSourceProvider.Create;
  try
    lMatches := lProvider.SelectFiles(lFolder, lMask, lRecursive);
    try
      if lMatches.Count = 0 then
        raise Exception.Create('Source selection matched no files: ' + ASelection);
      lMatches.CaseSensitive := True;
      lMatches.Sort;
      for lFile in lMatches do
      begin
        if FFiles.IndexOf(lFile) < 0 then FFiles.Add(lFile);
        lPath := ExtractFileDir(lFile);
        if FPaths.IndexOf(lPath) < 0 then FPaths.Add(lPath);
      end;
    finally
      lMatches.Free;
    end;
  finally
    lProvider.Free;
  end;
end;

procedure TNXForgeSources.Resolve(AContext: TJSONObject; const ABase: string);
var
  lSource, lItem: TJSONData;
  lFiles, lPaths: TJSONArray;
  lIndex: Integer;
  lValue: string;
begin
  FFiles.Clear;
  FPaths.Clear;
  lSource := AContext.Find('Source');
  // Scalar sources belong to operations such as Render and CSV.
  if (lSource = nil) or (lSource.JSONType <> jtArray) then Exit;
  for lIndex := 0 to lSource.Count - 1 do
  begin
    lItem := lSource.Items[lIndex];
    if lItem.JSONType = jtObject then lItem := lItem.FindPath('Value');
    if (lItem = nil) or (lItem.JSONType <> jtString) then
      raise Exception.Create('Source entries must be file or pattern strings');
    AddSelection(ABase, lItem.AsString);
  end;
  lFiles := TJSONArray.Create;
  AContext.Delete('Source');
  AContext.Add('Source', lFiles);
  for lValue in FFiles do lFiles.Add(lValue);
  lPaths := TJSONArray.Create;
  AContext.Objects['_nx'].Add('SourcePaths', lPaths);
  for lValue in FPaths do lPaths.Add(lValue);
end;

end.
