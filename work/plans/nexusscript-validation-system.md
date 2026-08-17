# Work Plan: NexusScript Validation System

## Inputs

- Source request: direct human-owner request for a work plan, supplied through
  `C:\Users\kcollins\.codex\attachments\c56e631e-0c6b-47f2-931a-c58e808d664f\pasted-text.txt`.
- Current compiler implementation under `NexusTools/Script/src`.
- Current schema parity consumer and tests under `NexusTools/Script/parity` and
  `NexusTools/Script/tests`.
- Current document association: an optional `doctype Path;` declaration
  identifies another compiled NexusScript document for consumer use without
  importing its namespace or automatically invoking validation.
- Existing constraints:
  - validation consumes the compiled generic model, not source syntax;
  - validator vocabulary is ordinary NexusScript vocabulary interpreted by the
    validator engine;
  - no validator or domain vocabulary enters the generic parser/compiler;
  - no executable predicates, callbacks, scripting, or meta-validator layer;
  - automatic validator dispatch and NexusLS/VS Code integration are deferred;
  - unrelated working-tree changes must remain untouched.

## Summary

Add a final NexusScript consumer named the Validator engine. It receives two
successfully compiled documents: the subject document and a validator-definition
document. It compiles the latter into a small in-memory rule model, validates
the subject's final effective structure, and returns source-based diagnostics.

The architecture is:

```text
subject source                 validator source
      |                              |
      +---- NexusScript compiler ----+
                     |
           two compiled documents
                     |
              Validator engine
                     |
          validation diagnostics
```

The engine has intentionally hard-coded knowledge of the validator vocabulary.
That is consumer semantics, not generic NexusScript syntax. Domain validators
such as `Schema.nxscript` contain data only. Schema, Build, Installer,
UI, and custom domain vocabulary remains absent from both the compiler and the
Validator engine.

The first implementation will prove this chain:

```text
Customer.nxscript
  -- doctype Schema --> Schema.nxscript

Schema.nxscript
  -- doctype Validator --> Validator.nxscript

Validator.nxscript
  -- doctype Validator --> Validator.nxscript
```

## Verified Findings

- `TNexusScriptCompiledDocument` exposes ordered root definitions and source
  identity.
- `TNexusScriptCompiledDefinition` exposes effective kind, name, properties,
  child definitions, parent, and source range after composition.
- `TNexusScriptCompiledProperty` exposes its name, compiled value, and source
  range.
- `TNexusScriptCompiledValue` retains the original value kind, source text,
  source range, array items, entry and effective names, effective text,
  effective/ resolved values, resolved property or definition targets,
  structural definition materialization, original definition name, inline
  source definition, and composition contributors.
- `TNexusScriptValueKind` distinguishes text, array, reference, text
  composition, and inline definition source forms. Resolved target pointers and
  effective values allow a consumer to distinguish source form from result
  shape without re-resolving reference text.
- The compiler already rejects unresolved references and compilation cycles.
  The Validator engine therefore receives a resolved document and must not
  duplicate generic resolution.
- Source ranges survive into compiled definitions, properties, and values.
  Inherited and referenced materializations generally retain their originating
  ranges, which is sufficient for initial primary diagnostics.
- `TNexusScriptDiagnostic` currently carries a code, message, and one source
  range. It does not carry severity or related provenance locations.
- The existing schema parity consumer demonstrates the intended consumer seam,
  but it directly translates recognized schema structures and is not a generic
  declarative validator.
- NexusScript file extensions are not compiler semantics. The Validator API
  will not infer or locate validators from filenames in this work.

## Architecture Problem

NexusScript can compile arbitrary generic structure, but it does not yet have a
consumer that declares and enforces the structural rules of a domain. Adding
required properties, allowed kinds, cardinality, or semantic scalar parsing to
the compiler would violate the core boundary. Hard-coding every domain in a
consumer would also prevent domains from defining their contracts in
NexusScript.

The correction is one deliberately concrete Validator engine. It owns a small
rule vocabulary and interprets ordinary compiled NexusScript definitions into
rules. Domain validators use that vocabulary to constrain other compiled
documents. There is no generic callback framework and no additional
meta-language.

## Target Contract

### Ownership

- Owner: a dedicated validator consumer area under `NexusTools/Script`, kept
  separate from `src` compiler internals. Final folder/unit placement will use
  `tp...` for shared rule/diagnostic types and `ob...` for engine/model objects.
- The caller owns the subject and validator compiled documents.
- The Validator engine owns its normalized rule model and validation
  diagnostics.
- The engine does not mutate either compiled document and does not take hidden
  ownership of them.

### Public API boundary

The public operation will be equivalent in responsibility to:

```text
Validate(
    Subject: TNexusScriptCompiledDocument;
    ValidatorDefinition: TNexusScriptCompiledDocument;
    Diagnostics: validator-owned result
): Boolean
```

The exact Pascal signature is an implementation detail, but it must:

- require already compiled documents;
- distinguish invalid validator definitions from subject validation failures;
- expose deterministic diagnostics without exceptions for ordinary invalid
  input;
- never accept raw source text or compiler/parser objects;
- never locate a validator from a filename.

Validation is two-phase:

1. normalize and validate the validator-definition document into a rule model;
2. apply that rule model to the subject document.

No partially normalized rules may be used after phase 1 reports an error.

### Minimal validator vocabulary

The Validator engine recognizes these definition kinds:

- `Language`: one root definition describing a validation profile;
- `Definition`: rules for one subject definition kind;
- `Property`: rules for one property name;
- `Child`: cardinality rules for direct child definitions by kind;
- `Value`: source-form, effective-category, and semantic-scalar rules;
- `Array`: rules for array entries and collection cardinality;
- `Reference`: rules for resolved reference targets.

These names are ordinary NexusScript identifiers. They are hard-coded only in
the Validator engine.

#### `Language`

Required structure:

- `Definitions`: a named array of inline `Definition` entries;
- `UnknownDefinitions`: optional `Allow` or `Reject`, default `Reject`.

Each `Definition` entry's effective name is the subject kind it governs. Kind
rule names must therefore be unique through ordinary NexusScript array naming.

#### `Definition`

Supported members:

- `Root`: optional semantic Boolean, default `False`;
- `Parents`: optional scalar array of allowed parent kinds;
- `UnknownProperties`: optional `Allow` or `Reject`, default `Reject`;
- `UnknownChildren`: optional `Allow` or `Reject`; when `Children` is present,
  its default is `Reject`;
- `Properties`: optional named array of inline `Property` rules;
- `Children`: optional named array of inline `Child` rules.

A kind is legal at document root only when `Root` is true. A nested definition
is checked independently from both directions that are actually declared:

- `Parents`, when present on the child kind, constrains the kinds under which
  that definition may appear;
- `Children`, when present on the parent kind, constrains accepted child kinds
  and applies its cardinality rules;
- when both apply, the nested definition must satisfy both;
- absence of either declaration imposes no constraint from that side and does
  not require a reciprocal declaration.

If `Children` and `UnknownChildren` are both absent, the parent kind imposes no
parent-side restriction on child kinds. If `Children` is present, unmatched
child kinds are governed by `UnknownChildren`, whose default is `Reject`. An
explicitly supplied `UnknownChildren` policy remains a parent-side constraint
even when `Children` is absent. Validator-definition normalization does not
reject missing reciprocal declarations or attempt to prove that the
independent parent and child constraints have a nonempty intersection.

For example, this rule alone restricts `Field` to `Table` parents:

```text
Definition Field {
    Parents: [Table];
}
```

This separate rule alone permits and counts `Field` children under `Table`:

```text
Definition Table {
    Children: [
        Child Fields {
            Kinds: [Field];
            Minimum: 1;
        }
    ];
}
```

#### `Property`

Supported members:

- `Required`: optional semantic Boolean, default `False`;
- one optional inline `Value` child named `Value`.

NexusScript already guarantees one property per name in a definition, so the
Validator vocabulary does not invent property occurrence multiplicity.
Absence is governed only by `Required`.

#### `Child`

Supported members:

- `Kinds`: required nonempty scalar array of permitted child kinds;
- `Minimum`: optional nonnegative semantic Integer, default `0`;
- `Maximum`: optional nonnegative semantic Integer or `Unbounded`, default
  `Unbounded`.

The `Child` entry name is a rule identity for diagnostics; it is not assumed to
equal a subject definition name or kind. Each effective child definition is
assigned to exactly one matching child rule. Overlapping `Kinds` across sibling
rules are invalid validator definitions because they make cardinality
ambiguous. Cardinality counts direct effective child definitions only.

#### `Value`

Supported members:

- `SourceForms`: optional nonempty scalar array drawn from `Text`, `Array`,
  `Reference`, `TextComposition`, and `InlineDefinition`;
- `EffectiveCategories`: optional nonempty scalar array drawn from `Text`,
  `Array`, and `Definition`;
- `Scalar`: optional `Text`, `Integer`, or `Boolean`;
- optional inline `Array` child named `Array`;
- optional inline `Reference` child named `Reference`.

Omitted constraints do not restrict that dimension. `SourceForms` examines the
retained `TNexusScriptValueKind`; `EffectiveCategories` examines the resolved
result. This separation permits rules such as "must be written as a reference"
without confusing that with "must resolve to a definition."

`Scalar: Text` accepts any effective text. `Integer` accepts an optional leading
minus followed by decimal digits with no whitespace or locale formatting.
`Boolean` accepts `True` or `False`, case-insensitively. These are Validator
consumer interpretations of text, not NexusScript primitive types.

#### `Array`

Supported members:

- `Minimum`: optional nonnegative Integer, default `0`;
- `Maximum`: optional nonnegative Integer or `Unbounded`, default `Unbounded`;
- `Names`: optional `Required`, `Optional`, or `Forbidden`, default `Optional`;
- `EntrySourceForms`: optional source-form set using the `Value` names;
- `EntryEffectiveCategories`: optional effective-category set;
- `DefinitionKinds`: optional allowed kinds for definition-valued entries;
- `Mixed`: optional Boolean, default `True`.

Order is preserved but does not affect validity in the initial vocabulary.
`Mixed: False` requires all entries to have the same effective category. Named
entry checks use `EffectiveName`; unnamed scalar entries remain unnamed.
Definition-valued entries use `StructuralDefinition` and its effective kind.
No dictionary type is introduced.

#### `Reference`

Supported members:

- `Targets`: required nonempty scalar array containing `Property` and/or
  `Definition`;
- `DefinitionKinds`: optional allowed kinds when a definition target is legal.

The rule inspects `ResolvedProperty` and `ResolvedDefinition`; it never resolves
`SourceText`. A `Reference` rule constrains values whose source form is actually
`Reference`. Allowing non-reference alternatives is expressed through
`Value.SourceForms`, not through a second flag.

### Representative validator documents

The examples below establish the intended structure; the implementation stage
will place complete executable fixtures under the validator tests.

#### `Validator.nxscript`

```text
Language Validator {
    Definitions: [
        Definition Language {
            Root: True;
            UnknownProperties: Reject;
            UnknownChildren: Reject;
            Properties: [
                Property Definitions {
                    Required: True;
                    Value Value {
                        SourceForms: [Array];
                        EffectiveCategories: [Array];
                        Array Array {
                            Names: Required;
                            EntryEffectiveCategories: [Definition];
                            DefinitionKinds: [Definition];
                            Mixed: False;
                        }
                    }
                },
                Property UnknownDefinitions {
                    Value Value { Scalar: Text; }
                }
            ];
        },

        Definition Definition {
            Root: False;
            UnknownProperties: Reject;
            UnknownChildren: Reject;
            Properties: [
                Property Root { Value Value { Scalar: Boolean; } },
                Property Parents {
                    Value Value {
                        EffectiveCategories: [Array];
                        Array Array { EntryEffectiveCategories: [Text]; }
                    }
                },
                Property UnknownProperties { Value Value { Scalar: Text; } },
                Property UnknownChildren { Value Value { Scalar: Text; } },
                Property Properties { Value Value { EffectiveCategories: [Array]; } },
                Property Children { Value Value { EffectiveCategories: [Array]; } }
            ];
        },

        Definition Property { Root: False; },
        Definition Child { Root: False; },
        Definition Value { Root: False; },
        Definition Array { Root: False; },
        Definition Reference { Root: False; }
    ];
}
```

The checked-in fixture will fully describe every member of all seven kinds;
the abbreviated tail above avoids making the plan itself the authoritative
validator file.

#### `Schema.nxscript`

```text
Language Schema {
    Definitions: [
        Definition Table {
            Root: True;
            UnknownProperties: Reject;
            UnknownChildren: Reject;
            Properties: [
                Property TableName {
                    Required: True;
                    Value Value {
                        EffectiveCategories: [Text];
                        Scalar: Text;
                    }
                },
                Property Fields {
                    Required: True;
                    Value Value {
                        EffectiveCategories: [Array];
                        Array Array {
                            Minimum: 1;
                            Names: Required;
                            EntryEffectiveCategories: [Definition];
                            DefinitionKinds: [Field];
                            Mixed: False;
                        }
                    }
                }
            ];
        },
        Definition Field {
            Root: False;
            Parents: [Table];
            UnknownProperties: Reject;
            Properties: [
                Property Type {
                    Required: True;
                    Value Value { Scalar: Text; }
                },
                Property Reference {
                    Value Value {
                        SourceForms: [Reference];
                        EffectiveCategories: [Definition];
                        Reference Reference {
                            Targets: [Definition];
                            DefinitionKinds: [Table];
                        }
                    }
                }
            ];
        }
    ];
}
```

This example treats definition-valued entries in `Fields` as structurally
contained by `Table` for validation purposes even though they reside in a
property array. The traversal rules below define that relationship explicitly.

#### `Customer.nxscript`

```text
module Core "Core.Schema.nxscript";

Table Customer {
    TableName: CUSTOMER;
    Fields: [
        Field ID {
            Type: Integer;
        },
        Field ParentID {
            Type: Integer;
            Reference: @Core.Parent;
        }
    ];
}
```

The module-qualified `Reference` property above resolves to a `Table Parent`
definition in the companion `Core.Schema.nxscript` fixture and is checked
through retained target provenance. No schema-specific interpretation is
performed by the NexusScript compiler.

### Validation traversal

Validation proceeds deterministically in source/effective order:

1. Normalize the validator definition and reject malformed rule vocabulary,
   duplicate/overlapping rules, invalid enum text, invalid bounds, unknown rule
   members, and references to unknown rule kinds. Do not require reciprocal
   `Parents` and `Children` declarations or reject independent constraints
   merely because their intersection permits no placement.
2. Visit subject root definitions in compiled order.
3. Resolve the applicable `Definition` rule by exact kind. Verify root
   legality, then independently apply the child's `Parents` constraint and the
   parent's `Children`/`UnknownChildren` constraint when each is present.
4. Check required and unknown properties in rule order, then subject order.
5. Validate each present property value: source form, effective category,
   scalar interpretation, reference constraints, and array constraints.
6. Traverse structural definitions materialized as array entries in array
   order, using the owning definition as their validation parent.
7. Validate ordinary direct child definitions in compiled order and then apply
   direct-child cardinality rules.
8. Continue recursively. Track visited compiled-definition object identities
   so retained target links are inspected but not traversed as containment.

References do not create validation traversal edges. A referenced definition is
validated where it occurs in its owning document/structural collection; the
reference site validates only target category and target kind. This avoids
duplicate diagnostics and recursion through valid reference graphs.

### Effective structure and provenance

- Structural validity is evaluated against the final compiled result after
  module resolution, composition, reference resolution, array composition, and
  effective-value computation.
- Rules use effective names for named collection constraints and lookup.
- Source form remains available for rules that explicitly require a reference,
  inline definition, array literal, text, or text composition.
- Inherited or referenced content is not rejected merely because it originated
  elsewhere. No local-versus-inherited restriction is included in the initial
  vocabulary because there is no concrete requirement for one.
- The primary diagnostic range is the most specific offending subject range:
  value/entry first, then property, then definition.
- Missing-member diagnostics point to the containing subject definition.
- Invalid validator rules point into the validator-definition document.
- When a diagnostic depends on a referenced target or rule declaration, the
  result should retain a related range for that location if the shared
  diagnostic API supports it.

### Diagnostics model

Use deterministic validator codes in a separate namespace from compiler
diagnostics. At minimum cover:

- invalid validator-definition structure;
- unknown subject definition kind;
- illegal root or containing kind;
- missing required property;
- unknown property;
- illegal or missing child definition;
- child or array cardinality violation;
- wrong source form or effective category;
- invalid semantic scalar;
- invalid array naming/mixing/entry kind;
- wrong reference target category or definition kind.

Validator results need severity, code, message, primary source range, and zero
or more related ranges. If the existing generic diagnostic class is expanded,
the change must remain domain-neutral and usable by both compiler and
consumers. Otherwise the Validator owns a parallel diagnostic type using the
shared `TNexusScriptRange`. Do not add validator codes or messages to compiler
units.

### Self-validation and bootstrap

The engine's hard-coded vocabulary is the bootstrap authority. There is no
special parser mode.

The bootstrap test is:

1. compile `Validator.nxscript` normally;
2. normalize it with the hard-coded Validator engine vocabulary;
3. use the normalized rules to validate that same compiled document;
4. require zero validator-definition and subject diagnostics;
5. mutate one rule fixture at a time and require the expected deterministic
   failure.

No exception is expected. The hard-coded vocabulary necessarily exists before
its declarative description can be interpreted; that is the engine's normal
consumer implementation, not a second validator or a language exception.

## Scope

- Validator engine and normalized rule model outside the generic compiler.
- Complete `Validator.nxscript` fixture.
- Initial `Schema.nxscript` and small valid/invalid schema fixtures.
- Definition, property, value, array, reference, cardinality, unknown-member,
  effective-structure, and provenance diagnostics described above.
- Focused tests and a validator test project/module integrated with the existing
  Nexus test conventions.
- The smallest domain-neutral diagnostic API refinement proven necessary by
  implementation.
- Documentation of the fixed validator vocabulary and API.

## Out Of Scope

- Automatic validator invocation based on a document's `doctype` association.
- Enforcement of `.nxscript` by the compiler.
- NexusLS, VS Code registration, completion, or syntax selection.
- Automatic selection or chaining of validators.
- Schema metadata translation, transformation, rendering, or NexusSchema
  production cutover.
- Build, Installer, UI, or other domain validator definitions beyond focused
  generic test fixtures.
- Regex, ranges of semantic scalar values, arbitrary predicates, callbacks,
  expressions, code execution, conditional rules, cross-document queries, or
  user-defined validator vocabulary.
- Validation of raw tokens, comments, quoting style, or other syntax already
  accepted or rejected by the compiler.
- Source-origin restrictions without a separately approved concrete use.
- A meta-meta-validator abstraction or compatibility layer.

## Staged Implementation Plan

### Stage 1: Freeze executable vocabulary fixtures

- Add a complete `Validator.nxscript` fixture covering every allowed
  validator kind, property, containment relationship, enum value, and default.
- Add the representative schema validator and minimal subject fixtures.
- Document normalization defaults and exact case-sensitivity behavior using the
  same case-insensitive name comparison convention currently used by
  NexusScript model lookup.
- Review the fixtures as ordinary NexusScript and compile them before adding
  validator code.

Acceptance: all fixtures compile through the unchanged generic compiler, and a
focused vocabulary inventory maps every fixture member to one engine-owned
semantic rule.

### Stage 2: Add validator-owned types and diagnostics

- Add enums/sets for source forms, effective categories, semantic scalar kinds,
  unknown-member policy, name policy, and reference target category.
- Add normalized language, definition, property, child, value, array, and
  reference rule objects with explicit ownership.
- Add validator diagnostics using shared source ranges. Extend the generic
  diagnostic type only if severity/related locations are demonstrably shared
  compiler-consumer requirements.

Acceptance: construction/destruction tests prove ownership; no validator
vocabulary appears in generic compiler/parser units.

### Stage 3: Normalize validator definitions

- Parse the compiled validator document into the normalized rule model.
- Require exactly one root `Language` definition.
- Validate all recognized rule kinds, members, source/effective value shapes,
  enum values, bounds, uniqueness, overlaps, and referenced kind names without
  requiring reciprocal `Parents`/`Children` relationships.
- Return deterministic invalid-validator diagnostics and no partial usable
  model on failure.

Acceptance: focused malformed-validator tests cover every vocabulary kind,
unknown members, missing members, bad enums, negative/reversed cardinality,
overlapping child rules, and unknown referenced kinds. Positive normalization
tests cover `Parents`-only, `Children`-only, and nonreciprocal declarations.

### Stage 4: Validate definitions, properties, and children

- Implement ordered effective-definition traversal.
- Validate known kinds, root legality, independent child-side `Parents` rules,
  independent parent-side `Children`/`UnknownChildren` rules, unknown
  properties, required properties, and direct-child cardinality.
- Traverse inline and reference-materialized structural definitions contained
  in arrays as collection children while never following reference target links
  as containment.

Acceptance: focused tests cover roots, nested definitions, array definitions,
composition-introduced members, unknowns, requirements, cardinality,
`Parents`-only acceptance/rejection, `Children`-only acceptance/rejection, the
intersection when both are present, and stable diagnostic order.

### Stage 5: Validate values and arrays

- Classify retained source form separately from effective result category.
- Add strict semantic Text/Integer/Boolean interpretation.
- Enforce array bounds, effective naming policy, entry categories, allowed
  definition kinds, and mixed-category policy.

Acceptance: focused tests cover every source form/effective category pairing,
named and unnamed scalar entries, inline definitions, definition references,
whole-array references, composed arrays, and all boundary cardinalities.

### Stage 6: Validate references through provenance

- Enforce reference-required rules using retained source kind.
- Inspect `ResolvedProperty` and `ResolvedDefinition` for allowed target
  categories and definition kinds.
- Emit related target/rule locations where supported.
- Prove that validation never parses or re-resolves reference source text and
  does not recursively traverse reference graphs.

Acceptance: property targets, definition targets, wrong target kinds, aliases,
renamed collection entries, and cyclic-but-compiler-valid relationship graphs
produce deterministic finite results.

### Stage 7: Prove bootstrap and domain separation

- Validate `Validator.nxscript` against itself.
- Validate `Schema.nxscript` against `Validator.nxscript`.
- Validate valid and invalid schema subjects against
  `Schema.nxscript`.
- Add a non-Schema miniature domain fixture to prove that the engine does not
  contain Schema vocabulary.
- Search generic compiler and Validator engine units for forbidden domain terms.

Acceptance: all three validation levels pass/fail as expected; the generic
compiler remains unchanged except for any approved domain-neutral diagnostic
refinement; no Schema, Build, Installer, or UI concepts occur in the Validator
engine.

### Stage 8: Documentation and integration boundary

- Document the public API, ownership, diagnostic ordering, vocabulary defaults,
  effective/provenance rules, and bootstrap process.
- Document `doctype` as the explicit association available to future consumer
  dispatch without making the generic compiler invoke validation.
- Identify, but do not implement, the future NexusLS/CLI validator resolver seam.

Acceptance: a consumer can compile two files, call the Validator engine, report
diagnostics, and free all objects without relying on filename inference.

## Sub-Agent Delegation

- Proposed role after approval: a `NexusScript Validator worker` owning the new
  validator folder, fixtures, and focused tests.
- Ownership boundary: the worker must not edit generic parser/compiler units,
  NexusSchema production code, NexusLS, or unrelated projects. Any proposed
  shared diagnostic change returns to Main Codex for explicit integration
  review before editing `NexusTools/Script/src`.
- Main Codex responsibilities: review normalized vocabulary against this plan,
  integrate any shared diagnostic seam, run builds/tests and forbidden-term
  searches, inspect ownership, and report deviations.
- Coordination risk: validator tests consume compiled-model internals, so model
  API changes and validator implementation must not be edited concurrently.

No sub-agent is started during planning. Implementation delegation begins only
after direct human approval.

## Verification Plan

- Compile the unchanged NexusScript executable and existing NexusScript tests
  before implementation.
- Compile all validator and subject `.nxscript` fixtures through the generic
  compiler.
- Build and run the focused Validator test module.
- Re-run the complete existing NexusScript suite, including inForce and Storm
  JSON/rendering parity.
- Require exact expected diagnostic codes, primary ranges, related ranges where
  applicable, and deterministic ordering.
- Add positive and negative tests for every vocabulary property and default.
- Run focused searches proving:
  - no Validator vocabulary entered lexer/parser/compiler control flow;
  - no Schema/Build/Installer/UI vocabulary entered the Validator engine;
  - no raw reference re-resolution exists in the Validator engine;
  - no compiler extension enforcement or validator filename inference was added.
- Inspect leaks/ownership under both successful and failed validator
  normalization and subject validation where available tooling permits.
- After approved implementation, create a fresh source archive with
  `scripts\New-NexusSourceArchive.ps1` and verify it contains `.nxscript`
  validator fixtures and no generated binaries.

## Risks And Questions

### Genuine contract/API gap: related diagnostic locations

The language contract supplies source/provenance information, but the current
diagnostic object has only one range. Validation can be implemented correctly
with primary ranges; richer "reference here, target/rule there" reporting may
require a domain-neutral related-range collection. Stage 2 must choose between
extending the shared diagnostic type or owning richer diagnostics solely in the
Validator. This is an API design choice, not a NexusScript syntax change.

### Structural containment of definition-valued array entries

For validation, a definition materialized in a property array is treated as a
structural child of the definition owning that property. This gives
`Table.Fields` entries the expected `Table` parent context without inventing a
dictionary or following arbitrary references. Tests must verify the current
compiled model provides enough ownership context; if it does not, expose the
smallest domain-neutral containment accessor rather than adding validator
knowledge to the compiler.

### Vocabulary size

The seven rule kinds are the proposed minimum that keeps definition, property,
value, array, and reference constraints orthogonal. Do not add regex,
cross-property predicates, conditional rules, or executable hooks during
implementation merely because they may be useful later.

No current requirement forces a NexusScript grammar change.

## Approval Gate

This plan is a design artifact only. No validator implementation, fixtures,
builds, tests, archives, or compiler changes begin until the human owner
explicitly approves implementation.
