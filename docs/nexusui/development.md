# Development Notes

These notes describe how NexusUI should be developed and reviewed.

## Code-first UI

NexusUI is intended for code-first UI construction.

Controls should be created, configured, and composed in Pascal code. The framework should not assume a visual designer or designer-maintained metadata.

## Keep behavior explicit

Prefer simple explicit behavior over hidden framework magic.

Examples:

- one focused control per window
- structural Tab traversal rather than numeric `TabOrder`
- explicit popup routing before normal windows/root controls
- explicit mouse capture for drag operations
- explicit text input start/stop for text controls

## Comments and naming

Prefer self-documenting code and clear names.

Comments are most useful when they explain an external constraint, a design decision, or a non-obvious platform behavior. Avoid comments that merely restate the code.

## Compatibility expectations

NexusUI should use Pascal code that remains friendly to FreePascal and Delphi where practical.

Avoid FreePascal-only structures unless the tradeoff is intentional.

## Common naming conventions

Project conventions used elsewhere in Nexus work include:

- local variables use `l` prefix
- function arguments use `A` prefix
- constants use `c` prefix where appropriate
- object/class units commonly use `ob` prefix
- type/constants units commonly use `tp` prefix
- utility units commonly use `ut` prefix

Follow the existing unit style unless there is a specific reason not to.

## Review workflow

For GitHub issues created by ChatGPT review work, apply the label:

```text
nxrp-review-bot
```

Issues with that label are external review notes. They should be verified against the codebase before implementation.

## Good task shape

Good implementation tasks are small and concrete:

- fix focus rejection for invisible controls
- route mouse wheel using coordinate helpers
- update one control to use skin state lookup
- add one first-pass control
- write one design note before implementation

Avoid broad tasks like "finish the UI framework" or "make all controls perfect."

## Build and verification

This documentation does not replace local builds.

Useful checks include:

- compile the Lazarus/FreePascal project
- run a small demo app
- exercise mouse capture
- test focus traversal
- test popup open/close behavior
- test text input focus/loss
- test scroll wheel behavior

If CI is added later, it should at least compile the core units and any sample/demo project that can run headless or without a display dependency.
