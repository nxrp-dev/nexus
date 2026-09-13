unit obNexusScriptLSOverlay;

{$mode delphi}{$H+}

interface

uses
  Classes,
  Generics.Collections,
  obNexusScriptSourceProvider;

type
  TNexusScriptLSOverlaySource = class
  private
    FSourceName: string;
    FText: string;
    FVersion: Integer;
  public
    constructor Create(const ASourceName, AText: string; AVersion: Integer);
    property SourceName: string read FSourceName;
    property Text: string read FText write FText;
    property Version: Integer read FVersion write FVersion;
  end;

  TNexusScriptLSOverlayProvider = class(TNexusScriptSourceProvider)
  private
    FBacking: TNexusScriptSourceProvider;
    FOwnsBacking: Boolean;
    FSources: TObjectList<TNexusScriptLSOverlaySource>;
    function FindSource(const ASourceName: string): TNexusScriptLSOverlaySource;
  public
    constructor Create(ABacking: TNexusScriptSourceProvider = nil);
    destructor Destroy; override;
    procedure Put(const ASourceName, AText: string; AVersion: Integer);
    procedure Remove(const ASourceName: string);
    function CanonicalName(const ASourceName: string): string; override;
    function Exists(const ASourceName: string): Boolean; override;
    function FolderExists(const AFolderName: string): Boolean; override;
    function ReadSource(const ASourceName: string; out AText: string;
      out AVersion: Integer): Boolean; override;
    function SelectFiles(const AFolderName, AFileNamePattern: string;
      ARecursive: Boolean): TStringList; override;
    function SameIdentity(const ALeft, ARight: string): Boolean; override;
  end;

implementation

uses
  SysUtils;

function WildcardMatch(const AValue, AMask: string): Boolean;
var
  lValueIndex: Integer;
  lMaskIndex: Integer;
  lStarIndex: Integer;
  lRetryIndex: Integer;
  lValue: string;
  lMask: string;
begin
  {$IFDEF Windows}
  lValue := LowerCase(AValue);
  lMask := LowerCase(AMask);
  {$ELSE}
  lValue := AValue;
  lMask := AMask;
  {$ENDIF}
  lValueIndex := 1;
  lMaskIndex := 1;
  lStarIndex := 0;
  lRetryIndex := 0;
  while lValueIndex <= Length(lValue) do
  begin
    if (lMaskIndex <= Length(lMask)) and
      ((lMask[lMaskIndex] = '?') or
      (lMask[lMaskIndex] = lValue[lValueIndex])) then
    begin
      Inc(lValueIndex);
      Inc(lMaskIndex);
    end
    else if (lMaskIndex <= Length(lMask)) and (lMask[lMaskIndex] = '*') then
    begin
      lStarIndex := lMaskIndex;
      lRetryIndex := lValueIndex;
      Inc(lMaskIndex);
    end
    else if lStarIndex > 0 then
    begin
      lMaskIndex := lStarIndex + 1;
      Inc(lRetryIndex);
      lValueIndex := lRetryIndex;
    end
    else
      Exit(False);
  end;
  while (lMaskIndex <= Length(lMask)) and (lMask[lMaskIndex] = '*') do
    Inc(lMaskIndex);
  Result := lMaskIndex > Length(lMask);
end;

constructor TNexusScriptLSOverlaySource.Create(const ASourceName,
  AText: string; AVersion: Integer);
begin
  inherited Create;
  FSourceName := ASourceName;
  FText := AText;
  FVersion := AVersion;
end;

constructor TNexusScriptLSOverlayProvider.Create(
  ABacking: TNexusScriptSourceProvider);
begin
  inherited Create;
  FBacking := ABacking;
  FOwnsBacking := FBacking = nil;
  if FOwnsBacking then
    FBacking := TNexusScriptFileSourceProvider.Create;
  FSources := TObjectList<TNexusScriptLSOverlaySource>.Create(True);
end;

destructor TNexusScriptLSOverlayProvider.Destroy;
begin
  FSources.Free;
  if FOwnsBacking then
    FBacking.Free;
  inherited Destroy;
end;

function TNexusScriptLSOverlayProvider.CanonicalName(
  const ASourceName: string): string;
begin
  Result := FBacking.CanonicalName(ASourceName);
end;

function TNexusScriptLSOverlayProvider.SameIdentity(const ALeft,
  ARight: string): Boolean;
begin
  Result := FBacking.SameIdentity(ALeft, ARight);
end;

function TNexusScriptLSOverlayProvider.FindSource(
  const ASourceName: string): TNexusScriptLSOverlaySource;
var
  lSource: TNexusScriptLSOverlaySource;
begin
  Result := nil;
  for lSource in FSources do
    if SameIdentity(lSource.SourceName, ASourceName) then
      Exit(lSource);
end;

procedure TNexusScriptLSOverlayProvider.Put(const ASourceName, AText: string;
  AVersion: Integer);
var
  lSource: TNexusScriptLSOverlaySource;
begin
  lSource := FindSource(ASourceName);
  if lSource = nil then
    FSources.Add(TNexusScriptLSOverlaySource.Create(
      CanonicalName(ASourceName), AText, AVersion))
  else
  begin
    lSource.Text := AText;
    lSource.Version := AVersion;
  end;
end;

procedure TNexusScriptLSOverlayProvider.Remove(const ASourceName: string);
var
  lIndex: Integer;
begin
  for lIndex := 0 to FSources.Count - 1 do
    if SameIdentity(FSources[lIndex].SourceName, ASourceName) then
    begin
      FSources.Delete(lIndex);
      Exit;
    end;
end;

function TNexusScriptLSOverlayProvider.Exists(
  const ASourceName: string): Boolean;
begin
  Result := (FindSource(ASourceName) <> nil) or FBacking.Exists(ASourceName);
end;

function TNexusScriptLSOverlayProvider.FolderExists(
  const AFolderName: string): Boolean;
var
  lSource: TNexusScriptLSOverlaySource;
  lFolder: string;
  lSourceFolder: string;
begin
  if FBacking.FolderExists(AFolderName) then
    Exit(True);
  lFolder := IncludeTrailingPathDelimiter(CanonicalName(AFolderName));
  for lSource in FSources do
  begin
    lSourceFolder := IncludeTrailingPathDelimiter(
      ExtractFileDir(lSource.SourceName));
    {$IFDEF Windows}
    if SameText(Copy(lSourceFolder, 1, Length(lFolder)), lFolder) then
    {$ELSE}
    if Copy(lSourceFolder, 1, Length(lFolder)) = lFolder then
    {$ENDIF}
      Exit(True);
  end;
  Result := False;
end;

function TNexusScriptLSOverlayProvider.ReadSource(const ASourceName: string;
  out AText: string; out AVersion: Integer): Boolean;
var
  lSource: TNexusScriptLSOverlaySource;
begin
  lSource := FindSource(ASourceName);
  if lSource = nil then
    Exit(FBacking.ReadSource(ASourceName, AText, AVersion));
  AText := lSource.Text;
  AVersion := lSource.Version;
  Result := True;
end;

function TNexusScriptLSOverlayProvider.SelectFiles(const AFolderName,
  AFileNamePattern: string; ARecursive: Boolean): TStringList;
var
  lSource: TNexusScriptLSOverlaySource;
  lFolder: string;
  lSourceFolder: string;
  lIndex: Integer;
  lFound: Boolean;
begin
  Result := FBacking.SelectFiles(AFolderName, AFileNamePattern, ARecursive);
  lFolder := IncludeTrailingPathDelimiter(CanonicalName(AFolderName));
  for lSource in FSources do
  begin
    lSourceFolder := IncludeTrailingPathDelimiter(
      ExtractFileDir(lSource.SourceName));
    if ARecursive then
    begin
      {$IFDEF Windows}
      lFound := SameText(Copy(lSourceFolder, 1, Length(lFolder)), lFolder);
      {$ELSE}
      lFound := Copy(lSourceFolder, 1, Length(lFolder)) = lFolder;
      {$ENDIF}
    end
    else
      lFound := SameIdentity(ExcludeTrailingPathDelimiter(lSourceFolder),
        ExcludeTrailingPathDelimiter(lFolder));
    if not lFound or not WildcardMatch(ExtractFileName(lSource.SourceName),
      AFileNamePattern) then
      Continue;
    lFound := False;
    for lIndex := 0 to Result.Count - 1 do
      if SameIdentity(Result[lIndex], lSource.SourceName) then
      begin
        Result[lIndex] := lSource.SourceName;
        lFound := True;
        Break;
      end;
    if not lFound then
      Result.Add(lSource.SourceName);
  end;
end;

end.
