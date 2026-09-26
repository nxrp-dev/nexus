#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
fpc -MObjFPC -Scgi -Fu../packages/nxtest/src -Fu../packages/foundation/serialization/src -Fu../packages/foundation/serialization/json/src -Fu../packages/network/json-rpc/src -Fu../NexusLib/core/src ./host/test/sample/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fu../packages/nxtest/src -Fu../packages/foundation/serialization/src -Fu../packages/foundation/serialization/json/src -Fu../packages/network/json-rpc/src -Fu../NexusLib/core/src ./host/src/nxtest_host.lpr
fpc -MObjFPC -Scgi -dX11 \
  -Fi../packages/gui/external/fpgui/framework/src/main/pascal/corelib \
  -Fi../packages/gui/external/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fi../packages/gui/external/fpgui/framework/src/main/resources \
  -Fu../packages/nxtest/src \
  -Fu../packages/foundation/serialization/src \
  -Fu../packages/foundation/serialization/json/src \
  -Fu../packages/network/json-rpc/src \
  -Fu../NexusLib/core/src \
  -Fu../packages/gui/src \
  -Fu../packages/gui/external/fpgui/framework/src/main/pascal/corelib \
  -Fu../packages/gui/external/fpgui/framework/src/main/pascal/corelib/render/software \
  -Fu../packages/gui/external/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fu../packages/gui/external/fpgui/framework/src/main/pascal/gui \
  -Fu../packages/gui/external/fpgui/framework/src/main/resources \
  ./ui/src/NexusTestUI.lpr
