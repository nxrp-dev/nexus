# Nexus XMPP BotHost

NexusBotHost is a visible NexusUI application that hosts a catalog of
provider-backed bots on NexusXMPP. The distinguished `NexusBot` instance
receives ordinary addressed MUC conversation and owns the control endpoint for
the catalog.

Bot behavior is defined by `catalog/Bots.nxscript` using the small Bot language
in `catalog/Bot.Language.nxscript`. The initial behavioral contract contains
only `Provider`, `Model`, and `Instructions`. Provider names are resolved by a
case-sensitive BotHost registry; `Codex` and `OpenAI` are registered providers.
Deployment data is separate RTTI-persisted configuration. Catalog loading
rejects an unregistered provider before publishing any bot entries.

Catalog loading is atomic. Compilation, Bot-language validation, bot-name
uniqueness, and static deployment bindings must all succeed before any entries
are published. Invalid catalog documents are rejected as a whole with collected
diagnostics; they are not retained as partially available bots. Connectivity,
authentication, provider startup, and other operational failures remain runtime
status rather than catalog validity.

The registered providers are `Codex` and `OpenAI`. `OpenAI` uses the Responses
API through WinHTTP on Windows, sends non-streaming requests, and keeps only the
previous response ID in memory for conversation continuity. It sends
`store: true`; the response chain therefore uses OpenAI-retained response state
while BotHost writes no conversation history to disk. Streaming, tools, and a
non-Windows OpenAI transport are not part of this milestone.

## Control plane

LIST, STATUS, INVITE, and DISMISS share one typed operation, authorization, and
controller implementation. They can arrive through:

- exact addressed room commands: `list bots`, `status <bot>`, `info <bot>`,
  `invite <bot>`, and `dismiss <bot>`;
- the RTTI-modeled Codex `bot_control` dynamic tool for conversational requests;
- XMPP IQ requests in `urn:nexus:bot-control:1`.

The existing BotHost router remains the sole owner of MUC admission. It accepts
live replies, `@Nick`, and Gajim's case-insensitive `Nick, ` addressing. Human
control authorization uses only a room-disclosed real bare JID; nicknames and
occupant JIDs are not identities. Direct-message control is not supported.

The IQ wire operations are:

```xml
<bots xmlns='urn:nexus:bot-control:1'/>
<status xmlns='urn:nexus:bot-control:1' bot='NexusBot'/>
<invite xmlns='urn:nexus:bot-control:1' bot='NexusBot'
        room='room@conference.example'/>
<dismiss xmlns='urn:nexus:bot-control:1' bot='NexusBot'
         room='room@conference.example'/>
```

The first two use IQ `get`; the latter two use IQ `set`. The control module also
provides a typed Pascal caller API and advertises the namespace through
XEP-0030. The controller owns explicit token cancellation and exactly-once
semantic completion. It owns no deadline, timer, or polling thread. The IQ
module retains only transport data needed to send the eventual response and
cancels accepted controller work when that transport is permanently lost.
Codex App Server request deadlines remain in the Codex provider process loop;
XMPP connection and outbound IQ deadlines remain in NexusXMPP. A pending
controller operation otherwise ends from an observed lifecycle result, explicit
token cancellation, or controller shutdown.

Controller shutdown closes admission, disconnects host notifications, and
synchronously quiesces every active host before it releases pending operations
or destroys hosts. Host shutdown joins both its XMPP connection and provider;
the Codex provider joins its App Server worker while controller callbacks and
IQ transport correlations remain alive.
After all producers have stopped, pending cancellation and object destruction
are synchronous; neither controller nor module destruction polls for ownership
to change.

The controller critical section protects only its active/pending collection
membership, pending claim state, token allocation, shutdown admission, and
copied deployment values. Authorization, catalog policy, host creation and
lifecycle calls, state snapshots, completion callbacks, shutdown behavior, and
object destruction all execute after that guard has been released. An active
host removed from the controller is retained until outstanding users release
it, then destroyed outside the critical section.

The GUI owns the editable persisted controller configuration. The controller
receives a private copy and accepts complete deployment updates through its
explicit update method; GUI controls never mutate the controller's object graph
directly.

INVITE and DISMISS are idempotent. INVITE completes after the bot is joined.
DISMISS leaves only the requested room; it does not stop the provider,
disconnect XMPP, or disturb other room memberships.

## Build and deterministic tests

From the repository root:

```powershell
lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
fpc -B -MObjFPC -Sh -FUoutput\NexusBotHostTests\fake-units -FEoutput\NexusBotHostTests\bin NexusTools\BotHost\tests\FakeCodexAppServer.lpr
$env:NEXUS_BOTHOST_FAKE_APP_SERVER = (Resolve-Path output\NexusBotHostTests\bin\FakeCodexAppServer.exe)
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost
```

The focused suite covers routing, copied observable multi-room state, the
case-sensitive provider registry, fail-fast catalog/provider association, typed
Codex App Server protocol objects, authorization, idempotency,
capacity/cancellation, exact human commands, IQ dispatch/serialization/error
mapping, discovery, the typed IQ caller, claimed operation shutdown, final
provider worker quiescence, and the real-pipe Codex App Server process
integration.

The `NexusBotHost.AppServerProcess` integration test verifies split JSONL
frames, independent stderr,
unknown notifications, authority decline, the complete thread/turn lifecycle,
the RTTI-declared `bot_control` schema, a typed tool call, and its typed result
across real pipes. Because App Server dynamic tools are experimental, BotHost
declares the typed `experimentalApi` initialize capability before starting a
thread with `dynamicTools`. If `NEXUS_BOTHOST_FAKE_APP_SERVER` is not set, that
test is reported as skipped by the Nexus test framework.

## Configuration and secrets

The GUI saves its distinguished-host settings under the current user's
application-data directory in `NexusBotHost\NexusBotHost.json`. Controller
configuration is saved beside it as `NexusBotController.json`. It contains:

- `CatalogFile` and the stable `ControllerFullJID`;
- bounded operation capacity;
- normalized reader and operator bare-JID allowlists;
- deployment bindings associating canonical catalog names with XMPP identity,
  resource, nickname, endpoint/TLS data, provider-specific deployment data, and
  a password-environment-variable name. The Codex binding uses
  `CodexExecutable` and `RuntimeDirectory`; the OpenAI binding uses
  `OpenAIAPIKeyEnvironmentVariable`.

No password value is persisted. The distinguished host defaults to the variable
name below:

```powershell
$env:NEXUS_BOT_XMPP_PASSWORD = '<password>'
```

Each additional bot binding should use its own environment variable. The
default second binding expects:

```powershell
$env:NEXUS_OPENAI_BOT_XMPP_PASSWORD = '<openfire-password>'
$env:OPENAI_API_KEY = '<OpenAI-API-key>'
```

Set those variables before issuing `invite OpenAIBot` through the existing
control path. The API key value is read only by the OpenAI provider worker and
is never persisted in configuration or placed in its typed JSON request.

Use a
dedicated runtime directory outside a source repository. The host starts an
ephemeral Codex thread with `sandbox = read-only`, `approvalPolicy = never`, and
restrictive developer instructions. Existing Codex authentication is reused;
no Codex or OpenAI credential value is stored.

For Openfire with a private CA, set `CAFile` to the trusted CA PEM used by the
NexusXMPP live tests. Trust the issuer rather than disabling verification.

## Installed App Server contract

The binding was verified against `codex-cli 0.153.0`. Verify upgrades:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File NexusTools\BotHost\scripts\Test-CodexAppServerSchema.ps1 -CodexExecutable <path-to-codex.exe>
```

The expected stable-v2 schema fingerprint and methods are recorded in
`schema/codex-app-server-contract.txt`. Schema drift is a review failure; JSON
protocol objects are modeled through RTTI and published properties, not
free-form JSON interpretation.

## Live Openfire verification

The live tests are registered as `NexusBotHostLive.OpenfireCodex` and
`NexusBotHostLive.OpenfireOpenAI` in `NexusBotHostTestModule.dll`. Configure
the desired test through environment variables, then invoke it through
`NexusTestHost`.

Codex:

```powershell
$env:NEXUS_BOTHOST_LIVE_OPENFIRE = '1'
$env:NEXUS_BOTHOST_CODEX_EXECUTABLE = '<path-to-codex.exe>'
$env:NEXUS_BOTHOST_RUNTIME_DIRECTORY = '<runtime-directory>'
$env:NEXUS_BOTHOST_MODEL = '<model>'
$env:NEXUS_BOTHOST_BOT_JID = '<bot-jid>'
$env:NEXUS_BOTHOST_BOT_PASSWORD_ENVIRONMENT_VARIABLE = 'NEXUS_BOT_XMPP_PASSWORD'
$env:NEXUS_BOT_XMPP_PASSWORD = '<bot-password>'
$env:NEXUS_BOTHOST_OBSERVER_JID = '<observer-jid>'
$env:NEXUS_BOTHOST_OBSERVER_PASSWORD = '<observer-password>'
$env:NEXUS_BOTHOST_CA_FILE = '<ca-file>'
$env:NEXUS_BOTHOST_ENDPOINT_HOST = '<host>'
$env:NEXUS_BOTHOST_ENDPOINT_PORT = '<port>'
$env:NEXUS_BOTHOST_ROOM_JID = '<room-jid>'
$env:NEXUS_BOTHOST_CATALOG_FILE = '<catalog-file>'
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-test NexusBotHostLive.OpenfireCodex
```

OpenAI uses the shared Openfire endpoint, CA, room, and observer variables from
the preceding example, plus:

```powershell
$env:NEXUS_BOTHOST_LIVE_OPENAI = '1'
$env:NEXUS_BOTHOST_OPENAI_MODEL = '<available-OpenAI-model>'
$env:NEXUS_BOTHOST_OPENAI_BOT_JID = 'test2@nexus.local'
$env:NEXUS_BOTHOST_OPENAI_BOT_PASSWORD_ENVIRONMENT_VARIABLE = 'NEXUS_OPENAI_BOT_XMPP_PASSWORD'
$env:NEXUS_BOTHOST_OPENAI_API_KEY_ENVIRONMENT_VARIABLE = 'OPENAI_API_KEY'
$env:NEXUS_OPENAI_BOT_XMPP_PASSWORD = '<bot-password>'
$env:OPENAI_API_KEY = '<OpenAI-API-key>'
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-test NexusBotHostLive.OpenfireOpenAI
```

The live test uses unique XMPP resources and ordinary client/module APIs. It
verifies IQ LIST and STATUS, DISMISS plus idempotent DISMISS, observed leave,
INVITE plus idempotent INVITE, observed rejoin, and an ordinary addressed MUC
conversation in the permanent room. Credentials and generated resources are
not written to the repository. Each live test is skipped unless its own switch
is set to `1`.
