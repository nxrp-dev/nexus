# Work Plan: NexusBot VPS-Hosted Shared Reference Workspace

## Inputs

- Source request: `C:\Users\kcollins\Downloads\nexusbot-vps-reference-workspace-workplan-request-final.md`.
- Related discussion/review notes:
  - Replace the discarded OpenAI-hosted-container concept with one persistent Nexus-owned Git checkout on the VPS.
  - `Workspace` is provider-neutral NexusScript configuration; OpenAI Responses local shell is the first access implementation.
  - JSON protocol objects remain RTTI/published-property Pascal objects. JSON is the wire representation, not the data contract.
  - Multiple workspaces are first-class and must be presented symmetrically.
  - Reference bots inspect canonical source and write only task-local cache artifacts. Development-bot behavior is separate.
- Existing constraints:
  - Repository `AGENTS.md`, `NexusTools/BotHost/AGENTS.md`, `.ai/standards/pascal.md`, `.ai/protocols/architecture-change.md`, and `.ai/protocols/codex-workplan-format.md`.
  - Current official OpenAI [Shell guide](https://developers.openai.com/api/docs/guides/tools-shell), [Responses create reference](https://developers.openai.com/api/reference/cli/resources/responses/methods/create), and [GPT-5.6 Luna model page](https://developers.openai.com/api/docs/models/gpt-5.6-luna).
  - All deterministic BotHost tests remain registered in `NexusBotHostTestModule`; no standalone test harness is permitted.
  - No sub-agent use is authorized.

## Summary

Extend the deployed Bot language with logical `Workspace` definitions and plural `Bot.Workspaces` references. At BotHost startup, materialize every referenced Git workspace once at its explicitly configured absolute `Location`, resolve it to one exact commit, create each bot's writable cache, and publish an immutable runtime view to hosts. No provider starts until all referenced workspaces are ready.

OpenAI bots with assigned workspaces will advertise the Responses local-shell tool. `TNXOpenAIProvider.ProcessPrompt` will handle typed `shell_call` items, execute their command arrays synchronously through a bounded VPS shell executor, submit typed `shell_call_output` items using the preceding response ID, and repeat until a final assistant message completes the same active prompt. This adds no thread: the existing OpenAI provider worker already isolates the blocking HTTP and process work from independently progressing XMPP activity.

Canonical repositories remain owned and refreshed by trusted Nexus code. Model-generated commands run inside a restricted filesystem/process boundary which exposes the assigned repositories read-only, exposes assigned bot caches read/write, uses a neutral working directory, and does not expose the VPS filesystem generally.

## Verified Findings

### Current Bot dialect and catalog

- `NexusTools/BotHost/catalog/Bot.Language.nxscript` currently allows only root `Bot` definitions with required text properties `Provider`, `Model`, and `Instructions`. It has no `Workspace` definition or `Bot.Workspaces` property.
- The NexusScript validator already supports arrays whose entries are references restricted by definition kind. No NexusScript grammar/compiler change is required.
- `TNXBotCatalog.Load` compiles and validates into an unpublished candidate entry list, performs deployment/provider validation, and swaps the candidate into `FEntries` only after every diagnostic is clear.
- Catalog entries currently retain only name, provider, model, and instructions. Catalog loading performs no Git or other workspace I/O.
- Provider names and catalog lookup are case-sensitive.

### Current runtime ownership

- `TNXBotHostRuntime.Configure` loads launch/controller configuration, loads the logical catalog, creates the controller and initial host, and wires XMPP/control behavior without starting external activity.
- `TNXBotHostRuntime.Start` is the current startup boundary. It creates the runtime directory, starts the provider, connects XMPP, and joins the configured room in that order.
- `TNXBotController.CreateConfiguredHost` creates hosts later for summoned catalog bots by copying their deployment and catalog values.
- Consequently, prepared workspace state must be owned above individual hosts, survive for the BotHost process lifetime, and be available both to the initial host and to later controller-created hosts.
- No runtime workspace owner or generalized resource manager currently exists.

### Current provider and Responses model

- `TNXBotHost` selects providers through `TNXBotProviderRegistry`; there is no provider-name switch in the host.
- `TNXBotHostConfig` is an RTTI-persisted configuration object. Deployment values are copied from `TNXBotDeploymentBinding` by `ApplyDeployment`.
- `TNXOpenAIProvider` owns one justified worker. It serializes one active prompt at a time, performs blocking HTTPS work on that worker, and uses `CompleteActive` as the sole terminal active-prompt boundary.
- `ProcessPrompt` currently sends one Responses request and accepts only a completed assistant message. Any intermediate tool-only response is currently treated as a completed response without assistant text and fails.
- `obNXOpenAIResponses.pas` models JSON with typed `TNXJSONObject` descendants and published properties. Its input array accepts only `TNXOpenAIInputMessage`, while its heterogeneous output dispatcher recognizes only `message`; it does not model tools, `shell_call`, or `shell_call_output`.
- Official OpenAI documentation defines local shell as `{ "type": "shell", "environment": { "type": "local" } }`, returns `shell_call` items containing `call_id`, `action.commands`, `timeout_ms`, and `max_output_length`, and accepts matching `shell_call_output` items containing stdout, stderr, and exit/timeout outcomes.
- The Responses reference defines `max_tool_calls` for calls processed **in one response**. Nexus continuation uses a new Response for each returned shell output, so this field does not establish a whole-active-prompt bound. A provider-side counter is required.
- The GPT-5.6 Luna page lists the Responses endpoint and hosted-shell support; it does not separately prove the local-shell request/continuation path. The requested opt-in live capability test remains required.

### Current process and path support

- Nexus has local `TProcess` usage which sets `Executable` and appends each parameter separately. There is no shared NexusLib process/sandbox abstraction suitable for this feature.
- `obNXBotHostConfig.pas` already resolves persisted relative paths against their configuration file. Workspace `Location` is different: the dialect contract requires it to be absolute.
- No checked-in BotHost VPS service unit, service identity, privilege-drop policy, mount namespace, or shell sandbox establishes the required repository protection. That deployment fact cannot be guessed from this checkout.
- `TProcess` is sufficient as the low-level executable-plus-argument mechanism for trusted Git commands and the sandbox launcher, but a same-authority `/bin/sh -c` child would not protect repositories owned by BotHost.

## Architecture Problem

BotHost currently has no representation of a shared logical workspace, no startup phase which turns such configuration into an exact canonical checkout, and no provider-neutral way to give a host an immutable view of repository/cache paths.

The OpenAI provider also assumes every successful Response terminates in assistant text. Local shell instead introduces a bounded continuation loop within one active prompt. Treating each shell call as a new prompt, a second completion system, or separate worker would break the existing ownership model.

Finally, merely instructing the model not to edit the repository is insufficient. BotHost must retain write authority to refresh the canonical checkout, while the model shell must not inherit that authority. Ordinary same-user file permissions cannot provide this distinction.

## Target Contract

### Deployed NexusScript contract

The deployed dialect will accept:

```nexusscript
Workspace Nexus {
    Purpose: "Shared inspectable working copy of the Nexus source tree.";
    SourceType: Git;
    Source: "https://github.com/nxrp-dev/nexus.git";
    Ref: main;
    Location: "/srv/nexus/workspaces/nexus";
}

Bot Reviewer {
    Provider: OpenAI;
    Model: gpt-5.6-luna;
    Instructions: "Review Nexus changes.";
    Workspaces: [@Nexus];
}
```

Exact language rules:

- `Workspace` is a root definition.
- `Purpose` is optional text.
- `SourceType` is required text and initially permits only case-sensitive `Git`.
- `Source` is required non-empty text.
- `Ref` is optional text; an omitted/blank value means the remote's configured default branch, resolved explicitly during initial clone. It is not silently replaced with `main`.
- `Location` is required non-empty text and must already be absolute.
- `Bot.Workspaces` is an optional array of references. Each entry must be a reference whose effective definition kind is `Workspace`; duplicate references in one bot are rejected during catalog extraction.
- Zero, one, or many workspace references are valid.
- The dialect remains provider-neutral and does not mention shell or OpenAI.

`TNXBotCatalog` will publish one coherent candidate containing both workspace definitions and bot entries. Each bot entry keeps non-owning references to workspace definitions owned by that same published catalog. Candidate failure leaves both the prior bot list and prior workspace list untouched.

Catalog/path validation will:

- normalize `Location` lexically with the host platform's absolute path normalization for comparison;
- reject relative paths, the filesystem root, duplicate normalized locations, and ancestor/descendant location overlap;
- use platform-appropriate path case comparison rather than NexusScript identifier comparison;
- reject empty source values and unsupported source types;
- validate references and duplicates without accessing the filesystem, Git, or network;
- not resolve symlinks or require the path to exist unless the deployment later establishes that configured workspace roots may be symlinks.

### Runtime workspace ownership

- Owner: `TNXBotController` owns one process-lifetime prepared-workspace collection because it already owns the catalog and creates both initial and summoned hosts.
- Preparation entry point: `TNXBotController.PrepareWorkspaces`, called synchronously by `TNXBotHostRuntime.Start` before `FHost.StartProvider`.
- Prepared state per logical workspace:
  - logical name and purpose;
  - explicit normalized workspace root;
  - `<Location>/repo`;
  - configured source/ref;
  - exact resolved commit;
  - readiness/failure only during preparation.
- State flow:

```text
valid published catalog
    -> runtime Start
    -> validate provider workspace capability for every referenced bot
    -> prepare every distinct referenced workspace once
    -> create bot cache directories and immutable bot-specific access records
    -> start initial provider
    -> connect XMPP and accept control/prompt traffic
```

- The collection becomes immutable after successful preparation. Hosts receive owned copies of small access records, not mutable repository owners. No workspace lock, polling, background refresh, or scheduler is introduced.
- A preparation failure raises from runtime startup before any provider starts. It does not mutate or invalidate the already published logical catalog.
- Controller-created hosts after startup can only use the already prepared collection. They do not fetch or refresh Git.
- `Shutdown` frees hosts before the controller-owned prepared collection. No workspace shutdown protocol is needed because it owns no thread or live process between calls.

### Refresh policy and trusted Git

The selected initial refresh boundary is BotHost startup only:

```text
startup -> fetch/resolve/checkout exact commit -> immutable view
process lifetime -> no refresh
restart -> next refresh
```

For each distinct referenced workspace, trusted Nexus preparation will:

1. Validate that `Location` is not occupied by an unrelated layout.
2. Create `Location` and `botcache` when absent.
3. If `repo` is absent, invoke `git clone --no-checkout -- <Source> <repo>` through `TProcess.Executable` plus individual parameters.
4. If `repo` exists, require it to be a Git work tree and require its `origin` URL to match the configured source; never silently repoint it.
5. Require a clean tracked/untracked status before moving the checkout. A dirty canonical repository is a startup failure; preparation does not erase unknown local material to recover.
6. Fetch the configured ref from `origin` using argument-list invocation. If `Ref` is omitted, use the cloned remote's symbolic default rather than assuming a branch name.
7. Resolve the fetched ref to one commit, check out that commit detached, and record the full commit ID.
8. Verify `HEAD` equals the recorded commit and the final work tree is clean.

Configuration values remain individual Git arguments. Git setup never concatenates `Source`, `Ref`, or paths into a shell command. Process output and exit status are bounded and included in a concise startup diagnostic on failure without exposing credentials embedded in a source URL.

### Bot cache mapping

- Every assigned bot receives `<Location>/botcache/<safe-bot-key>`.
- Because NexusScript identifiers may contain filesystem separators or other unsafe bytes, the physical key is not the raw bot name. Use one deterministic injective mapping: `id-` followed by uppercase hexadecimal encoding of the UTF-8 bot-name bytes.
- Reject a bot name whose encoded component exceeds the host filesystem's supported component bound; never truncate it.
- Construct the cache path only by joining the known `botcache` root with that one encoded component, normalize it, and assert it remains an immediate child of the root.
- Cache directories persist with the VPS filesystem. This feature performs no automatic cache cleanup.
- All reference shells may initially execute under the same sandbox authority. A bot is shown only its own assigned cache paths, but cross-bot cache separation remains a behavioral contract, not a promised OS security boundary.

### Provider-neutral host contract

- Add a small shared workspace-access type in BotHost, containing logical name, purpose, repository path, cache path, and resolved commit.
- `TNXBotHostConfig` owns a non-published runtime list of these access records. They are not persisted deployment JSON and are not NexusScript runtime state.
- `TNXBotProvider` gains a class-level workspace capability query which defaults to false. `TNXOpenAIProvider` returns true.
- Runtime preparation checks every bot with assigned workspaces through its registered provider class. An unsupported provider produces an explicit startup diagnostic; the catalog remains logically valid and no provider-name branch is added.
- `TNXBotHost` also rejects construction/configuration if non-empty workspace access is supplied to a provider which reports no support. This prevents later summoned hosts from silently losing workspace access.
- OpenAI bots with no assigned workspaces omit the shell tool entirely.

### Shell presentation

For an OpenAI bot with workspace assignments, append a generated runtime section to the configured provider instructions on every initial and continuation request:

```text
Reference workspaces available through local shell:

Workspace Nexus
Repository: /srv/nexus/workspaces/nexus/repo
Cache: /srv/nexus/workspaces/nexus/botcache/id-5265766965776572
Commit: abc123...

Workspace Another
Repository: /srv/nexus/workspaces/another/repo
Cache: /srv/nexus/workspaces/another/botcache/id-5265766965776572
Commit: def456...
```

- Preserve catalog order while presenting every assignment with the same fields.
- Use only absolute paths.
- Set the shell working directory to a neutral empty directory created by the sandbox, not any repository or first workspace.
- The model selects a workspace by its explicit path. There is no current workspace state.

### Minimum VPS shell boundary

The required filesystem distinction cannot be implemented by same-authority `TProcess` alone. The implementation will use one narrow Linux filesystem/process sandbox launcher, with Bubblewrap (`bwrap`) as the preferred mechanism to verify on the actual VPS:

- unshare the mount and PID namespaces;
- bind only required system executables/libraries read-only;
- bind every assigned repository at its real absolute path read-only;
- bind the bot's assigned cache directories at their real absolute paths read/write;
- provide private `/tmp`, `/proc`, and a neutral working directory;
- omit unrelated workspace and host paths;
- disable network for reference-shell commands;
- arrange for the sandbox process tree to die with its parent/namespace init.

This is not a generalized Nexus sandbox and it is not a container workspace. It is the process boundary for one model-requested command. Trusted Git preparation runs outside it.

Before implementation changes, inspect the actual VPS and prove that Bubblewrap is installed and usable by the BotHost service identity with unprivileged namespaces. If it is, use a fixed executable and fixed framework-owned arguments; only the model command is passed as the final `/bin/sh -c` argument. If it is not usable, stop and return the concrete deployment result for human selection rather than falling back to an unrestricted same-authority shell or inventing a daemon/privilege service.

This is the one concrete implementation blocker not answerable from the repository alone.

### Bounded synchronous shell executor

- `TNXOpenAIProvider` owns one injectable local-shell executor. Production uses the VPS sandbox launcher; tests use a fake executor.
- Execution remains synchronous in the existing OpenAI provider worker. No shell thread, queue, timer service, watchdog, or second completion path is added.
- Add typed positive deployment limits copied through `TNXBotHostConfig`:
  - `ShellCallMaximum`: maximum `shell_call` items over one active prompt;
  - `ShellCommandMaximum`: maximum commands accepted in one `shell_call` and therefore a bound on total processes;
  - `ShellCommandTimeoutMS`: host maximum for each command;
  - `ShellOutputMaximumBytes`: host maximum captured per command across stdout and stderr.
- Set `parallel_tool_calls` false. If a response nevertheless contains multiple shell calls, handle them in wire order while applying the same whole-prompt counter.
- Execute the commands in each action sequentially in array order. Return one output entry per command in the same order.
- Clamp requested `timeout_ms` and `max_output_length` to positive host maxima. Missing/non-positive requests use the host maximum; requests may reduce but never expand host authority.
- Drain stdout and stderr while the process runs so either pipe cannot block the child. Keep only the bounded output while continuing to drain excess bytes; mark diagnostics/output as truncated without allowing memory growth.
- On timeout, terminate the sandbox process tree and return the typed timeout outcome with any bounded partial output.
- Preserve non-zero exits as normal typed exit outcomes. Failure to launch or contain the sandbox is a prompt failure, not a fabricated shell result.
- `TThread.Yield` may be used only inside the existing worker's local process-drain loop when no pipe/process progress is available. It is not timing, polling architecture, or a new thread.

The above limits make total shell work finite:

```text
maximum processes = ShellCallMaximum * ShellCommandMaximum
maximum command time = processes * ShellCommandTimeoutMS
maximum returned bytes = processes * ShellOutputMaximumBytes
```

### RTTI-typed Responses continuation

Extend `obNXOpenAIResponses.pas` with published-property objects for:

- shell tool and local environment;
- request tools array;
- heterogeneous request input items (`message` and `shell_call_output` initially);
- heterogeneous response output items (`message` and `shell_call` initially);
- shell action and command string array;
- shell call status, ID/call ID, timeout, and maximum output length;
- shell output array;
- exit and timeout outcomes selected by their `type` discriminator;
- stdout and stderr;
- request fields `parallel_tool_calls` and `max_tool_calls` where useful.

The discriminator factories must instantiate the concrete RTTI class before binding JSON. Unknown item kinds remain typed base items and must not be misclassified as messages or shell calls.

`ProcessPrompt` becomes one local continuation loop:

1. Build the initial typed user-message request, attachments, shell tool when workspaces exist, and effective workspace instructions.
2. Send and bind the typed response.
3. If it contains shell calls and no terminal assistant message, validate the call shape and whole-prompt limits.
4. Execute each shell action synchronously and build typed `shell_call_output` input items.
5. Send the next request with `previous_response_id` set to the immediately preceding Response ID, the same tool declaration and effective instructions, and only the shell output input items.
6. Repeat until a valid terminal assistant message is returned or a normal failure/limit/cancellation occurs.
7. Call `CompleteActive` exactly once at the terminal boundary. Only terminal success advances `FPreviousResponseID` to the final Response ID and publishes `FinalAnswer`.

Intermediate responses must not call `CompleteActive`, `FinalAnswer`, `PromptFailed`, `ReturnToReady`, or free the active prompt. Existing cancellation is checked at existing safe boundaries before executing another command and before sending another continuation request; no new lifecycle machinery is introduced.

Uploaded attachment cleanup remains owned by the one active prompt and occurs after its final success/failure, not after an intermediate shell call.

## Scope

Expected files/areas:

- `NexusTools/BotHost/catalog/Bot.Language.nxscript`
- Bot catalog fixtures under `NexusTools/BotHost/catalog/`
- `NexusTools/BotHost/src/obNXBotCatalog.pas`
- New small BotHost workspace type/owner unit(s), expected under `NexusTools/BotHost/src/`
- `NexusTools/BotHost/src/obNXBotController.pas`
- `NexusTools/BotHost/src/obNXBotHostRuntime.pas`
- `NexusTools/BotHost/src/obNXBotHostConfig.pas`
- `NexusTools/BotHost/src/obNXBotHost.pas`
- `NexusTools/BotHost/src/obNXBotProvider.pas`
- `NexusTools/BotHost/src/obNXOpenAIProvider.pas`
- `NexusTools/BotHost/src/protocol/obNXOpenAIResponses.pas`
- `NexusTools/BotHost/NexusBotHost.lpi` only as required for added units
- `NexusTools/BotHost/tests/tsNXBotHostTests.pas`
- `NexusTools/BotHost/tests/tsNXOpenAIProviderTests.pas`
- One focused registered workspace test unit if separating it makes the tests clearer
- `NexusTools/BotHost/tests/NexusBotHostTestModule.lpr` and `.lpi` if a test unit is added
- `NexusTools/BotHost/tests/tsNXBotHostLiveTests.pas`
- `NexusTools/BotHost/config/NexusBotController.example.json`
- `NexusTools/BotHost/README.md`
- VPS deployment documentation for the verified sandbox prerequisite; no service mutation is implicit in this plan

## Out Of Scope

- OpenAI-hosted containers, container IDs, container uploads, lifecycle, networking, expiration, memory, or billing.
- Repository upload to OpenAI.
- Per-bot clones, worktrees, branches, overlays, or writable source trees.
- Development bots, source editing, builds, tests, commits, pushes, pull requests, patches to the canonical repository, or artifact orchestration.
- Continuous/background Git refresh, polling, or refresh commands during a BotHost lifetime.
- A generalized workspace/resource manager, process framework, sandbox library, scheduler, or daemon.
- New product threads or shell workers.
- A hard OS security promise between different bots' cache directories.
- The unfinished Role/Domain/Capability roster design.
- NexusScript grammar/compiler changes.
- Provider integrations other than OpenAI local shell.
- Broader BotHost refactoring.

## Staged Implementation Plan

### Stage 1: Verify the deployment boundary before coding it

1. On the VPS, inspect the BotHost service identity, Ubuntu version, available `git`, `/bin/sh`, and `bwrap`, and whether unprivileged Bubblewrap mount/PID namespaces work for that identity.
2. Run a disposable command proving the proposed boundary can expose a fixture repository read-only, a fixture cache read/write, hide an unrelated path, disable network, and terminate descendants.
3. Record the exact fixed launcher arguments in the implementation notes/tests.
4. If this proof fails, pause with the exact result. Do not implement an unrestricted fallback or select a larger deployment architecture without human review.

### Stage 2: Extend and extract the logical catalog

1. Add the exact `Workspace` and `Bot.Workspaces` rules to `Bot.Language.nxscript`.
2. Extend the catalog candidate with owning workspace definitions and non-owning bot references.
3. Extract all effective values from the compiled model, including plural references.
4. Validate source type, required values, duplicate references, absolute/non-root locations, normalized uniqueness, and non-overlap.
5. Swap the candidate bot/workspace graph atomically only after every logical and deployment diagnostic succeeds.
6. Add catalog tests proving validation performs no Git/network/filesystem materialization.

### Stage 3: Add startup-only workspace realization

1. Add the small controller-owned prepared-workspace collection and trusted executable-plus-argument process runner.
2. Implement first materialization, existing-repository verification, clean-state gate, fetch/ref resolution, detached exact checkout, final clean verification, and commit recording.
3. Implement deterministic safe bot-cache keys and cache creation.
4. Build owned bot-specific workspace access records for initial and later summoned hosts.
5. Call preparation from `TNXBotHostRuntime.Start` before provider startup; leave the collection immutable thereafter.
6. Ensure all failure paths leave catalog publication intact and prevent providers from accepting prompts.

### Stage 4: Add provider-neutral workspace capability

1. Add the non-published workspace access list to host runtime configuration.
2. Add the default-false provider capability query and OpenAI override.
3. Validate all referenced provider capabilities at startup without provider-name switches.
4. Copy access records in `CreateConfiguredHost` and enforce the same capability contract during host construction.
5. Prove bots without assignments remain unchanged and receive no shell access.

### Stage 5: Add typed Responses shell protocol

1. Replace the message-only request input array with a discriminator-backed heterogeneous typed array.
2. Add typed shell tool/environment, `shell_call`, action, commands, limits, output, and outcome objects.
3. Extend the output discriminator for `shell_call` and the input discriminator for `shell_call_output`.
4. Add round-trip/binding tests for exit, timeout, multiple commands, unknown items, and mixed message/tool output.
5. Keep all JSON serialization/deserialization inside the existing RTTI object model.

### Stage 6: Add the bounded local shell and continuation loop

1. Add typed deployment limits and copy/validation paths.
2. Implement the injectable synchronous shell executor using the verified fixed Bubblewrap boundary.
3. Generate the symmetric workspace instruction section and advertise local shell only for assigned OpenAI bots.
4. Refactor `ProcessPrompt` into the same-active-prompt continuation loop while preserving attachment ownership, cancellation, fatal/nonfatal HTTP handling, and terminal `CompleteActive` behavior.
5. Enforce call, command, timeout, and output bounds locally; do not rely on per-Response `max_tool_calls` as a whole-chain limit.
6. Add focused provider tests proving intermediate calls never complete/publish the prompt and final success/failure happens exactly once.

### Stage 7: Documentation and opt-in live proof

1. Update the example catalog/configuration with one explicit workspace and the shell limits, without adding credentials or machine-specific production paths to source control.
2. Document startup-only refresh, exact commit presentation, cache mapping/persistence, provider capability failure, Bubblewrap prerequisite, and the distinction between trusted Git and model shell.
3. Add the opt-in live test to the existing BotHost live-test suite.
4. Run it against the configured VPS BotHost model and a disposable known workspace/cache fixture.

## Sub-Agent Delegation

Implementation remains local to the primary Codex agent. This work plan does not authorize sub-agent creation, messaging, resumption, or delegation. Plan approval and implementation approval do not change that restriction.

## Verification Plan

### Deterministic catalog/runtime tests

Register tests proving:

1. Valid `Workspace` with explicit `Location` loads.
2. A bot can reference one declared workspace.
3. Missing and wrong-kind references fail.
4. Unsupported `SourceType` fails.
5. `Location` is not derived from workspace name.
6. Relative, root, duplicate, and overlapping locations fail.
7. Multiple workspace references remain distinct and ordered.
8. Duplicate workspace references on one bot fail.
9. Catalog load performs no Git/network/materialization calls.
10. Failed candidate load preserves the previously published bot/workspace graph.
11. Unsupported-provider workspace assignment fails explicitly at runtime, not dialect validation.
12. OpenAI without assignments receives no workspace access.

Use local temporary Git repositories and an injectable process recorder to prove:

13. First materialization uses executable-plus-argument Git invocation.
14. Existing repository source mismatch and dirty state fail without destructive cleanup.
15. Configured ref resolves to an exact detached commit.
16. Startup refresh occurs once and no prompt/controller path refreshes it.
17. Two bots share repository path/commit but receive distinct cache paths.
18. Multiple workspaces are presented symmetrically with absolute paths and neutral cwd.
19. Bot-name encoding cannot escape or collide through path separators and rejects overlong components.
20. No per-bot repository clone/worktree is created.
21. Materialization failure prevents provider startup and preserves the logical catalog.

### Deterministic typed-provider tests

Register tests proving:

22. Local shell tool and environment serialize through RTTI properties.
23. `shell_call` binds to its typed output class.
24. `shell_call_output` serializes as a typed heterogeneous input item.
25. Exit/timeout outcomes and stdout/stderr round-trip correctly.
26. Unknown input/output kinds remain base typed objects and are not misclassified.
27. One shell call continues the same active prompt and publishes only the later final answer.
28. Multiple command outputs preserve command order.
29. Multiple continuation responses preserve the immediately preceding response ID.
30. Cancellation/failure at every continuation boundary completes the prompt exactly once.
31. Shell call and command maxima terminate the prompt normally.
32. Requested timeout/output values are clamped to deployment maxima.
33. Excess process output is drained but not retained beyond the bound.
34. Non-zero exit is returned to the model; launch/containment failure fails the prompt.
35. Uploaded attachments remain owned until the entire shell continuation ends.

### Linux boundary tests

On Linux with the verified Bubblewrap prerequisite, run registered deterministic tests proving:

36. Repository reads and ordinary read-only Git inspection succeed.
37. Repository creation/modification/deletion attempts fail and leave Git clean.
38. Assigned cache writes succeed.
39. An unrelated host path is unavailable.
40. Network access is unavailable.
41. Timeout terminates the entire sandbox process tree and returns bounded partial output.

The Windows test run uses the injectable recorder/fake and does not pretend to prove the Linux OS boundary.

### Build and suite commands

After implementation approval:

```powershell
lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost.OpenAI
```

Build and run the equivalent Linux BotHost and registered test module on the VPS, including the Linux boundary suite. Use the existing Nexus test framework, not a new executable harness.

### Focused searches

- No hosted-container state or `container_id` introduced:

```powershell
rg -n "container_id|container_reference|container_auto" NexusTools\BotHost
```

- No new shell/workspace threads, schedulers, polling, or standalone harnesses:

```powershell
rg -n "Shell.*Thread|Workspace.*Thread|Scheduler|CheckDeadlines|Sleep\(" NexusTools\BotHost\src NexusTools\BotHost\tests
```

- No provider-name routing branch for workspaces:

```powershell
rg -n "Provider.*OpenAI|OpenAI.*Provider" NexusTools\BotHost\src\obNXBotHost.pas NexusTools\BotHost\src\obNXBotController.pas NexusTools\BotHost\src\obNXBotHostRuntime.pas
```

- Trusted Git values are passed as arguments, not interpolated shell commands. Review every production `git`, `/bin/sh`, and `bwrap` process construction directly.
- Review every `CompleteActive`, `FinalAnswer`, `PromptFailed`, and `FPreviousResponseID` path to prove intermediate shell responses do not terminate the prompt.

### Opt-in live OpenAI/VPS test

Through the registered live suite:

1. Start with a known clean canonical fixture and empty bot cache.
2. Advertise local shell to the configured production model.
3. Require a harmless `shell_call` which reads a known repository file.
4. Return typed output and verify the model continues to the final answer.
5. Require a harmless cache artifact write and verify its exact contents.
6. Attempt a repository write and verify it fails.
7. Verify the canonical repository remains clean and at the recorded commit.
8. Record model/API compatibility and bounded output without logging credentials.

This live test is opt-in and is not part of the deterministic suite.

## Risks And Questions

- **Concrete deployment blocker:** the repository does not define the VPS BotHost service identity or prove Bubblewrap availability. Stage 1 must establish the boundary before shell implementation. An unrestricted fallback is forbidden.
- **Model capability:** official documentation establishes the local-shell protocol and lists hosted-shell support for GPT-5.6 Luna, but only the live test can prove the exact deployed model/account accepts this local flow.
- **Git credentials:** private repository authentication may be required on the VPS. Reuse the existing operator-managed Git credential mechanism; do not place credentials in process arguments or diagnostics. If none exists, stop for a separate decision.
- **Source URL comparison:** the implementation must compare existing `origin` without logging embedded credentials and must not silently rewrite it.
- **Platform scope:** the real containment boundary is Linux/VPS-specific. Windows deterministic tests validate Nexus logic through fakes; they do not claim equivalent host containment.
- No human contract decision remains in the logical workspace, refresh, cache, provider, threading, or Responses continuation design. Only the verified VPS mechanism can confirm or block the selected sandbox implementation.

## Approval Gate

This work plan is a planning artifact only. No implementation, source edits beyond this plan, builds, tests, VPS inspection or changes, package installation, service configuration, Git materialization, OpenAI live call, or archive creation begins until the human owner explicitly authorizes implementation.

Implementation authorization does not authorize sub-agents.
