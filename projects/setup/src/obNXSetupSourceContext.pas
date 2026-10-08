(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupSourceContext;

{$mode delphi}{$H+}

interface

uses Classes, Generics.Collections, obNexusScriptSourceProvider, obNexusScriptModel;

type
  TNXSetupSource = class
  private
    FName, FText: string;
  public
    constructor Create(const AName, AText: string);
    property Name: string read FName;
    property Text: string read FText;
  end;

  TNXSetupFileSelection = class
  private
    FFolder, FPattern: string;
    FRecursive: Boolean;
    FFiles: TStringList;
  public
    constructor Create(const AFolder, APattern: string; ARecursive: Boolean;
      AFiles: TStringList);
    destructor Destroy; override;
    property Folder: string read FFolder;
    property Pattern: string read FPattern;
    property Recursive: Boolean read FRecursive;
    property Files: TStringList read FFiles;
  end;

  { Capture precisely the source and include/module selections read by compilation. }
  TNXSetupSourceContext = class(TNexusScriptSourceProvider)
  private
    FProvider: TNexusScriptSourceProvider;
    FOwnsProvider: Boolean;
    FReplay: Boolean;
    FSources: TObjectList<TNXSetupSource>;
    FSelections: TObjectList<TNXSetupFileSelection>;
    FTargets: TNexusScriptTargetSelection;
    FEntryName: string;
    function FindSource(const AName: string): TNXSetupSource;
  public
    constructor Create(AProvider: TNexusScriptSourceProvider = nil;
      ATargets: TNexusScriptTargetSelection = nil);
    destructor Destroy; override;
    procedure Freeze;
    procedure SaveToStream(AStream: TStream);
    class function LoadFromStream(AStream: TStream): TNXSetupSourceContext; static;
    function CanonicalName(const ASourceName: string): string; override;
    function Exists(const ASourceName: string): Boolean; override;
    function FolderExists(const AFolderName: string): Boolean; override;
    function ReadSource(const ASourceName: string; out AText: string;
      out AVersion: Integer): Boolean; override;
    function SelectFiles(const AFolderName, AFileNamePattern: string;
      ARecursive: Boolean): TStringList; override;
    function SameIdentity(const ALeft, ARight: string): Boolean; override;
    function SupportsRelativePaths(const ASourceName: string): Boolean; override;
    property Sources: TObjectList<TNXSetupSource> read FSources;
    property Selections: TObjectList<TNXSetupFileSelection> read FSelections;
    property Targets: TNexusScriptTargetSelection read FTargets;
    property EntryName: string read FEntryName write FEntryName;
  end;

implementation

uses SysUtils, utNXSetupStreams;

constructor TNXSetupSource.Create(const AName, AText: string);
begin
  inherited Create;
  FName := AName;
  FText := AText;
end;

constructor TNXSetupFileSelection.Create(const AFolder, APattern: string;
  ARecursive: Boolean; AFiles: TStringList);
begin
  inherited Create;
  FFolder := AFolder;
  FPattern := APattern;
  FRecursive := ARecursive;
  FFiles := TStringList.Create;
  FFiles.Assign(AFiles);
end;

destructor TNXSetupFileSelection.Destroy;
begin
  FFiles.Free;
  inherited Destroy;
end;

constructor TNXSetupSourceContext.Create(AProvider: TNexusScriptSourceProvider;
  ATargets: TNexusScriptTargetSelection);
begin
  inherited Create;
  FProvider := AProvider;
  FOwnsProvider := FProvider = nil;
  if FOwnsProvider then FProvider := TNexusScriptFileSourceProvider.Create;
  FSources := TObjectList<TNXSetupSource>.Create(True);
  FSelections := TObjectList<TNXSetupFileSelection>.Create(True);
  FTargets := TNexusScriptTargetSelection.Create;
  if ATargets <> nil then FTargets.Assign(ATargets);
end;

destructor TNXSetupSourceContext.Destroy;
begin
  FTargets.Free;
  FSelections.Free;
  FSources.Free;
  if FOwnsProvider then FProvider.Free;
  inherited Destroy;
end;

procedure TNXSetupSourceContext.Freeze;
begin
  if not FOwnsProvider then
  begin
    { Retained contexts cannot keep borrowing a caller's transient provider. }
    FProvider := TNexusScriptFileSourceProvider.Create;
    FOwnsProvider := True;
  end;
  FReplay := True;
end;

function TNXSetupSourceContext.CanonicalName(const ASourceName: string): string;
begin
  Result := FProvider.CanonicalName(ASourceName);
end;

function TNXSetupSourceContext.SameIdentity(const ALeft, ARight: string): Boolean;
begin
  Result := FProvider.SameIdentity(ALeft, ARight);
end;

function TNXSetupSourceContext.SupportsRelativePaths(const ASourceName: string): Boolean;
begin
  Result := FProvider.SupportsRelativePaths(ASourceName);
end;

function TNXSetupSourceContext.FindSource(const AName: string): TNXSetupSource;
var
  lSource: TNXSetupSource;
begin
  for lSource in FSources do
    if SameIdentity(lSource.Name, AName) then Exit(lSource);
  Result := nil;
end;

function TNXSetupSourceContext.Exists(const ASourceName: string): Boolean;
begin
  Result := FindSource(ASourceName) <> nil;
  if not Result and not FReplay then Result := FProvider.Exists(ASourceName);
end;

function TNXSetupSourceContext.FolderExists(const AFolderName: string): Boolean;
var
  lSelection: TNXSetupFileSelection;
begin
  if not FReplay then Exit(FProvider.FolderExists(AFolderName));
  for lSelection in FSelections do
    if SameIdentity(lSelection.Folder, AFolderName) then Exit(True);
  Result := False;
end;

function TNXSetupSourceContext.ReadSource(const ASourceName: string;
  out AText: string; out AVersion: Integer): Boolean;
var
  lSource: TNXSetupSource;
begin
  AText := '';
  AVersion := -1;
  lSource := FindSource(ASourceName);
  if lSource <> nil then
  begin
    AText := lSource.Text;
    Exit(True);
  end;
  Result := not FReplay and FProvider.ReadSource(ASourceName, AText, AVersion);
  if Result then FSources.Add(TNXSetupSource.Create(CanonicalName(ASourceName), AText));
end;

function TNXSetupSourceContext.SelectFiles(const AFolderName, AFileNamePattern: string;
  ARecursive: Boolean): TStringList;
var
  lSelection: TNXSetupFileSelection;
begin
  for lSelection in FSelections do
    if SameIdentity(lSelection.Folder, AFolderName) and
      (lSelection.Pattern = AFileNamePattern) and (lSelection.Recursive = ARecursive) then
    begin
      Result := TStringList.Create;
      Result.Assign(lSelection.Files);
      Exit;
    end;
  if FReplay then raise Exception.Create('File selection is absent from retained source context.');
  Result := FProvider.SelectFiles(AFolderName, AFileNamePattern, ARecursive);
  FSelections.Add(TNXSetupFileSelection.Create(CanonicalName(AFolderName),
    AFileNamePattern, ARecursive, Result));
end;

procedure TNXSetupSourceContext.SaveToStream(AStream: TStream);
var
  lSource: TNXSetupSource;
  lSelection: TNXSetupFileSelection;
  lName: string;
  lIndex: Integer;
begin
  WriteText(AStream, 'NXSource1');
  WriteText(AStream, FEntryName);
  WriteNumber(AStream, FTargets.Count);
  for lIndex := 0 to FTargets.Count - 1 do
  begin
    WriteText(AStream, FTargets.Items[lIndex].Name);
    WriteText(AStream, FTargets.Items[lIndex].Value);
  end;
  WriteNumber(AStream, FSources.Count);
  for lSource in FSources do
  begin
    WriteText(AStream, lSource.Name);
    WriteText(AStream, lSource.Text);
  end;
  WriteNumber(AStream, FSelections.Count);
  for lSelection in FSelections do
  begin
    WriteText(AStream, lSelection.Folder);
    WriteText(AStream, lSelection.Pattern);
    WriteNumber(AStream, Ord(lSelection.Recursive));
    WriteNumber(AStream, lSelection.Files.Count);
    for lName in lSelection.Files do WriteText(AStream, lName);
  end;
end;

class function TNXSetupSourceContext.LoadFromStream(AStream: TStream): TNXSetupSourceContext;
var
  lContext: TNXSetupSourceContext;
  lName, lText, lFolder, lPattern: string;
  lIndex, lCount, lItem: Integer;
  lFiles: TStringList;
  lRecursive: QWord;
begin
  lContext := TNXSetupSourceContext.Create;
  lFiles := TStringList.Create;
  try
    if ReadText(AStream) <> 'NXSource1' then raise EReadError.Create('Unknown Setup source format.');
    { Original filenames are virtual lookup identities, never extraction paths.
      Freeze forbids fallback reads from those locations. }
    lContext.FEntryName := ReadText(AStream);
    lCount := ReadCount(AStream);
    for lIndex := 1 to lCount do
    begin
      lName := ReadText(AStream);
      lText := ReadText(AStream);
      lContext.Targets.Add(lName, lText);
    end;
    lCount := ReadCount(AStream);
    for lIndex := 1 to lCount do
    begin
      lName := ReadText(AStream);
      lText := ReadText(AStream);
      if lContext.FindSource(lName) <> nil then raise EReadError.Create('Duplicate retained source.');
      lContext.Sources.Add(TNXSetupSource.Create(lName, lText));
    end;
    lCount := ReadCount(AStream);
    for lIndex := 1 to lCount do
    begin
      lFolder := ReadText(AStream);
      lPattern := ReadText(AStream);
      lRecursive := ReadNumber(AStream);
      if lRecursive > 1 then raise EReadError.Create('Invalid recursive selection flag.');
      lFiles.Clear;
      for lItem := 1 to ReadCount(AStream) do lFiles.Add(ReadText(AStream));
      lContext.Selections.Add(TNXSetupFileSelection.Create(lFolder, lPattern, lRecursive = 1, lFiles));
    end;
    RequireEnd(AStream);
    lContext.Freeze;
    Result := lContext;
    lContext := nil;
  finally
    lFiles.Free;
    lContext.Free;
  end;
end;

end.
