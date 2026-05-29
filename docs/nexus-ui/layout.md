# Nexus UI Layout

Layout is handled by the retained control tree. Each control has bounds,
optional alignment, optional anchors, and a parent that can lay out its
children.

## Alignment

`TNXControl.Align` uses `TNXControlAlign` from `tpNXLayout`:

```pascal
TNXControlAlign = (caNone, caTop, caBottom, caLeft, caRight, caClient);
```

Aligned children are laid out by the parent. Top, bottom, left, and right
children reserve space in that order, and `caClient` children fill the remaining
client area. Hidden aligned children are skipped.

Use alignment for panels, menus, toolbars, status bars, tab controls, and other
surfaces that should resize with their parent:

```pascal
lToolbar.Align := caTop;
lStatusBar.Align := caBottom;
lContent.Align := caClient;
```

## Anchors

`TNXControl.Anchors` uses `TNXControlAnchors` from `tpNXLayout`:

```pascal
TNXControlAnchor = (ancLeft, ancTop, ancRight, ancBottom);
TNXControlAnchors = set of TNXControlAnchor;
```

The default is left/top anchoring. Anchors apply to `caNone` controls during
parent resize callbacks. Anchoring both left and right resizes the control's
width; anchoring only right preserves distance from the parent's right edge.
Top/bottom anchors behave the same way for height.

## Sizing

Bounds are explicit. Use `MakeNXRect` for fixed initial placement and then
combine alignment or anchors where a control should follow its parent:

```pascal
lButton := TNXButton.Create(lPanel, MakeNXRect(12, 12, 100, 24));
lButton.Anchors := [ancRight, ancBottom];
```

Container controls call `LayoutChildren` when alignment-related state changes.
Controls can respond to size changes through `DoResize`.

## Split Layout

`TNXSplitter` resizes an aligned sibling region. `TNXSplitPanel` provides a
self-contained two-pane layout with `PaneA`, `PaneB`, and an internal splitter.
Use `TNXSplitPanel` when the two-pane relationship is intrinsic to the surface;
use `TNXSplitter` when resizing existing aligned siblings.

## Focus and Tab Traversal

Nexus UI does not use numeric `TabOrder`. Tab traversal is structural. A window
collects controls from the ownership tree and sorts them by:

1. top-to-bottom visual position
2. left-to-right visual position
3. ownership/child traversal
4. insertion order as a practical tie-breaker

A control participates in focus when it is visible, enabled, and
`CanFocus = True`. Structural Tab traversal also requires `TabStop = True`.

## Mouse Capture

Controls can capture the mouse during drag operations. While capture is active,
mouse motion and mouse up events route to the captured control even when the
pointer moves outside its bounds. This behavior is used by splitters, text
selection, sliders/track bars, and similar interactions.
