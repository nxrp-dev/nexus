# Creating a schema-driven project

Use Forge with Schema-dialect documents and an Environment supplying the target
Mustache template. Start from `NexusLib/script/bothost/database/`, which includes
five related tables, Firebird key conventions, and a package declaring the generated
SQL artifact. See [NexusForge](../nexus-forge/index.md) for commands.

Keep maintained scripts in `NexusLib/script/`. Include aggregates table definitions;
module supplies reusable references/configuration. The Environment owns target
conventions. CSV preload generation is a separate CSV operation invoking nxcsv.
