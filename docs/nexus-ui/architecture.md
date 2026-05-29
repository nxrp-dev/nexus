# Nexus UI Architecture

Nexus UI is organized around a small set of runtime responsibilities. The
framework is retained-mode: controls keep state, render themselves, and receive
input routed through the application, window, popup, and control hierarchy.

## Application

`TNXApplication` owns the top-level runtime. It creates and destroys the
platform backend, canvas, skin object, root window, popup manager, and window
manager. It also runs the message loop, receives normalized Nexus events from
the backend, routes input, processes deferred frees, and triggers rendering.

Top-level input routing follows this order:

1. active popup
2. modal or floating windows
3. root window

That priority keeps overlays and modal UI from leaking input to controls behind
them.

## Platform and Canvas

`TNXPlatform` is the backend boundary. The active implementation is SDL2
through `TNXSDL2`, but application and control code should not need SDL2 event
or rendering structures directly.

Backend responsibilities include:

- window creation and destruction
- event polling
- renderer and canvas support
- text input start and stop
- clipboard operations
- font services
- image loading
- timing

`TNXCanvas` is the drawing abstraction used by controls. It forwards drawing,
text, image, clipping, and nine-slice work to the platform implementation while
keeping control rendering code backend-neutral.

## Windows

`TNXWindow` is a control host and event boundary. The root window hosts the main
application control tree. Additional windows are managed by `TNXWindowManager`,
which tracks floating windows, the active window, and modal windows.

A window owns one authoritative focused control. Keyboard and text input route
to that focused control. Mouse input is hit-tested through the window's child
controls, with mouse capture taking priority during drag operations.

## Popups

`TNXPopup` is the base transient popup surface. Popup menus, combo dropdowns,
message dialogs, and related overlays use the popup path instead of behaving as
ordinary child controls.

`TNXPopupManager` routes input to the active popup before ordinary windows and
root controls. It owns popup show/hide behavior, click-away handling, and popup
z-order behavior.

## Controls

`TNXControlHost` provides child-management services for hosts, including child
lists, canvas/skin access, layout callback flow, focus delegation, and
coordinate conversion.

`TNXControl` is the retained base class for visual controls. It owns common
control behavior:

- bounds
- alignment and anchors
- visibility and enabled state
- focus state
- mouse hover state
- mouse capture
- child controls
- rendering hooks
- input hooks
- basic layout participation

Container controls such as panels and group boxes are still controls. Parent
relationships use the `INXControlParent` interface and should not imply
reference-counted ownership.

## Coordinate Spaces

Controls and windows expose explicit coordinate conversion helpers:

```pascal
ScreenToLocal(AX, AY)
LocalToScreen(AX, AY)
ContainsScreenPoint(AX, AY)
```

Prefer these helpers over hand-written `AbsLeft` and `AbsTop` math when routing
input between windows, popups, and nested controls.

## Events and Focus

The backend converts platform events into Nexus event records before
application-level routing begins. Application and control code should work with
Nexus event types.

Focusable controls must be visible, enabled, and have `CanFocus = True`.
Structural Tab traversal also requires `TabStop = True`. Nexus UI does not use
designer-style numeric `TabOrder`; traversal is based on the control tree and
visual position.

Text input is separate from key down/up. Text controls such as `TNXEditBox` and
`TNXMemo` start backend text input on focus and stop it when focus is lost so
IME and composed-character behavior can be handled by the backend.

## Current Architectural Priorities

The current architecture is serviceable but still being hardened. Priority
areas are:

- focus and input routing
- coordinate helper consistency
- popup keyboard ownership semantics
- scrollable control behavior
- skin lookup by named parts and states
- data binding design before implementation
