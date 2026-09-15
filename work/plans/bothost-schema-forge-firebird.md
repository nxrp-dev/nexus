# Work Plan: BotHost Database Through Schema and Forge

Status: Revised for owner review; no implementation authorized.
Date: 2026-09-15

## Inputs

- Owner request: use the BotHost database as real work demonstrating Schema/Forge
  scripting, targeting Firebird with room for other database environments later.
- Required data: bots actually controlled by a host, current status, and operation
  permissions for both bots and users requesting operations through IQ commands.
- `git.patch` is the first permission example. Live persistence and patch execution
  are not needed in this pass.
- Owner clarification: Forge is the intended front end. NexusBuild, NexusTask,
  and NexusScript remain while their behavior is accounted for; their current
  executable boundaries are not requirements for the future architecture.
- Owner clarification: an Environment supplies the database template and standards,
  including primary-key naming, SQL type, and generation conventions. Ordinary
  composition can override an environment configuration when needed.
- Owner clarification: indexes, unique constraints, and broader constraint
  vocabulary are deferred. Primary keys already follow conventions; do not replace
  those with mandatory explicit per-table key declarations.
- Owner rule: never use composite primary or foreign keys. Every table, including
  join/grant tables, has its own single-column primary key. Composite indexes are
  a separate concept and remain deferred in this pass.
- Include aggregates definitions; module supplies references/configuration;
  ordinary composition supplies completed values. Generic runtime must not infer
  tool semantics from arbitrary properties.
- Package-child execution classification remains deferred until a real case needs
  it. No sub-agents. Automatic archives remain paused.
- Repository architecture/work-plan protocols and applicable AGENTS.md apply.

## Summary

Build a small BotHost schema and prove this path:

```text
Forge package + selected Environment
  -> compile and validate Schema documents
  -> render their generic JSON with the Environment's Mustache template
  -> generated Firebird creation SQL, declared as a package artifact
  -> disposable Firebird database and verification
```

Forge owns the user-facing workflow. Reuse the existing compiler, validator, JSON
emitter, and Mustache implementation directly. Do not require NexusScript.exe as
an intermediate command, extend its CLI for this task, or create a second database
selection mechanism in a NexusScript artifact manifest.

This delivers generation artifacts and proof of a usable database, not a live
BotHost database service. Existing tools stay in place; this is one concrete step
toward Forge consolidation, not a wholesale migration or deletion of them.

## Verified Findings

- `tpNXBotControl.pas` defines list/status/invite/dismiss operations, verified caller
  identity inputs, and current bot status. It has no git-patch control operation.
- `obNXBotController.Authorized` uses configured Operators/Readers and specific
  verified-room rules. Those live rules are unchanged by this demonstration.
- The shared Schema dialect declares TableName, Fields, field Type, and Table
  Reference. The absence of explicit constraint properties does not mean the old
  generation path had no constraints: its template implements conventions.
- The existing Firebird constants are MODULE_POSTFIX, MODULE_ID_POSTFIX,
  GENERATOR_PREFIX, and NEXUS_SCHEMA_PRIMARY_KEY_TYPE. The legacy template derives
  primary-key names, emits NOT NULL/primary keys, and creates generators and insert
  triggers. It also includes application-specific reporting/history behavior that
  does not belong in the BotHost schema.
- The old template uses definition-name metadata as its table-name base. The
  current validated Schema contract separately exposes TableName. This example
  must consistently use TableName for physical SQL names and reference targets;
  do not accidentally alternate between logical definition names and TableName.
- Generic JSON and included-definition collections already support Schema-shaped
  rendering. No Schema-specific compiler or JSON producer is required.
- Forge already supports target-selected environments and composed Template values,
  but currently renders native command lines. It does not yet expose direct
  compile/validate/render-to-file execution as a Forge operation.
- Existing artifact-rendering code is reusable implementation material, not a
  requirement to preserve the separate NexusScript CLI/manifest workflow.
- Package readiness is declared artifact presence. Declared artifact parents are
  prepared, without inferring semantics from arbitrary operation Output properties.
- Firebird 5 is installed under `C:/Program Files/Firebird/Firebird_5_0/`, including
  isql.exe and fbclient.dll. A working disposable connection has not been verified.

## Architecture Problem

The missing capability is generic artifact generation inside Forge. Preserve the
separation of responsibilities while putting them behind that front end:

- Schema documents describe tables and fields.
- The selected Environment supplies rendering and primary-key standards.
- A declared generation operation compiles its source, validates it, and renders
  a file through shared language/artifact facilities.
- Package coordination checks the explicitly declared generated artifact.

The renderer does not understand primary keys, Firebird, or bots. Those meanings
belong to the definitions and template. Rendering SQL to a file must be an explicit
operation behavior; do not render it and accidentally send it to a process launcher.

## Target Contract

### Environment and primary-key conventions

Use normal Forge target selection and ordinary module/reference/composition rules.
A shared configuration document (the manifest/configuration in this workflow)
contains the Environment; it is not a second independently selected process catalog.

Illustrative Environment using existing constant names:

```nexusscript
Environment Firebird TargetDB[Firebird] {
    Template: "templates/Firebird.create.mustache";
    MODULE_POSTFIX: "_TBL";
    MODULE_ID_POSTFIX: "_ID";
    GENERATOR_PREFIX: "GEN_";
    NEXUS_SCHEMA_PRIMARY_KEY_TYPE: "BIGINT";
}
```

The actual document declares its normal dialect and is imported as a module.
The operation explicitly references this Environment and its Template. The resolved
Environment values must be available to that template as explicit render input;
merely loading a module must not inject all its definitions into the render context.
Use one named Environment context alongside the source model's generic JSON,
rejecting a name collision rather than silently replacing source data.

For this example, the convention is:

- Physical table: TableName + MODULE_POSTFIX.
- Primary-key column: TableName + MODULE_ID_POSTFIX.
- Primary-key type: NEXUS_SCHEMA_PRIMARY_KEY_TYPE.
- Generator: GENERATOR_PREFIX + the derived primary-key column name.
- The selected Firebird template supplies the corresponding insert trigger and
  creates the primary key with the existing non-null convention.
- Reference rendering uses the referenced table's same TableName and Environment
  conventions, so declaration and reference cannot disagree.

Every table, including permission and join tables, gets its own conventional
single-column generated primary key. Foreign keys reference that single column.
Composite primary and foreign keys are prohibited, not a deferred option.
Do not explicitly duplicate that key in Fields. BIGINT is the example Environment
value; it avoids depending on an undeclared legacy DOM_INDEX domain. Neither that
value nor the naming suffixes are runtime defaults.

An explicitly composed Environment may override constants or Template using normal
language behavior. Prove an override of the key suffix, including matching foreign
references. There is no per-table override system, key-policy callback, or new
configuration framework in this pass.

Only Firebird is implemented. Another backend can later supply an Environment and
Mustache implementation without adding engine branches to Forge. Do not claim the
initial SQL type choices are already portable across SQLite and SQL Server.

### Ownership, status, and security data

Proposed initial tables; each receives its conventional primary key:

| TableName | Additional fields and purpose |
| --- | --- |
| BOT_HOST | HostKey; identifies the controlling host. |
| OWNED_BOT | Host reference, catalog Name, BareJID, Enabled, Active, ProviderState, XMPPState, Diagnostic, UpdatedAt. |
| BOT_USER | Normalized BareJID and Enabled; requester identity, not a password record. |
| BOT_GRANT | Bot reference and OperationCode; row presence grants that bot the operation. |
| USER_BOT_GRANT | User reference, Bot reference, and OperationCode; grants that user the operation through that bot. |

A channel occupant is not automatically a registered owned bot. Room membership
establishes neither ownership nor privileged permission. Status is a current
snapshot, not an event history; its timestamp does not prove live liveness.

The demonstration uses explicit fixture identities and primary-key relationships.
It does not promise database-enforced uniqueness of HostKey, BareJID, bot names,
or grant combinations. Those indexes/constraints are deferred. Use existence-based
permission checks so duplicate grant rows do not multiply results. Revocation
removes all grants for the selected relationship. Do not build deduplication or
identity-resolution infrastructure to compensate for the deferred constraints.

For a user-requested `git.patch` demonstration, require all of:

- the selected bot belongs to the specified host and is enabled;
- the selected user is registered and enabled;
- a matching BOT_GRANT exists;
- a matching USER_BOT_GRANT exists for that user, bot, and operation.

Missing either grant denies the operation. A bot's grant does not authorize an
otherwise unauthorized human. No roles, wildcard grants, deny precedence, or
administrator bypass. Use SQL and synthetic identities to demonstrate the stored
policy. The future IQ handler must supply verified identities and enforce the
check; this task does not connect it or execute patches.

### Schema and template

Use the existing Schema vocabulary and conventional key/reference behavior.
Do not add index lists, unique-key declarations, explicit primary-key lists,
required-field vocabulary, or general constraint validation in this pass.

Create a clean Firebird template consuming generic model data plus the explicit
Environment input. Emit tables before foreign keys. Implement ordinary existing
Table references against convention-derived keys; no composite-reference model.
Carry over neither legacy reporting/history tables nor unrelated generators.

Separate ownership/status and security declarations where existing inclusion and
references permit clean authoring. Verify each table appears once in the combined
collection. Keep parser, lookup, include, and JSON semantics unchanged. If a real
incompatibility prevents this, pause to discuss it rather than inventing a workaround.

### Forge integration and lifecycle

Add one small, explicitly declared generic file-generation operation to Forge.
Working name: Render. Its contract describes Source, destination Output, Template,
and the explicit Environment render input. This is proposed operation vocabulary,
not new NexusScript syntax or a hierarchy of operation classes.

For Render, Template is the artifact template, not a native command template.
The declared Render operation selects compile/validate/render-to-file behavior;
ordinary FPC/Git commands keep their existing execution path. Do not select the
behavior by file extension, property presence, or rendered text. This adds one
concrete execution capability without reopening package-child classification.

Reuse the existing compilation/session, validation, generic JSON, and Mustache
code in-process. Extract or share only the small artifact functionality needed;
do not duplicate the compiler or import a CLI program as a runtime dependency.
Forward the current package request's target selections into the source compilation
session, including its normal dependencies/dialect processing. Standalone Render
uses the current Forge invocation selections. This is API plumbing under Forge,
not a required new NexusScript command-line switch.

Relative Source and inherited Template paths retain their declaring-source context;
package artifact Output resolves from the package root. Document and test those
specific contracts so moving configuration into a module does not change its paths.
Diagnostics identify the operation/source/template and actual failure. A compilation,
validation, or rendering failure stops subsequent operations. Preflight preparation
must preserve the existing guarantee that a later preparation failure does not
allow earlier commands to run; artifact writes are execution effects, not preflight.

Define a BotHost generation package with TargetDB required, initially restricted
to Firebird, and a named SchemaSQL artifact at generated/Firebird/BotHost.create.sql.
Its Render operation references that artifact Path and the selected Environment.
There is one target selection authority. No parallel manifest renderer selection,
separate generator executable setting, or automatic subprocess target forwarding.

Keep presence-only reuse. Fresh verification uses absent generated artifacts;
source changes alone do not request rebuilding. Output-file semantics belong to
Render's declared contract, never to arbitrary operations with an Output property.

A registered database fixture applies the generated SQL with installed Firebird
isql to a fresh isolated database. Explicit connection configuration; no credentials
in tracked files or printed command lines. Do not alter services, installation,
security5.fdb, or existing databases. A generated SQL file alone does not complete
native database acceptance.

## Scope

- `NexusTools/BotHost/database/`: Schema documents, shared Environment configuration,
  Firebird Mustache, Forge package, and concise usage instructions.
- A minimal `Render.ForgeDef.nxscript` piece and Forge's generic artifact execution
  integration alongside its native command path.
- Existing shared compilation/artifact APIs as needed for in-process reuse and
  explicit target/context propagation; affected callers only.
- NexusScript and Forge regression tests; BotHost database tests registered with
  NexusBotHostTestModule and run through the existing test host.
- Current documentation for these contracts and measured results.

## Out Of Scope

- Indexes, unique constraints, broad constraint vocabulary, and per-table
  primary-key overrides. Composite primary/foreign keys are prohibited outright.
- Live database persistence, catalog replacement, IQ changes, git patch execution,
  and modifications to existing Operators/Readers behavior.
- Room/conversation history, operation queues, audit tables, roles, repository ACLs,
  migrations, ORM/provider generation, and credential storage.
- SQLite/SQL Server implementation, engine discovery, Firebird installation,
  connection pools, background workers, and variant freshness tracking.
- Wholesale NexusBuild/NexusTask/NexusScript migration/removal, expansion of their
  standalone CLIs for this task, and restoration of a Schema-specific producer.
- Package-child execution classification and automatic archives.

## Staged Implementation Plan

1. Author the five-table Schema and shared Firebird Environment using existing
   conventions. Validate included model data and explicit Environment composition.
   Establish the exact normal reference paths before writing the final template.
2. Add the minimal generic Render contract/path under Forge. Reuse language/artifact
   code directly, pass explicit targets and Environment data, preserve provenance,
   and distinguish preparation from artifact-writing execution.
3. Author the clean Firebird template and the BotHost generation package. Verify
   Environment-driven naming/type/generation, consistent reference names, normal
   composition overrides, and no legacy application-specific output.
4. Exercise the real Forge front end to generate SQL and verify artifact reuse.
   Test failures and mixed native-command/render ordering without changing the
   existing package-child classification contract.
5. Register/run the disposable Firebird fixture. Verify generated keys, ordinary
   foreign keys, status round-trips, and both-sided grant queries. If a connection
   is unavailable, report that exact blocker; do not claim native acceptance.
6. Update documentation with the actual scripts and results. Remove resolved gap
   items rather than appending resolved annotations. No archive without a request.

## Sub-Agent Delegation

Implementation remains local. No sub-agent use is authorized.

## Verification Plan

- Build Forge CLI/tests, the existing NexusScript CLI/tests to verify shared-code
  integration, and the BotHost test module. Run full Forge and compiler suites;
  run the language-server suite for shared compilation/validation/context changes.
- Run focused BotHost database tests through NexusTestHost; do not launch unrelated
  live provider/network tests or patch operations. No separate BotHost test app.
- Prove Forge invokes shared generation code without requiring NexusScript.exe.
  Check target-selected Environment, source-model target propagation, inherited
  template origin, composed overrides, and explicit render context without collisions.
- Use a second synthetic Environment to prove selection/exclusion without claiming
  another database implementation. Unsupported package selections fail clearly.
- Verify exactly five tables. Check convention-derived key names/types/generators,
  key non-null behavior, and foreign-key names after an Environment suffix override.
  Compare logical definition names differing from TableName to catch accidental mixing.
- Apply DDL to a fresh Firebird database. Insert a row without explicitly providing
  its primary key and verify generation. Reject duplicate primary keys and invalid
  conventional foreign keys. Do not require deferred uniqueness/index behavior.
- Verify both grants allow; either absent denies; disabled bot/user, wrong host,
  wrong bot, and unknown user deny. Duplicate matching grants still yield one Boolean
  decision, and removing the matching grants revokes it.
- Store/read status without a room. Use synthetic text including an apostrophe in
  database fixtures with proper SQL value handling; no general seed-data importer.
- Verify compile/validation/render failure stops later work, preparation failures
  launch/write nothing, a missing output builds, and a present output reuses.
- Confirm no Firebird/BotHost semantics or primary-key defaults in generic runtime,
  no inferred OutputDirectory behavior, and no changes to live IQ authorization.
- Record actual totals, heap results, and any blocked native checks. Only fixture-owned
  databases/files may be cleaned up; no service or installation changes.

Build entry points remain the existing Forge, NexusScript, language-server test,
and NexusBotHostTestModule projects. Confirm current output paths and NexusTestHost
suite selection before executing. No builds/tests were run for this plan revision.

## Risks And Questions

- The five-table/direct-grant model remains the proposed minimal domain design.
  This demonstration is not a completed production security integration.
- Firebird tools are installed; disposable connection access is still unverified.
  Discuss an actual connection blocker instead of guessing credentials or changing
  the installation.
- Bringing artifact generation into Forge requires one real generic execution
  capability. Keep that change bounded; do not turn it into an operation framework
  or a broad consolidation project.
- If existing reference, include, composition, or presentation rules prevent the
  intended script, pause for owner discussion before changing those semantics.

## Approval Gate

This revision authorizes planning only. Only this plan is committed/pushed under
repository protocol. Implementation, builds, database creation, and runtime changes
wait for explicit owner authorization. Automatic archives remain paused.
