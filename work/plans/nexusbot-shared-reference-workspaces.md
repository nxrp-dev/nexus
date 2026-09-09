# Work Plan: NexusBot Shared Reference Workspaces

## Inputs

- Source request: `C:\Users\kcollins\Downloads\nexusbot-shared-reference-workspaces-workplan-request.md`.
- Current BotHost catalog, runtime, controller, provider, OpenAI protocol, configuration, and registered tests.
- Official OpenAI [Shell documentation](https://developers.openai.com/api/docs/guides/tools-shell).
- Repository and BotHost agent instructions.

## Summary

Add provider-neutral workspace declarations to the Bot dialect. At BotHost startup, prepare one shared Git checkout for each referenced workspace and create each assigned bot's cache directory. Pass the resulting repository path, cache path, and resolved commit to OpenAI bots.

Extend the existing RTTI-based Responses model and `TNXOpenAIProvider.ProcessPrompt` so the current OpenAI worker can execute local `shell_call` commands and return typed `shell_call_output` items until the same prompt produces its final assistant response.

No hosted OpenAI container, additional thread, generalized workspace service, provider framework, or filesystem sandbox is part of this work.

## Verified Findings

- `Bot.Language.nxscript` currently defines only `Bot` with `Provider`, `Model`, and `Instructions`.
- NexusScript already supports inline definitions in arrays and arrays of references constrained to a definition kind; no compiler or grammar change is needed.
- A catalog uses one root definition. References resolve bottom-up from their containing definition, so a bot nested under `NexusBots.Bots` addresses the sibling workspace collection as `@NexusBots.Workspaces.Nexus`.
- `TNXBotCatalog.Load` already builds and validates an unpublished candidate before replacing the published catalog.
- `TNXBotHostRuntime.Start` is the existing point before provider startup, XMPP connection, and room join.
- `TNXBotController` owns the catalog and creates both the initial and subsequently summoned hosts.
- `TNXBotHost` creates its provider through `TNXBotProviderRegistry`; workspace routing does not require provider selection changes.
- `TNXOpenAIProvider` already owns one worker for blocking HTTP work and one active prompt at a time.
- `ProcessPrompt` currently expects every successful Response to contain final assistant text.
- `obNXOpenAIResponses.pas` uses RTTI/published-property classes. Its request input is currently message-only, and its response output dispatcher recognizes messages but not `shell_call`.
- Official OpenAI documentation defines local shell using typed `shell_call` and `shell_call_output` items with command, timeout/output, stdout/stderr, and exit/timeout fields.
- Existing Nexus process use employs `TProcess.Executable` and separately appended parameters. No general process abstraction needs to be introduced.
- All BotHost tests are registered through `NexusBotHostTestModule`.

## Architecture Problem

The catalog cannot currently describe workspaces, BotHost has no startup step that prepares a shared checkout, and OpenAI Responses cannot continue an active prompt through a local-shell request.

These are three parts of one narrow flow:

```text
catalog workspace reference
    -> startup Git checkout and bot cache
    -> workspace paths supplied to OpenAI
    -> local shell continuation on the existing provider worker
```

## Target Contract

### NexusScript

Add this deployed shape:

```nexusscript
BotCatalog NexusBots {
    Workspaces: [
        Workspace Nexus {
            Purpose: "Shared reference copy of the Nexus source tree.";
            SourceType: Git;
            Source: "https://github.com/nxrp-dev/nexus.git";
            Ref: main;
            Location: "/srv/nexus/workspaces/nexus";
        }
    ];
    Bots: [
        Bot Reviewer {
            Provider: OpenAI;
            Model: gpt-5.6-luna;
            Instructions: "...";
            Workspaces: [@NexusBots.Workspaces.Nexus];
        }
    ];
}
```

- `BotCatalog` is the document's single root definition.
- `Workspaces` and `Bots` contain named inline `Workspace` and `Bot` definitions.
- `Purpose` and `Ref` are optional text.
- `SourceType`, `Source`, and `Location` are required text.
- Initially, `SourceType` accepts only `Git`.
- `Location` is the explicit absolute workspace root; it is not derived from the workspace name.
- `Bot.Workspaces` is an optional array of references to `Workspace` definitions and supports zero, one, or many entries.
- Invalid definitions and references fail the normal candidate catalog load.
- Catalog validation performs no filesystem, Git, or network work.

### Catalog and runtime data

- Extract workspace and bot entries from the single compiled `BotCatalog` root's `Workspaces` and `Bots` arrays.
- Extend the catalog candidate with workspace entries containing name, purpose, source type, source, optional ref, and location, and each bot entry with its compiled workspace references.
- Publish bot and workspace entries together only after the complete candidate validates.
- Add a small runtime workspace record containing logical name, purpose, repository path, bot cache path, and resolved commit.
- Pass an owned list of those records through the host configuration to the OpenAI provider. The list is runtime data and is not a published JSON configuration property.
- Preserve workspace order. For multiple workspaces, give the model every repository, cache, and commit explicitly using absolute paths. Do not choose a current workspace or privilege the first entry.

### Startup preparation

`TNXBotHostRuntime.Start` asks the controller to prepare every distinct referenced workspace before starting any provider.

For each workspace:

1. Create `Location` when necessary.
2. Create or verify `<Location>/repo` as a checkout of `Source`.
3. Fetch the configured `Ref`, or the remote default when `Ref` is absent.
4. Resolve and check out the exact commit.
5. Record the resolved commit for the current BotHost run.
6. Create `<Location>/botcache/<BotName>` for each assigned bot.

Trusted Git commands use `TProcess` with `git` as the executable and configuration values as individual arguments. They are not assembled into shell command strings.

Any preparation failure aborts startup before providers accept prompts. It does not alter the valid logical catalog. Preparation occurs only once per BotHost run; there is no refresh thread, timer, polling, or live branch tracking.

The controller retains the prepared workspace records so later summoned bots receive the same repository path and resolved commit as the initial bot.

### OpenAI local shell

Only OpenAI bots with at least one assigned workspace advertise:

```json
{"type":"shell","environment":{"type":"local"}}
```

Extend the RTTI protocol model with published-property classes for:

- shell tool and local environment;
- heterogeneous request input items;
- heterogeneous response output items;
- `shell_call`, action, command list, requested timeout, and requested output limit;
- `shell_call_output`, stdout, stderr, exit result, and timeout result.

Unknown response item types remain typed base items and are not mistaken for messages or shell calls.

The OpenAI provider supplies a concise workspace section with every assigned workspace's name, purpose, repository path, cache path, and resolved commit. Shell commands use a neutral working directory and the model selects a workspace by its explicit absolute path.

`ProcessPrompt` becomes a simple continuation loop:

```text
send initial Response
    -> final assistant message: complete normally
    -> shell_call: execute command list locally
                   send typed shell_call_output using that Response ID
                   continue loop
```

- The existing OpenAI worker executes the commands synchronously and sequentially.
- No shell worker, scheduler, queue, or second completion method is added.
- Intermediate shell calls do not invoke `CompleteActive`, publish an answer, fail/free the prompt, or return the provider to ready.
- Only the final assistant response completes the active prompt and updates `FPreviousResponseID`.
- Existing cancellation is checked between requests and commands.

Add three positive deployment limits, copied into `TNXBotHostConfig`:

- `ShellCallMaximum` for the complete active prompt;
- `ShellCommandTimeoutMS` for each command;
- `ShellOutputMaximumBytes` for retained stdout/stderr.

Clamp model-requested timeout/output values to those limits. Count shell calls locally across the entire prompt. Capture bounded stdout/stderr, preserve non-zero exit results, return timeout results, and clean up the launched process before continuing.

The canonical repository's read-only status remains a reference-bot behavior rule in this feature. Task-local output is directed to the bot cache. Do not add filesystem isolation or hostile-command defenses.

## Scope

- `NexusTools/BotHost/catalog/Bot.Language.nxscript`
- Relevant BotHost catalog fixtures
- `NexusTools/BotHost/src/obNXBotCatalog.pas`
- One small BotHost workspace type/unit if needed
- `NexusTools/BotHost/src/obNXBotController.pas`
- `NexusTools/BotHost/src/obNXBotHostRuntime.pas`
- `NexusTools/BotHost/src/obNXBotHostConfig.pas`
- `NexusTools/BotHost/src/obNXOpenAIProvider.pas`
- `NexusTools/BotHost/src/protocol/obNXOpenAIResponses.pas`
- Registered BotHost test units and project files as required
- `NexusTools/BotHost/config/NexusBotController.example.json`
- `NexusTools/BotHost/README.md`

## Out Of Scope

- OpenAI-hosted containers and container IDs.
- Per-bot clones, Git worktrees, branches, or writable development repositories.
- Development-bot editing/build/test/commit workflows.
- Filesystem sandboxes, OS identities, hostile-tenant isolation, and hard cross-bot cache isolation.
- Background workspace refresh or synchronization/page polling.
- General workspace, resource, provider, process, or shell frameworks.
- New product threads.
- Other provider workspace implementations.
- Role/Domain/Capability work and unrelated BotHost refactoring.

## Staged Implementation Plan

### Stage 1: Catalog contract

1. Add the single-root `BotCatalog` shape, inline `Workspace` and `Bot` arrays, and `Bot.Workspaces` references to the deployed Bot language.
2. Extract workspace definitions and plural references from the compiled root into the existing unpublished catalog candidate.
3. Publish the bot/workspace candidate atomically after validation.
4. Add focused catalog tests.

### Stage 2: Startup Git preparation

1. Add the small runtime workspace records retained by the controller.
2. Prepare each distinct referenced checkout once through direct Git process execution.
3. Resolve its exact commit and create assigned bot cache directories.
4. Abort runtime startup on preparation failure before provider startup.
5. Pass the prepared records to initial and summoned hosts.

### Stage 3: Typed Responses shell objects

1. Make the request input and response output arrays discriminator-backed typed collections.
2. Add the local-shell, call, action, output, and outcome classes.
3. Add serialization/binding tests using fixed JSON fixtures.

### Stage 4: Existing-worker continuation

1. Add and validate the three shell limits.
2. Advertise local shell and workspace paths only when the OpenAI bot has assignments.
3. Execute commands synchronously through `TProcess` on the current provider worker.
4. Continue Responses with typed outputs until the final assistant message.
5. Preserve existing prompt cancellation, attachment ownership, terminal completion, and error behavior.
6. Add focused provider tests.

### Stage 5: Documentation and live proof

1. Update example catalog/configuration and BotHost documentation.
2. Add one opt-in live test to the existing registered BotHost live suite.
3. Prove the configured model reads a known workspace file, writes a harmless cache artifact, accepts the returned shell output, and completes the same prompt.

## Sub-Agent Delegation

Implementation remains local. This plan does not authorize sub-agent use.

## Verification Plan

Focused deterministic tests will prove:

1. Valid and invalid workspace declarations/references.
2. Zero, one, and multiple workspace assignments.
3. Explicit `Location` use.
4. Catalog loading performs no Git/network work.
5. Local fixture repository preparation resolves an exact commit.
6. Multiple bots share one repository and receive separate cache paths.
7. No per-bot clone or worktree is created.
8. Preparation failure prevents provider startup without altering the catalog.
9. Typed shell protocol serialization and dispatch.
10. Shell output continues the same prompt.
11. Intermediate calls do not complete or publish the prompt.
12. Final assistant output completes exactly once.
13. Timeout and output limits are clamped and enforced.
14. OpenAI bots without workspaces do not advertise shell.

Build and run through the existing projects and Nexus test host:

```powershell
lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost.OpenAI
```

Also build and run the same registered module on the Ubuntu VPS. The opt-in live test uses the configured OpenAI model and VPS workspace; it is not part of the deterministic suite.

Focused review/search must confirm:

- no hosted-container fields or behavior;
- no new shell/workspace thread, scheduler, or polling path;
- no standalone test harness;
- no Git configuration values interpolated into trusted shell strings;
- no `CompleteActive` or answer publication at an intermediate shell response.

## Risks And Questions

- The exact configured model/local-shell combination is confirmed by the opt-in live test, not assumed from deterministic fixtures.
- Local command execution is deliberately trusted reference-bot behavior in this feature; hostile-command containment is out of scope.
- No unresolved architecture decision blocks implementation.

## Approval Gate

No implementation begins until the human owner explicitly authorizes it. Approval of this plan does not authorize sub-agents.
