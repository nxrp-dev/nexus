# Nexus Schema Command Line

`NexusSchema.exe` is a console program. Its command-line parser accepts switches that start with `-` or `/` and use `name=value` pairs.

## Required Switches

The current program expects these values:

| Switch | Meaning |
| --- | --- |
| `metadata` | Path to the `.nxs` schema file to parse. |
| `Output` | Output folder. |
| input extension switch | Template file for that input extension, such as `nxs`, `csv`, `tsv`, `tab`, or `jcsv`. |

The extension switch is looked up from the input file extension without the dot. A `.nxs` metadata file therefore needs `-nxs=...`.

## Basic Example

```powershell
.\NexusSchema.exe -metadata=StormSpecific.nxs -nxs=firebird\DatabaseSchema.create.mustache -Output=output
```

This parses `StormSpecific.nxs`, renders it with `DatabaseSchema.create.mustache`, and writes an output file named `StormSpecific.create` under `output`.

## Data Import Example

If the schema references CSV data files, pass a CSV template too:

```powershell
.\NexusSchema.exe -metadata=inForceMain.nxs -nxs=firebird\DatabaseSchema.create.mustache -csv=firebird\DatabaseImport.import.mustache -Output=output
```

The data file extension selects the matching template switch. Supported delimited data extensions in the current code are:

| Extension | Delimiter |
| --- | --- |
| `csv` | comma |
| `jcsv` | comma |
| `tsv` | tab |
| `tab` | tab |

## Output Naming

The tool derives each output filename from:

- the input file basename
- the extension embedded in the template name before `.mustache`
- the `Output` folder

For example:

| Input | Template | Output |
| --- | --- | --- |
| `StormSpecific.nxs` | `DatabaseSchema.create.mustache` | `StormSpecific.create` |
| `STATE.csv` | `DatabaseImport.import.mustache` | `STATE.import` |

For `.nxs` metadata input, the tool also writes an intermediate `.schema.json` file next to the final output.

## Exit Behavior

The program prints the parsed switch values, runs the compile/render flow, and prints a success message when it completes. Exceptions are caught and printed to standard output. The current source does not explicitly set a non-zero process exit code on failure.
