(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

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
