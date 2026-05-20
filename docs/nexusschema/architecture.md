# NexusSchema Architecture

NexusSchema is a small compiler/generator pipeline.

The current implementation should be understood as a practical toolchain rather than a large language platform. Each stage has a clear job and should remain independently understandable.

## Pipeline

```text
command line
    -> metadata input file
    -> parser
    -> metadata model
    -> transformation pass
    -> XML export
    -> template execution
    -> generated files
```

## Command line layer

The compiler reads options through `TCommandLine`.

The command line currently supplies:

- `/metadata` for the primary metadata file
- `/output` for the output folder
- one template option per input extension, such as `/dpp` or `/csv`

The executable chooses the template by reading the metadata file extension and using that extension as a command-line key.

## Parser layer

`TDDLPPParser` parses the primary metadata file and writes results into `TMetaDataModuleList`.

The parser should stay responsible for language recognition only. It should not also become a template runner, database tool, or filesystem coordinator.

## Metadata model layer

The metadata model is represented by list/object units such as:

- `obMetaDataModuleList.pas`
- `obTableList.pas`
- `obFieldList.pas`
- `obForeignKeyList.pas`
- `obIndexList.pas`
- `obTemplateList.pas`
- `obAttributeSetList.pas`
- `obNameValueList.pas`
- `obNameList.pas`

These units form the compiler's internal schema representation.

## Transformation layer

`TMetaDataTransform` runs after parsing and before output.

This is the correct place for derived metadata, normalization, expansion, defaults, and other operations that should not be hard-coded into templates.

## XML export layer

The compiler saves the transformed metadata model to XML before template execution.

That XML is the bridge between the Pascal compiler code and the external template system.

## Template execution layer

The current implementation invokes FMPP and passes a `DDLPP` data-model binding into the template command line.

There are two execution shapes:

- whole-model template execution against the generated XML
- per-table or per-data-file template execution using the child data entries from `lMetaData.Data`

## Design boundary

Keep these jobs separate:

- parser reads language
- model stores facts
- transform derives facts
- XML exports facts
- template writes text
- database executes generated SQL

NexusSchema should not blur those boundaries unless there is a concrete reason.