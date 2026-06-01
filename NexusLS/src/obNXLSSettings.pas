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
    FProgramFile: string;
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
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure LoadFromInitializationOptions(AOptions: TNXJSONRPCValue);
    procedure ExpandMacros(const ARootPath, ATempPath: string);

    property ProgramFile: string read FProgramFile write FProgramFile;
    property FPCOptions: TStringList read FFPCOptions;
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
  ExpandMacrosInStrings(FFPCOptions, ARootPath, ATempPath);
end;

end.
