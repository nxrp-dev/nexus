# HashLib4Pascal package and hash consumer audit: implementation review

Date: 2026-10-17.
Authorization: owner approval, "make it so", following plan commit
`bd29eee6d30ea5da4642a5a319c63c169b00877c`.
Status: implementation pass completed; compiled-package and full compiler-cycle
verification remain blocked by native host/SDK prerequisites described below.

The [approved plan](../plans/hashlib4pascal-package-and-hash-consumer-audit.md)
defines this scope. This review records actual results, including its limits.
No legacy package was removed and no implementation commit was created by this
pass. The owner's concurrent compiler/RTL work was preserved.

Subsequent owner direction, 2026-10-17: remove the bundled Maximus IDE entirely.
Its complete source/test/assets/templates tree and module registration were
deleted. The owner separately approved deleting Nanoedit, its only external
editor-widget consumer. These applications and the IDE's 488-case suite are no
longer retained; the PDR/OPDF integration is no longer a verification blocker.
Removal verification: no remaining production/example uses-clause imports of
IDE/editor/PDR units; clean native framework build and 566 passing tests (one
existing external-HVIF-fixture skip). Archived Maximus tests/templates were also
removed from the migration archives/manifests; all other archived file hashes
remain unchanged. The dependent Nanoedit source/assets/fixtures were deleted.

## Resulting architecture

`compiler/nxpackagefile.pas` still belongs to the existing compiler closure. Its
storage header is now **20-byte NXPM0002**: signature, storage mode, raw length
and compressed length. SHA-1 import, digest field, calculation and comparison
are deleted. Existing zlib integrity/exact-consumption checks, header/range
checks and the existing PCP/NXP/NXU validation remain with their current owners.
There is no replacement hash, identity token, association framework or legacy
SHA-1 reader. Sidecar consistency checks compare the two sizes. A same-sized
valid replacement is not required to fail an obsolete fingerprint comparison.

NXPM0001 is rejected with rebuild advice. Compiler/Forge readers, SDKs, providers
and dependent bundles require a coordinated rebuild; old envelopes are not
silently accepted. Setup state paths and torrent wire formats are unchanged.

The compiler build sequence is unchanged. Comparing the four edited Forge
recipes to the untouched pre-pass files, after removing only StageMetadataHash,
Stage_hash and their obsolete hash search inputs, produces exact byte matches.
Seed/native/cycle1/2/3 builds, flags, output paths, static RTL, cycle comparisons,
and subsequent tool/SDK/cross/release compiler selections remain unchanged.
PasZLib staging remains. No compiler variant, extra stage or SDK builder was
introduced. Ordinary Forge source builds now explicitly use the existing native
compiler/RTL settings and preserve the `NexusForge-next/<target>/nxforge` output.

The only canonical PasZLib is `nexus-fpc/packages/paszlib`. Its private
`utNXPasZLibCRC32` owns the existing IEEE reflected table and core update.
PasZLib's public crc32/get_crc_table facade remains. gzio, zip, unzip, zstream,
zipper and retained tests have no HashLib or legacy hash dependency. Duplicate
ZStream/Zipper tables and the MD5-only test equality dependency were removed.
Dotted wrappers map to the same implementation.

HashLib4Pascal is an ordinary library/tool dependency in External Packages.
Its original Hlp API is consumed directly; no public wrapper was added.

## Import and package infrastructure

The pre-integration source review is saved with
[the destination package](../../packages/nexus-packages-ext/hashlib4pascal/CODE_REVIEW.md).
Upstream revision is `1687d81fd0c8a08f3f04e7fed507a19131fbc0b1`. All **281** selected
files match the pinned archive and import-hash manifest: 144 runtime
Pascal units, 135 includes, LICENSE and README. No upstream algorithm was patched.
The original source tree is the untouched import; temporary proof copies and
logs are not a second maintained package or a tracked evidence archive.

Added Package.nxscript (`NXRP.HashLib4Pascal`), an explicit 144-unit `.nxpk`
requiring nxrtl, Forge provider/ordinary/smart-consumer recipes, a native source
test recipe, usage documentation and three discovery records. Root
ATTRIBUTIONS.md records MIT provenance and the licensing of FPC support units;
original notices are retained. Default SIMD dispatch stays enabled; PPL stays
disabled. No product thread was added.

The clean source closure includes all 17 Hlp unit directories, Include and
Simd/Backend include directories, native RTL, RTL Object Pascal/Generics, FCL
Base and pthreads support. The nested SIMD include directory was a necessary
recipe correction, not an upstream algorithm change. The `.nxpk` list exactly
matches the imported 144-unit set.

All three catalogs and HashLib/Torrent Package descriptors pass NexusScript
dialect validation. Editor source discovery includes the 17 Hlp directories and
retains legacy discovery paths for services still in use. The changed
language-server search-path unit compiles with native NexusFPC.

The pinned revision has **no HashLib.Tests/Data directory**. The plan's raw-data
tree reference was factually incorrect; no invented directory or unused upstream
test hierarchy was imported. Useful inline vectors were adapted directly to
nxtest with attribution. No FPCUnit bridge/helper/runner was introduced.

## Proven failures and fixes

### Minizip CRC sign

Before source: NexusFPC `00fb95dfe417ed7b7819f8414af9fb30c3735e61`, saved untouched
before edits; `zip.pas` SHA-256
`a750cefadedb7010c12e4a09717410d7b41f03f6fba4249663ef2166da01a43a`.
This digest matches the saved untouched source and its baseline manifest; the
Git revision identifies the reproducible original.

CRC state and stored CRC fields were LongInt. Checked ZIP writes raised
ERangeError in zipWriteInFileInZip when a split update set bit 31. Split unzip
reads failed for the same reason. An independent one-byte-NUL stored ZIP with
CRC D202EF8D also failed when the stored value became running state.

The running/waiting/stored CRC fields now use Cardinal. At the existing signed
four-byte header reader boundary, Move preserves the field's 32-bit pattern;
no numeric range conversion or unrelated parser rewrite is introduced.
Direct nxtest MiniZipInteroperability and MiniZipHighBitCRC cover split updates,
stored/deflated entries, independent input, stored fields and corrupt CRC
rejection. The before probes exit 217 with ERangeError; the same after probes
exit zero. The full focused suite passes under native NexusFPC and stock FPC.

### MD demo false success

Before source: Lab `2f7cf1cf1164698b08d58a5a07f254271f56e435`,
`examples/data/hashes/mdtest.pas`. Its success flag became true if any vector
matched, so a wrong expected value could be masked by later passing vectors.
Changing only the first expected MD2 digest to zeroes makes the untouched driver
exit zero. The corrected driver exits one at that case. All 21 RFC 1319/1320/1321
vectors remain in direct nxtest and the normal migrated demo passes.

### Tests and prerequisites diagnosed

No failed assertion was weakened or removed. The retained FCL Hash PEM test
initially lacked its relative private-key.pem fixture because it was launched
from Nexus; running from its existing tests directory passes all 31 cases.
Forge's real compiler fixtures require NexusFPC `fpc` on PATH and a built
NexusCSV; selecting stock fpc produced the wrong unit format. With the native
compiler/config and the existing CSV prerequisite, all 54 tests pass.
IDE tests require their existing resources working directory and writable test
configuration; the correctly launched retained suite passes 488 cases.

The plan's password/encrypted-ZIP claim was also incorrect: current PasZLib
explicitly rejects encryption and implements no password support. No encryption
feature or fixture for an unsupported success path was added.

## Ordinary consumer dispositions

Paths below are relative to their named repository. Every migrated digest call
uses exact existing raw bytes, without introducing text recoding.

| Owner / file | Result and contract |
| --- | --- |
| Nexus `projects/forge/src/utNXForgePackageFiles.pas` | SHA-256 stream hashing through Hlp; uppercase, ungrouped output retained; fixed-byte/package-publication tests pass |
| Nexus `projects/forge/src/utNXForgePackageSDK.pas` | Same SHA-256 input sorting, separators and serialization; stable expected fingerprint tests pass; no metadata hash added |
| Nexus `projects/setup/src/obNXSetupState.pas` | Raw product-ID bytes -> lowercase SHA-1; existing `.nx/setup/<digest>` path preserved; new fixed empty/abc/non-ASCII/NUL/high-byte checks pass |
| Packages `network/torrent/src/obNXTorrentMetaInfo.pas` | Exact original raw bencoded info slice -> same 20-byte SHA-1; fixed independent expectation added |
| Packages `network/torrent/src/obNXTorrentFileStore.pas` | Piece bytes -> same 20-byte digest; cross-file/corruption fixtures pass |
| Packages `network/torrent/test/NexusNetTorrentTests.lpr` | Hlp fixture helper plus independently fixed binary/info expectations; full socket-backed suite passes |
| Packages former `gui/external/fpgui/ide/src/main/pascal/ide.filemonitor.pas` | Removed with the complete Maximus application by subsequent owner direction; no remaining hash consumer |
| Lab `examples/data/hashes/mdtest.pas` | Direct MD2/4/5 Hlp calls; every retained vector must match; demo and corresponding nxtest cases pass |
| Lab `examples/data/hashes/hmd5.pas` | Direct HMAC-MD5, same key/data ordering; both printed fixed answers match |
| Lab `examples/data/hashes/hsha1.pas` | Direct HMAC-SHA1; both fixed-answer checks pass |
| Lab `examples/data/hashes/md5performancetest.pas` | Direct MD5 untyped bytes, lowercase hex; compiles/runs; no performance guarantee inferred |
| Lab `examples/data/hashes/sha1performancetest.pas` | Direct SHA-1 untyped bytes, lowercase hex; compiles/runs |
| Lab `examples/data/cryptography/demosha256.pas` | Direct SHA-256, explicit input bytes and uppercase hex; fixed empty/abc checks pass |
| Lab `examples/data/cryptography/sha256performancetest.pas` | Direct SHA-256; obsolete SHA256PASCAL instructions removed; compiles/runs |
| Lab `examples/gui/fpgui/gui/threads1/workerthread.pas` | Direct ComputeFile; existing blocking file-I/O worker/lifecycle unchanged; changed unit compiles against native fpGUI/HashLib closure |

The former Maximus application had an incomplete PDR/OPDF debugger integration.
Its version-based guard enabled OPDF on NexusFPC, although the native compiler
rejects `-gO` and has no OPDF emitter. This was an unsupported application feature,
not a HashLib requirement. The owner retired the entire application instead of
adopting that debugger; no compiler changes or replacement debugger were added.

Affected Forge, Setup and Torrent recipes now use current explicit FPC-child
syntax and source closure instead of obsolete schema/wildcard compiled units.
FCL Image, FCL DB, the fpGUI framework test recipe and 14 Lab recipes no longer
carry unnecessary legacy hash paths. No compiler bootstrap recipe was reshaped
to accommodate an ordinary tool dependency.

## Verification results

Host: native x86_64 Linux. NexusFPC 3.3.1 and its matching installed RTL;
stock FPC 3.2.2 with its own RTL for focused seed-compatibility checks.
Nexus nxbuild and the rebuilt Nexus Forge performed the builds. No Windows/WSL
compiler, SDK or runtime was used for these results.

| Check | Actual result |
| --- | --- |
| HashLib complete source closure / direct nxtest | All 144 units compile; **10 passed**, zero failures/errors/skips |
| Canonical PasZLib / direct nxtest | **11 passed**, native; **11 passed**, stock FPC 3.2.2; range/overflow/I/O/assertion checks enabled |
| PasZLib retained tests | Stream-seek, single-entry and full enabled ZIP/Zip64 suite pass, including 65,537 entries |
| Dotted compression core | Public CRC known answer and compression/decompression probe pass without hash/Hlp paths |
| Metadata direct nxtest | **3 passed** with native NexusFPC; **3 passed** with stock FPC 3.2.2 |
| Forge CLI / tests | Native CLI builds at the preserved output; **54 passed**; embedded/sidecar PE/ELF storage and SDK fingerprint checks included |
| Setup | Native application builds; **24 tests passed** |
| Torrent | Full native standalone suite passes, including localhost peer/wire fixtures and independent digest vectors |
| FCL Image | 56-unit package builds; **18 review regressions passed** |
| FCL DB | 66-unit package builds; **16 review regressions** and **943 retained behavior tests passed** |
| Former Maximus IDE | Subsequently removed entirely by the owner, including the previously passing 488-case suite; no active build or verification requirement remains |
| fpGUI framework | Native build passes; **566 tests passed**, zero failures/errors; one existing test skips because its external Haiku HVIF fixture is absent |
| fpGUI worker example / LS search paths | Both changed units compile with native NexusFPC |
| Migrated Lab hash demos | All **7** build and run with exit zero |
| Other affected Lab recipes | **14 of 14 build** after correcting the mobile recipe: Hello, special-name Hello, compression, database, JSON, XML, images, script editor, virtual tree, TLS genkeypair, TLS test1, XMPP, processes and the mobile plugin |
| Mobile plugin Lab recipe | Corrected its omitted NexusFPC `packages/libffi/src` path. Native Linux `libplugin_sample.so` builds, exports `luaopen_plugin_sample`, and requires `libffi.so.8`. All 16 C/Pascal ABI probe values match libffi 3.4.6; the existing integer/floating/managed-string RTTI invocation test passes. Simulator loading remains unverified |
| Retained legacy hash suites | `hash`: **14 passed**; `fcl-hash`: **31 passed**, including PEM/OTP/signature coverage |
| Descriptor/catalog validation | All three catalogs and both changed/new package descriptors pass dialect validation |
| Import/manifest/declaration | 281 unchanged original files; exact 144-unit nxpk; central attribution and original notices retained |
| Compiler sequence preservation | Four exact normalized recipe comparisons pass; only obsolete hash inputs removed |

HashLib tests cover fixed MD5/SHA-1/SHA-256/HMAC/CRC vectors, bytes/untyped,
explicit encoding, files/streams, incremental updates/clone/reset and binary
SHA padding boundaries. This is focused coverage of the migrated contracts,
not exhaustive validation of every algorithm in the upstream catalog.

Local logs and result JSON are under ignored `output/hashlib-audit`. Baseline
copies were temporary under `/tmp/nexus-hash-before`; no tracked evidence
archive, redundant provider source or copied test-runner hierarchy was added.
A fresh source checkpoint of Nexus, NexusFPC and Lab is produced with the
existing Linux archive helper under ignored `output/hashlib-audit/checkpoint`.

## Residual legacy ownership and removal blockers

A final comment-stripped uses-clause scan of tracked Pascal sources across all
five repositories finds no ordinary legacy digest import in migrated consumers.
The remaining import-bearing files are classified below. Dotted wrappers and
provider implementation includes remain with their existing owners.

| Files / owner | Remaining purpose and disposition |
| --- | --- |
| NexusFPC `packages/hash/src/{sha1,md5,crc,fnvhash}.pas` | Legacy providers retained by the approved non-goal; CRC also supplies CRC64/128 |
| `packages/hash/src/hmac.pas` | Internal MD5/SHA-1; retained for OTP/services |
| `packages/hash/src/ntlm.pas` | NTLM service and internal MD5; no protocol replacement authorized |
| `packages/hash/src/uuid.pas` | UUID byte-order/namespace/version semantics with internal MD5/SHA-1; retained |
| `packages/hash/src/unixcrypt.pas` | Unix password service; a digest substitution does not replace it |
| `packages/fcl-hash/src/{fpsha256,fpsha512}.pas` | Remaining SHA-2/HMAC/HKDF provider functionality for crypto services; retained |
| `packages/fcl-hash/src/fphashutils.pas` | Shared byte/encoding/crypto support types; retained |
| `packages/fcl-hash/src/{fpasn,fptlsbigint}.pas` | ASN.1 and big integers used by RSA/PEM; retained |
| `packages/fcl-hash/src/{fpecc,fpecdsa}.pas` | ECC/ECDSA with internal SHA-256; retained |
| `packages/fcl-hash/src/fprsa.pas` | RSA, ASN.1, big integers and internal SHA-1/SHA-2; retained |
| `packages/fcl-hash/src/fppem.pas` | Key/PEM parsing and thumbprints with ECC/SHA-256; retained |
| `packages/fcl-hash/src/onetimepass.pas` | HOTP/TOTP, HMAC/SHA-1, Base32/counter/time contracts; retained |
| `packages/hash/tests/{tsha1test,tcrctest,utestshmac}.pas` | Direct nxtest provider baseline; retained, all 14 cases pass |
| `packages/fcl-hash/tests/{utestsha256,utestsha512,utestpem,utestonetimepass}.pas` | Direct nxtest digest/signature/PEM/OTP baseline; retained, all 31 cases pass |
| NexusFPC `tests/bench/bmd5.pas` | Old benchmark source with no active build established; preserved and classified as inactive, not a production dependency |
| NexusFPC `tests/test/packages/hash/{tmdtest,sha1test}.pas` | Historical compiler-test fixtures; useful MD/SHA vectors are also covered by direct nxtest; no current runner was established or removed |
| Lab `examples/data/cryptography/{authenticator,gentotp}.pas` | OTP demonstrations still use onetimepass; retained non-hash service callers |
| Lab `examples/data/cryptography/dumppem.lpr` | ASN.1 demonstration still uses fpasn; retained |
| Lab `examples/data/cryptography/extractrsa.lpr` | RSA/ASN.1 demonstration still uses fprsa/fpasn; retained |

FCL DB's System.Hash.Base64 imports in xmldatapacketreader and fpxmlxsdexport
belong to FCL Base, not either legacy hash package. Synapse's internal algorithms,
the shared OpenSSL wrapper, FPImage/fpGUI/Abbrevia/Mustache private hashes,
Generics.Hashes and compiler FPCHash/NXU integrity code are independent owners
outside this migration. Search-path records for retained services/tests are
still intentional. Historical reviews and attribution are not active consumers.

Neither legacy package is ready for deletion: the retained crypto services and
their callers/tests require separately scoped ownership/API decisions. No
package retirement or unsupported Delphi validation is claimed here.

## Outstanding native verification

The installed native compiler tree contains bin, units and build-identity.json;
it has no runtime-package SDK. A scoped search of
`/media/kcollins/dev/source` and `/media/kcollins/dev/toolchain` found no usable
native SDK with a Linux target manifest, native compiler and nxrtl foundation.
The stale Linux setting that pointed through `/mnt/c` was removed; Linux
SDKDirectory is explicitly empty. No Windows fallback is used.

The HashLib Forge document validates, then `Build:Package` stops at Prepare:
`PackageBuildPrepare requires nonempty SDKDirectory and WorkDirectory`.
Therefore these required checks remain **unverified**:

- actual HashLib4Pascal.nxpl build/publication and its contained support units;
- SDK ownership/collision proof and coherent rebuilt NXPM0002 SDK/provider set;
- source-hidden ordinary and smart consumers, managed values/interfaces across
  provider images, and absent/wrong-generation provider rejection;
- complete isolated compiler bootstrap, cycle equality, SDK/cross/release reruns;
- full dotted compression closure with a matching dotted RTL.

This is an actual existing tooling constraint, not evidence that metadata needs
hashing. `NexusFPC.Forge.md`'s current deferred list explicitly states that native
Linux-hosted compiler/SDK construction through Forge is deferred. The checked-in
bootstrap names a stock Win32 seed compiler and `.exe` cycle outputs; Cross
still selects that existing cycle3. Preserving this sequence was a hard owner
requirement. This pass neither executes another host's toolchain nor introduces
a replacement native builder to obtain a passing claim. Focused stock/native
codec and compression tests establish source compatibility, not complete cycle
or runtime-package proof.

The implementation is available for owner review with these limits explicit.
