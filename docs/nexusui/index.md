# NexusUI Overview

NexusUI is a retained-mode Pascal UI framework built over SDL2.

It is intended to provide a small, practical control framework for tools and applications that should not depend on platform-specific visual component libraries. The framework is code-first: screens and controls are constructed in Pascal code, not through a visual designer.

## Design philosophy

NexusUI favors:

- Explicit ownership and event routing.
- Small control classes that can be understood by reading them.
- Backend isolation rather than direct SDL2 leakage throughout application code.
- Structural behavior over designer metadata.
- Practical controls needed by real applications.

NexusUI intentionally avoids designer-era patterns that require fragile manual metadata. For example, keyboard traversal is structural rather than based on a numeric `TabOrder` field.

## Runtime shape

At a high level, the runtime is:

```text
Application
  Platform backend
  Canvas
  Skin/theme data
  Root window
  Floating windows
  Popup manager
  Control tree
```

Controls are retained objects. They own state, render themselves, and receive input routed through the application/window/control hierarchy.

## Active backend

SDL2 is the current backend. The SDL2 layer is responsible for translating platform events into NexusUI events and providing rendering/input services through the Nexus platform abstractions.

Future backends are possible, but the immediate priority is making the SDL2 backend correct and complete enough for real application work.

## Current maturity

NexusUI already has a useful initial control set, including buttons, labels, edit boxes, check boxes, list boxes, combo boxes, panels, menus, popups, memo, grid, tree controls, progress bars, tabs, split panels, status bars, and dialogs.

The main framework work remaining is not merely adding widgets. The important work is hardening core behavior:

- focus routing
- popup routing
- mouse capture
- scrolling
- layout consistency
- skin resolution
- data binding semantics
