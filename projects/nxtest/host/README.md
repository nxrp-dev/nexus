# NexusTest Host

This product contains the command-line host and sample module used to exercise the NexusTest module boundary.

## Build

From the repository root:

```text
fpc -MObjFPC -Scgi -Fupackages/nexus-packages/nxtest/src -Fupackages/nexus-packages/serialization/src -Fupackages/nexus-packages/serialization/json/src -Fupackages/nexus-packages/network/json-rpc/src -Fupackages/nexus-packages/core/src projects/nxtest/host/test/sample/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fupackages/nexus-packages/nxtest/src -Fupackages/nexus-packages/serialization/src -Fupackages/nexus-packages/serialization/json/src -Fupackages/nexus-packages/network/json-rpc/src -Fupackages/nexus-packages/core/src projects/nxtest/host/src/nxtest_host.lpr
```

The host loads a test module dynamically and communicates through the exported `NXTest_*` C-style ABI.
