# Work Plan: NexusScript Definition Tags

## Inputs

- Source request: human-owner conversation request attached as
  `pasted-text.txt`, requesting a plan for language-level classification tags
  on NexusScript definitions.
- Related discussion: bracket syntax was selected over repeated `#Tag` and
  `tags(...)`; tags classify the declaration on which they appear and do not
  participate in composition.
- Current implementation and tests under `NexusTools/Script`.
- Existing constraints:
  - keep the compiler and compiled model domain-neutral;
  - represent tags as NexusScript metadata, not as a domain property;
  - preserve existing behavior and JSON for untagged documents;
  - do not add validator tag schemas, tag inheritance, key/value metadata,
    expressions, or general-purpose annotations;
  - follow `.ai/standards/pascal.md` and the repository architecture and
    approval protocols.
- Human-owner instruction: produce a work plan only; do not implement the
  feature yet.

## Summary

Add an optional, nonempty bracketed tag clause to every NexusScript definition
header:

```nexusscript
Build Release (CommonBuild) [Production, Win64] {
}
```

Tags are case-sensitive, valueless symbolic identifiers. They form an
unordered set whose source order is preserved only for deterministic storage
and output. Each source and compiled definition owns the tags declared on that
definition. Composition does not copy, merge, remove, or otherwise interpret
the tags on a contributor definition.

The generic JSON emitter exposes a tagged definition through `_nx.Tags` and
omits that member for an untagged definition. NexusScript assigns no domain
meaning to individual tag names.

## Verified Findings

- `TNexusScriptTokenKind` in
  `NexusTools/Script/src/obNexusScriptCompiler.pas` already has distinct
  `nstLeftBracket` and `nstRightBracket` tokens. No tokenizer token kind is
  required for the selected syntax.
- The tokenizer uses a broad `nstWord` bucket rather than a strict identifier
  token. Characters such as `=` remain inside one word token. Merely requiring
  `nstWord` would therefore accept `Environment=Production`, contrary to the
  requested valueless-identifier contract.
- `ParseDefinition` currently parses `Kind`, `Name`, an optional parenthesized
  composition-selector list, and then requires `{`. The tag clause belongs
  between the optional composition list and that brace.
- Array values consume the same bracket tokens only after `ParseValue` has
  entered value grammar. A tag clause in definition-header grammar is
  contextually distinct and creates no ambiguity with an array property such
  as `Outputs: [Executable, Symbols];`.
- `ParseValue.StartsInlineDefinition` currently recognizes only `Kind Name {`
  and `Kind Name (` through fixed token lookahead. A tagged inline definition
  begins `Kind Name [` and will be misclassified as scalar array content unless
  inline-definition recognition is changed.
- Nested definitions already use `ParseDefinition`, so the header grammar can
  be centralized there once all legal entry points recognize a definition.
- `TNexusScriptSourceDefinition` owns kind, name, properties, children,
  composition selectors, parent, and source range. It has no definition
  metadata collection for tags.
- `TNexusScriptCompiledDefinition` owns kind, name, completed properties,
  completed children, parent, source range, and compiler state. It likewise has
  no tags.
- `CopyDefinition` creates the initial compiled definition from a source
  definition. `CloneDefinition`, `CloneDefinitionForRebinding`,
  `CloneDefinitionAs`, and `CloneReferenceProjection` create structural copies
  for composition, references, projections, and imports. A definition-level
  field must be handled intentionally in each path or tags will disappear from
  some compiled structures.
- The composition routine applies a contributor's properties and children to
  the receiving definition. It does not copy definition identity metadata.
  Leaving contributor tags out of those apply loops implements local-only tag
  semantics; no tag merge phase is needed.
- When composition clones an inherited child, that clone still represents the
  child declaration. The child's own tags must remain on that cloned child even
  though the contributor definition's tags must not transfer to the receiving
  definition.
- Structural references and reference projections create renamed compiled
  representations of the referenced definition while retaining explicit
  reference provenance. Preserving the represented definition's tags through
  these clone paths keeps its classification inspectable without treating the
  tags as composition inheritance.
- `TNexusScriptJSONEmitter.DefinitionJSON` currently creates `_nx` with `Kind`,
  `Name`, `IsReference`, and optional `Reference`, then emits properties and
  children as domain members. `_nx` is the existing structural metadata
  boundary for tags.
- The emitter already walks every root, child, inline structural definition,
  and structural reference through `DefinitionJSON`, so one metadata emission
  path can cover every definition form once compiled tags are retained.
- The validator consumes completed properties, children, value source forms,
  and definition identity. It does not generically reject additional compiled
  definition fields, so compiler-level tags need not add validator semantics.
- `NexusTools/Script/tests/tsNexusScriptTests.pas` contains focused compiler,
  composition, inline-definition, projection, JSON-emitter, validator, and CLI
  coverage in one registered suite. Existing untagged tests provide broad
  regression coverage.
- The worktree was clean before this plan was created.

## Architecture Problem

Classification currently has no reserved structural representation. A domain
can declare a property such as `Tags`, but generic tooling cannot rely on that
name across doctypes, cannot distinguish language classification from domain
data, and may collide with a legitimate domain member.

Adding only parser syntax would leave the feature incomplete. Tags must survive
the source-to-compiled copy and every compiled-definition clone or projection,
while the composition algorithm must deliberately avoid transferring a
contributor definition's tags to its receiver. JSON must expose the resulting
metadata without changing the domain object or the output of existing untagged
documents.

The tokenizer also does not currently define a strict identifier language.
The tag grammar therefore needs an explicit spelling rule rather than relying
on `nstWord` to enforce the request's rejection of key/value and quoted forms.

## Target Contract

### Grammar

The definition header becomes:

```text
Definition := Kind Name [CompositionClause] [TagClause] Body
CompositionClause := '(' Path { ',' Path } ')'
TagClause := '[' TagIdentifier { ',' TagIdentifier } ']'
Body := '{' { Member } '}'
```

The clause order is fixed. Tags may follow the name or a completed composition
clause, but may not precede composition or appear after `{`.

The tag clause:

- is optional;
- must contain at least one tag;
- contains only unquoted tag identifiers separated by commas;
- does not allow a trailing comma;
- does not allow assignments, values, modifiers, nested arrays, or quoted
  strings;
- initially rejects dotted names unless the final identifier decision can
  admit the spelling without assigning namespace or path semantics.

The same grammar applies to root, nested, and inline definitions.

### Tag identity and ordering

- Tag identity is case-sensitive.
- `Production` and `PRODUCTION` are distinct tags.
- Repeating the exact same spelling on one definition is a compile error.
- Tags have set semantics; declaration order has no meaning to consumers.
- Source order is retained in the source model, compiled model, and JSON to
  produce deterministic output without normalization or sorting.
- NexusScript preserves spelling exactly and performs no casing conversion.

The recommended initial spelling rule is a deliberately narrow bare identifier:

```text
[A-Za-z_][A-Za-z0-9_]*
```

It covers every requested example, rejects `Environment=Production`, quoted
labels, whitespace, and dotted names, and avoids accidentally treating the
tokenizer's permissive word bucket as an identifier contract. This exact
character rule requires human-owner confirmation before implementation.

### Source-model ownership

`TNexusScriptSourceDefinition` owns an ordered `TStringList` of declared tag
spellings:

- the list is created and freed with the definition;
- its comparison policy is explicitly case-sensitive;
- parsing appends tags in declaration order;
- duplicate detection uses exact case-sensitive comparison;
- tag token ranges are used directly for parse diagnostics; per-tag ranges do
  not need to become retained model state unless implementation proves they are
  required beyond parsing.

Tags are not properties and do not enter the property/child member namespace.
A definition may therefore have both structural tags and an unrelated domain
property named `Tags`.

### Compiled-model ownership

`TNexusScriptCompiledDefinition` owns a separate ordered, case-sensitive list
containing the local tags represented by that compiled definition.

- `CopyDefinition` copies the source definition's tag spellings.
- General definition clones, imported-definition clones, renamed structural
  reference clones, and reference projections preserve the tags of the
  definition they represent.
- Lists are copied by value; source and compiled definitions and distinct
  compiled clones never share mutable `TStringList` ownership.
- No effective/inherited tag collection is introduced because local tags are
  the complete tag state.

### Composition behavior

For:

```nexusscript
Build Base [Windows] {
  Thing MailSettings [Shared] {
  }
}

Build Release (Base) [Production] {
}
```

the compiled `Release` tags are exactly `[Production]`; `Windows` is not
copied. The composed `MailSettings` child retains `[Shared]` because the child
clone represents that tagged child declaration.

The composition routine continues to merge only properties and children.
There is no union, precedence, duplicate handling across contributors,
removal, negation, or rebinding behavior for tags.

### Structural-reference behavior

A structural reference or projected/renamed structural definition retains the
tags of the definition it represents. This is metadata preservation across a
compiled representation, not propagation from a composition contributor.
Reference provenance and alias naming remain unchanged.

### JSON contract

For a tagged definition, `DefinitionJSON` adds a `Tags` array to `_nx` after
the existing identity members:

```json
{
  "_nx": {
    "Kind": "Build",
    "Name": "Release",
    "IsReference": false,
    "Tags": ["Production", "Win64"]
  }
}
```

- `Tags` contains JSON strings in retained declaration order.
- `Tags` is omitted when the compiled definition has no tags.
- Tags never appear as a domain-level member unless the source independently
  declares an ordinary domain property named `Tags`.
- Existing `_nx.Reference` behavior is unchanged.
- Existing untagged JSON remains byte-for-byte unchanged.
- Mustache and other generic JSON consumers can inspect `_nx.Tags` without a
  schema-specific adapter.

### Diagnostics

Add deterministic parser/compiler diagnostics for:

- an empty tag clause;
- an invalid tag spelling or disallowed quoted/dotted/value form;
- a case-sensitive duplicate tag on the same definition;
- malformed separators or a missing closing bracket, using existing parser
  recovery conventions where appropriate.

Reserve unused definition-diagnostic codes in the `NXS30xx` family for the
tag-specific empty, invalid, and duplicate cases. Tests will lock down the
chosen codes and source ranges. Existing `NXS2001` expected-token handling can
remain responsible for purely structural delimiter errors when it produces a
single clear diagnostic.

### Validator behavior

The validator ignores definition tags for policy purposes. Tags neither
satisfy nor violate property, child, value-form, allowed-value, or reference
rules. A tagged subject otherwise validates exactly as the equivalent untagged
subject.

No validator-language vocabulary for allowed, required, forbidden, or
mutually-exclusive tags is added.

## Scope

- `NexusTools/Script/src/obNexusScriptModel.pas`
  - owned source and compiled definition tag lists;
  - construction and destruction.
- `NexusTools/Script/src/obNexusScriptCompiler.pas`
  - definition-header tag parsing and diagnostics;
  - tag identifier validation;
  - inline-definition recognition;
  - source-to-compiled copying;
  - tag preservation in every definition clone/projection path;
  - explicit non-participation in composition.
- `NexusTools/Script/src/obNexusScriptJSON.pas`
  - conditional `_nx.Tags` array emission.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - focused parser, model, compilation, composition, clone/projection, JSON,
    validator, and regression tests.
- `NexusTools/Script/README.md`
  - definition-header grammar, local-only semantics, identifier and case
    rules, and `_nx.Tags` JSON representation.
- Fresh validated source archive after an approved implementation pass, as
  required by the architecture protocol.

## Out Of Scope

- General-purpose annotations or attributes.
- Key/value tags or arbitrary metadata values.
- Quoted tag labels.
- Tag expressions, queries, negation, removal, or modifiers.
- Tag inheritance, composition union, or precedence.
- Namespaced/dotted-tag semantics.
- Ordering semantics or compiler sorting.
- Case-insensitive normalization or consumer matching policy.
- Validator rules for allowed, required, kind-specific, or mutually-exclusive
  tags.
- Domain-specific meanings such as `Production`, `Lookup`, or
  `CrossReference` in the compiler.
- A reserved domain property named `Tags`.
- Changes to module, include, doctype, data, lookup, reference, property,
  child, or array semantics beyond recognizing and preserving tagged
  definitions.
- Changes to untagged JSON shape.
- Compatibility adapters or unrelated refactoring.

## Staged Implementation Plan

### Stage 1: Lock down grammar and failure behavior

1. Confirm the initial tag identifier character rule with the human owner.
2. Add focused failing compiler tests for:
   - one tag and multiple tags;
   - exact spelling and declaration-order retention in the source model;
   - tags after a composition clause;
   - tagged root, nested, and inline definitions;
   - `Production` and `PRODUCTION` as distinct tags;
   - exact duplicate rejection;
   - empty-list rejection;
   - quoted, assignment-like, dotted, malformed-comma, trailing-comma, and
     missing-bracket rejection.
3. Assign stable diagnostics and verify the reported source ranges point to
   the tag or clause that caused the error.

### Stage 2: Add source syntax and source-model ownership

1. Add the owned case-sensitive tag list to
   `TNexusScriptSourceDefinition`.
2. Parse the optional tag clause in `ParseDefinition` after composition and
   before the body.
3. Validate tag spellings without changing the global meaning of `nstWord` or
   the behavior of ordinary identifiers and values.
4. Replace the fixed inline-definition lookahead with recognition that accepts
   `{`, `(`, or `[` after `Kind Name`, while allowing `ParseDefinition` to
   validate the complete header.
5. Keep array-value parsing unchanged outside the inline-definition entry
   decision.

### Stage 3: Preserve local tags through compilation

1. Add the owned case-sensitive tag list to
   `TNexusScriptCompiledDefinition`.
2. Copy declared tags in `CopyDefinition`.
3. Audit and update `CloneDefinition`, `CloneDefinitionForRebinding`,
   `CloneDefinitionAs`, `CloneReferenceProjection`, and any definition-copy
   helper added or renamed by the current implementation.
4. Verify each cloned list has independent ownership.
5. Leave the composition apply loops unchanged with respect to the
   contributor definition's tags.
6. Prove with tests that a target retains only its locally declared tags,
   while a cloned composed child retains that child's own tags.
7. Prove that structural references, renamed projections, and imported
   definitions do not lose the represented definition's tags.

### Stage 4: Emit generic metadata

1. Extend `TNexusScriptJSONEmitter.DefinitionJSON` to create `_nx.Tags` only
   for a nonempty compiled tag list.
2. Emit each preserved spelling as a JSON string in declaration order.
3. Test tagged root, nested, inline, and referenced structural definitions.
4. Test that an ordinary domain property named `Tags` remains separate from
   `_nx.Tags`.
5. Assert that untagged `_nx` objects do not contain `Tags` and retain their
   existing serialized form.

### Stage 5: Regression and documentation pass

1. Verify a tagged document with a doctype validates exactly as its untagged
   equivalent; add no validator tag-policy behavior.
2. Run the complete existing compiler, session, validator, JSON, CLI,
   manifest, external-data, module, and parity fixture test suite.
3. Update `NexusTools/Script/README.md` with the final grammar and examples.
4. Run focused searches confirming tag handling is confined to generic model,
   compiler, emitter, tests, and documentation code.
5. Create the required fresh source archive only after the approved
   implementation compiles and all tests pass.

## Sub-Agent Delegation

After explicit implementation approval, assign the complete approved plan to
one `NexusScript definition-tags worker` with ownership limited to:

- `NexusTools/Script/src/obNexusScriptModel.pas`;
- `NexusTools/Script/src/obNexusScriptCompiler.pas`;
- `NexusTools/Script/src/obNexusScriptJSON.pas`;
- `NexusTools/Script/tests/tsNexusScriptTests.pas`;
- `NexusTools/Script/README.md`.

One worker should own the whole change because parser recognition, model
ownership, clone preservation, JSON emission, and focused tests share a tight
representation seam. Splitting these files across simultaneous workers would
create unnecessary overlap and increase the risk that one clone path or inline
definition form is missed.

Main Codex remains responsible for:

- confirming the unresolved identifier rule with the human owner;
- giving the worker the approved plan and current worktree constraints;
- reviewing every edit and checking ownership and local-only semantics;
- making any required integration correction;
- running the full build, test, grep, and archive workflow;
- reporting deviations, verification evidence, and the final artifact path.

No worker is spawned and no implementation activity begins during planning.

## Verification Plan

### Build and full suite

From the repository root:

```powershell
lazbuild --build-all NexusTools\Script\NexusScript.lpi
lazbuild --build-all NexusTools\Script\tests\NexusScriptTestModule.lpi
.\output\NexusScript\tests\x86_64-win64\NexusScriptTestModule.exe
```

Require both Lazarus projects to compile and the full NexusScript suite to
report success.

### Focused compiler/model assertions

- A root definition retains one and multiple source and compiled tags.
- Source and compiled lists preserve exact spelling and declaration order.
- `Production` and `PRODUCTION` remain two entries.
- An exact duplicate fails with the selected deterministic diagnostic.
- Empty, quoted, assignment-like, dotted, malformed, and unterminated clauses
  fail as specified.
- Tags work after composition and on nested and inline definitions.
- A receiver never acquires its contributor definition's tags.
- A structurally composed child retains the tags declared on that child.
- Structural references, renamed projections, and module/import clones retain
  the represented definition's tags.
- Every copied definition owns an independent tag list.

### Focused JSON assertions

- Tagged definitions emit `_nx.Tags` with the expected strings.
- Untagged definitions omit `_nx.Tags`.
- Root, nested, inline, and referenced definitions use the same metadata rule.
- `_nx.Tags` and an ordinary domain `Tags` property can coexist.
- `Kind`, `Name`, `IsReference`, and `Reference` remain unchanged.
- A representative untagged artifact remains byte-for-byte identical to its
  pre-feature expected JSON.

### Validator and compatibility assertions

- A tagged subject compiles and validates without requiring tag vocabulary in
  its doctype language.
- Existing untagged fixtures compile, validate, render, and emit unchanged.
- Existing array parsing, including arrays containing inline definitions,
  remains unchanged when no definition tag clause is present.
- Existing composition precedence and reference behavior remain unchanged.

### Focused source checks

```powershell
rg -n "Tags|TagClause|tag" NexusTools\Script\src NexusTools\Script\tests NexusTools\Script\README.md
rg -n "Tags|TagClause|tag" NexusTools\Script\validator NexusTools\Script\cli
```

Review the first result to confirm every definition copy path is covered.
The second should show no validator-policy or CLI-specific implementation;
generic JSON reaches the CLI through the existing emitter.

## Risks And Questions

### Required human decision: tag identifier spelling

The request defines tags as symbolic identifiers but the current tokenizer's
`nstWord` is intentionally broader than a conventional identifier and includes
`=` and other punctuation. The implementation must not silently equate
`nstWord` with the tag contract.

Recommended initial rule:

```text
[A-Za-z_][A-Za-z0-9_]*
```

This is sufficient for all stated uses and cleanly leaves dotted names for a
future design. The human owner must confirm this rule or provide the intended
alternative before implementation.

### Inline-definition recognition

The present fixed lookahead can mistake tagged inline definitions for scalar
array entries. Updating recognition is required, but it must not cause an
ordinary two-word array value followed by `[` to be consumed as a definition.
Focused positive and negative tests must lock down this boundary.

### Clone-path loss

There are several compiled-definition clone and projection helpers. Missing
one will produce tags on direct definitions but silently lose them on a
reference, import, composed child, or rebound value. The implementation must
centralize list copying in a small helper or audit every constructor path and
prove them through focused tests.

### Local-only versus copied-child metadata

Not inheriting a contributor definition's tags must not be implemented by
globally stripping tags from all clones. A child introduced through structural
composition still represents its own tagged declaration and must preserve
that local metadata.

### Exact JSON compatibility

Always emitting an empty `Tags` array would change every existing artifact.
Conditional emission is required. Tests must compare a representative untagged
artifact exactly, not merely assert that it remains valid JSON.

## Approval Gate

This plan creates no implementation authorization. No source, test, fixture,
or documentation implementation changes; builds; test runs; sub-agent work;
launches; or archive creation begin until the human owner:

1. confirms the initial tag identifier spelling rule; and
2. explicitly authorizes implementation of this work plan.
