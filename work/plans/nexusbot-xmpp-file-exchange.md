# Work Plan: NexusBot XMPP File Exchange

## Inputs

- Source request:
  `C:\Users\kcollins\Downloads\nexusbot-xmpp-file-exchange-workplan-request-final.md`.
- Related discussion: file exchange must be a complete XMPP-to-provider and
  provider-to-XMPP capability, use the existing registered unit-test
  infrastructure, preserve typed RTTI data contracts, and must not create a
  generic task, HTTP, artifact, or permissions framework.
- Repository guidance: root `AGENTS.md`,
  `NexusLib/net/src/xmpp/AGENTS.md`, `NexusTools/BotHost/AGENTS.md`,
  `.ai/standards/pascal.md`, `.ai/protocols/architecture-change.md`, and
  `.ai/protocols/codex-workplan-format.md`.
- Current source under `NexusLib/net/src/xmpp/` and
  `NexusTools/BotHost/`, including the checked-in Codex App Server schema and
  the current Synapse/OpenSSL HTTP implementation.
- Authoritative protocol/API references verified during planning:
  [XEP-0363 1.2.0](https://xmpp.org/extensions/xep-0363.html),
  [XEP-0446 0.2.0](https://xmpp.org/extensions/xep-0446.html),
  [XEP-0447 0.3.1](https://xmpp.org/extensions/xep-0447.html),
  [XEP-0066 1.6](https://xmpp.org/extensions/xep-0066.html),
  [XEP-0300 1.0.0](https://xmpp.org/extensions/xep-0300.html),
  [XEP-0428 0.2.1](https://xmpp.org/extensions/xep-0428.html), and the
  OpenAI [Files](https://platform.openai.com/docs/api-reference/files) and
  [Responses](https://platform.openai.com/docs/api-reference/responses)
  API contracts.

## Summary

Add standards-based, bounded file exchange without changing the existing
ownership of XMPP protocol semantics, BotHost routing, or provider work.
NexusXMPP will parse and produce typed self-contained XEP-0447 file shares and
negotiate XEP-0363 upload slots. Each `TNXBotHost` will own one serialized,
bounded HTTP transfer worker and a private exchange directory. Accepted inbound
files will be downloaded and verified before the typed prompt is submitted to
the provider. Authorized outbound artifacts will be uploaded, then announced
through ordinary direct or MUC messages.

The provider-neutral prompt will carry owned attachment objects, never raw
bytes or provider file handles. Codex will receive native local image/audio
items where its installed schema supports them and a narrow attachment-read
tool for other staged documents. OpenAI will upload the same staged bytes to
the Files API with purpose `user_data` and reference the returned `file_id`
through typed Responses input objects.

## Verified Findings

- `TNXXMPPMessage` is the common typed parser used for direct, MUC, MAM,
  carbon, and forwarded message contexts. Direct and MUC modules currently
  suppress a message callback when body, subject, and reply are all absent.
- `TNXXMPPMessageModule` and `TNXXMPPMUCModule` already own ordinary message
  construction, origin/reply semantics, bounded module commands, and
  stream-management replay policy.
- `TNXXMPPRequestManager` already owns bounded IQ correlation, timeouts,
  expected-sender validation, cancellation, and exactly-once terminal
  completion. Upload slots need no second request mechanism.
- `TNXXMPPDiscoModule` retains identities, features, items, and canonicalized
  data-form strings. That canonical form supports capability hashing but loses
  the typed `FORM_TYPE`/field/value relationship required to read the
  XEP-0363 `max-file-size` field.
- `TNXXMPPOpenSSL` supplies SHA-256 for in-memory data but has no streaming
  file-hash operation.
- Synapse `THTTPSend` supports caller-supplied input and output streams,
  verified OpenSSL TLS settings, timeouts, and cross-thread `Abort`. It does
  not automatically provide the destination policy, redirect policy, size
  bounds, or XEP-0363 header validation this feature requires.
- `TNXBotHost` owns its XMPP client, MUC and direct-message modules, provider,
  routing callbacks, and observable state. Direct messages and room messages
  currently create and submit a prompt synchronously from the XMPP callback.
- `TNXBotHostRouter.Admit` owns room-addressing policy and currently requires
  nonempty prompt text. Direct routing also rejects an empty body before a
  prompt can be created.
- `TNXBotPrompt` owns only text and delivery/caller identity today. Its
  `Clone` method is the provider queue ownership boundary.
- `TNXBotProvider` has prompt/state events but no typed outbound artifact-send
  request. BotHost contains no provider-name switching and must remain that
  way.
- `TNXBotDeploymentBinding` and `TNXBotHostConfig` are RTTI-persisted typed
  configuration objects. `RuntimeDirectory` is specifically used as the Codex
  process working directory and is not a provider-neutral exchange root.
- The current Codex App Server schema contains `localImage` and `localAudio`
  user-input variants but no generic local-document variant. The current
  Pascal model emits text input only, and Codex bot instructions prohibit file
  access generally.
- The current OpenAI provider sends a scalar string as Responses `input`; its
  existing provider worker correctly isolates the blocking OpenAI HTTP request.
  The current OpenAI Files API accepts `purpose=user_data`, supports bounded
  expiration, and returns a `file_id` that Responses accepts in an
  `input_file` content item.
- All deterministic BotHost tests are registered through
  `NexusBotHostTestModule`; NexusXMPP deterministic tests use
  `NexusNetXMPPTests.lpr`. No standalone test executable is needed or allowed.

## Architecture Problem

The current message pipeline has no typed representation or retained ownership
for a file. An XMPP URL cannot safely be handed directly to a provider: it has
not passed routing, destination policy, transfer bounds, hash verification, or
local ownership. Conversely, a provider path cannot safely be uploaded because
the model naming a path is not authority to disclose that host file.

The missing boundary is a small BotHost-owned artifact exchange:

```text
typed XMPP share
    -> existing BotHost routing
    -> bounded host-owned download/staging
    -> owned provider-neutral prompt attachment

authorized BotHost artifact
    -> typed provider file-send request
    -> XEP-0363 slot and bounded upload
    -> typed XEP-0447 direct/MUC message
```

HTTP GET and PUT are the only new product operations that justify a worker.
They block while XMPP stanza processing and provider activity must continue.
Parsing, routing, IQ completion, timeouts, callbacks, state transitions,
cleanup decisions, and provider handling remain on their existing owners and
do not acquire new threads.

## Target Contract

### Protocol baseline and wire contract

- Pin XEP-0363 1.2.0 (`urn:xmpp:http:upload:0`) for service discovery,
  `max-file-size`, slot requests, slot responses, allowed PUT headers, and
  stanza errors. Omit an explicit upload purpose: XEP-0363 defines `message` as
  the default, while purpose advertisement and requests are optional.
- Pin XEP-0446 0.2.0 (`urn:xmpp:file:metadata:0`) for name, media type,
  declared size, description, and XEP-0300 hashes.
- Pin XEP-0447 0.3.1 (`urn:xmpp:sfs:0`) and implement only self-contained
  `<file-sharing>` elements whose `<sources>` contains one or more supported
  `url-data` entries. A source arriving later through XEP-0367 is not accepted
  as attachment completion in this milestone.
- Pin XEP-0300 1.0.0 (`urn:xmpp:hashes:2`) for hash representation. Generate
  and verify SHA-256 using a streaming OpenSSL operation. Preserve other
  well-formed algorithm/value pairs as typed metadata, but do not claim to
  verify algorithms the implementation does not support. If a valid SHA-256
  is supplied, a mismatch fails the attachment. Outbound shares always include
  SHA-256.
- Pin XEP-0428 0.2.1 for an SFS fallback marker. Outbound file messages use the
  GET URL as the fallback body and include the matching XEP-0066 1.6
  `jabber:x:oob` URL recommended by XEP-0447. This is the only XEP-0066 use in
  the milestone.
- Recognize XEP-0066 only as compatibility fallback accompanying a modern SFS
  share. A matching OOB URL is fallback, not a duplicate attachment. If a
  conflicting OOB URL coexists with SFS, SFS remains authoritative and the OOB
  URL is ignored for retrieval. An OOB-only message is not an attachment and
  never authorizes a download.
- The XEP-0447 URL source element uses
  `http://jabber.org/protocol/url-data` as required by that wire shape. The
  implementation supports only its `target` URL here; it does not add general
  XEP-0103/0104 request-header or arbitrary scheme support.
- One message may contain multiple self-contained `<file-sharing>` elements.
  Every element in a multi-file message must have a nonempty unique SFS `id`.
  A single file may omit it; Nexus assigns an internal attachment identity.
- Within one attachment, try supported URL sources in wire order. Apply the
  complete URL policy, transfer bounds, actual-size checks, and hash
  verification independently to each source; delete its partial file before
  trying the next source and stop at the first complete success. Fail the
  attachment only after every supported source has failed.
- Incoming recognized SFS fallback ranges are removed from `DisplayBody`, as
  reply fallback already is, while `Body` retains the original wire text. A
  file-only fallback body therefore becomes empty display text but still
  produces an attachment-bearing message callback.
- Message/origin/reply identity remains on the containing ordinary message.
  Direct and room file responses use that existing identity model. File bytes
  never enter an XMPP stanza.

### NexusXMPP ownership

- Add pure shared typed file metadata/source/hash/slot records in
  `tpNXXMPPFileTypes.pas`.
- `TNXXMPPMessage` owns the parsed attachment collection for the lifetime of
  the message callback. The same parser operates inside live, MUC history,
  MAM, carbon, and forwarded contexts; it does not decide whether to download.
- Add a narrow `TNXXMPPFileSharingModule` that owns upload-service discovery,
  typed slot negotiation, and construction/submission of file-share messages.
  It performs no HTTP and owns no local files.
- Narrowly reshape `TNXXMPPDiscoInfo` so typed data forms retain form type,
  fields, and ordered values while capability hashing derives the same
  canonical string from the typed form. The existing disco module remains the
  one discovery mechanism. The file module receives request-specific typed
  disco completions rather than taking over a global callback.
- Slot IQ operations use the existing request manager, expected upload-service
  sender, configured IQ capacity, and request timeout. A malformed or spoofed
  slot never reaches the HTTP worker.
- For every slot PUT header, first strip every CR or LF from its name and value,
  then compare the resulting name case-insensitively with `Authorization`,
  `Cookie`, and `Expires`. Retain only those allowed headers in their original
  relative order, including duplicates. Ignore every other resulting header
  name and never include it in the HTTP request; an unknown header does not
  invalidate an otherwise usable slot. The live slot object owns the retained
  allowed-header secrets until its transfer ends and never logs them.
- Add streaming SHA-256 to the existing XMPP OpenSSL owner rather than adding
  another crypto dependency.

### BotHost exchange owner

- Add `TNXBotFileExchange`, owned one-to-one by each active `TNXBotHost`.
- The exchange owns:

  - its configured exchange root;
  - a registry of authorized staged/provider-produced artifacts;
  - one bounded input queue;
  - at most one current HTTP transfer;
  - one file-transfer worker;
  - cancellation tokens/flags and transfer completion callbacks.

- The worker exists only because Synapse HTTP GET/PUT blocks while XMPP and
  provider progress must continue. Transfers for one host are serialized;
  separate hosts remain independent.
- The queue synchronization protects only add/extract/swap of owned transfer
  records and worker wake/stop state. It is never held across HTTP, XMPP IQ,
  provider calls, callbacks, waits, shutdown, or file deletion.
- XMPP upload-slot discovery/negotiation happens through module commands and
  callbacks. Only the resulting valid slot is handed to the exchange worker.
  The XMPP connection thread never waits for HTTP.
- Completion returns to `TNXBotHost` as one owned event/callback object. Host
  policy decides whether a prompt is now ready or an outbound share may be
  sent. A completion bearing a cancelled/stale operation identity is discarded
  and cannot resurrect work.
- Shutdown stops admission, marks current work cancelled, calls Synapse
  `Abort` for an active transfer, wakes and joins the one worker, drains owned
  records, deletes partial files, then destroys registry and directory state.
  There is no polling for quiescence.

### Configuration and fixed defaults

Add the following published properties to `TNXBotDeploymentBinding` and the
runtime copy in `TNXBotHostConfig`; `ApplyDeployment`, validation, path
resolution, examples, and tests must cover them:

| Property | Default | Meaning |
| --- | ---: | --- |
| `ExchangeDirectory` | required per deployment | Provider-neutral BotHost-owned exchange root, resolved relative to the controller JSON file. |
| `FileMaximumBytes` | 16 MiB | Maximum declared and actual size of one inbound or outbound file. |
| `FileTransferCapacity` | 8 | Maximum queued plus active transfer records per host. |
| `StagedFileCapacity` | 32 | Maximum valid artifacts retained by one host session. |
| `StagedMaximumBytes` | 64 MiB | Maximum aggregate valid staged artifact bytes per host session. |
| `FileTransferTimeoutMS` | 120000 | Per HTTP GET or PUT timeout. |
| `TrustedFileOrigins` | empty | Exact additional HTTPS origins allowed to resolve to otherwise rejected private destinations. |

NexusXMPP also enforces protocol-shape constants independent of deployment
configuration: at most 8 attachments per message, 4 URL sources and 4 hashes
per attachment, 4096 UTF-8 bytes per URL/description, 255 UTF-8 bytes per
filename/media type/share ID, and 64 KiB total recognized file metadata per
message. These bounds prevent an oversized stanza model before BotHost config
is involved.

The effective outbound file maximum is the smaller of `FileMaximumBytes` and
the discovered service's advertised `max-file-size`. Absence of an advertised
maximum does not remove the local maximum. Actual streamed byte counts are
authoritative; `Content-Length`, XMPP size, filename extension, MIME type, and
model claims are only metadata/checks.

An exact trusted origin is canonical `https://host:port` (default HTTPS port
normalized to 443), with no path, query, fragment, wildcard, credentials, or
subdomain implication. Duplicate origins are rejected during configuration
validation.

### Inbound URL and HTTP policy

- Accept retrieval candidates only from typed SFS `url-data`. Matching OOB is
  retained only as compatibility fallback and OOB-only messages do not create
  retrieval candidates. Never scan ordinary body text for URLs.
- Require HTTPS, a DNS hostname, and no embedded user information. Reject
  loopback, unspecified, multicast, link-local, private-use, carrier-grade NAT,
  documentation/test, host-local, and otherwise non-public IPv4/IPv6 targets
  by default.
- Parse and canonicalize the origin, resolve the destination before the
  connection, and reject the request if any selected address is prohibited.
  An exact configured trusted origin may waive only the public-address rule;
  TLS certificate/hostname verification, byte limits, and redirect checks
  remain mandatory.
- Follow at most three inbound GET redirects. Resolve relative `Location`
  values and reapply scheme, credential, origin, DNS/address, TLS, timeout, and
  byte policy before each new request. Do not carry authentication/cookie
  headers across inbound downloads.
- Never follow an outbound slot PUT redirect. A 3xx PUT is a transfer failure,
  and slot headers are never sent to a second origin.
- Use `TFileStream` as Synapse input/output. A bounded output stream stops an
  inbound download as soon as actual bytes exceed the configured maximum.
  Downloads go first to a unique partial name and become valid artifacts only
  after size/hash verification and atomic rename.
- HTTP diagnostics distinguish URL-policy rejection, TLS/connect failure,
  timeout/cancellation, non-success status, early EOF, over-limit content,
  slot PUT rejection, and hash mismatch. They do not reveal local paths,
  presigned URLs, or headers to XMPP users.

### Staging and artifact authorization

- Never combine the remote name with a local directory. Create a unique
  opaque filename under `ExchangeDirectory`; retain the original name only as
  typed metadata. Reject NUL/control data and bound the metadata; display-name
  sanitization replaces separators, traversal tokens, drive/device syntax,
  and invalid platform characters but is not used as path authority.
- `TNXBotFileExchange` is the only owner allowed to register an artifact for
  outbound transfer. A registry entry contains an opaque artifact ID, canonical
  local path proven beneath the exchange root, original display name, media
  type, actual size, hash, origin, and lifetime state.
- Model/provider requests name the opaque artifact or attachment ID. An
  arbitrary filesystem path is rejected before any slot is requested.
- Successfully admitted inbound attachments remain available for the lifetime
  of the active BotHost/provider session so later turns can refer to them.
  The configured count/aggregate limits bound that retention; capacity failure
  rejects new work rather than silently evicting referenced files.
- Partials and prompt-only artifacts that fail or are cancelled before provider
  submission are deleted immediately. Provider-created registered artifacts
  and successful inbound artifacts are deleted on explicit session cleanup,
  provider stop/restart, or BotHost shutdown after all prompt/provider leases
  are released.

### Prompt contract and inbound state flow

- Add provider-neutral attachment types in `tpNXBotFileTypes.pas` and make
  `TNXBotPrompt` own a deep-cloned attachment collection. Each attachment has
  a stable neutral ID, original filename, authorized artifact ID, staged path
  exposed read-only to the provider adapter, media type, actual size, hash,
  SFS ID/disposition, and source metadata. It never carries bytes or a provider
  file handle.
- `ModelInput` may list attachment names/IDs/sizes deterministically for human
  context, but provider code consumes the typed collection directly.
- Extend the existing room router with attachment presence. The existing
  mention/comma/reply/implied decision remains authoritative. An explicitly
  addressed attachment message is accepted even when the stripped display body
  is empty; an unaddressed room attachment is observed normally but is not
  downloaded and does not wake a bot.
- A direct typed file share is intrinsically addressed and may contain text or
  be file-only.
- Accepted inbound flow is:

  1. NexusXMPP produces one typed message with attachment metadata.
  2. BotHost applies direct or existing room routing before any network fetch.
  3. BotHost allocates one pending prompt operation and reserves queue/staging
     capacity for every required attachment.
  4. The exchange serially downloads and verifies each attachment.
  5. When every attachment succeeds, BotHost attaches the resulting artifact
     references and submits the prompt once to the provider.
  6. Any attachment failure cancels the remaining transfers, releases partial
     state, and sends one concise deterministic host-level failure without
     consuming a provider turn.

- MUC history, MAM, carbon, and forwarded parsers retain typed attachments, but
  current BotHost live-prompt policy remains unchanged. Archived/history
  delivery never initiates a new download. A carbon/forwarded message is only
  actionable if its current existing delivery classification already admits it
  as a live prompt.
- Prompt cancellation, room loss, XMPP disconnect, provider stop, and shutdown
  mark the pending operation terminal. Downloads may finish physically after
  the semantic cutoff, but their completion deletes the partial/result and
  cannot submit the provider prompt.

### Provider-neutral outbound contract

- Add one typed provider event/request at the `TNXBotProvider` boundary:
  artifact/attachment ID, originating prompt identity and delivery context,
  optional safe description, and an exactly-once completion callback/result.
- `TNXBotHost` is the sole owner of authorization, slot acquisition, transfer,
  and XMPP delivery lifetime. Providers own only their request until completion.
  BotHost validates the artifact ID before discovery or upload.
- An outbound room request returns through the prompt's room. A direct request
  returns to the prompt sender and carries the compatible reply ID. This first
  implementation does not give providers arbitrary unsolicited recipient JIDs.
- After a successful PUT, BotHost asks NexusXMPP to send an SFS message through
  the existing MUC/direct module path. It includes file metadata, SHA-256,
  self-contained GET source, origin ID, reply identity where applicable, the
  GET URL body fallback, XEP-0428 indication, and matching XEP-0066 OOB.
- If XMPP disconnects after slot acquisition or upload but before the share
  message is accepted by the XMPP command queue, report an outbound delivery
  failure. Do not reuse a stale presigned PUT URL or claim the recipient saw the
  file.
- Bot-to-bot exchange is not special: the sending BotHost emits the same XMPP
  share and the receiving BotHost applies the same typed parse, routing,
  download, and provider mapping. There is no controller channel or shared-path
  shortcut.

### Codex provider adaptation

- Extend the RTTI Pascal model to match the installed App Server schema's
  `localImage` and `localAudio` variants. Map staged image/audio attachments to
  those native local inputs and always use the BotHost-owned staged path.
- The installed schema has no generic local-document item. Add one narrow
  dynamic `read_attachment(attachment_id, offset, maximum_bytes)` tool
  alongside `bot_control`. It accepts only an attachment ID from the active
  prompt plus a zero-based byte offset and requested byte count. The provider
  resolves that ID against the active prompt collection and returns bounded
  textual content from the exact staged artifact; it does not accept paths,
  URLs, or artifact IDs from other prompts.
- `read_attachment` supports incremental UTF-8 text/code reading and caps one
  call at 64 KiB regardless of the requested maximum. Its typed result contains
  attachment ID, total bytes, returned offset, returned bytes, next offset,
  whether more remains, and content. Returned text never ends inside a UTF-8
  code point, while offsets remain byte-based and deterministic. A non-text
  attachment without a native App Server mapping returns a typed
  unsupported-media result rather than pretending Codex consumed it.
- Revise the bot instructions only enough to permit native prompt attachments
  and `read_attachment`; retain read-only sandbox, no approvals, no arbitrary
  command/file/network/MCP access, and no general hands authority.
- Add a typed `send_file` dynamic tool taking an active-prompt attachment ID.
  It may relay an approved received artifact through the provider-neutral send
  request. It does not accept a filesystem path. Codex still cannot manufacture
  a new arbitrary file in read-only/no-hands mode; provider-created artifacts
  require a separately registered producer in future work.

### OpenAI provider adaptation

- Replace the scalar Responses `input` model with RTTI-backed heterogeneous
  message/content classes: one user message containing `input_text` plus one
  `input_file` per attachment. Do not construct free-form JSON.
- Add a narrow typed Files API model/executor operation. The existing OpenAI
  provider worker uploads the exact BotHost-staged bytes as multipart form data
  before creating the Response; no second OpenAI thread is added.
- Use Files API purpose `user_data` and `expires_after` anchored at
  `created_at` for 24 hours. Keep returned file IDs in provider-session state
  keyed by neutral attachment ID while the `previous_response_id` chain remains
  active. Delete them on failed prompt setup, chain reset, provider stop, or
  shutdown; expiry is the recovery boundary if explicit deletion cannot
  complete.
- Validate the returned filename/byte count where available, then map the
  returned ID into a typed `input_file.file_id`. Never give OpenAI the original
  XMPP URL and never Base64-embed the file by default.
- Files API upload/download envelopes have their own protocol response-body
  safety bound; it is independent of `AnswerMaximumBytes` and the staged file
  limit. Provider ingestion failure fails the prompt before Responses is called.
- The current OpenAI provider has no function/tool-call implementation. It can
  consume attachments after this work but cannot autonomously request outbound
  file sending. Do not add a generalized tool framework in this milestone.
  BotHost/API callers may still relay an existing approved artifact, and the
  provider-neutral outbound contract remains available to providers with an
  actual request mechanism.

### Error contract

- NexusXMPP reports malformed/duplicate/conflicting SFS metadata, malformed
  OOB fallback, missing sources, malformed upload data forms, spoofed slot
  senders, slot stanza errors, and missing PUT/GET URLs as protocol-specific
  failures. Unknown slot headers are ignored as required by XEP-0363; allowed
  headers are retained only after newline stripping.
- BotHost reports routing/capacity rejection, unsafe URL destination, staging
  failure, actual size overflow, early EOF, hash mismatch, HTTP GET/PUT failure,
  no upload service, service limit rejection, cancellation, stale completion,
  and unauthorized artifact separately in its activity journal.
- Providers report native mapping/ingestion errors separately from transfer
  errors. User-facing XMPP text is concise and contains no local path, secret
  header, presigned URL, credential, stack trace, or private diagnostic.

## Scope

Expected new files:

- `NexusLib/net/src/xmpp/tpNXXMPPFileTypes.pas`
- `NexusLib/net/src/xmpp/obNXXMPPFileSharing.pas`
- `NexusTools/BotHost/src/tpNXBotFileTypes.pas`
- `NexusTools/BotHost/src/obNXBotFileExchange.pas`
- `NexusTools/BotHost/src/protocol/obNXOpenAIFiles.pas`
- focused test units under the existing NexusXMPP and BotHost test trees if
  keeping the tests readable requires them.

Expected existing files to change:

- `NexusLib/net/src/xmpp/obNXXMPPMessage.pas`
- `NexusLib/net/src/xmpp/obNXXMPPMessageFeatures.pas`
- `NexusLib/net/src/xmpp/obNXXMPPMUC.pas`
- `NexusLib/net/src/xmpp/obNXXMPPDisco.pas`
- `NexusLib/net/src/xmpp/obNXXMPPOpenSSL.pas`
- `NexusLib/net/tests/NexusNetXMPPTests.lpr`
- `NexusLib/net/tests/NexusNetXMPPLiveTest.lpr`
- `NexusLib/net/tests/NexusNetXMPPTests.md`
- `NexusTools/BotHost/src/tpNXBotHost.pas`
- `NexusTools/BotHost/src/obNXBotHost.pas`
- `NexusTools/BotHost/src/obNXBotHostRouter.pas`
- `NexusTools/BotHost/src/obNXBotProvider.pas`
- `NexusTools/BotHost/src/obNXBotHostConfig.pas`
- `NexusTools/BotHost/src/obNXBotHostRuntime.pas`
- `NexusTools/BotHost/src/obNXCodexAppServer.pas`
- `NexusTools/BotHost/src/obNXOpenAIProvider.pas`
- `NexusTools/BotHost/src/protocol/obNXCodexAppServerTypes.pas`
- `NexusTools/BotHost/src/protocol/obNXOpenAIResponses.pas`
- `NexusTools/BotHost/tests/NexusBotHostTestModule.lpr`
- focused registered tests and fakes under `NexusTools/BotHost/tests/`
- `NexusTools/BotHost/config/NexusBotController.example.json`
- `NexusTools/BotHost/README.md`

The exact source list may contract during implementation. A newly discovered
need outside these owners is a plan conflict to report before broadening scope.

## Out Of Scope

- XEP-0367 source attachment and split-message completion.
- Jingle, SOCKS5, SI, in-band base64 XMPP transfer, peer-to-peer streams, or
  same-host filesystem shortcuts.
- XEP-0103/0104 behavior beyond the XEP-0447 `url-data target` wire element.
- Encrypted file sharing, thumbnails, previews, content-type sniffing, virus
  scanning, indexing, document libraries, versioning, or persistent artifact
  stores.
- Arbitrary URL extraction from prose and arbitrary provider-named local paths.
- Unsolicited provider-selected recipients or file broadcast authority.
- OpenAI function/tool calling solely to originate outbound files.
- Giving Codex general shell, filesystem, network, MCP, or write access.
- Generic HTTP clients, workers/pools/schedulers, async/task frameworks,
  artifact frameworks, permission frameworks, or controller polling.
- NexusUI changes and standalone test harnesses.
- Product-specific branches for Prosody, Openfire, ejabberd, Gajim, or any
  other XMPP implementation.
- Unrelated provider, XMPP, persistence, or networking cleanup.

## Staged Implementation Plan

### Stage 1: Establish typed XMPP file semantics

1. Add the XMPP file metadata, source, hash, upload-service, slot, and header
   types with explicit ownership and bounds.
2. Extend `TNXXMPPMessage` parsing for self-contained SFS and narrow OOB
   fallback compatibility, while leaving OOB-only messages non-attachment
   traffic. Generalize recognized fallback retention enough to remove SFS
   fallback from `DisplayBody` without disturbing reply fallback.
3. Make direct/MUC message delivery recognize an attachment-bearing message
   with no body, including nested MAM/carbon/history parsing without changing
   live-prompt policy.
4. Add deterministic parser, malformed-input, duplicate, size, namespace,
   fallback, and context tests before adding network transfer behavior.

### Stage 2: Add discovery and slot negotiation

1. Retain typed disco data forms and derive the existing caps canonical form
   from them.
2. Add the file-sharing module's server item/info discovery sequence and
   select a service advertising `urn:xmpp:http:upload:0`; reject ambiguity only
   when no selected service can satisfy the requested size.
3. Parse the advertised `max-file-size` from the XEP-0128 form whose
   `FORM_TYPE` is `urn:xmpp:http:upload:0`.
4. Submit typed slot IQ requests with actual size, filename, and media type,
   omitting the redundant optional purpose; validate sender and URLs, retain
   newline-stripped allowed headers in order, and ignore unknown headers.
5. Add deterministic disco/slot/sender/header/error/limit tests.

### Stage 3: Add the BotHost exchange and inbound pipeline

1. Add persisted exchange configuration, validation, path resolution, and the
   provider-neutral exchange directory.
2. Implement the one-worker exchange owner using streaming Synapse/OpenSSL,
   the exact inbound URL policy, redirect revalidation, bounded temporary
   files, streaming SHA-256, registry authorization, and explicit shutdown.
3. Extend the room router and direct handler to admit attachment-only messages
   correctly and reserve all capacity before starting downloads.
4. Hold accepted prompts in a host-owned pending attachment operation until
   all downloads succeed; converge failure/cancellation/late completion into
   one terminal method.
5. Add registered deterministic BotHost tests using an injectable
   file-transfer-specific executor. Add a small in-process HTTP fixture inside
   the registered suite only where real streaming/redirect behavior must be
   exercised; do not create an executable harness.

### Stage 4: Map attachments into providers

1. Deep-clone neutral prompt attachments through both existing provider queue
   paths.
2. Add typed Codex local image/audio input objects, the active-prompt-only
   `read_attachment` tool, and the attachment-ID-only `send_file` relay tool.
3. Add typed OpenAI Files and heterogeneous Responses input objects, multipart
   streaming upload, provider-session file-ID retention, expiry, and cleanup.
4. Add deterministic Codex wire tests against the fake App Server and OpenAI
   executor tests covering upload, input mapping, chain reuse, cleanup, and
   provider failures without live OpenAI traffic.

### Stage 5: Complete outbound XMPP delivery

1. Add the provider-neutral file-send request/completion event to
   `TNXBotProvider` and wire it once in `TNXBotHost` without provider branches.
2. Authorize the artifact, check local and advertised size, negotiate a fresh
   slot, stream PUT without redirects, and submit the typed SFS message through
   the existing direct/MUC command path.
3. Preserve prompt delivery/reply context and exactly-once completion. Cover
   disconnect between slot/upload/send, cancellation, stale completion, and
   unauthorized path attempts.
4. Prove bot-to-bot behavior by sending the ordinary file-share message through
   the same receive pipeline, not by calling receiver internals.

### Stage 6: Integrate, document, and verify live

1. Update configuration examples and focused NexusXMPP/BotHost documentation
   with pinned revisions, limits, staging lifetime, provider behavior, server
   requirements, and exclusions.
2. Configure the current Prosody POC's standards HTTP-upload module/component
   only if its disco results show the feature is absent. Record the exact
   module/configuration and advertised feature/form values; do not add
   Prosody-specific code.
3. Run the complete deterministic suites, then the controlled human-client,
   outbound, bot-to-bot, oversize, and shutdown live cases.
4. Record live evidence narrowly: one server/client pass proves that
   configuration, not universal interoperability.

## Sub-Agent Delegation

No sub-agent use is authorized. Implementation remains local to the primary
Codex process unless the human owner explicitly authorizes sub-agent use in a
later message. The size of this feature, separable stages, plan approval, and
implementation approval do not grant delegation authority.

## Verification Plan

### Focused source checks

- Confirm BotHost contains no provider-name branch for attachments or outbound
  transfer.
- Confirm no ordinary body URL parser, arbitrary-path upload, XEP-0367,
  controller-global transfer worker, polling loop, worker pool, NexusUI pump,
  or standalone test executable was added.
- Confirm every new JSON request/response/input shape is represented by
  RTTI-backed published Pascal properties rather than free-form JSON assembly.
- Confirm temporary slot URLs/headers, API keys, passwords, and local staging
  paths do not enter logs or user-facing messages.
- Confirm source units contain only the pinned namespaces/features and do not
  advertise algorithms or XEPs not implemented.

### Deterministic builds and tests

From the repository root, clean-build and run the existing registered targets:

```powershell
fpc -B -FuNexusLib\net\src\xmpp -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\fcl-xml -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetXMPPTests\units -FEoutput\NexusNetXMPPTests\bin NexusLib\net\tests\NexusNetXMPPTests.lpr
$env:Path = 'C:\Program Files\Git\mingw64\bin;' + $env:Path
output\NexusNetXMPPTests\bin\NexusNetXMPPTests.exe

lazbuild -B NexusTools\BotHost\NexusBotHost.lpi
lazbuild -B NexusTools\BotHost\tests\NexusBotHostTestModule.lpi
fpc -B -MObjFPC -Sh -FUoutput\NexusBotHostTests\fake-units -FEoutput\NexusBotHostTests\bin NexusTools\BotHost\tests\FakeCodexAppServer.lpr
$env:NEXUS_BOTHOST_FAKE_APP_SERVER = (Resolve-Path output\NexusBotHostTests\bin\FakeCodexAppServer.exe)
output\NexusTestHost\nxtest_host.exe output\NexusBotHostTestModule\x86_64-win64\NexusBotHostTestModule.dll run-suite NexusBotHost
```

NexusXMPP coverage must include valid/invalid SFS, multiple files, OOB and
fallback matching, OOB-only non-attachment behavior, hashes, metadata bounds,
typed disco forms, upload discovery/limits, slot success/error/spoofed sender,
unknown-header ignoring, allowed-header newline stripping and duplicate order,
feature advertisement, and direct, MUC, MAM, carbon, history, and forwarded
contexts.

BotHost coverage must include text/file and file-only DMs, all room addressing
forms, ignored unaddressed room files, prompt clone ownership, provider-submit
ordering, size/capacity/path/URL/redirect/EOF/hash failures, queued/active
cancellation, disconnect/shutdown, partial cleanup, outbound direct/room,
bot-to-bot receipt, ordered source fallback and first-success termination,
unauthorized path rejection, ranged Codex reads including UTF-8 boundaries,
and OpenAI Files/Responses mapping and cleanup.

### Controlled live verification

1. Query Prosody disco info/items and record the selected upload component,
   `urn:xmpp:http:upload:0`, and advertised `max-file-size`.
2. From an ordinary available XMPP client, send a small text/code file with
   text and then file-only to an addressed bot. Verify the staged file's actual
   size/hash and that the active provider can quote a deterministic fact from
   its contents.
3. Have Codex relay that approved attachment back to the room/direct sender and
   verify the client receives a usable SFS/OOB file share.
4. Send/relay an approved artifact from BotHost A to BotHost B over XMPP and
   verify provider B consumes the independently downloaded bytes.
5. Exercise local and service oversize rejection and record the bounded,
   non-secret error.
6. Disconnect XMPP and terminate BotHost during queued and active transfers;
   verify no hang, provider resurrection, accepted partial, or orphan process.
7. If another configured live server does not advertise XEP-0363, record a
   clean `no upload service` result rather than adding a server-specific path.

### Final repository checks

- Run `git diff --check`.
- Review the final diff for ownership, lifecycle, thread justification, and
  absence of unrelated cleanup.
- After approved implementation and successful verification, create the normal
  architecture archive checkpoint with `scripts\New-NexusSourceArchive.ps1`.

## Risks And Questions

- XEP-0446 and XEP-0447 remain Experimental. Their exact pinned wire shapes
  must not be silently changed when upstream revisions move.
- XEP-0414's broader algorithm set is Deferred and the current Nexus/OpenSSL
  surface supports SHA-256. This plan deliberately generates/verifies SHA-256
  only; adding SHA-3/BLAKE support requires a later explicit decision rather
  than another dependency now.
- A discovered upload component may impose a limit smaller than Nexus config
  or may be absent. That is a runtime capability result, not a reason for
  product-specific code.
- The current Codex App Server has no general local-document input. The narrow
  active-prompt attachment tool is the selected solution. Binary formats
  without a native media input remain truthfully unsupported for Codex.
- OpenAI input support depends on the selected model accepting that file type.
  API/model rejection remains a provider-ingestion failure and must not be
  misreported as an XMPP transfer failure.
- Presigned upload and download URLs often carry credentials in their query
  string. The embedded-credentials rejection applies to URL user-info, not an
  opaque signed query; queries are operation-owned secrets and must never be
  logged.
- No unresolved product choice blocks implementation. Any source or live
  protocol result that contradicts the contracts above must be reported before
  substituting a broader architecture.

## Approval Gate

This plan authorizes no implementation. No source edit, build, test execution,
server configuration change, program launch, archive creation, or other
implementation work begins until the human owner explicitly authorizes this
plan. A later implementation approval still does not authorize sub-agent use.
