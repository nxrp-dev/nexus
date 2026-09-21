#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
fpc -MObjFPC -Scgi -Fu../NexusLib/packages/nxtest/src -Fu../NexusLib/packages/foundation/serialization/src -Fu../NexusLib/packages/foundation/serialization/json/src -Fu../NexusLib/packages/network/json-rpc/src -Fu../NexusLib/core/src ./host/test/sample/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fu../NexusLib/packages/nxtest/src -Fu../NexusLib/packages/foundation/serialization/src -Fu../NexusLib/packages/foundation/serialization/json/src -Fu../NexusLib/packages/network/json-rpc/src -Fu../NexusLib/core/src ./host/src/nxtest_host.lpr
fpc -MObjFPC -Scgi -dX11 \
  -Fi../NexusLib/packages/gui/external/fpgui/framework/src/main/pascal/corelib \
  -Fi../NexusLib/packages/gui/external/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fi../NexusLib/packages/gui/external/fpgui/framework/src/main/resources \
  -Fu../NexusLib/packages/nxtest/src \
  -Fu../NexusLib/packages/foundation/serialization/src \
  -Fu../NexusLib/packages/foundation/serialization/json/src \
  -Fu../NexusLib/packages/network/json-rpc/src \
  -Fu../NexusLib/core/src \
  -Fu../NexusLib/packages/gui/src \
  -Fu../NexusLib/packages/gui/external/fpgui/framework/src/main/pascal/corelib \
  -Fu../NexusLib/packages/gui/external/fpgui/framework/src/main/pascal/corelib/render/software \
  -Fu../NexusLib/packages/gui/external/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fu../NexusLib/packages/gui/external/fpgui/framework/src/main/pascal/gui \
  -Fu../NexusLib/packages/gui/external/fpgui/framework/src/main/resources \
  ./ui/src/NexusTestUI.lpr
