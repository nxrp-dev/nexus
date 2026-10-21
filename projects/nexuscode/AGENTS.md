# Nexus Pascal Agent Notes

Follow the Nexus root [AGENTS.md](../../AGENTS.md), including its rules on instruction sources.

These rules apply to `projects/nexuscode`.

## Project Direction

- Nexus Pascal is a hard fork of FPCToolkit.
- The goal is a full VS Code based Pascal IDE, not long-term compatibility with the original extension.
- Prefer clear, correct behavior over backward compatibility. When a concept is renamed or removed, remove the old concept cleanly.

## Collaboration Rules

- Verify before acting.
- When the user asks for analysis, analyze and report before editing.
- When the user says `do it`, `make it so`, or otherwise clearly confirms, implement the change and verify it.
- After analysis, confer with the user before implementation unless the user has explicitly directed the change.
- Do not defend mistakes. Acknowledge them briefly, correct course, and continue.
- Be direct. Avoid wish-casting, guessing, or presenting assumptions as facts.

## `gpt:` And `me:` Notes

- Treat `gpt:` content as external review input.
- A `gpt:` note is permission to analyze the claim, not automatic permission to implement it.
- For each material `gpt:` claim, verify against the codebase/tooling and report whether it is true, false, or partial.
- Do not play devil's advocate when asked to be skeptical. Skeptical means verify.
- Do not call a claim accurate if your evidence shows a material contradiction.
- Treat `me:` notes as the user's own opinion/preference and factor them into the recommendation.

## Implementation Preferences

- Keep removals clean. Do not leave compatibility shims unless explicitly requested.
- Avoid broad refactors while removing one feature. Remove the requested feature and adjacent dead code only.
- Do not perform opportunistic refactors; follow the root scope rules.
- Prefer structured, named settings over raw string escape hatches.
- Avoid user-configured filesystem deletion behavior.
- Do not reintroduce:
  - MCP support
  - ESLint dependency
  - `vscode-nls` dependency
  - Beyond Debug / `by-dbg` references
  - build event command hooks
  - clean project/delete-output functionality
  - custom task inheritance
  - global `nexusPascal.customOptions`
  - user-facing task `customOptions`

## Current Custom Options Split

- User-facing/global custom options have been removed.
- User-facing task custom options have been removed.

## Debugging

- Nexus Pascal builds Pascal projects.
- `cppdbg` is the VS Code debug adapter type supplied by `ms-vscode.cpptools`; it does not mean the project is C/C++.
- Debug provider registration should target `cppdbg`, not `*`.
- The current debug auto-build gate is active-editor based. A smarter project-aware gate may be revisited later.

## Tooling Note

- The project folder is `projects/nexuscode` inside the Nexus repository.

## Analysis Scope

- For Nexus Pascal work, keep analysis limited to `src` and `package.json` by default.
- Only inspect files outside `src` and `package.json` when necessary to follow behavior referenced by those sources.

## Verification

- Run `npm.cmd run compile` after TypeScript changes.
- Run `npm.cmd run esbuild` when extension runtime/bundle behavior may be affected.
- Keep `debug.log` and `dirlist-full.txt` untracked unless the user explicitly asks otherwise.
