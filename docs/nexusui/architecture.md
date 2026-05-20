# Architecture

NexusUI is organized around a small set of runtime responsibilities.

## Major pieces

### `TNXApplication`

`TNXApplication` owns the top-level runtime loop and coordinates platform input, windows, popups, skin data, and rendering.

Primary responsibilities:

- receive normalized Nexus events from the platform backend
- route events to popups, floating windows, or the root window
- own the root window
- own the window manager
- own the popup manager
- trigger rendering

### `TNXPlatform`

`TNXPlatform` is the backend boundary. Application and control code should not need to know SDL2 details directly.

The active backend is SDL2, but the platform abstraction is intended to keep backend-specific code isolated.

Backend responsibilities include:

- window creation and destruction
- event polling
- renderer/canvas support
- text input start/stop
- clipboard operations
- font services
- image loading
- timing

### `TNXCanvas`

`TNXCanvas` is the drawing abstraction used by controls.

Controls should draw through the Nexus canvas API rather than directly calling SDL2 rendering functions. This keeps control code closer to backend-neutral Pascal UI logic.

### `TNXControl`

`TNXControl` is the retained base class for visual controls.

It owns common control behavior:

- bounds
- visibility
- enabled state
- focus state
- mouse hover state
- mouse capture
- child controls
- rendering hooks
- input hooks
- basic layout participation

A control may also act as a parent for child controls.

### `TNXWindow`

`TNXWindow` is a control host and event boundary.

A window owns one authoritative focused control. Keyboard and text input route to that focused control. Mouse input is hit-tested through the window's child controls.

### `TNXWindowManager`

The window manager owns floating windows and modal windows.

Its job is to decide whether an input event belongs to a modal window, a floating window, or should fall through to the root window.

### `TNXPopupManager`

The popup manager owns active transient popup routing.

Popups are routed before normal windows/root controls so dropdowns and popup menus behave like overlays rather than ordinary child controls.

## Event priority

Top-level input routing follows this general priority:

1. active popup
2. modal/floating windows
3. root window

This order keeps overlays and modal UI from leaking input into controls behind them.

## Control tree

Controls are retained objects arranged in a parent/child tree.

The parent relationship matters for:

- rendering order
- hit testing
- coordinate conversion
- focus delegation
- layout
- lifetime behavior

## Coordinate spaces

NexusUI uses explicit coordinate conversion helpers to reduce confusion between screen/window/control-local coordinates.

Important helpers include:

```pascal
ScreenToLocal(AX, AY)
LocalToScreen(AX, AY)
ContainsScreenPoint(AX, AY)
```

Prefer these helpers over hand-written `AbsLeft` / `AbsTop` math when routing input between windows, popups, and nested controls.

## Current architectural priorities

The current architecture is serviceable but still early. Priority areas are:

- finish hardening focus and input routing
- simplify coordinate handling in remaining paths
- clarify popup keyboard ownership semantics
- improve scrollable control behavior
- move skin lookup toward named parts and states
- design the data binding layer before implementing it
