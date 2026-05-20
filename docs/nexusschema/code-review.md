# Code Review Notes

These notes are based on the current `dppCompiler` project structure and entry point.

## Keep

### The pipeline is understandable

The compiler has a clear pipeline:

```text
metadata file -> parser -> metadata model -> transform -> XML -> template output
```

That is the right basic shape. Keep it.

### The model is separated from output

The parser writes to metadata objects. Output is delegated through XML and templates. That is better than embedding Firebird, CSV, or Pascal output directly in the parser.

### Transform has a real place

`TMetaDataTransform` exists as a dedicated stage. That is where normalization and derived metadata should live.

## Fix soon

### Make the FMPP path configurable

Current code directly calls:

```text
c:\fmpp\bin\fmpp.bat
```

That should become one of:

- `/fmpp=...`
- environment lookup
- config file value
- local tools folder convention
- path lookup through the shell

The compiler should not require one developer-specific absolute path.

### Create `TCommandLine` once

The main program creates `TCommandLine`, prints it, then `CompileScripts` creates a second `TCommandLine` instance.

Better shape:

```text
main creates command line
main passes command line into compiler runner
runner uses that instance
```

That removes duplicated parsing and makes startup behavior easier to reason about.

### Remove unused `TStringList`

The main block creates `lCreateFile : TStringList`, but the shown entry point does not use it.

Remove it unless a later version actually needs it.

### Return a failing exit code

The main exception handler prints the exception message, but the process should also return failure.

Batch files, CI, and deployment scripts need an executable signal, not just text.

Expected behavior:

```text
success -> exit code 0
failure -> non-zero exit code
```

### Fix user-facing spelling

The current startup/shutdown messages contain typos:

```text
ddpCompiler
sucessfuly
```

Use the executable/project spelling consistently:

```text
dppCompiler
successfully
```

## Design cleanup

### Introduce a compiler runner object

The entry point can become very small if the pipeline moves into an object.

Potential shape:

```text
TNexusSchemaCompiler
  CommandLine
  MetaData
  Parser
  Execute
```

The goal is not abstraction for its own sake. The goal is to keep process startup separate from compiler behavior.

### Keep filesystem coordination out of the parser

The parser should not decide output paths, template paths, or external process execution. The current code mostly respects that. Preserve the boundary.

### Keep template selection boring

Extension-based template lookup is fine for now.

Do not complicate it until there is a real need for multiple target profiles, database backends, or per-module overrides.

## Documentation gaps

The docs still need source-format examples once the `.dpp` syntax is stable enough to document directly.

Needed examples:

- smallest valid metadata file
- table definition
- field definition
- foreign key definition
- index definition
- template reference
- child data file reference
- full input-to-output example

## Review conclusion

The current direction is sound.

The biggest immediate risk is not architecture. It is local-machine coupling. Remove hard-coded external paths, make failure observable through exit codes, and document the source language with runnable examples.