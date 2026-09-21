# NexusTest UI

The NexusTest UI is the fpGUI presentation application for the reusable NexusTest framework.

It consumes:

- `NexusLib/packages/nxtest/src`
- `NexusLib/packages/gui/src`
- `NexusLib/packages/gui/external/fpgui`
- `NexusLib/packages/foundation/serialization/src`
- `NexusLib/packages/foundation/serialization/json/src`
- `NexusLib/packages/network/json-rpc/src`
- `NexusLib/core/src`

## Build

From the repository root:

```text
lazbuild nxnxtest/ui/src/NexusTestUI.lpi
```

The UI loads a NexusTest module and presents its suites, categories, and test results. The test protocol remains owned by `NexusLib/packages/nxtest`; fpGUI is only the presentation layer.
