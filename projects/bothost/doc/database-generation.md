# BotHost database generation

Run from the repository root:

```powershell
lazbuild projects\forge\NexusForge.lpi
& .\output\NexusForge\x86_64-win64\nxforge.exe `
  /input=projects\bothost\BotHost.Forge.nxscript /targets=TargetDB:Firebird
```

The Render task creates `generated/Firebird/BotHost.create.sql` on each run.
Generation runs inside Forge, using the shared NexusScript compiler, validator,
JSON emitter, and Mustache. It does not launch NexusScript.exe or connect to a DB.

## Files and conventions

- `projects/bothost/BotHost.Forge.nxscript`: Render task and output path.
- `projects/bothost/schema/BotHost.Schema.nxscript`: Schema dialect declaration and `*.Table.nxscript` include.
- `projects/bothost/schema/`: five tables; modules retain reference dependencies without adding extra tables.
- `projects/bothost/config/Environments.nxscript`: Firebird target and naming/type/generation constants.
- `projects/bothost/templates/firebird/Firebird.create.mustache`: tables, single-column primary keys, sequences,
  insert triggers, and ordinary single-column foreign keys, emitted after all tables.
- Owned dialects: `projects/schema/language/Schema.Language.nxscript` and
  `projects/forge/language/Forge.nxscript`, including
  `projects/forge/language/definitions/Render.ForgeDef.nxscript`.

The Environment is the convention authority. Normal composition can override its
values. Physical SQL names derive consistently from TableName, not definition names.
The template supplies trigger-based generation; it introduces no compiler defaults.
The older Schema example constants remain at
`projects/schema/examples/constants/Firebird.Constants.nxscript`;
this task uses its own Environment, not that legacy configuration.

## Stored data and scope

BOT_HOST identifies a controlling host. OWNED_BOT records bots that host actually
controls, their enabled state, and a current status snapshot. No channel membership
is required. UPDATED_AT timestamps the snapshot; ACTIVE is not proof of present
liveness. BOT_USER represents a requester, not a password record.

BOT_GRANT authorizes a bot for an operation. USER_BOT_GRANT authorizes a user to
request that operation through that bot. The demonstration uses `git.patch`.
Allow only when the selected bot belongs to the specified host, both bot and user
are enabled, and both matching grants exist. Existence checks tolerate duplicate
grants without multiplying decisions. Revocation removes all matching grant rows.

Every table, including grant tables, has its own generated single-column primary
key. Composite primary/foreign keys are prohibited. Index/uniqueness extensions
are deferred; names, JIDs, and grant combinations are not promised unique.
The fixture uses explicit synthetic IDs. Live IQ authorization, identity lookup,
persistence, and patch execution are outside this pass.

## Native verification

```powershell
lazbuild projects\bothost\test\NexusBotHostTestModule.lpi
$env:NEXUS_FIREBIRD_ISQL = 'C:\Program Files\Firebird\Firebird_5_0\isql.exe'
& .\output\NexusTestHost\nxtest_host.exe `
  .\output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
  run-test NexusBotHost.Database.Firebird
```

Run from the repository root. The registered test uses local embedded Firebird
with the explicit SYSDBA user and no password. It creates only uniquely named
fixture databases under `output/BotHostDatabaseVerification`, applies the generated
DDL, and drops those databases. Scripts/logs remain there for inspection. It does
not alter Firebird configuration, services, credentials, or existing databases.
On this machine Firebird's OS access requires running outside the execution sandbox.

The test exercises both standard and overridden key suffixes, generated SQL,
five tables, generated keys, invalid primary/foreign
keys, status text including an apostrophe, missing/either/both grants, disabled
users/bots, wrong host/bot, unknown user, duplicate grants, and revocation.
`projects/bothost/test/fixtures/database/assertions.sql` contains the SQL checks. Its view and
exception are test-only and are never emitted into the generated artifact.

Verified 2026-09-15 with installed Firebird 5: registered test passed; both disposable
databases were dropped. Generic Forge and compiler regression results are recorded
in `projects/forge/doc/contracts.md`.
