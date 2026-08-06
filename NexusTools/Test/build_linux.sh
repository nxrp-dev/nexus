#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
fpc -MObjFPC -Scgi -Fu./src -Fu../../NexusLib/core/src ./sample/SampleTests/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fu./src -Fu../../NexusLib/core/src ./sample/Host/nxtest_host.lpr
