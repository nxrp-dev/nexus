# NexusSchema

NexusSchema is the schema/compiler side of the Nexus project family.

Its job is to keep schema intent in a small source format and generate the mechanical output from that intent. The current implementation lineage comes from `dppCompiler`, a Free Pascal console compiler that parses metadata input, transforms it into an internal metadata model, writes XML, then drives template-based generation.

## What it is for

NexusSchema exists to avoid hand-maintaining repetitive schema artifacts.

The practical targets are:

- schema definition files
- metadata parsing
- metadata transformation
- XML export
- template-driven output generation
- database creation scripts
- import scripts
- future code generation

## Current implementation shape

The current compiler project is a Lazarus / Free Pascal console program named `dppCompiler`.

The project file includes parser, list/model, transformation, XML, command-line, tokenizer, and utility units. The active run parameters show the intended generation flow:

```text
/dpp="firebird\DatabaseSchema.create.ftl" /csv="firebird\DatabaseImport.import.ftl" /output="output" /metadata="inForceMain.dpp"
```

This means a metadata file is selected with `/metadata`, output goes to `/output`, and template selection is keyed by source-file extension.

## Generation flow

At a high level:

1. Read command-line options.
2. Determine the metadata file extension.
3. Select the matching template from the command line.
4. Parse the metadata file into `TMetaDataModuleList`.
5. Transform the metadata model.
6. Save the transformed model as XML.
7. Run the matching template against the XML.
8. Process child data files listed in the metadata model.

## Relationship to NexusUI

NexusSchema is not part of NexusUI.

NexusUI is the retained-mode SDL-backed UI framework. NexusSchema is the schema/parser/generator toolchain. They live under the same Nexus documentation site because they are part of the same broader project family, but they should stay documented separately.

## Current priority

The useful next step is to stabilize NexusSchema around a clean executable pipeline:

```text
source metadata -> parser -> metadata model -> transform -> XML -> templates -> generated output
```

The implementation already has most of those pieces. The immediate work is mostly cleanup, naming, portability, and documentation of the actual source format.