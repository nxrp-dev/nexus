# fpGUI Conversion Workplan for NexusTools/Test

## Scope

This plan describes how to convert the legacy NexusUI-based test UI in `NexusTools/Test/NexusTestUI` away from the existing `obNX*` and `tpNX*` control layer and onto a `fpGUI` form/control model while preserving the test engine and JSON-RPC test client contract.

## Repository Evidence

The current UI file is:

- `NexusTools/Test/NexusTestUI/uiNXTestMain.pas`

That file currently depends on the NexusUI object model:

- `obNXApplication`
- `obNXButton`
- `obNXControl`
- `obNXEditBox`
- `obNXGroupBox`
- `obNXLabel`
- `obNXMemo`
- `obNXPanel`
- `obNXTreeView`
- `tpNXLayout`
- `tpNXPlatform`
- `tpNXWindow`

The test model and client glue in `NexusTools/Test/src` should remain as the backend contract. The goal is to replace only the display shell, not the system-under-test command plumbing.

## Goal State

A small `fpGUI` form should own the UI shell. The backend test client should remain responsible for:

- loading the sample module DLL/so,
- issuing JSON-RPC commands,
- creating test result value objects,
- updating the tree, details memo, and run state.

The UI should become a lightweight adapter over the test client, not a second test engine.

## Conversion Phases

### Phase 1 — Freeze the contract boundary

1. Keep the module export ABI stable:
   - `NXTest_Init`
   - `NXTest_Release`
   - `NXTest_ExecuteCommand`
   - `NXTest_ReadResult`
2. Keep the JSON-RPC request/response model stable.
3. Keep the current `TNXTestModuleClient` and value/result object graph stable.
4. Ensure all UI-specific branching is isolated from the model and test runner.

### Phase 2 — Create an fpGUI UI adapter layer

1. Introduce a UI-neutral controller boundary for the test UI.
2. Move the existing `TNXTestUIController` orchestration behind an adapter object that is independent of the underlying widget toolkit.
3. Convert the event model from the NexusUI callback shape:
   - `procedure(Sender: TObject; X, Y: Integer; Button: TNXMouseButton)`
   to the fpGUI-style event shape or equivalent `TNotifyEvent` flow.
4. Replace `Application.RootWindow` and `tpNXWindow` assumptions with a normal fpGUI form owner/application model.

### Phase 3 — Rewrite the widget tree

Convert the widget construction points in the UI builder layer:

- `TNXPanel` -> a suitable fpGUI panel/container widget
- `TNXButton` -> `fpGUI` button control
- `TNXLabel` -> `fpGUI` label
- `TNXEditBox` -> `fpGUI` edit text control
- `TNXMemo` -> `fpGUI` memo/log display
- `TNXGroupBox` -> `fpGUI` frame/group box
- `TNXTreeView` -> `fpGUI` tree/list widget

The event wiring should be rebuilt so that the controller receives test load, refresh, run-all, run-selected, and node-selection events through the new form/control graph.

### Phase 4 — Replace the widget layout algorithm

The old UI currently builds a panel/button row and then a full test tree/detail layout. That sequence should be re-expressed in `fpGUI` terms:

1. Create a top-level `TForm`.
2. Add a button strip or panel for browse/load/refresh/run-all/run-selected.
3. Add a module path edit box and browse button.
4. Add a details group box and memo for the selected test case.
5. Add the tree/list allocation for suite/category/test results.
6. Connect `TreeChange`/selection events to the details panel refresh path.

### Phase 5 — Drop the NexusUI unit dependency

The UI code should stop importing the `obNX*` and `tpNX*` units. The LPI/project file and unit list in the test UI directory should be rewritten to import the fpGUI replacement classes. Then the workspace should be recompiled to verify the dependency map is no longer anchored in the old control layer.

### Phase 6 — Verify behavior preservation

After the UI shell is ported:

1. Load module path browsing should still work.
2. Catalog tree expansion should still reflect suites, categories, and test cases.
3. Refresh/load and run buttons should still issue the same JSON-RPC command semantics.
4. Result details should still surface the existing `TNXTestResultValue`/array payload shape.
5. The sample host and test module import path should remain unchanged.

## Implementation Order

1. Audit the test UI references in `uiNXTestMain.pas` and identify all `obNX*` and `tpNX*` constructors and typed event signatures.
2. Create a thin adapter layer that exposes stable UI operations to the existing controller methods.
3. Rewrite the widget composition code using `fpGUI` form and control classes.
4. Replace the tree-node bookkeeping and selection callbacks with the fpGUI event model.
5. Rebuild the test UI project with the new dependency list.
6. Verify no change to the module JSON-RPC contract or test engine semantics.

## Risks and Guardrails

- Do not rewrite the test registry, assertions, result store, runner, or JSON-RPC transport in the same pass.
- Do not collapse the `TNXTestUIController` into a monolithic fpGUI object; keep it behaviorally similar but toolkit-neutral.
- Do not rely on the old NexusUI mouse coordinate or button event tuple shape.
- Do not try to fully redesign the UI; first make the UI shell match the test harness contract while reducing the repository dependency on NexusUI.

## Success Criteria

The conversion is complete when:

- the `NexusTools/Test/NexusTestUI` project no longer imports the NexusUI units,
- the UI can build with fpGUI,
- the existing module command contract remains unchanged,
- the test tree, browse path, details pane, and run controls continue to operate through the same backend client abstraction.
