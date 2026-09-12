# Work Plan: NexusScript Multidimensional Target Filtering

## Inputs

- Source request: conversation request of September 12, 2026, supported by `C:\Users\kcollins\Downloads\nexusscript-target-filtering-workplan-request (2).md`.
- Related discussion/review notes: the current single selected Target is only the first dimension of the intended system. Target kinds are named, freeform NexusScript identifiers such as `Target` and `Platform`. Values within one target kind use OR semantics. Selected target kinds filter independently; target kinds not selected by the compiler remain unfiltered. A definition may declare each Target kind at most once. Target clauses do not participate in definition identity; normal duplicate-definition rules apply only to the definitions that survive filtering.
- Existing constraints: retain filtering before composition and effective-value resolution, keep the parsed source model complete, preserve case-sensitive identity, apply one immutable selection context throughout a compilation session, use typed model and RTTI-backed artifact objects, and do not include PasBuild or CLI work.

## Summary

Reshape the existing flat, single-dimensional Target implementation into a named multidimensional Target system.

A definition may declare any number of distinct named Target clauses after its name, with each Target-kind name appearing at most once:

```nexusscript
ATask SomeTask Target[Dev, QA] Platform[Windows] {
}
```

`Target` and `Platform` are ordinary, case-sensitive Target-kind names. Each clause contains one or more case-sensitive values. A compilation selection may select a value for any subset of the named Target kinds. Each selected kind filters independently; an unselected kind imposes no filtering. Values within a clause use OR semantics, while all selected kinds applicable to a definition must match. Target clauses affect applicability only; they do not alter definition identity.

The existing source-to-compiled filtering location and dependency propagation remain correct. The work replaces the flat definition value list and single selected string with typed named Targets and a named selection context, then adapts the parser, copying, metadata, uniqueness timing, exact source association, and focused tests around that corrected model.

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
- The parser currently rejects duplicate root definitions and duplicate child members before Target filtering can occur.
- `CompileSource.SourceFor` currently recovers a compiled definition's source definition by its name and parent path. Once same-identity source variants are permitted, that lookup can return an excluded variant instead of the exact source definition from which the retained compiled definition was created.
- The current Target implementation is uncommitted and shares the working tree with the separate include/module pattern implementation. The multidimensional change must preserve those unrelated working-tree changes.

## Architecture Problem

The filtering pipeline is in the correct location, but its data model assumes that every Target value belongs to one unnamed dimension. Consequently, `Dev` and `Windows` cannot be distinguished as values of different Target kinds, and the compiler can select only one string for the entire compilation.

Treating all values as one flat set cannot express the required relationship:

```nexusscript
ATask SomeTask Target[Dev, QA] Platform[Windows] {
}
```

The definition should be selectable independently by build Target and Platform. Flattening the declaration would incorrectly make `Dev`, `QA`, and `Windows` alternatives in one dimension. Likewise, requiring every declared kind to have a selected value would make partial compilation destructive and force callers to know every freeform Target kind used by a dialect.

The model therefore needs named Target clauses on definitions and named Target selections on a compiler/session. The existing source-to-compiled boundary can then evaluate only the kinds actually selected by the caller. Definitions that survive that filtering continue through the normal semantic pipeline and remain subject to the ordinary identity and duplicate-definition rules.

Permitting same-identity variants in the parsed source also makes name-based recovery of source definitions invalid. A retained compiled definition must remain associated with the exact source definition that produced it so composition and any other source-dependent behavior cannot accidentally consume an excluded variant.

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
- A definition may declare a given Target-kind name only once. Repeating the same exact case-sensitive Target-kind name on one definition is a duplicate-kind diagnostic; authors must combine alternatives into one value list such as `Target[Dev, QA]`.
- Different case-sensitive kind names remain distinct, so `Platform` and `platform` are different Target kinds at the NexusScript core level.
- The former anonymous syntax, such as `SomeTask[Dev]`, is replaced by an explicitly named clause such as `SomeTask Target[Dev]`. No compatibility alias or implicit Target-kind name is retained.

### Selection and matching

- A compilation selection is a case-sensitive set of Target-kind name/value pairs, with at most one selected value for each kind.
- No selected pairs means completely untargeted compilation: every definition is eligible to enter the compiled model, but all normal semantic rules still apply to that resulting candidate set, including uniqueness. Untargeted compilation may therefore fail if mutually exclusive targeted alternatives become simultaneously present.
- Each selected kind filters independently.
- If a definition has no clause for a selected kind, that selected kind does not restrict the definition.
- If a definition has a clause for a selected kind, at least one value in that clause must exactly match the selected value.
- Clauses whose kinds are not selected by the compiler are not evaluated and do not restrict the definition.
- A definition is retained only when it satisfies every selected kind for which it declares a clause.
- These rules produce OR behavior within a named kind and AND behavior across the selected named kinds that the definition restricts.
- Selection-context ordering has no semantic effect. `Target=Dev, Platform=Windows` and `Platform=Windows, Target=Dev` are the same selection.

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
- no selections retain it because the compilation is unfiltered, subject to normal semantic validation of the complete retained set.

### Identity and uniqueness

- Target clauses do not participate in identity. Existing NexusScript scoped identity and member-uniqueness rules remain unchanged.
- Source may contain same-identity definitions whose Target clauses make them mutually exclusive for a particular compilation. The Target system does not create a second target-aware identity scheme.
- Target filtering must occur before duplicate-definition validation for the affected compiled scope. A valid targeted variant must not be rejected merely because another same-identity source definition would have existed under a different selection.
- After filtering, the ordinary duplicate-definition rule applies without special Target logic. If two same-identity definitions survive the chosen selection, compilation fails with the existing duplicate-definition diagnostic.
- Untargeted or partially targeted compilation may therefore fail uniqueness validation when the omitted Target dimensions were required to distinguish mutually exclusive alternatives. This is a useful script/compiler error, not a Target-selection special case.
- NexusScript performs no Target-overlap analysis and does not attempt to prove that same-identity declarations are mutually exclusive. The retained compiled set alone determines whether ordinary uniqueness succeeds.

For example:

```nexusscript
ATask Build Platform[Windows] {
}

ATask Build Platform[Linux] {
}

ATask SendNotification {
}
```

- `Platform=Windows` retains one `Build` plus `SendNotification` and is valid.
- `Platform=Linux` retains the other `Build` plus `SendNotification` and is valid.
- no `Platform` selection retains both `Build` definitions, so normal duplicate-definition validation fails.
- the universal `SendNotification` remains valid for every Platform because it declares no Platform restriction.

The same rule handles overlapping applicability naturally. If one `Build` declares `Platform[Windows, Linux]` and another declares `Platform[Windows]`, Linux retains one and may be valid, while Windows retains both and fails the ordinary duplicate-definition rule.

### Ownership and propagation

- Source and compiled definitions each own their typed Target collections.
- A Target entry owns its unique-on-that-definition name and ordered value collection.
- A compiler and compilation session each own an immutable copy of their named selection context. Caller mutation cannot change an active compiler or invalidate a session's filename-keyed compiler cache.
- A session supplies the same complete selection context to every compiler it creates for entry, doctype, module, include, and discovered documents.
- The parsed source document remains complete and unchanged. Only compiled-model construction filters definitions.
- Every compiled definition created from source retains an exact association with the source definition that produced it. Composition and other source-dependent processing use that association rather than recovering a source definition by name.
- Filtering remains recursive for root, child, and inline structural definitions at every supported nesting level.
- Compiled-to-compiled copying does not reevaluate selection. It preserves the named Target declarations and appropriate source association of definitions already retained by the source-to-compiled boundary.
- Exclusion itself is not a diagnostic. Existing unresolved-reference and unresolved-composition diagnostics remain responsible when retained definitions name excluded definitions.

### Artifact metadata

- Retained declarations are emitted through the typed RTTI artifact model under `_nx.Targets`.
- `_nx.Targets` becomes an ordered array of typed named Target entries. Each entry contains its `Name` and ordered `Values`, and each `Name` occurs at most once for a definition.
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
- Validator/dialect policy for permitted Target kinds or values
- Negation, precedence, expressions, target inheritance, defaults, fallbacks, priorities, or Target-overlap analysis
- Selecting multiple values simultaneously for one Target kind
- Language-server completion or diagnostics for the new header syntax
- Compatibility support for anonymous Target clauses or the removed `Tags` terminology
- Include/module pattern changes or other unrelated working-tree changes
- Threads, new dependencies, or generalized configuration infrastructure

## Staged Implementation Plan

### Stage 1: Introduce the named Target model

1. Add a typed NexusScript Target object containing a Target-kind name and an owned, ordered, case-sensitive value collection.
2. Replace the source and compiled definitions' flat `TStringList` with owned collections of the typed Target objects while retaining the public concept name `Targets`.
3. Add small lookup/matching operations to the Target collection sufficient to find the unique clause by exact kind name and test an exact value. Do not introduce a generalized query abstraction.
4. Add a typed named Target-selection model containing one value per kind.
5. Have compilers and sessions own immutable copies of the selection model supplied at construction. Preserve parameterless construction for fully unfiltered compilation and remove the obsolete single-string `SelectedTarget` contract.

### Stage 2: Parse named Target clauses

1. Replace the one anonymous post-name bracket clause with zero or more explicitly named `TargetKind[...]` clauses in the definition header.
2. Parse each kind name and its nonempty list using the existing token decoding and source-range behavior.
3. Preserve Target-kind declaration order, value order, decoded spelling, and exact case.
4. Reject a repeated exact Target-kind name on the same definition with a focused duplicate-kind diagnostic; alternatives for one kind belong in one clause.
5. Retain the existing diagnostics for empty clauses and duplicate values where their meaning remains the same, correcting message wording only as needed for named clauses.
6. Ensure the lookahead that distinguishes definition headers and inline definitions recognizes one or more named Target clauses without changing ordinary property, array, composition-selector, or definition parsing.
7. Remove acceptance of the obsolete anonymous bracket form rather than retaining a compatibility path.

### Stage 3: Generalize compilation filtering

1. Replace the flat `DefinitionAppliesToTarget` check with one named-selection applicability check implementing the Target Contract exactly.
2. For every selected kind, leave definitions without that kind unrestricted and require definitions that declare the kind to contain the selected value.
3. Ignore definition clauses for kinds absent from the compilation selection.
4. Require all applicable selected kinds to match, with OR semantics across the values of each single named clause.
5. Apply the generalized check at the existing source-to-compiled construction points for roots, children, inline definitions, and array entries.
6. Ensure ordinary duplicate-definition validation for compiled scopes occurs after applicability filtering, so same-identity targeted alternatives may exist in source when a valid selection retains only one. Do not add Target fields to identity and do not add Target-overlap analysis.
7. Establish and preserve the exact source-definition association when each retained compiled definition is created. Remove source recovery by name from composition and other source-dependent processing; copied or projected definitions must preserve or deliberately supply the association appropriate to their existing semantics.
8. Preserve the complete named Target collection on each retained compiled definition and through existing clone, import, composition, rebinding, and projection paths.
9. Continue propagating one immutable selection context through every compiler owned by a compilation session.

### Stage 4: Adapt typed artifact metadata

1. Add typed RTTI artifact classes for a named Target entry and its ordered values.
2. Change `TNexusScriptArtifactMetadata.Targets` from a flat string array to an owned typed collection of Target entries.
3. Map compiled Target objects into those typed artifact objects without manual JSON construction.
4. Preserve omission for definitions without declarations and separation from ordinary domain properties.

### Stage 5: Replace and extend focused tests

1. Convert existing anonymous Target fixtures and source strings to explicit named clauses.
2. Prove parsing and model ownership for multiple Target kinds, multiple values, declaration order, and case-sensitive names and values.
3. Prove repeating the same exact Target-kind name on one definition is rejected, while differently cased kind names remain distinct at the core language level.
4. Prove fully untargeted compilation retains all eligible definitions when they are otherwise semantically compatible.
5. Prove same-identity platform variants are accepted in source, `Platform=Windows` retains only the Windows variant, `Platform=Linux` retains only the Linux variant, and an untargeted or insufficiently targeted compilation that retains both produces the existing duplicate-definition diagnostic.
6. Prove overlapping applicability uses ordinary uniqueness only: for example, `Platform[Windows, Linux]` plus a same-identity `Platform[Windows]` variant is valid for Linux and duplicate-invalid for Windows.
7. Prove that retained root and nested variants use their exact originating source definitions by giving same-identity variants different composition selectors or other source-dependent behavior and selecting each variant independently. Reverse their declaration order so the test cannot pass through first-name lookup accidentally.
8. Prove one selected kind filters only that kind while leaving every unselected kind unfiltered.
9. Prove selecting an unrelated kind that a definition does not declare leaves that definition unrestricted.
10. Prove two selected kinds produce OR-within and AND-across behavior using `Target` and `Platform` examples.
11. Prove the semantic result is independent of selection-context insertion/order.
12. Prove a definition with no clause for a selected kind remains universal for that kind.
13. Prove case-sensitive identity directly: a case-mismatched kind name is a different, unselected kind and therefore does not filter the definition; a case-mismatched value under the exact selected kind excludes it.
14. Prove recursive filtering for children, inline definitions, and inline array entries without changing the parsed source model.
15. Prove the complete named selection context propagates through doctype, explicit and discovered module, and explicit and discovered include documents.
16. Prove compiler/session ownership is immutable: mutating the caller's original selection after construction cannot change an active compiler/session or its cached compiler behavior.
17. Prove matching composition succeeds and composition through a definition excluded by either selected kind produces the existing unresolved-composition diagnostic.
18. Prove typed `_nx.Targets` metadata contains ordered unique `Name` and `Values` entries, excluded definitions are absent, definitions without clauses omit the member, and an ordinary `Targets` property remains independent.
19. Prove the obsolete anonymous clause is rejected and no `Tags` metadata or model contract returns.

### Stage 6: Update the language documentation

1. Replace the flat Target examples and single selected Target API description with named multidimensional examples.
2. Document independent selection, unfiltered unspecified kinds, OR within a kind, AND across applicable selected kinds, case sensitivity, one clause per Target kind, recursive filtering, and dependency propagation.
3. Document that Target clauses do not participate in identity; duplicate-definition validation applies to the post-filter compiled model, so untargeted or partially targeted compilation may legitimately fail when mutually exclusive variants are both retained.
4. Document the typed `_nx.Targets` metadata shape and removal of anonymous Target syntax.

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
- a Target-kind name occurs at most once per definition and `_nx.Targets` therefore has at most one entry per exact kind name;
- caller mutation cannot change a compiler/session's copied selection context;
- selection-context ordering does not affect matching;
- Target clauses have not been added to definition identity and no Target-overlap analyzer was introduced;
- duplicate-definition validation for targeted variants occurs only after the relevant applicability filtering;
- composition and other source-dependent processing use the exact source definition associated during source-to-compiled construction, not a name-based source lookup;
- no PasBuild, `nxbuild`, CLI, validator-policy, language-server, threading, or unrelated include/module behavior changed.

After an approved implementation pass, create and validate the source archive required by the architecture-change protocol.

## Risks And Questions

- The Target changes currently coexist with uncommitted include/module pattern work. Implementation must inspect and preserve overlapping user changes rather than restoring files wholesale.
- Definition-header lookahead is the main parser risk because a Target-kind name is an ordinary word followed by `[`. Tests must cover root, nested, and inline definitions as well as nearby array/property syntax.
- The typed `_nx.Targets` shape necessarily changes from a flat array to named entries. The old flat shape cannot express multiple Target kinds and is not retained as a compatibility duplicate.
- No human decision remains about partial selection: selected kinds filter independently, and kinds absent from the selection remain unfiltered. If omitted dimensions cause multiple same-identity variants to survive, the ordinary duplicate-definition diagnostic is the intended result.
- Freeform Target-kind names are intentionally case-sensitive and unselected kinds intentionally do not filter. Therefore a misspelled constrained-dialect kind such as `Platfrom[Windows]` can behave as an unrelated, unselected kind in generic NexusScript. This core change should not add policy validation; dialects such as NexusSetup should later validate their permitted Target-kind names where silent broadening would be unsafe.
- Deferring duplicate-definition validation until after filtering is a semantic requirement for targeted same-identity variants. Implementation must inspect existing duplicate checks carefully and move/defer only the checks necessary for this behavior without weakening unrelated source diagnostics.
- Same-identity source variants make name-based source recovery ambiguous. The implementation must preserve exact source association directly and must not repair the ambiguity with ordering assumptions or Target-aware identity.

## Approval Gate

This plan and its commit do not authorize implementation. Implementation begins only after the human owner explicitly approves it.
