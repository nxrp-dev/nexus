# NexusUI Component Inventory

This page lists the current NexusUI components and the role each one plays.

The descriptions are intentionally practical. This page should help answer: "what do we already have, and what is each class for?"

## Core base classes

### `TNXControl`

Base retained UI control.

Owns common behavior for bounds, visibility, enabled state, focus, mouse state, rendering hooks, input hooks, child controls, parent attachment, and basic layout participation.

### `TNXControlHost`

Base host for child controls.

Provides parent-side services such as child management, layout callback flow, focus delegation, coordinate conversion, and canvas/skin access.

### `TNXScrollableControl`

Base class for controls with a scrollable viewport.

Owns horizontal and vertical scrollbars and exposes scroll position behavior for controls such as memo or future scrollable containers.

## Application, windows, and overlays

### `TNXApplication`

Top-level NexusUI runtime object.

Owns the platform backend, root window, window manager, popup manager, skin, event loop, input routing, and rendering trigger.

### `TNXWindow`

Floating or root-level control host.

Owns authoritative focused control state and routes keyboard, text, mouse, and wheel input into its child controls.

### `TNXWindowManager`

Manages floating windows, active windows, and modal window behavior.

Routes events to modal/floating windows before they fall through to the root window.

### `TNXPopup`

Base transient popup surface.

Used for popup menus, combo dropdowns, and other overlay-like UI elements.

### `TNXPopupManager`

Routes input to the active popup before ordinary windows/root controls.

Owns popup show/hide behavior, click-away behavior, and popup z-order handling.

## Basic controls

### `TNXButton`

Clickable command control.

Uses skin state to distinguish normal, hot, focused, and pressed states.

### `TNXLabel`

Static text display control.

Useful for captions, field labels, and simple read-only text.

### `TNXEditBox`

Single-line text input control.

Supports focus, caret rendering, selection behavior, placeholder text, and text input handling.

### `TNXCheckBox`

Boolean option control.

Displays checked/unchecked state and supports focus/keyboard/mouse interaction.

### `TNXRadioButton`

Single-choice option control.

Intended for mutually exclusive option groups.

### `TNXImage`

Image display control.

Used for rendering loaded images/textures inside the control tree.

### `TNXProgressBar`

Progress display control.

Displays a current value within a min/max range.

## Text and editing controls

### `TNXMemo`

Multiline text editing control.

Supports scrolling, caret behavior, selection, text input, and placeholder behavior. This is the practical multiline editor for application UI.

### `TNXCodeEdit`

Planned or design-stage code/text editing control.

This should remain scoped carefully. It may become an enhanced memo or lightweight syntax-aware editor, but should not casually become a full code editor project.

## Lists, trees, grids, and structured data

### `TNXListBox`

List selection control.

Displays selectable rows with scrollbar support.

### `TNXTreeList`

Hierarchical list/tree control.

Used for nested or expandable structured data.

### `TNXGrid`

Grid/table control.

Useful for row/column structured data display and editing scenarios.

### `TNXPropertyEditor`

Property/value editor control.

Useful for object settings, configuration editing, and simple property-grid style workflows.

### `TNXTreeMap`

Treemap visualization control.

Displays hierarchical weighted data as nested rectangles, inspired by WinDirStat-style visualizations.

## Containers and layout controls

### `TNXPanel`

General-purpose container control.

Useful as a background, grouping surface, layout parent, or lightweight group box substitute.

### `TNXGroupBox`

Captioned grouping control.

Provides a labeled visual grouping surface with an internal content panel.

### `TNXSplitPanel`

Resizable two-pane container.

Owns two pane controls and a splitter between them.

### `TNXSplitPanelPane`

Internal pane used by `TNXSplitPanel`.

Not usually created directly by application code.

### `TNXSplitPanelSplitter`

Internal draggable splitter used by `TNXSplitPanel`.

Owns drag behavior for resizing split panes.

### `TNXTabControl`

Tabbed page control.

Owns tab strip/page behavior and switches active page content.

### `TNXTabStrip`

Internal tab header strip used by `TNXTabControl`.

Handles tab hit testing and tab header rendering.

### `TNXTabPageHost`

Internal page host area used by `TNXTabControl`.

Hosts active tab page content.

### `TNXStatusBar`

Bottom status display/control strip.

Useful for application state text, status panels, and lightweight application feedback.

## Menus and command surfaces

### `TNXMainMenu`

Top-level application menu control.

Displays menu items and opens dropdown/popup menus.

### `TNXPopupMenu`

Context/dropdown menu control.

Used by menus, right-click context actions, and popup command lists.

### `TNXComboBox`

Selection control with dropdown list.

Combines an edit/display surface with popup/dropdown selection behavior.

### `TNXToolBar`

Backlog control.

Would provide a horizontal or vertical command strip for common actions.

## Dialogs and pickers

### `TNXMessageDialog`

Modal message/action dialog.

Used for prompts, alerts, confirmations, and simple multi-button decisions.

### `TNXFileDialog`

Backlog/design control.

Needs a decision between native platform dialog wrapper, Nexus-rendered dialog, or an abstraction that supports both.

### `TNXColorPicker`

Backlog control.

Would provide color selection for property editors, settings, and visual configuration.

### `TNXDateEdit`

Backlog control.

Would provide date entry and validation, with optional picker behavior later.

### `TNXTimeEdit`

Backlog control.

Would provide time entry and validation, with optional picker behavior later.

### `TNXSpinEdit`

Backlog control.

Would provide numeric entry with increment/decrement behavior.

## Supporting visual systems

### `TNXSkin`

Skin/theme object.

Provides visual values such as colors, state colors, and appearance data used by controls.

### Skin appearances

Skin appearance classes represent visual parts such as colors, text, images, nine-slice data, and composite appearances.

These should eventually let controls ask for a part/state instead of hardcoding drawing choices.

## Component status categories

### Usable initial versions

- `TNXButton`
- `TNXLabel`
- `TNXEditBox`
- `TNXCheckBox`
- `TNXRadioButton`
- `TNXImage`
- `TNXProgressBar`
- `TNXMemo`
- `TNXListBox`
- `TNXTreeList`
- `TNXGrid`
- `TNXPropertyEditor`
- `TNXTreeMap`
- `TNXPanel`
- `TNXGroupBox`
- `TNXSplitPanel`
- `TNXTabControl`
- `TNXStatusBar`
- `TNXMainMenu`
- `TNXPopupMenu`
- `TNXComboBox`
- `TNXMessageDialog`

### Backlog or design-stage components

- `TNXToolBar`
- `TNXSpinEdit`
- `TNXDateEdit`
- `TNXTimeEdit`
- `TNXColorPicker`
- `TNXFileDialog`
- `TNXCodeEdit`
