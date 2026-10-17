# Work Plan: HashLib4Pascal Package and Hash Consumer Audit

Status: Approved by the owner ("make it so"); implementation pass completed with
native SDK/bootstrap verification limits recorded in the matching review.
Date: 2026-10-17.

Implementation results and source-verified corrections to the initial inventory
are in [the implementation review](../reviews/hashlib4pascal-package-and-hash-consumer-audit.md).
The prospective instructions below preserve the approved planning record.

## Inputs

- [Source request](../requests/hashlib4pascal-package-and-hash-consumer-audit.md),
  including its PasZLib CRC32 amendment at Nexus commit `782af64`.
- Owner correction during planning: **there must not be two PasZLib copies**.
  This supersedes the request's instruction to update both the bootstrap and
  external copies. Retain the authoritative NexusFPC tree; do not restore the
  deleted external package.
- Owner execution direction: remove intermediate approval gates. Initial plan
  approval authorizes the entire implementation and verification sequence;
  its stages are a technical ordering, not separate approval handoffs.
- Owner's latest correction, 2026-10-17: remove hashing dependencies from
  NexusFPC package metadata processing and use straightforward storage with
  only necessary structural validation. Preserve the existing compiler bootstrap
  and build sequence exactly. Do not introduce compiler variants, additional
  compilation stages, new hashing mechanisms or replacement dependencies.
  This supersedes both the request's SHA-1 preservation/source-substitution
  requirements and the previous plan's compiler separation and sidecar identity
  scheme. The broader package import, ordinary consumer migration and private
  PasZLib CRC remain in scope. The owner subsequently approved implementation
  with "make it so".
- Root `AGENTS.md`, `.ai/standards/pascal.md`,
  `.ai/protocols/architecture-change.md`, `.ai/protocols/codex-workplan-format.md`,
  `work/README.md`, and `work/plans/_template.md`.
- Applicable instructions in External Packages (root and compression), Forge,
  nxbuild, nxpackage, Setup, Packages network/GUI/FCL Image/FCL DB and their
  tests, and Nexus Lab.
- Inspected checkouts, including owner checkpoints committed during inspection:
  Nexus `37605ce8238dae0dcaa0d205de72810269282bce`, NexusFPC
  `00fb95dfe417ed7b7819f8414af9fb30c3735e61`, Packages
  `fe5d770b66c89ed737648ea7c93d8120668f93ea`, External Packages
  `4b7ff0a218ef79dbf467c7c29d8947a7c1029f4e`, and Lab
  `2f7cf1cf1164698b08d58a5a07f254271f56e435`. Existing unrelated changes are
  excluded from the plan commit.
- This revision corrects plan commit `2c2384b`. Bootstrap/metadata call sites
  were re-read in the current source, including the owner's ongoing unrelated
  compiler changes; none of those files is edited by this handoff.
- NexusFPC's `NexusFPC.Forge*.nxscript`, Forge package build templates and
  `projects/forge/doc/contracts.md`, the runtime-loading SDK guide in Lab,
  PasZLib's `README.md` and `CONSOLIDATION.md`, and root `ATTRIBUTIONS.md`.
- Pinned upstream [HashLib4Pascal source tree](https://github.com/Xor-el/HashLib4Pascal/tree/1687d81fd0c8a08f3f04e7fed507a19131fbc0b1),
  its source/package manifests, tests and
  [MIT license](https://github.com/Xor-el/HashLib4Pascal/blob/1687d81fd0c8a08f3f04e7fed507a19131fbc0b1/LICENSE).
  The source was inspected in temporary storage, not imported into a Nexus
  repository. No upstream build or test was executed.

## Summary

Introduce `NXRP.HashLib4Pascal` in External Packages, with one pinned upstream
source tree, a descriptive identity, a real runtime package and direct nxtest
coverage. Migrate ordinary legacy hash consumers while preserving their byte
and formatting contracts. HashLib is an ordinary library/tool dependency,
never an input to the compiler bootstrap.

Remove SHA-1 from the existing package metadata codec without replacing it.
Keep the existing compressed payload, embedded/sidecar placement and necessary
version, length, range and stream checks. Delete the fingerprint field and
comparison; do not add a replacement checksum or sidecar identity mechanism.
Rebuild affected development artifacts for the simplified storage version.

Preserve the compiler bootstrap and build sequence exactly: the same compiler
builds, capabilities, output paths, cycle comparisons, release tools, SDK and
cross/release ordering. The codec remains in its current compilation closure.
Only obsolete legacy hash source staging and search paths are removed after
both metadata SHA-1 and PasZLib's external CRC dependency are gone.

Make **the one authoritative PasZLib tree** self-contained. Consolidate its
existing CRC32 code into one private compression helper, retain the existing
PasZLib zlib facade, and remove its general-purpose hashing dependencies.
HashLib4Pascal is never a PasZLib dependency, including its tests.

Keep `hash` and `fcl-hash` intact, as required by the source request's non-goals.
This plan imports, migrates and audits; replacing their remaining non-hash
services and retiring the packages are outside its implementation scope.
Deliver the completed scope and residual dependency inventory together.

## Verified Findings

### Source ownership and bootstrap

1. `nexus-fpc/packages/paszlib` is the authoritative source by the owner's
   earlier consolidation decision. The external source tree and its catalog
   entries have been removed, confirmed in the current working tree and the
   owner's latest External Packages checkpoint. The earlier revision cited in
   the consolidation record still contains that retired copy; it is not the
   current inventory. The plan will not resurrect that tree.
2. `paszlib.pas`, `gzio.pas`, `zip.pas` and `unzip.pas` import `crc` and/or
   `System.Hash.Crc`. `PasZLib.crc32` and `PasZLib.get_crc_table` delegate to it.
3. The current file is `zstream.pas`, not `zstream.pp`. It already contains the
   reflected IEEE table and a complemented streaming update. `zipper.pas` has
   another copy of the table and raw CRC updates, including ZIP password/key
   processing. Consolidation must preserve those uncomplemented state updates.
4. Searches found no external caller of `PasZLib.get_crc_table`, nor an external
   user of `Zipper.Crc_32_Tab`, in the inspected source repositories. Keep the
   existing PasZLib pointer/table facade anyway, as explicitly requested; do
   not preserve the duplicate Zipper table through an alias or re-export.
5. PasZLib's retained `tests/tczipper.pas` imports `md5` only to compare original
   and extracted files. Byte comparison can retain that behavioral coverage
   without adding a hash library to the compression tests.
6. `compiler/nxpackagefile.pas` separately imports `SHA1` and calls `SHA1Buffer`
   for encoding and validating `NXPM0001`. The envelope is 40 bytes; bytes
   20..39 are the SHA-1 of the uncompressed metadata. Compression uses ZCompres
   and ZInflate. ZIP CRC tests alone do not validate this envelope path.
7. `StageMetadataHash` and the seed/native-generation paths in
   `NexusFPC.Forge.nxscript`, cross paths in `NexusFPC.Forge.Config.nxscript`,
   and `Stage_hash`/tool paths in `NexusFPC.Forge.Tools*.nxscript` remain live.
   Removing only PasZLib's CRC imports is insufficient: NXPackageFile's SHA-1
   must also be removed before those hash-only staging/search entries can go.
   No compiler capability separation or build-sequence change is necessary.

### Current metadata dependency and unchanged build sequence

| Source evidence | What it establishes |
| --- | --- |
| `compiler/pp.pas` -> `compiler` -> parser/link/target registration; PModules/FPPU/PkgUtil reference FPCP/TPCPPackage | The existing compiler closure includes package processing. Keep that closure and its capabilities unchanged |
| `compiler/link.pas:450`, `systems/t_linux.pas:557`, `pmodules.pas:1846` | Constant-only NXPackageFile imports do not require a new shared-format unit for this correction |
| `compiler/fpcp.pas` OpenPCP and SavePCP | Existing metadata I/O calls ReadPackageMetadata, EncodePackageMetadata and PackageMetadataReference; their responsibilities can stay in place |
| `compiler/nxpackagefile.pas:38` | The codec imports ZBase, ZCompres, ZInflate and SHA1. Remove SHA1 and its operations; retain existing compression without adding a dependency |
| `NexusFPC.Forge.nxscript` | BuildSeedCompiler, BuildNativeSeedCompiler, cycles 1/2/3, their static RTL and cycle2/cycle3 comparisons already define bootstrap. Preserve those builds, flags, outputs and ordering |
| `NexusFPC.Forge.PackageSDK.nxscript`, Tools.Config and Config | SDK, tools and cross builds currently use cycle3. Keep those selections and the existing subsequent build sequence |
| `utils/bin2obj.pas:20` | This release tool imports ZStream. Existing PasZLib staging remains needed independently of metadata hashing |

No technical constraint requiring a replacement metadata hash was found.
Removing SHA-1 in the existing codec, and external CRC in canonical PasZLib,
removes the legacy hash dependency without changing compiler stages. Package
metadata need not be exercised by ordinary compiler/RTL compilation, but this
work does not split its implementation out of the compiler.

### Existing validation retained

- The existing zlib decoder checks its stream integrity and NXPackageFile
  requires exact compressed-input consumption and uncompressed length. Retain
  these existing compression checks; add no checksum implementation or field.
- Retain necessary storage version/mode/length checks and bounded PE/ELF
  section access. Existing FPCP/PCP validation of NXP version/CPU/target, entry
  sizes/terminators, unit ranges and embedded NXU structure remains in place.
  Do not replace compiler-internal FPCHash/NXU checks as part of this work;
  they do not depend on a general-purpose hashing package.
- Existing package-name, SDK, required-provider and native-descriptor checks
  continue in their current owners. Forge's separate publication SHA-256
  manifests remain ordinary hashing consumers; they are not metadata-envelope
  processing dependencies.
- Remove the image/sidecar fingerprint comparison. Keep only storage consistency
  checks needed to locate and decode the sidecar. No new BuildIdentity field,
  caller plumbing or replacement association guarantee is required. Valid
  replacement metadata is not required to fail merely because its bytes differ
  from a previous payload.

### Upstream and runtime packaging

1. Revision `1687d81fd0c8a08f3f04e7fed507a19131fbc0b1` was verified through
   GitHub's recursive tree and inspected source. It contains **144 runtime
   Pascal units** outside `HashLib/src/Packages`, and **135 include files**
   below `HashLib/src/Include`. The exact selection is specified below.
2. `HashLibFPC.inc` requires FPC 3.2.2 or later. Its `{$MODE DELPHI}` selects an
   FPC language mode; this does not introduce support for the Delphi compiler.
   Its FPC PPL define is disabled. Keep it disabled; no product thread is
   needed or authorized for hashing.
3. `HlpHashFactory` references the algorithm catalog, SIMD code and KDFs.
   Direct HlpSHA1 is also a multi-unit library closure. Neither belongs in the
   compiler bootstrap or in the proposed metadata codec; reducing the number
   of imported HashLib units would leave the architectural mistake intact.
4. The library uses Classes, SysUtils, Math and StrUtils. `HlpCRC` also uses
   SyncObjs and Generics.Collections. ARM/OS branches reference Windows or dl;
   Posix.Dlfcn and System.Threading occur in conditional non-FPC/disabled
   branches. None is evidence of a legacy `hash` package requirement.
5. `nxrtl.nxpk` provides FPCPackage and its transitive shared foundation;
   FPCPackage imports SysUtils, Classes, TypInfo and platform support. The
   compiler's package builder also owns otherwise unowned implementation
   dependencies. Therefore the SDK's actual exported-unit metadata, rather
   than an assumption that every RTL/helper unit is already in nxrtl, must
   determine the remaining package source closure.
6. Current Forge has native preparation/publication operations, Windows and
   Linux package templates, and `RequiredPackages`. A descriptor or source
   `-Fu` build is not proof of compiled-package consumption.
7. This Linux host has native NexusFPC/RTL and a stock FPC 3.2.2 executable.
   The configured Linux `PackageSDKPath` does not exist and its identity is
   empty. The native compiler installation is not a runtime-package SDK.
   The checked-in full Bootstrap/PackageSDK recipe is Windows-oriented;
   native Linux SDK construction is documented as deferred. Windows execution
   is not available on this host. These are validation prerequisites, not
   successful target results.

### Consumer inventory

The following inventory comes from local source searches across all five
repositories, including Pascal uses clauses with comments removed, qualified
names, symbols, conditional branches, tracked configuration, build recipes and
tests. It includes code missed by searching only the parent repository's
ignored nested package directories. Generated build output and historical
snapshots are not counted as active consumers.

Paths in the tables use `N` = Nexus, `F` = NexusFPC, `P` = Packages,
`E` = External Packages and `L` = Lab. Every path is relative to that owner.
These classifications are source evidence; no unexecuted build is described as
a working product.

| File | Classification / stage | Existing contract | Proposed handling and required proof |
| --- | --- | --- | --- |
| F `compiler/nxpackagefile.pas` | Existing compiler and Forge metadata codec | NXPM0001 currently uses TSHA1Digest/SHA1Buffer | Remove SHA-1 import, fingerprint field and comparisons; retain simple storage/structural checks in the same compiler closure and unchanged build sequence |
| F `packages/paszlib/src/paszlib.pas` | Active compression facade | `crc.crc32`, `get_crc_table` | Delegate existing facade to private CRC; nil/empty/continuation/table tests |
| F `packages/paszlib/src/gzio.pas` | Active gzip read/write | `crc32` initialized with `(0,nil,0)` | Private CRC; independent gzip fixtures and trailer checks |
| F `packages/paszlib/src/zip.pas` | Active low-level ZIP writer | `crc32` over uncompressed bytes | Private CRC; local/central header values and independent extraction |
| F `packages/paszlib/src/unzip.pas` | Active low-level ZIP reader | Incremental CRC and stored-field comparison | Private CRC; valid and corrupt entry fixtures |
| F `packages/paszlib/src/zstream.pas` | Active private CRC provider already present | Complemented running CRC for gzip streams | Move table/update implementation to private helper; retain stream behavior |
| F `packages/paszlib/src/zipper.pas` | Active independent CRC table and raw-state operations | ZIP CRC, password/key byte updates | Use private table/core without changing pre/post conditioning; encrypted ZIP interoperability |
| F `packages/paszlib/tests/tczipper.pas` | Retained test, not runtime | MD5 file equality | Replace with byte equality; no HashLib import in PasZLib tests |
| N `projects/forge/src/utNXForgePackageFiles.pas` | Active build tool | `UpperCase(TSHA256.StreamHexa(...))` artifact hashes | Hlp SHA-256 stream bytes, uppercase ungrouped hex; fixed file vectors and publication rejection tests |
| N `projects/forge/src/utNXForgePackageSDK.pas` | Active SDK construction tool | SHA-256 of compiler/files and deterministic fingerprint inputs | Same byte stream, sorting, separators, encoding and uppercase result; stable-input identity/hash comparison |
| N `projects/setup/src/obNXSetupState.pas` | Product source with checked-in project/test recipes | `SHA1Print(SHA1String(AProductId))` in `.nx/setup/<digest>` | Raw bytes, lowercase 40 hex digits; existing-state path fixture, including non-ASCII and embedded zero bytes |
| P `network/torrent/src/obNXTorrentMetaInfo.pas` | Runtime source | SHA-1 of raw bencoded info bytes; `TNXTorrentHash` | Hash exact existing byte range, preserve 20-byte wire value; independently fixed torrent fixture |
| P `network/torrent/src/obNXTorrentFileStore.pas` | Runtime source | SHA-1 of piece bytes | Raw byte/stream hashing; binary and cross-file piece fixtures |
| P `network/torrent/test/NexusNetTorrentTests.lpr` | Direct test consumer | SHA-1 fixture/piece construction | Migrate helper and add fixed expected digests so producer/consumer cannot hide a shared mistake |
| P `gui/external/fpgui/ide/src/main/pascal/ide.filemonitor.pas` | Third-party IDE source, referenced by `ide.main` and `ide.form.main` | Lowercase SHA-1 of `AsString` bytes | Establish actual IDE entry/build closure before edit; migrate if built, otherwise record inactive blocker rather than claiming removal readiness |
| F `tests/bench/bmd5.pas` | Benchmark source, no active recipe established | MD5 benchmark calls | Adapt meaningful demonstration or explicitly retire obsolete benchmark only under approved scope; not a runtime dependency |
| F `tests/test/packages/hash/tmdtest.pas` | Legacy test fixture | MD5 known-answer behavior | Preserve useful vectors in nxtest; classify original runner separately |
| F `tests/test/packages/hash/sha1test.pas` | Legacy test fixture | SHA-1 known-answer behavior | Preserve useful vectors in nxtest; classify original runner separately |
| L `examples/data/hashes/mdtest.pas` | Demonstration | MD5 vectors | Direct HashLib API, same byte vectors |
| L `examples/data/hashes/hmd5.pas` | Demonstration | HMAC-MD5 | Direct HashLib HMAC, preserve key/data order and bytes |
| L `examples/data/hashes/md5performancetest.pas` | Demonstration/benchmark | MD5 over repeated text | Migrate API; no performance promise |
| L `examples/data/hashes/hsha1.pas` | Demonstration | HMAC-SHA1 | Direct HMAC, fixed expected bytes |
| L `examples/data/hashes/sha1performancetest.pas` | Demonstration/benchmark | Lowercase SHA-1 | Migrate API and preserve printed format |
| L `examples/data/cryptography/demosha256.pas` | Demonstration | SHA-256 and digest helpers | Direct HashLib API; preserve hex output |
| L `examples/data/cryptography/sha256performancetest.pas` | Demonstration/benchmark | SHA-256; old SHA256PASCAL instructions | Migrate API and remove obsolete implementation-selection instructions |
| L `examples/gui/fpgui/gui/threads1/workerthread.pas` | Third-party demonstration | Incremental SHA-1 context | Migrate digest calls only if retained; no authority to add/justify a hashing worker thread |
| L `examples/data/cryptography/dumppem.lpr` | Non-hash demonstration | `fpasn` ASN.1 | Retain; explicit non-hash disposition required |
| L `examples/data/cryptography/extractrsa.lpr` | Non-hash demonstration | `fpasn`, `fprsa` | Retain; importing hashes does not replace RSA/key parsing |
| L `examples/data/cryptography/gentotp.pas` | Non-hash service demonstration | `onetimepass` | Retain; OTP behavior requires its own decision/tests |
| L `examples/data/cryptography/authenticator.pas` | Non-hash service demonstration | `onetimepass` | Retain; not an ordinary digest substitution |

Provider internals and their retained tests are additional removal blockers:

| File(s) in F | Classification / dependency | Disposition in this implementation |
| --- | --- | --- |
| `packages/hash/src/sha1.pas`, `md5.pas`, `crc.pas`, `fnvhash.pas` | Legacy algorithm providers; CRC also offers CRC64/128 | Keep intact; migrate external digest consumers, not the old provider implementation |
| `packages/hash/src/hmac.pas` | Internal MD5/SHA-1 dependency | Keep intact while remaining users exist |
| `packages/hash/src/ntlm.pas` | Internal MD5; NTLM protocol utility | Keep; protocol/service replacement is outside this scope |
| `packages/hash/src/uuid.pas` | Internal MD5/SHA-1; UUID semantics | Keep; preserve UUID version/namespace byte order in any later replacement |
| `packages/hash/src/unixcrypt.pas` | Independent Unix crypt service | Keep; HashLib digests alone are not a replacement |
| `packages/fcl-hash/src/fpsha256.pas`, `fpsha512.pas` | SHA-2/HMAC/HKDF; use `fphashutils` | Keep providers; migrate ordinary external hashing first; HKDF requires explicit follow-on handling |
| `packages/fcl-hash/src/fphashutils.pas` | Shared byte/encoding/types/utilities | Keep with remaining crypto services; not merely a digest API |
| `packages/fcl-hash/src/fpasn.pas` | ASN.1, uses hash utilities | Retain; used by RSA/PEM and Lab |
| `packages/fcl-hash/src/fptlsbigint.pas` | Big integers, uses hash utilities | Retain with RSA |
| `packages/fcl-hash/src/fpecc.pas` | ECC, uses hash utilities | Retain with ECDSA/PEM and tests |
| `packages/fcl-hash/src/fpecdsa.pas` | ECDSA, ECC and SHA-256 | Retain; later crypto-service migration needs signing/verification tests |
| `packages/fcl-hash/src/fprsa.pas` | RSA, ASN.1, big integers, SHA-1/SHA-2 | Retain; changing hash providers internally is a separately bounded crypto task |
| `packages/fcl-hash/src/fppem.pas` | PEM/keys/thumbprints, ASN.1, ECC and SHA-256 | Retain; preserve parsing and thumbprint semantics in later disposition |
| `packages/fcl-hash/src/onetimepass.pas` | HOTP/TOTP, SHA-1/HMAC | Retain; tokens, Base32 input and counter/time behavior need separate preservation |
| `packages/hash/tests/tsha1test.pas`, `tcrctest.pas`, `utestshmac.pas` | Current direct nxtest coverage of retained providers | Keep; comparison baseline, not production callers to rewrite blindly |
| `packages/fcl-hash/tests/utestsha256.pas`, `utestsha512.pas` | Digest tests plus non-hash crypto coverage | Keep; do not discard ECC/ECDSA/PEM assertions while extracting useful hash vectors |
| `packages/fcl-hash/tests/utestpem.pas`, `utestonetimepass.pas` | Non-hash service tests | Keep unchanged as retirement blockers |
| `packages/hash/namespaced/*.pas`, `packages/fcl-hash/namespaced/*.pas`, both `namespaces.lst` | Alternate unit names/include wrappers of retained providers | Keep intact; scan both ordinary and dotted names before any later removal |
| `packages/hash/src/*x86*.inc`, `*i386.inc`, `*x64*.inc`; `packages/fcl-hash/src/sha256x86.inc` | Provider implementation includes | Keep with their providers; not independent consumers |

Build/configuration references are a separate inventory; a path alone is not a
direct hash call:

| Owner and file(s) | Classification / action after migration |
| --- | --- |
| F `NexusFPC.Forge.nxscript` | Remove only obsolete StageMetadataHash and legacy hash search entries after both dependencies are gone; preserve compiler/RTL builds, compression staging, outputs, flags, comparisons and ordering |
| F `NexusFPC.Forge.Config.nxscript` | Remove obsolete legacy hash search entries; preserve existing cycle3 compiler selection, target configuration and cross-build sequence |
| F `NexusFPC.Forge.Tools.nxscript`, `NexusFPC.Forge.Tools.Config.nxscript` | Drop obsolete Stage_hash and its search entries; retain existing PasZLib inputs, tool builds, compiler copies and sequence |
| F `NexusFPC.Forge.PackageSDK.nxscript`, `NexusFPC.Forge.Release.nxscript`, tests/forge identity/release checks | Preserve current compiler selection, output paths and ordering; verify rebuilt artifacts through the existing sequence, without rewiring these recipes |
| F `packages/paszlib/tests/PasZLibTests.nxproject`, `packages/paszlib/README.md` | Drop hash paths after private CRC and byte-comparison test changes |
| F `packages/hash/tests/HashTests.nxproject`, `NXTEST.md`; `packages/fcl-hash/tests/FCLHashTests.nxproject`, `NXTEST.md` | Keep paths needed to test retained legacy services |
| F `nexusfpc-package-build-requirements.md` | Update current dependency notes; preserve historical context |
| N `projects/forge/NexusForge.nxproject`, `projects/forge/test/NexusForgeTests.nxproject`, `projects/forge/doc/contracts.md` | HashLib is for Forge's ordinary SHA-256 operations; its shared package codec loses SHA-1 and uses simplified storage; no new metadata validation mechanism or compiler-bootstrap source staging |
| N `projects/setup/NexusSetup.nxproject`, `projects/setup/test/NexusSetupTests.nxproject` | Existing wildcard compiled-package paths can conceal hash dependency; make the migrated closure explicit |
| N `projects/ls/pascal/src/parser/obNXPasSearchPaths.pas`, `projects/nexuscode/bin/x86_64-win64/nexuspas-search-paths.json` | Editor discovery, not hashing at runtime; add new source and keep old paths while legacy services remain |
| P `network/torrent/test/NexusNetTorrentTests.nxproject` | Old build-schema fields and wildcard compiled units; bring only this affected recipe to current FPC child syntax for verification |
| P `db/fcl-db/FCLDB.nxpackage`, `tests/FCLDBBehaviorTests.nxproject`, `tests/FCLDBTests.nxproject`, `tests/VerifyReview.py` | Transitive compression/review paths; remove hash path only after clean closure proof |
| P `graphics/fcl-image/FCLImage.nxpackage`, `tests/FCLImageTests.nxproject`, `tests/VerifyReview.py` | Same transitive compression closure rule |
| P `gui/external/fpgui/framework/src/test/pascal/fpGUIFrameworkTests.nxproject`, `gui/external/fpgui/ide/src/test/pascal/fpGUIIDETests.nxproject` | Explicit hash paths; test-program build does not establish full IDE/file-monitor reachability |
| L `examples/data/compression/paszlib/PasZLibExamples.nxproject` | Remove hash path after self-contained runtime proof |
| L `examples/data/database/DatabaseExamples.nxproject`, `examples/data/json/JSONExamples.nxproject`, `examples/data/xml/XMLExamples.nxproject`, `examples/graphics/images/FCLImageExamples.nxproject` | Broad/transitive search paths; prove clean build before removing |
| L `examples/gui/script-editor/NexusScriptEditorDemo.nxproject`, `examples/gui/virtual-tree/NexusVirtualTreeViewDemo.nxproject`, `examples/mobile/pascal-plugin/plugin_sample.nxproject` | Broad/transitive search paths; distinguish platform/tool availability from dependency evidence |
| L `examples/network/tls/genkeypair.nxproject`, `examples/network/tls/test1.nxproject`, `examples/network/xmpp/NexusXMPPConsole.nxproject`, `examples/system/processes/ProcessExamples.nxproject` | Broad/transitive search paths; no migration of independent TLS/Synapse implementations inferred |
| L `examples/build/native/Hello.nxproject`, `examples/build/orchestration/hello world & test.nxproject` | Intentional source/path fixtures mention legacy hash source; preserve the fixture's build-language purpose with an appropriate source replacement |
| N/E/P catalogs, relevant Package.nxscript files and READMEs; root ATTRIBUTIONS.md | Discovery/dependency documentation updates; not code consumers |
| N `docs/migrations/fpcunit/*`, prior review results and old attribution records | Historical evidence only; do not rewrite history or treat it as an active dependency |

Explicit exclusions from the legacy dependency count:

- FCL DB's `System.Hash.Base64` in `src/base/xmldatapacketreader.pas` and
  `src/export/fpxmlxsdexport.pas` comes from FCL Base, not `hash`/`fcl-hash`.
- `network/external/synapse/synacode.pas` owns its SHA-1/MD5/HMAC/CRC code.
  OpenSSL's `TNXOpenSSLCrypto` owns its independent OpenSSL implementation.
  Do not migrate either merely because symbols have similar names.
- FPImage's `fpcolhash.pas`, fpGUI's private checksums, Abbrevia's archive
  checksums, Mustache/SynCommons hashes and compiler-internal `UpdateCRC32` are
  independent implementations. Generics.Hashes also has internal algorithms;
  that does not make it the legacy `hash` package.
- Absent E `compression/paszlib/external/paszlib/src`, its former Package
  descriptor and retired Lab `paszlib-external` examples are history, not a
  second migration target.

Re-run the inventory immediately before implementation and again before any
retirement proposal. Changes made by the owner or new consumers can invalidate
this source snapshot.

## Architecture Problem

NXPackageFile makes a general-purpose hash library a compiler dependency solely
for a metadata-envelope fingerprint. PasZLib independently imports legacy CRC.
Replacing either with HashLib would preserve an unnecessary dependency.

The correction is to remove the envelope fingerprint, keep straightforward
storage and necessary structural validation, and make PasZLib own its private
CRC32. There is no need to change the compiler's capabilities or bootstrap
architecture to do this. Existing package validation stays with its owners;
ordinary consumer hashing remains a separate HashLib migration.

## Target Contract

### HashLib4Pascal ownership and layout

External Packages owns `hashlib4pascal/`:

```text
Package.nxscript                         descriptive identity, author/license/requirements
HashLib4Pascal.nxpk                      package HashLib4Pascal; requires nxrtl; contains ...
HashLib4Pascal.Forge.nxscript            explicit package and compiled-consumer builds
HashLib4Pascal.Build.Config.nxscript     explicit SDK/source/output selections, no acquisition
README.md                               build/use instructions and central attribution link
CODE_REVIEW.md                          source/integration review before local corrections
external/hashlib4pascal/LICENSE          original complete MIT text
external/hashlib4pascal/README.md        original upstream documentation
external/hashlib4pascal/HashLib/src/     selected runtime units and all includes
external/hashlib4pascal/HashLib.Tests/Data/  original raw fixtures and their README
tests/HashLib4PascalTests.lpr            direct nxtest runner
tests/tsHashLib4PascalTests.pas          adapted known-answer/incremental tests
tests/HashLib4PascalTests.nxproject      explicit source-mode comparison build
tests/fixtures/                         ordinary hash/compiled-consumer fixtures
review/import-hashes.json               exact upstream file selection and hashes
```

The pinned selection is all 144 `.pas` files below `HashLib/src` **except**
`Packages/**`, plus all 135 `Include/**/*.inc`; preserve paths and source bytes.
List every selected Hlp unit explicitly in `.nxpk`, not a hand-picked MD5/SHA
subset. Appendix A enumerates the unit set. Include the original root LICENSE
and README and all raw `HashLib.Tests/Data/**` fixtures/README. Do not import
Lazarus/Delphi project files, generated package aggregator, IDE runners,
benchmarks or CI/build scripts into the Nexus build.

Adapt pertinent inline vectors from upstream `HashLibTestBase.pas`,
`CryptoTests.pas`, `CRCTests.pas`, `ChecksumTests.pas` and relevant hash/KDF tests
directly to nxtest. Record original file/case/revision in the adapted tests and
review. Do not restore FPCUnit helpers, runners, a bridge or a copied unused test
hierarchy. Preserve raw fixtures and their notices; adapted test notices must
retain upstream MIT attribution. Nexus build infrastructure has its own notice.

`Package.nxscript` uses `NXRP.HashLib4Pascal`, Ugochukwu Mmaduekwe and
contributors, and MIT. It describes the source/include closure and references
actual catalog packages for logical dependencies where available. The SDK
foundation requirement is explicitly represented by `.nxpk`'s `requires nxrtl`
and the recipe's matching SDK selection; do not invent a catalog reference to
an absent nxrtl descriptor or add execution policy to package identity.

Register exactly these discovery records:

| Catalog | Record |
| --- | --- |
| E `Packages.RepositoryIndex.nxscript` | LocalPackage HashLib4Pascal, descriptor `hashlib4pascal/Package.nxscript` |
| P `Packages.RepositoryIndex.nxscript` | ExternalPackage HashLib4Pascal, `Id: "NXRP.HashLib4Pascal"`, `Repository: @NexusPackages.NexusExternal`; no Descriptor property, which the external-record schema does not accept |
| N `packages/Packages.PackageIndex.nxscript` | LocalPackage HashLib4Pascal, descriptor `nexus-packages-ext/hashlib4pascal/Package.nxscript` |

Root ATTRIBUTIONS.md records author, original URL/revision, actual import date,
MIT, destination/status and preserved test provenance. The package README links
there; no parallel provenance page. PasZLib's retired-copy history stays intact.

### Complete build-input closure and compiled consumption

- Compile all Appendix A units, with UnitPaths for their 17 source directories
  and IncludePaths for `HashLib/src/Include`; preserve the recursive SIMD
  include tree so relative nested includes resolve. No `.lpk` is a dependency.
- Standard units are Classes, SysUtils, Math, StrUtils, SyncObjs and
  Generics.Collections, with their ordinary RTL/FCL Base/RTL Generics closure.
  Supply matching source paths for `packages/rtl-objpas/src/inc` and platform
  includes (StrUtils), `rtl/objpas` (Math), `packages/fcl-base/src` and platform
  includes (SyncObjs), and `packages/rtl-generics/src`/`inc` (Generics.*).
  SyncObjs brings DateUtils/platform synchronization; Generics.Collections
  brings its Defaults/Helpers/MemoryExpanders/Strings/RTTI dependencies.
- First read the selected SDK's unit ownership. Reuse nxrtl-owned units without
  recompiling or listing them in `contains`. Compile the remaining unowned
  support closure within the provider using the compiler's existing implicit
  containment, and record the exact contained-unit list for each target in
  the review. Never introduce a second System/Classes owner. An ownership
  collision with another required provider is a real blocker, not permission
  to add aliases, hide units or silently modify the shared SDK architecture.
- No dependency on FPC `hash`, `fcl-hash`, PasZLib, OpenSSL, FPCUnit or Lazarus
  is permitted in this provider. Keep PPL off. Preserve upstream Hlp APIs;
  correct only demonstrated Nexus compiler incompatibilities, with regression
  proof against the untouched pinned source and saved review evidence.
- Preserve the Free Pascal notices for any support units incorporated into the
  binary closure; the upstream library's MIT identity does not relabel linked
  FPC implementation material. Record those dependencies in central attribution
  and the distribution's notices.
- Compose existing PackageBuild on Win64 and LinuxPackageBuild on Linux.
  Produce the real `HashLib4Pascal.nxpl`, matching compiler metadata and a
  published generation/hash manifest. Embedded metadata is the normal product;
  an `.nxp` file is the existing optional sidecar mode, without a fingerprint.
- Build the compiled test consumer through `RequiredPackages: [nxrtl,
  HashLib4Pascal]` and provider package search paths. Its recipe must omit Hlp
  source paths and stale Hlp NXUs. Hide the imported source for this proof.
  Publish nxrtl, HashLib4Pascal and the consumer from the same SDK generation.
  Exercise digest/interface creation, streamed data, returned managed byte
  arrays/strings, destruction, initialization and finalization across images.

### Private PasZLib CRC32

Add one package-internal `src/utNXPasZLibCRC32.pas`. Move the existing zstream
table and core update there, preserving inherited notices. Keep the table
immutable and initialized statically; no lazy mutable initialization or thread.
It provides only the operations needed inside compression:

1. Zlib-compatible complemented CRC update over `(seed, PByte, Cardinal)`:
   reflected IEEE polynomial `$EDB88320`, initial/final XOR `$FFFFFFFF`, nil
   buffer returns the zlib initial value zero, zero-length non-nil buffer
   retains the seed, and chunks continue the previously finalized result.
2. A raw single-byte state step for Zipper's current uncomplemented CRC/password
   operations. Do not substitute the complemented operation in key updates.
3. A stable pointer to 256 consecutive 32-bit table entries for the existing
   `PasZLib.get_crc_table` facade and internal table users.

Update `paszlib`, `gzio`, `zip`, `unzip`, `zstream` and `zipper` to use this one
implementation. Retain signatures and behavior of `PasZLib.crc32` and
`PasZLib.get_crc_table`; remove both duplicate tables after checking their
callers. The helper is not a separately published general-purpose hash API.
Add the matching include-style `System.ZLib.InternalCRC32` namespace wrapper
and mapping for dotted builds; no System.Hash.Crc fallback branch remains.

The canonical source remains F `packages/paszlib/src`. Forge may copy it into
isolated build staging as it already does; those are generated build inputs,
not another maintained package. External Packages gets no PasZLib source,
catalog entry or build mirror. Consumers use the configured NexusFPC source
path. Byte-comparison replacement removes MD5 from retained PasZLib tests.

### Metadata processing and unchanged compiler build

Keep NXPackageFile, FPCP, PCP and their existing callers in the current compiler
closure. Do not add compiler-role conditionals, move constants to a new unit,
remove package capability from a bootstrap binary or add another compiler
build. The existing seed/native/cycle1/cycle2/cycle3 builds, static RTL builds,
cycle comparisons and cycle3 output remain exactly as they are.

SDK construction, release tools, cross builds and release assembly continue to
use their existing compiler paths and order. No additional self-rebuild,
staging framework, output directory or compiler variant is introduced.

Remove StageMetadataHash, Stage_hash and their legacy hash search entries only
after metadata SHA-1 and PasZLib's external CRC imports have been removed and
verified. Retain existing PasZLib/compression staging and search paths. Do not
replace the deleted hash inputs with HashLib, a private SHA-1 or another
provider. This is dependency-list cleanup within the existing sequence.

### Straightforward metadata storage

Simplify NXPackageFile in place. Retain its current encode/decode/reference
entry points, existing zlib-compressed payload and embedded/default or optional
sidecar placement. Remove SHA1, TSHA1Digest, SHA1Buffer, the 20-byte fingerprint
field and all fingerprint comparisons. Keep the existing header's version,
placement and two lengths: a 20-byte header, followed by the compressed payload
when present. Use a distinct storage version (`NXPM0002`) so old 40-byte
NXPM0001 data cannot be silently misread.

Necessary checks are supported version and placement, bounded lengths and image
sections, expected payload presence, exact stream input/output and the existing
NXP/NXU structural validation. For sidecars, retain the filename lookup and
necessary placement/length consistency checks. Do not add a digest, checksum,
build-identity field, sidecar binding token, identity out parameter or another
validation layer. Existing package/SDK identity handling is unchanged.

The existing compression stream's integrity checks remain part of decoding;
this work adds no new hashing or checksum mechanism. Tests should reject
malformed storage and invalid metadata structure, not demand detection of every
valid same-sized replacement payload.

Reject old NXPM0001 storage with a clear rebuild-required diagnostic. Rebuild
the compiler, Forge codec consumer, SDK, providers and dependent bundles using
the existing build sequence. No legacy SHA-1 decoder or compatibility hashing
path is retained. There is no verified current external requirement to consume
old development envelopes. Inner NXP004/NXU formats and the native descriptor
ABI do not need revisions for this storage change.

HashLib source may compile into Forge for its separate, existing publication
SHA-256 operations, avoiding acquisition of a runtime package Forge itself
builds. HashLib is never an input to NXPackageFile, NexusFPC bootstrap or
PasZLib. Setup/torrent digest algorithms and ordinary publication hash contracts
remain unchanged.

## Scope

- One External Packages import and its identity, `.nxpk`, Forge/configuration,
  source/test selection, review, hashes, README and direct nxtest tests.
- The three catalogs, central attribution, package documentation and explicit
  source discovery entries that change as a direct consequence.
- The single PasZLib runtime/test closure, namespace mapping, README and
  affected source-path records.
- In-place removal of codec SHA-1 and fingerprint storage/comparisons, minimal
  storage-version/size updates and affected metadata tests/documentation.
- Removal of obsolete legacy hash staging/search entries only; all compiler
  builds, capabilities, outputs and the existing build sequence stay unchanged.
- Forge artifact/SDK SHA-256; Setup and Torrent hashing; demonstrated active
  fpGUI file-monitor use; useful Lab hashing examples.
- Narrow conversion of affected old build recipes to the current nxbuild FPC
  child form so these consumers can actually be verified. No build-engine
  redesign or broad project conversion.
- Updated existing `tests/dynamic-packages/package_metadata_test.pas` fixtures
  and focused direct nxtest metadata-storage regressions; no new bootstrap
  recipe or compiler-capability harness.
- Focused metadata version/rebuild/structure fixtures, SDK hash-algorithm tests,
  persisted Setup paths, torrent bytes and ZIP/GZIP CRCs.

## Out Of Scope

- Removing, disabling or stripping `hash`, `fcl-hash`, their namespace wrappers
  or retained non-hash services/tests.
- A second PasZLib source tree, a standalone CRC package, or any HashLib
  dependency in PasZLib runtime or tests.
- Changing ordinary digest algorithms, byte widths, wire values, existing
  Setup directories, digest case or SDK fingerprint serialization. The metadata
  envelope change explicitly specified above is in scope.
- Replacing RSA/ECC/ECDSA/ASN.1/PEM/OTP/UUID/NTLM/Unix crypt services merely
  because HashLib is imported; replacing independent OpenSSL/Synapse/private
  library hashing; a general crypto framework or public re-export layer.
- New product threads, PPL activation, new Bash scripts/build wrappers,
  auto-acquisition, package scheduling, Lazarus or Delphi compiler validation.
- Compiler variants, package-capability conditionals, extra compilation stages,
  additional compiler self-builds, new compiler outputs or any change to the
  existing bootstrap/build order, cycle comparisons or downstream compiler paths.
- HashLib, a private SHA-1, new hashing/checksum mechanisms or replacement
  dependencies in metadata processing or compiler bootstrap; a sidecar identity
  scheme or a legacy SHA-1 decoder solely for compatibility. PasZLib's private
  CRC32 remains the previously approved compression-only decision.
- Silent SDK ownership changes, a new Linux SDK builder, or an unrelated
  compiler/release-toolchain rewrite to make an unavailable target appear
  verified. Missing prerequisites remain explicit blockers.

## Staged Implementation Plan

After initial approval, complete all stages in one continuous implementation
pass. Resolve routine implementation and verification issues within this scope;
do not return for import, CRC, migration, test or publication phase approvals.
Report actual external constraints only after completing all unaffected work.

### 1. Freeze inputs and establish validation prerequisites

Re-read the inventories and owner changes. Record current source revisions,
licenses and before-source hashes. Inspect compiler/SDK metadata and actual
nxrtl unit ownership for each available target. Locate matching current SDKs;
do not use prior disposable nxrtl test images as a complete SDK. Resolve usable
SDK locations/configuration as part of the work. An unavailable target must be
reported accurately rather than described as verified.

Capture existing fingerprint/Setup/torrent/metadata fixtures before migration.
Keep all output under ignored, isolated build directories. No full rebuild in
the shared working checkout. Record exact seed, compiler, RTL, LLVM and SDK
identities in the eventual review.

### 2. Make PasZLib independent

Prove the current CRC facade/table/stream behavior against independent zlib,
then consolidate the CRC code as specified. Replace the retained test's MD5
comparison with actual byte equality. Build ordinary and dotted runtime units
with no legacy hash path and no Hlp source/package paths. Run the focused CRC
tests, retained stream/ZIP tests, independent ZIP/GZIP interoperability and
affected image/database consumers. This package stays independent regardless
of which compiler build stage consumes it.

### 3. Remove metadata hashing within the existing build sequence

1. Simplify NXPackageFile as specified: delete SHA-1 operations and its stored
   field, retain the 20-byte structural header with a new storage version, and
   adjust reference/sidecar handling and diagnostics. Keep existing entry points
   and callers; do not add identity plumbing or alter package capability.
2. Update existing metadata tests and add focused direct nxtest regressions for
   embedded/sidecar roundtrips, necessary structural rejection and old-version
   rebuild diagnostics. Replace obsolete fingerprint assertions with storage
   and structure assertions; do not invent replacement tamper guarantees.
3. With both metadata SHA-1 and external PasZLib CRC removed, delete obsolete
   hash staging/search entries from the existing Forge recipes. Keep compression
   inputs and every existing compiler/RTL/tool/SDK/cross/release build, flags,
   output and ordering unchanged. Check the recipe diff specifically for this.
4. Use the existing Forge bootstrap in an isolated checkout with its stock
   FPC 3.2.2 seed. Verify the existing native/compiler generations, static RTL
   and cycle2/cycle3 comparisons, with no legacy hash or HashLib input available.
   The same codec and self-contained PasZLib remain in the compiler closure.
5. Rebuild Forge with the simplified shared codec before it reads new artifacts.
   Its ordinary SHA-256 implementation remains a separate migration below.
   Rebuild available SDKs, providers and consumers through the existing sequence;
   validate embedded and sidecar storage, package creation/consumption and old
   storage rejection. Report unavailable host/SDK prerequisites accurately.

No new compiler build, variant, stage, dependency or replacement fingerprint is
part of this step. Complete the approved sequence without intermediate owner
approval handoffs.

### 4. Import and verify the HashLib provider

Import the pinned selection, preserve notices, save the source/integration
review, add identity/manifest/recipes/tests and catalog entries. Port useful
vectors directly to nxtest. Establish source known-answer coverage, then
build/publish the real runtime provider and source-free consumer on each
available matching SDK. HashLib's upstream FPC minimum is not a reason to
insert it into compiler bootstrap.

Run ordinary and smart-linked consumer variants. Exercise available scalar and
normal SIMD dispatch for tested algorithms. A SIMD/compiler incompatibility
must be localized and proven before correction; a forced-scalar run alone must
not be reported as proof that the default package works.

### 5. Migrate ordinary consumers in dependency order

1. Forge's ordinary artifact/SDK SHA-256 hashing and revised codec consumption.
   Compare fixed byte-input hash vectors with the baseline. Newly rebuilt
   compiler/envelope bytes legitimately produce new artifact/SDK hashes; retain
   the established hashing algorithm, canonical input ordering and case.
2. Setup state path hashing and its deterministic tests; prove existing state
   discovery, not just agreement between two newly changed methods.
3. Torrent info/piece hashing and test helpers; test bytes containing zeros and
   high bytes, existing raw-info slices, cross-file pieces and corrupt pieces.
4. Establish actual full fpGUI IDE/file-monitor reachability and migrate it if
   active. Hashing-test executables alone do not settle this question.
5. Useful Lab hash demonstrations and affected source/test build paths.
   Retain non-hash crypto examples and legacy service suites. Keep all example
   programs in Lab; no examples copied into library imports.

Use the existing caller-owned flow, direct upstream interfaces and short local
methods. Preserve raw bytes before hex formatting. In particular, old
`SHA1String` accepts RawByteString; do not replace it with text transcoding via
`ComputeString` just because both parameters are named string.

### 6. Reconcile the audit and hand off retirement blockers

Repeat whole-repository uses/symbol/path searches and clean-build the affected
closures. Update every inventory row with verified active/inactive status,
result, current owner and remaining dependency. Save before/after proof and
unverified targets in the package review and matching implementation review.
Do not manufacture passing results for absent SDKs/platforms.

The remaining blocker list must explicitly include non-hash services,
unresolved bootstrap/source/SDK issues, legacy service tests, and any unproven
fpGUI/conditional platform path. This is a final audit deliverable, not another
approval checkpoint. No deletion of `hash` or `fcl-hash` occurs in this scope.

## Sub-Agent Delegation

Implementation remains local. Neither this plan nor approval to implement it
authorizes sub-agent use.

## Verification Plan

All commands below are **planned after explicit implementation authorization**.
None was run while preparing this plan. New recipe names below are planned
artifacts, not files that already exist.

### Commands and host prerequisites

Use installed Nexus nxbuild and Forge binaries, selected explicitly as
`HASH_NXBUILD` and `HASH_NXFORGE`. Set `HASH_NEXUS_ROOT` to Nexus and
`HASH_FPC_ROOT` to NexusFPC, and configure the recipes with absolute
SDK/work/output paths.
On this host NexusFPC is the sibling `../nexus-fpc`; checked-in Windows guides
use `tools/nexus-fpc`. Resolve the actual configured path, not a guessed extra
`../..` that happens to fit another machine. No automatic downloads or symlink
source-layout workaround is part of the plan.

From Nexus on Linux, run the package and affected-consumer checks once a
matching SDK is available:

```sh
"$HASH_NXFORGE" /input="$HASH_NEXUS_ROOT/packages/nexus-packages-ext/hashlib4pascal/HashLib4Pascal.Forge.nxscript" /targets=Build:Package,TargetOS:linux,TargetCPU:x86_64
"$HASH_NXFORGE" /input="$HASH_NEXUS_ROOT/packages/nexus-packages-ext/hashlib4pascal/HashLib4Pascal.Forge.nxscript" /targets=Build:Tests,TargetOS:linux,TargetCPU:x86_64
"$HASH_NXBUILD" /action=build /project=packages/nexus-packages-ext/hashlib4pascal/tests/HashLib4PascalTests.nxproject
"$HASH_NXBUILD" /action=build /project=../nexus-fpc/packages/paszlib/tests/PasZLibTests.nxproject
"$HASH_NXBUILD" /action=build /project=packages/nexus-packages/graphics/fcl-image/FCLImage.nxpackage
"$HASH_NXBUILD" /action=build /project=packages/nexus-packages/db/fcl-db/FCLDB.nxpackage
"$HASH_NXBUILD" /action=build /project=projects/forge/test/NexusForgeTests.nxproject
"$HASH_NXBUILD" /action=build /project=projects/setup/test/NexusSetupTests.nxproject
"$HASH_NXBUILD" /action=build /project=packages/nexus-packages/network/torrent/test/NexusNetTorrentTests.nxproject
```

Use clean output directories and inspect loaded units so stale compiled hash
units cannot conceal a dependency. The compiler continues to compile its
existing metadata codec and self-contained PasZLib; only general-purpose hash
source and compiled-unit inputs are absent. Use the existing Forge bootstrap
configuration on a supported host, with no new recipe or compiler role.

For Windows, use the configured current Forge executable and an isolated
NexusFPC checkout in the documented layout:

```powershell
& $hashForge /input=NexusFPC.Forge.nxscript /targets=Build:Bootstrap
& $hashForge /input=NexusFPC.Forge.nxscript /targets=Build:Tools
& $hashForge /input=NexusFPC.Forge.nxscript /targets=Build:PackageSDK
& $hashForge /input=$hashPackageRecipe /targets=Build:Package,TargetOS:win64,TargetCPU:x86_64
& $hashForge /input=$hashPackageRecipe /targets=Build:Tests,TargetOS:win64,TargetCPU:x86_64
```

`$hashPackageRecipe` is the absolute path to the new package recipe above.
Rebuild/select Forge with the simplified codec before SDK/publication reads;
an old reader cannot validate the new storage layout. The existing Windows
bootstrap uses stock `C:/fpc/3.2.2/bin/i386-win32/ppc386.exe`, then the existing
native generations and cycle comparisons. Preserve that sequence exactly.
The full checked-in Bootstrap target is Windows-oriented and is not a
Linux-native command. Do not introduce a new Linux builder/configuration or
additional compilation stage to fill that verification gap; report the missing
supported host/configuration and SDK as explicit limits.

After each build, run its actual produced direct nxtest executable and verify
exit status, nonzero test count and zero failures/errors. The package Forge
test target also runs the published source-free consumer. Run PasZLib's
retained programs in a disposable working directory with `test.zip`; retain
the existing large Zip64 test's adequate timeout. Build and run useful changed
Lab examples through Nexus recipes. Run existing hash/FCL Hash nxtest suites
as legacy baselines after authorization, without deleting useful coverage.

### Behavioral and negative coverage

| Area | Required checks |
| --- | --- |
| HashLib API | MD5/SHA-1/SHA-256/HMAC fixed known answers; bytes, explicit string encoding, file and stream; empty input, zeros/high bytes, boundary lengths, chunked updates and reset/clone where used |
| Hex/digest contracts | 16/20/32 raw digest bytes; no grouped hex; legacy SHA-1/MD5 lowercase; Forge SHA-256 uppercase; exactly preserved Setup and torrent outputs |
| Runtime package | Real nxpl metadata and required nxrtl build identity; source hidden/no Hlp NXUs; ordinary and smart linking; interface/array/string lifetime across images; provider absent or wrong generation rejected; no source fallback |
| PasZLib CRC | `123456789` -> `CBF43926`; empty, nil with zero/nonzero seed, non-nil zero length, arbitrary initial seed, binary buffers and split continuation; all table entries/pointer stability, independent zlib comparison |
| ZIP/GZIP | Both low-level gzio/zip/unzip and zstream/zipper APIs; stored/deflated/empty/multiple entries; little-endian stored CRC/trailer fields; corrupted CRC rejected according to current API; retained Zip64 coverage; independent archive encode/decode and password ZIP fixture |
| Compression self-containment | Clean ordinary and dotted builds with no hash or HashLib paths and no stale matching units; actual imports/closure inspected; retained tests use byte equality |
| Metadata storage | Embedded and sidecar roundtrips with the minimal 20-byte header; invalid version/mode/length, truncated image/stream, absent payload and invalid compressed stream rejected; old NXPM0001 rejected with rebuild advice; no fingerprint field, identity extension or legacy hash decoder |
| Metadata structure | Retain existing NXP/NXU bounds, entry/header and CPU/target/SDK/name/dependency validation; preserve existing native-descriptor and publication manifest checks; no new sidecar association or replacement-payload detection requirement |
| Stock seed/bootstrap | Existing FPC 3.2.2 seed/native/cycle compiler and static RTL builds in an isolated checkout; codec and self-contained PasZLib remain available; loaded-unit/object closure proves no legacy hash or HashLib dependency; ordinary and package compilation capabilities remain unchanged |
| Existing downstream builds | Existing cycle3 compiler remains the tool/SDK/cross/release input; nxrtl build, package metadata processing and source-free package consumption succeed through the unchanged recipes |
| Build-sequence preservation | Recipe diff contains only obsolete hash-input cleanup; existing seed/native/cycle1/2/3 and RTL builds, flags, outputs, cycle2/cycle3 equality checks and downstream ordering remain unchanged; no added compiler build or variant |
| Forge SDK/artifacts | SHA-256 algorithms, case and input ordering unchanged for fixed byte inputs; fresh metadata/compiler bytes correctly change artifact hashes and SDK identity; existing GUID behavior retained; old-envelope/malformed/mismatched bundles fail without selecting a new generation |
| Setup | Preexisting `.nx/setup/<lowercase-sha1>` location found; byte encoding and non-ASCII product IDs; no automatic state migration or changed directory algorithm |
| Torrent | Fixed raw bencoded info slice, zero/high-byte payloads, 20-byte hashes, percent-encoded/wire consumers unchanged, cross-file pieces and corruption; test helper independent expected values |
| Coverage failures | Prove a failure before fixing; distinguish invalid test expectations from real bugs; record missing target/tool prerequisites explicitly; never weaken a format assertion to obtain a pass |

Focused searches after changes must show no `crc`/`System.Hash.Crc`, Hlp unit,
HashLib package or legacy hash search path in the PasZLib runtime/test closure.
NXPackageFile must have no SHA1/TSHA1Digest/SHA1Buffer, fingerprint field or
comparison, HashLib import or replacement hash/checksum dependency. Existing
FPCP/PCP/NXPackageFile and compression imports remain in the compiler closure.
Compiler source/loaded-unit inspection must show no general-purpose hash input;
existing internal FPCHash/NXU integrity code is outside that dependency cleanup.
Inspect the Forge diff to confirm all compiler stages, outputs and order are
unchanged. Forge's ordinary SHA-256 consumer is classified separately. Other
legacy references remain only in classified retained services/tests or explicit
unresolved blockers. Source search must cover namespace wrappers, scripts,
catalog descriptors and editor search-path records, not just Pascal uses.

Manually inspect from a clean consumer directory: discover the new catalog
entry, follow its license/attribution link, build with documented SDK selection,
consume through RequiredPackages with upstream source unavailable, and inspect
the published provider/foundation closure. Record Windows/Linux results
separately. No GUI behavior or unavailable cross target is implied by a native
console test.

## Risks And Verification Limits

1. **PasZLib ownership is settled.** There is one canonical tree in NexusFPC.
   The request's two-copy language is superseded; no decision remains about
   using an external hash package or restoring the retired duplicate.
2. **SDK availability and support-unit ownership remain prerequisites.** The
   configured Linux SDK is absent; Windows is not executable here. Existing
   disposable nxrtl images do not prove a complete matching SDK. If a new SDK
   construction path or shared RTL ownership change is unavailable within this
   scope, record the concrete target limitation in the completed results.
3. **Hash-input removal has two prerequisites.** Metadata SHA-1 and PasZLib's
   external CRC must both be gone before deleting their legacy hash staging and
   search entries. No constraint requiring a replacement metadata hash or a
   bootstrap/build-sequence change was found. Current compiler closure, cycle3
   selection and capabilities are preserved.
4. **Source inspection is not execution proof.** The existing bootstrap without
   legacy hash inputs, simplified metadata storage and ordinary HashLib
   SIMD/platform/package behavior need their specified builds. No build or
   test was run in this planning revision.
5. **Zipper has raw-state CRC uses.** Consolidating only complemented APIs can
   preserve simple roundtrips yet break password processing; independent
   encrypted fixtures and raw-byte update vectors are required.
6. **A source reference is not a shipping product.** Full fpGUI IDE activity,
   older benchmark/test entry points and conditional platforms need explicit
   build reachability classification; preserve evidence and report uncertainty.
7. **Retirement remains blocked by non-hash behavior.** RSA, ECC, ECDSA, ASN.1,
   PEM, HOTP/TOTP, HKDF, UUID, NTLM and Unix crypt retain their current ownership
   because replacing those services is outside this plan. No absence of ordinary application uses
   authorizes deleting their tests, APIs or original source packages.
8. **Removing the fingerprint removes that comparison guarantee.** A valid,
   same-sized replacement sidecar is not required to fail storage validation.
   Do not compensate with a new identity/checksum mechanism. Existing package
   identity and publication-manifest checks keep their current responsibilities.
9. **The storage transition requires a coordinated rebuild.** An old compiler
   or Forge reader must not be mixed with new SDK/provider envelopes.
   Reject old storage versions; do not preserve a SHA-1 decoder simply to avoid
   rebuilding development artifacts. Ordinary Setup/torrent formats stay intact.

## Execution

This handoff creates, commits and pushes **only this work plan** for review.
No implementation starts during the planning handoff.

Once the owner approves the plan, complete its entire implementation and
verification scope in one pass, without intermediate approval gates. The
completion report includes the import, private PasZLib CRC, consumer migrations,
metadata hash removal, unchanged compiler bootstrap/build sequence, test/build
evidence and residual dependency inventory. Legacy packages remain
intact under the defined non-goals; there is no additional retirement approval
step inside this work.

## Appendix A: Pinned runtime unit declaration

Every name below corresponds to one `.pas` under the indicated directory in
the pinned `HashLib/src` tree. These 144 units, plus all 135 include files,
form the upstream runtime import; compiler-resolved standard support units are
recorded separately per target, as specified above.

```pascal
package HashLib4Pascal;
requires nxrtl;
contains
  { Base }
  HlpHMACNotBuildInAdapter,
  HlpHash,
  HlpHashBuffer,
  HlpHashCryptoNotBuildIn,
  HlpHashFactory,
  HlpHashResult,
  HlpHashRounds,
  HlpHashSize,
  HlpKDF,
  HlpMultipleTransformNonBlock,
  { Checksum }
  HlpAdler32,
  HlpCRC,
  HlpCRCCore,
  { Crypto/Blake2BParams }
  HlpBlake2BParams,
  { Crypto/Blake2SParams }
  HlpBlake2SParams,
  { Crypto }
  HlpBlake2B,
  HlpBlake2BP,
  HlpBlake2S,
  HlpBlake2SP,
  HlpBlake3,
  HlpGOST3411_2012,
  HlpGost,
  HlpGrindahl256,
  HlpGrindahl512,
  HlpHAS160,
  HlpHaval,
  HlpMD2,
  HlpMD4,
  HlpMD5,
  HlpMDBase,
  HlpPanama,
  HlpRIPEMD,
  HlpRIPEMD128,
  HlpRIPEMD160,
  HlpRIPEMD256,
  HlpRIPEMD320,
  HlpRadioGatun32,
  HlpRadioGatun64,
  HlpSHA0,
  HlpSHA1,
  HlpSHA2_224,
  HlpSHA2_256,
  HlpSHA2_256Base,
  HlpSHA2_384,
  HlpSHA2_512,
  HlpSHA2_512Base,
  HlpSHA2_512_224,
  HlpSHA2_512_256,
  HlpSHA3,
  HlpSnefru,
  HlpTiger,
  HlpTiger2,
  HlpWhirlPool,
  { Hash128 }
  HlpMurmurHash3_x64_128,
  HlpMurmurHash3_x86_128,
  HlpSipHash128,
  HlpXXHash128,
  { Hash32 }
  HlpAP,
  HlpBKDR,
  HlpBernstein,
  HlpBernstein1,
  HlpDEK,
  HlpDJB,
  HlpELF,
  HlpFNV,
  HlpFNV1a,
  HlpJS,
  HlpJenkins3,
  HlpMurmur2,
  HlpMurmurHash3_x86_32,
  HlpOneAtTime,
  HlpPJW,
  HlpRS,
  HlpRotating,
  HlpSDBM,
  HlpShiftAndXor,
  HlpSuperFast,
  HlpXXHash32,
  { Hash64 }
  HlpFNV1a64,
  HlpFNV64,
  HlpMurmur2_64,
  HlpSipHash,
  HlpXXHash3,
  HlpXXHash64,
  { Interfaces }
  HlpICRC,
  HlpIHash,
  HlpIHashInfo,
  HlpIHashResult,
  HlpIKDF,
  { Interfaces/IBlake2BParams }
  HlpIBlake2BParams,
  { Interfaces/IBlake2SParams }
  HlpIBlake2SParams,
  { KDF }
  HlpArgon2TypeAndVersion,
  HlpPBKDF2_HMACNotBuildInAdapter,
  HlpPBKDF_Argon2NotBuildInAdapter,
  HlpPBKDF_ScryptNotBuildInAdapter,
  { Misc }
  HlpArmHwCapProvider,
  HlpArmSimdFeatures,
  HlpBinaryPrimitives,
  HlpBitOperations,
  HlpConverters,
  HlpCpuFeatures,
  HlpDarwinSysCtl,
  HlpHashLibExceptions,
  HlpHashLibTypes,
  HlpSimdLevels,
  HlpX86SimdFeatures,
  { NullDigest }
  HlpNullDigest,
  { Simd/Backend }
  HlpAdler32ArmBackend,
  HlpAdler32X86Backend,
  HlpArgon2ArmBackend,
  HlpArgon2X86Backend,
  HlpBlake2BArmBackend,
  HlpBlake2BX86Backend,
  HlpBlake2SArmBackend,
  HlpBlake2SX86Backend,
  HlpBlake3ArmBackend,
  HlpBlake3X86Backend,
  HlpCRCArmBackend,
  HlpCRCX86Backend,
  HlpSHA1ArmBackend,
  HlpSHA1X86Backend,
  HlpSHA2_256ArmBackend,
  HlpSHA2_256X86Backend,
  HlpSHA2_512ArmBackend,
  HlpSHA2_512X86Backend,
  HlpSHA3ArmBackend,
  HlpSHA3X86Backend,
  HlpScryptArmBackend,
  HlpScryptX86Backend,
  HlpXXHash3ArmBackend,
  HlpXXHash3X86Backend,
  { Simd/Facade }
  HlpAdler32Simd,
  HlpArgon2Simd,
  HlpBlake2BSimd,
  HlpBlake2SSimd,
  HlpBlake3Simd,
  HlpCRCSimd,
  HlpSHA1Simd,
  HlpSHA2_256Simd,
  HlpSHA2_512Simd,
  HlpSHA3Simd,
  HlpScryptSimd,
  HlpXXHash3Simd,
  { Utils }
  HlpArrayUtils;
end.
```
