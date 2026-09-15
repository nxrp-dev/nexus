# Common script library

This is the single source for maintained Nexus scripts, dialects, environments,
and Mustache templates. Tools reference these files; do not keep working copies
beside tool implementations. Test-only and deliberately invalid fixtures remain
with their test suites. Generated outputs are not script-library inputs.

| Location | Purpose |
| --- | --- |
| `dialects/` | Shared language definitions, including Forge operation pieces |
| `bothost/Bots.nxscript` | Bot catalog example |
| `bothost/database/` | BotHost schema, Firebird Environment, template, and Forge package |
| `tools/CSV/` | CSV compiler configuration, command template, and explicit SQL output template |
| `examples/csv/` | Real lookup-file generation through Forge and nxcsv |
| `examples/forge/` | FPC/Git and PasBuild translation examples |
| `examples/schema/` | Existing inForce/Storm NexusScript models, constants, and templates |
| `data/lookup/` | Lookup datasets retained from the retired Schema tool |
| `tasks/` | Maintained Nexus build/deployment task scripts |

NexusSchema's executable, old parser/model/transformation code, and old `.nxs`
inputs are retired. The maintained inForce/Storm models and adapted templates
are in `examples/schema/`; old versions remain available in Git history.
The schema example's `data/` files are explicitly synthetic demonstration data,
not recovered production datasets. Existing NexusManifest examples remain supported
by NexusScript; new CSV work uses the ordinary Forge CSV compiler operation.

For current generation entry points, see
[BotHost database](bothost/database/README.md) and
[NexusCSV](../../NexusTools/CSV/README.md).
