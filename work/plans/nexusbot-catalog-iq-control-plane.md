# Work Plan: NexusBot Catalog and IQ Control Plane

## Inputs

- Source request: `nexusbot-roster-iq-control-plane-workplan-request (2).md`
  supplied from the owner's Downloads folder.
- Related discussion/review notes: the control host owns the catalog and all
  active in-process bot instances; IQ is a remote transport rather than
  in-process IPC; addressed human MUC messages and incoming IQ requests converge
  on one local typed operation, authorization boundary, and executor; BotHost's
  existing address router remains the sole owner of mention/reply admission.
- Existing constraints: no Openfire or ordinary-client changes; no direct-message
  control admission; no generalized RPC or XML RTTI framework; JSON-RPC tool
  contracts use RTTI classes and published properties; secrets remain in
  environment variables; implementation remains local with no sub-agents unless
  the human owner explicitly requests them.

## Summary

Add a controller-owned bot catalog and deterministic control executor to
NexusBot. The controller will own zero or more active `TNXBotHost` instances,
load behavioral bot definitions from a deliberately small Bot
language/validator definition using NexusScript, associate those definitions
with non-secret deployment configuration, and execute LIST, STATUS, INVITE, and
DISMISS operations.

Three adapters will converge on the same local operation model:

- exact human commands admitted by the existing MUC router;
- a narrow RTTI-modeled `bot_control` Codex tool for semantic human requests;
- a versioned XMPP IQ module for remote machine callers.

The IQ adapter will parse and serialize its own XML, advertise its namespace
through the existing XEP-0030 module, and complete asynchronous INVITE/DISMISS
requests exactly once without blocking the XMPP connection thread. Human
requests will call the local executor directly and will never send IQ to the
controller itself.

## Verified Findings

- `TNXBotHost` currently owns one `TNXCodexAppServer`, one `TNXXMPPClient`, one
  `TNXXMPPMUCModule`, and one `TNXBotHostConfig`.
- `TNXBotHost.JoinRoom` and `LeaveRoom` currently operate only on the single
  configured `RoomJID`, although `TNXXMPPMUCModule` already tracks multiple
  rooms.
- `TNXBotHost` uses one global `FAccepting` flag and its observable snapshot has
  one room state. That shape cannot faithfully represent a bot present in
  multiple rooms.
- The existing `TNXBotHostRouter` admits live addressed group-chat messages,
  rejects self/history/non-groupchat traffic, handles replies, and supports both
  leading `@Nick` and Gajim's case-insensitive `Nick, ` form. A control
  interpreter can consume its resulting `TNXBotPrompt`; it does not need another
  address parser.
- `TNXXMPPDispatcher.RegisterIQResponder` dispatches by IQ type plus the first
  child element's exact namespace/local-name pair. Unhandled get/set IQs receive
  `service-unavailable`.
- IQ responder handlers run during connection-thread stanza processing. They
  must copy all needed request identity/payload data before returning and cannot
  retain `TNXXMPPStanza`.
- `TNXXMPPModule.Submit` provides the existing application-to-XMPP command path.
  Deferred IQ responses can therefore be represented as owned module operations
  and sent on the connection thread instead of calling the module sender from an
  arbitrary thread.
- `TNXXMPPClient.SendIQ` already provides bounded outbound IQ submission,
  correlation, timeout, and completion callbacks, but accepts an XML payload.
  The bot-control module must place its typed caller API above that boundary.
- NexusXMPP modules can contribute feature namespaces with `AddFeatures`.
  `TNXXMPPClient.Connect` aggregates them into an installed
  `TNXXMPPDiscoModule`; BotHost does not currently install a disco module.
- `TNXXMPPMUCModule` retains occupant nick, real JID when disclosed by the room,
  occupant ID, availability, and room membership. This supplies the verified
  identity needed for authorized MUC control requests.
- `TNXCodexAppServer` already binds `item/tool/call` to typed RTTI protocol
  objects, but currently declines every dynamic tool call. The new implementation
  must accept only the declared `bot_control` tool and continue declining unknown
  tools deterministically.
- BotHost configuration is an RTTI-persisted JSON object. Password values are
  resolved from `PasswordEnvironmentVariable` and are not persisted.
- NexusScript compiler/session/model code is reusable under
  `NexusTools/Script/core`; no movement into `NexusLib` is required for BotHost
  to load a catalog.
- Focused BotHost module, standalone process-boundary, NexusXMPP deterministic,
  NexusScript deterministic, and Openfire live-test paths already exist and can
  be extended.

## Architecture Problem

The current application is one conversational bot instance. It has no owner for
multiple definitions or instances, no stable local management operation model,
and no way to correlate a long-running incoming IQ request with eventual bot
lifecycle completion. Adding command phrases directly to the room-message
handler or adding XML parsing directly to BotHost would create separate human
and machine semantics and would couple transport details to lifecycle ownership.

The correct seam is a local controller/executor. It owns catalog and runtime
state, accepts a typed operation plus verified authorization context, advances a
bot through activation/XMPP/room membership, and produces one typed result. The
human interpreter, model tool, and IQ module are adapters around that seam.

Multi-room membership must also become real at the bot-instance boundary.
Leaving one room cannot disable the entire bot or cancel unrelated work for its
other rooms.

## Target Contract

### Ownership

- A new `TNXBotController` is the control-host owner.
- It owns:
  - the immutable loaded bot catalog;
  - the deployment bindings associated with catalog entries;
  - the active `TNXBotHost` instances it creates;
  - the shared authorization policy;
  - pending control operations and their deadlines;
  - the shared control executor.
- The controller is the sole owner of operation lifetime, deadline, timeout,
  cancellation, and exactly-once semantic completion. No transport adapter owns
  a second operation state machine.
- Each active `TNXBotHost` remains one behavioral bot instance and owns its own
  Codex App Server session, XMPP client, MUC module, configuration clone, and
  observable runtime state.
- App Server child processes remain owned by their in-process bot instances;
  no separate Nexus daemon, IPC protocol, or distributed registry is introduced.
- The controller application owns one distinguished NexusBot instance through
  which addressed human commands and remote control IQs arrive.

### Catalog and deployment

- Use the term **catalog** exclusively; do not reuse XMPP's roster terminology.
- Add one minimal Bot language/validator definition using NexusScript and a
  deterministic loader supporting only the initial behavioral fields:
  - bot name/identity;
  - `Provider` (Codex only in this pass);
  - `Model`;
  - `Instructions`.
- A definition is **known** when present in the compiled catalog and **available**
  when it is valid, uses a supported provider, and has a valid deployment
  binding.
- Deployment configuration remains an RTTI/published object graph persisted by
  the existing JSON persistence system. Each binding names its catalog bot and
  supplies XMPP JID, password-environment-variable name, resource, room nick,
  Codex executable/runtime settings, and existing limits required to construct
  a `TNXBotHostConfig`.
- Persist only the environment-variable name, never a password or API key.
- Catalog identity follows NexusScript's case-sensitive identity. Human explicit
  name resolution may compare case-insensitively only when it selects exactly one
  catalog entry; IQ requests carry the canonical catalog name and use exact
  identity.
- Loading reports invalid definitions and missing/duplicate deployment bindings
  as catalog diagnostics. One bad entry does not erase valid entries.

### Local operation and authorization model

- Define one Pascal operation kind: LIST, STATUS, INVITE, or DISMISS.
- The operation carries canonical bot name when required and an explicit bare
  room JID for INVITE/DISMISS.
- A separate authorization context carries:
  - transport origin (human MUC, remote IQ, or model tool tied to a human turn);
  - verified caller bare JID;
  - source room JID when applicable;
  - whether the identity was resolved from verified MUC occupant state.
- The model tool inherits the authorization context and room of the original
  admitted prompt. Model-supplied arguments can never replace caller identity.
- Configure two small allowlists:
  - readers may LIST and STATUS;
  - operators may LIST, STATUS, INVITE, and DISMISS.
  Operators implicitly have reader access.
- Remote IQ callers authorize by normalized bare sender JID.
- Human MUC callers resolve their occupant through `TNXXMPPRoom` and authorize
  using the room-disclosed real JID. Nickname and occupant JID are never
  authorization. If no verified real JID exists, control operations are denied;
  ordinary conversation remains unaffected.
- Authorization is enforced in the shared executor for every adapter.

### Executor and lifecycle semantics

- LIST returns every catalog entry with canonical name, known/available validity,
  active-instance state, App Server state, XMPP state, and zero or more room
  memberships.
- STATUS returns the same lifecycle layers for one bot plus its provider/model
  and current diagnostic state; it does not expose instructions, secrets, or
  environment values.
- INVITE is idempotent:
  - already joined is a successful no-op returning current state;
  - otherwise validate the catalog/deployment entry;
  - create and retain an instance when inactive;
  - start its App Server and wait for ready;
  - connect its XMPP identity and wait for online;
  - join the explicit room and wait for joined;
  - complete successfully only after joined state is observed.
- If a newly created instance fails before joining, shut it down and remove it
  from the active map. A pre-existing instance remains owned and reports its
  resulting state.
- DISMISS is idempotent: an already-absent bot is a successful no-op. Otherwise
  it completes only after the explicit room reaches left/absent state.
- DISMISS never stops the App Server, disconnects XMPP, destroys the instance,
  or affects membership in another room.
- Pending operations have a configured capacity and deadline. Lifecycle events,
  failure events, shutdown, and deadline expiration converge through one
  exactly-once completion method. Completion removes the pending record before
  invoking its result callback so reentrant state notifications cannot complete
  it twice.
- Waiting is owned by the controller/control operation mechanism. Neither the
  XMPP connection thread nor NexusUI's message loop blocks or polls protocol
  completion.

### Multi-room bot-instance behavior

- Change bot-instance join/leave operations to take an explicit room JID.
- Replace global room admission state with per-room membership. A room message is
  eligible only for a currently joined room; leaving/failing one room does not
  disable other rooms.
- Observable bot state exposes a copied list of room JID/state pairs rather than
  one global room state. The GUI may continue displaying the configured default
  room by selecting that entry from the snapshot.
- Prompt cancellation gains a room-specific path so DISMISS cancels only work
  belonging to the dismissed room. Full disconnect/shutdown still cancels all
  prompts.
- Responses continue using the room JID retained by each prompt.

### Human adapter

- `TNXBotHostRouter` remains the only owner of message validity, live/history,
  groupchat, self-message, mention, Gajim nickname-comma, reply, empty, and size
  admission rules.
- The control interpreter receives only the router's admitted prompt.
- Recognize the narrow deterministic forms case-insensitively:
  - `list bots`;
  - `status <bot>` and human alias `info <bot>`;
  - `invite <bot>`;
  - `dismiss <bot>`.
- Deterministic INVITE/DISMISS inject the admitted prompt's room JID into the
  typed operation. They invoke the local executor directly and send a concise
  human rendering of its typed result back to that room.
- Non-command conversation continues to the Codex App Server unchanged.
- Semantic control requests go through one declared `bot_control` dynamic tool.
  Its input and result are RTTI classes with published properties; no free-form
  JSON construction or parsing is permitted.
- The tool accepts only the normalized operation fields. The host supplies
  caller/room context, authorizes and executes locally, and returns the typed
  result to the same Codex turn so NexusBot can answer conversationally.
- Unknown dynamic tools remain explicitly declined. Ordinary model prose is
  never parsed to discover a control operation.
- Human direct-message control admission remains out of scope.

### IQ adapter and wire contract

- Use namespace `urn:nexus:bot-control:1`.
- Use exact first-child QNames matching the existing dispatcher:
  - IQ `get` + `<bots/>` for LIST;
  - IQ `get` + `<status bot='CanonicalName'/>` for STATUS;
  - IQ `set` + `<invite bot='CanonicalName' room='room@service'/>`;
  - IQ `set` + `<dismiss bot='CanonicalName' room='room@service'/>`.
- The bot-control XMPP module owns validation, escaping, DOM parsing, result XML,
  error XML, responder registration, feature advertisement, and a typed Pascal
  caller API. BotHost/controller code never constructs or inspects control XML.
- The module copies incoming `id`, `from`, operation fields, and authorization
  identity before its responder returns. It emits a typed request event to the
  controller and retains only bounded transport-correlation data needed to
  serialize and send the controller's eventual IQ result/error. That record may
  contain the request ID, caller JID, response QName, and controller operation
  token; it contains no independent operation state, deadline, timeout,
  cancellation, or completion policy.
- Connection loss or adapter shutdown is reported to the controller as a
  cancellation cause. The controller performs the one semantic completion; the
  IQ adapter then sends the response when transport remains available or
  discards its transport-correlation record when it does not.
- Deferred results are submitted as owned module operations and serialized/sent
  on the XMPP connection thread.
- The caller API accepts typed operation values, uses `SubmitIQ`, validates the
  expected full controller JID, parses typed results/errors, and reports one
  completion callback.
- Install `TNXXMPPDiscoModule` on the controller and advertise
  `urn:nexus:bot-control:1` through the control module's `AddFeatures` method.
  Machine callers target a configured/discovered full controller JID/resource.

### Errors and no-op results

- Missing/malformed attributes, invalid operation shape, or invalid room JID:
  IQ `modify/bad-request`.
- Unauthorized caller: IQ `auth/forbidden`.
- Unknown bot: IQ `cancel/item-not-found`.
- Known but invalid/unavailable bot or activation/join failure:
  IQ `cancel/service-unavailable` with one namespaced Nexus condition and safe
  diagnostic text.
- Capacity exhaustion: IQ `wait/resource-constraint`.
- Operation deadline: IQ `wait/remote-server-timeout`.
- Unsupported QName/type continues through the existing unhandled-IQ
  `service-unavailable` behavior.
- Already joined INVITE and already absent DISMISS are successful typed no-op
  results, not errors.
- Local human/model adapters receive the same typed error category and safe
  detail before rendering it for a person or model turn.

## Scope

Expected areas include:

- `NexusTools/BotHost/src/tpNXBotControl.pas` for the single local operation,
  authorization, result, state, and completion contracts.
- `NexusTools/BotHost/src/obNXBotCatalog.pas` for NexusScript compilation,
  diagnostics, immutable catalog entries, and deployment association.
- `NexusTools/BotHost/src/obNXBotController.pas` for catalog/instance ownership,
  authorization, execution, pending deadlines, and exactly-once completion.
- `NexusTools/BotHost/src/obNXXMPPBotControl.pas` for the IQ responder/caller
  adapter and feature advertisement.
- `NexusTools/BotHost/src/obNXBotControlInterpreter.pas` for deterministic human
  command recognition and typed operation creation.
- `NexusTools/BotHost/src/obNXBotHost.pas`, `obNXBotHostState.pas`,
  `obNXBotHostConfig.pas`, and `tpNXBotHost.pas` for explicit multi-room
  instance behavior, verified caller context, deployment cloning, and controller
  integration.
- `NexusTools/BotHost/src/obNXCodexAppServer.pas` and the existing
  `src/protocol/obNXCodexAppServer*.pas` units for the RTTI-modeled
  `bot_control` declaration/call/result and its correlation to the originating
  prompt.
- `NexusTools/BotHost/uiNXBotHostMain.pas` only as required to construct the
  controller, persist controller/catalog configuration, and continue displaying
  the configured default room. No new management UI is required.
- A minimal Bot language definition, catalog fixture, and non-secret deployment
  configuration under `NexusTools/BotHost`.
- BotHost deterministic/module/standalone/live tests and, only where generic
  NexusXMPP behavior changes, the existing NexusXMPP deterministic tests.
- BotHost project search paths and documentation for catalog, authorization,
  environment variables, full controller JID, and live-test setup.

Exact filenames may be adjusted to match discovered ownership while preserving
one real definition for each shared type and the boundaries above.

## Out Of Scope

- Openfire plugins, server modules, database changes, or routing changes.
- Gajim changes, client plugins, special slash commands, or raw stanza tools.
- Human direct-message control admission.
- Sending IQ from the local human path to NexusBot itself.
- General RPC, orchestration, scheduling, delegation, swarm, or permissions
  frameworks.
- General XML RTTI/object binding or free-form JSON protocol objects.
- Separate bot daemons, IPC, or distributed catalogs/registries.
- AI exposure of the remote IQ caller API; the model sees only the local
  `bot_control` tool contract.
- Stopping/destroying active instances through DISMISS or adding a STOP command.
- Autonomous bot selection, dynamic definition installation, provider redesign,
  additional AI providers, persistent memory, voice, files, marketplace, web
  control panel, or a broad GUI redesign.
- Changes to NexusScript grammar/compiler semantics beyond consuming the existing
  engine and adding the minimal Bot language/validator definition and data
  files.
- Compatibility wrappers preserving the current single-room BotHost API; update
  the known call sites to the explicit room contract.

## Staged Implementation Plan

1. **Establish the typed local control contract.**
   Add the operation, authorization, result, bot-state, and completion types.
   Encode the settled idempotency and error categories in tests before adding
   transports. Keep these types independent of XML, JSON, UI, and model wording.

2. **Add the minimal catalog and deployment model.**
   Create the Bot language/validator definition and fixtures using NexusScript,
   compile catalog files with the existing session, extract effective compiled
   values, validate Codex-only entries, and associate canonical names with
   RTTI-persisted deployment bindings. Test valid, invalid, duplicate,
   unavailable, and secret-free persistence cases.

3. **Make one bot instance genuinely multi-room.**
   Reshape join/leave/state/admission/cancellation APIs around explicit room JIDs.
   Preserve full shutdown semantics while proving that leaving one room does not
   disable another. Update the GUI and existing BotHost/live-test call sites to
   pass the configured default room explicitly.

4. **Implement the controller and deterministic executor.**
   Own the catalog and active-instance map, add a narrow injectable instance
   factory/lifecycle seam for deterministic tests, implement reader/operator
   authorization, LIST/STATUS snapshots, INVITE activation stages, DISMISS room
   departure, bounded pending operations, deadlines, shutdown cancellation, and
   exactly-once completion. Do not introduce provider-general orchestration.

5. **Add the human deterministic adapter after routing.**
   Consume admitted prompts, recognize only the settled exact command forms,
   attach verified MUC real-JID authorization and explicit room context, invoke
   the local executor, and render typed results. Prove that ordinary conversation
   still reaches the App Server and that the interpreter contains no mention or
   reply parsing.

6. **Add the structured model tool path.**
   Declare `bot_control` with RTTI/published input and result classes, retain the
   originating prompt's immutable caller/room context through the turn, accept
   only that known dynamic tool, invoke the same executor, and return the typed
   result to Codex. Keep unknown tools declined and add fake-App-Server coverage
   for success, denial, operation failure, malformed arguments, and correlation.

7. **Add the XMPP IQ module and caller API.**
   Implement the four QNames, strict parsing/serialization, responder
   registration, bounded transport correlation, module-command response
   submission, standard error mapping, and typed outbound caller completions.
   Keep operation lifetime, deadlines, cancellation, and semantic completion
   exclusively in the controller. Install discovery on the controller and
   advertise the versioned namespace. Test requests, results, every error
   category, spoofed/unauthorized senders, timeout, capacity, connection loss,
   shutdown, duplicate lifecycle notifications, and exact once-only response
   behavior.

8. **Integrate controller ownership and configuration.**
   Have the GUI application construct one controller, its distinguished NexusBot
   instance, catalog, deployment bindings, and control IQ/disco modules before
   connecting. Persist only non-secret configuration. Ensure orderly shutdown
   completes/cancels pending control operations before destroying instances.

9. **Run live stock-client/server verification and document operation.**
   Extend the existing Openfire test to use ordinary clients, unique resources,
   the permanent `nexus-test@conference.nexus.local` room, and the typed caller
   API. Verify discovery, LIST, STATUS, authorized/unauthorized INVITE, observed
   join, idempotent INVITE, DISMISS, observed leave, and ordinary addressed MUC
   commands without test-only protocol construction. Document the catalog file,
   deployment bindings, environment variables, allowlists, and full controller
   JID.

## Sub-Agent Delegation

Implementation remains local to Main Codex. This plan does not authorize
spawning, resuming, messaging, or delegating to sub-agents. Plan approval and
implementation approval do not grant sub-agent permission; the human owner must
request sub-agent use explicitly in the current conversation.

## Verification Plan

- Build the focused BotHost test module:

  ```powershell
  lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
  ```

- Run its BotHost suites through the existing test host, including catalog,
  multi-room instance, executor, authorization, interpreter, model tool, IQ
  adapter, discovery, timeout, capacity, and exactly-once completion cases:

  ```powershell
  output\NexusTestHost\nxtest_host.exe `
    output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll `
    run-all
  ```

- Rebuild and run the standalone fake-App-Server process test to prove the
  RTTI tool-call/result boundary and ordinary prompt behavior across real pipes.
- Rebuild the NexusScript test module and run its suites to prove the Bot
  language/validator definition and catalog fixtures compile without changing
  existing language behavior.
- If the implementation changes generic NexusXMPP units, rebuild and run the
  complete deterministic NexusXMPP suite, not only the bot-control tests.
- Rebuild the application:

  ```powershell
  lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
  ```

- Focused searches must show:
  - no bot-control XML outside `obNXXMPPBotControl.pas` and its tests;
  - no free-form JSON creation/parsing for `bot_control`;
  - no IQ self-call in the human path;
  - no password value persisted in catalog or JSON configuration;
  - no remaining no-argument BotHost join/leave call sites;
  - no duplicate mention/reply/address parsing in the control interpreter;
  - no unconditional dynamic-tool decline for the recognized `bot_control` tool.
- Run the Openfire live test with credentials supplied only by environment
  variables. Observe the managed bot join and leave the permanent room from a
  stock Gajim client, and capture typed caller results for discovery and all four
  operations.
- Manually confirm in the GUI that normal conversation still works, deterministic
  control commands return concise results, semantic phrasing completes through
  the model tool, the default room remains visible, and activity text remains
  selectable/copyable.
- Run `git diff --check` and inspect the final diff for unrelated changes.
- After approved implementation and verification, create the required fresh
  source archive with `scripts\New-NexusSourceArchive.ps1` before reporting
  completion.

## Risks And Questions

- The current one-room host state and global acceptance flag must be corrected
  before multi-room control is reliable. Treating that as presentation-only
  would leave real cross-room cancellation/admission defects.
- Incoming IQ stanzas are short-lived connection-thread objects. Retaining a
  stanza or sending a deferred response directly from another thread would
  violate current ownership; copied request data plus submitted module response
  operations is mandatory.
- The IQ transport-correlation record must not acquire its own deadline,
  cancellation, or completion decisions. Those belong solely to the controller;
  otherwise two pending-state machines could race or produce contradictory
  outcomes.
- Semantic human control requires a real structured App Server tool exchange.
  Parsing a final assistant answer, embedding JSON in prose, or exposing raw IQ
  to the model is not an acceptable shortcut.
- Catalog definition validity, deployment availability, active instance state,
  XMPP connectivity, and room membership are deliberately separate. LIST/STATUS
  tests must prevent future collapse into one status flag.
- A full controller JID/resource must be stable or discovered from trusted
  presence before remote calls. Bare-JID routing is not accepted as the control
  endpoint contract.
- Live Openfire testing proves interoperability in the current environment but
  does not replace deterministic malformed-input, authorization, timeout, and
  exactly-once tests.
- No unresolved human decision is required before implementation. If repository
  inspection during implementation disproves a contract above, stop and report
  the conflict rather than silently redesigning the control plane.

## Approval Gate

This plan is a planning artifact only. No implementation, build, test, launch,
archive, or source change begins until the human owner explicitly authorizes
implementation. Approval to implement does not authorize sub-agent use.
