#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
fpc -MObjFPC -Scgi -Fu./src ./sample/SampleTests/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fu./src ./sample/Host/nxtest_host.lpr
