# Event and Focus Model

NexusUI routes input explicitly through the application, popup manager, window manager, windows, and controls.

## Event normalization

The backend converts platform-native events into Nexus events.

For SDL2, this means SDL keyboard, mouse, text, window, and wheel events are translated into Nexus event records before application-level routing begins.

Application and control code should work with Nexus event types, not SDL2 event structures.

## Top-level routing

Input routing starts in `TNXApplication`.

The preferred routing order is:

1. active popup
2. modal or floating windows
3. root window

This keeps transient UI above ordinary controls and prevents clicks or keyboard input from leaking behind active overlays.

## Focus ownership

Focus is authoritative at the window level.

A window owns one focused control. Keyboard and text input route to that control rather than recursively walking selected children.

This replaced the older selected-child model. The old model was locally simple but could allow multiple branches of the control tree to believe they were selected.

## Focusable controls

A control participates in focus when it is:

- visible
- enabled
- `CanFocus = True`
- `TabStop = True` for keyboard traversal

`CanFocus` means the control can become focused. `TabStop` means structural Tab traversal may land on it.

A control may be focusable without being a tab stop, but ordinary input controls usually should be both.

## Structural Tab traversal

NexusUI does not use designer-style integer `TabOrder`.

Tab traversal is structural. Controls are collected from the ownership tree and sorted by visual position:

1. top-to-bottom
2. left-to-right
3. ownership/child traversal
4. insertion order as a practical tie-breaker

This avoids manually maintained tab numbers and keeps behavior tied to the actual UI structure.

## Mouse capture

Controls can capture the mouse during drag-like operations.

When mouse capture is active, mouse motion and mouse up should route to the captured control even if the pointer has moved outside its bounds.

This is used by controls such as splitters, sliders, selections, and other drag interactions.

## Mouse wheel

Mouse wheel events are represented in the Nexus event model and include horizontal and vertical deltas.

Scrollable controls should consume wheel input when the pointer is over the relevant scrollable area and the matching scrollbar is visible.

## Text input

Text input is distinct from key down/up.

Controls that accept text should start backend text input when focused and stop it when focus is lost. This matters for composed characters, IME behavior, and platform text services.

## Popup input ownership

The popup manager routes input to the active popup before normal windows and controls.

Escape should close suitable popups. Mouse events inside the popup should route to the popup. Click-away behavior should either close the popup or intentionally allow the owner to handle the click, depending on the popup type.

Keyboard consumption should be explicit. A popup can either own keyboard input while active or only consume keys it handles, but that rule should be clear in the implementation.

## Practical rules

- Route keyboard/text to one focused control.
- Use mouse capture for drag operations.
- Prefer coordinate conversion helpers over raw absolute math.
- Keep popup routing above normal windows/root controls.
- Do not add numeric `TabOrder`.
