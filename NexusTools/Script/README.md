# NexusScript

NexusScript compiles source documents and serializes their completed domain
model as generic JSON. A Mustache template may transform that same JSON into
the final artifact.

```text
NexusScript /input=Customer.Schema.nxscript
NexusScript /input=Customer.Schema.nxscript /output=Customer.json
NexusScript /input=Customer.Schema.nxscript /template=Firebird.mustache
NexusScript /input=Customer.Schema.nxscript /template=Firebird.mustache /output=Customer.sql
NexusScript /manifest=Generated.NexusManifest.nxscript /output=generated
```

## Options

- `/input=<file>` is the NexusScript source document for raw JSON and
  single-template modes. It is not used in manifest mode.
- `/output=<file>` writes the artifact to a file. Without it, the artifact is
  written to stdout.
- `/template=<file>` renders the generated JSON through a Mustache template.
- `/manifest=<file>` compiles and validates a NexusScript `NexusManifest`,
  compiles its direct `Model` sources, renders each direct `Template` against
  their combined JSON, and renders declared external data through matching
  `SourceTemplate` rules.
- `/validate` applies each input model's declared `doctype` before producing
  output. Successful compilation is sufficient when a model has no doctype.
- `/help` displays generated command-line help.

Without `/template` or `/manifest`, JSON is the final artifact. With
`/template`, the same JSON is generated internally and passed to Mustache.

`/manifest` is mutually exclusive with `/input` and `/template`. Manifest mode
requires `/output`, which is the base directory for the templates' relative
output paths. A manifest requires at least one direct `Model` and at least one
`Template` or `SourceTemplate`. Each entry's `Source` and each ordinary
template's `Output` are read from
compiled `EffectiveText`, so ordinary NexusScript references and text
composition apply; those values are not interpreted as Mustache. Sources are
relative to the manifest document.

Every model compiles independently with its own NexusScript module, include,
doctype, and reference context. The manifest does not create namespaces,
aliases, wrappers, merges, or precedence. Artifact documents from every model
contribute to one global JSON object, and root names must be unique across that
complete context. The same canonical artifact source reached through multiple
models contributes once; declaring the same model source directly more than
once is a manifest error.

All models compile and the combined JSON is serialized once before the first
template is rendered. Templates render in compiled child order and all receive
that exact JSON string. Processing stops on the first template failure without
rolling back files written by earlier templates.

```nexusscript
doctype "NexusManifest.Language.nxscript";

NexusManifest FirebirdBuild {
    Model Domain { Source: "models/Domain.nxscript"; }
    Model Constants { Source: "constants/Firebird.Constants.nxscript"; }
    Template Schema {
        Source: "mustache/DatabaseSchema.mustache";
        Output: "DatabaseSchema.sql";
    }
    SourceTemplate CommaData {
        Types: [csv, jcsv];
        Compiler: CommaDelimited;
        Source: "mustache/DataImport.mustache";
        OutputDirectory: "preload";
        OutputExtension: ".sql";
    }
}
```

## External tabular data

A NexusScript document declares its own external tabular dependencies in the
header, before definitions:

```nexusscript
data STATE "data/state.csv";
data COUNTY "data/county.tsv";

Schema Domain {}
```

The declared path is relative to the declaring document. Data declarations are
not definitions, references, modules, includes, or generic JSON roots. They are
collected separately across the entry document, includes, and imported modules;
doctype documents do not contribute data dependencies.

`SourceTemplate` maps normalized source types to one built-in compiler and one
Mustache template. `CommaDelimited` supports `csv` and `jcsv`;
`TabDelimited` supports `tsv` and `tab`. Every declared source must match one
rule. The template runs once per source, and its output filename is the source
basename with `OutputExtension` beneath the optional `OutputDirectory`.
Mappings, source files, templates, safe output paths, and output collisions are
checked before source-driven files are written.

Each source template receives only its completed tabular context:

```json
{
  "DataSource": {
    "_nx": {
      "Kind": "DataSource",
      "Name": "STATE",
      "Type": "csv",
      "Source": "data/state.csv"
    },
    "Fields": ["STATE_ID", "DESCRIPTION"],
    "Records": [
      ["CA", "California"],
      ["OR", "Oregon"]
    ]
  }
}
```

`Fields` and each positional record retain source order. The source compiler
rejects empty files, blank or duplicate headers, malformed quoted fields, and
rows whose value count differs from the header count. The external context is
not merged with the ordinary combined model context.

Diagnostics are written to stderr so redirected stdout contains only the
artifact. Filename components such as `.Schema` are decorative and have no
execution meaning.

## JSON model

The JSON root is an object. Each compiled root definition is a member keyed by
its completed definition name. Inside a definition, properties and direct child
definitions are members keyed by their domain names. There is no fixed wrapper,
kind grouping, pluralization, or Schema-specific conversion.

Every definition also has reserved `_nx` metadata containing its NexusScript
kind and identity. Domain members remain separate, so an ordinary `Name`
property does not conflict with the definition name.

```nexusscript
Catalog Product {
    Name: Nexus;
    Fields: [
        Field ID { Type: UUID; },
        Field Created { Type: Timestamp; }
    ];
}
```

```json
{
  "Product": {
    "_nx": { "Kind": "Catalog", "Name": "Product" },
    "Name": "Nexus",
    "Fields": [
      {
        "_nx": { "Kind": "Field", "Name": "ID" },
        "Type": "UUID"
      },
      {
        "_nx": { "Kind": "Field", "Name": "Created" },
        "Type": "Timestamp"
      }
    ]
  }
}
```

A Mustache template consumes the domain shape directly:

```mustache
{{#Product}}
product {{Name}}
{{#Fields}}{{#_nx}}{{Name}}{{/_nx}}: {{Type}}
{{/Fields}}
{{/Product}}
```

All scalar values are JSON strings. Arrays preserve compiled order. Structural
values are definition objects. An unnamed scalar array entry remains a string;
a named scalar or named nested-array entry is represented as an object with
`_nx.Name` and a `Value` member. A definition that declares a property or child
named `_nx` is rejected during emission.

An entry document may declare `module Path;` to make every root in another
document addressable under its declared name, or `module Root Path;` to import
only the named root. A module never renames a root and does not add the imported
document to the artifact set.

An entry document may declare `include Path;` dependencies. Included documents
are compiled separately, contribute to the same artifact in deterministic
entry-first order, and do not introduce reference namespaces. Use `module`
when definitions must be addressable from another document. A `doctype Path;`
association remains separate and does not contribute artifact content unless
that document is also included. Root names must be unique across the complete
artifact document set.
