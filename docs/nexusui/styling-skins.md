# Styling and Skins

NexusUI is moving toward a skin-driven visual model.

The goal is not to clone every feature from external theme formats. The goal is to provide enough structured styling to make applications look consistent while keeping control rendering understandable.

## Skin direction

A skin should provide reusable visual decisions for controls:

- colors
- borders
- text colors
- active/focused/disabled states
- optional images
- optional nine-slice assets
- composite appearances

Controls should increasingly ask the skin for named visual parts and states rather than directly hardcoding drawing decisions.

## Current practical model

Many controls currently use shared skin colors such as:

- form background
- normal background
- text background
- foreground
- border
- selected/hot/focused color
- active/pressed color
- transparent/full transparent color

This is a good starting point, but it should evolve toward explicit control parts.

## Target lookup shape

A future skin lookup model should answer questions like:

```text
Control class: Button
Part: background
State: hot
```

or:

```text
Control class: EditBox
Part: border
State: focused
```

This allows the same control to render consistently without knowing whether the result is a flat color, image, nine-slice, or composite appearance.

## Recommended states

Useful skin states include:

- normal
- hot
- focused
- pressed
- disabled
- selected

Not every control needs every state.

## External theme import

External theme formats can be useful as raw material, especially for colors and widget assets. NexusUI does not need full semantic import from GTK, Qt, Windows themes, or game asset packs.

A practical importer should extract:

- color palettes
- simple widget assets
- border images
- nine-slice components
- fonts, if appropriate and legally usable

Then map those assets into NexusUI's own skin model.

## Control authoring guidance

When writing controls:

- Prefer skin values over hardcoded colors.
- Keep fallback rendering simple.
- Avoid embedding platform-specific visual assumptions.
- Use control state consistently: normal, hot, focused, pressed, disabled.
- Do not make the skin system more complex than the controls that need it.

## Near-term work

The next useful skin improvements are:

1. define common control part names
2. define shared skin states
3. centralize state-to-appearance lookup
4. update core controls gradually
5. document expected fallback behavior
