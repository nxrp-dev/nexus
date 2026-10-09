(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPackageStructure;

{$mode objfpc}{$H+}

interface

uses
  Classes, obNXVirtualTreeView, obVTVTree, tpVTV, obNexusScriptModel;

type
  TNXPackageStructure = class(TNXVirtualTreeView)
  protected
    function AddCaption(AParent: PVirtualNode; const ACaption: string): PVirtualNode;
    procedure AddDefinition(AParent: PVirtualNode;
      ADefinition: TNexusScriptCompiledDefinition);
    procedure AddValue(AParent: PVirtualNode;
      AValue: TNexusScriptCompiledValue; const AName: string);
    procedure GetCaption(ASender: TfpgVirtualStringTree; ANode: PVirtualNode;
      AColumn: TColumnIndex; var AText: string);
    procedure FreeCaption(ASender: TfpgVirtualStringTree; ANode: PVirtualNode);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadDocument(ADocument: TNexusScriptCompiledDocument);
  end;

implementation

uses
  SysUtils, tpNexusScript;

type
  PStructureNodeData = ^TStructureNodeData;
  TStructureNodeData = record
    Caption: string;
  end;

constructor TNXPackageStructure.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  NodeDataSize := SizeOf(TStructureNodeData);
  OnGetText := @GetCaption;
  OnFreeNode := @FreeCaption;
  TreeOptions.PaintOptions := TreeOptions.PaintOptions +
    [toShowHorzGridLines, toShowVertGridLines];
end;

function TNXPackageStructure.AddCaption(AParent: PVirtualNode;
  const ACaption: string): PVirtualNode;
begin
  Result := AddChild(AParent);
  PStructureNodeData(GetNodeData(Result))^.Caption := ACaption;
end;

procedure TNXPackageStructure.GetCaption(ASender: TfpgVirtualStringTree;
  ANode: PVirtualNode; AColumn: TColumnIndex; var AText: string);
begin
  AText := PStructureNodeData(ASender.GetNodeData(ANode))^.Caption;
end;

procedure TNXPackageStructure.FreeCaption(ASender: TfpgVirtualStringTree;
  ANode: PVirtualNode);
begin
  Finalize(PStructureNodeData(ASender.GetNodeData(ANode))^);
end;

procedure TNXPackageStructure.AddValue(AParent: PVirtualNode;
  AValue: TNexusScriptCompiledValue; const AName: string);
var
  lChild: PVirtualNode;
  lIndex: Integer;
  lText: string;
begin
  lText := AName;
  if AValue.HasEffectiveText then lText := lText + ': ' + AValue.EffectiveText;
  lChild := AddCaption(AParent, lText);
  if AValue.Kind = nsvArray then
    for lIndex := 0 to AValue.Items.Count - 1 do
      AddValue(lChild, AValue.Items[lIndex], '[' + IntToStr(lIndex) + ']');
end;

procedure TNXPackageStructure.AddDefinition(AParent: PVirtualNode;
  ADefinition: TNexusScriptCompiledDefinition);
var
  lChild: TNexusScriptCompiledDefinition;
  lNode: PVirtualNode;
  lProperty: TNexusScriptCompiledProperty;
begin
  lNode := AddCaption(AParent, ADefinition.Kind + ' ' + ADefinition.Name);
  for lProperty in ADefinition.Properties do
    AddValue(lNode, lProperty.Value, lProperty.Name);
  for lChild in ADefinition.Children do AddDefinition(lNode, lChild);
end;

procedure TNXPackageStructure.LoadDocument(
  ADocument: TNexusScriptCompiledDocument);
var
  lDefinition: TNexusScriptCompiledDefinition;
begin
  BeginUpdate;
  try
    Clear;
    if ADocument = nil then Exit;
    for lDefinition in ADocument.Definitions do AddDefinition(nil, lDefinition);
    FullExpand;
  finally
    EndUpdate;
  end;
end;

end.
