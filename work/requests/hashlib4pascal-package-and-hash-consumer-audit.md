This is a demand for a work plan.

# Work Request: HashLib4Pascal Nexus Package and Legacy Hash Consumer Audit

## Status

Status: Work plan requested. No implementation is authorized by this request.

## Summary

Adopt HashLib4Pascal as a fully integrated, externally authored Nexus package, following the repository's existing package/source/build/test/provenance workflow. Then produce an exhaustive, evidence-based inventory of consumers of the old NexusFPC `hash` and `fcl-hash` functionality across relevant Nexus repositories, identifying which can migrate directly and which need an architectural decision **before** either old package is removed.

**This request does not authorize removal of `hash` or `fcl-hash`, a package-file format change, or a speculative migration of all callers.** Those decisions follow review of the completed inventory.

## Background

The current hashing functionality is fragmented between the FPC `hash` package (MD2/MD4/MD5, SHA-1, CRC, FNV, HMAC, and other utilities) and `fcl-hash` (SHA-2, HMAC, HKDF, RSA, ECC, ASN.1, PEM, OTP and related utilities). HashLib4Pascal offers coherent one-shot/incremental digest interfaces and an extensive algorithm catalog. Hash algorithms do not, by themselves, replace all the cryptographic and ancillary functionality buried in `fcl-hash`.

Proposed upstream: https://github.com/Xor-el/HashLib4Pascal

- Inspected upstream `master` commit: `1687d81fd0c8a08f3f04e7fed507a19131fbc0b1` (pin and verify the selected import revision instead of floating on `master`).
- Upstream author: Ugochukwu Mmaduekwe and contributors.
- Upstream license: MIT. Preserve the full original license and source notices.
- Upstream states FPC >= 3.2.2; `HashLib/src/Include/HashLibFPC.inc` checks `FPC_FULLVERSION >= 30202`.
- Upstream package manifests and source are available under `HashLib/src`. They are input for inventory, **not** instructions to use Lazarus or create an `.lpi` Nexus build.

## Current Architecture Rule

1. `nexus-packages-ext` owns externally authored package imports; upstream source and original notices live under that package's `external/` subtree.
2. `Package.nxscript` is the authoritative package identity/metadata/requirements declaration. A separate, explicitly composed Forge or nxbuild recipe owns compilation and artifacts; package identity must not depend on the build method. Do not introduce automatic dependency acquisition, scheduling, wrappers, or a new build framework.
3. Catalogs advertise discovery only. Preserve correct distinctions among the external repository's local package record, the first-party repository's external reference, and the machine-level package index.
4. A real runtime Nexus package includes `.nxpk`, the compiled `.nxpl`, matching `nxrtl`/SDK requirements, and a consumer test using `RequiredPackages`, not merely a metadata descriptor or source `-Fu` path.
5. NexusFPC currently bootstraps from FPC 3.2.2. Compiler/bootstrap code cannot acquire a circular dependency on a Nexus runtime package built by that same compiler.
6. Current on-disk and protocol hash bytes are compatibility contracts. Replacing an implementation is **not** permission to change algorithm, encoding, digest width, output case, or previously persisted identifiers.
7. Follow `AGENTS.md`, `packages/nexus-packages-ext/AGENTS.md`, `.ai/standards/pascal.md`, and the architecture/workplan protocols. No Lazarus/lazbuild reliance, Bash scripts, speculative compatibility adapters, or unnecessary abstraction.

## Desired Final State for This Work

### A. Complete HashLib4Pascal package import

Proposed identity: `NXRP.HashLib4Pascal`, compiled package: `HashLib4Pascal.nxpk` -> `HashLib4Pascal.nxpl`, and package location `packages/nexus-packages-ext/hashlib4pascal/` (actual repository root `nexus-packages-ext/hashlib4pascal/`).

- Import a pinned, tracked upstream source snapshot under `external/hashlib4pascal/`, preserving its license and pertinent test vectors/tests. Record upstream revision, import date, upstream URL, authors, license, path and status in the central Nexus `ATTRIBUTIONS.md`; README should link to that record.
- Supply the descriptive `Package.nxscript`, package documentation, complete `.nxpk` runtime unit declaration (including dependencies on `nxrtl` as required), and a native Forge/nxbuild recipe in its appropriate owned location. Preserve upstream Hlp* APIs on initial import unless a *verified* Nexus compiler requirement forces a localized, documented correction. Do not introduce a wrapper layer simply to re-export the library.
- Register in `nexus-packages-ext/Packages.RepositoryIndex.nxscript`, `nexus-packages/Packages.RepositoryIndex.nxscript` (external package reference), and `nexus/packages/Packages.PackageIndex.nxscript` (local package path); use actual checkout-relative locations.
- Compile with the current NexusFPC + SDK. Verify both a real package build and a source-free consumer using `RequiredPackages`. Cover Linux x86-64 and Windows x86-64 to the extent tools are available; report unverified targets explicitly. Verify FPC 3.2.2 source/bootstrap compatibility where this import touches seed-stage tools.
- Port or adapt useful upstream known-answer cases to NexusTest (not an `.lpi` runner), at least binary/string/stream MD5, SHA-1, SHA-256, HMAC and CRC32/incremental behavior. Preserve raw bytes and check exact hex digest casing where promised. Preserve upstream fixtures and test provenance.
- Keep implementation and tests separate from package identity/metadata. Do not alter or remove legacy hashing packages as part of importing the new one.

### B. Comprehensive legacy-consumer audit

Search all relevant current repositories and active build recipes, not just the provided Nexus archive: `nexus`, `nexus-fpc`, `nexus-packages`, `nexus-packages-ext`, and affected build/test examples, including `nexus-lab` where applicable. Search Pascal `uses`, qualified unit names, helper functions/types, compiler units, conditional branches, package/project descriptors, include paths, scripts and tests. Distinguish active direct dependencies from internal functions of unrelated libraries, documentation-only mentions, transitive dependencies, and third-party bundled private implementations.

For every genuine consumer, record repository/file, symbol/unit, owner, runtime or bootstrap stage, intended digest/checksum semantics, compatibility constraints, whether HashLib4Pascal can replace it, and tests needed. Provide a concrete proposed migration sequence and a **removal-blocker list**. Do not infer completeness from GitHub search indexing alone.

## Already Verified Search Leads (Revalidate in Current Checkout)

These are seed findings, not a claimed exhaustive inventory:

| Consumer | Existing use | Critical contract |
| --- | --- | --- |
| `nexus-fpc/compiler/nxpackagefile.pas`, especially lines 38, 95-145 | `SHA1`, `TSHA1Digest`, `SHA1Buffer` | The `NXPM0001` metadata envelope is 40 bytes, with its 20-byte SHA-1 fingerprint at offset 20; both encoder and decoder use it. Used by the compiler itself and reused by Forge through `nxpackagefile`. The FPC 3.2.2 seed/bootstrap also matters. |
| `nexus-fpc/packages/paszlib/src/gzio.pas`, `zip.pas`, `unzip.pas`, `paszlib.pas`; plus relocated `nexus-packages-ext/compression/paszlib/external/paszlib/src/` | `crc` / `System.Hash.Crc` and zlib-compatible `crc32(seed,ptr,len)` | ZIP/GZIP interoperability, update/initialization semantics, and compiler-bootstrap compression dependency. |
| `nexus/projects/forge/src/utNXForgePackageFiles.pas` and `utNXForgePackageSDK.pas` | `fpsha256`, `TSHA256.StreamHexa` | SHA-256 of package artifacts and deterministic SDK fingerprints; preserve exact hashes and uppercase encoding. See `projects/forge/doc/contracts.md`. |
| `nexus/projects/setup/src/obNXSetupState.pas` | `sha1`, `SHA1Print(SHA1String(AProductId))` | The SHA-1-derived directory `.nx/setup/<digest>` identifies existing installation-state locations. Must not strand prior installations or change byte/encoding semantics. |
| `nexus-packages/network/torrent/src/obNXTorrentMetaInfo.pas`, `obNXTorrentFileStore.pas`, and `test/NexusNetTorrentTests.lpr` | `sha1`, `SHA1String`, `TSHA1Digest` | Torrent v1 20-byte info hashes and piece digests over **raw bencoded/file bytes**, not text transcoding. |
| `nexus-packages/gui/external/fpgui/ide/src/main/pascal/ide.filemonitor.pas` | `sha1`, `SHA1Print(SHA1String(...))` | External fpGUI IDE code; establish whether this is part of an actively compiled product before proposing edits. |
| `nexus-fpc/packages/fcl-hash/src/` | SHA-1, SHA-2, HMAC and related internal dependencies | `fcl-hash` also owns RSA/ECC/ECDSA/ASN.1/PEM/OTP functionality that is **not** covered by importing HashLib4Pascal. Classify each before contemplating deletion. |
| `nexus-packages/graphics/fcl-image/tests/VerifyReview.py` and `nexus-packages/db/fcl-db/tests/VerifyReview.py` | Build/source search paths to `nexus-fpc/packages/hash/src` | Relocation/test closures and transitive CRC dependencies. The FCLImage and FCLDB package documentation also calls out hash helpers. |

**Do not misclassify** `System.Hash.Base64` used by FCLDB (from `fcl-base`, not the FPC `hash` package), OpenSSL's independent `TNXOpenSSLCrypto` implementation, Synapse's private SHA1/MD5 routines, the private fpGUI/Abbrevia/FPImage/Mustache checksum implementations, or compiler-internal `UpdateCRC32`, without evidence they really require the retired hash units.

### Special pre-removal decisions

1. **Compiler format and bootstrap**: The compiler's SHA-1 has an established binary-format purpose, not a general-purpose SDK checksum. Propose how to remove the dependency **without** introducing a cycle or changing the `NXPM0001` 40-byte on-disk contract. Changing envelope format/algorithm is out of scope absent separate owner approval. Document options and their tradeoffs rather than silently choosing one.
2. **PasZLib CRC**: Identify the correct zlib-compatible CRC implementation that the compiler can still use while bootstrapping and the relocated PasZLib package can consume. Verify CRC32 type, polynomial/variant, seed/continuation, zero-length/NULL behavior, and ZIP/GZIP fixtures.
3. **Non-hash `fcl-hash` features**: Specify which services remain in use, where they belong, and which require a separate replacement. HashLib4Pascal alone is not a claim that RSA, ECC, ASN.1, PEM, OTP, UUID, NTLM or Unix crypt can be deleted.
4. **Existing format fingerprints**: Preserve Setup persistent state directories, torrent wire digests, Forge SDK/artifact hashes and sidecar/package metadata fingerprints, including historical fixtures.

## Work Plan Requirements

The Codex plan must identify:

1. Inspected upstream revision, exact source/import/test selection, license and provenance retention.
2. Final repository ownership and directory/file layout, including build recipe vs identity separation and all catalog records.
3. Complete compiled-package source/units/includes/dependencies and expected `.nxpl` consumption path. Evidence for the required Linux and Windows compiler/SDK targets, and any constrained runtime package behavior.
4. Ordered import/build/test phases and commands using the current Nexus tooling.
5. A file-by-file legacy hash dependency inventory (including NexusFPC compiler + PasZLib), classified by active/inactive/third-party/internal/transitive.
6. Concrete migration/removal blockers; what requires an architecture decision vs mechanical replacement; a proposed follow-on migration plan with verification boundaries.
7. Explicit tests, failure handling, unverified targets, and remaining risks. Report source-tree or toolchain gaps honestly.

The plan is one artifact at `work/plans/hashlib4pascal-package-and-hash-consumer-audit.md`, matching this request's filename. Following the repository protocol, the plan is committed/pushed for owner review and **not implemented** until the owner directly authorizes it.

## Constraints / Non-Goals

- Do not remove or disable `hash` or `fcl-hash` in this request's implementation scope.
- Do not change `NXPM0001` or the SHA-1 20-byte digest field in compiled package metadata.
- Do not make compiler/seed builds depend on already compiled Nexus runtime packages, and do not lose FPC 3.2.2 bootstrap compatibility.
- Do not automatically migrate protocol wire digests, state paths or SDK hashes to different algorithms.
- Do not broaden this work into a crypto-framework rewrite. If unrelated functionality blocks future deletion, describe that follow-on scope separately.
- No Lazarus build tools, new `.lpi` build workflows, Bash scripts, wrappers for wrapper's sake, auto package acquisition, or new build systems.
- Respect upstream MIT source notices and the Nexus central attribution rules. Do not rewrite upstream into Nexus ownership.
- Do not spawn subagents without explicit owner instruction. Do not initiate code edits or tests merely because this plan request exists.

## Acceptance Criteria (for a separately authorized implementation)

- HashLib4Pascal is imported at a recorded revision with complete MIT provenance, manifest, package/catalog registrations, and documentation.
- The current Nexus compiler can produce a real `HashLib4Pascal.nxpl`; a consumer built **against the compiled package** passes targeted NexusTest known-answer and incremental/file/stream tests. Limitations are reported accurately by platform.
- The old hash packages remain intact and no old consumer is inadvertently changed.
- A verified, repository-wide dependency inventory and a prioritized blocker/migration map exist, including compiler metadata SHA-1, PasZLib CRC32, Forge, Setup and torrent consumers.
- A distinct decision gate prevents retirement until the owner approves the handling of compiler bootstrap/format and the remaining non-hash `fcl-hash` services.

## Compile and Verification Requirements

Plan exact current Forge/nxbuild and NexusFPC commands for the host environments. Include clean builds, compiled-package linkage/loading, SHA-1/SHA-256/CRC32 known vectors, HMAC vectors, real ZIP/GZIP round-trips, torrent byte-for-byte hashes, Setup state-directory continuity, package/sidecar decode and rejection of tampered fingerprints, and SDK manifest reproducibility where affected. The existing legacy suites are evidence but should not be run or modified before direct implementation authorization.

## Manual Verification Requirements

Inspect the package index and distribution from a clean consumer's perspective: discover the package, verify its attribution, build `.nxpl` using the documented recipe, compile a consumer through `RequiredPackages`, and confirm no hidden dependency on the upstream `.lpk` or developer source path.
