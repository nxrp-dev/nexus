# Work Plan: NexusScript Include And Module Discovery

## Inputs

- Source request: `C:\Users\kcollins\Downloads\nexusscript-discover-workplan-request (2).md`.
- Related discussion: `discover` is valid only as target-selection syntax for existing `include` and `module` declarations. A declaration excludes its own declaring document from its results.
- Existing constraints: preserve current include, module, reference, compilation-session, and canonical-document behavior; do not add a discovery catalog, standalone declaration, ordering policy, cache, watcher, or concurrency mechanism.

## Summary

Extend NexusScript's existing dependency declarations with these forms:

```nexusscript
include discover "." "*.PasBuild.nxscript";
include discover recursive "." "*.PasBuild.nxscript";

module discover "." "*.Language.nxscript";
module discover recursive "." "*.Language.nxscript";
```

The folder and filename mask select zero or more documents. Each selected document then follows the existing relationship named by the declaration. Discovery does not create a language relationship of its own.

## Verified Findings

- `TNexusScriptParser.ParseModule` and `ParseInclude` in `NexusTools/Script/core/obNexusScriptCompiler.pas` currently parse direct declarations before any root definition.
- The tokenizer already emits `discover` and `recursive` as ordinary word tokens. No token kind or lexer change is required.
- `TNexusScriptSourceModule` currently owns `RootSelector`, `Path`, and `SourceRange`; `TNexusScriptSourceInclude` owns `Path` and `SourceRange` in `NexusTools/Script/core/obNexusScriptModel.pas`.
- `TNexusScriptCompilationSession.CompileDocument` in `NexusTools/Script/core/obNexusScriptSession.pas` resolves paths relative to the declaring document, compiles module and include targets, detects active-document cycles, and reuses previously compiled documents.
- A direct all-roots module calls `AddImportedDocument`; a selected-root module calls `AddImportedDefinition`. Discovery corresponds only to the existing all-roots form.
- Includes compile their target documents without adding their definitions to reference lookup.
- The artifact context already distinguishes entry, include, and module documents through the compilation session. Discovery does not need an artifact-specific path.
- NexusScriptLS currently owns document lifecycle state but does not yet analyze NexusScript source. No new language-server behavior is mechanically required.
- Compiler tests are registered in `NexusTools/Script/tests/tsNexusScriptTests.pas` and run through `NexusScriptTestModule` in the normal Nexus unit-test framework.

## Architecture Problem

An `include` or `module` declaration currently names exactly one document. Callers that need every matching project or language document in a folder would have to enumerate and repeat those declarations outside the language.

The correction belongs at the existing declaration boundary: let either declaration select files with a folder and mask, then pass each selected document into its current behavior.

## Target Contract

### Grammar

Support exactly:

```text
include discover [recursive] <folder> <mask> ;
module  discover [recursive] <folder> <mask> ;
```

- `<folder>` and `<mask>` are required.
- They use the language's existing word/string parsing rules; quoting remains necessary where those rules require it.
- `recursive` is valid only immediately after `discover`.
- There is no standalone `discover` declaration.
- Discovery does not support the direct module declaration's root selector. Every selected module contributes all of its roots, exactly like `module <path>;`.
- Existing direct `include` and `module` forms remain unchanged.

### Source model

Extend `TNexusScriptSourceInclude` and `TNexusScriptSourceModule` only enough to distinguish a direct target from a discovery target and retain:

- whether discovery is used;
- whether it is recursive;
- the declared folder;
- the declared filename mask;
- the existing declaration source range.

Keep `Path` and `RootSelector` for existing direct declarations. Do not add a general target-provider hierarchy or discovery catalog.

### Target selection

- Resolve the discovery folder relative to the declaring document using the compilation session's existing relative-document context.
- Enumerate files in that folder and, only when requested, its subfolders.
- Apply the required filename mask while enumerating candidates.
- Exclude the document containing the discovery declaration from that declaration's results.
- Do not add a discovery-specific sorting, canonicalization, deduplication, or cache pass.
- Pass selected targets directly to the existing compilation session. Its current document identity, active-file detection, and compiled-document reuse remain authoritative.
- An empty result is an empty set of relationship targets, not a missing direct dependency.
- A folder that cannot be enumerated produces a discovery diagnostic identifying the declaration and folder.
- A selected document that cannot be read or compiled fails through the same relationship path as an explicitly named include or module.

### Include behavior

For every selected document, execute the same compilation-session path as a direct include:

```nexusscript
include "selected-file.nxscript";
```

Selected definitions do not enter reference or composition lookup. They participate in compiled dependency/artifact handling only as current includes do.

### Module behavior

For every selected document, execute the same compilation-session path as an all-roots direct module:

```nexusscript
module "selected-file.nxscript";
```

All roots enter the declaring compiler's existing imported-definition path. Existing duplicate-root, reference, and composition behavior remains unchanged.

### Combined relationships

The same document may be selected by both declarations:

```nexusscript
include discover recursive "." "*.PasBuild.nxscript";
module discover recursive "." "*.PasBuild.nxscript";
```

The compilation session reuses the same compiled document while applying both existing relationships. Discovery adds no ownership or caching rule for that overlap.

## Scope

- `NexusTools/Script/core/obNexusScriptModel.pas`
- `NexusTools/Script/core/obNexusScriptCompiler.pas`
- `NexusTools/Script/core/obNexusScriptSession.pas`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- Focused discovery fixtures under `NexusTools/Script/tests/fixtures/`
- `NexusTools/Script/README.md` syntax and semantic documentation
- Project files only if a newly used standard FPC unit must be added explicitly

## Out Of Scope

- Standalone `discover`
- A discovery result catalog or public catalog API
- New reference, visibility, composition, or artifact semantics
- Selected-root module discovery
- PasBuild integration or project modeling
- General dependency-system redesign
- Package or repository discovery
- Filesystem watching or rescanning
- New caching or indexing
- Sorting or deterministic-order infrastructure
- Symlink, reparse-point, or filesystem-policy frameworks
- NexusScriptLS analysis features
- Threads, background work, or scheduling

## Staged Implementation Plan

### Stage 1: Represent and parse discovery targets

1. Add the minimal discovery fields to the existing source include and module types.
2. Branch `ParseInclude` and `ParseModule` when the first declaration word is `discover`.
3. Parse the optional `recursive` word followed by the required folder and mask.
4. Retain current parsing unchanged for direct paths and direct module root selectors.
5. Emit focused syntax diagnostics for missing folder, missing mask, or malformed discovery forms.

Verification:

- Parser tests prove all four supported forms retain the expected fields.
- Negative tests reject standalone `discover`, missing arguments, and a module selector combined with discovery.
- Existing direct declaration tests remain unchanged and pass.

### Stage 2: Route discovered includes through existing include behavior

1. Add one private compilation-session helper that enumerates the files selected by a discovery declaration.
2. Resolve the folder relative to the declaring document.
3. Skip the declaration's own document when encountered.
4. In the include loop, send every selected file through the same `CompileDocument` call used by direct includes.
5. Preserve the current include failure context and artifact participation.

Verification:

- Non-recursive discovery selects matching sibling files and ignores nonmatching files.
- Recursive discovery additionally selects matching nested files.
- A declaring document matched by its own mask is not included and does not report a dependency cycle.
- Definitions from discovered includes remain unavailable to references.
- Included artifacts remain visible through the existing artifact context.

### Stage 3: Route discovered modules through existing module behavior

1. Reuse the same enumeration helper from the module loop.
2. Compile each selected file through `CompileDocument`.
3. Add each selected compiled document through the existing `AddImportedDocument` path.
4. Leave direct selected-root module processing unchanged.

Verification:

- Non-recursive and recursive module discovery expose roots from the expected files.
- Nonmatching documents do not enter reference lookup.
- References and composition resolve through discovered module roots using existing rules.
- Existing duplicate-root behavior is preserved.
- The declaring document is excluded when its own mask matches.

### Stage 4: Prove overlap and document the syntax

1. Add a fixture where one file is selected by both include and module discovery.
2. Verify the compilation session retains one compiler for that document while both relationships take effect.
3. Update the NexusScript README with the four supported forms and their equivalence to repeated direct declarations.
4. State explicitly that no standalone form or selected-root discovery form exists.

## Sub-Agent Delegation

Implementation remains local to the primary Codex agent. This plan does not authorize sub-agent use; only a direct request from the human owner can do so.

## Verification Plan

Build the affected projects:

```text
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
lazbuild -B NexusTools\Script\ls\NexusScriptLS.lpi
lazbuild -B NexusTools\Script\ls\tests\NexusScriptLSTestModule.lpi
```

Run the registered NexusScript compiler suite:

```text
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-suite NexusScript.Compiler
```

Focused source checks should confirm:

- no standalone `discover` parser branch exists;
- both discovery forms enter the existing include/module handling paths;
- no discovery catalog, watcher, thread, or cache was added;
- no test-only executable or standalone harness was created.

No manual verification is required; the behavior is deterministic filesystem parsing covered by registered tests.

## Risks And Questions

- No human decision remains. The declaration excludes itself as a document; this does not establish a new public path-identity rule.
- Filesystem enumeration and mask matching should use the smallest standard FPC mechanism already compatible with supported Nexus platforms. Do not turn platform differences into a new filesystem abstraction.

## Approval Gate

This plan creates no implementation authorization. Implementation begins only after the human owner explicitly approves it.
