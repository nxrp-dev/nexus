# NexusScript Dialects

This directory is the shared catalog of production NexusScript language
definitions. Documents refer to a dialect by its portable path beneath this
directory, for example:

```nexusscript
dialect "Bot/Bot.Language.nxscript";
```

The compilation session first resolves a relative dialect beside the declaring
document, then beneath its configured `DialectRoot`. Absolute dialects retain
their exact-path behavior. The application or command-line entry point decides
how the root is supplied.

- `Language/` defines NexusScript language definitions themselves.
- `Bot/` defines NexusBot catalogs.
- `NexusManifest/` defines artifact manifests.
- `WorkspaceIndex/` defines Nexus workspace indexes.

Test-only dialects remain with the tests that own them. Runtime behavior and
Mustache templates remain with the tools that consume these shared contracts.
