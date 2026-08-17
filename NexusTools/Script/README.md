# NexusScript

NexusScript compiles a source document and produces the JSON representation
used by the existing artifact pipeline. A Mustache template may transform that
JSON into the final artifact.

```text
NexusScript /input=Customer.Schema.nxscript
NexusScript /input=Customer.Schema.nxscript /output=Customer.json
NexusScript /input=Customer.Schema.nxscript /template=Firebird.mustache
NexusScript /input=Customer.Schema.nxscript /template=Firebird.mustache /output=Customer.sql
```

## Options

- `/input=<file>` is the required NexusScript source document.
- `/output=<file>` writes the artifact to a file. Without it, the artifact is
  written to stdout.
- `/template=<file>` renders the generated JSON through a Mustache template.
- `/validate` validates the compiled document through its explicit `doctype`
  association before producing output.
- `/help` displays generated command-line help.

Without `/template`, JSON is the final artifact. With `/template`, the same JSON
is generated internally and passed to Mustache.

Diagnostics are written to stderr so redirected stdout contains only the
artifact. Filename components such as `.Schema` are decorative and have no
execution meaning.

The current JSON is the established metadata artifact representation. It is not
a serialization of NexusScript compiler internals, and documents unsupported
by the existing artifact path are rejected rather than represented as empty
JSON.

An entry document may declare `include Path;` dependencies. Included documents
are compiled separately, contribute to the same artifact in deterministic
entry-first order, and do not introduce reference namespaces. Use `module`
when definitions must be addressable from another document. A `doctype Path;`
association remains separate and does not contribute artifact content unless
that document is also included.
