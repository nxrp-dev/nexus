# Work Plan: NexusScript Target-Based Compilation Filtering

## Inputs

- Source request: `work/requests/nexusscript-target-filtering-workplan-request.md`, corrected from `C:\Users\kcollins\Downloads\nexusscript-target-filtering-workplan-request (2).md`.
- Related discussion: bracket lists were always intended to declare compile targets. The current `Tags` terminology and general-purpose-classification documentation reflect an incorrect interpretation and are not a compatibility requirement.
- Existing constraints: preserve untargeted compilation as the complete model, filter before composition and effective-value resolution, use one selected Target throughout the complete compilation graph, keep the parsed source model intact, and do not include PasBuild work.

## Summary

Correct the existing bracket-list feature from the misnamed `Tags` contract to `Targets`, then complete its intended behavior by allowing a compiler or compilation session to select one optional Target. An untargeted compiler produces the current complete model. A targeted compiler copies only applicable definitions into the compiled model, recursively and before composition or value binding.

The selected Target belongs to the compiler/session instance and is immutable for that instance. A compilation session supplies it to every compiler created for the entry document, doctypes, modules, includes, and discovered documents. This gives the entire dependency graph one consistent selection context without mixing target-specific compiled documents in the session's filename-based compiler cache.

## Verified Findings

- The parser already accepts a nonempty bracket list following a definition header and stores its decoded values in `TNexusScriptSourceDefinition.Tags`.
- Source and compiled definitions each own a case-sensitive `TStringList`; source-to-compiled copying and compiled clone/projection paths preserve the list.
- The current parser variables, diagnostics, model properties, tests, artifact metadata, JSON output, and README incorrectly call the values tags. Parser diagnostics `NXS3005` and `NXS3006` describe empty and duplicate tag clauses.
- `TNexusScriptArtifactMetadata` is a typed RTTI JSON object. Its published `Tags` property currently produces `_nx.Tags`; the corrected fixed contract must remain typed and become `_nx.Targets` without free-form JSON construction.
- `TNexusScriptCompiler.CompileSource` first constructs compiled roots from imported and local definitions, then performs composition, and finally binds/evaluates definitions. The source-to-compiled construction boundary is therefore the existing place to apply filtering.
- Direct child definitions and inline structural definitions are copied recursively from the parsed source model. Compiled definitions are also cloned for imports, composition, rebinding, and structural-reference projection.
- `TNexusScriptCompilationSession` recursively compiles doctypes, modules, includes, and discoveries. Its compiler cache is keyed by source filename, so a session must not contain compiled documents produced for different selected Targets.
- A compilation session may compile multiple entry files during its lifetime, while dependency compilers are reused by filename. An immutable session Target keeps those cached results coherent.
- The validator assigns no policy meaning to the bracket list. Target selection belongs to compilation and requires no dialect-validator rule.
- The registered `NexusScript.Compiler` suite already covers parsing, preservation through composition/import/projection, JSON metadata, sessions, doctypes, modules, includes, and discovery, providing the appropriate test home for this work.

## Architecture Problem

NexusScript parses and preserves Target declarations but never uses them to select a compiled model. Every definition is currently materialized, composed, and resolved regardless of the requested build target. The implementation and public metadata also describe Targets as general-purpose tags, obscuring their intended language contract.

Filtering after composition would be incorrect: excluded definitions could contribute properties or children before being removed, and references could bind through definitions that do not belong to the selected Target. Mutating the parsed tree would also destroy the complete source representation needed by tooling and diagnostics.

The selected Target must apply to the whole compilation graph. Supplying different Targets to documents within one session, or changing the Target while retaining filename-only cached compilers, would combine incompatible compiled models.

## Target Contract

- The bracket list on a definition is its ordered list of `Targets`.
- Target spelling and identity remain case-sensitive and use the existing decoded NexusScript word/string rules.
- No selected Target means untargeted compilation. Every definition is included and its declared Targets remain present in the compiled model and emitted metadata.
- With a selected Target, a definition is included when its Target list is empty or contains an exact case-sensitive match for the selected Target.
- Multiple declared Targets use OR semantics.
- Filtering occurs while converting parsed source definitions into compiled definitions, before duplicate imported/local collision handling, composition, reference resolution, array preparation, and effective-value evaluation consume the compiled model.
- The parsed `TNexusScriptSourceDocument` remains complete and unchanged, including definitions excluded from its compiled counterpart.
- Filtering is recursive. It applies to root definitions, direct child definitions, and inline structural definitions at every supported nesting depth.
- Excluding a direct child omits that child from its compiled parent. Excluding an inline structural definition omits the value or array entry that contains that definition; it does not leave an invalid compiled placeholder.
- Imported documents arrive already filtered by a compiler using the same selected Target. Existing compiled clone, composition, rebinding, and projection paths preserve the Targets of retained definitions and do not perform a second selection pass.
- A reference or composition selector that names an excluded definition follows the existing unresolved-reference or unresolved-composition diagnostic path. Exclusion itself is not a diagnostic.
- Doctype documents receive the same selected Target as every other document. There is no target syntax or override on a doctype declaration.
- The selected Target is immutable configuration of a `TNexusScriptCompiler` or `TNexusScriptCompilationSession`. Existing parameterless construction creates an untargeted instance.
- A compilation session creates all of its document compilers with its selected Target, keeping its filename-keyed cache internally consistent across entry, doctype, module, include, and discovery traversal.
- Rename the public/model contract from `Tags` to `Targets`. Remove the incorrect `Tags` model and metadata names rather than retaining aliases or compatibility output.
- Preserve diagnostic codes `NXS3005` and `NXS3006`, but correct their messages and related parser identifiers from tag to Target terminology.
- Emit retained Target declarations through the typed artifact metadata model as `_nx.Targets`. A domain property named `Targets` remains an ordinary domain property and does not conflict with `_nx.Targets`.

## Scope

- `NexusTools/Script/core/obNexusScriptModel.pas`
- `NexusTools/Script/core/obNexusScriptCompiler.pas`
- `NexusTools/Script/core/obNexusScriptSession.pas`
- `NexusTools/Script/artifact/obNexusScriptArtifactModel.pas`
- `NexusTools/Script/artifact/obNexusScriptJSON.pas`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- Focused file-backed fixtures under `NexusTools/Script/tests/fixtures/` as required for cross-document and discovery coverage
- `NexusTools/Script/README.md`

## Out Of Scope

- PasBuild integration or changes under `lib/pasbuild`
- `nxbuild` project modeling, planning, command-line behavior, or execution
- NexusScript grammar changes or new keywords
- Multiple simultaneously selected Targets, AND expressions, negation, dimensions, priorities, fallbacks, or target inheritance
- Target selection on module, include, doctype, discover, property, or data declarations
- Validator policy for Targets
- Dependency ordering, discovery ordering, reference lookup, or composition-rule redesign
- Compatibility aliases named `Tags` or duplicate `_nx.Tags` output
- Language-server filtering behavior
- Threads, caching systems, or new dependencies

## Staged Implementation Plan

### Stage 1: Correct the Target contract terminology

1. Rename source and compiled definition storage and properties from `Tags` to `Targets`, retaining the existing case-sensitive owned lists and declaration order.
2. Rename parser locals and correct parser diagnostic text to say Target. Keep the existing diagnostic codes for the same malformed bracket-list cases.
3. Update every source-to-compiled copy and compiled clone/projection path to use `Targets`, preserving the current local-declaration behavior through composition and the current copy ownership.
4. Rename the typed artifact metadata property from `Tags` to `Targets` and populate it through the existing RTTI-backed artifact object so emitted metadata becomes `_nx.Targets`.
5. Correct test names, assertions, fixture text where appropriate, and README terminology. Document Targets as compile-time selection criteria rather than general-purpose classification.
6. Remove remaining Target-feature identifiers or prose using the incorrect tag terminology. Do not rename unrelated domain properties or unrelated uses of the word target, such as reference targets.

### Stage 2: Add immutable compilation Target configuration

1. Give `TNexusScriptCompiler` an optional selected Target established at construction, with a read-only property for inspection. Parameterless construction remains untargeted.
2. Give `TNexusScriptCompilationSession` the same optional construction-time Target and expose it read-only.
3. Construct every compiler owned by a session with the session's selected Target, including compilers reached through doctype, module, include, and discovery traversal.
4. Keep the existing compile method call shapes unchanged; the compiler/session instance supplies the selection context. Do not add mutable per-call state that could invalidate filename-cached compiler results.

### Stage 3: Filter during compiled-model construction

1. Add one exact, case-sensitive applicability check: untargeted compilation, no declared Targets, or a declared Target matching the selected Target.
2. Apply that check as source definitions are copied into the compiled document. Skip excluded roots before they can participate in imported/local collision checks, composition, or binding.
3. Apply the same check recursively while copying direct children.
4. Apply it while copying inline structural-definition values, omitting an excluded inline value or array entry cleanly from its containing compiled property/value.
5. Leave compiled-to-compiled clone paths selection-neutral because their input has already been filtered within the same compilation Target.
6. Preserve retained definitions' complete Target lists in the compiled model; selection does not erase metadata.

### Stage 4: Prove selection semantics and pipeline placement

1. Extend the existing definition-target test to prove source and compiled `Targets` ownership, order, spelling, case sensitivity, and preservation through imports, composition, nested definitions, inline definitions, and structural projections.
2. Add direct compiler cases for untargeted compilation, an untargeted definition, one Target, multiple Target OR membership, exact matching, nonmatching, and case-mismatched selection.
3. Prove the parsed source document still contains a definition excluded from the compiled document.
4. Prove recursive filtering for direct children and inline definitions, including omission of excluded inline array entries without placeholders.
5. Add file-backed session coverage proving the same selected Target reaches explicit modules, includes, discovered modules/includes, and doctype documents.
6. Add composition coverage proving a selected receiver can compose a matching retained definition and that composition naming an excluded definition produces the existing unresolved-composition diagnostic.
7. Update artifact tests to prove untargeted and targeted retained definitions emit `_nx.Targets`, excluded definitions are absent, `_nx.Tags` is absent, and an ordinary domain `Targets` property remains separate.

### Stage 5: Document the completed behavior

1. Replace the README's definition-tags section with the Target declaration and selection contract.
2. Document untargeted versus targeted compiler/session construction, universal untargeted definitions, OR membership, case-sensitive identity, recursive filtering, dependency propagation, and filtering before composition.
3. Document `_nx.Targets` as retained declaration metadata and remove `_nx.Tags` from the public artifact contract.

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

Focused source checks should confirm:

- no Target-feature model property, parser diagnostic, artifact property, test name, or documentation contract still uses `Tag`, `Tags`, `_nx.Tags`, or equivalent tag terminology;
- `_nx.Targets` is supplied by the typed RTTI artifact model rather than free-form JSON construction;
- the applicability check executes only on source-to-compiled construction paths and precedes composition and binding;
- every compiler created by a compilation session receives the same immutable selected Target;
- no PasBuild, `nxbuild`, language-server, validator-policy, threading, or unrelated subsystem code changed.

No standalone test harness or manual verification is required. After an approved implementation pass, create and validate the fresh source archive required by the architecture-change protocol.

## Risks And Questions

- No human decision remains in the requested semantics.
- A compilation session cannot change Targets after construction. Callers needing another Target create another session, which prevents mixed-target results in the existing filename-based cache.
- Because filtering precedes composition and resolution, selectors naming excluded definitions fail normally. Tests must distinguish this intended consequence from a filtering defect.
- Recursive filtering of inline definitions removes their containing inline value or array entry. This is the only coherent compiled representation of an excluded inline definition and must be covered directly.
- The terminology correction intentionally changes the emitted metadata contract from `_nx.Tags` to `_nx.Targets`; no compatibility duplicate is retained because the former name represented an incorrect, unneeded contract.

## Approval Gate

This plan and its commit do not authorize implementation. Implementation begins only after the human owner explicitly approves it.
