# Controls

NexusUI controls are retained Pascal objects. They are created in code, attached to a parent, and rendered/input-routed through the Nexus control tree.

## Current control inventory

The current codebase includes initial versions of many common controls.

### Basic controls

- `TNXButton`
- `TNXLabel`
- `TNXEditBox`
- `TNXCheckBox`
- `TNXRadioButton`
- `TNXImage`
- `TNXProgressBar`

### Containers and layout controls

- `TNXPanel`
- `TNXGroupBox`
- `TNXSplitPanel`
- split panel panes and splitter support
- `TNXTabControl`
- tab page host / tab strip support
- `TNXStatusBar`

### Lists, grids, and structured data controls

- `TNXListBox`
- `TNXTreeList`
- `TNXGrid`
- `TNXPropertyEditor`
- `TNXTreeMap`

### Text controls

- `TNXEditBox`
- `TNXMemo`

`TNXMemo` is the practical multiline text control. A future `TNXCodeEdit` should be scoped carefully before implementation.

### Menus and popups

- `TNXMainMenu`
- `TNXPopupMenu`
- `TNXPopup`
- popup manager support

### Dialogs

- `TNXMessageDialog`

More dialog types are expected later, especially file dialogs and picker-style dialogs.

## Backlog controls

These are still useful targets, but should be implemented only when the framework needs them:

- `TNXToolBar`
- `TNXSpinEdit`
- `TNXDateEdit`
- `TNXTimeEdit`
- `TNXColorPicker`
- `TNXFileDialog`
- `TNXCodeEdit`

## Hardening before more widgets

The project does not need endless widget creation before the core is stable.

Before adding too many more controls, prioritize:

- focus correctness
- mouse capture correctness
- popup routing correctness
- scroll behavior
- clipping behavior
- skin state resolution
- consistent coordinate conversion

## Control implementation pattern

A typical control should:

1. inherit from `TNXControl` or a suitable derived base
2. set basic defaults in the constructor
3. override rendering methods for visual output
4. override input hooks for behavior
5. expose a minimal public API
6. use skin/theme values instead of hardcoded colors where practical

## Focus and Tab behavior

Focusable controls should set:

```pascal
CanFocus := True;
TabStop := True;
```

Non-input containers and decorative controls should usually set:

```pascal
CanFocus := False;
TabStop := False;
```

NexusUI does not use numeric `TabOrder`.

## Code editor note

A full code editor is a large project and should not be added casually.

`TNXCodeEdit` should be treated as a design decision first. It may be an enhanced memo, a lightweight syntax-aware text control, or intentionally deferred because VS Code remains the real development environment.
