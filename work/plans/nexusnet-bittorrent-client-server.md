# Work Plan: NexusNet BitTorrent Client Server

## Inputs

- Source request: `work/requests/nexusnet-bittorrent-client-server.md`
- Related workflow notes:
  - `AGENTS.md`
  - `.ai/standards/pascal.md`
  - `.ai/protocols/architecture-change.md`
  - `.ai/protocols/subagents.md`
- Existing constraints:
  - This is a work plan only.
  - No implementation begins until Kevin directly authorizes it.
  - Keep the subsystem in `NexusNet` unless a later integration point is explicitly requested.
  - Avoid external dependencies unless explicitly approved.
  - Keep the design simple, explicit, and staged.

## Summary

`NexusNet` should start as a standalone Pascal networking subsystem with BitTorrent as the first substantial protocol family.

For this plan, "client/server" should mean:

- client: load/create torrents, announce to trackers, connect to peers, download pieces, verify content, resume downloads, and manage multiple torrents.
- server/seeding: accept inbound peer connections, upload verified pieces, enforce choking/unchoking policy, rate/account traffic, and continue seeding after download completion.
- optional service components: a JSON-RPC control service should be part of the product shape; a tracker server should be a later module after the peer engine is correct.

The implementation should be delivered in verified slices. The first slice should not try to include DHT, peer exchange, uTP, encryption, and tracker server behavior. Those are real BitTorrent features, but adding them before the metainfo, storage, tracker, peer-wire, and seeding core is stable would create too much surface area.

## Verified Findings

- `NexusNet` currently exists under the repository root.
- `NexusNet/src` currently contains two folders:
  - `json-rpc`
  - `torrent`
- No `AGENTS.md` file exists under `NexusNet`, so the root repository rules and Pascal standards apply.
- No source files currently exist under `NexusNet/src/json-rpc` or `NexusNet/src/torrent`.
- Existing shared Nexus JSON-RPC object units are present under `NexusLib/src`, including `obNXJSONRPCObjects.pas` and `obNXJSONRPCMessages.pas`.
- Existing persistence and JSON support are present under `NexusLib/src`, including `obNXPersist.pas` and `obNXJSONValues.pas`.
- The current worktree has unrelated NexusLS changes. Implementation should avoid those files unless explicitly approved for a separate task.

## Architecture Problem

BitTorrent is not one protocol. It is a set of connected concerns:

- `.torrent` metainfo and bencoding
- piece hashes and info-hash calculation
- tracker HTTP/UDP announce and scrape
- peer wire protocol
- extension protocol
- storage layout and piece verification
- session scheduling and piece selection
- inbound peer handling for seeding
- optional DHT, PEX, magnet metadata, uTP, encryption, and tracker server behavior

If these concerns are owned by one manager class, the result will be hard to test and hard to evolve. NexusNet needs simple module boundaries early.

## Target Contract

### Torrent Protocol Layer

- Owner: low-level units in `NexusNet/src/torrent`
- Responsibilities:
  - bencode parsing/writing
  - metainfo loading and saving
  - info-hash calculation
  - peer message encode/decode
  - tracker request/response encode/decode
- State flow:
  - parse bytes into typed Pascal structures
  - serialize typed structures back to protocol bytes
  - no socket or filesystem ownership in this layer

### Storage Layer

- Owner: torrent storage units in `NexusNet/src/torrent`
- Responsibilities:
  - map torrent files to piece ranges
  - read/write blocks
  - track piece completion
  - verify SHA-1 piece hashes
  - support resume state
- State flow:
  - session asks storage for missing/writable blocks
  - storage writes blocks and verifies complete pieces
  - only verified pieces become uploadable

### Peer Layer

- Owner: peer connection and peer state units in `NexusNet/src/torrent`
- Responsibilities:
  - outbound peer connections
  - inbound peer accept path for seeding
  - handshake
  - bitfield/have/interested/choke/request/piece/cancel messages
  - request queue and block pipeline
  - upload/download accounting
- State flow:
  - peer state consumes wire messages
  - peer state emits session events and outbound messages
  - peer layer does not choose global piece strategy

### Session Layer

- Owner: torrent session units in `NexusNet/src/torrent`
- Responsibilities:
  - own active torrents
  - own tracker announces
  - own peer lists
  - choose pieces and blocks
  - coordinate storage verification
  - apply seeding/upload policy
  - expose status snapshots
- State flow:
  - session coordinates tracker, peer, and storage components
  - session owns runtime state, not protocol encoding details

### JSON-RPC Control Layer

- Owner: `NexusNet/src/json-rpc`
- Responsibilities:
  - typed control request/result objects
  - local service methods for torrent lifecycle
  - status queries and control commands
- State flow:
  - JSON-RPC commands call the session service
  - JSON-RPC objects do not implement torrent protocol mechanics

## Proposed Unit Structure

Initial torrent units:

```text
NexusNet/src/torrent/tpNXTorrent.pas
NexusNet/src/torrent/obNXBEncode.pas
NexusNet/src/torrent/obNXTorrentMetaInfo.pas
NexusNet/src/torrent/obNXTorrentFileStore.pas
NexusNet/src/torrent/obNXTorrentPieceMap.pas
NexusNet/src/torrent/obNXTorrentTracker.pas
NexusNet/src/torrent/obNXTorrentPeerProtocol.pas
NexusNet/src/torrent/obNXTorrentPeer.pas
NexusNet/src/torrent/obNXTorrentSession.pas
NexusNet/src/torrent/obNXTorrentService.pas
```

Initial JSON-RPC units:

```text
NexusNet/src/json-rpc/tpNXNetJSONRPC.pas
NexusNet/src/json-rpc/obNXNetJSONRPCRequests.pas
NexusNet/src/json-rpc/obNXNetJSONRPCService.pas
```

Initial verification targets:

```text
NexusNet/tests/NexusNetTestModule.lpi
NexusNet/tests/NexusNetTestModule.lpr
NexusNet/tests/tsNXTorrentCoreTests.pas
NexusNet/tests/fixtures/
```

Optional later executable targets:

```text
NexusNet/app/NexusTorrentCLI.lpi
NexusNet/app/NexusTorrentCLI.lpr
NexusNet/app/NexusNetDaemon.lpi
NexusNet/app/NexusNetDaemon.lpr
```

The exact file list can be tightened during implementation, but the first pass should keep `tp...` for shared enums/records/constants and `ob...` for classes.

## Staged Implementation Plan

### Stage 1: Project And Test Skeleton

- Add a NexusNet test module that compiles without network access.
- Add basic shared torrent types in `tpNXTorrent.pas`.
- Add fixture structure for small local test torrents and bencoded samples.
- Establish a compile command for the new subsystem.

Expected validation:

```text
lazbuild NexusNet\tests\NexusNetTestModule.lpi
```

### Stage 2: Bencode And Metainfo

- Implement bencode parser/writer.
- Support integers, byte strings, lists, and dictionaries.
- Preserve dictionary ordering when calculating the info-hash.
- Implement torrent metainfo load/save.
- Support single-file and multi-file torrents.
- Add tests for invalid bencode, round-trip encode/decode, metainfo parsing, and info-hash stability.

This stage should not open sockets.

### Stage 3: Piece Layout, Hashing, And File Store

- Implement file-to-piece mapping.
- Implement block read/write against a local download directory.
- Implement SHA-1 piece verification.
- Implement resume data for completed and partially completed pieces.
- Add tests using tiny local fixture files.

Only verified pieces should be visible as uploadable.

### Stage 4: Tracker Client

- Implement HTTP tracker announce first.
- Parse compact and non-compact peer lists if practical.
- Add announce state: started, stopped, completed, regular interval.
- Add scrape later only if it remains small.
- Defer UDP tracker support unless explicitly approved for this stage.

Tests should use a controlled local HTTP tracker fixture or a mocked transport boundary, not public network dependency.

### Stage 5: Peer Wire Protocol

- Implement handshake encode/decode.
- Implement core peer messages:
  - keep-alive
  - choke
  - unchoke
  - interested
  - not interested
  - have
  - bitfield
  - request
  - piece
  - cancel
- Add stream parser tests that handle partial reads and multiple messages in one buffer.
- Keep peer message parsing separate from socket ownership.

### Stage 6: Single Torrent Download Engine

- Implement one active torrent session.
- Connect to peers from tracker results.
- Select missing pieces with a simple rarest-first or sequential-first policy.
- Use a bounded block request pipeline.
- Verify pieces before marking them complete.
- Support pause/resume at the session level.
- Add controlled integration tests with a local in-process peer where possible.

For the first working version, a simple deterministic piece picker is acceptable if it keeps the engine testable.

### Stage 7: Seeding And Inbound Peers

- Add inbound peer accept support.
- Serve only verified pieces.
- Implement basic choking/unchoking policy.
- Track upload accounting.
- Support seed-only mode for a complete local torrent.
- Add manual tests against a known client in a private local network or loopback setup.

This is the "server" part of the first functional BitTorrent scope.

### Stage 8: Multi-Torrent Session And JSON-RPC Control

- Add `TNXTorrentService` or equivalent service object that owns multiple torrents.
- Add JSON-RPC request/result objects for:
  - add torrent file
  - add magnet link, initially allowed to return unsupported until Stage 9
  - start torrent
  - pause torrent
  - remove torrent
  - get torrent status
  - list torrents
  - get peer list
  - set rate limits if rate limiting exists by then
- Keep control API objects separate from torrent engine objects.

### Stage 9: Magnet, DHT, And Extension Protocol

- Implement magnet URI parsing.
- Implement BEP 10 extension handshake.
- Implement metadata exchange, BEP 9.
- Implement DHT, BEP 5, after the peer engine is stable.
- Consider PEX after DHT and extension handshake exist.

These should be later stages because they require more network state and timeout behavior.

### Stage 10: Later Optional Protocols

Only after the core is stable, consider:

- UDP tracker protocol
- uTP
- encryption/obfuscation
- local tracker server
- web seeds
- super-seeding
- ratio scheduling
- bandwidth shaping

These are not first-pass requirements.

## JSON-RPC Control Shape

Use typed request/result objects, matching the Nexus JSON-RPC style already used elsewhere in the repo.

Representative methods:

```text
torrent.addFile
torrent.addMagnet
torrent.start
torrent.pause
torrent.remove
torrent.list
torrent.status
torrent.peers
torrent.files
torrent.setLimits
session.status
session.shutdown
```

Representative object model:

```text
TNXNetTorrentAddFileRequest
TNXNetTorrentAddFileResult
TNXNetTorrentStatusRequest
TNXNetTorrentStatusResult
TNXNetTorrentInfo
TNXNetTorrentPeerInfo
TNXNetTorrentFileInfo
```

Published properties should be the JSON-RPC contract surface. The JSON-RPC layer should call a service object and return typed results; it should not assemble arbitrary JSON payloads by hand.

## Non-Goals For First Approved Implementation

- No DHT in the first compiling slice.
- No uTP in the first compiling slice.
- No encryption in the first compiling slice.
- No tracker server in the first compiling slice.
- No GUI integration.
- No NexusLS integration.
- No public-network-only test strategy.
- No dependency-heavy implementation unless separately approved.

## Verification Plan

Compile after every structural stage:

```text
lazbuild NexusNet\tests\NexusNetTestModule.lpi
```

If a CLI or daemon target is added:

```text
lazbuild NexusNet\app\NexusTorrentCLI.lpi
lazbuild NexusNet\app\NexusNetDaemon.lpi
```

Focused test categories:

- bencode valid/invalid parsing
- bencode deterministic writing
- info-hash calculation from exact encoded `info` dictionary bytes
- single-file metainfo parsing
- multi-file metainfo parsing
- piece/file range mapping
- block write/read behavior
- SHA-1 piece verification
- resume state reload
- tracker response parsing
- peer handshake parsing
- peer message stream parsing with fragmented input
- request pipeline state
- seeding refuses unverified pieces
- JSON-RPC request/result serialization

Focused greps after implementation:

```text
rg "class\\(" NexusNet\\src
rg "published" NexusNet\\src\\json-rpc NexusNet\\src\\torrent
rg "TStringList|TMemoryStream|TFileStream" NexusNet\\src\\torrent
rg "SHA1|sha1|InfoHash|BEncode|Tracker|Handshake" NexusNet\\src\\torrent NexusNet\\tests
```

Manual interoperability tests after the relevant stages:

1. Create a tiny torrent from local fixture files.
2. Load the torrent and verify the info-hash against a known external tool.
3. Start a controlled local seed using a known client.
4. Download from that local seed to a fresh directory.
5. Restart the NexusNet process and resume the partial download.
6. Seed the completed content from NexusNet.
7. Download from NexusNet using a known client.
8. Control add/start/pause/status/list through JSON-RPC.

Public torrents should not be the main verification path. They are useful later as smoke tests, but they are too noisy for first-pass correctness.

## Sub-Agent Delegation

Sub-agents are useful after implementation approval, but not before.

Proposed roles:

- `NexusNet protocol worker`
  - owns bencode, metainfo, tracker payload parsing, and peer message encode/decode
- `NexusNet storage worker`
  - owns piece map, file store, hashing, resume state, and related tests
- `NexusNet session worker`
  - owns torrent session orchestration, peer scheduling, and seeding policy after protocol/storage contracts exist
- `NexusNet control worker`
  - owns JSON-RPC request/result objects and service boundary after the session API is stable

Main Codex responsibilities:

- keep the contracts simple and integrated
- prevent duplicate state models
- sequence work so workers do not edit the same files concurrently
- review all implementation output
- run final verification
- create the required archive after an approved architecture implementation pass

Recommended initial implementation delegation:

- Do not start with four workers.
- Use one `NexusNet protocol worker` for Stage 1 and Stage 2 after approval.
- Add storage/session/control workers only when the preceding contracts compile and tests pass.

## Risks And Questions

- Socket layer choice needs verification against current Free Pascal availability and project preferences. Do not guess before implementation.
- SHA-1 implementation source needs verification. If the repo already has a suitable hash unit, use it; otherwise decide whether FPC standard units are enough or whether a small local implementation is needed.
- Bencode dictionary ordering is critical for info-hash correctness. The metainfo implementation must preserve exact encoded `info` bytes or provide deterministic canonical encoding where valid.
- BitTorrent has many BEPs. The first functional target needs a firm scope or it will sprawl.
- "Server" should be confirmed: this plan treats it primarily as seeding/inbound peer service plus JSON-RPC daemon control. A tracker server is proposed as later optional work.
- NAT traversal and public inbound connectivity are operational concerns. The first version should work on loopback/LAN before trying to solve internet reachability.
- Legal/safety policy for default downloads may matter later. The code should support user-provided torrents and controlled tests; bundled public content is not needed.

Open questions for Kevin before implementation:

- Should `server` include a BitTorrent tracker server in the first full milestone, or is seeding/inbound peer service the intended meaning?
- Do you want a CLI executable first, a daemon with JSON-RPC first, or only a testable library first?
- Should `json-rpc` reuse NexusLib JSON-RPC objects directly, or should NexusNet keep its own command surface that depends on NexusLib only at the boundary?
- Is the first implementation allowed to use standard FPC networking/hash units if available, or should NexusNet avoid even those where practical?

## Approval Gate

No implementation begins until Kevin explicitly authorizes it.
