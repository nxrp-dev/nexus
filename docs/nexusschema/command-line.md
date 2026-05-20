# Command Line Flow

NexusSchema may eventually have command-line tooling, but this page should not document unreleased or obsolete private tools.

## Goal

Any command-line interface should be boring and scriptable.

The tool should be usable from:

- a clean command prompt
- a batch file
- a build script
- CI
- a local development workflow

## Expected shape

A future command-line tool should clearly separate input, target, and output.

Conceptually:

```text
nexusschema --input schema-file --target target-name --output output-folder
```

The final names do not matter yet. What matters is that they are explicit, stable, and easy to automate.

## Required behavior

A command-line tool should:

- return exit code `0` on success
- return a non-zero exit code on failure
- print useful failure text
- avoid machine-specific absolute paths
- allow all required paths to be passed in or discovered predictably
- support repeatable builds from a clean checkout

## Not yet finalized

The public command-line contract is not finalized.

Do not treat examples on this page as committed syntax. Once the tool interface is stable, this page should be replaced with exact runnable commands.