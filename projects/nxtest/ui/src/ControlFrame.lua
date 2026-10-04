--[[
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
]]

function drawControlFrame(canvas, x, y, width, height, frameColor)
    canvas:Color(frameColor)
    canvas:Rectangle(x, y, width, height)

    if width > 3 and height > 3 then
        canvas:Color(0xFF3DAEE9)
        canvas:Line(x + 1, y + 1, x + 1, y + height - 2)
    end
end
