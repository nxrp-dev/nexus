# Work Plan: NexusTask Declarative Build System

## Inputs

- Source request: clean psMake-inspired declarative build-system reimplementation.
- Revision request: `C:\Users\kcollins\Downloads\nexustask-work-plan-revision-request.md`.
- Human clarification:
  - Project name: `NexusTask`.
  - Make concrete semantic decisions now; they can be revised later if needed.
- Existing constraints:
  - This is a work plan only.
  - No implementation begins until Kevin explicitly authorizes it.
  - This is a clean reimplementation, not psMake XML compatibility.
  - Implementation should be Object Pascal / Free Pascal.
  - The project must fit Nexus' low-dependency, typed, simple architecture direction.
  - `NexusBuild` remains the Pascal compiler/project interoperability layer. `NexusTask` is repository/build/deployment orchestration.

## Summary

Create `NexusTask`, a Nexus-native trusted declarative task runner. The initial implementation establishes a small `.nxtask` language, a proper lexer/parser, parsed and materialized task models, external file loading, reference expansion, structural validation, target-aware inspection, executor-owned traversal, a small task-action registry, canonical text fixture output, and a standalone command-line development/test harness.

NexusTask manifests are trusted executable build/deployment descriptions. They are not untrusted configuration files and are not intended to be sandboxed into harmlessness. The initial system should still remain deterministic, source-aware, testable, and conservative in language features.

The first implementation proves:

- parse `.nxtask` scripts into a typed unresolved model
- load referenced external `.nxtask` files
- resolve node expansions using declaration context
- resolve scalar references with type preservation
- validate duplicate/conflict rules structurally
- materialize a declaration tree with no unresolved references
- inspect target applicability without side effects
- execute applicable nodes through a registry while the executor owns traversal
- emit canonical text dumps for parser, materializer, target inspection, diagnostics, and execution trace

## Verified Findings

- Existing `psMake` is a useful source of concepts: hierarchical tasks, targets, value replacement, node expansion, external references, and action dispatch.
- Existing `psMake` is not the implementation foundation:
  - it is PowerShell/XML based
  - it contains old SVN, Delphi, IIS, and C# helper assumptions
  - it has hardcoded local paths
  - it mixes parsing, expansion, validation, and execution
- `NexusBuild` currently handles Pascal project/build planning around `TNXPascalProject`, FPC, and Lazarus. It should not become a general orchestration language.
- `NexusTest` can inform test style, but NexusTask also needs a standalone command-line development harness that makes every major stage observable.

## Architecture Problem

Nexus needs a trusted declarative orchestration layer without inheriting psMake's legacy implementation shape.

The essential architecture problem is keeping these concerns separate:

- lexing/parsing source text
- validating parsed structure
- loading external files
- resolving scalar and node references
- materializing a concrete declaration tree
- evaluating target applicability
- walking the tree
- invoking actions

If action execution controls traversal, or if unresolved references survive into execution, the runner becomes harder to reason about and test. The initial design must keep declaration processing complete before execution and keep traversal owned by the executor.

## Target Contract

### NexusTask Language

- Owner: `NexusTask`.
- Responsibilities:
  - express trusted declarative task trees
  - express scalar configuration values
  - express local and external scalar references
  - express local and external node expansion
  - express target applicability
  - preserve source ranges for diagnostics and provenance
- State flow:
  - source text parses into unresolved syntax
  - parsed syntax is structurally validated
  - parsed syntax materializes into a concrete task tree
  - inspection and execution read the materialized tree without mutating it
- Persistence behavior:
  - source scripts are plain text `.nxtask` files
  - canonical dumps are test/development fixtures, not a second persistence format

### NexusTask Runtime

- Owner: task loading, resolution, validation, target, and executor units.
- Responsibilities:
  - canonicalize and cache parsed documents
  - resolve external references relative to the file containing the reference
  - resolve references using declaration-document context
  - detect semantic scalar and node-expansion cycles
  - validate duplicate names and expansion conflicts
  - evaluate target applicability without deleting nodes
  - walk applicable nodes in materialized declaration order
  - invoke the current node's action
  - store runtime results, diagnostics, trace events, and side effects outside the declaration tree
- State flow:
  - resolver finishes tree construction before exposing the materialized tree
  - ordinary Pascal classes/collections are acceptable
  - the behavioral contract is non-mutation during inspection and execution, not specialized immutable machinery

### Trust Boundary

NexusTask manifests are trusted operator/deployment artifacts. A manifest is closer to an executable build script than inert data.

The initial implementation should not include credential features, redaction interfaces, deployment secret metadata, or credential-backed actions. Those belong later when a real credential-bearing production action requires them. The initial logger should avoid indiscriminately dumping every property value.

## Scope

The initial project includes:

- lexer
- parser
- parsed document model
- scalar value model
- reference syntax model
- source range and provenance model
- parsed-tree structural validator
- materialized task/property model
- external file loader/cache
- scalar reference resolver
- node expansion resolver
- semantic cycle detector
- post-expansion validator
- target applicability evaluator
- task-action registry
- executor-owned tree walker
- structured execution results and trace
- canonical text dump writers
- deterministic sample actions
- standalone command-line development harness
- automated tests
- sample root/external scripts
- expected fixture outputs where useful

## Out Of Scope

- old psMake XML compatibility
- PowerShell compatibility
- general-purpose programming features
- loops, functions, arbitrary expressions, or embedded scripts
- list-valued properties
- action-owned child traversal/control flow
- parallel execution
- incremental build caching
- remote execution
- credential handling or redaction policy
- plugin package management
- NexusLS integration
- Lazarus project interpretation
- Pascal directive injection
- VSIX packaging
- production deployment task library
- replacing `NexusBuild`

## Proposed Project Structure

```text
NexusTask/
  AGENTS.md
  NexusTaskTest.lpi
  NexusTaskTest.lpr
  src/
    tpNXTask.pas
    obNXTaskSource.pas
    obNXTaskDiagnostics.pas
    obNXTaskLexer.pas
    obNXTaskParser.pas
    obNXTaskSyntax.pas
    obNXTaskValues.pas
    obNXTaskValidation.pas
    obNXTaskMaterialized.pas
    obNXTaskLoader.pas
    obNXTaskResolver.pas
    obNXTaskCycles.pas
    obNXTaskTargets.pas
    obNXTaskActions.pas
    obNXTaskExecutor.pas
    obNXTaskTrace.pas
    obNXTaskDump.pas
    obNXTaskCLI.pas
  tests/
    tsNXTaskLexerTests.pas
    tsNXTaskParserTests.pas
    tsNXTaskValidationTests.pas
    tsNXTaskResolverTests.pas
    tsNXTaskMaterializationTests.pas
    tsNXTaskTargetTests.pas
    tsNXTaskExecutionTests.pas
    tsNXTaskEndToEndTests.pas
  samples/
    root.nxtask
    shared.nxtask
    empty.nxtask
    multiple-roots.nxtask
    cycles/
    errors/
    expected/
```

The first executable is `NexusTaskTest`, a development/test harness. A production CLI can be split out later.

## Language Decisions

### File Extension

Use `.nxtask`.

### Comments

Support line comments:

```text
// comment
```

Block comments are not required initially.

### Identifiers

Identifiers start with a letter or underscore and may contain letters, digits, underscores, and hyphens.

```text
Identifier = [A-Za-z_][A-Za-z0-9_-]*
```

Task names, action names, property names, and target names are case-sensitive.

### Root Structure

A NexusTask document contains zero or more root task nodes.

Rules:

- root task names must be unique within the document
- root nodes retain declaration order
- references resolve from the referenced document's root scope
- reusable external files may expose multiple independent root nodes
- execution walks every applicable root node in declaration order
- typical executable build files may choose one orchestration root, but the grammar does not require exactly one

### Task Declaration

```text
TaskName TaskAction (Debug, Release) {
  PropertyName: Value
  ChildName ChildAction {
  }
}
```

The target list is optional:

```text
TaskName TaskAction {
}
```

### Scalar Values

Supported scalar types:

- string
- integer
- floating-point
- boolean

Boolean literals are lowercase only:

```text
true
false
```

Integers use Pascal `Int64`.

Floating-point values use Pascal `Double`.

Accepted numeric literal syntax:

```text
42
-7
3.14
-0.5
```

Initial numeric literals do not include exponent notation, hex notation, digit separators, `NaN`, or infinity.

Number parsing rules:

- a literal without a decimal point is an integer
- a literal with a decimal point is a floating-point value
- integer overflow produces a diagnostic
- invalid floating-point syntax or out-of-range values produce diagnostics
- tests use canonical output to avoid locale-dependent formatting

Canonical numeric dump format:

- integer: base-10 `Int64` text with no separators
- floating-point: invariant decimal formatting sufficient for stable fixture comparison

Do not silently convert every number to floating point.

### Strings

Unquoted strings are allowed only when they do not contain whitespace or delimiter characters.

Strings containing spaces, braces, parentheses, colons, brackets, angle brackets, commas, backslashes that need preserving, or comment markers must be quoted.

```text
OutputRoot: artifacts/bin
Message: "Packaging release output"
WindowsPath: "C:\build\output"
```

Quoted strings support minimal escapes:

- `\"`
- `\\`
- `\n`
- `\t`

### Reference Syntax

Local scalar reference:

```text
[Configuration.OutputRoot]
```

External scalar reference:

```text
["shared.nxtask":Configuration.OutputRoot]
["build/shared.nxtask":Configuration.OutputRoot]
["..\shared\common.nxtask":Configuration.OutputRoot]
["C:\build\shared.nxtask":Configuration.OutputRoot]
```

Local node expansion:

```text
<Pascal.CommonOptions>
```

External node expansion:

```text
<"shared.nxtask":Pascal.CommonOptions>
<"build/shared.nxtask":Pascal.CommonOptions>
<"..\shared\common.nxtask":Pascal.CommonOptions>
<"C:\build\shared.nxtask":Pascal.CommonOptions>
```

External filenames in references must be quoted strings. This keeps the colon delimiter readable while supporting Windows drive-letter paths.

## Parsed Syntax Model

Parsing produces an unresolved syntax tree. It records declarations in source order and does not enforce structural uniqueness policy.

Recommended classes:

- `TNXTaskParsedDocument`
  - canonical file name
  - root task list
  - diagnostics
- `TNXTaskParsedNode`
  - name token
  - action token
  - declared targets
  - properties in source order
  - children in source order
  - node expansion references in source order
  - source range
  - declaration document identity
- `TNXTaskParsedProperty`
  - name token
  - parsed scalar literal or scalar reference
  - source range
  - declaration document identity
- `TNXTaskParsedValue`
  - scalar kind
  - string value
  - `Int64` value
  - `Double` value
  - boolean value
  - scalar reference where applicable
  - source range
- `TNXTaskNodeReference`
  - optional external filename literal
  - node path
  - source range
  - declaration document identity
- `TNXTaskValueReference`
  - optional external filename literal
  - node path
  - property name
  - source range
  - declaration document identity
- `TNXTaskSourceRange`
  - file name
  - line
  - column
  - length

Duplicate sibling task names and duplicate properties are structural validation failures, not parser grammar failures.

## Lexer And Parser Approach

Use a hand-written lexer and recursive descent parser in Pascal.

The lexer emits:

- identifiers
- string literals
- integer literals
- floating-point literals
- boolean literals
- `{`
- `}`
- `(`
- `)`
- `[`
- `]`
- `<`
- `>`
- `:`
- `.`
- `,`
- end of file

The parser reports source-aware diagnostics for syntax failures:

- missing task name
- missing task action
- missing opening or closing brace
- invalid target list syntax
- missing property separator
- invalid scalar literal
- invalid reference syntax
- unexpected token

Parser recovery should report more than one error when practical, but correctness is more important than aggressive recovery.

## Structural Validation

Introduce a parsed-tree structural validator separate from the parser.

Validation responsibilities:

- duplicate root task names
- duplicate sibling child task names
- duplicate properties on a node
- diagnostics that identify both original and duplicate declarations

Pass 1 may run structural validation immediately after parsing, but the parser itself does not own duplicate-name policy.

Equivalent validation runs after expansion to catch conflicts introduced by node expansion.

## Materialized Task Model

The materialized model contains concrete declarations and no unresolved references.

Recommended classes:

- `TNXTaskDocument`
  - root materialized nodes
  - source file table
  - diagnostics
- `TNXTaskNode`
  - name
  - action
  - declared targets
  - properties
  - children
  - provenance
- `TNXTaskProperty`
  - name
  - scalar value
  - provenance
- `TNXTaskValue`
  - kind: string, integer, floating-point, boolean
  - string value
  - `Int64` value
  - `Double` value
  - boolean value
- `TNXTaskProvenance`
  - declaration source range
  - current insertion source range
  - expansion stack
  - declaration document identity

The resolver finishes construction before exposing the materialized tree. Inspection and execution must not mutate it. Runtime results, diagnostics, logs, and side effects live outside the declaration tree.

## Build-File Loading Model

External file references resolve relative to the file containing the reference.

Rules:

- canonicalize filenames before caching
- cache parsed documents by canonical filename
- repeated references to the same file reuse the cached parsed document
- the loader prevents recursive reparsing
- load failures are diagnostics
- filenames may appear repeatedly in a reference graph without being cycles by themselves

Cycles are semantic reference-resolution problems, not ordinary document-loading problems.

## Reference Resolution

### Lookup

Use deterministic hierarchical lookup from the referenced document's root scope. Broad descendant search is not allowed.

Example:

```text
[NexusBuild.Configuration.OutputRoot]
```

means:

```text
root NexusBuild -> child Configuration -> property OutputRoot
```

Forward references are allowed because resolution operates over parsed document graphs, not textual execution order.

Missing references are errors and do not produce empty strings or defaults.

### Declaration Context

References retain the declaration-document context in which they were originally written.

When a node from `shared.nxtask` is expanded into another document, local references inside the expanded content still resolve against `shared.nxtask`.

This prevents the consuming document from accidentally changing imported behavior by declaring similarly named nodes.

Required behavior:

- structurally expanded properties and child nodes are inserted into the destination
- every unresolved reference retains its originating document identity
- local references are local to the document in which the reference was declared
- external references remain explicitly external
- materialization uses provenance/declaration context to resolve nested references
- diagnostics identify both declaration context and expansion site where relevant

### Scalar References

A scalar reference must resolve to a property, not a node.

The resolved value preserves type:

- string remains string
- integer remains integer
- floating-point remains floating-point
- boolean remains boolean

Assertions comparing numeric values must respect numeric kind unless the action explicitly defines mixed integer/float comparison.

## Node Expansion

Node expansion inserts the referenced node's properties and child nodes into the node that contains the expansion reference. The referenced node wrapper itself is not inserted.

Example:

```text
BuildServer TestCompile {
  <"shared.nxtask":Pascal.CommonOptions>
}
```

If `Pascal.CommonOptions` contains `Mode` and `Output` properties, those properties become properties of `BuildServer`.

Rules:

- expansion happens before scalar reference resolution
- nested expansions are resolved recursively
- expansion is not inheritance
- no override behavior exists initially
- duplicate properties after expansion are errors
- duplicate child names after expansion are errors
- local declarations and expanded declarations have equal conflict priority
- source provenance records both the originating declaration and expansion site
- unresolved references inside expanded content retain original declaration context

## Cycle Detection

Detect cycles by qualified reference identity, not merely by filenames in a load stack.

Reference identity includes:

- reference kind: scalar value or node expansion
- canonical document filename
- qualified node path
- property name for scalar references

Conceptual examples:

```text
value:C:\build\shared.nxtask:Configuration.OutputRoot
node:C:\build\common.nxtask:Pascal.CommonOptions
```

The resolver maintains active stacks for scalar resolution and node expansion. Cycles may cross file boundaries. Diagnostics show the full file-qualified reference chain.

A document may reference another document that also references the first document without error when the actual semantic reference graph terminates.

## Target Applicability

Omitted target list means "all targets allowed by the parent."

Target filtering is evaluated during inspect and execute. It must not delete or mutate materialized nodes.

Rules:

- root task with no target list applies to every selected target
- child with no target list inherits parent applicability
- child with target list applies only when parent applies and child declares the selected target
- parent exclusion prevents descendant execution
- target comparisons are case-sensitive
- execution walks every applicable root node in declaration order

Inspect mode must show skipped nodes with reasons:

- applies by explicit target
- applies by inherited target
- skipped by own target list
- skipped because parent skipped

## Execution Behavior

The execution walker owns traversal.

Initial execution order:

```text
enter node
invoke node action
walk applicable child nodes in materialized declaration order
leave node
```

An action operates on the current node only.

An action must not:

- suppress child traversal
- repeat child traversal
- reorder children
- conditionally invoke children
- directly execute child nodes
- become an alternate control-flow engine

`Group` is a no-op or trace-only action. Its children are still walked by the executor.

If later requirements need actions that wrap, suppress, repeat, or conditionally execute descendants, that must be designed explicitly as a separate execution-node category or execution contract.

Execution produces structured results and trace events outside the declaration tree.

## Task-Action Registration

Do not hard-code task actions into the parser.

Introduce:

- `TNXTaskAction`
  - executes one current node
  - receives read-only/conventionally non-mutating node access
  - does not receive traversal control
- `TNXTaskActionRegistry`
  - maps case-sensitive action names to factories
- `TNXTaskActionContext`
  - working directory
  - diagnostics sink
  - trace sink
  - file-system boundary helpers where needed by actions
- `TNXTaskActionResult`
  - success/failure
  - message
  - diagnostics

Initial action set:

- `Group`
  - no-op or trace-only
- `Trace`
  - records a deterministic message in the execution trace
- `Assert`
  - validates a narrow deterministic scalar or execution condition for tests
- `WriteTextFile`
  - writes text to a file
  - proves working-directory behavior
  - proves path resolution at the action boundary
  - proves property schema validation
  - proves failure diagnostics
  - may create parent directories only if explicitly documented as part of its contract

Do not include `Exec`, `CopyFile`, or independently required `CreateDirectory` in the initial action set.

## Diagnostics And Source Provenance

Every diagnostic includes:

- severity
- code
- message
- primary source range
- optional related ranges

Related ranges are required for:

- duplicate declarations
- scalar reference cycles
- node expansion cycles
- external reference chains
- expansion site plus originating declaration

Diagnostics should identify declaration context and expansion site when expanded content fails to resolve or validate.

## Canonical Text Dumps

The test harness must produce deterministic text representations for:

- parsed syntax
- materialized tree
- target inspection
- execution trace
- diagnostics where fixture comparison is useful

The canonical text format is a development/testing representation only. It is not a second persistence format and not a public interchange contract.

It must provide:

- stable declaration order
- normalized line endings
- explicit scalar type display
- explicit task name and action
- declared targets
- resolved values
- reference information in parse mode
- provenance where relevant
- target applicability and skip reasons
- execution order

Do not introduce JSON serialization merely for fixtures unless existing Nexus facilities make it clearly simpler without manual JSON construction.

## Standalone Test Application

Create `NexusTaskTest` as an independently buildable command-line development harness.

Required modes:

```text
NexusTaskTest parse samples/root.nxtask
NexusTaskTest expand samples/root.nxtask
NexusTaskTest inspect samples/root.nxtask -target Release
NexusTaskTest execute samples/root.nxtask -target Release
NexusTaskTest test
```

### Parse Mode

Displays canonical parsed syntax:

- root and child task hierarchy
- task names and actions
- declared targets
- scalar properties and concrete parsed types
- unresolved references
- source locations
- parser and structural diagnostics

### Expand Mode

Displays canonical materialized tree:

- concrete task hierarchy
- resolved scalar values and types
- expanded content
- declaration context
- provenance
- diagnostics

### Inspect Mode

Displays canonical target view:

- materialized tree
- applicability for each node
- skip reasons
- no external side effects

### Execute Mode

Walks applicable nodes and invokes actions:

- execution order
- action name
- selected target
- property values needed by the action trace
- failure behavior
- source-aware diagnostics

## Sample Scripts

Include samples covering:

- empty document
- one root node
- multiple root nodes
- duplicate root names
- nested task groups
- all-target tasks
- Debug-only tasks
- Release-only tasks
- parent target exclusion overriding child target inclusion
- local string, integer, floating-point, and boolean replacement
- external string, integer, floating-point, and boolean replacement
- local node expansion
- external node expansion
- Windows absolute external path syntax
- relative external path syntax
- expansion inside expanded nodes
- references inside expanded nodes resolving against declaration context
- forward references
- missing references
- circular scalar references
- circular node expansions
- cross-file semantic cycles
- cross-file non-cycles
- duplicate sibling names
- duplicate properties
- duplicate conflicts introduced by expansion
- unknown task actions
- action execution failure
- successful tree execution
- execution order across multiple root nodes

Representative real-ish sample:

```text
NexusBuild Group (Debug, Release) {
  Configuration Values {
    OutputRoot: artifacts
    Optimize: false
    RetryCount: 3
    WarningThreshold: 0.75
  }

  Prepare Group {
    CreateTrace Trace {
      Message: "Preparing output"
    }
  }

  BuildServer Group (Debug, Release) {
    Output: [NexusBuild.Configuration.OutputRoot]
    <"shared.nxtask":Pascal.CommonOptions>
  }

  Package Group (Release) {
    EmitPackage Trace {
      Message: "Packaging release output"
    }
  }
}
```

Declaration-context sample:

```text
// shared.nxtask
Pascal Group {
  Paths Values {
    DefaultOutput: artifacts
  }

  CommonOptions Values {
    Output: [Pascal.Paths.DefaultOutput]
  }
}
```

```text
// root.nxtask
Build Group {
  Pascal Group {
    Paths Values {
      DefaultOutput: wrong-local-value
    }
  }

  Compile Group {
    <"shared.nxtask":Pascal.CommonOptions>
  }
}
```

`Output` from the expanded `CommonOptions` resolves to `shared.nxtask`'s `Pascal.Paths.DefaultOutput`, not the consuming document's similarly named node.

## Automated Testing

### Lexer Tests

Cover:

- identifiers
- comments
- braces and delimiters
- quoted strings and escapes
- unquoted strings
- integer literals
- floating-point literals
- lowercase boolean literals
- reference delimiters
- external quoted filenames including Windows absolute paths

### Parser Tests

Cover:

- valid task syntax
- empty document
- one root
- multiple roots
- nested tasks
- targets
- properties
- scalar references
- node references
- invalid target syntax
- missing braces
- missing property separator
- invalid references
- source ranges

### Structural Validation Tests

Cover:

- duplicate root task names
- duplicate sibling task names
- duplicate properties
- diagnostics linking duplicate and original declarations

### Resolver And Materialization Tests

Cover:

- local scalar references
- external scalar references
- type preservation
- local node expansion
- external node expansion
- nested expansion
- declaration context inside expanded nodes
- expansion conflict errors
- missing references
- scalar cycles
- node cycles
- cross-file non-cycles
- materialized tree contains no unresolved references

### Numeric Tests

Cover:

- `Int64` integer parsing
- integer overflow diagnostics
- `Double` parsing
- invalid floating-point diagnostics
- canonical numeric dump output
- scalar reference type preservation
- assertion behavior for integer, floating-point, and mixed numeric comparisons

### Target Tests

Cover:

- explicit target matching
- omitted target inheritance
- parent constraints
- skipped descendants
- multiple root execution order
- case-sensitive target behavior

### Execution Tests

Use deterministic test actions to verify:

- executor-owned traversal
- pre-order execution
- actions cannot control child traversal
- `Group` children are walked normally
- `Trace` output
- narrow `Assert` behavior
- `WriteTextFile` side effects
- action failure propagation
- unknown action diagnostics

Execution tests must not depend on compilers, npm, VS Code, network access, or external tools.

### End-To-End Tests

Load complete samples, materialize them, inspect Debug/Release targets, execute deterministic actions, and compare canonical text fixtures.

## Staged Implementation Plan

### Pass 1: Language, Parser, And Structural Validation

Implement:

- `NexusTask/AGENTS.md`
- `NexusTaskTest` project shell
- source range model
- diagnostic model
- lexer
- parser
- parsed syntax model
- scalar value parsing with integer/float distinction
- structural validator for duplicate roots, sibling names, and properties
- canonical parse/diagnostic dumps
- parse-mode CLI
- lexer/parser/validation tests

Acceptance criteria:

- `NexusTaskTest parse samples/root.nxtask` prints canonical parsed syntax.
- Empty, one-root, and multi-root documents parse.
- Duplicate names/properties are structural diagnostics, not parser policy.
- Numeric kinds are preserved in parse output.
- Windows external filenames parse through quoted external-reference syntax.

### Pass 2: Loading, Expansion, And Materialization

Implement:

- external file loader/cache
- canonical filename resolution
- file-relative external references
- node expansion
- scalar resolution
- declaration-context preservation
- qualified reference identity
- scalar cycle detection
- node-expansion cycle detection
- post-expansion structural validation
- materialized model
- canonical materialized-tree dump
- expand-mode CLI
- resolver/materialization tests

Acceptance criteria:

- `NexusTaskTest expand samples/root.nxtask` prints a materialized tree with no unresolved references.
- Expanded content retains original declaration context for internal references.
- Cross-file cycles are detected semantically.
- Cross-file non-cycles are allowed.
- Duplicate conflicts introduced by expansion are errors.
- Scalar references preserve string, integer, floating-point, and boolean kinds.

### Pass 3: Target-Aware Inspect And Executor-Owned Traversal

Implement:

- target applicability evaluator
- inspect-mode CLI
- action base contract
- action registry
- execution context
- execution walker
- structured execution trace
- `Group`, `Trace`, `Assert`, and `WriteTextFile`
- execute-mode CLI
- canonical inspect/execute dumps
- target and execution tests

Acceptance criteria:

- `NexusTaskTest inspect samples/root.nxtask -target Debug` shows applicability and skip reasons.
- Parent target exclusion prevents descendant execution.
- Omitted target lists inherit parent applicability.
- Execution walks applicable roots in declaration order.
- Execution order is `enter`, action, applicable children, `leave`.
- Actions operate only on the current node and do not control traversal.
- `Group` children are walked by the executor.
- `WriteTextFile` proves deterministic side effects and action-boundary path handling.

### Pass 4: Fixture Hardening And Developer Ergonomics

Implement:

- fixture comparison helpers
- complete expected outputs for representative samples
- improved related-location diagnostic dumps
- README usage examples
- final sample cleanup

Acceptance criteria:

- Parse, expand, inspect, execute, and diagnostic dumps are canonical and fixture-friendly.
- Line endings are normalized for tests.
- Sample coverage demonstrates the language and runtime contract without production deployment actions.
- The project is ready to serve as the proving ground for later production task libraries.

## Verification Plan

Required verification for this initial project:

```text
lazbuild NexusTask\NexusTaskTest.lpi
NexusTask\NexusTaskTest.exe test
```

Manual CLI checks:

```text
NexusTask\NexusTaskTest.exe parse NexusTask\samples\root.nxtask
NexusTask\NexusTaskTest.exe expand NexusTask\samples\root.nxtask
NexusTask\NexusTaskTest.exe inspect NexusTask\samples\root.nxtask -target Debug
NexusTask\NexusTaskTest.exe inspect NexusTask\samples\root.nxtask -target Release
NexusTask\NexusTaskTest.exe execute NexusTask\samples\root.nxtask -target Release
```

Regression compilation of other Nexus projects is required only if NexusTask modifies or depends on shared units used by those projects. The implementation pass must identify those dependencies before adding broader regression builds.

## Risks And Questions

### Risks

- The language could drift toward a general-purpose programming language if loops, expressions, functions, or dynamic action behavior are added too early.
- Node expansion could become inheritance if override rules are introduced prematurely.
- Declaration-context preservation adds resolver complexity, but it prevents imported content from changing meaning based on the consuming file.
- `WriteTextFile` is intentionally small, but even this first side-effecting action needs precise working-directory and path diagnostics.
- Canonical fixture output can become a maintenance burden if it tries to be a public serialization format instead of a development dump.

### Decisions Made For Initial Implementation

- Project name is `NexusTask`.
- File extension is `.nxtask`.
- Manifests are trusted executable descriptions.
- Documents may contain zero or more root nodes.
- Root names are unique within a document.
- Execution walks applicable root nodes in declaration order.
- External filenames in reference syntax are quoted strings.
- External paths resolve relative to the file containing the reference.
- Identifiers and targets are case-sensitive.
- Forward references are allowed.
- Scalar values are string, integer, floating-point, or boolean.
- Integers are `Int64`.
- Floating-point values are `Double`.
- Parser records declarations; structural validator detects duplicates.
- Node expansion inserts referenced node contents, not the wrapper node.
- Expansion happens before scalar resolution.
- References inside expanded nodes retain declaration-document context.
- Duplicate conflicts are errors.
- Cycle detection uses qualified semantic reference identity.
- Inspection and execution must not mutate the materialized declaration tree.
- Target filtering does not delete nodes from the materialized tree.
- Executor owns traversal.
- Actions operate only on the current node.
- Initial execution order is pre-order: enter, action, children, leave.
- Initial action set is `Group`, `Trace`, `Assert`, and `WriteTextFile`.
- Initial fixture output is canonical text, not JSON and not persistence.

### Genuine Architectural Questions

- Should the later production-facing CLI be named `nxtask`, `nexustask`, or something else?
- Should future action names remain plain identifiers or eventually allow namespaces such as `File.WriteText` and `Process.Exec`?
- Should `WriteTextFile` create parent directories automatically as part of its contract, or should it fail when the parent directory is missing until a later directory action exists?
- Should mixed integer/floating-point comparisons in `Assert` be allowed initially, or should assertions require exact scalar kind unless an explicit comparison mode is supplied?

## Final Acceptance

The initial project is complete when a developer can:

1. Build `NexusTaskTest`.
2. Parse included `.nxtask` files.
3. Inspect parsed hierarchy, references, scalar kinds, and source locations.
4. Validate duplicate roots, duplicate sibling tasks, and duplicate properties structurally.
5. Load referenced external scripts.
6. Materialize all node and scalar replacements.
7. Preserve declaration context for references inside expanded nodes.
8. Receive clear errors for unresolved or circular references.
9. Detect semantic cycles across files using qualified reference identity.
10. Select Debug or Release from the command line.
11. Inspect which materialized nodes apply to that target.
12. Walk applicable roots and children in deterministic executor-owned order.
13. Invoke `Group`, `Trace`, `Assert`, and `WriteTextFile` actions.
14. Verify canonical parse, expand, inspect, execute, and diagnostic outputs through automated tests.
15. Use NexusTask as the development proving ground for later production build/deployment actions.

## Approval Gate

No implementation begins until Kevin explicitly authorizes it.
