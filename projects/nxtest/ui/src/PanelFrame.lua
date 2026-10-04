--[[
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
]]

function drawPanelFrame(canvas, state, colors)
  if state.Style == 'bsFlat' then return end

  local x, y, w, h = state.Left, state.Top, state.Width, state.Height
  local single = state.BorderStyle == 'bsSingle'
  local width = single and 1 or 2
  local raised = state.Style == 'bsRaised'
  canvas:Color(raised and colors.Highlight or colors.Shadow)
  canvas:LineWidth(width)
  if single then
    canvas:Line(x, y, x + w - 1, y)
    canvas:Line(x, y + 1, x, y + h - 1)
  else
    canvas:Line(x, y + 1, x + w - 1, y + 1)
    canvas:Line(x + 1, y + 1, x + 1, y + h - 1)
  end
  canvas:Color(raised and colors.Shadow or colors.Highlight)
  canvas:LineWidth(width)
  canvas:Line(x + w - 1, y, x + w - 1, y + h - 1)
  canvas:Line(x, y + h - 1, x + w, y + h - 1)
end
