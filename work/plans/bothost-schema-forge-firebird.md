# Work Plan: BotHost Database Through Schema and Forge

Status: Proposed for owner review; no implementation authorized.
Date: 2026-09-15

## Inputs

- Owner request: draft a work plan for a Firebird BotHost database, using Schema
  and preferably Forge to exercise the existing declarative generation system.
- Required domain: bots actually controlled by a host, their current status, and
  operation permissions for both those bots and the users making IQ requests.
- `git.patch` is the first concrete permission example. Patch execution and live
  database use are not needed yet.
- Keep the first pass small. Future SQLite/SQL Server support means room for new
  target definitions/templates, not implementing those engines now.
- Existing decisions: include aggregates definitions; module provides references
  and reusable configurations; ordinary composition supplies operation Template.
  Generic runtime must not infer tool semantics from arbitrary property names.
- The package-child execution-classification question remains deferred by the
  owner. This task does not redesign it.
- Repository architecture/work-plan protocols and applicable folder AGENTS.md
  apply. No sub-agents. Automatic archives remain paused.

## Summary

Create a small, useful BotHost schema and demonstrate the complete path:

```text
BotHost Schema documents
  -> target-selected NexusScript artifact manifest
  -> generic JSON and Firebird Mustache
  -> generated creation DDL (a Forge package artifact)
  -> disposable Firebird database and SQL verification
```

Forge orchestrates SQL generation through an ordinary native NexusScript command.
The database test applies that generated SQL using installed Firebird tooling.
This pass delivers schema and generation artifacts, plus proof they create a real
usable database. It does not deliver a production database service or IQ handler.

## Verified Findings

- `NexusTools/BotHost/src/tpNXBotControl.pas` defines list, status, invite, and
  dismiss operations. It has caller bare-JID/origin fields and bot status fields
  including Active, ProviderState, XMPPState, Diagnostic, and Rooms. There is no
  git-patch control operation in that contract.
- `obNXBotController.Authorized` currently uses configured Operators/Readers and
  specific verified-room rules. The proposed database does not replace those
  live rules during this task.
- `obNXXMPPBotControl.pas` registers IQ handlers for the existing operations and
  extracts the caller identity. Persisted authorization must ultimately use that
  verified identity, not a room nickname or a claimed identity in a command body.
- The shared `Schema.Language.nxscript` currently validates root Table definitions
  with TableName and Fields; Field supports Type and a Table Reference. It has
  no declared primary-key, required-field, or composite-unique-key vocabulary.
- The generic NexusScript emitter already supplies completed definition data and
  `_nx.Collections`; compiler tests cover included collections and schema-shaped
  Mustache generation. No Schema-specific compiler/JSON producer is needed.
- Existing schema-generation fixtures include legacy application-specific history,
  reporting tables, and Firebird conventions. Those templates cannot simply be
  applied to BotHost unchanged. Some fixture models lack a dialect declaration;
  successful rendering of those fixtures is not proof of validated Schema input.
- `NexusScript` supports artifact manifest rendering and `/validate`, but its CLI
  has no `/targets` flag. `TNexusScriptManifest.Render` creates both manifest and
  model compilation sessions without caller target selections. This is a concrete
  integration gap for target-selected database generation.
- Forge accepts explicit Targets and renders each completed operation's Template.
  Its shipped operation pieces currently cover FPC and Git, not NexusScript
  generation. A new operation definition/template can invoke NexusScript without
  adding a compiler-specific execution branch.
- Forge package readiness is artifact presence only. Declared artifact parents are
  prepared; arbitrary operation properties do not govern package readiness/layout.
- `C:/Program Files/Firebird/Firebird_5_0/` contains isql.exe and fbclient.dll.
  Neither isql nor isql-fb is on the inspected PATH. Installation presence does
  not establish a working test connection; no database was opened during planning.

## Architecture Problem

We need to prove that the existing generic language and execution machinery can
produce a useful database, while keeping three responsibilities distinct:

1. Schema declares tables, relationships, and constraints.
2. The manifest selects database-specific rendering through ordinary Targets.
3. Forge invokes the generator and verifies declared generated artifacts.

Firebird spelling belongs in selected definitions/templates. Neither the compiler
nor Forge gains a Firebird switch or a BotHost-specific producer. The necessary
changes are a small Schema contract extension, target propagation through artifact
rendering, and a declarative Forge operation for invoking the generator.

## Target Contract

### Ownership and status

Proposed initial tables, to be implemented as actual schema declarations:

| Table | Minimum content and purpose |
| --- | --- |
| BOT_HOST | ID and unique stable HostKey; identifies the controlling host. |
| OWNED_BOT | ID, HostID, catalog Name, BareJID, Enabled, Active, ProviderState, XMPPState, Diagnostic, UpdatedAt. Unique HostID + Name. |
| BOT_USER | ID, unique normalized BareJID, Enabled. A requester identity, not a stored login/password. |
| BOT_GRANT | BotID + OperationCode composite key. Row presence grants the bot that operation. |
| USER_BOT_GRANT | UserID + BotID + OperationCode composite key. Row presence grants that user the operation through that bot. |

The host owns bot registration. A channel occupant is not automatically an owned
bot. Room membership does not establish ownership or grant privileged operations.
Status is a current snapshot, not an event history. UpdatedAt describes when that
snapshot was recorded; a persisted Active value alone is not proof of live liveness.

Use primary keys, required identifiers, foreign keys, and the listed unique keys.
No cascaded history machinery, generated CRUD/provider layer, or implicit primary
key generator. Fixture IDs may be explicit; a live ID-allocation policy is deferred.

### Security demonstration

OperationCode is explicit data, initially `git.patch`; no new permission grammar.
For the demonstration query to allow a user-requested operation:

- the bot belongs to the specified controlling HostKey and is enabled;
- the requesting user is registered and enabled;
- BOT_GRANT contains the bot/operation pair;
- USER_BOT_GRANT contains the user/bot/operation combination.

Missing either grant means denied. Grant removal is revocation. No roles,
inheritance, wildcard grants, deny precedence, or implicit administrator bypass.
A bot's grant does not authorize an otherwise unauthorized human requester.

Demonstrate this with SQL and synthetic identities. This establishes the stored
policy contract only; a future IQ execution path must consult it before acting.
No claim that database rows alone enforce authorization in the current host.
Autonomous patch execution, repository/workspace scope rules, and new IQ protocol
payloads are outside this pass.

### Schema and Firebird rendering

Extend the existing shared Schema dialect only for constraints needed above:
required fields, explicit primary-key field lists, composite unique keys, and
foreign-key target fields where the existing Reference contract is insufficient.
Use ordinary properties, arrays, definitions, and references. Do not change parser
syntax, reference lookup, include aggregation, or generic JSON presentation.

The Field Type values may initially use the SQL types required by Firebird.
Do not claim these are already portable across all future engines. Backend type
mapping can be expressed by selected definition pieces/templates when another
engine is actually added; no type-mapping framework is required now.

Write a clean Firebird creation template consuming the generic compiled schema.
Generate tables before inter-table foreign keys so declaration order need not
solve dependency ordering. Do not carry over reporting/history tables from the
legacy application template. Include only essential seed/reference data, if any;
permission demonstration data belongs in test fixtures, not production grants.

### Manifest targets

Use `TargetDB[Firebird]` on the manifest's renderer definition. Illustrative shape:

```nexusscript
NexusManifest BotHostDatabase {
    Model Domain { Source: "BotHost.Schema.nxscript"; }
    Template CreateSchema TargetDB[Firebird] {
        Source: "templates/Firebird.create.mustache";
        Output: "BotHost.create.sql";
    }
}
```

The real document declares NexusManifest normally. Future backends add selected
renderer definitions; there is no engine-selection switch in Pascal runtime.
This pass supplies only the Firebird renderer. Unsupported selections must fail
rather than produce an empty successful build.

Add `/targets=Name:Value,...` to NexusScript using its existing target-selection
model and the established Forge CLI spelling. Pass one explicit selection set to
manifest compilation and each model session, including their normal dependencies
and dialect loading. Also support it consistently in direct input/template mode.
Omitting targets preserves existing callers; the BotHost package requires TargetDB
and restricts this first implementation to Firebird. Do not add implicit defaults
or change the meaning of an omitted target in the language.

Proposed generator command after implementation:

```text
NexusScript /manifest=BotHost.NexusManifest.nxscript /targets=TargetDB:Firebird /output=generated/Firebird /validate
```

### Forge integration and lifecycle

Add a `NexusScript.ForgeDef.nxscript` operation piece and a native command template.
Its explicit data describes the generator executable, artifact manifest, destination,
and forwarded target selections. These are operation-specific contract properties;
Forge's executor merely renders and launches the command.

Define one BotHost schema-generation package with TargetDB required and a named
SchemaSQL artifact at `generated/Firebird/BotHost.create.sql`. Supply executable
location and reusable command configuration through ordinary module composition.
The package/configuration explicitly forwards the selected database target to the
child generator; do not assume Forge targets automatically cross a process boundary.

Artifact-presence reuse remains unchanged. Verification starts with missing output
or an isolated directory; changing schema source alone does not invalidate an
existing generated SQL artifact. No hashing, freshness tracking, or readiness markers.

The disposable database belongs to the test fixture, not a production deployment.
Apply the generated DDL with isql and stop on SQL failure. Connection configuration
must be explicit, with no credentials in source control or printed command lines.
Do not install/reconfigure Firebird, modify security5.fdb, or touch existing databases.
Prove SQL application separately from file generation; a generated SQL file alone
is not acceptance of the database portion.

## Scope

- New BotHost-owned artifacts under `NexusTools/BotHost/database/`: Schema documents,
  artifact manifest, Firebird Mustache, Forge package/configuration, and short README.
- `NexusLib/script/dialects/Schema/Schema.Language.nxscript`: minimal constraint data.
- `NexusLib/script/dialects/NexusForge/pieces/NexusScript.ForgeDef.nxscript` and its
  reusable operation template/configuration in Forge examples.
- `NexusTools/Script/cli/obNexusScriptCommand.pas` and
  `artifact/obNexusScriptManifest.pas`: explicit target plumbing and affected callers.
- Existing NexusScript and Forge tests for these behaviors; new BotHost database
  tests registered with `NexusBotHostTestModule`, using the existing test host.
- Related current documentation and focused generation examples.

## Out Of Scope

- Live BotHost persistence, catalog replacement, database-backed IQ enforcement,
  git patch execution, and modifications to current Operators/Readers behavior.
- Room tracking, conversations/messages, operation queues, audit/history tables,
  credentials, roles, repository ACLs, migrations, upgrades, or a general ORM.
- SQLite/SQL Server implementation, cross-engine compatibility claims, engine
  discovery, Firebird installation, connection pools, or background workers.
- NexusTools/Schema legacy tool changes or restoration of its removed producer.
- Package execution classification, artifact freshness, or automatic archives.

## Staged Implementation Plan

1. Author the five-table model and the smallest needed Schema constraint vocabulary.
   Separate ownership/status from security where existing include/reference semantics
   permit it cleanly. Validate the combined schema and verify each table appears
   once in the generic collection. Reuse module/reference semantics as they stand.
2. Add and test target propagation through NexusScript CLI and artifact rendering.
   Prove the selected manifest renderer and selected model values receive the same
   target. A second synthetic renderer may test exclusion; it is not SQLite support.
3. Implement the Firebird DDL template and expected-output checks for columns,
   required fields, primary/unique keys, and foreign keys. Preserve existing schema
   fixtures and regression expectations except deliberate additive contract changes.
4. Add the declarative Forge generator operation and BotHost package. Exercise the
   real NexusScript executable, explicit target forwarding, artifact creation/reuse,
   invalid input, and child-process failure. Add no generator-specific runtime branch.
5. Register a BotHost database fixture that creates an isolated Firebird database,
   applies the generated DDL, inserts synthetic hosts/bots/users/grants, and verifies
   constraints, status round-trips, and the authorization query. Cleanup only that
   fixture's verified-owned files/database. If connection setup is unavailable,
   report that exact blocker and do not mark database acceptance complete.
6. Document the actual scripts, commands, target convention, known remaining gaps,
   and measured verification results. Remove resolved gap entries rather than
   keeping a growing list of resolved issues.

## Sub-Agent Delegation

Implementation remains local. The owner has not authorized sub-agent use.

## Verification Plan

- Build NexusScript CLI, NexusForge CLI, both console test projects, and the
  BotHost test module. Run the full NexusScript and Forge suites. Run the full
  language-server suite because shared Schema validation changes affect analysis.
- Register domain/native database tests with NexusBotHostTestModule and run the
  focused database suite through NexusTestHost. Do not launch unrelated live bot,
  network/provider, or patch-execution tests.
- Verify normal compile/validate/render behavior remains unchanged without targets;
  selected renderer/model values agree; malformed selections fail clearly; no
  matching renderer fails; a child generator's nonzero exit fails Forge.
- Validate the actual BotHost schema, not merely unvalidated synthetic models.
  Assert exactly the intended five tables and no legacy report/history structures.
- Apply generated SQL to Firebird, then inspect actual relations, columns, keys,
  and foreign keys. Reject duplicate bot names per host, duplicate identities and
  grants, invalid foreign keys, and null required identifiers.
- Verify permission cases: both grants allow; either grant absent denies; disabled
  bot/user denies; wrong controlling host, wrong bot, and unregistered user deny;
  removing a grant revokes access. Room presence alone supplies no permission.
- Store/read status without requiring a room association. Use synthetic names and
  a text value containing an apostrophe to verify SQL value handling in the fixture;
  do not introduce general seed-data interpolation or quietly rely on raw quoting.
- Verify a missing generated artifact builds and a present artifact reuses. A later
  database test always uses a fresh isolated database, not a stale file's presence.
- Focused source scan: no Firebird/BotHost branches in compiler/executor, no revived
  Schema producer, no inferred operation Output handling, and no live IQ changes.
- Record real totals and separate unrun or blocked native tests. No archive unless
  the owner explicitly requests another one.

Expected build entry points:

```text
lazbuild NexusTools/Script/NexusScript.lpi
lazbuild NexusTools/Script/tests/NexusScriptTests.lpi
lazbuild NexusTools/Script/ls/tests/NexusScriptLSTests.lpi
lazbuild NexusTools/Forge/NexusForge.lpi
lazbuild NexusTools/Forge/tests/NexusForgeTests.lpi
lazbuild NexusTools/BotHost/tests/NexusBotHostTestModule.lpi
```

Confirm executable/module output paths and test-host invocation from current
project files before running; do not create a separate BotHost test application.

## Risks And Questions

- The five-table model and direct per-user/per-bot grants are proposed first-pass
  choices, not a claim that the owner requested a complete security design.
- Firebird tools are installed, but a usable local connection has not been proven.
  Verify a disposable connection during implementation; discuss an actual blocker
  rather than guessing passwords or changing installation settings.
- Shared Schema is currently small. Add only the constraint vocabulary needed by
  this schema. If it requires a parser/model/presentation redesign, pause for owner
  discussion instead of expanding this work implicitly.
- Existing dialect discovery, inclusion, composition, and bounded references must
  be proved by the actual scripts. Pause before choosing a workaround or changing
  their semantics if the proposed authoring encounters a real conflict.
- Current room-based permissions for existing IQ operations remain unchanged.
  The demonstration's git.patch policy is deliberately not yet connected to them.

## Approval Gate

This request authorizes planning only. No implementation, builds, database creation,
service changes, or IQ/runtime changes begin until the owner explicitly authorizes
implementation. Only this work-plan artifact is committed/pushed for review under
repository protocol. Automatic archives remain paused.
