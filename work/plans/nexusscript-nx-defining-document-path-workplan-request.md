# Work Plan: NexusScript Definition Source Ranges In `_nx`

## Inputs

- Source request: `C:\Users\kcollins\Downloads\nexusscript-nx-defining-document-path-workplan-request.md`.
- Related discussion: root-only source metadata is insufficient when composition, structural references, or nested definitions cause one emitted tree to contain definitions declared in different documents. JSON size is not an optimization constraint for this feature.
- Existing constraints: use NexusScript's existing source-range provenance, name the JSON members consistently with the NexusScript model, and do not expand into PasBuild or generalized provenance work.

## Summary

Expose the existing `TNexusScriptCompiledDefinition.SourceRange` in each definition object's `_nx` metadata. The emitted range identifies the source document and exact declaration range already retained by the compiler, including definitions preserved through composition, structural-reference projection, modules, includes, and discovery.

Do not introduce another defining-path field. `SourceRange.SourceName` is already the authoritative source-document identity, while its positions provide the additional provenance now required.

## Verified Findings

- `TNexusScriptRange` already contains `SourceName`, `StartPosition`, and `EndPosition`; each position contains `Offset`, `Line`, and `Column`.
- `TNexusScriptCompiledDefinition` already exposes its `SourceRange` through the compiled-model API.
- Source definitions are materialized with their original source range.
- `CloneDefinition`, `CloneDefinitionForRebinding`, `CloneDefinitionAs`, and reference-projection cloning construct definitions with the source definition's existing range. Imported, composed, projected, and structural definitions therefore already retain their declaration provenance.
- File compilation expands the filename before parsing, so `SourceRange.SourceName` is a physical expanded filename for files compiled through `CompileFile` and `TNexusScriptCompilationSession`.
- `CompileText` deliberately accepts a caller-supplied source name. Its `SourceName` is source identity and is not necessarily a filesystem path.
- `TNexusScriptJSONEmitter.DefinitionJSON` creates `_nx` metadata for direct roots, nested definitions, inline definitions, and structural definition projections.
- Named scalar and named array values may also contain `_nx`, but they are not definitions and do not own `TNexusScriptCompiledDefinition.SourceRange`.

## Architecture Problem

The compiler already preserves the required provenance, but generic JSON drops it. A downstream JSON consumer can identify a definition's kind and name but cannot determine which source declaration produced it.

Emitting provenance only on artifact roots would not describe nested definitions copied from another document by composition or emitted through structural references. Adding a separate path property would duplicate the existing range and allow two provenance values to disagree.

## Target Contract

Every JSON object emitted from a `TNexusScriptCompiledDefinition` includes its existing source range under `_nx`:

```json
{
  "_nx": {
    "Kind": "Project",
    "Name": "Example",
    "IsReference": false,
    "SourceRange": {
      "SourceName": "C:\\projects\\Example.PasBuild.nxscript",
      "StartPosition": {
        "Offset": 0,
        "Line": 1,
        "Column": 1
      },
      "EndPosition": {
        "Offset": 14,
        "Line": 1,
        "Column": 15
      }
    }
  }
}
```

- Use the model's existing names exactly: `SourceRange`, `SourceName`, `StartPosition`, `EndPosition`, `Offset`, `Line`, and `Column`.
- Copy the compiled definition's range exactly. Do not normalize, relativize, validate, or reinterpret `SourceName` in the emitter.
- Emit the range for every definition handled by `DefinitionJSON`, not only top-level artifact roots.
- A composed receiver retains the range of the receiver declaration.
- A nested definition copied through composition retains the copied definition's original range.
- A structural-reference projection retains the referenced definition's original range even when its emitted identity uses the receiving member name.
- Inline definitions retain their own declaration range.
- Do not add `SourceRange` to `_nx` objects belonging only to named scalar or named array values; those are not compiled definitions.
- Do not add a second source-path or defining-document property to `TNexusScriptCompiledDefinition`. Its current `SourceRange` remains authoritative.
- This contract exposes definition provenance only. It does not add JSON wrappers or provenance metadata for scalar properties, array values, composition contributors, or dependency declarations.

## Scope

- `NexusTools/Script/artifact/obNexusScriptJSON.pas`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- Focused fixtures only if file-backed module/include/discovery coverage cannot reuse existing fixtures
- `NexusTools/Script/README.md`

## Out Of Scope

- New fields or storage in the source or compiled NexusScript model
- PasBuild integration or `TModuleInfo` construction
- Property-level or value-level JSON provenance
- Composition-contributor history
- Dependency, module, include, or discovery redesign
- Relative-path conversion or filesystem normalization
- Source-file existence checks in the JSON emitter
- JSON size optimization, source tables, path interning, or metadata deduplication
- NexusScript grammar changes
- Language-server behavior
- Threads, caching, or indexing

## Staged Implementation Plan

### Stage 1: Serialize the existing range

1. Add a small JSON-emitter helper that converts `TNexusScriptRange` into the settled object shape.
2. Add the resulting object as `_nx.SourceRange` inside `DefinitionJSON`.
3. Leave all compiled-model and clone code unchanged because it already preserves the authoritative range.
4. Leave named scalar and named array `_nx` construction unchanged.

Verification:

- A direct definition emits all source-range members with their existing values.
- Existing `_nx.Kind`, `_nx.Name`, `_nx.IsReference`, `_nx.Reference`, and `_nx.Tags` behavior remains unchanged.
- An empty definition still contains only its `_nx` domain member, with the expanded metadata inside it.

### Stage 2: Prove provenance through existing definition paths

1. Assert that a nested definition emits its own range rather than inheriting the root's range.
2. Assert that an inline definition emits its declaration range.
3. Assert that a structural-reference projection emits the referenced definition's original range.
4. Compile a file-backed module or discovered module and prove its imported definition retains the selected document's expanded source filename in the compiled API.
5. Where the imported definition is emitted as an artifact definition through an existing artifact document path, prove JSON contains the same range.
6. Add a composition case whose nested definition originates in another document and prove that definition's emitted `SourceName` remains the contributor document while the receiver root retains its own source name.

Verification:

- Tests compare emitted values to the authoritative compiled `SourceRange`; they do not hardcode Windows-only path separators.
- File-backed tests compare `SourceName` with the appropriate `ExpandFileName` result.
- `CompileText` tests prove the supplied logical source name is copied exactly without claiming it is a physical path.

### Stage 3: Document the metadata

1. Extend the NexusScript generic JSON documentation with the `SourceRange` object.
2. State that file compilation produces an expanded physical source filename while `CompileText` preserves the caller-supplied source identity.
3. State that range metadata belongs to definition objects and is not added to named scalar or named array metadata.

## Sub-Agent Delegation

Implementation remains local to the primary Codex agent. This plan does not authorize sub-agent use; only a direct request from the human owner can do so.

## Verification Plan

Build the affected CLI and registered test module:

```text
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
```

Run the registered NexusScript compiler suite:

```text
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-suite NexusScript.Compiler
```

Focused source checks should confirm:

- `SourceRange` is serialized from the compiled definition's existing property;
- no duplicate defining-path field was added to the compiled model;
- named scalar and named array metadata were not given definition ranges;
- no PasBuild, compiler-resolution, dependency, or language-server code changed.

No manual verification is required. After an approved implementation pass, create and validate the fresh source archive required by the architecture-change protocol.

## Risks And Questions

- No human decision remains. JSON size growth from repeated definition ranges is accepted for this feature.
- `SourceName` describes source identity. It is an expanded physical filename in file-backed compilation and remains the caller-supplied identifier for `CompileText`.
- Definition-level ranges do not expose the provenance of individual scalar properties copied by composition. That is intentionally outside this request and must not be inferred from the enclosing definition range.

## Approval Gate

This plan creates no implementation authorization. Implementation begins only after the human owner explicitly approves it.
