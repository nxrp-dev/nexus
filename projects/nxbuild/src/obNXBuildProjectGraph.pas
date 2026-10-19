(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildProjectGraph;

{$mode objfpc}{$H+}

interface

uses Classes, Generics.Collections, obNXBuildDescription, obNXBuildDirectories;

type
  TNXBuildProjectNode = class
  private
    FDescription: TNXBuildDescription;
    FDependencies: specialize TList<TNXBuildProjectNode>;
    FDirectories: TNXBuildDirectories;
    FVisiting: Boolean;
    FResolved: Boolean;
  public
    constructor Create(ADescription: TNXBuildDescription);
    destructor Destroy; override;
    property Description: TNXBuildDescription read FDescription;
    property Dependencies: specialize TList<TNXBuildProjectNode> read FDependencies;
    property Directories: TNXBuildDirectories read FDirectories;
  end;

  TNXBuildProjectGraph = class
  private
    FDescriptions: specialize TObjectList<TNXBuildDescription>;
    FNodes: specialize TObjectList<TNXBuildProjectNode>;
    FOrder: specialize TList<TNXBuildProjectNode>;
    FStack: TStringList;
    function AddNode(ADescription: TNXBuildDescription): TNXBuildProjectNode;
    function FindNode(const AFileName: string): TNXBuildProjectNode;
    procedure Visit(ANode: TNXBuildProjectNode);
  public
    constructor Create(ARoot: TNXBuildDescription);
    destructor Destroy; override;
    property Order: specialize TList<TNXBuildProjectNode> read FOrder;
  end;

implementation

uses SysUtils, obNXBuildRequirement, obNXBuildDescriptionLoader;

constructor TNXBuildProjectNode.Create(ADescription: TNXBuildDescription);
begin
  inherited Create;
  FDescription := ADescription;
  FDependencies := specialize TList<TNXBuildProjectNode>.Create;
  FDirectories := TNXBuildDirectories.Create;
end;

destructor TNXBuildProjectNode.Destroy;
begin
  FDirectories.Free;
  FDependencies.Free;
  inherited Destroy;
end;

constructor TNXBuildProjectGraph.Create(ARoot: TNXBuildDescription);
begin
  inherited Create;
  FDescriptions := specialize TObjectList<TNXBuildDescription>.Create(True);
  FNodes := specialize TObjectList<TNXBuildProjectNode>.Create(True);
  FOrder := specialize TList<TNXBuildProjectNode>.Create;
  FStack := TStringList.Create;
  Visit(AddNode(ARoot));
end;

destructor TNXBuildProjectGraph.Destroy;
begin
  FStack.Free;
  FOrder.Free;
  FNodes.Free;
  FDescriptions.Free;
  inherited Destroy;
end;

function TNXBuildProjectGraph.AddNode(ADescription: TNXBuildDescription): TNXBuildProjectNode;
var
  lExisting: TNXBuildProjectNode;
begin
  for lExisting in FNodes do
    if lExisting.Description.Id = ADescription.Id then
      raise Exception.CreateFmt('Project identity "%s" has multiple descriptors: %s and %s.',
        [ADescription.Id, lExisting.Description.FileName, ADescription.FileName]);
  Result := TNXBuildProjectNode.Create(ADescription);
  FNodes.Add(Result);
end;

function TNXBuildProjectGraph.FindNode(const AFileName: string): TNXBuildProjectNode;
var
  lNode: TNXBuildProjectNode;
begin
  for lNode in FNodes do
    if SameFileName(lNode.Description.FileName, AFileName) then Exit(lNode);
  Result := nil;
end;

procedure TNXBuildProjectGraph.Visit(ANode: TNXBuildProjectNode);
var
  lRequirement: TNXBuildRequirement;
  lDependency: TNXBuildProjectNode;
  lDescription: TNXBuildDescription;
  lLoader: TNXBuildDescriptionLoader;
  lChain: string;
  lIndex: Integer;
begin
  if ANode.FVisiting then
  begin
    lChain := '';
    for lIndex := 0 to FStack.Count - 1 do
      lChain := lChain + FStack[lIndex] + ' -> ';
    raise Exception.Create('Project dependency cycle: ' + lChain + ANode.Description.Id);
  end;
  if ANode.FResolved then Exit;
  ANode.FVisiting := True;
  FStack.Add(ANode.Description.Id);
  try
    for lRequirement in ANode.Description.Requirements do
    begin
      lDependency := FindNode(lRequirement.Descriptor);
      if lDependency = nil then
      begin
        lLoader := TNXBuildDescriptionLoader.Create;
        try
          lDescription := lLoader.LoadDescription(lRequirement.Descriptor,
            ANode.Description.SelectedTargets);
        except
          on E: Exception do
          begin
            lLoader.Free;
            raise Exception.CreateFmt('%s: project "%s" requires "%s" (%s): %s',
              [lRequirement.Location, ANode.Description.Id, lRequirement.Id,
               lRequirement.Descriptor, E.Message]);
          end;
        end;
        lLoader.Free;
        FDescriptions.Add(lDescription);
        lDependency := AddNode(lDescription);
      end;
      if lDependency.Description.Id <> lRequirement.Id then
        raise Exception.CreateFmt('%s: requirement "%s" resolves to project "%s" in %s.',
          [lRequirement.Location, lRequirement.Id, lDependency.Description.Id,
           lRequirement.Descriptor]);
      ANode.Dependencies.Add(lDependency);
      Visit(lDependency);
    end;
    ANode.Directories.Include(ANode.Description.Publishes);
    for lDependency in ANode.Dependencies do
      ANode.Directories.Include(lDependency.Directories);
    ANode.FResolved := True;
    FOrder.Add(ANode);
  finally
    FStack.Delete(FStack.Count - 1);
    ANode.FVisiting := False;
  end;
end;

end.
