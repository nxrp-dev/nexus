# NexusUI Agent Instructions

## Scope

These rules apply to all work in this repository.

This repository is an Object Pascal / Free Pascal GUI project. Treat the codebase as a deliberately simple, low-dependency framework-style project. Prefer clear structure, explicit ownership, and boring maintainable code over clever abstractions.

## Project Direction

- The project is a NexusUI style GUI framework built in Object Pascal.
- SDL2 may be used as the current backend, but the public framework shape should not feel like an SDL demo.
- SDL-specific details should be contained behind framework objects where practical.
- Do not introduce large abstractions before they are needed.
- Prefer correct design over preserving existing code shape. Existing code and generated code have no special authority just because they already exist.
- Prefer Kaizen: make small, coherent, verified improvements that move the project in the right architectural direction.
- Prefer removing or reshaping bad abstractions over layering workarounds on top of them.

## Generated Code Rules

- Treat ChatGPT, local LLM, and other generated output as rough-draft scaffolding.
- Generated code must compile, run where practical, and receive an architecture/integration pass before it is treated as real NexusUI code.
- Broad-stroke generated controls are acceptable as first passes, but detailed behavior, lifecycle, ownership, rendering, input routing, focus/selection, and skinning must be reviewed against NexusUI architecture.
- Do not preserve generated implementation details when they conflict with the project direction.
- Treat feedback prefixed with `gpt:` as external review input only. Verify claims against the codebase before acting on them.

## NexusUI Architecture Rules

- `TNXApplication` owns application/runtime lifecycle.
- Windows are first-class UI surfaces managed by the application/window manager.
- Controls are renderable and/or interactable UI objects.
- Container controls such as panels and group boxes are still controls.
- Avoid vague middle layers that blur application, window, and control responsibilities.
- Parent relationships should use the CORBA-style `INXControlParent` interface and must not imply reference-counted ownership.
- Keep parent interfaces narrow. Do not add host-specific behavior to generic parent contracts just because one child wants it.
- Child controls should not manipulate parent-specific concepts such as parent window movement or parent selection state. Use explicit callbacks/events or owner-managed state instead.
- Defer destruction when closing/removing controls during event dispatch.

## Persistence and Object Model Rules

- For structured framework data, design the correct Object Pascal object graph first, then persist that graph.
- RTTI and published properties are intentional modeling tools in this project, not reluctant fallbacks.
- Persisted lists that may contain descendants must preserve per-item class/type identity and reconstruct the correct descendant.
- Persistence aliases may be used for clean external names, but the default identity is the real Pascal class name.
- Do not let text storage leak into the internal model. For example, binary data is stored as binary and exposed through a published base64 property only at the persistence boundary.
- Tests for persistence should prefer construct, stream out, stream in, stream out, and byte-compare the two outputs, plus semantic checks.
- Avoid vague dynamic side channels. If dynamic attributes are needed, model them explicitly with a published `TStringList` or a real persisted object/list.

## Language and Compatibility Rules

- This is Object Pascal / Free Pascal code.
- Keep code compatible with both Free Pascal and Delphi where practical.
- Respect Pascal visibility and type rules.
- Do not use clever workarounds to bypass language constraints.
- Do not use casts to bypass design or type problems unless explicitly approved.
- Do not add compatibility APIs, overloads, aliases, or convenience wrappers unless explicitly requested.
- Do not introduce dependencies or frameworks unless explicitly requested.

## Unit Naming Rules

Use the project’s intent-based unit prefixes:

- `ob` for object/class definitions.
- `ui` for GUI/forms/user-interface units.
- `ut` for utility/helper functions grouped by theme.
- `tp` for types and constants.

Do not invent new naming conventions unless explicitly asked.

## Shared Definition Ownership Rules

- Do not use type aliases as convenience wrappers or compatibility shims.
- Shared definitions must have one real source of truth.
- If shared definitions are type declarations, constants, enums, records, or other pure type-level data, move the real definitions into an appropriate `tp...` unit and have each consumer use that unit directly.
- If shared definitions are object/class implementations, move the real definitions into an appropriate `ob...` unit and have each consumer use that unit directly.
- Do not re-export enum values, constants, type names, or classes from another unit to avoid updating `uses` clauses.

## Identifier Naming Rules

- Function and procedure arguments must use the `A` prefix.
  - Example: `AName`, `AValue`, `AOwner`, `ARect`.
- Local variables must use the lowercase `l` prefix, with no exceptions.
  - Example: `lIndex`, `lEvent`, `lWindow`.
- Class fields should use the `F` prefix.
  - Example: `FRunning`, `FMainWindow`, `FRenderer`.
- Constants should use the `c` prefix where practical.
  - Example: `cDefaultWidth`, `cDefaultHeight`.

## Class Structure Rules

- Fields belong in `private`.
- Behavior getters and setters belong in `protected`.
- Properties belong in `public`.
- Trivial getters and setters should be replaced by direct field-backed properties.
- Use properties to expose state intentionally.
- Do not expose fields directly.
- Keep constructors and destructors simple.
- Avoid lifecycle magic hidden in unrelated methods.
- Use protected getters/setters only when behavior is actually needed:

## Function Return Rules

- Use `Result` for function return values.
- Do not assign return values to the function name.

## Code Change Rules

- Keep changes narrowly scoped to the requested work.
- Do not perform opportunistic refactors.
- Do not reformat unrelated code.
- Do not rename unrelated symbols.
- Always correct naming/style rule violations in code being touched, even if not separately requested.
- When making those incidental corrections, inform the user and verify the change did not break anything.
- Do not change the public API unless explicitly requested or clearly required by the task.
- If a rewrite is requested, preserve the original public API as much as reasonably possible.

## Simplicity Rules

- Prefer straightforward Pascal over clever generic tricks.
- Prefer explicit ownership over implicit lifecycle assumptions.
- Prefer small, boring methods over dense multipurpose methods.
- Avoid speculative architecture.
- Avoid unnecessary interfaces, event buses, factories, adapters, or managers.
- Do not introduce a message/event abstraction until the existing event flow requires it.

## SDL / Backend Rules

- SDL2 is an implementation detail where possible.
- Application-level code may know about SDL during early normalization, but the long-term direction is to keep backend details contained.
- Rendering should be routed through framework objects rather than ad hoc drawing in startup code.
- Do not hide SDL behind excessive abstraction prematurely.

## Collaboration Rules

- Questions are not work directives. Treat them as discussion, validation, or design exploration only.
- If the user asks a question, answer the question only. Do not infer permission to inspect, edit, build, run, refactor, or otherwise act from the question.
- Do not edit files, run builds, run tests, launch programs, or perform repository operations unless the user explicitly asks for that work to be performed.
- The user may ask several questions while validating their own thinking. Wait for an explicit implementation request such as "do it", "make the change", "implement this", "run it", or equivalent before taking action.
- Do not make unsolicited design commentary.
- Do not over-explain obvious Pascal mechanics to an experienced developer.
- Do not moralize, hedge excessively, or bury the answer in caveats.
- Be direct, practical, and specific.
- If the user asks for a bare minimum example, provide the bare minimum example.
- If the user asks for review, review the current code as provided, not an imagined ideal version.
- If information is uncertain, say so plainly instead of guessing.
- References to GPT, ChatGPT, the other AI, or feedback prefixed with `gpt:` refer to an external reviewer.
- Treat feedback prefixed with `gpt:` as ChatGPT review input only, not as a work directive.
- Treat all `gpt:` claims with skepticism: verify claims against the codebase, judge whether the feedback is useful, and confirm with the user before making any changes based on it.

## Review Rules

When reviewing code:

- Identify actual problems, not hypothetical architecture preferences.
- Separate compile-breaking issues from design concerns.
- Prefer concrete fixes over vague advice.
- Do not suggest framework-level rewrites unless the current code is structurally blocking the requested goal.
- Keep review comments tied to the code in front of you.

## Implementation Rules

When implementing requested changes:

- Make the smallest coherent change that accomplishes the goal.
- Keep the public API relatively stable unless instructed otherwise.
- Match the surrounding code style.
- Use clear Pascal visibility sections.
- Keep methods short enough to read without jumping through unrelated logic.
- Do not add defensive code that obscures the main flow unless it addresses a real failure mode.
- Do not silently swallow errors unless the existing project pattern does so intentionally.

## Verification Workflow

- Compile frequently after structural changes.
- For new controls, first make them compile and run, then review for ownership, lifecycle, rendering, input routing, focus/selection, and skinning fit.
- For large generated controls, do not confuse "broadly works" with "architecturally integrated."
- Commit small, coherent checkpoints after the code compiles and the user is satisfied with the current behavior.
- Use external AI review as a second-pass critique, not as a replacement for local compile/run verification or architectural judgment.

## Forbidden Behaviors

- Do not guess about compiler, Lazarus, LPI, or platform behavior when the answer depends on exact tool behavior.
- Do not invent configuration keys or project settings.
- Do not claim a change will work unless it is grounded in known behavior or verified context.
- Do not use casts as a substitute for proper design.
- Do not add backward compatibility shims without being asked.
- Do not convert simple code into abstract architecture for its own sake.
- Do not rename the project owner’s concepts without permission.

## Default Bias

When in doubt:

1. Keep it simple.
2. Keep it Pascal-compatible.
3. Keep it narrowly scoped.
4. Preserve the public API.
5. Centralize lifecycle and ownership.
6. When a shared concept crosses unit boundaries, place the real definition in the unit whose prefix matches what it is (`tp...` for shared type definitions, `ob...` for shared objects/classes, etc.) rather than aliasing or re-exporting it.
7. Ask only when the missing detail blocks the work.
8. Do not guess.
