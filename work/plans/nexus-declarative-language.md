# Work Plan: Nexus Declarative Language Reconstruction

## Inputs

- Source request: direct human-owner request to produce a full implementation work plan for the Nexus declarative language contract.
- Language contract: `C:\Users\kcollins\Downloads\nexus-declarative-language-contract.md`.
- Related discussion/review notes: the generic language must remain structurally generic; schema meaning belongs to a consumer; deleted design-history uncertainty must not be reintroduced as latent contract requirements.
- Existing constraints:
  - follow `.ai/standards/pascal.md`;
  - keep reusable language/compiler code outside tool-specific ownership;
  - do not retain legacy APIs or syntax merely for compatibility;
  - preserve the implementation approval gate;
  - do not disturb unrelated worktree changes.

## Summary

Reconstruct NexusSchema as a generic declarative-language compiler with a separate schema consumer. The generic compiler will parse and compile only the structural language described by the contract. The NexusSchema consumer will interpret the compiled structure as schema metadata and feed the existing metadata transformation, JSON, Mustache rendering, and output pipeline.

The intended pipeline is:

```text
source
  -> generic lexer/parser
  -> generic source model
  -> symbol binding
  -> composition and value resolution
  -> compiled declarative document
  -> schema consumer
  -> existing metadata/transformation/rendering pipeline
```

The generic compiler must not know about tables, fields, templates, SQL, Mustache, or schema validation.

This is a clean reconstruction. The implementation will follow the current contract rather than preserve the shape or syntax of the historical schema-specific parser. Existing repository scripts will be migrated to the new language. No compatibility parser or shim will be retained unless the human owner separately identifies and approves a current compatibility requirement.

## Verified Findings

- `NexusTools/Schema/src/obNexusSchemaParser.pas` parses directly into `TMetaDataModuleList`; it does not produce a generic syntax or compiled document model.
- The current parser has hard-coded branches for schema vocabulary including tables, templates, types, attributes, children, variables, data files, and `uses`.
- `NexusTools/Schema/src/obNexusSchemaTypes.pas` defines schema-specific keywords and operators rather than a generic language token model.
- `NexusTools/Schema/src/obNexusSchemaTokenizer.pas` converts physical newlines into semicolon tokens, while the new contract requires explicit semicolons.
- Current reference parsing supports only the historical schema field-reference shape and stores table/field names directly in metadata fields.
- The current tokenizer and parser do not provide the generic nested definition model, unified member namespace, arrays, composition flattening, effective-scope reference rebinding, general module aliases/root selectors, compile-time text composition, or compiled reference provenance required by the contract.
- The legacy front-end units are directly referenced only by the NexusSchema executable, NexusSchema tests, project files, and their own token queue dependency.
- The downstream schema pipeline is already separable:
  - `obMetaDataModel.pas` and `obMetaDataModuleList.pas` own schema metadata;
  - `obMetaDataTransformations.pas` performs schema-specific expansion and reference processing;
  - `obMetaDataJSON.pas` serializes metadata;
  - `obMustacheRenderer.pas` renders generated outputs;
  - `obDataSourceProcessors.pas` handles delimited data sources.
- The command-line entry point in `NexusTools/Schema/src/NexusSchema.lpr` currently constructs the legacy parser, transforms metadata, writes JSON, and renders templates. This is the principal integration seam for the new compiler and schema consumer.
- Existing repository inputs `NexusTools/Schema/StormSpecific.nxs`, `NexusTools/Schema/inForceMain.nxs`, and test fixtures use the historical syntax and must be migrated for an end-to-end cutover.
- The existing `NexusSchemaTestModule` provides the correct focused verification project but currently has only tokenizer, parser, JSON-root, and Firebird-render smoke coverage.
- The worktree contains unrelated modified and untracked files outside this plan. They must be preserved and excluded from Nexus declarative-language commits.

## Architecture Problem

The current implementation combines three responsibilities in one parser path:

1. recognizing source syntax;
2. interpreting schema-domain vocabulary;
3. constructing the schema metadata model.

This prevents the parser/compiler from remaining ignorant of consumer meaning. It also makes generic definitions, nesting, composition, module scopes, reference resolution, value dependency analysis, and provenance impossible to model cleanly without adding further schema-specific branches.

The correction is not to generalize the existing metadata parser through additional conditionals. The correction is to establish a real generic language boundary. Source compilation must produce a domain-neutral compiled document. Schema interpretation begins only after that boundary.

## Target Contract

### Generic compiler ownership

- Owner: shared Nexus library code, placed according to repository ownership rules rather than under a schema-specific consumer unit.
- Responsibilities:
  - tokenize source while retaining source positions and ranges;
  - parse generic definitions, properties, values, arrays, references, composition selectors, modules, strings, escapes, and comments;
  - construct a generic source model;
  - construct scopes and enforce `Scope + Name` identity;
  - enforce the unified property/child-definition namespace;
  - resolve local and qualified references using the contract's scope rules;
  - compile modules into separate documents and expose imported scopes through aliases;
  - flatten inherited composition with the contract's precedence and collision behavior;
  - resolve inherited references recursively against the effective composed definition after flattening and precedence;
  - evaluate compile-time text composition and property dependency graphs;
  - reject duplicate members, unresolved references, illegal composition targets, ambiguous category collisions, and cycles;
  - preserve resolved targets, effective values where applicable, source locations, and reference provenance in the compiled document;
  - return deterministic diagnostics without assigning domain meaning.

### Generic compiler non-responsibilities

The generic compiler must not:

- recognize `Table`, `Field`, `Template`, `Type`, `Attribute`, or other consumer vocabulary as built-in language concepts;
- validate schema-specific parent/child relationships or required properties;
- construct `TMetaDataModuleList` or other schema-domain objects;
- know about SQL, Firebird, data import, Mustache, or generated output files;
- preserve historical syntax or APIs without an explicitly approved current requirement.

### Schema consumer ownership

- Owner: `NexusTools/Schema`.
- Responsibilities:
  - receive a successfully compiled generic document;
  - recognize the schema vocabulary expected by the current NexusSchema product;
  - validate schema-specific kinds, properties, nesting, references, and required values;
  - translate the generic compiled structure into `TMetaDataModuleList` and the existing schema metadata objects;
  - report schema diagnostics using source/provenance supplied by the generic compiler;
  - pass valid metadata through the existing transformations, JSON serialization, data processing, and Mustache rendering pipeline.

### State and ownership flow

```text
source text/file
  -> source document owned by compiler session
  -> compiled document owned by compiler result
  -> schema metadata owned by schema consumer/caller
  -> transformed metadata owned by existing schema pipeline
  -> serialized/rendered output
```

- The compiler session owns source buffers, tokens, parse nodes, module records, and diagnostics for its lifetime.
- The compiled result owns the domain-neutral effective definitions, values, resolved references, and provenance exposed to consumers.
- The schema consumer does not take hidden ownership of the compiled result; its ownership boundary must be explicit in its API.
- Module documents are compiled once per physical source identity within a compilation session and exposed through importer aliases without textual inclusion.
- Failure paths must release partially constructed documents, module state, and consumer metadata without relying on process termination.

## Scope

Expected implementation areas include:

- shared source-position, diagnostic, token, syntax, value, definition, reference, module, and compiled-document types;
- generic lexer/token stream;
- generic parser;
- scope and symbol construction;
- composition resolver;
- value/reference resolver;
- compilation session and module loader;
- NexusSchema consumer/adapter;
- `NexusTools/Schema/src/NexusSchema.lpr` integration;
- `NexusTools/Schema/NexusSchema.lpi` and test-project unit lists/search paths;
- `NexusTools/Schema/tests/tsNXSchemaCoreTests.pas` or coherently split focused test units;
- migration of `StormSpecific.nxs`, `inForceMain.nxs`, and generated test fixtures;
- NexusSchema architecture and language documentation affected by the cutover;
- removal of obsolete front-end units after all call sites are migrated.

Candidate legacy removals, subject to focused call-site verification, are:

- `NexusTools/Schema/src/obNexusSchemaTypes.pas`;
- `NexusTools/Schema/src/obNexusSchemaTokenizer.pas`;
- `NexusTools/Schema/src/obTokenQueue.pas`;
- the schema-specific implementation and API of `NexusTools/Schema/src/obNexusSchemaParser.pas`.

The final unit names and shared library folder should follow the repository's `tp...` ownership for shared type definitions and `ob...` ownership for compiler objects. Definitions must have one real owner; do not add alias or re-export units to preserve the legacy surface.

## Out Of Scope

- A complete declarative validator-definition vocabulary or validator API beyond what the schema consumer needs for this cutover.
- Nexus language-server features, editor completion, navigation, formatting, semantic tokens, or refactoring.
- Raw, multiline, or alternate quoted-string forms not present in the contract.
- General arithmetic, interpolation, functions, macros, conditionals, loops, maps, tuples, sets, or executable statements.
- Module re-export or transitive exposure not required by the contract.
- A compatibility mode for historical `.nxs` syntax.
- Compatibility aliases for removed parser/tokenizer classes or units.
- Opportunistic redesign of schema metadata, transformations, JSON shape, templates, CLI switches, or data-source processing.
- Changes to unrelated Nexus tools, NexusUI, NexusLS, NexusTask, installer work, or existing unrelated worktree changes.

## Staged Implementation Plan

### Stage 1: Establish shared source and diagnostic types

Create the smallest coherent shared type layer required by every compiler stage:

- source identity;
- byte/character offset as appropriate for the chosen source representation;
- line and column;
- source range;
- diagnostic severity, code/category, message, primary range, and related ranges;
- token kind and token record/class;
- reference-path segment representation.

Keep these definitions free of parser behavior and schema vocabulary. Add focused construction and location tests before the types spread through later units.

### Stage 2: Implement the generic lexer

Implement lexical recognition for:

- identifiers and unquoted scalar text;
- `{`, `}`, `:`, `;`, `(`, `)`, `,`, `[`, `]`, `@`, `.`, and `+`;
- double-quoted text;
- `^` escapes: `^^`, `^"`, `^n`, `^r`, and `^t`;
- `//` comments;
- non-nesting `/* ... */` comments;
- whitespace without converting newlines into semicolons;
- end of file and invalid/unterminated constructs.

Preserve the source range for every token and diagnostic. Keep quoted content, unquoted trimmed content, and syntax tokens distinguishable without assigning consumer primitive types.

Verification checkpoint: compile and run lexer tests covering every token, escape, comment boundary, explicit semicolon, and malformed-source path.

### Stage 3: Build the generic source model and parser

Define one generic source representation for:

- document;
- module declaration with alias, optional root selector, and path;
- definition with kind, name, optional composition selectors, properties, and child definitions;
- property;
- scalar, quoted text, array, reference, and text-composition value expressions;
- source provenance on every declaration and expression.

Implement parsing for the decided syntax. The parser must preserve structure and produce syntax diagnostics; it must not recognize domain kinds or construct schema metadata.

Parser recovery should be limited to useful, deterministic synchronization at semicolons, closing brackets, and closing braces. Do not add speculative recovery abstractions before focused malformed-source tests demonstrate their need.

Verification checkpoint: parse the contract's representative forms and assert the generic source tree, member ordering, values, ranges, and diagnostics.

### Stage 4: Construct scopes and enforce member identity

Build document and definition scopes independently of domain semantics.

Enforce:

- definition identity as `Scope + Name`;
- `Kind` exclusion from identity;
- unique local property names;
- unique local child-definition names;
- property/child local name collision errors;
- module alias collision with other root-addressable names;
- nested reuse of names in different scopes.

Represent symbol identity directly rather than using display strings as the long-term identity mechanism. Retain source declarations for diagnostics and navigation.

Verification checkpoint: positive and negative namespace tests, including same-name/different-kind rejection and valid nested shadowing.

### Stage 5: Resolve references

Implement the contract's lookup rules exactly:

- single-segment references inspect the current scope only;
- qualified references compare the current scope name, then enclosing scope names, for the first segment;
- after the first segment matches, remaining segments resolve strictly downward;
- no implicit sibling lookup;
- module aliases are available throughout nested scopes as the explicit module-level exception;
- every reference must resolve during compilation.

Store the originating source expression, resolved symbol target, target source location, and consumer-visible provenance. A property target may contribute an effective value; a definition target remains a resolved structural reference without scalar substitution.

Verification checkpoint: local, self-qualified, ancestor-qualified, explicit sibling, forbidden implicit sibling, module-qualified, unresolved, property-target, and definition-target cases.

### Stage 6: Resolve inherited composition

Resolve composition selectors using the corresponding selector lookup rules and require definition targets.

Implement:

- empty and absent composition lists;
- multiple sources applied left to right;
- rightmost inherited precedence followed by local precedence;
- property-over-property replacement;
- child-definition-over-child-definition replacement independent of kind;
- compile-time ambiguity when the same effective name crosses property/child categories;
- complete replacement rather than implicit recursive merging of a colliding child definition;
- composition-cycle detection;
- preservation of declaration and composition provenance.

After flattening and precedence, resolve inherited references recursively against the effective composed definition. Do not introduce additional reference categories or preserve source bindings contrary to that rule.

Verification checkpoint: single and multiple composition, local overrides, child replacement, category collision, nested composition, cycle failure, and effective reference rebinding.

### Stage 7: Evaluate values and dependency graphs

Compile generic values without adding a consumer primitive type system.

Implement:

- trimmed unquoted scalar text;
- exact quoted text after escape processing;
- arrays of `ValueExpression`;
- left-associative text composition;
- unquoted, quoted, and text-resolving reference operands;
- literal whitespace and literal `+` through quoting;
- forward property references;
- recursive effective-value resolution;
- value-dependency cycle detection;
- rejection of definition references as text operands.

Retain both effective results and contributing expression/reference provenance. Keep absence of an effective scalar value distinct from empty text and any consumer interpretation of `null`-like text.

Verification checkpoint: arrays, nested expressions as permitted by the grammar, mixed text operands, forward chains, definition-operand rejection, and complete cycle diagnostics.

### Stage 8: Implement module compilation

Add a compilation session that:

- loads the entry document;
- resolves each declared module path according to one consistent filesystem policy;
- compiles imported documents separately;
- tracks physical source identity to avoid redundant compilation;
- exposes an imported root or selected nested definition under the importer alias;
- resolves root selectors strictly downward;
- allows multiple aliases for the same compiled physical document;
- detects dependency cycles and reports a deterministic chain;
- preserves document boundaries and source locations.

Module loader mechanics must implement the observable contract without treating deleted design-history questions as latent requirements. If an implementation choice would materially alter source-visible behavior and the contract does not determine the answer, pause with that one concrete ambiguity instead of creating a general unresolved-design phase.

Verification checkpoint: relative imports, quoted/unquoted paths, aliases, root selectors, nested alias visibility, alias collisions, repeated physical imports, missing files, invalid selectors, and dependency cycles.

### Stage 9: Implement the NexusSchema consumer

Create a schema-owned adapter that consumes only the generic compiled API.

The adapter will:

- identify the schema kinds and properties supported by the current product;
- validate required schema structure before metadata construction;
- translate compiled definitions, values, arrays, and resolved references into existing metadata objects;
- preserve existing schema output meaning where it is still a current requirement;
- report consumer diagnostics against compiler-provided source ranges;
- leave generic compilation unaware of schema types.

Review the current parser, metadata model, transformations, example inputs, and Mustache templates together to map every currently used schema concept. Put behavior in the schema consumer when it assigns schema meaning; leave it in the generic compiler only when it is mandated by the language contract.

Verification checkpoint: consumer tests asserting metadata modules, tables/templates, fields, attributes, data registrations, and references from representative new-language documents.

### Stage 10: Integrate the command-line pipeline and migrate sources

Update `NexusSchema.lpr` to:

1. create the generic compilation session;
2. compile the requested metadata source and modules;
3. stop with useful diagnostics on language errors;
4. invoke the schema consumer;
5. stop with useful diagnostics on schema errors;
6. continue through the existing metadata transform, JSON, data, Mustache, and output stages.

Migrate the repository's `.nxs` examples and test fixtures to the new language. Do not retain dual parsing paths. Update Lazarus project unit lists and search paths to use the real shared compiler and consumer units directly.

Verification checkpoint: both example inputs compile through the new front end, schema metadata serializes, Firebird output renders, and command-line failures return clear source diagnostics.

### Stage 11: Remove the legacy front end

After all call sites have moved:

- remove the old tokenizer, token queue, schema-specific token types, and parser implementation;
- remove obsolete project entries and `uses` references;
- remove tests that assert historical syntax or tokenization;
- replace them with contract-level and consumer-level assertions;
- run focused searches proving the old units and APIs are gone.

Do not keep wrappers, aliases, deprecated classes, or compatibility units solely to avoid updating repository call sites.

### Stage 12: Documentation and final architecture review

Update NexusSchema documentation to describe:

- the generic compiler pipeline;
- the compiled-document/consumer boundary;
- the current declarative syntax;
- schema consumer behavior;
- command-line use with migrated examples.

Perform a final integration review of:

- ownership and destruction;
- absence of domain vocabulary in the generic compiler;
- source/provenance completeness;
- scope and reference behavior;
- composition flattening and rebinding;
- module caching and failure cleanup;
- consumer-only schema semantics;
- removal of legacy code and documentation.

## Sub-Agent Delegation

After direct implementation approval, assign the coherent compiler and NexusSchema cutover to one named `NexusSchema worker` by default.

### Worker ownership

- shared generic language/compiler units selected by the approved repository placement;
- `NexusTools/Schema/src/` compiler-consumer integration;
- `NexusTools/Schema/tests/` focused tests;
- NexusSchema project files and migrated `.nxs` fixtures;
- affected NexusSchema documentation.

### Main Codex responsibilities

- provide the worker the complete approved plan and current constraints;
- preserve unrelated worktree changes and define the allowed write set;
- review model ownership before accepting downstream stages;
- inspect every worker diff and reject domain leakage or compatibility scaffolding;
- make tightly scoped integration corrections when required;
- run or coordinate final compile, tests, focused searches, manual CLI checks, archive creation, and reporting.

### Delegation shape

Use one worker for the full coherent implementation rather than assigning concurrent writers to lexer, parser, resolver, and model units. Those units share evolving interfaces and ownership rules; parallel edits would create a high-conflict integration seam.

If the compiler API and schema consumer boundary stabilize cleanly, a second bounded `NexusSchema test reviewer` may inspect coverage or add tests in files not being edited by the primary worker. Do not allow overlapping writes to the same test or project files.

No sub-agent implementation begins before direct human approval of this plan.

## Verification Plan

### Compile checkpoints

Compile frequently after structural stages, with these final required builds:

```text
lazbuild NexusTools\Schema\tests\NexusSchemaTestModule.lpi
lazbuild NexusTools\Schema\NexusSchema.lpi
```

If the shared compiler receives its own focused test project during implementation, compile and run that project as an additional required checkpoint.

### Automated language tests

Cover at minimum:

- explicit braces and semicolons;
- generic `Kind Name` definitions;
- properties and nested definitions;
- duplicate definitions and unified-member collisions;
- quoted/unquoted text and trimming;
- all decided escapes;
- line and block comments, including non-nesting behavior;
- arrays;
- text composition and literal quoting;
- local and qualified references;
- explicit sibling traversal and rejected implicit sibling lookup;
- property and definition reference results;
- unresolved-reference errors;
- forward value references and dependency cycles;
- composition selectors, precedence, replacement, ambiguity, cycles, and rebinding;
- module aliases, root selectors, nested visibility, collisions, repeated imports, failures, and dependency cycles;
- source ranges and diagnostic locations for representative failures.

### Automated schema-consumer tests

Cover at minimum:

- conversion of representative schema definitions into the current metadata model;
- table/template/field behavior still required by the product;
- schema reference mapping;
- attributes and data registrations used by current fixtures;
- consumer diagnostics for invalid schema structure;
- metadata JSON root and representative content;
- end-to-end Firebird Mustache rendering.

### Command-line verification

Run the NexusSchema executable against both migrated repository inputs using their current template/output paths. Confirm:

- valid inputs complete successfully;
- expected JSON and rendered files are produced;
- output contains representative expected tables/fields rather than merely existing;
- invalid syntax reports filename and source location;
- unresolved references and composition/module cycles fail deterministically;
- missing module files report the importing source and declared path.

### Focused searches

Use focused repository searches to prove:

- generic compiler units contain no schema-domain vocabulary such as `Table`, `Field`, `Template`, Firebird, SQL, Mustache, or metadata-model classes except inside neutral test fixture text;
- no production call sites use `obNexusSchemaTokenizer`, `obNexusSchemaTypes`, `obTokenQueue`, or the legacy parser API;
- no lexer path converts newlines into semicolons;
- the generic parser/compiler never constructs `TMetaDataModuleList` or schema metadata classes;
- no compatibility parser, alias unit, or re-export was left behind;
- all repository `.nxs` sources use the new syntax.

### Final checkpoint

After compilation, tests, CLI verification, focused searches, and documentation review pass, create a fresh source archive with:

```text
scripts\New-NexusSourceArchive.ps1
```

Verify that the archive contains the new compiler, schema consumer, tests, migrated inputs, project files, and documentation. Report any verification step that could not be run.

## Risks And Implementation Decisions

The language contract is authoritative. Deleted design-history uncertainty must not be reintroduced as an implicit requirements list.

The following are implementation decisions to resolve while preserving the contract:

- Place reusable compiler types and objects under the correct shared Nexus library ownership. Do not leave the generic compiler owned by `NexusTools/Schema` merely because that is its first consumer.
- Choose concrete Pascal classes/records, collections, and ownership patterns for source and compiled models without exposing storage accidents as language behavior.
- Choose deterministic diagnostic codes and recovery boundaries without weakening compile-time errors required by the contract.
- Choose a physical-source canonicalization and module-cache key suitable for Windows and supported target platforms.
- Choose a deterministic module dependency-cycle diagnostic and stop compilation safely.
- Migrate existing `.nxs` sources and tests directly rather than adding compatibility machinery.

If implementation encounters a genuine contract-level ambiguity that materially changes observable source behavior, stop and present that specific ambiguity with a minimal example. Do not reopen settled syntax or resurrect removed alternatives merely because the implementation requires an internal choice.

The current dirty worktree is an integration risk. Before implementation commits, inspect status and stage only files owned by the approved work. Never discard or rewrite unrelated changes.

## Approval Gate

This work plan authorizes planning only.

No implementation edits, builds, tests, program launches, archive creation, implementation delegation, or implementation commits begin until the human owner directly approves this plan for implementation.

Once approved, implementation follows this plan's architecture and scope. If the implementation proves a material part of the plan wrong, pause and report the conflict before proceeding. Small necessary adjustments within the approved architecture may be made and must be reported.
