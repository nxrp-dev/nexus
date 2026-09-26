# NexusTest Host

This product contains the command-line host and sample module used to exercise the NexusTest module boundary.

## Build

From the repository root:

```text
fpc -MObjFPC -Scgi -Fupackages/nxtest/src -Fupackages/foundation/serialization/src -Fupackages/foundation/serialization/json/src -Fupackages/network/json-rpc/src -FuNexusLib/core/src nxnxtest/host/test/sample/nxtest_sampletests.lpr
fpc -MObjFPC -Scgi -Fupackages/nxtest/src -Fupackages/foundation/serialization/src -Fupackages/foundation/serialization/json/src -Fupackages/network/json-rpc/src -FuNexusLib/core/src nxnxtest/host/src/nxtest_host.lpr
```

The host loads a test module dynamically and communicates through the exported `NXTest_*` C-style ABI.
