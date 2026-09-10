# Work Plan: Simplify NexusScript Include And Module Pattern Syntax

## Inputs

- Source request: `C:\Users\kcollins\Downloads\nexusscript-include-module-pattern-syntax-workplan-request.md`.
- Related discussion/review notes: remove the `discover` keyword and let the existing include/module path argument select either one exact file or files matching a wildcard pattern. Preserve the existing filename-mask behavior; do not create a general glob language. Wildcard modules remain all-roots modules and cannot use a root selector.
- Existing constraints: preserve exact include/module behavior, current dependency relationships, declaring-document self-exclusion, optional recursive matching, and the normal Nexus unit-test framework. Keep this change independent of Target filtering and PasBuild.

## Summary

Replace the separate discovery syntax:

```nexusscript
include discover [recursive] <folder> <mask>;
module discover [recursive] <folder> <mask>;
```

with path-pattern forms on the existing declarations:

```nexusscript
include [recursive] <path-or-pattern>;
module [recursive] <path-or-pattern>;
```

An argument without `*` or `?` follows the existing exact-file path. An argument containing either wildcard is split into its directory and filename-mask portions and expanded through the current discovery behavior. This removes discovery-specific grammar and model state without changing what an include or module means.

## Verified Findings

- `TNexusScriptParser.ParseInclude` and `ParseModule` currently collect declaration words and then branch on a leading `discover` word.
- The existing discovery grammar stores `Discover`, `Recursive`, `DiscoverFolder`, and `DiscoverMask` in `TNexusScriptSourceInclude` and `TNexusScriptSourceModule`; both types already have the ordinary `Path` field needed by the simplified model.
- Direct modules additionally support `module RootSelector Path;`. Existing discovery deliberately supports only the all-roots module relationship.
- `TNexusScriptCompilationSession.ExpandDiscoveries` expands discovery declarations into ordinary include/module records before normal dependency compilation.
- `SelectDiscoveredFiles` already resolves the declared folder relative to the declaring document, applies an FPC `FindFirst` filename mask, optionally descends into subfolders, excludes the declaring document itself, and reports missing/enumeration failures.
- Expanded includes and modules already enter the ordinary relationship paths. Includes join artifact/dependency handling without creating reference visibility; all-roots modules add their compiled definitions through `AddImportedDocument`.
- Existing registered compiler tests cover discovery parsing, malformed declarations, non-recursive and recursive matching, empty results, missing folders, self-exclusion, include/module behavior, and a document selected through both relationships.
- The README still documents the older folder-plus-mask `discover` forms.

## Architecture Problem

Discovery is represented as a separate declaration mode even though it changes only how the existing include or module path selects physical files. That distinction creates unnecessary grammar, model fields, and session branching.

The path itself can express the selection. Exact paths identify one dependency; wildcard paths identify zero or more dependencies. After selection, the existing include or module relationship remains authoritative.

## Target Contract

### Syntax

Support these forms:

```nexusscript
include <exact-path>;
include <wildcard-path>;
include recursive <wildcard-path>;

module <exact-path>;
module <wildcard-path>;
module recursive <wildcard-path>;
module <root-selector> <exact-path>;
```

- `discover` is removed from the grammar. Old `include discover ...` and `module discover ...` declarations are invalid.
- `recursive` is optional immediately after `include` or `module` and controls descent for wildcard matching.
- A path containing neither `*` nor `?` is exact and follows the existing direct dependency behavior.
- A path containing `*` or `?` is a wildcard pattern.
- A wildcard module is always an all-roots module. `module <root-selector> <wildcard-path>;` is invalid and does not introduce selected-root wildcard behavior.
- The language's existing word/string parsing and quoting rules remain authoritative.

### Pattern interpretation

- Split a wildcard path into its directory portion and filename-mask portion using the existing platform path helpers.
- With no directory portion, search the declaring document's directory.
- Resolve an explicit directory portion relative to the declaring document through the existing dependency-path rules.
- Apply the existing `FindFirst` filename-mask behavior. Do not add globstar, wildcard directory components, brace expansion, regular expressions, or another glob engine.
- Without `recursive`, search only the resolved directory. With it, apply the same filename mask in that directory and its subdirectories.
- Continue to exclude the declaring document itself from its wildcard result.
- Preserve the current behavior for empty matches, missing folders, enumeration failures, dependency compilation failures, and session document reuse.

### Source model and session flow

- `TNexusScriptSourceInclude` retains only `Path`, `Recursive`, and `SourceRange` for this feature.
- `TNexusScriptSourceModule` retains `RootSelector`, `Path`, `Recursive`, and `SourceRange`.
- Remove `Discover`, `DiscoverFolder`, and `DiscoverMask` rather than retaining compatibility state.
- Store the declared exact path or wildcard pattern in `Path`.
- Replace discovery-specific expansion terminology with pattern expansion, but retain the existing simple operation: expand wildcard records into ordinary exact-path records before dependency compilation.
- Exact declarations bypass pattern enumeration and continue through their current code path.
- Each wildcard-selected include behaves as an ordinary `include Path;` declaration.
- Each wildcard-selected module behaves as an ordinary all-roots `module Path;` declaration.

## Scope

- `NexusTools/Script/core/obNexusScriptModel.pas`
- `NexusTools/Script/core/obNexusScriptCompiler.pas`
- `NexusTools/Script/core/obNexusScriptSession.pas`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- Existing focused discovery fixtures under `NexusTools/Script/tests/fixtures/discover/` and any affected Target fixtures
- `NexusTools/Script/README.md`

## Out Of Scope

- Target filtering or other definition-selection behavior
- PasBuild or `nxbuild` integration
- Changes to include, module, doctype, reference, composition, or artifact semantics
- Selected-root wildcard modules
- Standalone discovery declarations or a discovery catalog
- Wildcard directory segments or a new glob implementation
- Ordering, sorting, canonicalization, deduplication, caching, indexing, or filesystem watching
- Filesystem identity redesign
- NexusScriptLS analysis features
- Threads, background work, or new dependencies

## Staged Implementation Plan

### Stage 1: Simplify the source model and parser

1. Remove `Discover`, `DiscoverFolder`, and `DiscoverMask` from source include and module objects.
2. Parse optional `recursive` immediately after the `include` or `module` keyword.
3. Store the single exact path or wildcard pattern in `Path`.
4. Preserve the direct module root-selector form when its path is exact.
5. Reject missing paths, extra declaration parts, old `discover` forms, recursive selected-root forms, and selected-root wildcard modules through the existing include/module diagnostic families.

### Stage 2: Reuse the existing selection mechanics through a path pattern

1. Replace `ExpandDiscoveries` with the correspondingly named pattern-expansion operation.
2. Detect `*` or `?` in each declaration's `Path`. Leave exact declarations untouched.
3. Split a wildcard path into its directory and filename mask, using the declaring directory when no directory was specified.
4. Pass those two pieces and `Recursive` to the existing file-selection behavior.
5. Expand each match into an ordinary exact-path include or all-roots module record carrying the original declaration source range.
6. Preserve declaring-document self-exclusion and all current error/no-match behavior.

### Stage 3: Update focused tests and documentation

1. Convert parser tests from `discover` syntax to exact, wildcard, and recursive wildcard path forms.
2. Retain coverage for non-recursive matching, recursive matching, folder-qualified patterns, empty results, missing folders, self-exclusion, and combined include/module selection.
3. Prove exact include, exact all-roots module, and exact selected-root module behavior remain unchanged.
4. Add explicit rejection coverage for old `discover` syntax and selected-root wildcard modules.
5. Verify `*` and `?` select through existing filename-mask behavior without adding wildcard directory semantics.
6. Replace the README discovery section with the simplified path-pattern contract and examples.

## Sub-Agent Delegation

Implementation remains local to the primary Codex agent. This plan does not authorize sub-agent use; only a direct request from the human owner can do so.

## Verification Plan

Build the affected CLI and registered test module:

```text
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
```

Run the registered compiler suite:

```text
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-suite NexusScript.Compiler
```

Compile public consumers of the affected compiler/session API:

```text
lazbuild -B NexusTools\Script\ls\NexusScriptLS.lpi
lazbuild -B NexusTools\Script\ls\tests\NexusScriptLSTestModule.lpi
lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
```

Focused source checks should confirm:

- no parser, source-model, session, test, or current README contract retains the removed `discover` grammar or `Discover`, `DiscoverFolder`, or `DiscoverMask` state;
- wildcard expansion still uses the existing include/module relationship paths;
- selected-root wildcard modules are rejected;
- no new glob engine, ordering policy, cache, watcher, thread, or standalone test harness was added;
- Target filtering and unrelated projects were not changed for this work.

No manual verification is required because the behavior is deterministic filesystem compilation covered by the registered Nexus unit tests. After an approved implementation pass, create and validate the fresh source archive required by the architecture-change protocol.

## Risks And Questions

- No human decision remains. The plan defines wildcard characters as `*` and `?`, retains the existing filename-mask implementation, and keeps wildcard modules all-roots only.
- `recursive` on an exact path is not a meaningful operation and should be rejected rather than silently ignored.
- Platform filename-mask behavior remains the behavior already accepted by the existing feature; this work does not attempt to normalize it into a new cross-platform glob contract.

## Approval Gate

This plan and its commit do not authorize implementation. Implementation begins only after the human owner explicitly approves it.
