#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses",
# as defined by the Mozilla Public License, v. 2.0.
#
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception

set -e
cd "$(dirname "$0")"
fpc -MObjFPC -Scgi -Fu../../packages/nxtest/src -Fu../../packages2/nexus-packages/serialization/src -Fu../../packages2/nexus-packages/serialization/json/src -Fu../../packages/network/json-rpc/src -Fu../../NexusLib/core/src ./host/test/sample/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fu../../packages/nxtest/src -Fu../../packages2/nexus-packages/serialization/src -Fu../../packages2/nexus-packages/serialization/json/src -Fu../../packages/network/json-rpc/src -Fu../../NexusLib/core/src ./host/src/nxtest_host.lpr
fpc -MObjFPC -Scgi -dX11 \
  -Fi../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/pascal/corelib \
  -Fi../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fi../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/resources \
  -Fu../../packages/nxtest/src \
  -Fu../../packages2/nexus-packages/serialization/src \
  -Fu../../packages2/nexus-packages/serialization/json/src \
  -Fu../../packages/network/json-rpc/src \
  -Fu../../NexusLib/core/src \
  -Fu../../packages2/nexus-packages/gui/src \
  -Fu../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/pascal/corelib \
  -Fu../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/pascal/corelib/render/software \
  -Fu../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/pascal/corelib/x11 \
  -Fu../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/pascal/gui \
  -Fu../../packages2/nexus-packages/gui/external/fpgui/framework/src/main/resources \
  ./ui/src/NexusTestUI.lpr
