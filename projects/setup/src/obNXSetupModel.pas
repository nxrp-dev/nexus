(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupModel;

{$mode delphi}{$H+}

interface

uses Classes, SysUtils, Generics.Collections, tpNXSetup, obNexusScriptLive,
  obNXSetupSourceContext;

type
  ENXSetup = class(Exception);
  TNXSetupFeature = class;
  TNXSetupLocation = class;
  TNXSetupDependency = class;

  TNXSetupNode = class
  private
    FDeclaration: TNexusScriptLiveDefinition;
  public
    constructor Create(ADeclaration: TNexusScriptLiveDefinition);
    property Declaration: TNexusScriptLiveDefinition read FDeclaration;
  end;

  TNXSetupProduct = class(TNXSetupNode)
  private
    FId, FName, FVersion, FPublisher, FCopyright: string;
    FIcon, FImage, FLicense, FDescription, FWebsite, FSupport, FUpdates: string;
    FChildMode: TNXSetupChildMode;
  public
    property Id: string read FId;
    property Name: string read FName;
    property Version: string read FVersion;
    property Publisher: string read FPublisher;
    property Copyright: string read FCopyright;
    property Icon: string read FIcon;
    property Image: string read FImage;
    property License: string read FLicense;
    property Description: string read FDescription;
    property Website: string read FWebsite;
    property Support: string read FSupport;
    property Updates: string read FUpdates;
    property ChildMode: TNXSetupChildMode read FChildMode;
  end;

  TNXSetupLocation = class(TNXSetupNode)
  private
    FKind, FPath: string;
    FBase: TNXSetupLocation;
  public
    property Kind: string read FKind;
    property Path: string read FPath;
    property Base: TNXSetupLocation read FBase;
  end;

  TNXSetupPayload = class(TNXSetupNode)
  private
    FKind: TNXSetupPayloadKind;
    FSource, FPath: string;
    FLocation: TNXSetupLocation;
    FPreserveExisting, FKeepOnUninstall, FIgnoreVersion: Boolean;
  public
    property Kind: TNXSetupPayloadKind read FKind;
    property Source: string read FSource;
    property Path: string read FPath;
    property Location: TNXSetupLocation read FLocation;
    property PreserveExisting: Boolean read FPreserveExisting;
    property KeepOnUninstall: Boolean read FKeepOnUninstall;
    property IgnoreVersion: Boolean read FIgnoreVersion;
  end;

  TNXSetupShortcut = class(TNXSetupNode)
  private
    FName, FPath: string;
    FLocation, FTarget: TNXSetupLocation;
  public
    property Name: string read FName;
    property Path: string read FPath;
    property Location: TNXSetupLocation read FLocation;
    property Target: TNXSetupLocation read FTarget;
  end;

  TNXSetupDependency = class(TNXSetupNode)
  private
    FRequires: TList<TNXSetupDependency>;
    FOwnership: TNXSetupOwnership;
    FAcquisition: TNXSetupAcquisition;
    FInstaller: TNXSetupInstaller;
  public
    constructor Create(ADeclaration: TNexusScriptLiveDefinition);
    destructor Destroy; override;
    property Requires: TList<TNXSetupDependency> read FRequires;
    property Ownership: TNXSetupOwnership read FOwnership;
    property Acquisition: TNXSetupAcquisition read FAcquisition;
    property Installer: TNXSetupInstaller read FInstaller;
  end;

  TNXSetupFeature = class(TNXSetupNode)
  private
    FName: string;
    FRequired, FDefault: Boolean;
    FChildMode: TNXSetupChildMode;
    FParent: TNXSetupFeature;
    FChildren, FRequires: TList<TNXSetupFeature>;
    FDependencies: TList<TNXSetupDependency>;
    FFiles: TObjectList<TNXSetupPayload>;
    FShortcuts: TObjectList<TNXSetupShortcut>;
  public
    constructor Create(ADeclaration: TNexusScriptLiveDefinition);
    destructor Destroy; override;
    property Name: string read FName;
    property Required: Boolean read FRequired;
    property Default: Boolean read FDefault;
    property ChildMode: TNXSetupChildMode read FChildMode;
    property Parent: TNXSetupFeature read FParent;
    property Children: TList<TNXSetupFeature> read FChildren;
    property Requires: TList<TNXSetupFeature> read FRequires;
    property Dependencies: TList<TNXSetupDependency> read FDependencies;
    property Files: TObjectList<TNXSetupPayload> read FFiles;
    property Shortcuts: TObjectList<TNXSetupShortcut> read FShortcuts;
  end;

  { Owns the declarations and their provenance. All inter-entity links borrow. }
  TNXSetupDocument = class
  private
    FLive: TNexusScriptLiveDocument;
    FProduct: TNXSetupProduct;
    FFeatures: TObjectList<TNXSetupFeature>;
    FRoots: TList<TNXSetupFeature>;
    FLocations: TObjectList<TNXSetupLocation>;
    FDependencies: TObjectList<TNXSetupDependency>;
    FSourceContext: TNXSetupSourceContext;
  public
    constructor Create;
    destructor Destroy; override;
    function FindFeature(const AName: string): TNXSetupFeature;
    property Product: TNXSetupProduct read FProduct;
    property Features: TObjectList<TNXSetupFeature> read FFeatures;
    property Roots: TList<TNXSetupFeature> read FRoots;
    property Locations: TObjectList<TNXSetupLocation> read FLocations;
    property Dependencies: TObjectList<TNXSetupDependency> read FDependencies;
    property SourceContext: TNXSetupSourceContext read FSourceContext;
    property Live: TNexusScriptLiveDocument read FLive;
  end;

  { Builds the declared model from Live; no compiler bookkeeping or JSON. }
  TNXSetupModelBuilder = class
  public
    class function Build(ALive: TNexusScriptLiveDocument;
      AContext: TNXSetupSourceContext = nil): TNXSetupDocument; static;
  end;

implementation

uses tpNexusScriptLive;

function Text(ADefinition: TNexusScriptLiveDefinition; const AName: string): string;
var
  lProperty: TNexusScriptLiveProperty;
begin
  lProperty := ADefinition.FindProperty(AName);
  Result := '';
  if lProperty <> nil then Result := lProperty.Value.AsText;
end;

function ReadChildMode(ADefinition: TNexusScriptLiveDefinition): TNXSetupChildMode;
var
  lText: string;
begin
  Result := scmIndependent;
  lText := Text(ADefinition, 'ChildMode');
  if SameText(lText, 'Exclusive') then Result := scmExclusive
  else if (lText <> '') and not SameText(lText, 'Independent') then
    raise ENXSetup.Create('Invalid child selection mode: ' + lText);
end;

function ReadBoolean(ADefinition: TNexusScriptLiveDefinition; const AName: string): Boolean;
var
  lText: string;
begin
  lText := Text(ADefinition, AName);
  Result := SameText(lText, 'True');
  if not Result and (lText <> '') and not SameText(lText, 'False') then
    raise ENXSetup.Create('Invalid boolean ' + AName + ': ' + lText);
end;

function Target(ADefinition: TNexusScriptLiveDefinition;
  const AName: string): TNexusScriptLiveDefinition;
var
  lProperty: TNexusScriptLiveProperty;
begin
  Result := nil;
  lProperty := ADefinition.FindProperty(AName);
  if lProperty <> nil then Result := lProperty.Value.AsDefinition;
end;

constructor TNXSetupNode.Create(ADeclaration: TNexusScriptLiveDefinition);
begin
  inherited Create;
  FDeclaration := ADeclaration;
end;

constructor TNXSetupFeature.Create(ADeclaration: TNexusScriptLiveDefinition);
begin
  inherited Create(ADeclaration);
  FChildren := TList<TNXSetupFeature>.Create;
  FRequires := TList<TNXSetupFeature>.Create;
  FDependencies := TList<TNXSetupDependency>.Create;
  FFiles := TObjectList<TNXSetupPayload>.Create(True);
  FShortcuts := TObjectList<TNXSetupShortcut>.Create(True);
end;

destructor TNXSetupFeature.Destroy;
begin
  FShortcuts.Free;
  FFiles.Free;
  FDependencies.Free;
  FRequires.Free;
  FChildren.Free;
  inherited Destroy;
end;

constructor TNXSetupDependency.Create(ADeclaration: TNexusScriptLiveDefinition);
begin
  inherited Create(ADeclaration);
  FRequires := TList<TNXSetupDependency>.Create;
end;

destructor TNXSetupDependency.Destroy;
begin
  FRequires.Free;
  inherited Destroy;
end;

constructor TNXSetupDocument.Create;
begin
  inherited Create;
  FFeatures := TObjectList<TNXSetupFeature>.Create(True);
  FRoots := TList<TNXSetupFeature>.Create;
  FLocations := TObjectList<TNXSetupLocation>.Create(True);
  FDependencies := TObjectList<TNXSetupDependency>.Create(True);
end;

destructor TNXSetupDocument.Destroy;
begin
  FSourceContext.Free;
  FFeatures.Free;
  FRoots.Free;
  FLocations.Free;
  FDependencies.Free;
  FProduct.Free;
  FLive.Free;
  inherited Destroy;
end;

function TNXSetupDocument.FindFeature(const AName: string): TNXSetupFeature;
var
  lFeature: TNXSetupFeature;
begin
  Result := nil;
  for lFeature in FFeatures do
    if SameText(lFeature.Declaration.Name, AName) then
    begin
      if Result <> nil then raise ENXSetup.Create('Ambiguous feature name: ' + AName);
      Result := lFeature;
    end;
end;

type
  TNXSetupBuilder = class
  private
    FDocument: TNXSetupDocument;
    FFeatures: TDictionary<TNexusScriptLiveDefinition, TNXSetupFeature>;
    FLocations: TDictionary<TNexusScriptLiveDefinition, TNXSetupLocation>;
    FDependencies: TDictionary<TNexusScriptLiveDefinition, TNXSetupDependency>;
    procedure ReadProduct(ASource: TNexusScriptLiveDocument);
    procedure AllocateEntities(ASource: TNexusScriptLiveDocument);
    procedure WireFeatures;
    procedure WireLocations;
    procedure WireDependencies;
  public
    constructor Create(ADocument: TNXSetupDocument);
    destructor Destroy; override;
    procedure Build(ASource: TNexusScriptLiveDocument);
  end;

constructor TNXSetupBuilder.Create(ADocument: TNXSetupDocument);
begin
  inherited Create;
  FDocument := ADocument;
  FFeatures := TDictionary<TNexusScriptLiveDefinition, TNXSetupFeature>.Create;
  FLocations := TDictionary<TNexusScriptLiveDefinition, TNXSetupLocation>.Create;
  FDependencies := TDictionary<TNexusScriptLiveDefinition, TNXSetupDependency>.Create;
end;

destructor TNXSetupBuilder.Destroy;
begin
  FDependencies.Free;
  FLocations.Free;
  FFeatures.Free;
  inherited Destroy;
end;

procedure TNXSetupBuilder.ReadProduct(ASource: TNexusScriptLiveDocument);
var
  lDefinition: TNexusScriptLiveDefinition;
begin
  for lDefinition in ASource.Roots do
    if SameText(lDefinition.Kind, 'Product') then
    begin
      if FDocument.FProduct <> nil then raise ENXSetup.Create('Setup requires one product.');
      FDocument.FProduct := TNXSetupProduct.Create(lDefinition);
    end;
  if FDocument.FProduct = nil then raise ENXSetup.Create('Setup requires a product.');
  lDefinition := FDocument.FProduct.Declaration;
  with FDocument.FProduct do
  begin
    FId := Text(lDefinition, 'Id'); FName := Text(lDefinition, 'Name');
    FVersion := Text(lDefinition, 'Version'); FPublisher := Text(lDefinition, 'Publisher');
    FCopyright := Text(lDefinition, 'Copyright'); FIcon := Text(lDefinition, 'Icon');
    FImage := Text(lDefinition, 'Image'); FLicense := Text(lDefinition, 'License');
    FDescription := Text(lDefinition, 'Description'); FWebsite := Text(lDefinition, 'Website');
    FSupport := Text(lDefinition, 'Support'); FUpdates := Text(lDefinition, 'Updates');
    FChildMode := ReadChildMode(lDefinition);
  end;
  if Trim(FDocument.Product.Id) = '' then raise ENXSetup.Create('Product identity is empty.');
end;

procedure TNXSetupBuilder.AllocateEntities(ASource: TNexusScriptLiveDocument);
var
  lDefinition: TNexusScriptLiveDefinition;
  lFeature: TNXSetupFeature;
  lLocation: TNXSetupLocation;
  lDependency: TNXSetupDependency;
begin
  { Register every entity before wiring a possible back-edge. }
  for lDefinition in ASource.Definitions do
    if SameText(lDefinition.Kind, 'Feature') then
    begin
      lFeature := TNXSetupFeature.Create(lDefinition);
      FDocument.FFeatures.Add(lFeature);
      FFeatures.Add(lDefinition, lFeature);
      lFeature.FName := Text(lDefinition, 'Name');
      if lFeature.FName = '' then lFeature.FName := lDefinition.Name;
      lFeature.FRequired := ReadBoolean(lDefinition, 'Required');
      lFeature.FDefault := ReadBoolean(lDefinition, 'Default');
      lFeature.FChildMode := ReadChildMode(lDefinition);
    end
    else if SameText(lDefinition.Kind, 'Location') then
    begin
      lLocation := TNXSetupLocation.Create(lDefinition);
      FDocument.FLocations.Add(lLocation);
      FLocations.Add(lDefinition, lLocation);
      lLocation.FKind := Text(lDefinition, 'Kind');
      lLocation.FPath := Text(lDefinition, 'Path');
    end
    else if SameText(lDefinition.Kind, 'Dependency') then
    begin
      lDependency := TNXSetupDependency.Create(lDefinition);
      FDocument.FDependencies.Add(lDependency);
      FDependencies.Add(lDefinition, lDependency);
      if SameText(Text(lDefinition, 'Ownership'), 'Owned') then
        lDependency.FOwnership := soOwned
      else if not SameText(Text(lDefinition, 'Ownership'), 'Shared') then
        raise ENXSetup.Create('Dependency ownership must be Owned or Shared: ' + lDefinition.Name);
    end;
end;

procedure TNXSetupBuilder.WireFeatures;
var
  lDefinition, lChild, lTarget: TNexusScriptLiveDefinition;
  lFeature: TNXSetupFeature;
  lFile: TNXSetupPayload;
  lShortcut: TNXSetupShortcut;
  lProperty: TNexusScriptLiveProperty;
  lItem: TNexusScriptLiveValue;
begin
  for lFeature in FDocument.Features do
  begin
    lDefinition := lFeature.Declaration;
    if lDefinition.Parent = FDocument.Product.Declaration then FDocument.FRoots.Add(lFeature)
    else if FFeatures.TryGetValue(lDefinition.Parent, lFeature.FParent) then
      lFeature.FParent.FChildren.Add(lFeature);
    lProperty := lDefinition.FindProperty('Requires');
    if lProperty <> nil then
      for lItem in lProperty.Value.Items do
      begin
        lTarget := lItem.AsDefinition;
        if FFeatures.ContainsKey(lTarget) then lFeature.FRequires.Add(FFeatures[lTarget])
        else if FDependencies.ContainsKey(lTarget) then lFeature.FDependencies.Add(FDependencies[lTarget])
        else raise ENXSetup.Create('Feature requirement is not a feature or dependency.');
      end;
    for lChild in lDefinition.Children do
      if SameText(lChild.Kind, 'File') or SameText(lChild.Kind, 'Directory') then
      begin
        lFile := TNXSetupPayload.Create(lChild);
        lFeature.FFiles.Add(lFile);
        if SameText(lChild.Kind, 'Directory') then lFile.FKind := spkDirectory;
        lFile.FSource := Text(lChild, 'Source'); lFile.FPath := Text(lChild, 'Path');
        lFile.FLocation := FLocations[Target(lChild, 'Location')];
        lFile.FPreserveExisting := ReadBoolean(lChild, 'PreserveExisting');
        lFile.FKeepOnUninstall := ReadBoolean(lChild, 'KeepOnUninstall');
        lFile.FIgnoreVersion := ReadBoolean(lChild, 'IgnoreVersion');
      end
      else if SameText(lChild.Kind, 'Shortcut') then
      begin
        lShortcut := TNXSetupShortcut.Create(lChild);
        lFeature.FShortcuts.Add(lShortcut);
        lShortcut.FName := Text(lChild, 'Name');
        lShortcut.FPath := Text(lChild, 'Path');
        lShortcut.FLocation := FLocations[Target(lChild, 'Location')];
        lShortcut.FTarget := FLocations[Target(lChild, 'Target')];
      end;
  end;
end;

procedure TNXSetupBuilder.WireLocations;
var
  lLocation: TNXSetupLocation;
  lTarget: TNexusScriptLiveDefinition;
begin
  for lLocation in FDocument.Locations do
  begin
    lTarget := Target(lLocation.Declaration, 'Base');
    if lTarget <> nil then lLocation.FBase := FLocations[lTarget];
    if SameText(lLocation.Kind, 'Derived') and (lLocation.Base = nil) then
      raise ENXSetup.Create('Derived location requires a base: ' + lLocation.Declaration.Name);
  end;
end;

procedure TNXSetupBuilder.WireDependencies;
var
  lDependency: TNXSetupDependency;
  lDefinition, lChild: TNexusScriptLiveDefinition;
  lProperty: TNexusScriptLiveProperty;
  lItem: TNexusScriptLiveValue;
begin
  for lDependency in FDocument.Dependencies do
  begin
    lDefinition := lDependency.Declaration;
    lProperty := lDefinition.FindProperty('Requires');
    if lProperty <> nil then
      for lItem in lProperty.Value.Items do lDependency.FRequires.Add(FDependencies[lItem.AsDefinition]);
    for lChild in lDefinition.Children do
      if SameText(lChild.Kind, 'Payload') or SameText(lChild.Kind, 'Web') then
      begin
        if lDependency.FAcquisition.Kind <> sakNone then
          raise ENXSetup.Create('Dependency has multiple acquisition declarations.');
        lDependency.FAcquisition.Kind := sakPayload;
        if SameText(lChild.Kind, 'Web') then lDependency.FAcquisition.Kind := sakWeb;
        lDependency.FAcquisition.Source := Text(lChild, 'Source');
      end
      else
      begin
        if lDependency.FInstaller.Kind <> sikNone then
          raise ENXSetup.Create('Dependency has multiple installer declarations.');
        if SameText(lChild.Kind, 'Exe') then lDependency.FInstaller.Kind := sikExe
        else if SameText(lChild.Kind, 'MSI') then lDependency.FInstaller.Kind := sikMSI
        else if SameText(lChild.Kind, 'VSIX') then lDependency.FInstaller.Kind := sikVSIX
        else raise ENXSetup.Create('Unsupported dependency child: ' + lChild.Kind);
      end;
  end;
end;

procedure TNXSetupBuilder.Build(ASource: TNexusScriptLiveDocument);
begin
  ReadProduct(ASource);
  AllocateEntities(ASource);
  WireFeatures;
  WireLocations;
  WireDependencies;
end;

class function TNXSetupModelBuilder.Build(ALive: TNexusScriptLiveDocument;
  AContext: TNXSetupSourceContext): TNXSetupDocument;
var
  lDocument: TNXSetupDocument;
  lBuilder: TNXSetupBuilder;
begin
  { Both inputs stay caller-owned on failure; success transfers ownership. }
  lDocument := TNXSetupDocument.Create;
  lBuilder := nil;
  try
    try
      lBuilder := TNXSetupBuilder.Create(lDocument);
      lBuilder.Build(ALive);
      lDocument.FLive := ALive;
      lDocument.FSourceContext := AContext;
      Result := lDocument;
    except
      lDocument.Free;
      raise;
    end;
  finally
    lBuilder.Free;
  end;
end;

end.
