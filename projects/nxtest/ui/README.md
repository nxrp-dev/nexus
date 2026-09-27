# NexusTest UI

The NexusTest UI is the fpGUI presentation application for the reusable NexusTest framework.

It consumes:

- `packages/nxtest/src`
- `packages/gui/src`
- `packages/gui/external/fpgui`
- `packages/foundation/serialization/src`
- `packages/foundation/serialization/json/src`
- `packages/network/json-rpc/src`
- `NexusLib/core/src`

## Build

From the repository root:

```text
lazbuild projects/nxtest/ui/src/NexusTestUI.lpi
```

The UI loads a NexusTest module and presents its suites, categories, and test results. The test protocol remains owned by `packages/nxtest`; fpGUI is only the presentation layer.
