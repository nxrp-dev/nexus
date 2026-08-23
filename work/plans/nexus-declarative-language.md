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

Build a new standalone `NexusScript` project under `NexusTools/Script`. NexusScript will provide the generic declarative-language compiler described by the contract, its generic tests, and a schema consumer/parity target that proves it can replace the current NexusSchema front end.

The production NexusSchema parser, executable path, project files, fixtures, and tests remain unchanged while NexusScript is constructed. NexusSchema cutover begins only after the completed NexusScript compiler and schema consumer independently compile migrated equivalents of the production schema inputs and demonstrate parity through the existing metadata, JSON, and rendering pipeline.

NexusScript documents may explicitly declare an optional
`doctype Path;` association. The declaration identifies another ordinary
NexusScript document for consumers without importing its namespace or causing
automatic validation. Filenames and filename components carry no validator or
consumer semantics; `.nxscript` remains the conventional extension rather than
a compiler-enforced requirement.

The intended pipeline is:

```text
source
  -> generic lexer/parser
  -> generic source model
  -> symbol binding
  -> composition and value resolution
  -> compiled declarative document
  -> NexusScript schema consumer
  -> existing metadata/transformation/rendering pipeline
```

The generic compiler must not know about tables, fields, templates, SQL, Mustache, or schema validation.

This is a clean side-by-side reconstruction. The implementation will follow the current contract rather than preserve the shape or syntax of the historical schema-specific parser. NexusScript will reach functional replacement parity before any production NexusSchema parsing path is modified. No compatibility parser or shim will be retained after cutover unless the human owner separately identifies and approves a current compatibility requirement.

The controlling safety rule is:

> No production NexusSchema parsing path is modified until the NexusScript compiler and schema consumer are independently functional and verified at the parity gate defined by this plan.

## Verified Findings

- `NexusTools/Schema/src/obNexusSchemaParser.pas` parses directly into `TMetaDataModuleList`; it does not produce a generic syntax or compiled document model.
- The current parser has hard-coded branches for schema vocabulary including tables, templates, types, attributes, children, variables, data files, and `uses`.
- `NexusTools/Schema/src/obNexusSchemaTypes.pas` defines schema-specific keywords and operators rather than a generic language token model.
- `NexusTools/Schema/src/obNexusSchemaTokenizer.pas` converts physical newlines into semicolon tokens, while the new contract requires explicit semicolons.
- Current reference parsing supports only the historical schema field-reference shape and stores table/field names directly in metadata fields.
- The current tokenizer and parser do not provide the generic nested definition model, unified member namespace, arrays, composition flattening, effective-scope reference rebinding, module imports/root selectors, compile-time text composition, or compiled reference provenance required by the contract.
- The legacy front-end units are directly referenced only by the NexusSchema executable, NexusSchema tests, project files, and their own token queue dependency.
- The downstream schema pipeline is already separable:
  - `obMetaDataModel.pas` and `obMetaDataModuleList.pas` own schema metadata;
  - `obMetaDataTransformations.pas` performs schema-specific expansion and reference processing;
  - `obMetaDataJSON.pas` serializes metadata;
  - `obMustacheRenderer.pas` renders generated outputs;
  - `obDataSourceProcessors.pas` handles delimited data sources.
- The command-line entry point in `NexusTools/Schema/src/NexusSchema.lpr` currently constructs the legacy parser, transforms metadata, writes JSON, and renders templates. This is the eventual cutover seam, not a construction-stage edit target.
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

### NexusScript ownership

- Owner: the standalone `NexusTools/Script` project.
- Responsibilities:
  - tokenize source while retaining source positions and ranges;
  - parse generic definitions, properties, values, arrays, references, composition selectors, modules, strings, escapes, and comments;
  - construct a generic source model;
  - construct scopes and enforce `Scope + Name` identity;
  - enforce the unified property/child-definition namespace;
  - resolve local and qualified references using the contract's scope rules;
  - compile modules into separate documents and expose imported roots under their declared identities;
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

### Temporary parity consumer ownership

- Owner during construction and parity proof: a clearly separated schema-parity area under `NexusTools/Script`, outside the generic compiler/runtime units.
- Responsibilities:
  - receive a successfully compiled generic document;
  - recognize the schema vocabulary expected by the current NexusSchema product;
  - validate schema-specific kinds, properties, nesting, references, and required values;
  - translate the generic compiled structure into `TMetaDataModuleList` and the existing schema metadata objects without modifying the production NexusSchema front end;
  - report schema diagnostics using source/provenance supplied by the generic compiler;
  - pass valid metadata through the existing transformations, JSON serialization, data processing, and Mustache rendering pipeline.

The parity consumer is construction scaffolding for proving replacement behavior; it is not part of the generic NexusScript language core. At cutover, move the completed schema interpretation into `NexusTools/Schema` ownership while NexusSchema consumes the stable NexusScript compiler API.

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
- The NexusScript schema consumer does not take hidden ownership of the compiled result; its ownership boundary must be explicit in its API.
- Module documents are compiled once per physical source identity within a compilation session and expose their declared roots without textual inclusion or renaming.
- Failure paths must release partially constructed documents, module state, and consumer metadata without relying on process termination.

## Scope

Expected implementation areas include:

- new `NexusTools/Script` folder-level instructions referencing the applicable Pascal standards;
- NexusScript executable and Lazarus project under `NexusTools/Script`;
- NexusScript test module/project under `NexusTools/Script/tests`;
- source-position, diagnostic, token, syntax, value, definition, reference, module, and compiled-document types owned by NexusScript;
- generic lexer/token stream, parser, scope/symbol construction, composition resolver, value/reference resolver, and module compilation session;
- temporary schema consumer and parity harness isolated from the NexusScript generic compiler/runtime;
- new-language parity fixtures corresponding to `StormSpecific.nxs`, `inForceMain.nxs`, and focused test inputs, stored outside the production NexusSchema fixture paths during construction;
- parity comparison of metadata JSON and representative rendered outputs;
- final NexusSchema integration only after the parity gate passes;
- production fixture migration, obsolete front-end removal, and affected documentation only during the approved cutover stages.

Candidate legacy removals, subject to focused call-site verification, are:

- `NexusTools/Schema/src/obNexusSchemaTypes.pas`;
- `NexusTools/Schema/src/obNexusSchemaTokenizer.pas`;
- `NexusTools/Schema/src/obTokenQueue.pas`;
- the schema-specific implementation and API of `NexusTools/Schema/src/obNexusSchemaParser.pas`.

The final unit names under `NexusTools/Script` should follow the repository's `tp...` ownership for shared type definitions and `ob...` ownership for compiler objects. Definitions must have one real owner; do not add alias or re-export units to preserve the legacy surface.

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
- Any edit to the production NexusSchema parser, tokenizer, executable path, project files, tests, or existing `.nxs` fixtures before the NexusScript parity gate passes.

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
- module declaration with an optional root selector and path;
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
- imported-root collision with other root-addressable names;
- nested reuse of names in different scopes.

Represent symbol identity directly rather than using display strings as the long-term identity mechanism. Retain source declarations for diagnostics and navigation.

Verification checkpoint: positive and negative namespace tests, including same-name/different-kind rejection and valid nested shadowing.

### Stage 5: Resolve references

Implement the contract's lookup rules exactly:

- single-segment references inspect the current scope only;
- qualified references compare the current scope name, then enclosing scope names, for the first segment;
- after the first segment matches, remaining segments resolve strictly downward;
- no implicit sibling lookup;
- imported roots are available throughout nested scopes as the explicit module-level exception;
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
- exposes imported roots under their declared names;
- optionally filters the import to one declared root without renaming it;
- rejects duplicate imported-root names and collisions with local roots;
- detects dependency cycles and reports a deterministic chain;
- preserves document boundaries and source locations.

Module loader mechanics must implement the observable contract without treating deleted design-history questions as latent requirements. If an implementation choice would materially alter source-visible behavior and the contract does not determine the answer, pause with that one concrete ambiguity instead of creating a general unresolved-design phase.

Verification checkpoint: relative imports, quoted/unquoted paths, natural root names, root selectors, nested import visibility, root collisions, repeated physical imports, missing files, invalid selectors, and dependency cycles.

### Stage 9: Implement the temporary schema parity consumer

Create an isolated schema parity consumer under `NexusTools/Script` that consumes only the generic compiled API. Keep it outside the generic NexusScript compiler/runtime units. During this stage, it may use the existing downstream schema metadata, transformation, JSON, data-source, and rendering units as read-only dependencies, but it must not modify the production NexusSchema parser or executable path.

The adapter will:

- identify the schema kinds and properties supported by the current product;
- validate required schema structure before metadata construction;
- translate compiled definitions, values, arrays, and resolved references into existing metadata objects;
- preserve existing schema output meaning where it is still a current requirement;
- report consumer diagnostics against compiler-provided source ranges;
- leave generic compilation unaware of schema types.

Review the current parser, metadata model, transformations, example inputs, and Mustache templates together to map every currently used schema concept. Put behavior in the schema consumer when it assigns schema meaning; leave it in the generic compiler only when it is mandated by the language contract.

Verification checkpoint: consumer tests asserting metadata modules, tables/templates, fields, attributes, data registrations, and references from representative new-language documents.

### Stage 10: Prove replacement parity independently

Build a NexusScript parity harness that exercises the new compiler and schema consumer without routing production NexusSchema through them.

Create new-language parity fixtures under `NexusTools/Script` corresponding to the current production NexusSchema inputs. Keep the original `.nxs` files unchanged so the existing executable remains usable and provides the comparison baseline.

For each parity case:

1. run the unchanged NexusSchema path against the original input;
2. run NexusScript and its schema consumer against the corresponding new-language input;
3. normalize intentionally unstable output such as generated paths or ordering only when the existing contract does not make it significant;
4. compare schema metadata JSON structurally;
5. compare representative rendered outputs;
6. investigate and correct the replacement rather than altering NexusSchema to make parity easier.

Parity requires more than successful execution. The new path must demonstrate equivalent schema meaning for the current repository inputs, including representative tables, fields, references, attributes, template expansion, data registration, and rendered Firebird output.

Verification checkpoint: a recorded parity matrix passes for both repository schema inputs and focused fixtures. The matrix identifies the original input, NexusScript equivalent, baseline artifacts, replacement artifacts, comparison method, and result.

### Stage 11: Parity gate and cutover approval

Before any production NexusSchema edit, Main Codex reviews the complete replacement and reports:

- NexusScript compiler and generic test results;
- schema-consumer test results;
- parity matrix results;
- any intentional output differences and their justification;
- focused proof that the generic compiler contains no schema-domain semantics;
- the exact production NexusSchema files proposed for cutover.

The human owner must approve the cutover after reviewing this evidence. General implementation approval for Stages 1-10 does not by itself waive this parity gate.

If parity is incomplete, continue correcting NexusScript without modifying the production NexusSchema parsing path.

### Stage 12: Cut NexusSchema over to NexusScript

After explicit cutover approval:

- move the proven schema-consumer behavior from the temporary parity area into `NexusTools/Schema` ownership, preserving the stable generic compiler boundary;
- update `NexusSchema.lpr` to invoke the completed NexusScript compiler and the schema-owned consumer;
- update NexusSchema project search paths and unit lists to use the completed replacement directly;
- migrate the production `.nxs` examples and NexusSchema test fixtures to the new language;
- replace legacy parser/tokenizer tests with integration tests that exercise the completed compiler/consumer boundary;
- preserve the existing metadata transformation, JSON, data-source, Mustache, CLI, and output behavior except for approved differences established at parity review;
- do not retain parallel production parsing paths.

Verification checkpoint: the production NexusSchema project and test module compile, migrated inputs run through the production executable, and their artifacts match the already approved NexusScript parity results.

### Stage 13: Remove the legacy NexusSchema front end

After production cutover verification passes:

- remove the old tokenizer, token queue, schema-specific token types, and parser implementation;
- remove obsolete project entries and `uses` references;
- remove tests that assert historical syntax or tokenization;
- run focused searches proving the old units and APIs are gone.

Do not keep wrappers, aliases, deprecated classes, or compatibility units solely to avoid updating repository call sites.

### Stage 14: Documentation and final architecture review

Document NexusScript as the owner of the declarative compiler and its generic language behavior. Update NexusSchema documentation to describe its consumer role and production use of NexusScript after cutover.

Documentation must describe:

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
- the side-by-side parity evidence and cutover boundary;
- removal of legacy code and documentation.

## Sub-Agent Delegation

After direct implementation approval, assign Stages 1-10 to one named `NexusScript worker` by default. Do not assign that worker production NexusSchema write ownership before the parity gate and separate cutover approval.

### Worker ownership

- `NexusTools/Script/` project, source, tests, parity fixtures, and parity harness;
- generic compiler plus the isolated temporary schema parity consumer;
- NexusScript documentation;
- read-only inspection of `NexusTools/Schema/` during construction and parity.

### Main Codex responsibilities

- provide the worker the complete approved plan and current constraints;
- preserve unrelated worktree changes and define the allowed write set;
- review model ownership before accepting downstream stages;
- inspect every worker diff and reject domain leakage or compatibility scaffolding;
- enforce the production NexusSchema no-touch boundary before parity approval;
- review and report the parity matrix before requesting cutover approval;
- make tightly scoped integration corrections when required after cutover approval;
- run or coordinate final compile, tests, focused searches, manual CLI checks, archive creation, and reporting.

### Delegation shape

Use one worker for the coherent NexusScript construction rather than assigning concurrent writers to lexer, parser, resolver, and model units. Those units share evolving interfaces and ownership rules; parallel edits would create a high-conflict integration seam.

If the compiler API and schema consumer boundary stabilize cleanly, a second bounded `NexusScript test reviewer` may inspect coverage or add tests in files not being edited by the primary worker. Do not allow overlapping writes to the same test or project files.

After cutover approval, the NexusScript worker may receive a refreshed assignment for the bounded NexusSchema integration/removal stages, or a separate `NexusSchema cutover worker` may own only `NexusTools/Schema/`. Main Codex must define non-overlapping file ownership before either assignment.

No sub-agent implementation begins before direct human approval of this plan.

## Verification Plan

### Compile checkpoints

Compile NexusScript frequently during construction. Before the parity gate, the required builds are:

```text
lazbuild NexusTools\Script\tests\NexusScriptTestModule.lpi
lazbuild NexusTools\Script\NexusScript.lpi
```

The existing NexusSchema projects must remain buildable from the unchanged production path throughout Stages 1-10. Compile them as regression checks without editing them:

```text
lazbuild NexusTools\Schema\tests\NexusSchemaTestModule.lpi
lazbuild NexusTools\Schema\NexusSchema.lpi
```

After cutover approval, both NexusScript and NexusSchema projects are required final builds.

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
- module imports, root selectors, nested visibility, collisions, repeated imports, failures, and dependency cycles;
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

### Independent parity verification

Before cutover, run the unchanged NexusSchema executable against the original repository inputs and NexusScript against the corresponding new-language parity fixtures. Confirm:

- both paths complete successfully for valid equivalents;
- both paths produce metadata JSON and representative rendered output;
- structural JSON comparison passes after only documented normalization;
- representative tables, fields, references, attributes, and rendered statements match;
- NexusScript invalid syntax reports filename and source location;
- NexusScript unresolved references and composition/module cycles fail deterministically;
- NexusScript missing module files report the importing source and declared path;
- the production NexusSchema sources and executable path remain unchanged.

After cutover approval, repeat the accepted parity cases through the production NexusSchema executable using migrated inputs.

### Focused searches

Use focused repository searches to prove:

- generic compiler units contain no schema-domain vocabulary such as `Table`, `Field`, `Template`, Firebird, SQL, Mustache, or metadata-model classes except inside neutral test fixture text;
- no lexer path converts newlines into semicolons;
- the generic parser/compiler never constructs `TMetaDataModuleList` or schema metadata classes;
- before parity approval, `git diff` shows no modification to the production NexusSchema parser, tokenizer, executable path, project files, tests, or existing `.nxs` fixtures;
- after cutover, no production call sites use `obNexusSchemaTokenizer`, `obNexusSchemaTypes`, `obTokenQueue`, or the legacy parser API;
- after cutover, no compatibility parser, alias unit, or re-export remains;
- after cutover, all production NexusSchema `.nxs` sources use the new syntax.

### Final checkpoint

After compilation, tests, CLI verification, focused searches, and documentation review pass, create a fresh source archive with:

```text
scripts\New-NexusSourceArchive.ps1
```

Verify that the archive contains NexusScript, its compiler, schema consumer, tests, parity evidence, the cut-over NexusSchema project, migrated production inputs, and documentation. Report any verification step that could not be run.

## Risks And Implementation Decisions

The language contract is authoritative. Deleted design-history uncertainty must not be reintroduced as an implicit requirements list.

The following are implementation decisions to resolve while preserving the contract:

- Keep the new compiler and construction harness owned by `NexusTools/Script` as NexusScript. Do not place them under `NexusTools/Schema` merely because schema parity is the first replacement target.
- Choose concrete Pascal classes/records, collections, and ownership patterns for source and compiled models without exposing storage accidents as language behavior.
- Choose deterministic diagnostic codes and recovery boundaries without weakening compile-time errors required by the contract.
- Choose a physical-source canonicalization and module-cache key suitable for Windows and supported target platforms.
- Choose a deterministic module dependency-cycle diagnostic and stop compilation safely.
- Create separate NexusScript parity fixtures during construction; migrate existing production `.nxs` sources and tests only after parity and cutover approval.

If implementation encounters a genuine contract-level ambiguity that materially changes observable source behavior, stop and present that specific ambiguity with a minimal example. Do not reopen settled syntax or resurrect removed alternatives merely because the implementation requires an internal choice.

The current dirty worktree is an integration risk. Before implementation commits, inspect status and stage only files owned by the approved work. Never discard or rewrite unrelated changes. During Stages 1-10, the allowed production write set excludes `NexusTools/Schema`.

## Approval Gate

This work plan authorizes planning only.

No implementation edits, builds, tests, program launches, archive creation, implementation delegation, or implementation commits begin until the human owner directly approves this plan for implementation.

Once approved, implementation follows this plan's architecture and scope. If the implementation proves a material part of the plan wrong, pause and report the conflict before proceeding. Small necessary adjustments within the approved architecture may be made and must be reported.
