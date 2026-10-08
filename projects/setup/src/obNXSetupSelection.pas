(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupSelection;

{$mode delphi}{$H+}

interface

uses Classes, Generics.Collections, obNXSetupModel;

type
  { Applicability is supplied by the caller; selection includes ancestors. }
  TNXSetupSelection = class
  private
    FDocument: TNXSetupDocument;
    FApplicable, FExplicit, FSelected: TList<TNXSetupFeature>;
    FDependencies: TList<TNXSetupDependency>;
    procedure Resolve(ASeeds, AResult: TList<TNXSetupFeature>);
    procedure CollectDependencies;
    procedure Commit(ASeeds, ASelected: TList<TNXSetupFeature>);
    procedure CheckExclusive(ASelected: TList<TNXSetupFeature>);
    function InBranch(AFeature, AParent: TNXSetupFeature): Boolean;
  public
    constructor Create(ADocument: TNXSetupDocument;
      AApplicable: TList<TNXSetupFeature>);
    destructor Destroy; override;
    procedure SelectDefaults;
    procedure SaveSeeds(ASeeds: TStrings);
    procedure RestoreSeeds(ASeeds: TStrings);
    function SetSelected(AFeature: TNXSetupFeature; ASelected: Boolean;
      out AReason: string): Boolean;
    function Explain(AFeature: TNXSetupFeature): string;
    property Explicit: TList<TNXSetupFeature> read FExplicit;
    property Selected: TList<TNXSetupFeature> read FSelected;
    property Dependencies: TList<TNXSetupDependency> read FDependencies;
  end;

implementation

uses SysUtils, tpNXSetup;

function FeatureKey(AFeature: TNXSetupFeature): string;
begin
  Result := IntToStr(Length(AFeature.Declaration.Name)) + ':' + AFeature.Declaration.Name;
  if AFeature.Parent <> nil then Result := FeatureKey(AFeature.Parent) + '/' + Result;
end;

procedure TNXSetupSelection.SaveSeeds(ASeeds: TStrings);
var
  lFeature: TNXSetupFeature;
begin
  ASeeds.Clear;
  for lFeature in FExplicit do ASeeds.Add(FeatureKey(lFeature));
end;

procedure TNXSetupSelection.RestoreSeeds(ASeeds: TStrings);
var
  lSeeds, lSelected: TList<TNXSetupFeature>;
  lFeature: TNXSetupFeature;
  lKey: string;
  lFound: Boolean;
begin
  lSeeds := TList<TNXSetupFeature>.Create;
  lSelected := TList<TNXSetupFeature>.Create;
  try
    for lKey in ASeeds do
    begin
      lFound := False;
      for lFeature in FApplicable do
        if FeatureKey(lFeature) = lKey then
        begin
          if lSeeds.IndexOf(lFeature) >= 0 then raise ENXSetup.Create('Duplicate retained feature: ' + lKey);
          lSeeds.Add(lFeature);
          lFound := True;
          Break;
        end;
      if not lFound then raise ENXSetup.Create('Retained feature is unavailable: ' + lKey);
    end;
    Resolve(lSeeds, lSelected);
    Commit(lSeeds, lSelected);
  finally
    lSelected.Free;
    lSeeds.Free;
  end;
end;

constructor TNXSetupSelection.Create(ADocument: TNXSetupDocument;
  AApplicable: TList<TNXSetupFeature>);
var
  lFeature: TNXSetupFeature;
begin
  inherited Create;
  FDocument := ADocument;
  FApplicable := TList<TNXSetupFeature>.Create;
  FExplicit := TList<TNXSetupFeature>.Create;
  FSelected := TList<TNXSetupFeature>.Create;
  FDependencies := TList<TNXSetupDependency>.Create;
  for lFeature in AApplicable do
  begin
    if FDocument.Features.IndexOf(lFeature) < 0 then
      raise ENXSetup.Create('Applicable feature belongs to another document.');
    if FApplicable.IndexOf(lFeature) < 0 then FApplicable.Add(lFeature);
  end;
  Resolve(FExplicit, FSelected);
  CollectDependencies;
end;

destructor TNXSetupSelection.Destroy;
begin
  FDependencies.Free;
  FSelected.Free;
  FExplicit.Free;
  FApplicable.Free;
  inherited Destroy;
end;

procedure TNXSetupSelection.CheckExclusive(ASelected: TList<TNXSetupFeature>);
var
  lIndex, lOther: Integer;
  lLeft, lRight: TNXSetupFeature;
  lMode: TNXSetupChildMode;
begin
  for lIndex := 0 to ASelected.Count - 1 do
  begin
    lLeft := ASelected[lIndex];
    lMode := FDocument.Product.ChildMode;
    if lLeft.Parent <> nil then lMode := lLeft.Parent.ChildMode;
    if lMode <> scmExclusive then Continue;
    for lOther := 0 to lIndex - 1 do
    begin
      lRight := ASelected[lOther];
      if lLeft.Parent = lRight.Parent then
        raise ENXSetup.CreateFmt('Exclusive choices conflict: %s and %s.',
          [lLeft.Name, lRight.Name]);
    end;
  end;
end;

procedure TNXSetupSelection.Resolve(ASeeds, AResult: TList<TNXSetupFeature>);
var
  lFeature, lRequired: TNXSetupFeature;
  lIndex: Integer;
begin
  AResult.Clear;
  for lFeature in ASeeds do
    if AResult.IndexOf(lFeature) < 0 then AResult.Add(lFeature);
  for lFeature in FApplicable do
    if lFeature.Required and (lFeature.Parent = nil) and
      (AResult.IndexOf(lFeature) < 0) then AResult.Add(lFeature);
  lIndex := 0;
  while lIndex < AResult.Count do
  begin
    lFeature := AResult[lIndex];
    if FApplicable.IndexOf(lFeature) < 0 then
      raise ENXSetup.Create('Required feature is not applicable: ' + lFeature.Name);
    if (lFeature.Parent <> nil) and (AResult.IndexOf(lFeature.Parent) < 0) then
      AResult.Add(lFeature.Parent);
    for lRequired in lFeature.Requires do
      if AResult.IndexOf(lRequired) < 0 then AResult.Add(lRequired);
    for lRequired in lFeature.Children do
      if lRequired.Required and (FApplicable.IndexOf(lRequired) >= 0) and
        (AResult.IndexOf(lRequired) < 0) then AResult.Add(lRequired);
    Inc(lIndex);
  end;
  CheckExclusive(AResult);
end;

function TNXSetupSelection.InBranch(AFeature, AParent: TNXSetupFeature): Boolean;
begin
  while AFeature <> nil do
  begin
    if AFeature = AParent then Exit(True);
    AFeature := AFeature.Parent;
  end;
  Result := False;
end;

procedure TNXSetupSelection.CollectDependencies;
var
  lFeature: TNXSetupFeature;
  lDependency: TNXSetupDependency;
  lIndex: Integer;
begin
  FDependencies.Clear;
  for lFeature in FSelected do
    for lDependency in lFeature.Dependencies do
      if FDependencies.IndexOf(lDependency) < 0 then FDependencies.Add(lDependency);
  lIndex := 0;
  while lIndex < FDependencies.Count do
  begin
    for lDependency in FDependencies[lIndex].Requires do
      if FDependencies.IndexOf(lDependency) < 0 then FDependencies.Add(lDependency);
    Inc(lIndex);
  end;
end;

procedure TNXSetupSelection.Commit(ASeeds, ASelected: TList<TNXSetupFeature>);
begin
  FExplicit.Clear;
  FExplicit.AddRange(ASeeds);
  FSelected.Clear;
  FSelected.AddRange(ASelected);
  CollectDependencies;
end;

procedure TNXSetupSelection.SelectDefaults;
var
  lSeeds, lSelected: TList<TNXSetupFeature>;
  lFeature: TNXSetupFeature;
  lCount: Integer;
begin
  lSeeds := TList<TNXSetupFeature>.Create;
  lSelected := TList<TNXSetupFeature>.Create;
  try
    Resolve(lSeeds, lSelected);
    repeat
      lCount := lSeeds.Count;
      for lFeature in FApplicable do
        if lFeature.Default and (lSeeds.IndexOf(lFeature) < 0) and
          ((lFeature.Parent = nil) or (lSelected.IndexOf(lFeature.Parent) >= 0)) then
          lSeeds.Add(lFeature);
      Resolve(lSeeds, lSelected);
    until lSeeds.Count = lCount;
    Commit(lSeeds, lSelected);
  finally
    lSelected.Free;
    lSeeds.Free;
  end;
end;

function TNXSetupSelection.Explain(AFeature: TNXSetupFeature): string;
var
  lOther: TNXSetupFeature;
begin
  Result := '';
  if AFeature.Required and (FApplicable.IndexOf(AFeature) >= 0) then
    Result := 'Required within the selected branch.';
  for lOther in FSelected do
    if (lOther <> AFeature) and (lOther.Requires.IndexOf(AFeature) >= 0) then
    begin
      if Result <> '' then Result := Result + ' ';
      Result := Result + 'Required by ' + lOther.Name + '.';
    end;
  if (Result = '') and (FExplicit.IndexOf(AFeature) >= 0) then Result := 'Explicitly selected.';
  for lOther in FSelected do
    if lOther.Parent = AFeature then
    begin
      if Result <> '' then Result := Result + ' ';
      Result := Result + 'Parent of ' + lOther.Name + '.';
    end;
end;

function TNXSetupSelection.SetSelected(AFeature: TNXSetupFeature;
  ASelected: Boolean; out AReason: string): Boolean;
var
  lSeeds, lSelected: TList<TNXSetupFeature>;
  lIndex: Integer;
begin
  Result := False;
  AReason := '';
  if FApplicable.IndexOf(AFeature) < 0 then
  begin
    AReason := 'Feature is not in the supplied applicable set.';
    Exit;
  end;
  lSeeds := TList<TNXSetupFeature>.Create;
  lSelected := TList<TNXSetupFeature>.Create;
  try
    lSeeds.AddRange(FExplicit);
    if ASelected then
    begin
      if lSeeds.IndexOf(AFeature) < 0 then lSeeds.Add(AFeature);
    end
    else
      for lIndex := lSeeds.Count - 1 downto 0 do
        if InBranch(lSeeds[lIndex], AFeature) then lSeeds.Delete(lIndex);
    try
      Resolve(lSeeds, lSelected);
      if not ASelected and (lSelected.IndexOf(AFeature) >= 0) then
      begin
        AReason := Explain(AFeature);
        Exit;
      end;
      Commit(lSeeds, lSelected);
      Result := True;
    except
      on lError: ENXSetup do AReason := lError.Message;
    end;
  finally
    lSelected.Free;
    lSeeds.Free;
  end;
end;

end.
