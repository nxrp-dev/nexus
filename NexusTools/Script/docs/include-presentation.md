# Generating from included systems

`include` contributes definitions to one presentation. `module` makes definitions
available for references and composition. A file used through both contributes
once, while references still resolve to the original definitions. A separately
composed definition remains a separate output item.

To generate tables from Inventory and Customer, the entry file can contain:

```nexusscript
include "Inventory.nxscript";
include "Customer.nxscript";
```

The Mustache template can iterate all contributed tables, including tables
nested inside system roots:

```mustache
{{#_nx.Collections.Table}}
create table {{_nx.Name}} ...;
{{/_nx.Collections.Table}}
```

Collections use the actual definition kind, without automatic pluralization.
Each item has the normal definition JSON: its properties, nested definitions,
and `_nx` metadata. Fields and indexes stay inside their table; collecting a
table does not combine its members with another table's members. Named root
lookup remains available for explicit constants and intentionally grouped output.

The presentation gathers the entry document followed by included documents in
declaration order, recursively. A shared included document contributes once.
Module-only definitions do not contribute independently. Reference values keep
their original target metadata and are not counted as additional declarations.
Source provenance is retained in each definition's `_nx.SourceRange`.

Inclusion does not merge same-named roots or rewrite lexical identity. Distinct
roots with the same name are errors. Nested names retain their owner scope, so
different tables can each contain a field called `ID`. A kind collection is an
iteration view, not a new namespace for resolving references.

Reusable bases placed in an included file are exposed just like any other
definition. Keep them in module-only files when they should not be generated.
There is no automatic classification or exclusion of templates.

## Included language rules

A declared language can include independently named language fragments:

```nexusscript
include "pieces/*.nxscript";
Language Forge {
    UnknownDefinitions: Reject;
    Definitions: [];
}
```

Each fragment contributes its own `Language` root and `Definitions` array.
Validation gathers those rule entries through the same included-definition view;
the master need not name or inherit from the fragment roots. Duplicate rule
names are errors, not overrides. The declared language supplies the unknown-kind
policy; an explicitly supplied fragment policy must agree. Invalid included
subject definitions are also validated.

Dialect file lookup is unchanged: inclusion does not choose the document's
dialect or introduce a discovery registry.

## Verification

```powershell
lazbuild -B NexusTools\Script\tests\NexusScriptTests.lpi
& .\output\NexusScript\console-tests\x86_64-win64\NexusScriptTests.exe
```

The console runner executes the existing NexusScript cases plus include
collection, mixed module/include, and included-language regressions. Fixtures
under `tests/fixtures/include-collections` demonstrate the nine-table example,
diamond includes, repeated includes, references, composition, collisions, and
language rules loaded from separate files.
