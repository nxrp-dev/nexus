# NexusTest Host

This product contains the command-line host and sample module used to exercise the NexusTest module boundary.

## Build

From the repository root:

```text
fpc -MObjFPC -Scgi -FuNexusLib/packages/nxtest/src -FuNexusLib/packages/foundation/serialization/src -FuNexusLib/packages/foundation/serialization/json/src -FuNexusLib/packages/network/json-rpc/src -FuNexusLib/core/src nxnxtest/host/test/sample/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -FuNexusLib/packages/nxtest/src -FuNexusLib/packages/foundation/serialization/src -FuNexusLib/packages/foundation/serialization/json/src -FuNexusLib/packages/network/json-rpc/src -FuNexusLib/core/src nxnxtest/host/src/nxtest_host.lpr
```

The host loads a test module dynamically and communicates through the exported `NXTest_*` C-style ABI.
