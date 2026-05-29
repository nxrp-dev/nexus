# Nexus UI Controls

Nexus UI controls are retained Pascal objects. They are created in code,
attached to a parent, and rendered/input-routed through the Nexus control tree.

## Core Base Classes

- `TNXControl` is the base retained UI control. It owns common bounds,
  visibility, enabled state, focus, mouse, rendering, input, child, parent, and
  layout behavior.
- `TNXControlHost` is the base host for child controls. It provides child
  management, layout callback flow, focus delegation, coordinate conversion,
  and canvas/skin access.
- `TNXScrollableControl` is the base class for controls with a scrollable
  viewport and scrollbars.

## Application, Windows, and Overlays

- `TNXApplication` owns the runtime loop, platform backend, root window, window
  manager, popup manager, skin, event routing, and rendering trigger.
- `TNXWindow` hosts a root or floating control tree and owns the authoritative
  focused control.
- `TNXWindowManager` manages floating windows, active windows, and modal
  windows.
- `TNXPopup` is the base transient popup surface.
- `TNXPopupManager` routes active popup input before normal windows/root
  controls.

## Basic Controls

- `TNXButton` is a clickable command control. It uses skin state for normal,
  hot, focused, and pressed rendering when skin data is available.
- `TNXGlyphButton` extends button behavior with image/glyph rendering.
- `TNXLabel` displays static text.
- `TNXEditBox` provides single-line text input with focus, caret, selection,
  placeholder, and text input handling.
- `TNXCheckBox` provides a boolean option control.
- `TNXRadioButton` extends check box behavior for mutually exclusive sibling
  choices.
- `TNXImage` displays loaded images/textures inside the control tree.
- `TNXProgressBar` displays a value within a min/max range.
- `TNXTrackBar` provides a draggable value control.

## Text and Editing Controls

- `TNXMemo` is the practical multiline text editor. It supports scrolling,
  caret behavior, selection, text input, and placeholder behavior.
- `TNXDateEdit` and `TNXTimeEdit` are edit-derived date and time entry controls.
- `TNXCodeEdit` is not present as a current control. Treat it as a future
  design decision, not as a small widget addition.

## Lists, Trees, Grids, and Structured Data

- `TNXListBox` displays selectable rows.
- `TNXTreeList` displays hierarchical expandable data.
- `TNXTreeView` displays tree nodes with columns/cells.
- `TNXGrid` displays row/column data.
- `TNXPropertyEditor` displays editable property/value rows.
- `TNXTreeMap` displays hierarchical weighted data as nested rectangles.
- `TNXStarMap` is a visual map control.

## Containers and Layout Controls

- `TNXPanel` is a general-purpose container and background surface.
- `TNXGroupBox` is a captioned grouping container with a content panel.
- `TNXSplitter` resizes aligned sibling regions.
- `TNXSplitPanel` owns two panes and an internal splitter.
- `TNXTabControl` owns tab pages, a tab strip, and a page host.
- `TNXCommandOverlay` positions controls along command overlay edges.

## Menus and Command Surfaces

- `TNXMainMenu` displays top-level application menus.
- `TNXPopupMenu` displays dropdown and context menu items.
- `TNXComboBox` combines a selection surface with popup/dropdown behavior.
- `TNXToolbar` provides a command strip with buttons and separators.
- `TNXStatusBar` displays status text and panels.

## Dialogs and Pickers

- `TNXMessageDialog` is a modal popup-backed message/action dialog.
- `TNXFileDialog` and `TNXColorPicker` are not present as current controls.
  They need design decisions before implementation, especially around native
  dialog wrappers versus Nexus-rendered dialogs.

## Control Implementation Pattern

A typical control should:

1. inherit from `TNXControl` or a suitable derived base
2. set simple defaults in the constructor
3. override rendering methods for visual output
4. override input hooks for behavior
5. expose a minimal public API
6. use skin/theme values instead of hardcoded colors where practical

Focusable input controls should usually set:

```pascal
CanFocus := True;
TabStop := True;
```

Decorative controls and non-input containers should usually avoid keyboard
focus unless they have a specific interaction reason.

## Hardening Before More Widgets

The project does not need endless widget creation before the core is stable.
Before adding broad new surfaces, prioritize:

- focus correctness
- mouse capture correctness
- popup routing correctness
- scroll behavior
- clipping behavior
- skin state resolution
- consistent coordinate conversion
