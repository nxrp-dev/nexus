This is a demand for a work plan.

# Work Request: NexusNet BitTorrent Client Server

## Status

Status: Work plan requested

## Summary

Create the architecture plan for a new NexusNet BitTorrent subsystem under `NexusNet/src/torrent`.

The goal is a fully functional BitTorrent client/server implementation in Object Pascal / Free Pascal, built as simple Nexus code rather than a dependency-heavy wrapper.

## Background

`NexusNet` is a new repository folder. It will contain Nexus networking platforms, with BitTorrent as one protocol/platform under that umbrella.

The current BitTorrent-specific layout is:

```text
NexusNet/src/torrent/
```

The desired end state should include both client behavior and server-style behavior:

- download torrents from metainfo files and magnet links
- seed and upload content to peers
- optionally provide BitTorrent service components such as a tracker once the peer engine is stable

## Current Architecture Rule

NexusNet should be a small, explicit Pascal subsystem.

Protocol data should be modeled as typed Pascal objects and records where practical. Wire encoding and decoding should live at the boundary. Session orchestration, storage, and peer state should be separate responsibilities.

Do not collapse the implementation into one large torrent manager object.

## Current Concern

BitTorrent has several separable protocols and runtime loops:

- bencode and torrent metainfo
- info-hash and piece hashing
- tracker announce/scrape
- peer wire protocol
- piece selection and verification
- storage mapping
- upload/seeding policy
- DHT and magnet metadata exchange

If these are introduced without clear ownership, the subsystem will quickly become difficult to verify and maintain.

## Desired Final State

NexusNet should contain a layered BitTorrent implementation:

```text
NexusNet/src/torrent/
  protocol primitives
  torrent metadata
  tracker clients
  peer wire protocol
  piece store and verifier
  torrent session engine
  seeding/upload policy
```

The first implementation target should be library only, verified through focused tests. GUI client work belongs later in Nexus Lab.

## Required Review

Codex should inspect the new folder layout and repository standards before proposing implementation.

The work plan should identify:

- proposed unit/file structure
- core object ownership boundaries
- supported BitTorrent protocol scope by stage
- client responsibilities
- server/seeding responsibilities
- tracker and DHT staging
- storage and verification model
- test strategy
- compile and manual verification plan
- risks and open questions

## Work Plan Requirements

The work plan should explain:

1. verified findings
2. target architecture
3. proposed unit structure
4. staged implementation plan
5. client/server feature scope
6. non-goals for the first pass
7. risks and open questions
8. compile/test plan
9. manual interoperability plan
10. sub-agent delegation plan if implementation is later approved

## Constraints

No code edits are authorized by this file.

Do not expand scope into NexusLS or NexusUI unless a clear integration boundary is later requested.

Do not introduce large abstractions before there is a protocol responsibility that needs them.

Do not add external dependencies unless the human owner explicitly approves them.

Use Object Pascal / Free Pascal naming and unit conventions from `.ai/standards/pascal.md`.

## Acceptance Criteria For The Work Plan

The work plan is acceptable if it clearly explains:

- what "client/server" should mean for NexusNet BitTorrent
- where the core torrent engine should live
- how bencode, metainfo, trackers, peers, storage, and session state should be separated
- what can be delivered in early verified slices
- which features belong later, such as DHT, peer exchange, uTP, encryption, or tracker server support
- how the subsystem can be tested without relying only on public torrents
- what compile and manual interoperability steps should be used after implementation approval

## Compile Requirements

The returned plan should identify the Pascal compile target that should be created for NexusNet if one does not already exist.

## Manual Test Requirements

The returned plan should propose manual tests for:

- parsing known metainfo
- creating a torrent from local files
- connecting to a tracker or controlled test tracker
- downloading from a controlled seed
- seeding to a controlled peer
- resuming a partial download
