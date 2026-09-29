# Work Plan: TNXSkin Based On fpGUI Fusion Rendering

## Inputs

- Human-owner request for a direct and narrowly scoped Nexus skin:
  `TNXSkin = class(TfpgStyle)`.
- Human-owner direction to use fpGUI's Fusion style as the implementation model
  because it is the closest existing rendering behavior to the desired result.
- Human-owner direction for an associated NXScript dialect whose compiled
  document supplies the skin's color values.
- Human-owner correction that the earlier pasted work-plan request was overly
  broad and is not authoritative for this plan.
- Current `TfpgStyle`, `TfpgFusionStyle`, style-manager, NexusScript compiler,
  validator, and compiled-model sources.
- Repository architecture-change protocol, GUI and NexusScript package
  instructions, and Pascal standards.

This is a work plan only. It does not authorize implementation, builds, tests,
program execution, broad NexusUI cleanup, or changes outside this plan file.

## Summary

Add a Nexus-owned `TNXSkin` that descends directly from `TfpgStyle`. Copy and
adapt the useful rendering behavior from `TfpgFusionStyle`; do not inherit from
or retain a runtime dependency on the Fusion style classes.

`TNXSkin` will own a fixed native color palette corresponding to the colors
used by the Fusion rendering code. It will have a complete built-in dark
palette so ordinary construction through `TfpgStyleManager` works without a
skin file.

Add a small GUI-owned NXScript dialect defining exactly those palette values.
An NXScript compilation/validation adapter will convert one compiled `Skin`
definition into a temporary native palette. Only after every required color
has been parsed successfully will `TNXSkin` replace its active palette and
update fpGUI's named-color table. Painting will read only the native palette;
it will never traverse NXScript data.

This plan does not create a general theme framework, an editor color system,
font or metric scripting, skin inheritance, hot reload, image-based skinning,
or new fpGUI style APIs.

## Verified Findings

- `TfpgStyle` is declared in fpGUI core and provides the virtual drawing and
  metric surface used by concrete styles.
- `TfpgFusionStyle` descends directly from `TfpgStyle`. Its light and dark
  subclasses only select one of two constant palettes.
- Fusion's palette contains 30 `TfpgColor` values covering window and input
  backgrounds, frame and text colors, selection/accent colors, button states,
  progress-bar states, checkbox/radio states, and tab states.
- Fusion overrides control frame, bevel, arrow, string, focus, button, menu,
  progress bar, checkbox, radio button, and page-control rendering, plus the
  related button/check/radio metrics. Other behavior remains inherited from
  `TfpgStyle`.
- Fusion maps its palette into fpGUI named colors in its constructor. Existing
  fpGUI widgets therefore receive much of the style through both virtual draw
  calls and the named-color table.
- Fusion still hardcodes white for active selection text. To make all colors
  used by the copied implementation scriptable, the Nexus palette needs one
  additional `SelectionText` entry.
- `TfpgStyleManager` constructs styles through a parameterless virtual
  constructor and owns the selected style instance. A Nexus style therefore
  needs a valid built-in palette before any external document is loaded.
- Current Nexus fpGUI applications initialize fpGUI, select `Plastic Dark`,
  and assign `fpgStyle := fpgStyleManager.Style`. Registering a `Nexus` style
  is compatible with this existing startup pattern.
- `TNexusScriptCompilationSession` produces a compiled document and retains
  compilation diagnostics. `TNexusScriptValidator` validates a compiled
  subject against its compiled dialect document.
- The NXScript language-definition dialect can require named properties and
  reject unknown properties, but it has no color scalar type. Color syntax
  must therefore be declared as text and checked while converting the
  validated document into the native palette.
- Product dialects belong with their owning package. The skin dialect belongs
  under `packages/gui`, while the generic NXScript compiler and validator
  remain unchanged.
- `packages/gui/src/obNXSkin.pas` already declares an unrelated legacy
  `TNXSkin = class(TNXPersistObject)`. Its source consumers are other legacy
  NexusUI units. No currently scanned program source outside that legacy
  subsystem imports it, but removing or renaming the subsystem is not part of
  this narrowly corrected request.

## Architecture Problem

Nexus fpGUI programs currently select a concrete fpGUI style. That leaves the
rendering implementation and its palette owned by fpGUI, and there is no
Nexus-owned boundary at which a validated NXScript document can supply the
colors.

The correction does not require a new general-purpose styling architecture.
It requires one concrete Nexus style with:

1. Fusion-quality drawing behavior owned by Nexus;
2. a fixed, explicit native palette used by that drawing code; and
3. a small loader that turns a compiled and validated NXScript `Skin`
   definition into that palette before it becomes active.

## Target Contract

### `TNXSkin`

- Declare `TNXSkin = class(TfpgStyle)` in a new GUI unit whose name does not
  collide with the still-present legacy `obNXSkin` unit. The recommended
  initial unit is `obNXFPGUISkin.pas`.
- Register the class with `TfpgStyleManager` under the name `Nexus`.
- Copy and adapt the Fusion rendering methods into `TNXSkin`. Do not inherit
  from `TfpgFusionStyle`, import `fpg_style_fusion`, or access Fusion's palette
  at runtime.
- Retain the same override boundary as Fusion unless implementation review
  finds that a copied method has an actual defect. This task is not an audit or
  redesign of every fpGUI widget.
- Replace Fusion's numeric palette indices with a Nexus enum and an enum-indexed
  array so drawing code uses names rather than unexplained offsets.
- Include these 31 roles:
  `WindowBackground`, `InputBackground`, `DarkShadow`, `WidgetFrame`,
  `PrimaryText`, `Selection`, `SelectionText`, `ScrollBar`, `GridLines`,
  `Focus`, `ButtonTop`, `ButtonBottom`, `ButtonHoverTop`,
  `ButtonHoverBottom`, `ButtonPressedTop`, `ButtonPressedBottom`,
  `DisabledText`, `MenuSeparator`, `ButtonHighlight`, `ButtonBorder`,
  `ProgressTop`, `ProgressBottom`, `ProgressHighlight`, `ProgressBorder`,
  `ProgressTrack`, `CheckBackground`, `CheckBorder`, `CheckMark`,
  `CheckPressed`, `InactiveTab`, and `TabBorder`.
- Initialize those roles from Nexus-owned constants based on Fusion Dark. This
  is the deterministic built-in skin and allows style-manager construction to
  succeed without an external file.
- Centralize fpGUI named-color assignment in one private method called after
  default construction and after a successful palette load. Preserve Fusion's
  current mappings, substituting the explicit `SelectionText` role for its
  hardcoded white value.

### Native state and loading

- The native runtime representation is only the enum-indexed array of
  `TfpgColor`; do not introduce a second object graph or generic appearance
  hierarchy.
- Expose one operation that accepts an already compiled NXScript document and
  its validation result, builds a local candidate palette, and applies it to
  the skin only on complete success.
- The loader must require exactly one root definition of kind `Skin`.
- Parse every color into the local candidate before assigning `FColors` or
  changing fpGUI named colors. A missing or malformed value returns a
  diagnostic and leaves the current palette untouched.
- NXScript compiler/model objects remain owned by the compilation session and
  are not retained by `TNXSkin`.
- Painting methods read `FColors` directly. No compilation, validation,
  definition lookup, string lookup, or color parsing occurs during painting.

### NXScript dialect

- Add `packages/gui/language/Skin.Language.nxscript`.
- Define one root kind, `Skin`, with `UnknownProperties: Reject`.
- Give `Skin` a required integer `Version` property and one required text
  property for each of the 31 palette roles listed above.
- Accept only `Version: 1` in the native conversion step. The generic language
  validator can establish that the value is an integer; the skin loader owns
  the supported-version decision.
- Use a single canonical text form for colors: `#AARRGGBB`. This maps directly
  and unambiguously to fpGUI's documented `TfpgColor` representation.
- Reject missing `#`, wrong length, or non-hexadecimal digits. Do not add named
  colors, expressions, references, inheritance, partial overrides, or alpha
  inference in this version.
- Add one complete skin fixture which declares the dialect and supplies all
  31 values. The fixture is test/example input, not a runtime dependency of
  the built-in palette.

### Ownership and startup

- `TfpgStyleManager` owns the `TNXSkin` instance, exactly as it owns other
  styles.
- `TNXSkin` owns its native palette by value and owns no NXScript document.
- The compilation session owns the compiled skin and dialect documents until
  conversion is finished.
- Application startup remains explicit:
  initialize fpGUI, select `Nexus`, assign `fpgStyle`, compile and validate an
  optional skin document, then apply its colors before forms are created.
- If no skin file is requested, use the built-in palette. If compilation,
  validation, or color conversion fails, report the diagnostics and retain the
  built-in palette.
- Runtime hot reload is not part of this work. That avoids introducing widget
  traversal, repaint policy, or mutable style lifetime work that was not
  requested.

## Scope

- Add `packages/gui/src/obNXFPGUISkin.pas` containing the direct `TfpgStyle`
  descendant, native palette, Fusion-derived rendering, named-color mapping,
  and compiled-document conversion entry point.
- Add `packages/gui/language/Skin.Language.nxscript`.
- Add focused GUI-package tests and skin fixtures for dialect validation,
  conversion, atomic failure behavior, default colors, named-color mapping,
  and direct `TfpgStyle` ancestry.
- Update the GUI test project search paths to include the existing NexusScript
  units required by those tests.
- Update NexusTestUI to select `Nexus` instead of `Plastic Dark` as the
  in-repository integration proof. Loading an external file in that program is
  not required unless the owner separately chooses a file-selection contract.
- Add short documentation for the fixed palette names, color format, and
  startup sequence.

## Out Of Scope

- Deriving from Fusion or modifying Fusion itself.
- Moving `TfpgStyle` out of fpGUI core or addressing the old `fpg_style.pas`
  TODO.
- Auditing or redesigning all fpGUI widget paint paths.
- Adding new `TfpgStyle` virtual methods.
- Fonts, metrics, icons, images, nine-slice assets, syntax highlighting,
  editor themes, diagnostic roles, or workspace semantic roles.
- General theme inheritance, partial skins, imports beyond ordinary NXScript
  compilation behavior, or a generic role registry.
- Runtime skin switching or hot reload.
- Configuration discovery, command-line skin selection, or a skin chooser.
- Migrating SwarmNX, SpaceTraderNX, or other external repositories.
- Removing, renaming, or repairing the remaining legacy NexusUI subsystem.
- Preserving the exact internal layout or names of Fusion's numeric palette.

## Staged Implementation Plan

### Stage 1: Add the Nexus style with built-in colors

1. Add the Nexus palette enum and enum-indexed color array.
2. Add `TNXSkin = class(TfpgStyle)` with Fusion Dark-derived default values.
3. Copy the Fusion override declarations and implementations into the Nexus
   unit, replacing numeric indices and hardcoded selection text with named
   Nexus palette roles.
4. Add the centralized fpGUI named-color mapping.
5. Register `TNXSkin` as `Nexus` and confirm there is no uses-clause or
   inheritance dependency on `fpg_style_fusion`.

### Stage 2: Define the skin dialect

1. Add the `Skin` language definition with version and all 31 required color
   properties.
2. Add one valid complete fixture and focused invalid fixtures for a missing
   property, unknown property, wrong scalar kind, unsupported version, and bad
   color text.
3. Keep all skin-specific schema files under `packages/gui`; do not add skin
   knowledge to `packages/nxscript`.

### Stage 3: Convert compiled NXScript into the native palette

1. Use `TNexusScriptCompilationSession` and `TNexusScriptValidator` in the
   loading/test boundary rather than adding a parser.
2. Verify the single-root `Skin` contract after generic validation.
3. Parse the 31 properties into a local native array and collect a precise
   source-range diagnostic for any unsupported or malformed value.
4. Commit the candidate array to `TNXSkin` and update fpGUI named colors only
   after the entire conversion succeeds.
5. Ensure the style retains no compiler, document, property, or string-based
   lookup state after conversion.

### Stage 4: Integrate and document

1. Change NexusTestUI startup from `Plastic Dark` to the registered `Nexus`
   style.
2. Keep NexusTestUI on the built-in palette so this task does not invent a
   configuration mechanism.
3. Document the dialect, exact color format, required palette, default
   behavior, and the explicit compile/validate/apply sequence for callers that
   already know a skin filename.
4. Reconcile documentation edits with the existing dirty worktree rather than
   overwriting unrelated pending changes.

## Sub-Agent Delegation

Implementation remains local to Main Codex. No sub-agent use is authorized by
this plan; plan approval and implementation approval do not authorize
delegation.

## Verification Plan

- Build the GUI test module with:

  ```text
  lazbuild -B packages/gui/test/NexusUITestModule.lpi
  ```

- Run the GUI test module through the existing NexusTest host/UI path and
  verify:
  - the built-in palette is complete;
  - a valid compiled fixture produces the expected 31 native colors;
  - every invalid fixture reports failure;
  - a failed load leaves the prior palette unchanged;
  - named fpGUI colors reflect the successfully applied palette.
- Build NexusTestUI with:

  ```text
  lazbuild -B projects/nxtest/ui/src/NexusTestUI.lpi
  ```

- Launch NexusTestUI for manual visual verification of buttons, menus,
  progress bars, checkboxes, radio buttons, tabs, frames, and focus/selection
  states rendered by `TNXSkin`.
- Use focused source checks to verify:
  - `TNXSkin` descends directly from `TfpgStyle`;
  - the Nexus style unit does not use or inherit a Fusion class;
  - all copied rendering color accesses use named palette enum values;
  - NXScript units are absent from paint methods and no compiled document is
    retained by the style;
  - NexusTestUI no longer selects `Plastic Dark`.
- Create the architecture checkpoint archive required by repository protocol
  only after separately approved implementation and successful verification.

## Risks And Questions

- The new class name collides with the legacy `TNXSkin` in `obNXSkin.pas`.
  This plan recommends the separate `obNXFPGUISkin` unit so the requested work
  does not silently expand into legacy-subsystem removal. Once that subsystem
  is explicitly removed, the owner may choose to rename the new unit to
  `obNXSkin` in a separate cleanup.
- The Fusion implementation is new and may contain local rendering defects.
  Copying it establishes the requested baseline; observed defects should be
  reported and decided individually rather than triggering an unrequested
  style redesign.
- The plan intentionally requires a complete external palette. Optional or
  inherited values would add merge semantics that are not needed to satisfy
  the corrected request.
- NexusTestUI proves in-repository integration, but external programs will
  continue selecting their current style until their migrations are separately
  requested.

## Approval Gate

No implementation, source edit outside this plan, build, test, program launch,
or external-project migration begins until the human owner explicitly approves
this work plan and authorizes implementation.
