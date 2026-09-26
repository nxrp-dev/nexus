# Creating a schema-driven project

Use Forge with Schema-dialect documents and an Environment supplying the target
Mustache template. Start from `projects/bothost/BotHost.ForgePackage.nxscript`,
with five related tables under `projects/bothost/schema/`, Firebird key conventions
under `projects/bothost/config/`, and a template under `projects/bothost/templates/`.
See [NexusForge](../nexus-forge/index.md) for commands.

Keep schemas, configuration, and templates with their owning product. The Schema
include aggregates table definitions; modules supply reusable references. The
Environment owns target conventions. CSV preload generation is a separate CSV
operation invoking nxcsv.
