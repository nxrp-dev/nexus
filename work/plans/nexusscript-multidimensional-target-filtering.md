# Work Plan: NexusScript Multidimensional Target Filtering

## Inputs

- Source request: conversation request of September 12, 2026, supported by `C:\Users\kcollins\Downloads\nexusscript-target-filtering-workplan-request (2).md`.
- Related discussion/review notes: the current single selected Target is only the first dimension of the intended system. Target kinds are named, freeform NexusScript identifiers such as `Target` and `Platform`. Values within one target kind use OR semantics. Selected target kinds filter independently; target kinds not selected by the compiler remain unfiltered.
- Existing constraints: retain filtering before composition and effective-value resolution, keep the parsed source model complete, preserve case-sensitive identity, apply one immutable selection context throughout a compilation session, use typed model and RTTI-backed artifact objects, and do not include PasBuild or CLI work.

## Summary

Reshape the existing flat, single-dimensional Target implementation into a named multidimensional Target system.

A definition may declare any number of named Target clauses after its name:

```nexusscript
ATask SomeTask Target[Dev, QA] Platform[Windows] {
}
```

`Target` and `Platform` are ordinary, case-sensitive Target-kind names. Each clause contains one or more case-sensitive values. A compilation selection may select a value for any subset of the named Target kinds. Each selected kind filters independently; an unselected kind imposes no filtering. Values within a clause use OR semantics, while all selected kinds applicable to a definition must match.

The existing source-to-compiled filtering location and dependency propagation remain correct. The work replaces the flat definition value list and single selected string with typed named Targets and a named selection context, then adapts the parser, copying, metadata, and focused tests around that corrected model.

## Verified Findings

- The current working tree has already renamed the feature from `Tags` to `Targets` in the parser, source model, compiled model, typed artifact metadata, JSON emitter, tests, and documentation.
- `TNexusScriptSourceDefinition.Targets` and `TNexusScriptCompiledDefinition.Targets` are currently case-sensitive `TStringList` instances containing only flat Target values.
- The current grammar accepts one anonymous bracket clause immediately after a definition name, such as `Thing Example[Dev, QA]`.
- `TNexusScriptCompiler` and `TNexusScriptCompilationSession` currently receive one immutable `SelectedTarget: string` through their constructors.
- `DefinitionAppliesToTarget` currently retains a definition when compilation is untargeted, the definition has no values, or its flat value list contains the selected string.
- Filtering already occurs during source-to-compiled construction. It covers roots, direct children, inline structural definitions, and inline array entries before composition and binding.
- A compilation session already gives its selected Target to every compiler created for entry, doctype, module, include, and discovered documents.
- Existing compiled clone, import, composition, rebinding, projection, and artifact paths preserve retained Target data after the initial filtering boundary.
- Existing tests cover flat Target parsing, case-sensitive identity, filtering, nested and inline definitions, dependency propagation, composition failure through excluded definitions, and typed `_nx.Targets` emission.
- The current Target implementation is uncommitted and shares the working tree with the separate include/module pattern implementation. The multidimensional change must preserve those unrelated working-tree changes.

## Architecture Problem

The filtering pipeline is in the correct location, but its data model assumes that every Target value belongs to one unnamed dimension. Consequently, `Dev` and `Windows` cannot be distinguished as values of different Target kinds, and the compiler can select only one string for the entire compilation.

Treating all values as one flat set cannot express the required relationship:

```nexusscript
ATask SomeTask Target[Dev, QA] Platform[Windows] {
}
```

The definition should be selectable independently by build Target and Platform. Flattening the declaration would incorrectly make `Dev`, `QA`, and `Windows` alternatives in one dimension. Likewise, requiring every declared kind to have a selected value would make partial compilation destructive and force callers to know every freeform Target kind used by a dialect.

The model therefore needs named Target clauses on definitions and named Target selections on a compiler/session. The existing source-to-compiled boundary can then evaluate only the kinds actually selected by the caller.

## Target Contract

### Declaration syntax

- A definition may carry zero or more named Target clauses after its name and composition selectors and before its body.
- Each clause has a Target-kind name followed by a nonempty bracketed value list:

  ```nexusscript
  ATask SomeTask Target[Dev, QA] Platform[Windows] {
  }
  ```

- Target-kind names and values follow the existing NexusScript word/quoted-string rules where those tokens are supported by the definition-header grammar. This work does not create a separate identifier grammar.
- Target-kind names and values are case-sensitive.
- Values retain declaration order and decoded spelling.
- An empty clause remains invalid. Duplicate values within the same clause remain invalid.
- Repeated clauses with the same Target-kind name are preserved and contribute to the same OR set for matching. No additional duplicate-kind restriction is introduced.
- The former anonymous syntax, such as `SomeTask[Dev]`, is replaced by an explicitly named clause such as `SomeTask Target[Dev]`. No compatibility alias or implicit Target-kind name is retained.

### Selection and matching

- A compilation selection is a case-sensitive set of Target-kind name/value pairs, with at most one selected value for each kind.
- No selected pairs means completely untargeted compilation and produces the full compiled model.
- Each selected kind filters independently.
- If a definition has no clause for a selected kind, that selected kind does not restrict the definition.
- If a definition has one or more clauses for a selected kind, at least one value across those clauses must exactly match the selected value.
- Clauses whose kinds are not selected by the compiler are not evaluated and do not restrict the definition.
- A definition is retained only when it satisfies every selected kind for which it declares a clause.
- These rules produce OR behavior within a named kind and AND behavior across the selected named kinds that the definition restricts.

Given:

```nexusscript
ATask Example Target[Dev, QA] Platform[Windows] {
}
```

- `Target=Dev, Platform=Windows` retains it.
- `Target=QA, Platform=Windows` retains it.
- `Target=Prod, Platform=Windows` excludes it.
- `Target=Dev, Platform=Linux` excludes it.
- `Target=Dev` retains it because `Platform` was not selected.
- `Platform=Windows` retains it because `Target` was not selected.
- no selections retain it because the compilation is unfiltered.

### Ownership and propagation

- Source and compiled definitions each own their typed Target collections.
- A Target entry owns its name and ordered value collection.
- A compiler and compilation session each own an immutable copy of their named selection context. Caller mutation cannot change an active compiler or invalidate a session's filename-keyed compiler cache.
- A session supplies the same complete selection context to every compiler it creates for entry, doctype, module, include, and discovered documents.
- The parsed source document remains complete and unchanged. Only compiled-model construction filters definitions.
- Filtering remains recursive for root, child, and inline structural definitions at every supported nesting level.
- Compiled-to-compiled copying does not reevaluate selection. It preserves the named Target declarations of definitions already retained by the source-to-compiled boundary.
- Exclusion itself is not a diagnostic. Existing unresolved-reference and unresolved-composition diagnostics remain responsible when retained definitions name excluded definitions.

### Artifact metadata

- Retained declarations are emitted through the typed RTTI artifact model under `_nx.Targets`.
- `_nx.Targets` becomes an ordered array of typed named Target entries. Each entry contains its `Name` and ordered `Values`.
- Example conceptual output:

  ```json
  "Targets": [
    { "Name": "Target", "Values": ["Dev", "QA"] },
    { "Name": "Platform", "Values": ["Windows"] }
  ]
  ```

- This shape is produced by typed Pascal artifact objects and normal RTTI serialization. The emitter must not construct or manipulate free-form JSON.
- Definitions without Target clauses omit `_nx.Targets` according to the existing optional metadata behavior.
- A domain property named `Targets` remains ordinary compiled content and remains separate from `_nx.Targets`.

## Scope

- `NexusTools/Script/core/obNexusScriptModel.pas`
- `NexusTools/Script/core/obNexusScriptCompiler.pas`
- `NexusTools/Script/core/obNexusScriptSession.pas`
- `NexusTools/Script/artifact/obNexusScriptArtifactModel.pas`
- `NexusTools/Script/artifact/obNexusScriptJSON.pas`
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
- Focused Target fixtures under `NexusTools/Script/tests/fixtures/targets/`
- `NexusTools/Script/README.md`

## Out Of Scope

- PasBuild or `nxbuild` integration
- Command-line selection syntax or CLI redesign
- Package management or dependency-resolution changes
- Doctype-specific Target syntax or behavior
- Target declarations on properties, data declarations, module declarations, include declarations, or doctype references
- Validator policy for Target kinds or values
- Negation, precedence, expressions, target inheritance, defaults, fallbacks, or priorities
- Selecting multiple values simultaneously for one Target kind
- Language-server completion or diagnostics for the new header syntax
- Compatibility support for anonymous Target clauses or the removed `Tags` terminology
- Include/module pattern changes or other unrelated working-tree changes
- Threads, new dependencies, or generalized configuration infrastructure

## Staged Implementation Plan

### Stage 1: Introduce the named Target model

1. Add a typed NexusScript Target object containing a Target-kind name and an owned, ordered, case-sensitive value collection.
2. Replace the source and compiled definitions' flat `TStringList` with owned collections of the typed Target objects while retaining the public concept name `Targets`.
3. Add small lookup/matching operations to the Target collection sufficient to find clauses by exact kind name and test an exact value. Do not introduce a generalized query abstraction.
4. Add a typed named Target-selection model containing one value per kind.
5. Have compilers and sessions own immutable copies of the selection model supplied at construction. Preserve parameterless construction for fully unfiltered compilation and remove the obsolete single-string `SelectedTarget` contract.

### Stage 2: Parse named Target clauses

1. Replace the one anonymous post-name bracket clause with repeated `TargetKind[...]` clauses in the definition header.
2. Parse each kind name and its nonempty list using the existing token decoding and source-range behavior.
3. Preserve clause order, repeated kind clauses, value order, and exact case.
4. Retain the existing diagnostics for empty clauses and duplicate values where their meaning remains the same, correcting message wording only as needed for named clauses.
5. Ensure the lookahead that distinguishes definition headers and inline definitions recognizes one or more named Target clauses without changing ordinary property, array, composition-selector, or definition parsing.
6. Remove acceptance of the obsolete anonymous bracket form rather than retaining a compatibility path.

### Stage 3: Generalize compilation filtering

1. Replace the flat `DefinitionAppliesToTarget` check with one named-selection applicability check implementing the Target Contract exactly.
2. For every selected kind, leave definitions without that kind unrestricted and require definitions that declare the kind to contain the selected value.
3. Ignore definition clauses for kinds absent from the compilation selection.
4. Require all applicable selected kinds to match; aggregate values across repeated clauses of the same kind as one OR set.
5. Apply the generalized check at the existing source-to-compiled construction points for roots, children, inline definitions, and array entries.
6. Preserve the complete named Target collection on each retained compiled definition and through existing clone, import, composition, rebinding, and projection paths.
7. Continue propagating one immutable selection context through every compiler owned by a compilation session.

### Stage 4: Adapt typed artifact metadata

1. Add typed RTTI artifact classes for a named Target entry and its ordered values.
2. Change `TNexusScriptArtifactMetadata.Targets` from a flat string array to an owned typed collection of Target entries.
3. Map compiled Target objects into those typed artifact objects without manual JSON construction.
4. Preserve omission for definitions without declarations and separation from ordinary domain properties.

### Stage 5: Replace and extend focused tests

1. Convert existing anonymous Target fixtures and source strings to explicit named clauses.
2. Prove parsing and model ownership for multiple Target kinds, multiple values, repeated kind clauses, declaration order, and case-sensitive names and values.
3. Prove fully untargeted compilation retains every definition.
4. Prove one selected kind filters only that kind while leaving every unselected kind unfiltered.
5. Prove two selected kinds produce OR-within and AND-across behavior using `Target` and `Platform` examples.
6. Prove a definition with no clause for a selected kind remains universal for that kind.
7. Prove case-sensitive identity directly: a case-mismatched kind name is a
   different, unselected kind and therefore does not filter the definition;
   a case-mismatched value under the exact selected kind excludes it.
8. Prove recursive filtering for children, inline definitions, and inline array entries without changing the parsed source model.
9. Prove the complete named selection context propagates through doctype, explicit and discovered module, and explicit and discovered include documents.
10. Prove matching composition succeeds and composition through a definition excluded by either selected kind produces the existing unresolved-composition diagnostic.
11. Prove typed `_nx.Targets` metadata contains ordered `Name` and `Values` data, excluded definitions are absent, definitions without clauses omit the member, and an ordinary `Targets` property remains independent.
12. Prove the obsolete anonymous clause is rejected and no `Tags` metadata or model contract returns.

### Stage 6: Update the language documentation

1. Replace the flat Target examples and single selected Target API description with named multidimensional examples.
2. Document independent selection, unfiltered unspecified kinds, OR within a kind, AND across applicable selected kinds, case sensitivity, recursive filtering, and dependency propagation.
3. Document the typed `_nx.Targets` metadata shape and removal of anonymous Target syntax.

## Sub-Agent Delegation

Implementation remains local to the primary Codex agent. This plan does not authorize sub-agent use; only a direct request from the human owner can do so.

## Verification Plan

Build the affected project and registered test module:

```text
lazbuild -B NexusTools\Script\NexusScript.lpi
lazbuild -B NexusTools\Script\tests\NexusScriptTestModule.lpi
```

Run the registered compiler suite through the existing unit-test host:

```text
output\NexusTestHost\nxtest_host.exe output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.dll run-suite NexusScript.Compiler
```

Focused source checks must confirm:

- no flat definition `TStringList` or single-string `SelectedTarget` remains in the Target feature;
- no anonymous definition Target clause remains accepted or documented;
- no Target-feature model, diagnostic, artifact, test, or documentation contract has reverted to `Tag`, `Tags`, or `_nx.Tags`;
- `_nx.Targets` is populated only through typed RTTI artifact objects;
- the named applicability check runs at the existing source-to-compiled boundary before composition and binding;
- every compiler created by a session receives the same immutable named selection context;
- unselected dimensions are not accidentally treated as failed matches;
- no PasBuild, `nxbuild`, CLI, validator-policy, language-server, threading, or unrelated include/module behavior changed.

After an approved implementation pass, create and validate the source archive required by the architecture-change protocol.

## Risks And Questions

- The Target changes currently coexist with uncommitted include/module pattern work. Implementation must inspect and preserve overlapping user changes rather than restoring files wholesale.
- Definition-header lookahead is the main parser risk because a Target-kind name is an ordinary word followed by `[`. Tests must cover root, nested, and inline definitions as well as nearby array/property syntax.
- The typed `_nx.Targets` shape necessarily changes from a flat array to named entries. The old flat shape cannot express multiple Target kinds and is not retained as a compatibility duplicate.
- No human decision remains about partial selection: selected kinds filter independently, and kinds absent from the selection remain unfiltered.

## Approval Gate

This plan and its commit do not authorize implementation. Implementation begins only after the human owner explicitly approves it.
