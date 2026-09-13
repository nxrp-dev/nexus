#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
fpc -MObjFPC -Scgi -Fu./src -Fu../../NexusLib/core/src ./sample/SampleTests/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fu./src -Fu../../NexusLib/core/src ./sample/Host/nxtest_host.lpr
fpc -MObjFPC -Scgi -dX11 \
  -Fi../../lib/fpgui/framework/src/main/pascal/corelib \
  -Fi../../lib/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fi../../lib/fpgui/framework/src/main/resources \
  -Fu./src \
  -Fu../../NexusLib/core/src \
  -Fu../../NexusLib/ui/src \
  -Fu../../lib/fpgui/framework/src/main/pascal/corelib \
  -Fu../../lib/fpgui/framework/src/main/pascal/corelib/render/software \
  -Fu../../lib/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fu../../lib/fpgui/framework/src/main/pascal/gui \
  -Fu../../lib/fpgui/framework/src/main/resources \
  ./NexusTestUI/NexusTestUI.lpr
