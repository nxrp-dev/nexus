# Work Plan: HashLib4Pascal Package and Hash Consumer Audit

Status: Proposed for owner review. After approval, execute the full scope in one pass.
Date: 2026-10-17.

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
- Owner architecture correction, 2026-10-17: the previous plan is not approved.
  Package metadata is not a prerequisite for compiler bootstrap. Remove that
  coupling instead of importing HashLib/SHA-1 into bootstrap. Reevaluate the
  envelope and sidecar association without treating NXPM0001 as immutable.
  This correction supersedes the request's earlier SHA-1 preservation and
  source-level bootstrap substitution requirements; the broader package import,
  ordinary consumer migration and private PasZLib CRC remain in scope.
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
- This architecture revision updates plan commit `358006f`. Bootstrap/metadata
  call sites were re-read in the current source, including the owner's ongoing
  unrelated compiler changes; none of those files is edited by this handoff.
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

Build bootstrap compilers without package metadata processing. Build the
normal package-capable compiler afterward from the verified bootstrap compiler.
Its metadata codec uses self-contained PasZLib, with no general-purpose hash
library. Replace the redundant SHA-1 envelope fingerprint with zlib integrity
and existing package build identity for sidecar association, using a new
envelope version and an explicit package/SDK rebuild policy.

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
   These reflect the current unconditional source coupling, not an inherent
   bootstrap requirement. Removing only PasZLib's CRC imports is insufficient;
   the metadata dependency boundary itself must change.

### Why metadata currently enters bootstrap

| Source evidence | What it establishes |
| --- | --- |
| `compiler/pp.pas` uses `compiler`; `compiler.pas` uses parser/link/target registration | Every ordinary compiler build reaches the parser and linker implementation closure |
| `compiler/pmodules.pas` imports FPCP/PkgUtil; FPPU and PkgUtil also reference TPCPPackage | Package types and branches are mixed into the ordinary module loader; deleting a uses item alone is not a coherent separation |
| `compiler/link.pas:450`, `systems/t_linux.pas:557`, `pmodules.pas:1846` | These clients import NXPackageFile only for the `.nxpl` constant; they need no codec, compression or hashing |
| `compiler/fpcp.pas` OpenPCP and SavePCP | Actual metadata I/O is here: ReadPackageMetadata for a package provider, EncodePackageMetadata/PackageMetadataReference when producing a package |
| `compiler/nxpackagefile.pas:38` | Its unconditional implementation imports ZBase, ZCompres, ZInflate and SHA1; all compiler references to those compression/hash units found in the current compiler tree are here |
| `compiler/pkgutil.pas` Load_Packages | Actual provider loading loops over PackageList; ordinary static builds with an empty list do not need package metadata I/O |
| `NexusFPC.Forge.nxscript` Bootstrap entries | Message/table generators, `pp.pas` programs and ordinary RTL `.pas` units are compiled; there is no `.nxpk` compilation or RequiredPackages selection in these steps |
| `NexusFPC.Forge.PackageSDK.nxscript` SharedRTL/HostStartup | The later SDK compiles `nxrtl.nxpk`, then uses the resulting package to compile startup code; this genuinely requires a package-capable compiler |
| `NexusFPC.Forge.PackageSDK.nxscript` Compiler; Tools.Config HostTool; Config CrossCompiler | They currently take cycle3's binary directly. They must select the later normal compiler after bootstrap/package capability is separated |
| `utils/bin2obj.pas:20` | This release tool genuinely imports ZStream. PasZLib may remain in that tool's closure even when removed from bootstrap; that does not justify a hash dependency |

No source-level necessity for package metadata processing during the existing
compiler/ordinary RTL bootstrap was found. The verified obstacles are the
unconditional imports, mixed-in package branches, and downstream recipes that
currently equate the verified cycle3 compiler with the distributable normal
compiler. These are implementation constraints to correct, not reasons to add
a replacement SHA-1 implementation.

### Existing metadata protections

- `zinflate.pas` CHECK1 compares the stored and computed Adler-32 before
  returning Z_STREAM_END; `nxpackagefile.DecodePackageMetadata` also requires
  exact input consumption and output length. This protects against ordinary
  compressed-payload corruption without SHA-1.
- `nxpackagefile` bounds-checks envelope and PE/ELF sections. FPCP/PCP validate
  NXP version/CPU/target, metadata entry sizes/terminators/checksum, unit ranges
  and embedded NXU headers. Retain these checks; the metadata checksum is the
  compiler's existing internal FPCHash operation, not a hashing package.
- FPCP.ReadContainerNames checks SDK identity; LoadPCP checks package name;
  PkgUtil.Load_Packages checks exact required-provider build identities. Forge
  additionally compares metadata and native image identities/dependencies and
  enforces SHA-256 artifact manifests during publication/consumption.
- These checks do **not** by themselves associate two independently valid,
  same-named/same-SDK sidecar generations. Current NXPM0001 binds them through
  the SHA-1 stored in the image reference. That association must be preserved
  explicitly if sidecars remain supported; zlib integrity is not identity.
- Existing FPkg.Current_Package_Build_Identity already creates a GUID-derived
  generation identity when none is supplied. Forge.NewPackageBuildIdentity does
  the same. `-Fk` accepts 1..64 hexadecimal characters; do not assume every
  existing identity is a fixed 16-byte GUID. These identities can supply the
  sidecar association without introducing a new hash provider.

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
| F `compiler/nxpackagefile.pas` | Current unconditional compiler dependency; actually needed for later package I/O and Forge artifact reading | NXPM0001 currently uses TSHA1Digest/SHA1Buffer | Exclude codec from bootstrap; remove SHA-1 from the later codec, version the envelope and bind sidecars through existing build identity; verify both compiler roles |
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
| F `NexusFPC.Forge.nxscript` | Remove metadata/hash staging and paths from bootstrap; add one ordinary post-bootstrap normal compiler build; keep matching bootstrap-cycle comparisons |
| F `NexusFPC.Forge.Config.nxscript` | Use the normal compiler for distributed cross compiler construction; no HashLib or legacy SHA-1 substitution; supply codec/PasZLib only where package capability is built |
| F `NexusFPC.Forge.Tools.nxscript`, `NexusFPC.Forge.Tools.Config.nxscript` | Drop unused Stage_hash; narrow PasZLib paths to genuine consumers such as bin2obj; copy/use the normal compiler, not the internal bootstrap binary |
| F `NexusFPC.Forge.PackageSDK.nxscript`, `NexusFPC.Forge.Release.nxscript`, tests/forge identity/release checks | Require the verified bootstrap and completed normal compiler; rewire compiler publication/SDK input paths and validate correct capability |
| F `packages/paszlib/tests/PasZLibTests.nxproject`, `packages/paszlib/README.md` | Drop hash paths after private CRC and byte-comparison test changes |
| F `packages/hash/tests/HashTests.nxproject`, `NXTEST.md`; `packages/fcl-hash/tests/FCLHashTests.nxproject`, `NXTEST.md` | Keep paths needed to test retained legacy services |
| F `nexusfpc-package-build-requirements.md` | Update current dependency notes; preserve historical context |
| N `projects/forge/NexusForge.nxproject`, `projects/forge/test/NexusForgeTests.nxproject`, `projects/forge/doc/contracts.md` | HashLib is for Forge's ordinary SHA-256 operations; its shared package codec loses SHA-1 and adopts the new envelope/identity checks; no compiler-bootstrap source staging |
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

The previous plan treated an accidental source closure as a bootstrap
requirement. Importing HashLib source would have preserved the coupling while
enlarging the seed's prerequisites. Package filename constants, ordinary module
compilation, package metadata I/O, and publication checks have different jobs.

Correct the existing dependency boundary: bootstrap needs the ordinary compiler
and static RTL, not package metadata. The later normal compiler needs the
metadata codec and self-contained compression. The codec does not need a
general-purpose fingerprint when zlib/structural checks protect its payload and
the existing package generation identity associates its sidecar. Ordinary
HashLib consumers and publication SHA-256 checks remain ordinary consumers.

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
  a fingerprint-bound `.nxp` is only the existing optional sidecar mode.
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

### Bootstrap boundary and later normal compiler

Move the real shared package filename/section/format constants into a small
`compiler/tpNXPackageFormat.pas`. Link, Linux's response writer, the parser and
the codec import that unit directly; NXPackageFile must not re-export aliases.
This unit has no file I/O, codec, compression or hash dependency.

Use one build-role conditional, `NEXUS_BOOTSTRAP`, on the compiler programs
built for bootstrap. Exclude the FPCP import and the existing branches that
actually use TPCPPackage in PModules, FPPU and PkgUtil. FPCP and its package
metadata processor/codec must not be compiled into that role at all. Gate
package input and `-FP` at their existing parser/option entry points with a
clear unsupported-in-bootstrap diagnostic; do not advertise
FPC_HAS_DYNAMIC_PACKAGES. The ordinary Load_Packages call sites may remain,
with the bootstrap branch doing no work for an empty package list and rejecting
a nonempty one. Never fabricate an empty/fake package or substitute a loader.

Keep the ordinary NXU reader and the small shared FPkg/GlobType declarations
that the general module model actually needs. Only the existing package
capability branches change; no wholesale compiler rewrite is proposed. No
interchangeable metadata service, plugin, callback registry, runtime mode
switch, duplicate class model or dependency framework is introduced.

The same source can then be compiled normally, without NEXUS_BOOTSTRAP, by the
verified bootstrap compiler. The compiler doing that compilation reads ordinary
Pascal/NXU source inputs; it does not need to process package metadata merely
because its output program will have that capability.

| Stage / artifact | Required functionality and dependencies |
| --- | --- |
| Stock FPC 3.2.2, message/table generators | Ordinary programs and source generation; no package metadata, PasZLib or HashLib introduced by this work |
| BuildSeedCompiler (`seed32`) and BuildNativeSeedCompiler | Bootstrap-role compiler, ordinary source/NXU compilation and static linking; no NXPackageFile, compression or general-purpose hash library in its closure |
| Native bootstrap compiler generations 1/2/3 and their static RTL builds | Same bootstrap role/settings for every generation; ordinary units/programs only, no package processing or external hash/compression inputs |
| Post-bootstrap BuildNormalCompiler | One ordinary FPC build using verified cycle3 and its matching static RTL, producing the normal compiler; its output includes package I/O and self-contained PasZLib, but no SHA-1/HashLib metadata dependency |
| Release tools | Only dependencies required by each tool; bin2obj can consume ZStream/PasZLib, while ppufiles/ppumove inspect NXU/entry data without the package envelope codec |
| Cross compiler construction | Use the normal native compiler and explicit source closure; distributed compilers retain their existing target capabilities, without introducing a hashing prerequisite for their construction |
| SDK foundation and startup | The normal compiler builds nxrtl.nxpk and consumes its package; metadata codec/PasZLib are now genuinely needed in the executing compiler |
| Runtime package build and compile-time consumption | Normal compiler encodes/decodes metadata and validates structural/identity contracts; HashLib is only a declared package being built/consumed where requested |
| Publication and manifest verification | Forge's ordinary SHA-256 consumer and existing image/metadata checks; this is not a compiler-bootstrap hashing dependency |
| Loading already built runtime packages | Existing native descriptors and exact dependency/build identity checks; runtime loading does not decompress the compiler metadata envelope |

Keep cycle2/cycle3 comparisons between identical bootstrap-role configurations.
Add BuildNormalCompiler as an ordinary child after bootstrap verification, with
its own clean unit/output directory, for example `build/forge-bootstrap/normal`.
`Bootstrap.Outputs.Compiler` and SDK, cross, release-tool/compiler-copy and
release checks must select that normal compiler. Internal cycle3 must not be
published accidentally or used to compile nxrtl.nxpk. Verify a normal-compiler
self-rebuild separately; never compare minimal and normal variants as though
their binaries should be identical.

Stage canonical PasZLib only for the normal compiler and tools that actually
need it, and remove StageMetadataHash rather than replace it with StageHashLib.
Keep the existing ordered Forge FPC/CopyFile/Compare operations. This adds a
small compiler capability boundary and one explicit normal build, not a new
staged build system. A prebuilt Forge still orchestrates the build; its own
ordinary publication hashing code is not linked into bootstrap compilers.

### Metadata envelope without general-purpose fingerprinting

Remove SHA1 from NXPackageFile rather than substitute another implementation.
Retain the existing zlib stream with its Adler-32 check, exact size/termination
checks, PE/ELF range validation, NXP structural/checksum/embedded-unit checks,
SDK/name/dependency identity checks and publication SHA-256 manifests.

Retain the established embedded/default and optional sidecar modes. Associate
sidecars by the **existing package BuildIdentity**, which already names an
immutable provider generation. Do not add another generated identity, CRC
provider, fingerprint field or cryptographic algorithm for that purpose.

Proposed envelope `NXPM0002`:

| Offset | Size | Meaning |
| --- | --- | --- |
| 0 | 8 | NXPM0002 signature/version |
| 8 | 4 | Existing placement mode: 1 payload present, 0 image reference |
| 12 | 4 | Uncompressed metadata length |
| 16 | 4 | Compressed metadata length |
| 20 | 1 | Existing build identity's byte length, 1..64 |
| 21 | identity length | Existing hexadecimal BuildIdentity bytes, preserving the established identity value |
| 21 + identity length | compressed length, mode 1 only | Existing zlib-compressed NXP payload |

Validate all lengths, modes, identity syntax and exact file consumption before
use. Image reference and sidecar must agree on version, lengths and build
identity. The encoding caller passes its existing Current_Package_Build_Identity;
it must be the same value written to the NXP payload and native descriptor.

The reader exposes the envelope's expected identity to its existing callers.
FPCP compares it with the decoded NXP BuildIdentity in ReadContainerNames before
contained NXUs are exposed. Forge compares it with ReadRawMetadata's Build
value before using that metadata, then retains its existing metadata/native
descriptor and manifest checks. Keep parsing responsibilities in those existing
owners; do not make the bootstrap parse native descriptors or introduce a
second generic NXP parser just to compare an identity.

Zlib alone cannot reject a valid sidecar from another generation. Test that
case explicitly, including equal lengths and the same package name/SDK. Also
reject disagreement between the envelope identity and the decoded identity.
Build identity is an association token, not a digest of arbitrary content:
deliberately publishing different valid bytes under the same reused identity
is not content-authenticated by this envelope. Existing immutable generations
and enforced SHA-256 artifact manifests retain responsibility for published
byte identity. Do not claim either old or new envelope is package authentication.

The new header is bounded and may be larger than the old 40-byte header for
some identity lengths. The architectural benefit is removing an unnecessary
hash implementation/dependency, not a promise of fewer header bytes.

Alternatives evaluated:

| Option | Decision |
| --- | --- |
| Keep SHA-1 or substitute HashLib/private SHA-1 | Reject: retains redundant machinery and does not correct bootstrap coupling |
| Trust zlib/structural checks alone while keeping sidecars | Reject: independent valid generations can both pass those checks |
| Use existing generation identity for sidecars, with versioned no-hash envelope | Selected: preserves package conventions and expresses the actual association requirement |
| Remove optional sidecars entirely | Simpler association model, but unnecessary for this correction; current compiler, nxbuild/Forge options and tests explicitly support the mode |

Reject old NXPM0001 envelopes with a clear rebuild-required diagnostic. Rebuild
the normal compiler, Forge codec consumer, SDK, providers and dependent bundles
together. Do not write the new layout under the old signature or retain a
SHA-1 compatibility decoder solely to preserve disposable development builds.
There is no verified external distribution requirement for mixed envelope
versions. Inner NXP004/NXU formats and native descriptor ABI need not change
solely because their storage envelope changes; verify that rather than adding
unrelated format revisions. Setup/torrent digests and publication SHA-256
algorithms/serialization remain unchanged.

HashLib source can still compile into Forge for its ordinary SHA-256 operations,
avoiding acquisition of a runtime package Forge is responsible for building.
That source is not staged into NexusFPC bootstrap or its metadata codec.
Application and Lab consumers continue to use upstream APIs directly; only
compiled-package tests count as runtime integration proof.

## Scope

- One External Packages import and its identity, `.nxpk`, Forge/configuration,
  source/test selection, review, hashes, README and direct nxtest tests.
- The three catalogs, central attribution, package documentation and explicit
  source discovery entries that change as a direct consequence.
- The single PasZLib runtime/test closure, namespace mapping, README and
  affected source-path records.
- Compiler bootstrap capability boundary, the pure shared format constants,
  post-bootstrap normal compiler and native/cross/tool/SDK/release wiring.
- Removal of codec SHA-1, NXPM0002 envelope and existing-identity sidecar
  association; FPCP and Forge reader/writer/test/documentation changes.
- Forge artifact/SDK SHA-256; Setup and Torrent hashing; demonstrated active
  fpGUI file-monitor use; useful Lab hashing examples.
- Narrow conversion of affected old build recipes to the current nxbuild FPC
  child form so these consumers can actually be verified. No build-engine
  redesign or broad project conversion.
- F `tests/bootstrap/NXBootstrapClosureTests.Forge.nxscript` using existing
  Forge operations, and direct nxtest closure/capability tests and updated
  `tests/dynamic-packages/package_metadata_test.pas` fixtures. These are planned
  files, not an additional build system or a HashLib-owned bootstrap harness.
- Focused metadata version/rebuild/identity fixtures, SDK hash-algorithm tests,
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
- HashLib, a private SHA-1, another general-purpose hashing package or a
  hash-provider abstraction in compiler bootstrap; preserving NXPM0001 via a
  historical SHA-1 decoder solely for compatibility.
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

### 3. Correct bootstrap and metadata dependencies, then build the normal compiler

1. Move the real constants to tpNXPackageFormat and update constant-only
   consumers, including test helpers that currently import them via the codec.
   Add the one bootstrap-role conditional at existing package entry/loader
   branches. Keep ordinary NXU compilation intact.
2. Remove the SHA-1 codec operations and implement the specified versioned
   envelope/build-identity comparison in existing codec/FPCP/Forge owners.
   Update embedded/sidecar tests and rebuild diagnostics; preserve ordinary
   SHA-1 consumers and publication SHA-256 semantics.
3. Exclude FPCP/package metadata processing and nxpackagefile.pas from initial
   bootstrap source closure/staging, together with metadata compression/hash
   staging and UnitPaths. Specifically exclude fpcp.pas, pcp.pas and
   nxpackagefile.pas from the bootstrap source fixture, then stage those sources
   and canonical PasZLib only for the normal compiler. No Hlp source is staged
   into either compiler role. Clean all variant unit directories.
4. Use the stock FPC 3.2.2 seed to build bootstrap-role seed/native/generation
   compilers and static RTL through Forge in an isolated checkout. Require
   codec, PasZLib and legacy/HashLib source and compiled units to be unavailable
   to these bootstrap steps. Verify cycle2/cycle3 compiler and RTL object
   equality with matching flags.
5. Build the normal compiler from verified cycle3 using the later source
   closure and matching RTL. Verify an isolated normal self-rebuild, ordinary
   compilation, package creation and consumption. Never compare bootstrap and
   normal binaries for equality or distribute the bootstrap binary.
6. Rebuild Forge against the revised no-SHA-1 codec before asking it to inspect
   the new SDK/package envelopes. Its existing SHA-256 implementation can remain
   temporarily until the ordinary HashLib migration below; that is not a
   compiler-bootstrap source dependency. Rewire Bootstrap output, cross compiler
   builds, release tools, SDK compiler copy and release/identity checks to the
   normal compiler. Drop Stage_hash;
   retain a narrow PasZLib path for bin2obj rather than broad unused paths.
7. Rebuild available SDKs/providers/consumers against the new envelope; validate
   source-free consumption, embedded and sidecar association, and old-format
   rejection. Keep unsupported host/tool prerequisites explicit.

Fix demonstrated boundary/compatibility problems within this sequence, without
falling back to a bootstrap SHA-1 import or retaining an unnecessary dependency
because the old recipe had it. No phase-specific owner approval is added.

### 4. Import and verify the HashLib provider

Import the pinned selection, preserve notices, save the source/integration
review, add identity/manifest/recipes/tests and catalog entries. Port useful
vectors directly to nxtest. Establish source known-answer coverage, then
build/publish the real runtime provider and source-free consumer on each
available matching **normal-compiler** SDK. HashLib's upstream FPC minimum
is not a reason to insert it into compiler bootstrap.

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

From Nexus on Linux, run the planned bootstrap closure/capability checks with
the configured native host prerequisites, then the package checks once a
matching normal-compiler SDK is available:

```sh
"$HASH_NXFORGE" /input="$HASH_FPC_ROOT/tests/bootstrap/NXBootstrapClosureTests.Forge.nxscript" /targets=TargetOS:linux,TargetCPU:x86_64
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

The bootstrap closure recipe selects stock
`/usr/lib/x86_64-linux-gnu/fpc/3.2.2/ppcx64` and that installation's matching RTL
for the seed, then the matching NexusFPC RTL for subsequent stages. It uses
`-n`, explicit unit paths and clean output directories. The bootstrap source
fixture excludes FPCP/PCP metadata processing, the codec, PasZLib and all legacy/HashLib source and
compiled-unit paths. Compile ordinary programs/units and the bootstrap compiler
itself in that closure; record loaded units and reject accidental package use.
Only the subsequent normal compiler/metadata fixtures receive the codec and
canonical PasZLib, still without any general-purpose hash package. The recipe
uses existing FPC/Run/Compare operations, not a new shell wrapper or framework.

For Windows, use the configured current Forge executable and an isolated
NexusFPC checkout in the documented layout:

```powershell
& $hashForge /input=NexusFPC.Forge.nxscript /targets=Build:Bootstrap
& $hashForge /input=NexusFPC.Forge.nxscript /targets=Build:Tools
& $hashForge /input=NexusFPC.Forge.nxscript /targets=Build:PackageSDK
& $hashForge /input=$hashBootstrapRecipe /targets=TargetOS:win64,TargetCPU:x86_64
& $hashForge /input=$hashPackageRecipe /targets=Build:Package,TargetOS:win64,TargetCPU:x86_64
& $hashForge /input=$hashPackageRecipe /targets=Build:Tests,TargetOS:win64,TargetCPU:x86_64
```

`$hashPackageRecipe` and `$hashBootstrapRecipe` are the absolute paths to the
new package and bootstrap test recipes above. Rebuild/select the Forge binary
with the revised codec before the SDK/publication steps; an old Forge reader
cannot validate NXPM0002. The Windows bootstrap recipe explicitly checks stock
`C:/fpc/3.2.2/bin/i386-win32/ppc386.exe` and its own units before the Win64
bootstrap-role generations, followed by the normal compiler. The checked-in
full Bootstrap target is not a Linux-native command; do not claim otherwise.
Native Linux whole-compiler
bootstrap requires a verified Forge host configuration. Select and validate
the available configuration during implementation. Missing configuration/SDK
construction is an explicit target limitation, not a reason to introduce make,
a Bash builder or an unrecorded ad hoc build.

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
| NXPM0002 | Embedded and sidecar roundtrips; bounded variable identity header; invalid mode/length/identity, truncated image/stream and incorrect zlib check rejected; old NXPM0001 explicitly rejected with rebuild advice; no SHA-1 field or legacy decoder |
| Metadata structure/association | Retain NXP checksum, CPU/target/SDK/name, embedded NXU bounds and exact dependency identities; reject equal-sized valid sidecar from another same-name/same-SDK generation and envelope-versus-decoded BuildIdentity mismatch; preserve image-descriptor and manifest checks |
| Stock seed/bootstrap | FPC 3.2.2 and isolated Forge seed/native/cycle compiler builds with FPCP/PCP metadata processing, codec, PasZLib, legacy hash and HashLib unavailable; actual loaded-unit/object closure proves absence, not merely omitted search flags; plain static programs/RTL still compile |
| Bootstrap capability | Reject `.nxpk` and RequiredPackages/`-FP` explicitly; no dynamic-package capability macro; ordinary NXU checks remain, including existing internal FPCHash checksums |
| Normal compiler | Verified bootstrap builds normal source with package capability and self-contained PasZLib, no SHA-1/HashLib codec dependency; normal self-rebuild, SDK nxrtl build and source-free package consumer succeed; only normal compiler is published or used for package SDK/cross/release work |
| Generation comparisons | Bootstrap cycle2/cycle3 compiler and RTL objects compare with identical role/settings; normal self-build comparison is separate; no minimal/full binary equality claim |
| Forge SDK/artifacts | SHA-256 algorithms, case and input ordering unchanged for fixed byte inputs; fresh metadata/compiler bytes correctly change artifact hashes and SDK identity; new GUID behavior retained; old-envelope/malformed/mismatched bundles fail without selecting a new generation |
| Setup | Preexisting `.nx/setup/<lowercase-sha1>` location found; byte encoding and non-ASCII product IDs; no automatic state migration or changed directory algorithm |
| Torrent | Fixed raw bencoded info slice, zero/high-byte payloads, 20-byte hashes, percent-encoded/wire consumers unchanged, cross-file pieces and corruption; test helper independent expected values |
| Coverage failures | Prove a failure before fixing; distinguish invalid test expectations from real bugs; record missing target/tool prerequisites explicitly; never weaken a format assertion to obtain a pass |

Focused searches after changes must show no `crc`/`System.Hash.Crc`, Hlp unit,
HashLib package or legacy hash search path in the PasZLib runtime/test closure.
Bootstrap closure must exclude FPCP/PCP metadata processing, NXPackageFile,
ZBase/ZCompres/ZInflate and every general-purpose hashing package, including
Hlp units. Internal FPCHash/NXU integrity code is not such a package and remains
where required for ordinary compilation. The later codec must have no SHA-1 or
HashLib import. Forge's ordinary SHA-256 consumer is classified separately. Other
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
3. **Actual bootstrap constraints are source coupling and output selection.**
   Constant-only clients import the codec; TPCPPackage branches sit inside the
   ordinary loader; SDK/tools/cross currently select cycle3. Correct these
   concrete sites and verify the two compiler roles. No inherent technical
   blocker requiring metadata or a hash provider in bootstrap was found.
4. **Source inspection is not execution proof.** Stock bootstrap exclusion,
   normal compiler capability, the format transition and ordinary HashLib
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
8. **Sidecar identity is not payload authentication.** New associations use the
   existing unique generation identity; zlib and structural checks validate
   accidental corruption. Published byte integrity remains the manifest's job.
   Tests must not claim those checks authenticate arbitrary replacement data.
9. **The envelope transition requires a coordinated rebuild.** An old normal
   compiler or Forge reader must not be mixed with new SDK/provider envelopes.
   Reject old storage versions; do not preserve a SHA-1 decoder simply to avoid
   rebuilding development artifacts. Ordinary Setup/torrent formats stay intact.

## Execution

This handoff creates, commits and pushes **only this work plan** for review.
No implementation starts during the planning handoff.

Once the owner approves the plan, complete its entire implementation and
verification scope in one pass, without intermediate approval gates. The
completion report includes the import, private PasZLib CRC, consumer migrations,
bootstrap/normal-compiler separation, metadata format/association correction,
test/build evidence and residual dependency inventory. Legacy packages remain
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
