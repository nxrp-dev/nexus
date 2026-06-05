unit obNXLSSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  fpjson,
  obNXJSONValues,
  obNXJSONRPCObjects;

type
  TNXLSSettings = class
  private
    FCWD: string;
    FFPCDir: string;
    FProgramFile: string;
    FLazarusDir: string;
    FFPCOptions: TStringList;
    FCheckSyntax: Boolean;
    FPublishDiagnostics: Boolean;
    FShowSyntaxErrors: Boolean;
    FCheckInactiveRegions: Boolean;
    function ExpandMacrosInString(const AValue, ARootPath, ATempPath: string): string;
    procedure ExpandMacrosInStrings(AValues: TStrings; const ARootPath, ATempPath: string);
    procedure LoadStringArray(AData: TJSONData; ATarget: TStrings);
    procedure LoadStringValue(AObject: TJSONObject; const AName: string; var ATarget: string);
    procedure LoadBooleanValue(AObject: TJSONObject; const AName: string; var ATarget: Boolean);
    function JSONBoolean(AObject: TJSONObject; const AName: string; ADefault: Boolean): Boolean;
    function JSONString(AObject: TJSONObject; const AName: string): string;
    function FindFPCDirInLazarus(const ALazarusDir: string): string;
    function FPCDirFromCompilerPath(const ACompilerPath: string): string;
    procedure LoadToolchains(AObject: TJSONObject);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure LoadFromInitializationOptions(AOptions: TNXJSONRPCValue);
    procedure ExpandMacros(const ARootPath, ATempPath: string);

    property ProgramFile: string read FProgramFile write FProgramFile;
    property CWD: string read FCWD write FCWD;
    property FPCDir: string read FFPCDir write FFPCDir;
    property FPCOptions: TStringList read FFPCOptions;
    property LazarusDir: string read FLazarusDir write FLazarusDir;
    property CheckSyntax: Boolean read FCheckSyntax write FCheckSyntax;
    property PublishDiagnostics: Boolean read FPublishDiagnostics write FPublishDiagnostics;
    property ShowSyntaxErrors: Boolean read FShowSyntaxErrors write FShowSyntaxErrors;
    property CheckInactiveRegions: Boolean read FCheckInactiveRegions write FCheckInactiveRegions;
  end;

implementation

uses
  SysUtils;

constructor TNXLSSettings.Create;
begin
  inherited Create;
  FFPCOptions := TStringList.Create;
  Clear;
end;

destructor TNXLSSettings.Destroy;
begin
  FreeAndNil(FFPCOptions);
  inherited Destroy;
end;

procedure TNXLSSettings.Clear;
begin
  FProgramFile := '';
  FCWD := '';
  FFPCDir := '';
  FLazarusDir := '';
  FFPCOptions.Clear;
  FCheckSyntax := False;
  FPublishDiagnostics := False;
  FShowSyntaxErrors := False;
  FCheckInactiveRegions := True;
end;

function TNXLSSettings.ExpandMacrosInString(const AValue, ARootPath,
  ATempPath: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '$(root)', ARootPath, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '$root', ARootPath, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '$(tmpdir)', ATempPath, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '$tmpdir', ATempPath, [rfReplaceAll, rfIgnoreCase]);
end;

procedure TNXLSSettings.ExpandMacrosInStrings(AValues: TStrings;
  const ARootPath, ATempPath: string);
var
  lIdx: Integer;
begin
  for lIdx := 0 to AValues.Count - 1 do
    AValues[lIdx] := ExpandMacrosInString(AValues[lIdx], ARootPath, ATempPath);
end;

procedure TNXLSSettings.LoadStringArray(AData: TJSONData; ATarget: TStrings);
var
  lArray: TJSONArray;
  lIdx: Integer;
begin
  ATarget.Clear;

  if (AData = nil) or (AData.JSONType = jtNull) then
    Exit;

  if AData.JSONType = jtString then
  begin
    if Trim(AData.AsString) <> '' then
      ATarget.Add(AData.AsString);
    Exit;
  end;

  if AData.JSONType <> jtArray then
    Exit;

  lArray := TJSONArray(AData);
  for lIdx := 0 to lArray.Count - 1 do
    if (lArray.Items[lIdx] <> nil) and (lArray.Items[lIdx].JSONType = jtString) then
      ATarget.Add(lArray.Items[lIdx].AsString);
end;

procedure TNXLSSettings.LoadStringValue(AObject: TJSONObject; const AName: string; var ATarget: string);
var
  lData: TJSONData;
begin
  if (AObject = nil) or (AObject.IndexOfName(AName) < 0) then
    Exit;

  lData := AObject.Find(AName);
  if (lData <> nil) and (lData.JSONType = jtString) then
    ATarget := lData.AsString;
end;

procedure TNXLSSettings.LoadBooleanValue(AObject: TJSONObject; const AName: string; var ATarget: Boolean);
var
  lData: TJSONData;
begin
  if (AObject = nil) or (AObject.IndexOfName(AName) < 0) then
    Exit;

  lData := AObject.Find(AName);
  if (lData <> nil) and (lData.JSONType = jtBoolean) then
    ATarget := lData.AsBoolean;
end;

function TNXLSSettings.JSONBoolean(AObject: TJSONObject; const AName: string;
  ADefault: Boolean): Boolean;
var
  lData: TJSONData;
begin
  Result := ADefault;
  if AObject = nil then
    Exit;

  lData := AObject.Find(AName);
  if (lData <> nil) and (lData.JSONType = jtBoolean) then
    Result := lData.AsBoolean;
end;

function TNXLSSettings.JSONString(AObject: TJSONObject; const AName: string): string;
var
  lData: TJSONData;
begin
  Result := '';
  if AObject = nil then
    Exit;

  lData := AObject.Find(AName);
  if (lData <> nil) and (lData.JSONType = jtString) then
    Result := Trim(lData.AsString);
end;

function TNXLSSettings.FindFPCDirInLazarus(const ALazarusDir: string): string;
var
  lRoot: string;
  lSearch: TSearchRec;
begin
  Result := '';
  if ALazarusDir = '' then
    Exit;

  lRoot := IncludeTrailingPathDelimiter(ALazarusDir) + 'fpc';
  if not DirectoryExists(lRoot) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(lRoot) + '*', faDirectory,
    lSearch) = 0 then
  try
    repeat
      if (lSearch.Name <> '.') and (lSearch.Name <> '..') and
        ((lSearch.Attr and faDirectory) <> 0) and
        DirectoryExists(IncludeTrailingPathDelimiter(lRoot) + lSearch.Name) then
      begin
        Result := IncludeTrailingPathDelimiter(lRoot) + lSearch.Name;
        Exit;
      end;
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;

  if Result = '' then
    Result := lRoot;
end;

function TNXLSSettings.FPCDirFromCompilerPath(const ACompilerPath: string): string;
var
  lBinDir: string;
begin
  Result := '';
  if ACompilerPath = '' then
    Exit;

  lBinDir := ExtractFileDir(ACompilerPath);
  if SameText(ExtractFileName(lBinDir), 'bin') then
    Exit(ExtractFileDir(lBinDir));

  lBinDir := ExtractFileDir(lBinDir);
  if SameText(ExtractFileName(lBinDir), 'bin') then
    Result := ExtractFileDir(lBinDir);
end;

procedure TNXLSSettings.LoadToolchains(AObject: TJSONObject);
var
  lCompilerPath: string;
  lData: TJSONData;
  lFPC: TJSONObject;
  lLazarus: TJSONObject;
  lToolchains: TJSONData;
begin
  if AObject = nil then
    Exit;

  lToolchains := AObject.Find('toolchains');
  if (lToolchains = nil) or (lToolchains.JSONType <> jtObject) then
    Exit;

  lLazarus := nil;
  lData := TJSONObject(lToolchains).Find('lazarus');
  if (lData <> nil) and (lData.JSONType = jtObject) then
    lLazarus := TJSONObject(lData);
  if (lLazarus <> nil) and JSONBoolean(lLazarus, 'enabled', True) then
    FLazarusDir := JSONString(lLazarus, 'installDirectory');

  lFPC := nil;
  lData := TJSONObject(lToolchains).Find('freepascal');
  if (lData <> nil) and (lData.JSONType = jtObject) then
    lFPC := TJSONObject(lData);
  if (lFPC <> nil) and JSONBoolean(lFPC, 'enabled', True) then
  begin
    FFPCDir := JSONString(lFPC, 'installDirectory');
    if FFPCDir = '' then
      FFPCDir := JSONString(lFPC, 'fpcDirectory');
    if FFPCDir = '' then
    begin
      lCompilerPath := JSONString(lFPC, 'compilerPath');
      FFPCDir := FPCDirFromCompilerPath(lCompilerPath);
    end;
  end;

  if (FFPCDir = '') and (FLazarusDir <> '') then
    FFPCDir := FindFPCDirInLazarus(FLazarusDir);
end;

procedure TNXLSSettings.LoadFromInitializationOptions(AOptions: TNXJSONRPCValue);
var
  lData: TJSONData;
  lObject: TJSONObject;
begin
  Clear;

  if (AOptions = nil) or (not AOptions.Assigned) then
    Exit;

  lData := AOptions.ToJSONData;
  try
    if (lData = nil) or (lData.JSONType <> jtObject) then
      Exit;

    lObject := TJSONObject(lData);
    LoadStringValue(lObject, 'cwd', FCWD);
    LoadToolchains(lObject);
    LoadStringValue(lObject, 'program', FProgramFile);
    LoadStringArray(lObject.Find('fpcOptions'), FFPCOptions);
    LoadBooleanValue(lObject, 'checkSyntax', FCheckSyntax);
    LoadBooleanValue(lObject, 'publishDiagnostics', FPublishDiagnostics);
    LoadBooleanValue(lObject, 'showSyntaxErrors', FShowSyntaxErrors);
    LoadBooleanValue(lObject, 'checkInactiveRegions', FCheckInactiveRegions);
  finally
    lData.Free;
  end;
end;

procedure TNXLSSettings.ExpandMacros(const ARootPath, ATempPath: string);
begin
  FProgramFile := ExpandMacrosInString(FProgramFile, ARootPath, ATempPath);
  FCWD := ExpandMacrosInString(FCWD, ARootPath, ATempPath);
  FFPCDir := ExpandMacrosInString(FFPCDir, ARootPath, ATempPath);
  FLazarusDir := ExpandMacrosInString(FLazarusDir, ARootPath, ATempPath);
  ExpandMacrosInStrings(FFPCOptions, ARootPath, ATempPath);
end;

end.
