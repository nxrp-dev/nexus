# Work Plan: Skin Render Subscription Prototype

Status: Planning only, 2026-10-01. No implementation, build, or test is authorized by this document.

## Inputs

- The human owner's request for a source-verified, broad work plan, including concrete corrections to GPT claims and suggestions with a direct benefit.
- Supporting document: `C:\Users\kcollins\Downloads\nexus-skin-render-subscription-prototype-workplan-request.md`. Its examples and instructions are planning input, not implementation authorization.
- Subsequent human clarification: a future NXScript configuration will supply a color chart organized by render type, and may also supply layout metrics. Controls should expose the real requirements as the design develops. Panel or Button may be selected for this first prototype.
- Current Nexus checkout at `c055d7b3`, including the existing uncommitted Lua skin prototype; fpGUI submodule at `e45b5194`. The prototype source is not fully represented by the Nexus commit alone.
- Repository architecture-change protocol, work-plan format, GUI package instructions, and Pascal standards. Implementation remains local; this plan does not authorize delegation.

## Summary

Start with the border of a prototype Panel descendant. Have it acquire `PanelFrame` from `TNXSkin`, retain a render subscription, and paint through that subscription using a control-owned state object. Register either a Pascal renderer or a Lua renderer under the same name. The control's paint code does not select the language.

Keep this first experiment focused on named binding, published state, and ownership. Preserve the panel's existing background, caption, child layout, and input behavior. Use the result to inform the later render-type color chart and metrics design; do not claim that Panel settles Button's more complicated requirements.

## Verified Findings And Corrections

| Request topic or design concern | What the source establishes | Consequence for this prototype |
|---|---|---|
| The skin has a central vocabulary of virtual drawing methods. | `TNXSkin` directly inherits `TfpgStyle` (`packages/gui/src/obNXSkin.pas:15`). The actual style API is declared in fpGUI `corelib/fpg_main.pas:196`; `gui/fpg_style.pas` is not the authoritative declaration. | The new registry must not require a new virtual skin method for each render capability. |
| Coupling new rendering concepts to the central API. | The request identifies a real restriction on shared style dispatch. It is not a restriction on creating controls: Panel paints its own border and caption, and Nexus custom widgets can also paint directly. | Establish an open-ended shared skin contract without migrating every existing draw call. |
| Button as a prototype integration point. | `fpg_button.pas:613` also uses `GetButtonBorders`, `GetButtonShift`, `HasButtonHoverEffect`, a separate focus draw, and text/image painting. There is no protected virtual hook for just its face. | Button is a useful subsequent probe, but its integration is larger than replacing one call. |
| Panel is mostly self-painted. | Confirmed at `fpg_panel.pas:737`. Its raised/lowered border is four lines; flat panels omit it. Caption painting follows. The inherited painter clears the background (`:438`), and client geometry depends on flat versus framed (`:834`). | Panel supplies a smaller existing render path and observable geometry to preserve. |
| Binding the Lua render function up front. | The request is correct: the existing code pins canvas userdata, but `TNXLuaSkin.DrawControlFrame` still calls `lua_getglobal` every draw (`projects/nxtest/ui/src/obNXLuaSkin.pas:173`). | Pin the selected render function at registration and invoke it by registry reference. |
| Performance expectations for subscriptions. | Binding that function removes one lookup. Existing SQLite captures show `Lua.Plugin` accounts for 83.8% and 84.4% of traced self-time. There were 112,000 `FindPublishedLink` calls for 14,000 Lua frames in each capture. `DoLuaIndex` and `DoLuaLinkDispatch` both resolve a canvas member by name. | Treat subscription as an architectural improvement, not a demonstrated cure for canvas dispatch cost. Measure these costs separately. |
| Published-member discovery versus per-call dispatch. | `TLuaPlugin.Create` builds published-member lists once. Repeated work includes searching those lists, creating closures, preparing arguments, and dynamic invocation (`packages/lua/src/Lua.Plugin.pas:80,352,426`). | Cache state descriptors once, but do not describe all bridge time as metadata discovery or as the intrinsic cost of RTTI. |
| Making the illustrative published `Rect` property concrete. | If implemented using fpGUI's `TfpgRect`, it is an old-style value `object` (`fpg_base.pas:172`). NexusFPC rejects publishing that object kind (`compiler/symdef.pas:8741` and `pdecvar.pas:522`). | Publish scalar coordinates; retain a normal typed rectangle convenience operation outside the published schema. |
| Extending state through new published properties. | Property names can be open-ended; value kinds still require a defined conversion. The current Lua bridge handles scalar values but does not generally expose arbitrary nested Pascal objects or records. | Promise automatic exposure of new properties of supported types, not unlimited type support. |
| Retained bindings across style lifetime changes. | `TfpgStyleManager.SetStyle` frees the previous instance immediately (`fpg_stylemanager.pas:130`). It has no subscription notification mechanism. `TNXLuaSkin.Destroy` closes its Lua VM before inherited destruction. | Bindings need explicit invalidation, and Lua-backed registrations must be released before the VM closes. |

The profile findings above were rechecked read-only in `output/NexusLuaSkinProfile/skin-benchmark.sqlite`. Both captures are complete with no lost events or import issues. They instrument Pascal procedures and use a recording canvas: they do not separately measure Lua DLL internals or real screen rendering, and profiler overhead affects timings.

## Architecture Problem

The current integration offers either a known `TfpgStyle.Draw*` method or control-owned drawing. A new shared visual operation has no independent name and state contract through which a skin can supply an implementation.

A subscription supplies that missing contract. It also creates a new lifetime obligation: a control retains something supplied by a replaceable skin. The design must address that obligation explicitly rather than relying on a raw renderer pointer remaining valid.

## Target Contract

### Registration, binding, and painting

`TNXSkin` owns an instance-local render registry and exposes registration and subscription. A registration associates a case-sensitive capability name, an accepted state class, and one renderer implementation. Duplicate names, missing capabilities, and incompatible state classes fail during setup with useful diagnostics. Different skin configurations can register different implementations of the same capability.

The base registry knows no `PanelFrame`, `ButtonFace`, or other built-in list. Capability names and state classes belong beside their controls/render implementations. A prototype skin composition unit registers `PanelFrame`; introducing another capability does not edit the registry or `TfpgStyle`.

The control owns one persistent state instance. A useful concrete binding shape is:

```pascal
FFrameRender := ASkin.Subscribe('PanelFrame', FFrameState);
// During paint, update FFrameState from the control, then:
FFrameRender.Render(Canvas);
```

The state is borrowed by the subscription and remains owned by the control. Binding the state instance here allows type validation and Lua property discovery outside painting. Replacing that instance requires explicit rebinding. The exact private helper names are implementation details, not an additional framework requirement.

The minimum new responsibilities are:

| Object/concept | Responsibility |
|---|---|
| `TNexusControlState`, based on `TPersistent` | RTTI-enabled common state: `Left`, `Top`, `Width`, `Height`, and `Enabled`. `ReadOnly` belongs in descendants that need it. |
| `TNXPanelFrameState` | Panel-specific published `Style` and `BorderStyle`, using the existing Pascal enum types. |
| Per-skin render registry | Own registrations and implementations; resolve names when subscribing; track live subscriptions without owning them. |
| Renderer implementation | Declare its accepted state type and create a binding for a compatible state instance. |
| Control-owned render subscription | Invoke an already resolved implementation, retain the borrowed state association, and detach safely. |
| Pascal PanelFrame renderer | Paint from a typed `TNXPanelFrameState`, with the existing panel border semantics. |
| Lua renderer adapter | Pin a function, marshal published state, and invoke it using the existing canvas bridge. |

Pascal bindings validate the state relationship once and retain the correctly typed reference. Rendering is normal Pascal field/property access, not RTTI method invocation. Any checked type narrowing belongs at the binding boundary; do not scatter unchecked casts through painters.

### Published state in Lua

Discover readable published properties from the actual state class, including inherited properties, when creating its schema descriptor. Cache those descriptors by actual class for the Lua adapter's lifetime. Do not enumerate properties or resolve them by name again on each paint.

For each invocation, read current values through those descriptors and create a plain Lua state table. Preserve property names exactly. This is a value snapshot: a script may retain it without retaining the Pascal state or owning the control. Script writes affect only that table. Start with a fresh table per invocation and measure its allocation cost before introducing mutable table reuse.

| Pascal state kind | Lua representation |
|---|---|
| Boolean | Lua boolean |
| Signed/unsigned 32-bit integer, coordinates, ARGB colors | Lua number, with exact integer value |
| Single/Double | Lua number |
| Supported string types | UTF-8 Lua string |
| Enum, including panel style/border style | Symbolic enum name, matching the current bridge's enum output convention |

Lua 5.1 uses a double for numbers in our binding. Do not promise exact arbitrary `Int64`/`QWord` transport: accept only exactly representable integers if those kinds are included, otherwise reject them explicitly. Unsupported property kinds and unreadable properties produce a class/property-specific binding error. No silent stringification, recursive object graph serialization, or property-name registry is needed.

Do not expose the control-owned state through `TLuaPlugin.PushLuaObject`: its userdata finalizer frees the Pascal object (`Lua.Plugin.pas:495`). The snapshot avoids that ownership conflict. Share existing scalar conversion code where appropriate without making the state base depend on Lua or inherit from the plugin object.

### Ownership and lifecycle

| Owner | Owned resources and release behavior |
|---|---|
| fpGUI style manager | Owns the active skin as it does today. |
| `TNXSkin` | Owns its render registry and renderer implementations. Registry shutdown first invalidates subscriptions, then frees implementations. |
| Prototype control | Owns its state and subscription. Free the subscription before the state; a live subscription unregisters itself from its registry. |
| Subscription | Borrows the renderer and control state. Skin shutdown clears its callable/owner references. Calling an invalidated binding reports an error; later destruction remains safe. |
| Lua-enabled prototype skin | Owns the existing Lua state. Release its render registrations and Lua registry references before `lua_close`; perform the same cleanup after partial construction failure. |
| Lua adapter | Owns its function reference and schema descriptors, and borrows the VM. Canvas access is attached only for the synchronous render call and detached in `finally`. |

Preserve the existing Lua-owned canvas userdata convention: do not additionally free the same bridge from Pascal. Keep it reachable while needed, release its registry reference during teardown, and let Lua finalize it. Restore the Lua stack and FPU exception mask on both success and error. A failed Lua draw must not leave an error value accumulating on the stack or a canvas attached.

Skin destruction must invalidate retained bindings even if the control is destroyed later. The normal UI selects its skin before constructing the prototype control, and destroys controls before application shutdown. Runtime automatic skin switching and automatic rebinding are not required for this experiment.

The existing `SetStyle` implementation also leaves updating global `fpgStyle` to its caller; the test UI already does that explicitly. Its unconditional trailing assertion is another pre-existing issue when assertions are enabled. Do not infer safe application-wide hot swapping from the new subscription alone, or conceal these issues by silently disabling checks.

## Prototype Integration

Add an opt-in `TNXRenderPanel` descendant of `TfpgPanel` and exercise it in a small test surface launched from NexusTestUI. Existing `TNXPanel` consumers keep their current behavior.

The exact operation moved into the subscription is the raised/lowered/single/double frame block in `TfpgPanel.HandlePaint`; a flat frame emits no border commands. Both Pascal and Lua implementations reproduce those coordinates, colors, and line widths.

There is no separate border hook in `TfpgPanel`. The prototype descendant therefore owns its short `HandlePaint` orchestration: clear the clip/background with the same parent-background rules, update the state, invoke the subscription, then paint the caption with the existing font, alignment, wrapping, margin, line spacing, and disabled-text behavior. Do not call the inherited panel painter and then overpaint its already-drawn border. Preserve inherited client geometry, input handling, and child painting. `OnPaint` and child traversal are dispatched outside `HandlePaint` by fpGUI and must not be duplicated.

This entails a small amount of duplicated background/caption orchestration in the opt-in descendant; that is a concrete limitation of the available override point. It keeps the experiment independent of modifications to the upstream fpGUI submodule. Do not turn this into a template for copying whole painters across every future control. Revisit the integration hook when Button is selected.

Reuse the existing Lua canvas operations, adding only a solid line-width operation needed for the panel's double border. Current `Color` also resets line style to width one; the renderer must set the requested width after setting each edge color, or an explicitly reviewed adjustment must preserve the old frame script's behavior.

Resolve the Lua render function once, validate that it is callable, and store a registry reference. Registration must not run again during painting. Keep Pascal/Lua selection in skin composition; the panel receives the same subscription interface in either mode. Pinning a function means later reassignment of its Lua global does not change an existing binding. Editing the script and restarting should still require no Pascal rebuild.

## Colors And Layout Metrics

The future NXScript color chart will be organized by render capability. Treat that as the intended direction, not as authorization to design and implement the configuration system now.

For `PanelFrame`, the current concrete inputs are a highlight edge and a shadow edge. Resolve them from the existing skin palette (`clHilite2`/`clShadow1` currently map to Nexus widget-frame/dark-shadow colors). Keep these renderer resources separate from control state. A small capability-local color input gives Pascal and Lua the same numeric values; it can later be populated from compiled NXScript without changing the panel or subscription contract. Do not add a master enum of every render's colors or hardcode NXScript traversal into painting. Preserve current native-palette updates when supplying these values.

Panel already exposes a metric relationship worth observing: single and double borders use one- and two-pixel strokes, while framed client bounds use a two-pixel inset and flat panels use none. The prototype preserves that relationship. A future configurable stroke/inset must also inform `GetClientRect` and layout; changing drawing alone would produce incorrect content placement. Metrics belong to a control/layout-facing contract outside paint, but that contract is not yet specified by this experiment.

Button remains the useful next source of evidence: gradients, normal/hover/pressed/default/focus treatment, border metrics, image/text positioning, and hover policy. Its current Nexus face painter ignores the button's temporary `clButtonFace` override by using the skin's own gradient palette, and does not provide a separate disabled face treatment. Those are concrete policy gaps to settle when Button is addressed, rather than assumptions to encode now in a universal color chart. A `PanelFrame` result will not establish that Button metrics or control color overrides have been solved.

## Work Required And Likely Files

- Add the backend-independent state/registry/subscription definitions under `packages/gui/src/`, with an `ob...` unit owning the class definitions. Add generic registration/subscription and explicit render teardown to `obNXSkin.pas`. Keep the base skin independent of control-specific names and Lua.
- Add the opt-in Panel descendant, its state schema, and Pascal frame renderer in narrowly scoped GUI units. The schema is owned by the capability, not by a master framework field list.
- Add an optional Lua render adapter under `packages/gui/src/`. Move the existing reusable `TNXLuaCanvas` definition out of the test project when the package adapter needs it, retaining one owner/definition. The adapter may depend on `packages/lua`; neither package may reference `projects/`.
- Put generic published-object-to-Lua value projection in `packages/lua/src/` if it is shared with `Lua.Plugin`; reuse/extract scalar conversion only as needed by that concrete consumer. Keep per-canvas published-link caching separate from the render-subscription change so its effect can be measured independently.
- Use the existing application-owned `obNXLuaSkin.pas` and a small native prototype skin registration to select the implementation. Add a `PanelFrame.lua` fixture. Adjust Lua skin teardown to release new adapters before closing its VM.
- Extend NexusTestUI's entry point/test surface and existing smoke/benchmark support. Correct its stale JSON source search path from `packages/foundation/json/src` to `packages/foundation/serialization/json/src` as part of making that affected project reproducibly build.
- Adapt `repo-automation/Build-NexusLuaSkinPrototype.ps1` only as necessary to deploy the new Lua fixture and exercise the selected smoke path. Preserve its existing output location and the existing Lua version/DLL choice.

These are responsibility boundaries rather than a demand for a file per helper. Keep the implementation small and retain the existing frame prototype as a baseline where useful.

## Verification Plan

The implementation should provide observable evidence for each claim:

- Run the same panel control with Pascal and Lua registrations under `PanelFrame`. Compare ordered drawing commands, coordinates, colors, and line widths for raised, lowered, flat, single, and double variants. Check caption, disabled text, parent background, resizing, clipping, and child placement on the real UI surface.
- Derive a state with additional published integer, Boolean, and string properties (for example `Severity`, `Selected`, and `BadgeText`). Have a test renderer consume them through the unchanged generic Lua adapter. Verify inherited properties and updates between paints. A native typed binding must also receive the appropriate state class.
- Register an arbitrary second capability name in a focused test, without editing the framework. Confirm a base-state renderer can be bound from different state descendants; this exercises generic and specialized contracts without adding another production control.
- Count capability resolution, Lua function resolution, and schema discovery. Repeated paints through an existing subscription must not repeat any of them. Canvas method lookup costs remain separately visible until deliberately optimized.
- Check missing/duplicate capability names, incompatible state classes, unsupported state kinds, Lua initialization/draw errors, control destruction, skin destruction with a live binding, and retained Lua state snapshots after control destruction. Verify stack balance and detached canvas access after failure.
- Pair smoke assertions with fixed fixtures. The current old smoke check expects two magenta lines, whereas `ControlFrame.lua` now draws one blue line; its failure is a stale expectation, not evidence that the new architecture works or fails. Make test failures report their actual exception instead of the current bare exit code.
- Reuse the benchmark's warmups and ten alternating pairs. Compare direct Pascal, subscribed Pascal, and subscribed Lua performing equivalent panel work; report per-render timings, state-projection cost, and drawing-command counts. Use uninstrumented timing for runtime cost and NexusFPC `-profile` plus SQLite for attribution. Do not compare the old small frame workload directly with a richer panel workload as a speedup claim.
- Verify a visible Lua-only color change by editing the deployed script, restarting, and observing it without any rebuild afterward.

Expected build/run routes after implementation are `lazbuild -B projects\nxtest\ui\src\NexusTestUI.lpi` (with the Lua import library/runtime supplied by the existing helper), focused render smoke/benchmark modes added to that executable, and the GUI skin tests affected by `TNXSkin`. For profiling, use NexusFPC's documented `-profile -Aas-clang -XLL` and its support units in isolated build output, then `NexusProfilerImport import <database.sqlite> <trace.nxp> -run <name>`. The prior build also required the available `regexpr` source and the current JSON source path; record the actual compiler inputs when repeating it.

Focused source checks must confirm that the selected border painter invokes its retained binding, the generic registry contains no Panel/Button name switch, the state base imports no Lua unit, and package source has no references into `projects/`. Inspect all new ownership edges and Lua references before considering the prototype verified.

## Out Of Scope And Remaining Limits

No migration of all fpGUI styles or controls, new rendering engine, generalized plugin loader, Lua-version change, automatic hot reload, global skin-switch coordinator, or additional product thread is needed. Existing named colors and legacy drawing routes outside the selected specimen remain operational. The current global color table means this is not proof of independently themed controls sharing one application.

The render-type NXScript color chart and potential metric configuration remain future work informed by these observations. Open decisions there include precedence between theme colors and per-control overrides, and how changed metrics trigger layout. This prototype should expose the facts needed for those decisions without inventing their final API.

Only this plan artifact is produced, committed, and pushed during the planning handoff. Implementation requires a direct request from the human owner.
