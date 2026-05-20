# Command Line Flow

NexusSchema currently runs as a Free Pascal console compiler.

The executable is named `dppCompiler` in the Lazarus project file.

## Current run shape

The known local run parameters are:

```text
/dpp="firebird\DatabaseSchema.create.ftl" /csv="firebird\DatabaseImport.import.ftl" /output="output" /metadata="inForceMain.dpp"
```

That gives the compiler four pieces of information:

- the primary metadata file
- the output folder
- the template to use for `.dpp` input
- the template to use for `.csv` input

## Template lookup rule

The compiler gets the input file extension and uses it as a command-line key.

Example:

```text
metadata file: inForceMain.dpp
extension:     dpp
template key:  /dpp
```

For child data files, the same rule applies. A `.csv` child file uses the `/csv` template.

## Output naming rule

The output filename is based on the input filename and the template extension.

Conceptually:

```text
output folder + input base name + template-derived extension
```

The compiler also writes an XML version of the transformed metadata model beside the generated output.

## Execution stages

```text
read command line
find metadata file
find template for metadata extension
parse metadata
transform metadata
save XML
run whole-model template
loop child data files
run extension-matched template for each child file
```

## Current external dependency

Template execution currently calls FMPP through a batch file.

The current code uses this path directly:

```text
c:\fmpp\bin\fmpp.bat
```

That works on the original development machine, but it should eventually become a command-line option, config value, environment lookup, or tool-discovery rule.

## Failure behavior

The process wrapper raises an exception when FMPP returns a non-zero exit status.

The main program catches exceptions and prints the error message. A future cleanup should also set a non-zero process exit code so batch files and CI can detect failure.