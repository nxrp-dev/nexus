# Nexus Repository Agent Instructions

These rules apply to the whole repository.

## AI Review Issue Labeling

- Any GitHub issue created by ChatGPT must include the label `nxrp-review-bot`.
- Treat issues labeled `nxrp-review-bot` as external AI review notes: useful input, but verify claims against the codebase before acting on them.

## Local Notifications

- When a task completes or user input is needed, run `scripts\Notify-Codex.ps1` with a spoken sentence.

## Scripts

- You may execute scripts from the /scripts folder.
- When asked for a fresh archive use the ps script New-NexusSourceArchive.ps1.

## Scope

This repository is an Object Pascal / Free Pascal project. Treat the codebase as a deliberately simple, low-dependency framework-style project. 

## Standards

- For Object Pascal / Free Pascal code, follow `.ai/standards/pascal.md`.
- Folder-level `AGENTS.md` files should explicitly reference the standards that apply to that folder.

## Project Direction

- The project includes the NexusUI style GUI framework built in Object Pascal.
- For architecture-level corrections, follow the process in `.ai/protocols/architecture-change.md`.
- Do not introduce large abstractions before they are needed.
- Prefer correct design over preserving existing code shape. Existing code and generated code have no special authority just because they already exist.
- Code does not exist for its own sake. It exists to serve the current design and purpose; when that purpose changes, adjust, reshape, or remove the code to match the new goal.
- Do not preserve code, APIs, or behavior solely for legacy or compatibility. Compatibility must be an explicit, verified, current requirement before it can justify keeping an otherwise incorrect shape.
- Prefer Kaizen: make small, coherent, verified improvements that move the project in the right architectural direction.
- Prefer removing or reshaping bad abstractions over layering workarounds on top of them.

## Generated Code Rules

- Treat ChatGPT, local LLM, and other generated output as rough-draft scaffolding.
- Generated code must compile, run where practical, and receive an architecture/integration pass before it is treated as real Nexus code.
- Broad-stroke generated controls are acceptable as first passes, but detailed behavior, lifecycle, ownership, rendering, input routing, focus/selection, and skinning must be reviewed against Nexus architecture.
- Do not preserve generated implementation details when they conflict with the project direction.
- Treat feedback prefixed with `gpt:` as external review input only. Verify claims against the codebase before acting on them.  Analyze, push back if needed and discuss.  Do not act on these statements until directed to do so.
- Use external AI review as a second-pass critique, not as a replacement for local compile/run verification or architectural judgment.

## Code Change Rules

- Keep changes narrowly scoped to the requested work unless requested otherwise.
- Do not perform opportunistic refactors.
- Do not reformat unrelated code.
- Do not rename unrelated symbols.
- Correct naming/style violations in the specific code being changed for the task.
- Do not perform broad style cleanup in nearby or unrelated code unless explicitly requested.
- Preserve APIs only when the user requests it or when a verified current external integration requirement has been identified and accepted.
- When correcting architecture or design, API changes are acceptable if they produce the correct model and all affected NexusUI/project call sites are updated.

## Simplicity Rules

- Prefer explicit ownership over implicit lifecycle assumptions.
- Prefer small, boring methods over dense multipurpose methods.
- Avoid speculative architecture.

## Collaboration Rules

- Questions, design discussion, diagnosis, and "thoughts only" requests are not work directives. Treat them as discussion, validation, or design exploration only.
- Do not infer permission to edit, build, run, refactor, or otherwise act from a question or discussion.
- Do not edit files, run builds, run tests, launch programs, or perform repository operations unless the user explicitly asks for that work to be performed.
- Treat clear imperative requests such as "fix", "integrate", "apply", "clean up", "rebuild", "commit", or "push" as work directives, even if they do not include "do it".
- Do not over-explain obvious Pascal mechanics to an experienced developer.
- Do not moralize, hedge excessively, or bury the answer in caveats.
- Be direct, practical, and specific.
- If the user asks for a bare minimum example, provide the bare minimum example.
- If the user asks for review, review the current code as provided, not an imagined ideal version.
- If information is uncertain, say so plainly instead of guessing.
- Do not guess.  Verify.  Confirm.  Do not guess.
- When the user asks a question, answer from verified knowledge. The user usually has a working hypothesis and is asking for confirmation or correction, not speculation.

## Sub-Agent Rules

- For approved architecture implementation work, follow `.ai/protocols/subagents.md`.
- Sub-agents are helpers, not authorities. Main Codex remains responsible for orchestration, integration, verification, and final reporting.
- Prefer persistent expertise roles with bounded live agent lifetimes.
- Keep sub-agents in their assigned folder or subsystem ownership.
- Close and replace unreliable, stale, or scope-drifting sub-agents instead of preserving flawed context.

## Review Rules

When reviewing code:

- Identify actual problems, not hypothetical architecture preferences.
- Separate compile-breaking issues from design concerns.
- Prefer concrete fixes over vague advice.
- Keep review comments tied to the code in front of you.

## Implementation Rules

When implementing requested changes:

- Make the smallest coherent change that accomplishes the goal.
- Match the surrounding code style.
- Use clear Pascal visibility sections.
- Keep methods short enough to read without jumping through unrelated logic.
- Do not add defensive code that obscures the main flow unless it addresses a real failure mode.
- Do not silently swallow errors unless the existing project pattern does so intentionally.

## Verification Workflow

- Compile frequently after structural changes.
- For new controls, first make them compile and run, then review for ownership, lifecycle, rendering, input routing, focus/selection, and skinning fit.
- When asked to commit, commit small, coherent checkpoints after the code compiles and the user is satisfied with the current behavior.

## Forbidden Behaviors

- Do not guess about compiler, Lazarus, LPI, or platform behavior when the answer depends on exact tool behavior.
- Do not use casts as a substitute for proper design.
- Do not convert simple code into abstract architecture for its own sake.
- Do not rename the project owner's concepts without permission.

## Default Bias

When in doubt:

1. Keep it simple.
2. Keep it narrowly scoped.
3. Centralize lifecycle and ownership.
4. When a shared concept crosses unit boundaries, place the real definition in the unit whose prefix matches what it is (`tp...` for shared type definitions, `ob...` for shared objects/classes, etc.) rather than aliasing or re-exporting it.
