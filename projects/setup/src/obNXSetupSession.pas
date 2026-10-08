(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)



unit obNXSetupSession;

{$mode delphi}{$H+}

interface

uses obNXSetupModel, obNXSetupSelection, obNXSetupLocations, obNXSetupBundle,
  obNXSetupPlan;

type
  { Owns declaration/selection/extraction for one operation. No UI ownership. }
  TNXSetupSession = class
  private
    FDocument: TNXSetupDocument;
    FSelection: TNXSetupSelection;
    FLocations: TNXSetupLocations;
    FBundle: TNXSetupBundle;
    FRoot: string;
    procedure InitializeSelection;
  protected
    procedure SetRoot(const AValue: string);
  public
    destructor Destroy; override;
    class function OpenDefinition(const AFileName: string): TNXSetupSession; static;
    class function OpenExecutable(const AFileName: string): TNXSetupSession; static;
    class function OpenInstalled(const AStateFile: string): TNXSetupSession; static;
    class procedure Repair(const AStateFile: string); static;
    function BuildPlan: TNXSetupPlan;
    function Install: string;
    property Document: TNXSetupDocument read FDocument;
    property Selection: TNXSetupSelection read FSelection;
    property Locations: TNXSetupLocations read FLocations;
    property Root: string read FRoot write SetRoot;
    property Bundled: TNXSetupBundle read FBundle;
  end;

implementation

uses SysUtils, Generics.Collections, obNXSetupLoader, obNXSetupState,
  obNXSetupFileInstaller;

destructor TNXSetupSession.Destroy;
begin
  FLocations.Free;
  FSelection.Free;
  FDocument.Free;
  FBundle.Free;
  inherited Destroy;
end;

procedure TNXSetupSession.InitializeSelection;
var
  lApplicable: TList<TNXSetupFeature>;
begin
  FLocations := TNXSetupLocations.Create;
  lApplicable := TList<TNXSetupFeature>.Create;
  try
    { Target filtering occurs in compilation. No additional detection policy. }
    lApplicable.AddRange(FDocument.Features);
    FSelection := TNXSetupSelection.Create(FDocument, lApplicable);
  finally
    lApplicable.Free;
  end;
end;

class function TNXSetupSession.OpenDefinition(const AFileName: string): TNXSetupSession;
var
  lSession: TNXSetupSession;
begin
  lSession := TNXSetupSession.Create;
  try
    lSession.FDocument := TNXSetupLoader.LoadFile(AFileName);
    lSession.InitializeSelection;
    lSession.FSelection.SelectDefaults;
    Result := lSession;
    lSession := nil;
  finally
    lSession.Free;
  end;
end;

class function TNXSetupSession.OpenExecutable(const AFileName: string): TNXSetupSession;
var
  lSession: TNXSetupSession;
begin
  lSession := TNXSetupSession.Create;
  try
    lSession.FBundle := TNXSetupBundle.OpenExecutable(AFileName);
    lSession.FDocument := lSession.FBundle.LoadDocument;
    lSession.InitializeSelection;
    lSession.FSelection.SelectDefaults;
    Result := lSession;
    lSession := nil;
  finally
    lSession.Free;
  end;
end;

class function TNXSetupSession.OpenInstalled(const AStateFile: string): TNXSetupSession;
var
  lState: TNXSetupState;
  lSession: TNXSetupSession;
begin
  lState := TNXSetupState.LoadFile(AStateFile);
  lSession := TNXSetupSession.Create;
  try
    lSession.FBundle := TNXSetupBundle.OpenArchive(
      IncludeTrailingPathDelimiter(ExtractFileDir(AStateFile)) + 'payload.zip');
    lSession.FDocument := lSession.FBundle.LoadDocument;
    if (lSession.FDocument.Product.Id <> lState.ProductId) or
      (lSession.FDocument.Product.Version <> lState.Version) then
      raise ENXSetup.Create('Retained payload does not match installed product.');
    lSession.InitializeSelection;
    lSession.FLocations.LoadBindings(lState.Bindings);
    lSession.Root := lState.Root;
    lSession.FSelection.RestoreSeeds(lState.Seeds);
    Result := lSession;
    lSession := nil;
  finally
    lSession.Free;
    lState.Free;
  end;
end;

procedure TNXSetupSession.SetRoot(const AValue: string);
begin
  FLocations.Bind('ApplicationRoot', AValue);
  FRoot := ExpandFileName(AValue);
end;

function TNXSetupSession.BuildPlan: TNXSetupPlan;
begin
  if FRoot = '' then raise ENXSetup.Create('Choose an absolute installation folder.');
  Result := TNXSetupPlan.Build(FSelection, FLocations);
  try
    if FBundle <> nil then Result.RelocateSources(FBundle.Payloads);
  except
    Result.Free;
    raise;
  end;
end;

function TNXSetupSession.Install: string;
var
  lPlan: TNXSetupPlan;
  lArchive: string;
begin
  lPlan := BuildPlan;
  try
    lArchive := '';
    if FBundle <> nil then lArchive := FBundle.ArchiveFile;
    Result := TNXSetupFileInstaller.Install(FDocument, lPlan, FRoot, lArchive);
  finally
    lPlan.Free;
  end;
end;

class procedure TNXSetupSession.Repair(const AStateFile: string);
var
  lSession: TNXSetupSession;
  lPlan: TNXSetupPlan;
begin
  lSession := OpenInstalled(AStateFile);
  lPlan := nil;
  try
    lPlan := lSession.BuildPlan;
    TNXSetupFileInstaller.Install(lSession.Document, lPlan, lSession.Root,
      lSession.Bundled.ArchiveFile, True);
  finally
    lPlan.Free;
    lSession.Free;
  end;
end;

end.

