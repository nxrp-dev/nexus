(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXPascalSkin;

{$mode objfpc}{$H+}

interface

uses obNXSkin;

type
  TNXPascalSkin = class(TNXSkin)
  public
    constructor Create; override;
  end;

implementation

uses obNXPanelRender, fpg_stylemanager;

constructor TNXPascalSkin.Create;
begin
  inherited Create;
  RegisterRenderer(cNXPanelFrame, TNXPanelFrameRenderer.Create(Colors));
end;

initialization
  fpgStyleManager.RegisterClass('NexusPascal', TNXPascalSkin);

end.
