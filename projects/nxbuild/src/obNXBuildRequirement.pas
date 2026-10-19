(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXBuildRequirement;

{$mode objfpc}{$H+}

interface

type
  TNXBuildRequirement = class
  private
    FId: string;
    FDescriptor: string;
    FLocation: string;
  public
    constructor Create(const AId, ADescriptor, ALocation: string);
    property Id: string read FId;
    property Descriptor: string read FDescriptor;
    property Location: string read FLocation;
  end;

implementation

constructor TNXBuildRequirement.Create(const AId, ADescriptor, ALocation: string);
begin
  inherited Create;
  FId := AId;
  FDescriptor := ADescriptor;
  FLocation := ALocation;
end;

end.
