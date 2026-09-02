# Work Plan: NexusScript External Data Source and Manifest Rendering

## Inputs

- Human-owner conversation request and subsequent design discussion.
- Pasted request, `NexusScript External Data Source and Manifest Rendering Work
  Plan`.
- Current NexusScript compiler, compilation session, JSON emitter, CLI manifest
  renderer, validator, tests, and schema-generation parity artifacts.
- Historical NexusSchema parser, delimited-data processor, command dispatch,
  and Firebird data-import Mustache script.
- Repository architecture-change and sub-agent protocols.

This plan authorizes no implementation, build, test run, archive, or unrelated
repository change.

## Summary

Add explicit external tabular-data dependencies to NexusScript documents and
add a sibling source-driven rendering rule to NexusManifest.

The resulting pipeline is:

```text
compiled NexusScript model dependency closure
    -> declared external data sources
    -> source-type compiler
    -> one completed tabular context per source
    -> matching SourceTemplate
    -> one derived output per source
```

Ordinary `Model` and `Template` behavior remains unchanged. External files do
not become NexusScript modules, definitions, properties, references, or roots
in the generic NexusScript JSON artifact.

The initial tabular context shape is deliberately isolated behind the external
source compiler. The human owner has identified that a more natural keyed JSON
shape may exist but has deferred that redesign. The first implementation will
use the provisional positional contract in this plan so declaration,
dependency, dispatch, and output work can proceed without introducing a
Mustache object-enumeration extension.

## Verified Findings

### Current NexusScript

- `TNexusScriptSourceDocument` separately owns doctypes, modules, includes,
  and definitions. There is no external-source declaration collection.
- `TNexusScriptCompilationSession` recursively compiles doctypes, modules, and
  includes. Its public `ArtifactDocuments` contains the entry document and its
  include closure, but intentionally excludes module-only documents.
- Imported module definitions are cloned into compiler lookup state. External
  data must not use that symbol-import mechanism.
- `TNexusScriptJSONEmitter` consumes artifact compiled documents. External
  source declarations should not be added as emitted domain roots.
- `TNexusScriptCommand.RenderManifest` compiles every manifest `Model`, merges
  their artifact documents into one JSON context, and then runs every ordinary
  `Template` once with a fixed `Output`.
- `NexusManifest.Language.nxscript` currently permits only `Model` and
  `Template` children and requires at least one of each.
- Current Mustache integration supports arrays, dotted lookup, unescaped values,
  and dmustache's `-first`, `-last`, and `-index` pseudo-values. It does not
  expose generic JSON object property enumeration or indirect lookup by a
  runtime property name.
- The current schema parity model temporarily represents historical data files
  as ordinary nested `Data` definitions with `Name` and `Path`. Those are model
  data only and do not provide the required external-source behavior.
- The current parity manifests run `DatabaseImport.import.mustache` as one
  ordinary fixed-output template against the combined model. That cannot
  reproduce one import output per declared data file.

### Historical NexusSchema

- NexusSchema accepted top-level declarations equivalent to
  `data NAME PATH` and stored the declared name and filename separately from
  schema definitions.
- It normalized the data file extension and selected the corresponding command
  option/template by extension. The association was extension to template, not
  individual filename to template.
- The delimited processor treated `csv` and `jcsv` as comma-delimited and `tsv`
  and `tab` as tab-delimited.
- The first nonempty file row supplied headers. Subsequent nonblank rows supplied
  values. Quoted fields and doubled double quotes were parsed by the processor.
- Its JSON used `TABLE_NAME`, `Headers`, `Rows`, `Values`, and generated `Comma`
  members. It also doubled apostrophes before exposing `Value` to the SQL
  template.
- The historical data template received only the separately compiled external
  data context. It did not receive the schema model.
- Each declared data file was rendered independently. The output basename came
  from the data filename and its extension came from the selected template.
- `Comma` and SQL-oriented value preparation were manifestation conveniences,
  not general tabular source semantics. The new architecture will not add
  Schema/table knowledge to the NexusScript compiler, generic JSON emitter, or
  manifest engine.
- The historical lookup files referenced by the migrated inForce model use
  unavailable absolute `X:\...` paths and are not present in the checkout.
  Exact baseline comparison therefore depends on obtaining those inputs or a
  trusted historical output archive.

## Architecture Problem

The existing manifest abstraction has this cardinality:

```text
all declared Models -> one combined JSON context -> each Template once
```

External data requires different cardinality and ownership:

```text
each declared source -> its compiler -> its own context -> matching rule once
```

Overloading ordinary `Template` would make one construct mean both fixed-output
batch rendering and source-driven fan-out. Listing concrete source files in the
manifest would also move model dependency ownership to the wrong layer.

The missing architecture is therefore:

1. an explicit source declaration owned by a NexusScript document;
2. a session-level external dependency closure distinct from artifact JSON;
3. a source compiler registry;
4. a source-driven manifest rule with derived outputs; and
5. orchestration that compiles and renders each matched source independently.

## Target Contract

### NexusScript declaration

Add one explicit header declaration:

```nxscript
data STATE "DML/state.csv";
data COUNTY "DML/county.csv";
```

`data` is intentionally limited to externally stored tabular data in this
iteration. Do not generalize it into a resource/plugin framework.

- The identifier is the source's logical name and is case-insensitively unique
  within its declaring document.
- The path is required text syntax, resolved relative to the declaring
  NexusScript file and canonicalized by the compilation session.
- The declaration is legal only in the document header with doctype, module,
  and include declarations, before definitions.
- It does not enter normal scope, reference lookup, definition composition, or
  JSON emission.
- The source type is initially the normalized extension without the leading
  dot. No separate declared type syntax is added until a source without a
  reliable extension requires it.
- `csv`, `jcsv`, `tsv`, and `tab` are the initial supported types.

### Dependency closure

Add a session-owned external-source dependency collection separate from
`ArtifactDocuments`.

- Traverse the entry document, includes, and imported modules transitively.
- Do not traverse doctypes as model-owned data dependencies.
- A selected-root module import still contributes that source document's data
  declarations. The initial declaration belongs to the source document, not to
  an individual exported definition.
- Deduplicate an identical logical name plus canonical filename reached through
  multiple dependency paths.
- Fail when the same logical name resolves to different canonical files in one
  compiled model closure.
- Preserve declaration/dependency discovery order for deterministic rendering.
- A canonical file declared under different logical names remains distinct;
  normal output-collision checks may reject the resulting derived filenames.

This traversal does not change module symbol visibility or artifact-document
composition.

### Source compiler

Add a small external-source compilation unit with an explicit registry owned by
the NexusScript tool, not by the generic NexusScript language compiler.

Initial registrations:

```text
csv, jcsv -> comma-delimited compiler
tsv, tab  -> tab-delimited compiler
```

The delimited compiler owns:

- file loading;
- header parsing;
- quoted-field and doubled-quote handling;
- delimiter selection;
- blank-line handling;
- row-width validation; and
- construction of the completed Mustache context.

Use strict deterministic behavior for new inputs:

- an empty file fails;
- the first row is the header row;
- blank or duplicate header names fail;
- blank data lines are ignored;
- every data row must contain exactly the header count;
- malformed/unclosed quoted fields fail with filename and line information;
- values remain strings;
- source order is preserved.

Do not silently discard surplus values as NexusSchema did. Do not add SQL,
table, lookup, or Schema concepts to the parser.

### Provisional Mustache context

The initial source compiler emits one isolated context:

```json
{
  "DataSource": {
    "_nx": {
      "Kind": "DataSource",
      "Name": "STATE",
      "Type": "csv",
      "Source": "DML/state.csv"
    },
    "Fields": [
      "STATE_ID",
      "DESCRIPTION"
    ],
    "Records": [
      ["CA", "California"],
      ["OR", "Oregon"]
    ]
  }
}
```

- `_nx` contains compiler-owned source identity and declaration metadata.
- `Fields` preserves header order.
- `Records` contains positional values in the same order.
- The context contains no `Comma`, `TABLE_NAME`, cell wrapper objects, schema
  model, or manifest definition.
- The source name is information; a template may choose to interpret it as a
  database table name without making that interpretation part of compilation.
- The generic source compiler emits parsed values without adding a new
  Mustache helper system. Historical output comparisons determine whether any
  existing parity fixture needs narrowly isolated compatibility treatment.

This shape is provisional by explicit human-owner decision. Keep its creation
behind one source-compiler/context boundary and avoid exposing cell-model types
through the language compiler, session, manifest, or CLI APIs. A future keyed
record representation must therefore require changes only to this context
builder, its template, and focused tests.

### Manifest rule

Add `SourceTemplate` as a sibling of ordinary `Template`:

```nxscript
SourceTemplate CommaDelimitedImport {
    Types: [csv, jcsv];
    Compiler: CommaDelimited;
    Source: "../mustache/DatabaseImport.import.mustache";
    OutputDirectory: "data";
    OutputExtension: ".sql";
}

SourceTemplate TabDelimitedImport {
    Types: [tsv, tab];
    Compiler: TabDelimited;
    Source: "../mustache/DatabaseImport.import.mustache";
    OutputDirectory: "data";
    OutputExtension: ".sql";
}
```

Contract:

- `Types` is a required nonempty array of normalized source-type identifiers.
- `Compiler` is a required identifier resolved through the built-in external
  source compiler registry. It is not a Pascal class name or loadable plugin.
- `Source` is the required Mustache filename, resolved relative to the manifest.
- `OutputDirectory` is optional and defaults to the manifest output root. If
  supplied, it is a safe relative path beneath that root.
- `OutputExtension` is required, includes the leading dot, and contains no path
  separators.
- The output filename is the external source's basename with
  `OutputExtension`, beneath `OutputDirectory`.
- A type may match exactly one `SourceTemplate` in a manifest.
- Each discovered source must match exactly one rule. Unsupported source types,
  unknown compilers, missing rules, and multiple rules fail before rendering.
- Fixed `Output` is not available on `SourceTemplate`; its one-to-many semantics
  require derived filenames.

The manifest validator permits `Model`, ordinary `Template`, and
`SourceTemplate`. Existing manifests with only `Model` and `Template` remain
valid and behave unchanged. `SourceTemplate` is optional for models that declare
no external data.

### Rendering context and execution

Each `SourceTemplate` invocation receives only its compiled `DataSource`
context. It does not receive the combined NexusScript model or constants.

This matches historical NexusSchema behavior and prevents implicit context
merging and name-precedence rules. If a future data template demonstrates a
real need for main-model constants, that requires a separate explicit context
composition design and human review.

Manifest execution becomes:

1. Compile all ordinary `Model` entries exactly as today.
2. Produce the combined NexusScript JSON once for ordinary `Template` entries.
3. Collect external data dependencies from every model session in model order.
4. Deduplicate repeated dependencies and validate logical-name conflicts.
5. Resolve every dependency to exactly one `SourceTemplate` and compiler.
6. Derive every final output path.
7. Preflight missing files, missing/ambiguous rules, unsafe output paths, and
   collisions among source-driven outputs before writing any source-driven
   output.
8. In deterministic model/declaration order, compile each source, render the
   matching Mustache template with that source context, and write its derived
   output.

Do not change ordinary template ordering, fixed-output behavior, or its current
partial-output semantics. Collision preflight is scoped to the new
source-driven output set and collisions with known ordinary-template outputs.

## Scope

### Add

- One external-source compiler/registry unit under `NexusTools/Script/src/`.
- Focused source declaration, delimited input, manifest, Mustache, and expected
  output fixtures under `NexusTools/Script/tests/fixtures/`.
- Repository-local parity data fixtures sufficient to exercise CSV/JCSV and
  TSV/TAB without relying on unavailable `X:\...` paths.

### Modify

- `NexusTools/Script/src/obNexusScriptModel.pas`
  - add owned source-declaration and resolved-dependency model types.
- `NexusTools/Script/src/obNexusScriptCompiler.pas`
  - parse header-level `data NAME "path";` declarations and report focused
    syntax/duplicate-name diagnostics.
- `NexusTools/Script/src/obNexusScriptSession.pas`
  - resolve and expose the transitive external-source dependency closure without
    changing `ArtifactDocuments`.
- `NexusTools/Script/NexusScript.lpi` and the test project file
  - register the new source compiler unit where required.
- `NexusTools/Script/validator/NexusManifest.Language.nxscript`
  - add and validate `SourceTemplate`.
- `NexusTools/Script/cli/obNexusScriptCommand.pas`
  - enumerate source rules, preflight dependencies/outputs, invoke the registry,
    render each isolated context, and write each derived output.
- `NexusTools/Script/tests/tsNexusScriptTests.pas`
  - add the focused coverage below.
- `NexusTools/Script/parity/schema-generation/models/*.nxscript`
  - replace temporary ordinary `Data` definitions with explicit declarations
    when corresponding repository-local data files are available.
- `NexusTools/Script/parity/schema-generation/manifests/*.nxscript`
  - replace the fixed ordinary `DatabaseImport` entry with source-driven rules.
- `NexusTools/Script/parity/schema-generation/mustache/DatabaseImport.import.mustache`
  - consume only the provisional external-source context.
- `NexusTools/Script/README.md` and parity documentation
  - document declarations, propagation, dispatch, output derivation, context,
    limitations, and parity evidence.

Exact new unit and fixture filenames should follow the existing prefix and
folder conventions. Do not rename existing NexusScript concepts.

## Out Of Scope

- Inline tabular data in NexusScript definitions.
- Treating external data as a module, include, definition, reference, or generic
  JSON root.
- Schema/table/foreign-key/lookup semantics in generic compiler or manifest code.
- Generic JSON-object enumeration or indirect-property lookup in Mustache.
- A general resource, compiler-plugin, filter, helper, or transformation system.
- Main-model and external-source context merging.
- Binary/byte persistence of external file contents.
- Watching, caching, incremental rebuilds, parallel rendering, or task graphs.
- Changing existing ordinary `Template` behavior.
- Silently supporting arbitrary extensions.
- Recreating unavailable historical data or claiming baseline parity without
  the original inputs.
- Unrelated cleanup or refactoring.

## Staged Implementation Plan

### Stage 1: Declare external data sources

- Add the source declaration model and parser syntax.
- Enforce header placement, required identity/path, and document-local duplicate
  rules.
- Keep declarations outside definitions, lookup, composition, validation roots,
  and generic JSON output.
- Add parser/model tests before integrating manifestation.

### Stage 2: Build the dependency closure

- Add session traversal for entry, include, and module documents while excluding
  doctypes.
- Resolve paths relative to their declaring documents.
- Preserve deterministic order, deduplicate repeated traversal, and diagnose
  logical-name conflicts.
- Prove that module import selectors and duplicate import paths do not change
  source dependency results or existing artifact JSON.

### Stage 3: Compile delimited sources

- Add the registry and comma/tab compiler registrations.
- Implement deterministic parsing and the provisional context builder.
- Add focused unit tests for all four extensions, quoting, doubled quotes,
  blank lines, empty files, headers, and row widths.
- Confirm the compiler contains no NexusSchema model access or database-table
  assumptions.

### Stage 4: Add source-driven manifest rules

- Extend the validator with optional `SourceTemplate` children and the exact
  property contract above.
- Add private CLI/adaptor structures for compiled rule enumeration; do not add a
  general pipeline framework.
- Resolve compiled effective property values using existing NexusScript rules.
- Validate type/compiler mappings and derive safe outputs before rendering.

### Stage 5: Render and publish per source

- Collect source dependencies from all manifest model sessions.
- Preflight source files, rules, templates, output paths, and collisions.
- Compile each source and invoke the existing Mustache renderer with only its
  external context.
- Reuse the existing single-file writer for accepted destinations.
- Wrap failures with manifest rule identity and external source identity while
  preserving the underlying parser/render/write error.

### Stage 6: Migrate and compare parity artifacts

- Add repository-local representative lookup data fixtures.
- Replace temporary `Data` model definitions and the fixed import template entry
  with the new declaration and source-rule contracts.
- Adapt the copied import Mustache to `DataSource`, `Fields`, and `Records` using
  `-last` rather than emitted `Comma` values.
- Run NexusScript schema generation and source-data generation together.
- Compare source-driven SQL against NexusSchema for identical available inputs.
- If original inForce files or baselines remain unavailable, report fixture
  parity separately and list exact missing evidence; do not claim full historical
  data parity.

### Stage 7: Document and architecture-review

- Document the delivered syntax, import/include propagation, context, dispatch,
  and derived-output rules.
- Confirm existing manifests and ordinary templates remain unchanged.
- Search the change for magic `Data` property interpretation, CSV-as-module
  handling, Schema/table coupling, fixed per-source outputs, and duplicated
  context shapes.
- If implementation requires broader reference, module, JSON emitter, Mustache,
  or manifest semantics than this plan defines, stop for human review.

## Sub-Agent Delegation

This plan does not authorize or recommend sub-agent use. Implementation remains
local unless the human owner explicitly requests sub-agent use in the current
conversation. Plan approval and implementation approval do not authorize delegation.

## Verification Plan

### Declaration and dependency behavior

- A valid `data NAME "path";` declaration parses before definitions.
- Missing identity/path, malformed syntax, declaration after definitions, and
  duplicate local names fail with source ranges.
- Paths resolve relative to the declaring document rather than process cwd or
  manifest location.
- Entry, include, direct module, transitive module, selected-root module, and
  duplicate-import fixtures produce the specified dependency closure.
- Doctype documents do not contribute sources.
- Same-name/different-file conflicts fail; repeated identical dependencies
  deduplicate deterministically.
- Generic emitted model JSON is byte-identical with and without a declaration
  when definitions are otherwise identical.

### Delimited compilation

- CSV and JCSV use comma delimiters; TSV and TAB use tab delimiters.
- Header and record order are preserved.
- Quoted delimiters and doubled quotes parse correctly.
- Empty input, blank/duplicate headers, malformed quotes, short rows, and long
  rows fail clearly with source identity and line information.
- Blank data lines are ignored.
- The emitted context matches the provisional JSON contract exactly.

### Manifest dispatch and outputs

- Existing manifests without `SourceTemplate` retain their current behavior.
- Each declared source matches by normalized type and renders exactly once.
- Multiple files of one type use the same rule and produce separate outputs.
- CSV/JCSV and TSV/TAB compiler mappings select the correct delimiter behavior.
- Missing, duplicate, and unknown type/compiler mappings fail before writes.
- Template and output directories resolve relative to their specified owners.
- Output basename and configured extension are derived correctly.
- Absolute/traversing output directories and invalid extensions fail.
- Same-basename sources that derive the same destination fail collision
  preflight.
- A source-driven output colliding with a known ordinary template destination
  fails before source-driven writes.
- A data template can see its own source context and cannot accidentally see
  the combined main model.

### Compatibility and integration

- All existing compiler, module/include, JSON, validator, CLI, template, and
  manifest tests pass unchanged.
- Existing `/template` and ordinary manifest outputs remain byte-identical.
- The full registered NexusScript test suite passes.
- NexusScript and its test module clean-build.
- End-to-end fixtures generate one schema output plus one data output per
  declared source.
- Available identical inputs produce SQL equivalent to NexusSchema after
  normalizing only documented path/line-ending differences.

## Risks And Deferred Questions

- The provisional positional `Fields`/`Records` context may not be the final
  desired native JSON representation. This is explicitly deferred, not treated
  as settled architecture.
- Mustache cannot generically enumerate property names in keyed record objects
  with the current renderer. Do not extend Mustache during this implementation.
- Source declarations currently belong to a document, so selected-root module
  imports bring all data declarations from that document. A future need for
  per-export ownership requires new language semantics and review.
- Exact historical inForce data parity remains evidence-blocked until the
  original external files or trusted baselines are supplied.
- If historical value escaping causes an observable parity difference, stop and
  present the source value, historical compiled context, current context, and
  failing Mustache output before adding target-specific behavior.

## Approval Gate

No implementation begins until the human owner explicitly authorizes this plan.
If implementation proves the provisional context cannot satisfy the existing
data-import Mustache without broader engine mechanics, stop and request human
review rather than adding those mechanics.
