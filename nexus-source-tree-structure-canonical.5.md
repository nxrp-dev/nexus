# Nexus Source Tree Structure — Canonical


## Canonical Status

This document consolidates and supersedes the source-layout documents that led to it:

- `nexus-package-source-layout.md`
- `nexus-source-tree-structure.md`
- `nexus-source-tree-structure (1).md`
- `nexus-source-tree-structure-recursive.md`
- `nexus-source-tree-structure-normalized.md`
- `nexus-source-tree-structure-metadata.md`

Where those documents disagree, the later recursive, normalized, and metadata rules in this document are authoritative. Earlier examples remain useful only where they do not conflict with these rules.

## Purpose

This document defines the physical on-disk source-tree conventions for
Nexus products, product families, packages, tests, extensions,
languages, configuration, schemas, resources, and supporting development
tools.

The central rules are:

> **Physical containment expresses ownership, not dependency.**

> **Conformity applies to meaning, not arbitrary physical sameness.**

If Forge uses NexusScript, NexusScript does not belong under Forge. If
NexusCode uses the language servers, the language servers do not belong
under NexusCode. Reusable implementations live independently under
`packages/`; concrete product implementations live under `projects/`;
internal development and maintenance utilities live under `tools/`.
Within each category, product-specific material lives with the component
that owns it.

Common directory names have common meanings, but technology-native
structure is retained when it carries useful meaning. Directories are
created when needed; empty directories are not required for symmetry.

## Repository Root Classification

The repository root uses broad semantic classifications before concrete
artifact identities:

``` text
Nexus/
├── packages/
├── projects/
└── tools/
```

These three directories answer different architectural questions:

- `packages/` contains reusable components intended to participate in
  other builds.
- `projects/` contains concrete artifact-producing implementations and
  product families.
- `tools/` contains internal development and maintenance utilities whose
  purpose is to operate on, inspect, transform, build, test, or administer
  Nexus artifacts and the Nexus development environment.

The distinction is based on **purpose**, not implementation form. An
executable is not automatically a tool. A language server, application,
service, installer, or extension that is a concrete implementation of
Nexus design belongs under `projects/` even though it produces an
executable or deployable artifact.

`tools/` is a specialized artifact-producing category kept separate
because its products primarily assist development or maintenance rather
than constitute the Nexus product/runtime surface.

Concrete product names therefore do not normally become peers of
`packages/`, `projects/`, and `tools/` at the repository root. For
example, `forge/`, `ls/`, `nexuscode/`, and `bothost/` belong beneath
`projects/`, while a header-maintenance utility belongs beneath `tools/`.

Repository-support material such as documentation, scripts, automation,
or metadata may still have root-level locations when its role is
repository-wide rather than an artifact classification.

## Recursive Structural Grammar

The directory rules are recursive rather than level-specific.

> **Ordinary named directories establish component/ownership scopes.
> Reserved semantic directories describe roles relative to their
> immediate owner.**

A component may own subcomponents to any useful depth:

``` text
packages/
└── network/
    ├── xmpp/
    │   ├── .nx/
    │   │   └── index/
    │   ├── src/
    │   │   └── bindings/
    │   ├── doc/
    │   ├── runtime/
    │   └── test/
    └── torrent/
        ├── src/
        ├── test/
        └── bit/
            ├── src/
            ├── test/
            └── nxbit/
                ├── src/
                ├── runtime/
                └── test/
```

`network`, `xmpp`, `torrent`, `bit`, and `nxbit` are component/ownership
scopes. Reserved names such as `src`, `bindings`, `runtime`, and `test`
retain their meanings relative to their immediate owner. The rules
therefore do not depend on hierarchy depth.

## Largest Current Example

``` text
Nexus/
├── projects/
│   ├── forge/
│   │   ├── src/
│   │   │   └── nxForge.pas
│   │   ├── language/
│   │   │   ├── Forge.nxscript
│   │   │   └── definitions/
│   │   │       ├── FPC.ForgeDef.nxscript
│   │   │       └── Git.ForgeDef.nxscript
│   │   └── test/
│   │       └── ... Forge NXTest cases ...
│   │
│   ├── setup/
│   │   ├── src/
│   │   │   └── nxSetup.pas
│   │   ├── language/
│   │   │   └── Setup.nxscript
│   │   ├── resources/
│   │   │   ├── fonts/
│   │   │   └── images/
│   │   ├── runtime/
│   │   │   └── ... support binaries ...
│   │   └── test/
│   │       └── ... Setup NXTest cases ...
│   │
│   ├── schema/
│   │   ├── src/
│   │   │   └── ... Schema implementation ...
│   │   ├── language/
│   │   │   └── Schema.nxscript
│   │   ├── templates/
│   │   │   ├── sqlite/
│   │   │   ├── firebird/
│   │   │   └── oracle/
│   │   ├── ext/
│   │   │   └── csv-mustache/
│   │   │       ├── src/
│   │   │       └── test/
│   │   └── test/
│   │       └── ... Schema NXTest cases ...
│   │
│   ├── ls/
│   │   ├── pascal/
│   │   │   ├── src/
│   │   │   │   └── ... Pascal LS composition/adaptation ...
│   │   │   └── test/
│   │   └── nxscript/
│   │       ├── src/
│   │       │   └── ... NexusScript LS composition/adaptation ...
│   │       └── test/
│   │
│   ├── nexuscode/
│   │   ├── src/
│   │   │   └── extension.ts
│   │   ├── resources/
│   │   │   ├── images/
│   │   │   └── icons/
│   │   ├── runtime/
│   │   ├── syntaxes/
│   │   │   ├── pascal.tmLanguage.json
│   │   │   └── nexusscript.tmLanguage.json
│   │   ├── snippets/
│   │   ├── test/
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── test/
│   │   ├── host/
│   │   │   ├── src/
│   │   │   └── test/
│   │   └── ui/
│   │       ├── src/
│   │       ├── resources/
│   │       ├── runtime/
│   │       └── test/
│   │
│   └── bothost/
│       ├── src/
│       ├── config/
│       │   └── ... deployment configuration scripts ...
│       ├── schema/
│       │   └── ... BotHost database Schema definitions ...
│       ├── resources/
│       ├── runtime/
│       └── test/
│
├── tools/
│   └── headers/
│       ├── src/
│       │   └── ... header/license scanner and updater ...
│       └── test/
│
└── packages/
    ├── pascal/
    │   ├── src/
    │   │   └── ... parser, model, resolver, analysis ...
    │   └── test/
    ├── nxscript/
    │   ├── src/
    │   │   └── ... parser, compiler, source/semantic model ...
    │   └── test/
    ├── test/
    │   ├── src/
    │   │   └── ... reusable NXTest framework ...
    │   └── test/
    │       └── ... tests of NXTest itself ...
    ├── compression/
    │   ├── src/
    │   │   └── nxzip.pas
    │   ├── external/
    │   │   ├── abbrevia/
    │   │   └── paszlib/
    │   └── test/
    ├── mustache/
    │   ├── src/
    │   │   └── nxmustache.pas
    │   ├── external/
    │   │   └── dmustache/
    │   └── test/
    ├── network/
    │   ├── json-rpc/
    │   │   ├── src/
    │   │   └── test/
    │   ├── lsp/
    │   │   ├── src/
    │   │   └── test/
    │   ├── xmpp/
    │   │   ├── .nx/
    │   │   │   └── index/
    │   │   ├── src/
    │   │   │   └── bindings/
    │   │   ├── doc/
    │   │   ├── runtime/
    │   │   │   └── ... XMPP-only native binaries ...
    │   │   └── test/
    │   ├── torrent/
    │   │   ├── src/
    │   │   ├── test/
    │   │   └── bit/
    │   │       ├── src/
    │   │       ├── test/
    │   │       └── nxbit/
    │   │           ├── src/
    │   │           ├── runtime/
    │   │           └── test/
    │   ├── external/
    │   │   └── synapse/
    │   └── test/
    ├── gui/
    │   ├── src/
    │   ├── external/
    │   │   └── fpgui/
    │   └── test/
    ├── fpc/
    │   ├── fcl-db/
    │   │   ├── src/
    │   │   └── test/
    │   ├── fcl-json/
    │   │   ├── src/
    │   │   └── test/
    │   ├── rtl-generics/
    │   │   ├── src/
    │   │   └── test/
    │   └── ... other directly adopted FPC packages ...
    ├── sqlite/
    │   ├── src/
    │   │   ├── bindings/
    │   │   │   └── ... Nexus-maintained SQLite bindings ...
    │   │   ├── nxsqlite.pas
    │   │   └── nxsqlitedataset.pas
    │   ├── runtime/
    │   │   └── win64/
    │   │       └── sqlite3.dll
    │   ├── reference/
    │   │   └── sqlite3.h
    │   └── test/
    ├── firebird/
    │   ├── src/
    │   │   ├── bindings/
    │   │   └── ... optional higher-level source ...
    │   ├── runtime/
    │   ├── reference/
    │   └── test/
    └── lua/
        ├── src/
        │   └── bindings/
        ├── runtime/
        ├── reference/
        └── test/
```

The remote-test/network component discussed during design is
intentionally not assigned a final location because its actual role has
not yet been reviewed.

## `projects/`

`projects/` contains concrete Nexus artifact-producing implementations
and product families.

A project exists primarily to produce a concrete artifact such as an
application, service, language server, extension, installer, or other
deployable/runtime product. It may consume any number of reusable
packages without owning those packages physically.

Examples include:

``` text
projects/
├── forge/
├── setup/
├── schema/
├── nexuscode/
├── bothost/
├── test/
│   ├── host/
│   └── ui/
└── ls/
    ├── pascal/
    └── nxscript/
```

If several independently meaningful executable roles form one coherent
product family, they may be grouped beneath that family. `projects/ls/`
is the canonical example: Pascal LS and NexusScript LS are distinct
concrete implementations, while `ls/` expresses their shared product
family. `projects/test/` follows the same rule for the Host and UI test
applications.

A project is **not** classified as a tool merely because it builds an
executable or is primarily used by developers. The language servers are
part of the Nexus development/runtime product surface and therefore live
under `projects/`, not `tools/`.

Projects and packages intentionally have different obligations:

> **Package = structured participant.**

> **Project = artifact producer.**

Packages require stronger structural knowledge because they are intended
to interoperate, be discovered, deployed, indexed, and consumed by other
code. A project's internal source arrangement is comparatively opaque to
the rest of Nexus; Forge primarily needs its declared inputs, entry
points, dependencies, outputs, compiler/toolchain, artifact type, and
other build settings.

Projects should use the normal Nexus semantic folders (`src/`, `test/`,
`runtime/`, `doc/`, `.nx/`, and so on) where those meanings apply, but
their internal layout may be declaration-described rather than inferred
as a package contract.

## `packages/`

Everything beneath `packages/` conforms to the Nexus package structural
grammar regardless of origin.

> **If it is materialized under `packages/`, Nexus package structure
> applies.**

This includes first-class Nexus packages, directly adopted FPC packages,
and any future externally sourced package families. Origin and
maintenance policy do not create structural exceptions.

Upstream packages may therefore be physically reorganized during import
so that source, tests, runtime payloads, resources, bindings,
references, and nested components occupy their normal Nexus semantic
locations.

This is packaging normalization, not necessarily source modification or
implementation ownership.

A useful rule is:

> **Preserve upstream code where policy requires it; normalize upstream
> packaging.**

`packages/` is the local home of the reusable package universe available
to Nexus. Packages are built primarily to be consumed from code and may
contain source, external implementation source, bindings, runtime
payloads, reference material, resources, and tests.

`packages/` is preferred over `lib/` because these units are richer than
traditional libraries.

Package acquisition, remote repository organization, globally unique
package IDs, prefixes such as `nx-`, versions, and artifact identity are
future package-definition/distribution concerns rather than
source-layout concerns.

## `src/`

`src/` contains implementation source owned or presented by its
immediate enclosing component. The rule is recursive; `src/` may appear
beneath a package, product, extension, tool, or nested component. If a
subdivision can independently own runtime payloads, resources, tests, or
further components, model it as a component and let it own its own
`src/`.

For packages, it does not mean "originally authored by Nexus."
Nexus-authored NexusScript, directly adopted and structurally normalized
FCL-DB under `packages/fpc/fcl-db/`, and higher-level SQLite code can
all legitimately live under `src/`.

## `test/`

`test/` contains tests owned by the immediately enclosing component,
whether that component is a product, executable role, extension,
internal tool, package, or nested component. NXTest cases belong beside
the thing they verify:

``` text
projects/forge/test/
projects/ls/pascal/test/
tools/headers/test/
packages/nxscript/test/
packages/fpc/fcl-db/test/
packages/sqlite/test/
```

The reusable NXTest framework itself remains:

``` text
packages/test/src/
```

and its own tests naturally live at:

``` text
packages/test/test/
```

The repeated word is intentional: the first `test` is the package
identity; the second is the standard test folder.

## `.nx/`

`.nx/` contains Nexus-private metadata **about** its immediate enclosing
component.

The dot prefix is intentional. Normal semantic folders describe the
component itself; `.nx/` contains Nexus's machine-oriented knowledge
about that component.

Like the rest of the structural grammar, `.nx/` is recursive and may
appear at any ownership scope:

``` text
packages/network/.nx/
packages/network/xmpp/.nx/
packages/network/torrent/bit/.nx/
```

Potential contents include fingerprints, signatures, deterministic
indexes, and local caches.

A representative structure is:

``` text
.nx/
├── fingerprints
├── fingerprints.sig
├── index/
│   └── symbols
└── cache/
    └── ...
```

The exact filenames and binary formats remain separate design decisions.

### `.nx/index/`

`.nx/index/` contains deterministic, portable, regenerable indexes
describing the enclosing component.

A prebuilt symbol index may contain information such as:

``` text
units
public symbols
symbol kinds
signatures
visibility
source locations
component/package ownership
dependencies
target/platform applicability
documentation references
```

This allows language tooling to discover symbols without reparsing every
package at startup.

For example, an unresolved Pascal identifier such as `StrToInt` can be
resolved through package indexes to its providing unit and component,
allowing tooling to offer an appropriate `uses` fix or future package
dependency action.

An index is derived data rather than source authority. The underlying
source remains authoritative.

### Content-root linkage

A portable index should record the exact content fingerprint/root from
which it was generated.

Conceptually:

``` text
current component root = 83AD...
index content root      = 83AD...

MATCH -> index describes current contents
```

If the roots differ:

``` text
current component root = 912C...
index content root      = 83AD...

MISMATCH -> index is stale and must be rejected/rebuilt
```

This avoids relying on timestamps or ad hoc freshness heuristics.

Where prebuilt indexes are distributed, the content-integrity/signature
system may also authenticate them according to the eventual fingerprint
design.

### `.nx/cache/`

`.nx/cache/` contains machine-local disposable acceleration state.

Cache contents are:

-   safely regenerable;
-   not authoritative;
-   not required to be portable;
-   not required to survive source transfer or packaging.

This is distinct from `.nx/index/`, whose contents may be intentionally
generated and distributed as portable package metadata.

### Authoritative versus derived metadata

`.nx/` may contain both authoritative metadata and derived metadata, but
their roles must remain explicit.

For example:

``` text
fingerprints / signatures   authoritative integrity metadata
index/                      deterministic derived metadata
cache/                      local disposable metadata
```

`.nx/` should not become an unclassified junk drawer. New metadata types
should receive explicit semantics when introduced.

## `doc/`

`doc/` contains documentation owned by its immediate enclosing
component.

The rule is recursive:

``` text
packages/network/doc/          # package-wide network documentation
packages/network/xmpp/doc/     # XMPP-specific documentation
packages/sqlite/doc/           # SQLite package documentation
```

Documentation belongs at the narrowest component scope it documents.

`doc/` may later participate in discovery tooling. Because source,
documentation, tests, runtime payloads, and private metadata share the
same ownership scope, tooling can locate related material without
package-specific mappings.

## `examples/`

`examples/` contains example material owned by its immediate enclosing component. Like `test/`, `doc/`, and `runtime/`, it follows the recursive ownership rule.

``` text
packages/network/xmpp/examples/
packages/sqlite/examples/
```

Examples should live at the narrowest component scope they demonstrate. Material that is actually used for deployment or operation is not an example merely because it can also serve as one; real configuration belongs under `config/`.

## Authoritative Component Definitions

Authoritative declarative files that define a component belong with the component being defined, not inside `.nx/`. `.nx/` is Nexus-private machine-oriented knowledge **about** the component; it is not a hiding place for the component's source-of-truth configuration.

For Forge-managed components, a `*.Forge.nxscript` definition therefore belongs at the component root when such a definition exists:

``` text
packages/sqlite/
├── SQLite.Forge.nxscript
├── src/
├── test/
└── .nx/
```

The general rule is:

> **Definition belongs with the thing being defined. Derived/private knowledge about that thing belongs in `.nx/`.**

## `external/`

`external/` contains non-Nexus implementation source beneath a distinct
Nexus-facing package implementation.

It says nothing about maintenance policy. The contents may be a
Nexus-maintained fork, an untouched upstream tree, FPC-derived source,
or several implementations consolidated behind one Nexus API.

``` text
compression/
├── src/
│   └── nxzip.pas
└── external/
    ├── abbrevia/
    └── paszlib/
```

## `src/bindings/`

`bindings/` is a reserved subdivision of `src/` containing low-level
bindings to an external API or ABI. Nexus maintains every binding it
adopts, regardless of original authorship.

Bindings belong to the narrowest source scope that owns them:

``` text
packages/sqlite/src/bindings/
packages/network/xmpp/src/bindings/
```

Higher-level source built on a binding remains at the `src/` root:

``` text
sqlite/src/
├── bindings/
├── nxsqlite.pas
└── nxsqlitedataset.pas
```

## `runtime/`

`runtime/` contains binaries or other payloads required at runtime by
its immediate enclosing component. It is not a home for subordinate
executable source.

Runtime payloads belong at the **narrowest ownership scope that requires
them**:

``` text
packages/sqlite/runtime/
packages/network/xmpp/runtime/
packages/network/torrent/bit/nxbit/runtime/
```

A Torrent consumer must not receive XMPP-only binaries merely because
both components belong to `network`. This gives the future
package/deployment system enough structural information to deploy
payloads with the component that owns them.

## `resources/`

`resources/` contains non-code assets such as fonts, images, and icons.
Functional definitions with stronger semantic identities retain their
own folders, such as `syntaxes/` or `templates/`.

## `reference/`

`reference/` contains authoritative maintenance material that is not
package implementation source. Binding packages may keep native headers
here, for example `sqlite/reference/sqlite3.h`.

## `language/`

`language/` contains a language or dialect definition owned by the
enclosing product:

``` text
projects/forge/language/Forge.nxscript
projects/setup/language/Setup.nxscript
projects/schema/language/Schema.nxscript
```

The reusable NexusScript engine remains under `packages/nxscript/`.

## `language/definitions/`

`language/definitions/` contains composable subordinate definitions that
extend the owning language.

For Forge:

``` text
projects/forge/language/
├── Forge.nxscript
└── definitions/
    ├── FPC.ForgeDef.nxscript
    └── Git.ForgeDef.nxscript
```

ForgeDefs are sub-validations/definitions aggregated into the Forge
language to add validation and construction support. They may be
supplied externally without becoming separate Forge implementations.

## `templates/`

`templates/` contains functional templates owned by a product. Schema
uses Mustache templates to turn its model into target-specific output:

``` text
projects/schema/templates/
├── sqlite/
├── firebird/
└── oracle/
```

These are not generic passive resources; they are part of Schema's
output behavior.

## `ext/`

`ext/` contains subordinate functionality that extends the behavior
available through the owning product/system.

For example:

``` text
projects/schema/ext/
└── csv-mustache/
    ├── src/
    └── test/
```

The CSV/Mustache component is runtime/end-user functionality available
to Schema scripts, not a Nexus developer utility. `ext/` describes its
relationship to Schema without implying a service, plugin architecture,
or development tool.

## `config/`

`config/` contains real configuration owned by the enclosing product.

BotHost deployment scripts belong under:

``` text
projects/bothost/config/
```

even if they can also serve as useful examples. Files actively used for
deployment should not be mislabeled as `examples/`.

## `schema/`

At product level, `schema/` contains data/database schema definitions
owned by that product:

``` text
projects/bothost/schema/
```

This is distinct from `language/`. BotHost is using the Schema dialect
to define its persistent model; it is not defining a BotHost programming
language.

## `tools/`

Root-level `tools/` contains true internal development and maintenance
utilities used to develop, inspect, transform, build, test, or administer
the Nexus codebase and development environment.

A tool is a specialized artifact-producing implementation, but its
classification is determined by **purpose**, not by the fact that it is
an executable.

Use `tools/` when the primary purpose of the artifact is to operate on
other Nexus artifacts or assist Nexus development/maintenance. Use
`projects/` when the artifact is itself a concrete implementation of the
Nexus product/runtime design.

Examples:

``` text
tools/
└── headers/
    ├── src/
    └── test/

projects/
└── ls/
    ├── pascal/
    └── nxscript/
```

The header utility is a tool because it maintains source artifacts. The
language servers are projects because they are concrete runtime
implementations consumed by editors such as NexusCode.

This is deliberately different from `projects/schema/ext/`: `tools/`
serves Nexus developers/maintenance, while the latter provides
end-user/runtime functionality to Schema.

## Technology-Native Structure

A product may retain meaningful ecosystem-native structure where forcing
it into generic Nexus folders would destroy useful semantics.

NexusCode is the primary example:

``` text
projects/nexuscode/
├── src/
├── resources/
├── runtime/
├── syntaxes/
├── snippets/
├── test/
├── package.json
└── tsconfig.json
```

TextMate grammars belong under the meaningful VS Code `syntaxes/`
convention rather than being hidden under `resources/`. `package.json`,
`tsconfig.json`, and similar ecosystem-native files remain where their
technology expects them.

Conformity is semantic, not cosmetic.

## Ownership Versus Dependency

A dependency does not move under its consumer.

Forge uses NexusScript:

``` text
projects/forge/
packages/nxscript/
```

The concrete language-server projects use their language implementation
and reusable protocol infrastructure:

``` text
packages/pascal       ──┐
packages/network/lsp  ──┼──> projects/ls/pascal

packages/nxscript     ──┐
packages/network/lsp  ──┼──> projects/ls/nxscript
```

NexusCode may launch or communicate with the language servers, but does
not own them:

``` text
projects/nexuscode/

projects/ls/
├── pascal/
└── nxscript/
```

Physical containment follows conceptual ownership. `projects/` groups
concrete artifact producers by product ownership; it does not imply that
one project owns the reusable packages it consumes.

## Package Identity, Class, and Direct Adoption

Unqualified children of `packages/` are first-class Nexus packages.
Their package identity is the identity Nexus presents.

When Nexus hides an implementation behind a Nexus-controlled API, name
the first-class package for the capability:

``` text
packages/compression/
packages/network/
packages/gui/
```

When Nexus maintains bindings for an external API as part of the Nexus
package surface, the API/library identity is appropriate and remains
first-class:

``` text
packages/sqlite/
packages/firebird/
packages/lua/
```

When Nexus directly adopts packages from an external package family and
intentionally exposes them essentially as those packages, place them
beneath a family qualifier while preserving each package's established
name:

``` text
packages/fpc/
├── fcl-db/
├── fcl-json/
├── rtl-generics/
└── ...
```

Do not collapse those identities into paths such as `packages/fpc/db/`.
The grouping adds classification; it does not rename the adopted
package.

The `fpc/` qualifier means more than "this source once came from FPC."
It means **this remains an FPC package in the Nexus package universe**.
If FPC-derived source is instead incorporated beneath a first-class
Nexus abstraction, it follows that abstraction:

``` text
packages/compression/
├── src/
└── external/
    └── paszlib/
```

There is no corresponding `packages/nexus/` group. The unqualified
`packages/` level is already the first-class Nexus namespace. Additional
qualifier groups should be introduced only for real second-class package
families that Nexus exposes directly.

Filesystem names need not solve future globally unique package identity.
That belongs to the future package-definition system.

## Directory Vocabulary Summary

  ---------------------------------------------------------------------
  Directory                          Meaning
  ---------------------------------- ----------------------------------
  `projects/`                        Concrete artifact-producing
                                     Nexus implementations and product
                                     families

  `packages/`                        Reusable package universe;
                                     unqualified children are
                                     first-class Nexus packages

  `packages/<qualifier>/`             Second-class directly adopted
                                     package family, such as
                                     `packages/fpc/`

  `src/`                             Implementation source
                                     owned/presented by the enclosing
                                     concept

  `test/`                            NXTest cases/tests owned by the
                                     enclosing concept

  `examples/`                        Example material owned by the
                                     enclosing component

  `external/`                        Underlying non-Nexus
                                     implementation source beneath a
                                     Nexus-facing package

  `src/bindings/`                    Nexus-maintained low-level API/ABI
                                     bindings

  `runtime/`                         Runtime payloads/binaries required
                                     alongside the product/package

  `resources/`                       Non-code assets such as fonts,
                                     images, and icons

  `reference/`                       Authoritative
                                     maintenance/reference material not
                                     compiled as implementation source

  `language/`                        Language/dialect definition owned
                                     by a product

  `language/definitions/`            Composable subordinate definitions
                                     extending that language

  `templates/`                       Functional templates used by a
                                     product to produce target-specific
                                     output

  `ext/`                             Subordinate functionality
                                     extending an owning product/system

  `config/`                          Real product
                                     configuration/deployment material

  `schema/`                          Product-owned data/database schema
                                     definitions

  `tools/`                           Internal Nexus development and
                                     maintenance utilities; not a
                                     catch-all for executables

  `syntaxes/`, `snippets/`, etc.     Technology-native structure
                                     retained when semantically
                                     meaningful
  ---------------------------------------------------------------------

## Component-Scoped Deployment

The recursive ownership model supplies deployment semantics. If a
component is selected or referenced, its runtime payload can follow it
without forcing sibling payloads into the deployment:

``` text
packages/network/xmpp/
├── src/
└── runtime/
    └── xmppnative.dll

packages/network/torrent/
└── src/
```

Selecting XMPP can imply `network/xmpp/runtime/*`; selecting Torrent
does not. Nested components behave identically.

## Private Metadata and Discovery

The recursive structure is also intended to support machine discovery.

Because every package and nested component uses the same ownership
grammar, tooling can recursively discover:

``` text
src/        source to parse/index
doc/        related documentation
test/       tests
runtime/    deployable payload
.nx/index/  prebuilt discovery metadata
```

This enables a global package symbol catalog without provenance-specific
rules. First-class Nexus packages and normalized adopted packages can be
indexed identically.

The filesystem therefore acts as a machine-readable architectural
contract as well as a human organization scheme.

## Structural Invariant for Package Consumers

Package consumers must not need to know where a package originally came
from in order to understand its physical structure.

These paths:

``` text
packages/sqlite/
packages/network/
packages/fpc/fcl-db/
packages/fpc/fcl-json/
```

all obey the same recursive structural grammar.

The `fpc/` qualifier communicates package class/origin relationship, not
a different filesystem dialect.

This permits global rules for source discovery, testing, runtime
deployment, resources, bindings, fingerprints, and future package
metadata without provenance-specific branches.

## Design Intent

The source tree should make ownership and architectural boundaries
obvious without encoding incidental history.

The structure does not organize first-class Nexus packages by provenance
or maintenance policy. Categories such as `nexus/`, `maintained/`,
`unmaintained/`, `forked/`, or `upstream/` do not determine where
first-class code belongs.

A qualifier such as `packages/fpc/` is different: it identifies a
second-class package family that Nexus intentionally exposes directly
while preserving the external package identities. It is therefore part
of the package contract, not merely historical provenance.

The goal is a tree in which a developer can infer why something is
physically located where it is:

-   concrete Nexus artifact-producing implementations belong in
    `projects/`;
-   reusable code belongs in `packages/`;
-   first-class Nexus packages are unqualified children of `packages/`;
-   directly adopted second-class package families use a qualifier such
    as `packages/fpc/` while preserving original package names;
-   product-specific implementation belongs with its project/product
    ownership scope;
-   tests live beside what they verify;
-   documentation lives beside the narrowest component it documents;
-   `.nx/` provides a recursive private-metadata scope for deterministic
    indexes, integrity metadata, and disposable caches;
-   external implementation source sits beneath the Nexus abstraction
    that owns it;
-   bindings are explicitly identified and Nexus-maintained;
-   runtime payloads and resources are distinct from source;
-   language definitions, schemas, templates, configuration, and
    extensions are named for their actual semantic roles;
-   internal development tools are clearly separated from concrete
    product/runtime projects, and executability alone never determines
    tool classification;
-   technology-native structure is preserved when it communicates real
    meaning;
-   every package beneath `packages/` obeys one recursive structural
    grammar regardless of origin;
-   upstream layout differences are normalized at import/update time
    rather than propagated to every package consumer.

When a future case does not fit cleanly, the rules should be
re-evaluated rather than forcing the new case into an inappropriate
existing bucket.


## Reconciliation Notes

The following earlier rules are specifically superseded or clarified here:

- Concrete Nexus products and product families are classified under `projects/`; earlier root-level examples such as `forge/`, `ls/`, `nexuscode/`, `bothost/`, and `test/` are superseded by `projects/forge/`, `projects/ls/`, `projects/nexuscode/`, `projects/bothost/`, and `projects/test/`. `tools/` is reserved for development/maintenance utilities rather than serving as a catch-all for executables.
- Category-first layouts such as `network/src/xmpp/`, `network/test/...xmpp...`, and `network/examples/xmpp/` are not the preferred model when XMPP is an independently meaningful ownership scope. The recursive form is `network/xmpp/src/`, `network/xmpp/test/`, `network/xmpp/examples/`, `network/xmpp/doc/`, and so on.
- Runtime payloads are not package-global by default. They belong to the narrowest component that requires them, allowing deployment to follow component selection.
- Directly adopted upstream/FPC packages do not retain arbitrary upstream packaging merely because of origin. Once materialized under `packages/`, they are normalized to the Nexus structural grammar.
- Directly adopted second-class package families may use a qualifier such as `packages/fpc/`, while preserving each adopted package's established name (`packages/fpc/fcl-db/`, not `packages/fpc/db/`).
- `external/` remains valid for underlying implementation source hidden beneath a distinct Nexus-facing abstraction. It should not be confused with a second-class package family that Nexus exposes directly.
- `.nx/` is recursive private metadata. It may contain integrity metadata, portable deterministic indexes, and disposable caches, but authoritative component definitions remain outside it.
- `doc/`, `test/`, `examples/`, `runtime/`, `.nx/`, and other semantic folders follow immediate ownership and therefore may appear at any component depth.

### Network Example

Applying the canonical grammar to a Network package with independently meaningful XMPP, Torrent, JSON-RPC, and LSP components yields a shape such as:

``` text
packages/network/
├── Network.Forge.nxscript
├── src/                         # source owned directly by Network
├── external/
│   └── synapse/                 # valid if Synapse is hidden implementation machinery
├── doc/
├── test/                        # tests of Network as a whole
├── .nx/
├── xmpp/
│   ├── src/
│   │   └── bindings/
│   ├── examples/
│   ├── doc/
│   ├── runtime/
│   ├── test/
│   │   └── fixtures/
│   └── .nx/
├── torrent/
│   ├── src/
│   ├── doc/
│   ├── test/
│   └── .nx/
├── json-rpc/
│   ├── src/
│   ├── doc/
│   ├── test/
│   └── .nx/
└── lsp/
    ├── src/
    ├── doc/
    ├── test/
    └── .nx/
```

The exact presence of each reserved folder is demand-driven; empty folders are not required. The key rule is ownership: if XMPP can independently own tests, documentation, runtime payloads, examples, metadata, or subcomponents, `xmpp/` is the ownership scope and `src/` belongs beneath it.
