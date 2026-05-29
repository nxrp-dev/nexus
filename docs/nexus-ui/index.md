# Nexus UI

Nexus UI is a retained-mode Object Pascal UI framework built around explicit
application, window, canvas, popup, and control objects. SDL2 is the current
backend, but application and control code are intended to work through Nexus UI
runtime abstractions instead of SDL2 structures directly.

The framework is code-first. Screens are composed in Pascal code, controls are
retained objects, and runtime behavior is owned by a small set of readable
classes rather than by designer metadata.

## Runtime Shape

At a high level, a Nexus UI application is organized as:

```text
TNXApplication
  TNXPlatform backend
  TNXCanvas
  TNXSkin
  Root TNXWindow
  TNXWindowManager
  TNXPopupManager
  Retained control tree
```

Input is normalized by the platform backend, routed through the application,
then delivered to popups, floating or modal windows, the root window, and
finally individual controls.

## Current Maturity

The repository contains working initial implementations for common controls,
including buttons, labels, edit boxes, memo, check boxes, radio buttons, list
boxes, combo boxes, grids, tree controls, panels, group boxes, tabs, splitters,
split panels, menus, toolbars, status bars, progress bars, track bars, images,
tree maps, property editors, date/time edits, popups, and message dialogs.

The important near-term work is hardening shared behavior rather than simply
adding more widgets:

- focus routing
- popup routing
- mouse capture
- scroll behavior
- layout consistency
- skin resolution
- data binding design

## Documentation Map

- [Philosophy](philosophy.md) describes the framework's design priorities.
- [Getting Started](getting-started.md) shows the shape of a small application.
- [Architecture](architecture.md) explains runtime ownership and routing.
- [Controls](controls.md) lists the current control inventory and authoring
  expectations.
- [Layout](layout.md) documents alignment, anchors, focus traversal, and
  related control-tree behavior.
- [Styling](styling.md) covers the current skin model.
- [Data Binding](data-binding.md) records the planned data-aware layer.
- [Cross Platform](cross-platform.md) describes the backend boundary and the
  current SDL2 status.
