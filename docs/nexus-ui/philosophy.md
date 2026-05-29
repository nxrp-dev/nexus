# Nexus UI Philosophy

Nexus UI favors explicit framework objects, code-first composition, and a small
set of practical controls that can be understood by reading the Pascal units.

## Code-First UI

Controls are created, configured, and composed in Pascal code. The framework
does not assume a visual designer, designer-maintained metadata, or generated
form files. A screen is ordinary source code that constructs controls, assigns
bounds or layout properties, wires events, and starts the application loop.

## Explicit Runtime Behavior

Important behavior should have one visible owner:

- `TNXApplication` owns the runtime loop and top-level event routing.
- `TNXWindow` owns the authoritative focused control for its control tree.
- `TNXPopupManager` owns active transient popup routing.
- Controls explicitly capture and release the mouse for drag-like operations.
- Text controls explicitly start and stop backend text input as focus changes.

This keeps behavior debuggable and avoids hidden framework magic.

## Backend Isolation

SDL2 is the active backend, but it is not meant to leak through application UI
code. Backend-specific work belongs behind `TNXPlatform`, `TNXCanvas`, and the
SDL2 implementation unit. Controls should draw through `TNXCanvas` and handle
Nexus event records rather than directly using SDL2 calls or event structures.

## Practical Controls

Nexus UI is driven by real application needs. The existing control set covers
common application surfaces such as menus, tabs, forms, lists, grids, text
editing, status display, popups, and dialogs. Additional controls should be
added when a real tool needs them and after shared routing, layout, focus, and
skin behavior are stable enough to support them.

## Readable Framework Code

The codebase prefers small classes, narrow parent contracts, explicit ownership,
and direct Pascal naming conventions. Useful comments explain constraints or
design decisions; they should not restate obvious code. New work should match
the existing unit structure and naming style:

- `ob` units for object and class definitions
- `tp` units for shared types and constants
- `ut` units for utilities
- `A` prefixes for arguments
- `l` prefixes for locals
- `F` prefixes for fields
