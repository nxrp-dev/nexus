# Work Plan: NexusNet BitTorrent Hardening Pass

## Inputs

- Source request: attached pasted work-plan demand for NexusNet BitTorrent hardening.
- Related constraints:
  - Work plan only.
  - The source request was ChatGPT-generated external review input. Treat it as non-authoritative; verify every claim against the local code before implementation.
  - No implementation begins until Kevin explicitly approves it.
  - Keep the pass small and corrective.
  - Do not expand into full client orchestration, piece picking, DHT, magnet links, encryption, resume files, peer scheduling, or advanced tracker behavior.
  - Preserve piece-level completion/availability state for now.
  - Prefer OOP responsibilities over procedural helper sprawl.

## Summary

The current NexusNet BitTorrent vertical slice is a useful foundation, but it needs a contract-correction pass before any feature expansion.

The request text came from ChatGPT, so this plan does not treat it as authoritative. The items below are included because local inspection confirmed the relevant code shape or risk. Any implementation pass should keep the same skeptical posture and reject any review suggestion that does not match the code in front of us.

This pass should make the existing code stricter around untrusted peer, tracker, metainfo, and torrent-file-path input. It should not add a new download scheduler or introduce block-level persistent state. The target is a safer library slice whose existing object boundaries remain recognizable:

- peer wire codec owns message encode/decode contracts
- peer connection owns socket frame limits and exact reads
- metainfo/bencode own parse validation and decode-tree lifetime
- file store owns safe torrent-path normalization under the configured root
- session remains a thin library facade and does not become a full client engine in this pass

## Verified Findings

- `NexusNet/src/torrent/obNXTorrentPeerProtocol.pas`
  - `TNXTorrentPeerMessage.Encode` currently encodes `tpmPort` as ID `9` plus a UInt32 stored in `Offset`.
  - `TNXTorrentPeerMessageCodec.Decode` decodes `tpmPort` with `NXReadUInt32(AData, 6)`.
  - Decode does not validate exact message lengths for fixed-shape messages.
  - Short `have`, `request`, `cancel`, or `port` packets can reach UInt32 reads that assume bytes exist.
  - Choke/unchoke/interested/not-interested accept any payload length greater than or equal to 1 instead of requiring ID-only messages.
  - `piece` accepts any length at or above the implicit minimum without an explicit minimum contract.

- `NexusNet/src/torrent/obNXTorrentPeerConnection.pas`
  - `ReceiveMessage` reads a peer-supplied UInt32 length and then reads that many bytes without a maximum frame-size check.
  - This allows hostile peers to force unbounded allocation/read attempts.

- `NexusNet/src/torrent/obNXTorrentFileStore.pas`
  - `AbsoluteFileName` checks whether `ExpandFileName(FRootPath + ARelativePath)` begins with `ExpandFileName(FRootPath)`.
  - The check is too weak because prefix matching can be fooled by sibling paths with the same prefix.
  - It does not explicitly reject absolute paths, drive-qualified paths, `..`, empty segments, or separator tricks before joining to the root.

- `NexusNet/src/torrent/obNXTorrentMetaInfo.pas`
  - `LoadFromBEncodedString` creates `lRoot` and frees it only on the happy path after the main `try`.
  - If validation raises after root decode succeeds, the decoded root leaks.
  - The `pieces` length divisible-by-20 check already exists in `LoadPiecesFromInfo`.
  - Required metainfo fields are accessed through `RequireBytes`/`RequireInteger`, which gives clear generic bencode errors, but this pass can make torrent-specific validation clearer where it adds value.

- `NexusNet/src/torrent/obNXBEncode.pas`
  - Top-level trailing data is already rejected.
  - Byte-string length parsing rejects negative values through `TryStrToInt`, but malformed decimal forms are only loosely validated.
  - Integer parsing accepts whatever `TryStrToInt64` accepts, without bencode-specific checks for malformed integer encodings.
  - Dictionary duplicate keys are currently allowed.

- `NexusNet/src/torrent/obNXTorrentTracker.pas`
  - `TNXTorrentTrackerResponse.Decode` creates `lRoot` and frees it only after the happy path.
  - If tracker response validation raises after root decode succeeds, the decoded root leaks.
  - Compact peer-list length validation already exists.

- `NexusNet/tests/NexusNetTorrentTests.lpr`
  - Existing positive tests cover bencode round trip, single-file metainfo, piece mapping, file-store verification, peer request message round trip, tracker compact peers, peer state, Synapse handshake, and service status.
  - The socket test currently uses a fixed port and `Sleep(200)`. The requested new tests should avoid adding more fixed-port/sleep dependency.

## Target Behavior Changes

### Peer Protocol Codec

Update `obNXTorrentPeerProtocol.pas`.

Add big-endian UInt16 helpers:

```pascal
function NXReadUInt16(const AData: string; APosition: Integer): Word;
function NXWriteUInt16(AValue: Word): string;
```

Keep UInt32 helpers for index/begin/length fields.

Make decode length-contract strict:

- keep-alive: length prefix must be `0`; no message ID
- choke/unchoke/interested/not-interested: length must be `1`
- have: length must be `5`
- bitfield: length must be at least `1`
- request: length must be `13`
- piece: length must be at least `9`
- cancel: length must be `13`
- port: length must be `3`
- extension: length must be at least `2` if preserving BEP 10 extension message ID semantics; if the current implementation treats the full extension payload opaquely, require at least `1` for this pass and do not expand extension handling

Make malformed short packets raise `ENXTorrentPeerProtocolError` with a message that identifies the message kind and expected payload shape.

Fix `tpmPort`:

- encode as length `3`, ID `9`, UInt16 port
- decode UInt16 port into the existing `Offset` property for this pass, or add a `Port` property if the implementation can remain small
- do not encode/decode port as UInt32

Add encode-side validation for messages created by local code:

- request/cancel length must be `> 0`
- index, offset, and length must not be negative
- offset plus length must not overflow signed integer range
- port must be `0..65535`
- peer ID and handshake checks remain as-is

Do not introduce block ownership state in the codec. The peer wire fields remain piece index plus begin/offset plus length or payload.

### Peer Connection Frame Limit

Update `obNXTorrentPeerConnection.pas`.

Add a named constant near the top of the unit:

```pascal
const
  NXTorrentMaxPeerMessageBytes = 2 * 1024 * 1024;
```

Before `ReceiveMessage` calls `ReadExact(lLength)`, reject any length greater than the cap with `ENXTorrentPeerConnectionError` or `ENXTorrentPeerProtocolError`.

The preferred shape is:

- connection object detects oversized frame length
- raises a clear peer protocol/connection exception
- does not allocate or read the advertised body

Keep this as a frame-size safety check only. Do not add scheduler/request-window behavior.

### Request Length Sanity

Keep request-boundary validation close to where the current implementation has enough context:

- codec can validate non-negative numeric fields and `length > 0`
- file store already validates `ABlockOffset + Length(AData) <= piece length`
- add overflow-safe checks in `TNXTorrentFileStore.WriteBlock` and `ReadBlock`
- if adding a helper on `TNXTorrentPieceMap`, keep it narrow, for example:

```pascal
procedure ValidatePieceBlockRange(APieceIndex, ABegin, ALength: Integer);
```

Do not add block persistence. Piece remains the completion/verification/availability unit.

### Bencode And Metainfo Validation

Update `obNXBEncode.pas`.

Add targeted parse validation:

- integer body must be non-empty
- `-0` is invalid
- leading zero is invalid except exactly `0`
- negative values only allowed in integer values, not string lengths
- string length text must contain only digits
- empty string length text is invalid
- duplicate dictionary keys should raise `ENXBEncodeError`

Dictionary duplicate-key rejection can live in `TNXBEncodeDictionary.Add`; this will make all decoded dictionaries strict. If this is too broad during implementation, use an explicit `AddDecoded` method for decode-time strictness and keep manual construction behavior unchanged. Preferred first pass: reject duplicates universally because duplicate bencode dictionary keys are unsafe for metainfo interpretation.

Update `obNXTorrentMetaInfo.pas`.

- Wrap `lRoot` in `try/finally` so decoded roots are freed on all validation paths.
- Preserve current info-hash stability: continue storing `FInfoDictionary := TNXBEncodeDictionary(lInfo.Clone)` after successful load.
- Do not sort or canonicalize loaded dictionaries in this pass.
- Keep the existing pieces-length divisible-by-20 validation.
- Add clearer torrent-specific validation for:
  - empty `name`
  - non-positive `piece length`
  - missing either single-file `length` or multi-file `files`
  - multi-file empty `files`
  - empty path list or empty path segment

### Tracker Decode Ownership

Update `obNXTorrentTracker.pas`.

- Wrap `lRoot` in `try/finally` in `TNXTorrentTrackerResponse.Decode`.
- Keep compact peer length validation.
- Validate dictionary peer ports are in `0..65535`.
- Keep this as decode hardening only; do not add scrape, UDP tracker, retry, or announce scheduling.

### File Store Path Safety

Update `obNXTorrentFileStore.pas`.

Centralize torrent path normalization in one method, for example:

```pascal
function NormalizeTorrentRelativePath(const APath: string): string;
```

Enforce:

- reject empty path
- reject absolute paths
- reject drive-qualified Windows paths
- reject `..` segments
- reject empty segments caused by doubled separators
- reject path segments containing alternate separators after splitting
- combine only normalized relative path segments under `FRootPath`
- verify the final expanded path is inside the expanded root using delimiter-aware comparison, not raw prefix matching

The delimiter-aware final check should compare against a root path normalized with a trailing delimiter and require the candidate path to start with that full root string.

Do not introduce a broader sandbox abstraction.

## Files To Change

- `NexusNet/src/torrent/obNXTorrentPeerProtocol.pas`
  - UInt16 helpers
  - strict decode length validation
  - `port` UInt16 encode/decode
  - encode-side numeric sanity checks

- `NexusNet/src/torrent/obNXTorrentPeerConnection.pas`
  - max peer message constant
  - oversized frame rejection before body read

- `NexusNet/src/torrent/obNXBEncode.pas`
  - stricter integer and byte-string decimal validation
  - duplicate dictionary key rejection

- `NexusNet/src/torrent/obNXTorrentMetaInfo.pas`
  - root decode `try/finally`
  - targeted metainfo validation
  - no info-hash behavior change beyond rejecting invalid data earlier

- `NexusNet/src/torrent/obNXTorrentTracker.pas`
  - root decode `try/finally`
  - dictionary peer port validation

- `NexusNet/src/torrent/obNXTorrentFileStore.pas`
  - safe torrent path normalization
  - delimiter-aware root containment check
  - overflow-safe block range checks

- `NexusNet/src/torrent/obNXTorrentPieceMap.pas`
  - optional narrow block range validation helper if it keeps file-store checks cleaner

- `NexusNet/tests/NexusNetTorrentTests.lpr`
  - add negative tests requested below
  - avoid adding new sleeps/fixed ports

## Tests To Add

Add focused tests to `NexusNet/tests/NexusNetTorrentTests.lpr`.

Peer protocol tests:

- `tpmPort` encodes as `#0#0#0#3 + #9 + UInt16(port)`
- `tpmPort` decodes UInt16 port exactly
- decoder rejects short `have`
- decoder rejects short `request`
- decoder rejects short `cancel`
- decoder rejects short `port`
- decoder rejects extra payload on choke/unchoke/interested/not-interested
- decoder rejects malformed fixed-length message instead of reading past payload

Peer connection tests:

- `ReceiveMessage` rejects an oversized length prefix without trying to read the body
- use a test-only connection or socket pair if practical; if not, expose a small protected/internal method only if it stays within the connection object responsibility
- do not add new fixed-port/sleep tests

Request/block sanity tests:

- creating/encoding request with zero length fails
- creating/encoding request with negative offset fails
- file store rejects `begin + length` beyond final piece length
- final piece range validation uses the final piece length, not the standard piece length

Bencode/metainfo tests:

- bencode rejects trailing junk, preserving existing positive test
- bencode rejects malformed integer encodings such as `i03e`, `i-0e`, `ie`
- bencode rejects duplicate dictionary keys
- metainfo rejects `pieces` whose length is not divisible by 20
- metainfo decode failure after root decode does not leak obvious owned roots; practically, test by making the decode raise in the validation path and ensure no secondary failure occurs, because leak detection is not currently instrumented

Tracker tests:

- malformed tracker peer list still raises cleanly
- tracker dictionary peer with invalid port raises
- malformed tracker decode path frees root by construction through `try/finally`; again, test observable exception behavior unless leak instrumentation is added separately

File-store path tests:

- reject `..\evil.bin`
- reject `subdir\..\evil.bin`
- reject absolute Windows path such as `C:\temp\evil.bin`
- reject rooted path such as `\temp\evil.bin`
- reject doubled separators or empty path segments where they would create ambiguous torrent paths
- accept normal nested path such as `content\part.bin`

Existing tests must continue to pass.

## Risks

- Duplicate bencode dictionary rejection may affect manually constructed dictionaries if any current construction accidentally adds duplicate keys. That would be a real model bug, but implementation should verify current tests.
- Strict peer message length validation may require minor changes to any existing tests that relied on loose acceptance.
- Path normalization needs care on Windows because `ExpandFileName` and drive/root handling can hide unsafe inputs if validation is done after joining.
- The current socket test uses a fixed port and sleep. This pass should not make that worse, but replacing it is outside the requested hardening unless implementation naturally introduces a small dynamic-port helper.
- Info-hash stability depends on preserving the loaded `info` dictionary bytes/shape. Do not add dictionary sorting in this pass.

## Acceptance Criteria

Implementation is accepted when:

- existing NexusNet tests still pass
- new negative protocol tests pass
- peer message decoder is strict about length contracts for every supported message kind
- peer `port` message uses a 16-bit payload
- peer connection rejects oversized frames before reading the advertised body
- request/cancel numeric fields are sanity checked without introducing block-level persistent state
- metainfo rejects invalid `pieces` hash data length
- malformed bencode integer/length encodings are rejected
- duplicate dictionary keys are rejected during decode
- metainfo and tracker decode exception paths free decoded bencode roots through `try/finally`
- torrent file paths cannot escape the configured root
- no peer scheduling, DHT, magnet, encryption, resume-file, or large session rewrite is introduced

## Verification Plan

Compile:

```text
fpc -FuNexusNet\src\torrent -Fulib\synapse -FuC:\lazarus\fpc\3.2.2\units\x86_64-win64\hash -FUoutput\NexusNetTorrentTests\units -FEoutput\NexusNetTorrentTests\bin NexusNet\tests\NexusNetTorrentTests.lpr
```

Run:

```text
output\NexusNetTorrentTests\bin\NexusNetTorrentTests.exe
```

Focused greps after implementation:

```text
rg "NXReadUInt16|NXWriteUInt16|NXTorrentMaxPeerMessageBytes" NexusNet\src\torrent
rg "tpmPort" NexusNet\src\torrent NexusNet\tests
rg "try\\s*$|finally|lRoot.Free" NexusNet\src\torrent\obNXTorrentMetaInfo.pas NexusNet\src\torrent\obNXTorrentTracker.pas
rg "\\.\\. |\\.\\.|ExtractFileDrive|PathDelim|DirectorySeparator" NexusNet\src\torrent\obNXTorrentFileStore.pas
```

## Approval Gate

No implementation begins until Kevin explicitly authorizes this hardening pass.
