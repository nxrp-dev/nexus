# Nexus UI Styling

Nexus UI is moving toward a skin-driven visual model. The goal is not to clone
every external theme system. The goal is enough structured styling for
consistent applications while keeping control rendering understandable.

## Skin Object

`TNXSkin` stores shared visual values and structured widget appearance data. It
is owned by `TNXApplication` and exposed to controls through their parent chain.
The current runtime supports both simple shared colors and richer widget/state
appearance lookup.

Common shared colors include:

- form background
- normal background
- text background
- foreground
- border
- selected/hot/focused color
- active/pressed color
- transparent/full transparent color

## Widget Parts and States

Structured skin lookup is based on:

```text
Skin class
Part
State
```

For example, a button can ask for its background part in a hot, focused,
pressed, disabled, or normal state. `TNXButton` already uses `GetNineSlice` for
skinned button backgrounds when the skin provides the requested part/state.

Useful skin states are defined in `TNXSkinState`:

- normal
- hot
- focused
- pressed
- disabled
- selected

Not every control needs every state.

## Appearance Data

The skin model includes appearance classes for colors, text, images,
nine-slice images, and composites. `TNXSkinMaterial` stores referenced material
data such as image file names and runtime image handles. The canvas provides
image and nine-slice drawing support.

`TNXSkin.LoadNamedSkin` loads a named skin and binds runtime resources through
the active canvas.

## Control Authoring Guidance

When writing or hardening controls:

- prefer skin values over hardcoded colors
- keep fallback rendering simple
- avoid platform-specific visual assumptions
- use control state consistently
- ask the skin for named parts/states when that path exists
- avoid making the skin system more complex than the controls that need it

## Near-Term Skin Work

The useful next improvements are:

1. define common control part names
2. define expected state fallback behavior
3. centralize appearance lookup where repeated
4. update core controls gradually
5. document required skin assets for the default skin
