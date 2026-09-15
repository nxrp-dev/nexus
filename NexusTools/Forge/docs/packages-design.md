# NexusForge packages

Status: First implementation available for review; see [usage](packages.md).
Date: 2026-09-15
Revision: Module-composed operation configurations, direct Template rendering, and shared environment data.

Implementation uses existing NexusScript loading and target rules unchanged.
The earlier incomplete target example is discussed in
[the target-resolution note](package-target-resolution.md).

## Purpose

A package describes a usable build result and how to produce it when it is
missing. It may represent a compiler, a library, a section of code, or an
application. Consumers request the package and use its named outputs rather than
reconstructing its build layout.

Forge compiles and validates completed operation documents, renders each
operation's Template with Mustache, and executes native tools sequentially.
Packages add the decision to reuse an existing result or execute its build.

Package is a construct within a Forge document. Its identity, requirements,
outputs, and build operations belong together. A separate `Build.nxscript` path
is not a required part of the package contract.

## Settled first-pass decisions

These are owner decisions, not open questions for this review:

1. **Artifact presence determines readiness.** If all declared target artifacts
   for the requested package variant are present, the package is built. If any
   are absent, it needs building. No hashing, timestamps, source-change detection,
   build receipts, or freshness tracking in this pass.
2. **The package definition resides in the package root directory.** Its containing
   directory establishes the package root. No independently configured root and
   no detached package definition pointing at another root.
3. **Named outputs are part of the package contract.** A consumer refers to a
   package output by name and receives its resolved path.
4. **The first pass is local and explicit.** No remote downloads, registry,
   version-range solver, compiler installation management, or environment repair.
5. **Keep Forge generic.** Compiler- and tool-specific behavior stays in definitions
   and templates. Packages must not introduce special FPC executors.
6. **The package contains its build operations.** File separation is optional
   organization, not a mandatory recipe-file indirection.
7. **Dependencies reference package definitions.** Normal `@` references identify
   packages; they do not launch builds or turn into runtime filesystem paths.
8. **Use folder hierarchies for target variants.** Keep public output names stable
   and distinguish variant artifacts by their declared locations. The precise
   directory dimensions and ordering are package conventions, not compiler rules.
9. **Each package declares its accepted target dimensions in order.** Dimensions
   may constrain allowed values and requiredness. This validates selections; it
   does not replace existing NexusScript Target filtering.
10. **Package filenames are convention only.** `*.ForgePackage.nxscript` is the
    recommended pattern, not a parser or runtime requirement. Several package
    files may share a root directory. Multiple packages per file are supported.

The remaining sections describe behavior around those decisions. Concrete
authoring syntax and CLI spelling are documented in [usage](packages.md).

## Package contents

A package definition needs four things:

| Part | Meaning |
| --- | --- |
| Identity | The resolved Package definition identity; a request additionally specifies its target selections. |
| Build requirements | References to explicitly loaded local package definitions and the variants needed. |
| Build operations | Forge operations belonging to this package, rendered through their resolved Template properties. |
| Outputs | Named artifact paths expected after a successful build. |

Identity belongs to the resolved package definition. Neither the containing
directory, filename suffix, nor human-readable name alone identifies a package.
File identity provides source context, but this draft does not equate a file
with exactly one package. Several package files in one directory share a physical
root without becoming the same package. Existing definition identity and naming
rules are the starting point; no new identifier encoding is specified here.

Version, Author, and License are optional text properties. The definition name
supplies Name. Metadata is available as ordinary compiled properties for resource
and archive consumers; it does not affect identity, targets, or artifact reuse.
This first pass does not parse versions, select between versions, search for a
best match, or validate license identifiers.

Package identity and request identity are distinct. `@Compiler` identifies the
same definition regardless of the variant requested. A package request combines
that identity with normalized named target selections. In-run reuse and active
build-cycle detection use the request identity: a different variant of the same
package is not automatically a cycle.

## Root and discovery

Recommended convention: `*.ForgePackage.nxscript`. Loading follows normal
NexusScript file/module/include relationships and explicit entry paths. Forge
does not independently scan for or require this suffix. A developer may use
`*.SillyPackage.nxscript`, for example, and adjust the relevant file relationships;
the package semantics remain unchanged.

For example:

```text
workspace/
    compiler/
        native.ForgePackage.nxscript
        cross-win32.ForgePackage.nxscript
        tools.ForgePackage.nxscript
        Shared.nxscript
        source/
        bin/
    application/
        application.ForgePackage.nxscript
        Shared.nxscript
        source/
        bin/
```

The compiler package files share one source/build root. This layout illustrates
multiple files in a directory; it makes no decision about packages per file.

The application explicitly brings the compiler's package definition into scope
from its local file, then declares its requirement through a reference to that
definition. `module` is the existing mechanism to investigate for this role:
making a dependency available without aggregating it into the consumer.

A normal `@` reference does not search the filesystem or load a missing package.
Loading and reference resolution must remain distinct. No recursive discovery of
unrelated directories and no inference of packages from executables on PATH.

The root is the directory containing the package's original defining source file, not the
consumer or the location of a reference projection. Package output paths resolve
from that root. The invocation's input path resolves from the caller's working
directory. Moving the whole workspace can preserve relative package relationships.

Existing NexusScript include/module/dialect paths keep their existing rules.
Relative Template paths resolve from the source file supplying their value,
including inherited and referenced values.
There is no change to language file resolution.

## Package structure and file organization

One source file may contain several packages. Explicit package names select
between them using existing definition identity. The API accepts an omitted name
only when the document supplies exactly one package. No special loading or
reference mechanism is needed.

Conceptual structure only; this is not yet a validated package dialect example:

```text
Package Application
    requirements referencing other packages
    named outputs
    FPC CompileApplication
    other operations, in declared order
```

The package describes both the result and the operations producing it. Operations
inside a package execute when that package needs building. Loading a dependency
definition does not independently schedule its operations. Standalone Forge
operations remain possible outside package execution.

Larger definitions may use existing composition and file mechanisms where they
fit. This design does not promise implicit merging: `include` aggregates
definitions and does not splice one root's children into another root. A split-file
package example must be proved against current semantics before any shorthand
or organization pattern is specified.

## Variants

### Package target contract

Each package declares the target dimensions it accepts, in an authoritative order.
Each dimension is declared once and may specify allowed values and whether a
selection is required. Duplicate dimension declarations are errors; use existing
NexusScript identifier comparison rules rather than introducing new ones.

Conceptual example, not finalized NexusScript syntax:

```text
Accepted target dimensions, in order:
    TargetCPU — required; allowed: x86, x64
    TargetOS  — required; allowed: Windows, Linux
```

Validate the requested package selections before readiness checks or execution:

- Reject selections for dimensions the package does not declare.
- Reject a missing selection for a required dimension.
- Reject a value outside a dimension's declared allowed set. Omitting an allowed
  set adds no package-level value restriction.
- An omitted optional dimension remains unspecified. Do not infer its value from
  the host, another dimension, or an implicit default.

Target selections are named; declared dimension order provides deterministic
normalization and display, not a new semantic variant when the same names and
values are reordered. Caller argument order does not change the request.
It retains dimension names and distinguishes an unspecified optional dimension
from a supplied value. Omitting an earlier dimension must not shift later values
into its position or make different selections appear identical.

The accepted-target declaration is the package's input contract. Existing
NexusScript Targets still select the applicable definitions, build operations,
and outputs. No second filtering engine is introduced. Each dependency's requested
selection is validated against that dependency's own target contract.

Allowed values for individual dimensions do not establish which combinations
are supported. Cross-dimension combination constraints are deferred unless the
first concrete compiler package demonstrates that they are necessary. Do not
infer that every allowed CPU/OS pair has an available compiler or build recipe.

### Output layout and readiness

Readiness applies to the selected variant, not every possible output of every
variant. Different variants that must coexist declare different output locations;
Forge must not mistake one variant's executable for another merely because both
are called a compiler.

For a compiler package, where the compiler runs and what it generates are distinct
facts. Those can be represented with named target dimensions. This does not imply
automatic toolchain discovery or a compiler-version manager.

Illustrative folder layout, not prescribed platform spelling or interpolation syntax:

```text
package/
    compiler.ForgePackage.nxscript
    bin/
        <host>/
            <target>/
                compiler.exe
                compiled-unit.ppu
                compiled-unit.o
```

An output can retain the public name `Compiler` across variants while its selected
path changes. The consumer supplies the requested Targets and output name; it
does not construct this directory hierarchy. The package declares concrete paths
through the applicable definitions. No automatic path-generation grammar is
implied by the angle-bracket placeholders above.

The ordered target declaration could also determine directory component order
if automatic variant-folder construction is adopted later. This draft does not
require that feature or define how omitted optional dimensions would be encoded
in generated paths. Explicit selected output paths remain the initial mechanism.

One compiler package can expose several target variants. Whether those variants
use one compiler executable or several depends on the actual compiler. A directory
layout cannot confer additional compilation capabilities. A genuinely shared
executable may have one shared output path, while target-specific units or other
required artifacts occupy separate directories. Readiness checks all outputs
declared for the requested variant, not just the executable.

A dependency must identify the variant it needs. The build tool required by a
cross-target application need not have the same target selection as the application.
Requirements supply named Selection entries explicitly; silently assuming that
every dependency uses identical targets would be incorrect.

## Readiness and build behavior

Proposed sequence:

```text
Require a package and variant
    locate and validate its root definition
    validate its target contract and the requested selections
    select its declared outputs
    all outputs present?
        yes: return the named output paths
        no:
            obtain its declared build requirements
            run its selected Forge operations from the package root
            require successful completion
            require every declared output to be present
            return the named output paths
```

At least one output must be declared for a buildable selected variant. An empty
output list must not make a package vacuously ready.

Outputs are explicit paths in the initial design. A declared file must exist as a
file; a declared directory must exist as a directory. A directory's existence does
not prove anything about its contents. Declare required files individually when
that distinction matters. No output globbing or inferred completeness rules are
needed initially.

A ready package does not rebuild or require its build prerequisites to be rebuilt.
An already-built compiler, for example, need not retain its bootstrap compiler.
These requirements describe building the package; they are not a new runtime
dependency-management facility.

This skips prerequisite artifact checks and builds, not normal NexusScript
loading and reference resolution. Referenced definition files may still be needed
to compile the package document even when its outputs already exist.

Missing artifacts cause the selected operation sequence to run as a whole. Forge need not identify
which operation should recreate a particular missing artifact. The recipe and
underlying tools handle their normal build behavior.

For this pass, an explicit rebuild can be achieved by removing the declared
outputs and requesting the package again. A dedicated rebuild command is not
necessary to establish the initial contract.

## Named outputs and consumption

NexusScript resolves package identity; Forge resolves package readiness and output
locations. The compiled model already distinguishes the resolved definition from
its bounded reference projection. Forge must follow the definition identity,
not assume the projection is a complete copy of the package. In particular,
structural arrays deliberately omitted from projections remain omitted.

Conceptually, `Requires: @Compiler` identifies a package definition already in
scope. This neither ensures that package is built nor selects one of its outputs.
It needs no package-specific meaning inside NexusScript reference resolution.

Illustrative relationships, not proposed NexusScript syntax:

```text
compiler package
    output Compiler = bin/<host>/<target>/compiler.exe
    operations producing its declared outputs

application package
    requires the loaded compiler package, with the required compiler variant
    compile operation uses that requirement's named output Compiler
    output Application = bin/<target>/application.exe
```

Selecting the named output supplies the path declared by that dependency,
anchored at the dependency's package root. Consumers do not duplicate its `bin`
layout. An unknown output name is an error, not an empty template value or a
fallback PATH lookup.

The selected output's location can be known from its declaration before any build
runs. Its presence is a separate question. Forge ensures the required package is
ready before executing the consumer. The design does not require deferred `@`
evaluation to discover the path after execution.

The operation still needs to identify which output it consumes when a requirement
provides several. A PackageOutput descriptor names the requirement and output;
the operation references that descriptor normally. Forge supplies its resolved
path in the rendering context without new reference or interpolation syntax.

Resolved output paths must be made available as ordinary build inputs before
command rendering. The Mustache template remains responsible for quoting the
compiler executable path and its arguments. The executor remains unaware that
the executable came from a compiler package.

The same mechanism can supply a library's unit directory, a generated file, or
an application's executable. It should not require a different resolver for each.

## Execution boundaries and failure

Managed builds prepare selected artifact parent directories before launching their
operations. Ready-package reuse does not prepare directories. Preparation does not
create directory artifacts themselves.

The package runtime does not interpret operation Output properties, inject derived
directory values, or constrain intermediate output locations. FPC's optional text
UnitOutput property explicitly supplies -FU through its template. Our configurations
use the artifact directory for units by referencing the same declared directory.
Any additional intermediate-directory preparation belongs to the recipe.

Package coordination remains sequential. Obtain required packages before running
the dependent recipe. Reuse a resolved package/variant within the request and
detect cycles among packages currently needing a build. Report the dependency
chain rather than recursing indefinitely. No parallel scheduler is needed.

A failed prerequisite stops its consumer. A failed operation retains ordinary
Forge command/output/exit diagnostics. A recipe that exits successfully but leaves
a required output absent is a failed package build and names the missing output.

Logs should distinguish reuse from building and identify the package, selected
variant, and relevant paths. This does not require a persistent build database.

Artifact presence is intentionally not proof of freshness or provenance. Source
edits do not invalidate existing outputs. Likewise, a failed recipe may leave
files behind: that request fails, but a later request applies the same presence
rule and may reuse them if every declared output now exists. This is a consequence
of the chosen simple contract, not a reason to quietly add success stamps or
automatic cleanup. The caller can remove unwanted outputs to force another build.

## Integration with existing Forge

Package coordination should call the existing compile/validate/render/execute
path for the package's selected operations. The package root is their working
directory, including when composition supplies operations from other files. Standalone Forge
operation execution retains its current document-relative default.

The runner executes the concrete operations belonging to a requested package.
Package metadata, Environment data, and module-only definitions are not commands.
Preflight rendering, declaration order, and stop-on-failure behavior apply to each
operation list.

Shared configurations are ordinary modules containing partial operation bases
and target-selected Environment values. Composition completes each operation,
including its Template; validation checks the concrete operation. No separate
process catalog, matching by kind, or invocation manifest parameter is needed.
A package and its dependencies each load their definitions under their own request
Targets. The dependency does not receive the consumer's filtered configuration.

Environment property names and target values remain author-defined. A package
can concatenate an imported suffix into its declared output Path and reference
that same Path from its operation, so artifact detection and compiler output agree.
No operating-system naming rules belong in Forge's runtime.

The package layer supplies resolved dependency outputs to the recipe; it must not
rewrite tool commands or reconstruct FPC options. Forge language pieces continue
to be discovered by `*.ForgeDef.nxscript`. Package authoring vocabulary should use
the existing dialect/composition facilities without changing filename semantics.

This design is a prerequisite for expressing reusable compiler build stages.
It does not specify or claim to verify an FPC bootstrap/cross-compiler build
sequence. That recipe still needs to be established against the actual sources
and required target toolchain.

## Implemented authoring choices

Multiple packages per file use explicit package names. Requirements contain an
ordinary package reference and named Selection entries for dependency Targets.
Named outputs use Output entries. A PackageOutput descriptor selects a requirement
and its output; operations reference that descriptor using normal references.
Forge resolves it to an absolute path in the operation rendering context.
The compiled model and generic JSON contract remain unchanged.

Tests exercise dependency-specific configuration selection and consume a real
compiler executable through its named output. See [usage](packages.md).

## Acceptance examples

- A package with all selected outputs present is reused without launching a tool.
- Removing one required output runs the recipe; success requires all outputs afterward.
- Source changes alone do not trigger rebuilding.
- Invoking from a different directory preserves package-relative behavior.
- Several package files in one directory retain distinct definition identities
  while resolving their outputs and operations from the same physical root.
- Changing the filename convention and updating explicit loading relationships
  preserves package behavior; no Forge suffix scan is needed.
- A package contains and executes its own operations without a required Build.nxscript.
- Loading a dependency and referencing its package identity does not execute it.
- Reference projections retain their existing bounded behavior; Forge inspects
  the actual dependency definition for its build and output declarations.
- A consumer obtains a compiler by its named output and successfully runs it.
- Two consumers requesting the same package variant reuse the available result.
- Reordering caller selections does not change variant identity or output selection.
- Duplicate target-dimension declarations, undeclared selections, missing required
  selections, and disallowed values fail before readiness checks or execution.
- An omitted optional dimension remains unspecified and distinct from an explicitly
  selected value, with later dimensions retaining their identities.
- A dependency's selections are checked against its own accepted target set.
- Distinct variants do not satisfy one another through accidental output-path reuse.
- Stable output names resolve to the selected variant's declared folder paths.
- Where an executable is shared across targets, missing target-specific required
  artifacts still cause that variant to need building.
- A ready package works without rebuilding its build prerequisites.
- Missing package definitions, unknown outputs, and unresolved variants fail clearly.
- A cycle among packages needing builds reports the chain.
- Prerequisite failure prevents consumer execution.
- A zero-exit recipe with missing outputs fails its package request.
- Paths with spaces and `&` continue to work through existing template quoting.

## Explicit exclusions

Hashing, timestamps, source freshness, persistent build-state tracking, automatic
partial-output cleanup, remote repositories, downloads, version solving, automatic
compiler installation, environment activation/repair, parallel package builds,
fine-grained incremental scheduling, and automatic variant-folder construction
are outside this first pass. Cross-dimension target constraints remain deferred
unless the first compiler package establishes a concrete requirement.

Review should look for contradictions, missing behavior needed by the examples,
and unnecessary complexity. Artifact presence, root-local definitions, and the
local-only first pass are intentional constraints.
