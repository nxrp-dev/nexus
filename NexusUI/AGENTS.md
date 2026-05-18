# NexusUI Agent Instructions

## Scope

These rules apply to all work in this repository.

This repository is an Object Pascal / Free Pascal GUI project. Treat the codebase as a deliberately simple, low-dependency framework-style project. Prefer clear structure, explicit ownership, and boring maintainable code over clever abstractions.

## Project Direction

- The project is a SimpleGUI / NexusUI style GUI framework built in Object Pascal.
- SDL2 may be used as the current backend, but the public framework shape should not feel like an SDL demo.
- SDL-specific details should be contained behind framework objects where practical.
- Do not introduce large abstractions before they are needed.

## Language and Compatibility Rules

- This is Object Pascal / Free Pascal code.
- Keep code compatible with both Free Pascal and Delphi where practical.
- Do not use Free Pascal-only structures, containers, or language features without explicit approval.
- Respect Pascal visibility and type rules.
- Do not use clever workarounds to bypass language constraints.
- Do not use casts to bypass design or type problems unless explicitly approved.
- Do not add compatibility APIs, overloads, aliases, or convenience wrappers unless explicitly requested.
- Do not introduce dependencies or frameworks unless explicitly requested.

## Unit Naming Rules

Use the project’s intent-based unit prefixes:

- `ob` for object/class definitions.
- `ui` for GUI/forms/user-interface units.
- `dm` for data modules.
- `ut` for utility/helper functions grouped by theme.
- `tp` for types and constants.

Examples:

- `obSimpleApplication.pas`
- `obSimpleWindow.pas`
- `obSimpleControl.pas`
- `tpSimpleTypes.pas`
- `utSimpleStrings.pas`

Do not invent new naming conventions unless explicitly asked.

## Identifier Naming Rules

- Function and procedure arguments must use the `A` prefix.
  - Example: `AName`, `AValue`, `AOwner`, `ARect`.
- Local variables must use the lowercase `l` prefix, with no exceptions.
  - Example: `lIndex`, `lEvent`, `lWindow`.
- Class fields should use the `F` prefix.
  - Example: `FRunning`, `FMainWindow`, `FRenderer`.
- Constants should use the `c` prefix where practical.
  - Example: `cDefaultWidth`, `cDefaultHeight`.
- Preserve existing project naming unless a requested cleanup explicitly changes it.

## Class Structure Rules

- Fields belong in `private`.
- Behavior getters and setters belong in `protected`.
- Properties belong in `public`.
- Trivial getters and setters should be replaced by direct field-backed properties.
- Use properties to expose state intentionally.
- Do not expose fields directly.
- Keep constructors and destructors simple.
- Avoid lifecycle magic hidden in unrelated methods.

Preferred property shape:

```pascal
private
  FCaption: string;

public
  property Caption: string read FCaption write FCaption;
```

Use protected getters/setters only when behavior is actually needed:

```pascal
private
  FVisible: Boolean;

protected
  procedure SetVisible(AValue: Boolean); virtual;

public
  property Visible: Boolean read FVisible write SetVisible;
```

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

- The coding agent's standing name in this repository is Nex. Use Nex when distinguishing this agent from other AI tools or reviewers.
- References to GPT, ChatGPT, the other AI, or feedback prefixed with `gpt:` refer to an external reviewer, not Nex.
- Questions are not work directives. Treat them as discussion, validation, or design exploration only.
- If the user asks a question, answer the question only. Do not infer permission to inspect, edit, build, run, refactor, or otherwise act from the question.
- Do not edit files, run builds, run tests, launch programs, or perform repository operations unless the user explicitly asks for that work to be performed.
- The user may ask several questions while validating their own thinking. Wait for an explicit implementation request such as "do it", "make the change", "implement this", "run it", or equivalent before taking action.
- Do not make unsolicited design commentary.
- Do not refer to inherited or original code as "my code" when speaking to the project owner.
- Do not over-explain obvious Pascal mechanics to an experienced developer.
- Do not moralize, hedge excessively, or bury the answer in caveats.
- Be direct, practical, and specific.
- If the user asks for a bare minimum example, provide the bare minimum example.
- If the user asks for pseudocode, provide pseudocode only.
- If the user asks for review, review the current code as provided, not an imagined ideal version.
- If information is uncertain, say so plainly instead of guessing.
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
6. Ask only when the missing detail blocks the work.
7. Do not guess.
