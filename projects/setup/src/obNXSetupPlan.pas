(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupPlan;

{$mode delphi}{$H+}

interface

uses Classes, Generics.Collections, obNXSetupModel, obNXSetupSelection, obNXSetupLocations;

type
  TNXSetupPlannedFile = class
  private
    FPayload: TNXSetupPayload;
    FSource, FDestination: string;
  public
    property Payload: TNXSetupPayload read FPayload;
    property Source: string read FSource;
    property Destination: string read FDestination;
  end;

  TNXSetupPlannedShortcut = class
  private
    FShortcut: TNXSetupShortcut;
    FLocation, FTarget: string;
  public
    property Shortcut: TNXSetupShortcut read FShortcut;
    property Location: string read FLocation;
    property Target: string read FTarget;
  end;

  { Resolved inspection data, not execution order or evidence of installation. }
  TNXSetupPlan = class
  private
    FFiles: TObjectList<TNXSetupPlannedFile>;
    FShortcuts: TObjectList<TNXSetupPlannedShortcut>;
    FDependencies: TList<TNXSetupDependency>;
    FSeeds, FBindings: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    class function Build(ASelection: TNXSetupSelection;
      ALocations: TNXSetupLocations): TNXSetupPlan; static;
    procedure RelocateSources(ASources: TDictionary<string, string>);
    property Files: TObjectList<TNXSetupPlannedFile> read FFiles;
    property Shortcuts: TObjectList<TNXSetupPlannedShortcut> read FShortcuts;
    property Dependencies: TList<TNXSetupDependency> read FDependencies;
    property Seeds: TStringList read FSeeds;
    property Bindings: TStringList read FBindings;
  end;

implementation

uses SysUtils, tpNXSetup, utNXSetupPaths;

constructor TNXSetupPlan.Create;
begin
  inherited Create;
  FFiles := TObjectList<TNXSetupPlannedFile>.Create(True);
  FShortcuts := TObjectList<TNXSetupPlannedShortcut>.Create(True);
  FDependencies := TList<TNXSetupDependency>.Create;
  FSeeds := TStringList.Create;
  FBindings := TStringList.Create;
end;

destructor TNXSetupPlan.Destroy;
begin
  FBindings.Free;
  FSeeds.Free;
  FDependencies.Free;
  FShortcuts.Free;
  FFiles.Free;
  inherited Destroy;
end;

class function TNXSetupPlan.Build(ASelection: TNXSetupSelection;
  ALocations: TNXSetupLocations): TNXSetupPlan;
var
  lPlan: TNXSetupPlan;
  lFeature: TNXSetupFeature;
  lPayload: TNXSetupPayload;
  lShortcut: TNXSetupShortcut;
  lFile: TNXSetupPlannedFile;
  lPath: string;
  lLink: TNXSetupPlannedShortcut;
begin
  lPlan := TNXSetupPlan.Create;
  try
    ASelection.SaveSeeds(lPlan.FSeeds);
    ALocations.SaveBindings(lPlan.FBindings);
    lPlan.FDependencies.AddRange(ASelection.Dependencies);
    for lFeature in ASelection.Selected do
    begin
      for lPayload in lFeature.Files do
      begin
        lFile := TNXSetupPlannedFile.Create;
        lPlan.FFiles.Add(lFile);
        lFile.FPayload := lPayload;
        if IsAbsolutePath(lPayload.Source) then lFile.FSource := ExpandFileName(lPayload.Source)
        else lFile.FSource := ExpandFileName(IncludeTrailingPathDelimiter(
          ExtractFileDir(lPayload.Declaration.SourceRange.SourceName)) + lPayload.Source);
        lPath := lPayload.Path;
        if (lPath = '') and (lPayload.Kind = spkFile) then lPath := ExtractFileName(lFile.Source);
        lFile.FDestination := TNXSetupLocations.RelativePath(
          ALocations.Resolve(lPayload.Location), lPath);
      end;
      for lShortcut in lFeature.Shortcuts do
      begin
        lLink := TNXSetupPlannedShortcut.Create;
        lPlan.FShortcuts.Add(lLink);
        lLink.FShortcut := lShortcut;
        lLink.FLocation := ALocations.Resolve(lShortcut.Location);
        lLink.FTarget := TNXSetupLocations.RelativePath(
          ALocations.Resolve(lShortcut.Target), lShortcut.Path);
      end;
    end;
    Result := lPlan;
  except
    lPlan.Free;
    raise;
  end;
end;

procedure TNXSetupPlan.RelocateSources(ASources: TDictionary<string, string>);
var
  lFile: TNXSetupPlannedFile;
  lName: string;
  lFound: Boolean;
begin
  for lFile in FFiles do
  begin
    lFound := False;
    for lName in ASources.Keys do
      if SameFileName(lName, lFile.Source) then
      begin
        lFile.FSource := ASources[lName];
        lFound := True;
        Break;
      end;
    if not lFound then raise ENXSetup.Create('Payload is absent from installer: ' + lFile.Source);
  end;
end;

end.
