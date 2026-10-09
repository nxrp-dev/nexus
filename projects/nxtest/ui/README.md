# NexusTest UI

The NexusTest UI is the fpGUI presentation application for the reusable NexusTest framework.

It consumes:

- `packages/nexus-packages/nxtest/src`
- `packages/nexus-packages/gui/src`
- `packages/nexus-packages/gui/external/fpgui`
- `packages/nexus-packages/serialization/src`
- `packages/nexus-packages/serialization/json/src`
- `packages/nexus-packages/network/json-rpc/src`
- `packages/nexus-packages/core/src`

## Build

From the repository root:

```text
lazbuild projects/nxtest/ui/src/NexusTestUI.lpi
```

The UI loads a NexusTest module and presents its suites, categories, and test results. The test protocol remains owned by `packages/nexus-packages/nxtest`; fpGUI is only the presentation layer.
