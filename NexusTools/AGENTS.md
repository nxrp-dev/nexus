# NexusTools Agent Instructions

These rules apply to `NexusTools`.

## Scope

`NexusTools` contains framework-related projects used to build, test, inspect,
package, or support Nexus itself. These are not framework runtime libraries and
not lab applications.

## Standards

- For Object Pascal / Free Pascal code, follow `../.ai/standards/pascal.md`.
- Keep tool-specific behavior inside the tool that owns it.
- Shared reusable library code belongs in `NexusLib`, not in a tool folder.

## Boundaries

- Tool projects may depend on `NexusLib`.
- Tool projects should not depend on `nexus-lab` applications.
- Do not move reusable source into `NexusTools` just because a tool currently
  needs it.
