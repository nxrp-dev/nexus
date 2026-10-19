# Nexus attributions

This is the canonical attribution and provenance record for the Nexus project family,
maintained in the root of the Nexus repository. It covers maintained forks, imported
libraries, external tools, sample assets, and historical influences across repositories.
Last reviewed: **2026-10-10**.

Nexus is directed and developed by **Kevin Collins**. Upstream authors retain credit
for their work. ChatGPT and Codex have assisted development and review under Kevin's
direction; that assistance does not replace his authorship or design responsibility.
The voluntary acknowledgement “Built with NexusUI by Kevin Collins” remains welcome.

## Reading and maintaining this record

- **Upstream** identifies the original project and, where known, the exact imported
  revision. An upstream revision's date is not the date Nexus forked it.
- **Fork/import date** distinguishes a documented import from the earliest surviving
  Nexus commit. “Unknown” means the exact event is not recorded; a baseline date is
  evidence of possession by that date, not a reconstructed fork date.
- **Our location** uses the repository keys below. Paths are relative to that
  repository, unless explicitly described as external installations or historical paths.
- **SPDX** uses the [SPDX License List](https://spdx.org/licenses/) short identifiers.
  `OR` records alternatives; `AND` records combined obligations; `WITH` records an
  exception. `LicenseRef-*` identifies custom terms defined in this document.
  `NOASSERTION` is an explicit unresolved value, **not a license or permission grant**.
  A mixed distribution is not assigned one license merely because its root has one.
- **Status** distinguishes maintained code, external dependencies, retained upstream
  material, and historical references. Retained material is not necessarily compiled
  or shipped on every platform.

Update this file when adopting, relocating, upgrading, or retiring third-party work.
Record author, upstream URL and revision, fork/import date with evidence, our repository
and path, upstream SPDX expression, and status. Keep retired entries with their last
location and retirement evidence. Link here from package documentation instead of
creating another attribution or upstream-provenance document.

Original license texts, copyright notices, upstream author lists, asset notices, and
source headers remain with their material. Distribution license payloads remain in
place too. This index does not replace those texts or change anyone's license.
Consumed package descriptors retain their machine-readable author/license metadata.
Installed package-manager dependencies retain their own notices and lockfiles; this
record is not a version-specific bill of materials for every installation.

## Repository locations

| Key | Our repository | Local checkout |
| --- | --- | --- |
| Nexus | [nxrp-dev/nexus](https://github.com/nxrp-dev/nexus) | `C:\gitdev\nexus` |
| Packages | [nxrp-dev/nexus-packages](https://github.com/nxrp-dev/nexus-packages) | `C:\gitdev\nexus\packages\nexus-packages` |
| External | [nxrp-dev/nexus-packages-ext](https://github.com/nxrp-dev/nexus-packages-ext) | `C:\gitdev\nexus\packages\nexus-packages-ext` |
| Apple | [nxrp-dev/nexus-packages-apple](https://github.com/nxrp-dev/nexus-packages-apple) | `packages/nexus-packages-apple` under the Nexus checkout |
| FPC | [nxrp-dev/nexus-fpc](https://github.com/nxrp-dev/nexus-fpc) | `C:\gitdev\tools\nexus-fpc` |
| Pascal | [nxrp-dev/nexus-pascal](https://github.com/nxrp-dev/nexus-pascal) | `C:\gitdev\tools\nexus-pascal` |
| Engine | [nxrp-dev/nexus-mobile](https://github.com/nxrp-dev/nexus-mobile) | `C:\gitdev\Nexus2D` |
| Lab | [nxrp-dev/nexus-lab](https://github.com/nxrp-dev/nexus-lab) | sibling `nexus-lab` checkout |

The Engine and Lab repository names above are their verified current Git remotes;
their checkout names differ. This record does not rename them. Temporary compiler
validation checkouts and generated outputs inherit the provenance of their source
repository rather than constituting additional forks.

## Compiler, editor, and development foundations

### Boost.Multiprecision reference arithmetic

- **Credit:** Boost.Multiprecision and Boost.Config authors and contributors,
  including John Maddock and Christopher Kormanyos; retained upstream notices
  identify individual contributions.
- **Upstream:** [Boost.Multiprecision](https://github.com/boostorg/multiprecision),
  revision `b484d2f158df88e04470e7da4bcc59bf63f65688`, and
  [Boost.Config](https://github.com/boostorg/config), revision
  `2bd6f0dfc52ff1fb1bd502361f4d0c750ce51d93` (Boost 1.86.0).
- **Fork/import date:** not forked or vendored. The 2026-10-11 numeric correction
  pass used these sources to generate the retained independent reference corpus.
- **Our location/status:** FPC `tests/compiler-real/reference.cpp` and
  `reference-vectors.txt`; optional test-generation dependency. The corpus remains
  a native-math comparison after retirement of the compiler's software evaluator.
- **SPDX:** `BSL-1.0` for the upstream libraries.
- **Evidence/notices:** generator source and the preceding numeric-repair test
  record; downloaded upstream sources and licenses stay in ignored validation
  output, not the distributed compiler.

### innoextract bootstrap extraction tool

- **Credit:** Daniel Scharrer and innoextract contributors.
- **Upstream:** [innoextract](https://constexpr.org/innoextract/), version 1.9.
- **Fork/import date:** not forked. Downloaded on 2026-10-11 to extract the stock
  FPC 3.2.2 Win32 bootstrap without running its installer.
- **Our location/status:** FPC `output/native-real/bootstrap-input/innoextract`;
  temporary validation tool, not a source/build dependency or shipped component.
- **SPDX:** `Zlib`; preserve the binary archive's accompanying third-party notices.
- **Evidence/notices:** the extracted `license` directory and `README.txt`.

### Free Pascal and NexusFPC

- **Credit:** Free Pascal development team and the contributors named in the retained
  compiler, RTL, package headers, and documentation.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  [project](https://www.freepascal.org/).
- **Fork/import date:** unknown. The locally available shallow history includes
  Nexus work on **2026-09-17**, `2a3622f8`; it cannot establish the original fork date.
- **Our location/status:** FPC repository; maintained compiler, runtime, and packages.
  FCL Base moved on 2026-10-18 to Nexus
  `packages/nexus-packages/fcl-base`; its dedicated provenance record is below.
  The inherited core make build recipes and `fpcmake`/`fpgmake` generators were
  retired on 2026-10-11 in favor of NexusForge. Package/test recipes remain pending
  their separate migration; this record retains credit for the retired components.
  The unused `rmwait` file-deletion utility by Tomas Hajny (2009-2011) was also
  retired on 2026-10-11 after confirming it had no remaining build consumers.
  The `fpcmkcfg` configuration generator by Michael Van Canneyt (2005), its
  templates and the `samplecfg` wrapper were retired the same day; the release
  now ships a fixed, compiler-relative configuration directly.
- **Hash provider retirement (2026-10-17):** the MD2/4/5, SHA-1, SHA-2,
  HMAC, CRC and FNV implementations in FPC `packages/hash` and `packages/fcl-hash`,
  their assembly includes and obsolete runners/benchmarks were removed after
  migrating ordinary consumers and retained crypto services to HashLib4Pascal.
  The source baseline is FPC `9dec5243bef0552d346f22005e3ac3e06ad8185e`;
  original authors/notices remain in that Git history. Later on 2026-10-17,
  the owner directed removal of the remaining RSA, ECC/ECDSA, ASN.1, PEM, OTP,
  UUID, NTLM, system crypt and supporting services, their namespace wrappers,
  dedicated tests and four dependent Lab demonstrations. Both package directories
  are retired in full; their final source/notices remain in NexusFPC Git history
  at `a9eb6b312de147d38502c12bca34c493ac2908be`. The removed Lab demonstrations
  were `authenticator`, `gentotp`, `dumppem` and `extractrsa`. No production
  consumer was found in the maintained repositories. Useful RFC/CRC vectors
  continue to run directly in Packages
  `hashlib4pascal/tests`; its FPC-derived HMAC tests retain `COPYING.FPC` and
  `COPYING.txt` beside them. The RTL's shared CRC32 remains independent.
- **FGL retirement (2026-10-18):** `rtl/objpas/fgl.pas`, credited to Micha
  Nelissen (2006) and the Free Pascal development team, and its `System.FGL`
  wrapper were retired after migrating the application consumers and RTTI cache
  to `Generics.Collections`. The experimental FGL-based `Classes` branch and
  dedicated obsolete fixtures were removed; useful compiler regressions now use
  Collections. The original source, headers and notices remain in NexusFPC Git
  at `867b50d8d09a92ac6999d9fa16f9bd7c5072ee52`. The upstream and unknown fork
  date are recorded above; the RTL SPDX expression and linking exception below
  apply. Contnrs remains maintained.
- **Standalone AVL retirement (2026-10-18):** FCL
  `packages/fcl-base/src/avl_tree.pas`, credited to Mattias Gaertner (2008),
  and its `Fcl.AVLTree` wrapper were retired after converting fpGUI listview
  selection and both translation tools to `Generics.Collections`. The original
  source, headers and license notices remain in NexusFPC Git at
  `8976685dafd97146ea8a14a576e161cfabc173ca`. The Lab AVL demonstration by
  Marco van de Voort (2009) now uses the shared generic AVL map and preserves
  its original FPC/BSD license notice. Upstream and the unknown original fork
  date are recorded above; the FCL license expression below applies to the
  retired implementation. Contnrs remains maintained.
- **Users package restoration:** bindings by Michael van Canneyt and Marco van
  de Voort, as credited by the original package metadata, restored on
  **2026-10-15** at FPC `packages/users` from revision
  `b33f3bce53e299f319980d56adb40aae82ce36c4`, preceding their deletion in
  `f40338cf8a`. Runtime and example source bytes are retained with `.pas`
  filenames; namespace references follow the renamed files. Historical package
  metadata identifies LGPL with modification; `packages/COPYING.FPC` retains
  the independent-module linking exception. The restored units supply fpGUI's
  Linux file-owner and group-name lookup; retired Make/fpmake files stay retired.
- **Resource metadata restoration/migration:** `FileInfo`, credited to the Free
  Pascal development team (2013), was restored unchanged on **2026-10-16** from
  NexusFPC `b33f3bce53e299f319980d56adb40aae82ce36c4:packages/fcl-extra/src/fileinfo.pp`
  to `packages/fcl-res/src/fileinfo.pas`; SHA-256
  `2622f48109d66b99df6f3852247ab3039c518ae14d6c42bc0d243a899c151715`.
  The existing `Fcl.FileInfo` wrapper moved from `fcl-base` to `fcl-res`.
  It retains its FCL header and `COPYING.FPC` license/independent-module exception
  and supplies Setup's executable-version reader. The original upstream is the
  Free Pascal source linked above; the original fork date remains unknown.
  The same migration retired `utils/fpcres`, `utils/fpcreslipo`, the Pascal RC
  parser/preprocessor, native resource writers and external-sidecar loader.
  Their authors remain credited by the historical source at NexusFPC
  `ca6b3976bf5417fd73251dcb9f39d9edcf48ea07`; the retained reader/model units,
  including Giulio Bernardi's resource base classes (2008), preserve their
  original headers and notices. New Setup version fixtures are generated from
  the checked-in `projects/setup/test/fixtures/version-{1,2}.rc` scripts with
  LLVM RC; they contain only the test version records.
- **TP Lex/Yacc retirement:** the generators, grammar/template sources and
  `tplylib` support units were retired on **2026-10-16** after removal of their
  last production consumer, the resource-script parser. Credit remains with
  Albert Graef (original TP Lex/Yacc), Berend de Boer (Turbo/Borland Pascal
  adaptations) and Michael Van Canneyt (Free Pascal port), as stated in
  NexusFPC `814f931dab:utils/tply/README.txt`. That historical README identifies
  upstream as <http://www.musikwissenschaft.uni-mainz.de/~ag/tply> and declares
  version 4.0 and later `GPL-2.0-or-later`; `utils/tply/COPYING.txt` and the
  original source notices remain in Git at that revision. The original fork
  date is unknown. Our former locations were NexusFPC `utils/tply` and
  `packages/tplylib`; Forge no longer builds or distributes them.
- **Unused utility retirement:** `utils/ppdep.pas`, `utils/postw32.pas`,
  `utils/data2inc.pas` and `utils/data2inc.exm` were retired on **2026-10-16**
  after confirming no retained production invocation. Peter Vreman is credited
  by `ppdep` (1999-2000); `data2inc` credits Peter Vreman's `msg2inc` and Marco
  van de Voort's adaptation (1999-2000). Their headers reference LGPL and/or
  `COPYING.FPC`; those original notices and the independent-module exception
  remain in historical NexusFPC `814f931dab` and the retained license files.
  `postw32` credits Pavel Ozerski (1998-2000), under `GPL-2.0-or-later`.
  The source upstream is Free Pascal, linked above; the original import dates
  are unknown. `bin2obj`, `rstconv` and `creumap` remain retained utilities.
- **SPDX:** compiler `GPL-2.0-or-later`; RTL's LGPL 2.1 text and linking permission are
  recorded as `LGPL-2.1-only WITH Independent-modules-exception`, with any broader
  version grants in individual headers preserved. Packages have individual licenses;
  no blanket compiler license is applied to them.
- **Linux library linking correction (2026-10-17):** the maintained compiler now
  preserves explicit versioned shared-library filenames and exact lookup through
  the Linux link path. The X11 bindings (subsequently relocated to Nexus
  `packages/nexus-packages/graphics/x11`) share ABI
  names in the new Nexus-authored `tpX11Libraries` unit, which carries its own
  `MPL-2.0-no-copyleft-exception` notice. Existing binding headers and notices are
  preserved. The source baseline is FPC `6bca029dba0aebb0389c514d1574af4923af06f4`;
  direct nxtest regressions are retained in FPC `tests/linker`.
- **Evidence/notices:** `compiler/COPYING.txt`, `rtl/COPYING.txt`, `rtl/COPYING.FPC`,
  `packages/COPYING.FPC`, individual source headers. SPDX explicitly identifies the
  [Independent Module Linking exception](https://spdx.org/licenses/Independent-modules-exception.html)
  with FPC's `COPYING.FPC`; do not invent an `FPC-exception` identifier.


### X11

- **Credit:** the Free Pascal contributors and header translators, including
  Ido Kanner (XKB) and Felipe Monteiro de Carvalho (Xft extensions); The Open
  Group, Digital Equipment Corporation, Hewlett-Packard/Compaq, Silicon
  Graphics, XFree86, Keith Packard, Red Hat, Oracle and the other authors named
  in the preserved per-file notices. fpGUI's original authors are retained in
  the accompanying `AUTHORS.txt`; Kevin Collins owns the Nexus library-name
  definitions, build integration and direct tests.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  derived X.Org/XFree86 client headers and the fpGUI Xft translation credited in
  `src/xft.pas`. The original fork/import date is unknown.
- **Relocation date/evidence:** 2026-10-17, all 125 original files inventoried
  from NexusFPC `0f60ce9c1bfd30e56fd6d5246a8ed46077f9990a`, Git tree
  `7ae8f892b6a34bb10abb3067ddb5296ca483c8bd`. Destination
  `graphics/x11/review/baseline-hashes.json` records each original SHA-256.
- **Our location/status:** maintained Packages `graphics/x11`, comprising all
  45 runtime units and 16 includes, namespace wrappers/maps, saved code review and
  Nexus package/build/test integration. The compiler-side directory is removed.
  The 17 link-only programs were converted into 227 direct nxtest symbol
  checks. The keyboard-map printer moved to Lab `examples/gui/x11/KeyboardMap.pas`.
  Proven C ABI, library import and XKB/helper corrections are recorded in the
  destination `CODE_REVIEW.md`; no duplicate provider/evidence archive is kept.
- **SPDX/notices:** imported C bindings retain their individual MIT/X11-family
  notices; the fpGUI-derived Xft material retains
  `LGPL-2.1-only WITH Independent-modules-exception` and its author record.
  `COPYING.FPC`, `COPYING.modifiedLGPL` and `COPYING.LGPL.txt` preserve the
  accompanying linking permission and license texts. Nexus-authored library
  definitions/integration/tests carry `MPL-2.0-no-copyleft-exception`.
  No single blanket license is asserted for the imported tree.
- **Verification tools:** native Ubuntu Xvfb and X11/Fontconfig development
  packages were downloaded/extracted only under ignored `output/x11-review`;
  they are not imported package source or a distributed build dependency.

### RTL Unicode

- **Credit/upstream:** Inoussa Ouedraogo (collations), Nikolay Nikolov (grapheme
  and width units), the Free Pascal team and LazUtils contributors, as credited
  in the retained headers and package metadata. Source upstream is the
  [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source); UTF8Utils
  identifies its origin as LazUtils. Original fork/import date unknown.
- **Restoration evidence:** recovered on **2026-10-17** from NexusFPC
  `ab6ea7e3d03556520972fbd480b37c6611e1b7fa:packages/rtl-unicode`, preceding
  deletion in `334e806fea1b1ee4cd89d6ccf4ac8a74e19cb83c`. That immutable Git tree
  is the untouched snapshot; `packages/nexus-packages/rtl-unicode/UPSTREAM.sha256`
  records all original paths/hashes. The historical package contained 59 files
  and 443,483 lines, predominantly generated tables. Retired Make/fpmake files
  and unused namespace wrappers remain historical. Runtime `.pp` files are now
  `.pas`; there is one maintained source tree.
- **Our location/status:** active at `packages/nexus-packages/rtl-unicode` with
  Nexus package metadata, build recipe and direct nxtest regressions. Corrections
  make UTF-8 bytes independent of default Char width, preserve caller code-page
  policy and update grapheme segmentation. The collation inheritance fix stays
  in its owning NexusFPC RTL unit, `rtl/objpas/unicodedata.pas`. Bootstrap and its
  build sequence are unchanged. The original NFD runner is converted to direct
  nxtest coverage of the complete matching fixture; no duplicate runner is kept.
- **Licensing/notices:** original per-file notices remain intact. `COPYING.txt`
  and `COPYING.FPC` preserve FPC's LGPL text and independent-module exception
  (`LGPL-2.1-only WITH Independent-modules-exception`, with broader per-file
  grants preserved). LazUtils' [modified LGPL notice](https://gitlab.com/freepascal.org/lazarus/lazarus/-/raw/main/COPYING.modifiedLGPL.txt)
  and [LGPL 2.0 text](https://gitlab.com/freepascal.org/lazarus/lazarus/-/raw/main/COPYING.LGPL.txt)
  are retained separately. Their SHA-256 values are respectively
  `0624a5291021279446fbea96cdd33527d09c64c87d5616f789b2521e2a9e3d71` and
  `7a4436f9ec37603356791c87de3bc444989befd2682d29efb3d97604e04c1852`.
  Generated tables retain Inoussa's original permissive data notices. New Nexus
  code uses `MPL-2.0-no-copyleft-exception`; no blanket license replaces these
  individual headers.
- **Unicode 17 inputs:** Unicode, Inc., `Unicode-3.0`. Original headers and
  license remain inside `tests/data/Unicode17.zip`. Official sources fetched
  **2026-10-17**: [GraphemeBreakTest.txt](https://www.unicode.org/Public/17.0.0/ucd/auxiliary/GraphemeBreakTest.txt),
  [NormalizationTest.txt](https://www.unicode.org/Public/17.0.0/ucd/NormalizationTest.txt),
  [emoji-data.txt](https://www.unicode.org/Public/17.0.0/ucd/emoji/emoji-data.txt)
  and [DerivedCoreProperties.txt](https://www.unicode.org/Public/17.0.0/ucd/DerivedCoreProperties.txt).
  Their SHA-256 values in that order are
  `e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec`,
  `5019ffd530751a741900c849c0e010332f142a3612234639bd200b82138a87db`,
  `2cb2bb9455cda83e8481541ecf5b6dfda66a3bb89efa3fa7c5297eccf607b72b`,
  `24c7fed1195c482faaefd5c1e7eb821c5ee1fb6de07ecdbaa64b56a99da22c08`.
  The bundled [Unicode License V3](https://www.unicode.org/license.txt) has SHA-256
  `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96`.
  `tools/generate-grapheme-context.py` regenerates the additional runtime
  property include from those pinned ZIP members without network access.
  Collation fixtures remain in their single FPC test archive, recorded below.
- **Little-endian platform retirement (2026-10-18):** retained little-endian
  collation blobs are byte-identical to the restored import. Removed seven
  unused native big-endian blobs and their host selectors. Their original
  hashes remain in `UPSTREAM.sha256` and the immutable restoration tree above.
  The old `utils/unicode` collation generators were already retired in
  `334e806fea`; no active collation regeneration pipeline is restored here.
  Future imports must follow the documented little-endian-only contract.

### Unicode collation conformance data

- **Credit:** Unicode, Inc.; original 2025 copyright, trademark and terms-of-use
  headers remain inside both dataset members.
- **Upstream:** Unicode CLDR [root collation data](https://www.unicode.org/reports/tr35/tr35-collation.html#Root_Data_Files).
  NexusFPC commit `e48ce1c6aa60ce12ebab4761867f82e64494ac90`, **2026-05-16**,
  records the update from CLDR 48.2. The retained file headers identify UCA/UCD
  **17.0.0** and **2025-08-04**. The original Nexus fork/import date is unknown.
- **Our location/status:** FPC `tests/test/units/fpwidestring/CollationTests.zip`;
  the two former loose `.txt` fixtures were compressed without byte changes on
  **2026-10-17** by owner direction. The tests extract directly into owned memory
  streams and write no expanded files. The archive is retained test input, not
  a source/evidence checkpoint. The restored `rtl-unicode` package supplies
  `unicodeducet`; all three collation programs pass against matching ANSI and
  Unicode RTLs. The independent extraction/cleanup suite also passes.
- **SPDX:** `Unicode-3.0`, as identified by the upstream
  [Unicode License V3](https://www.unicode.org/license.txt). Original file notices
  remain intact; Nexus-authored loader/tests use their own source notices.
- **Original byte hashes:** `CollationTest_NON_IGNORABLE_SHORT.txt`, 2,245,489 bytes,
  SHA-256 `7063c05ad292803f8d4269abc64e2ce50ab96d0038f799670ed325f9a5e20bb8`;
  `CollationTest_SHIFTED_SHORT.txt`, 2,482,352 bytes,
  SHA-256 `51a2f9d9d0ed4a54bb123c72df7211e9f3b83ca15249ad350cd8780f8ccbf7c5`.
  Both extracted archive members match those original bytes exactly.

### Apple platform packages

- **Credit:** Apple Inc. for the original framework interfaces; Free Pascal
  and GNU Pascal interface contributors identified by the preserved headers.
  `iosxlocale.pas` credits Yury Sidorov (2013), and `iosxwstr.pas` credits
  Jonas Maebe (2015). Preserve the original references to contributed
  routines and Apple interface copyright notices.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/univint`, `packages/cocoaint` and `packages/iosxlocale`.
  Exact original fork/import date and upstream revision are unknown. The
  relocation input is the maintained NexusFPC tree at
  `b7bb9f717c6baf94eee76c8c051635184112680e`; it is not asserted to be an
  unmodified upstream release.
- **Fork/import evidence:** relocated unchanged on **2026-10-16** to the new
  Apple repository. Per-package untouched archives and SHA-256 manifests preserve
  all 2,645 original files: 909 universal-interface files, 1,731 Cocoa files and
  five locale files. Previous Apple binding maintenance remains recorded in
  FPC `nexusfpc-apple-bindings-cleanup.md` and its Git history.
- **Our location/status:** Apple `univint`, `cocoaint` and `iosxlocale`;
  maintained Apple-only packages, with nxpackage descriptors, nxbuild recipes
  and explicit repository/machine catalog entries. The former FPC package
  directories are historical. These packages do not live in the standard
  Packages repository. The owner explicitly waived code review for this move.
- **SPDX:** `iosxlocale`'s FPC source uses
  `LGPL-2.1-only WITH Independent-modules-exception`. For the mixed Apple
  interface material in `univint` and `cocoaint`, package-wide identification
  is `NOASSERTION`; the retained Apple notices do not establish one uniform
  package-wide grant. FPC distribution notices are preserved without replacing
  those original per-file notices.
- **Evidence/notices:** Apple package `migration/original-source.tar.gz`,
  `original-hashes.json` and archive hashes; source headers and namespace maps;
  FPC `packages/COPYING.FPC` and `rtl/COPYING.txt`, copied beside each package.
  Apple [MIGRATION.md](packages/nexus-packages-apple/MIGRATION.md) records
  byte-preservation checks, descriptor/plan validation and unavailable Apple
  build/runtime verification. Metadata and registered unit roots were recovered
  from the retired recipes at FPC
  `781faeb495d6aeb9d98facf441b826958af2d378`.

### Retired FPCUnit and retained-test conversion

- **Credit:** Dean Zobec and Michael van Canneyt (FPCUnit core), Vincent
  Snijders (console runner), Graeme Geldenhuys (reporters/fpGUI integration),
  and the contributors credited in each preserved test and helper header.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-fpcunit` and the package/RTL/compiler test directories; fpGUI
  integration remains credited by the fpGUI record below. Exact original import
  date and upstream revision are unknown. The last local FPCUnit source change
  is NexusFPC `6c5bd2eef00b97fe12e5b1e87310ec60313b8c52` (2026-10-14).
- **Our location/status:** FPC `packages/fcl-fpcunit` and its framework-specific
  runners retired on **2026-10-16**. Useful retained tests in FPC and Packages
  now use nxtest directly, without a bridge. JSON's `jsonfpcunit` helper and
  fpGUI's FPCUnit GUI/Lazarus runner integration are also historical.
- **Preservation/evidence:** Nexus `docs/migrations/fpcunit` contains
  archives of original source, per-file SHA-256 manifests, original source notices
  and the [conversion report](docs/migrations/fpcunit/README.md).
  After the owner-directed Maximus removal, the first archive preserves 604
  files and the second preserves 95 retired support files, including ancillary
  templates and runner assets. Maximus entries were removed from both archives
  and manifests; all remaining source bytes match their original hashes.
  Maintained converted tests keep their original notices. The archive preserves material from the
  local fork, not an asserted unmodified upstream release.
- **SPDX:** mixed, per original file. FPC package material referencing
  `COPYING.FPC`: `LGPL-2.1-only WITH Independent-modules-exception`;
  console/simple runners explicitly state `LGPL-2.0-or-later`;
  `xmlreporter.pas` explicitly states `GPL-2.0-or-later`. Preserve those narrower
  notices rather than assigning the entire archive one package license. fpGUI
  and individual retained tests retain the licensing recorded by their own
  source headers and existing records in this document.

### FCL JSON

- **Credit:** Michael van Canneyt and other Free Pascal development team
  contributors named in the retained source headers. The original package
  metadata names Michael van Canneyt as author.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-json`. The last upstream source change before the surviving Nexus
  baseline is `416b51be8722c3ca3b3cc307e0df1afe64a1d5cd` (2026-08-19);
  this is a lineage reference, not a claim that the Nexus source is unmodified.
- **Fork/import date:** original FPC fork date unknown. Relocated from FPC
  `packages/fcl-json` on **2026-10-15**, using the complete tree at NexusFPC
  revision `b7361861c09b1bcc0d3ca293639539fda644c594`. All 54 existing files
  were preserved byte for byte during relocation.
- **Our location/status:** Packages `serialization/fcl-json`; maintained package
  with an nxbuild static-unit recipe. Source, namespace wrappers, examples,
  upstream tests and the pre-existing review are retained. The former FPC
  `packages/fcl-json` location is historical; compiler release tools now stage
  source from the Packages checkout. The former `jsonfpcunit` helper was retired on 2026-10-16; its original
  source remains in the archived test snapshot.
- **Local maintenance:** nxtest regressions subsequently reproduced and
  corrected all eleven saved JSON review findings on Linux. A follow-up removed
  nine invalid retained tests, added executable regression coverage and fixed
  two further array-cleanup generator defects. Original source headers and
  license texts remain with the modified material.
- **SPDX:** `LGPL-2.1-only WITH Independent-modules-exception`; original package
  metadata says “LGPL with modification”.
- **Evidence/notices:** retained headers, `COPYING.FPC` copied from FPC
  `packages/COPYING.FPC`, and `COPYING.txt` copied from FPC `rtl/COPYING.txt`.
  Author/license metadata is recoverable in FPC revision
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-json/fpmake.pp`;
  those retired build files are not restored.

### FCL XML

- **Credit:** Sebastian Guenther, Sergei Gorelkin and the Free Pascal development
  team, with individual authors named in the retained headers. The reader tests
  also retain their Mono/Jason Diamond/Martin Willemoes Hansen attribution;
  `tests/extras2.pas` retains its W3C copyright notice.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-xml`. The most recent upstream source change visible before the
  Nexus edits is `3095698a96498400a0eedffc26f10ab23007f65e` (2026-08-01).
  This is lineage evidence, not a claim that the imported tree is unmodified.
- **Fork/import date:** original FPC fork date unknown. Relocated on
  **2026-10-16** from NexusFPC revision
  `ab22ed40f859707684f48e2a91359fe61e3ebeb9`. All 71 original files were
  copied byte for byte before applying local corrections; the original tree
  and SHA-256 inventory remain in Nexus `output/fcl-xml-tests/baseline` and
  `baseline-hashes.json`.
- **Our location/status:** Packages `serialization/fcl-xml`; maintained package
  with an nxpackage descriptor, nxbuild runtime-unit recipe, saved code review
  and nxtest regressions. The former NexusFPC `packages/fcl-xml` location is
  historical. The source includes namespace wrappers, examples and useful
  retained tests. Unsupported streaming operations and XPath namespace-axis
  evaluation now raise explicit errors instead of silently discarding data or
  returning a false empty result.
- **SPDX:** `LGPL-2.1-only WITH Independent-modules-exception`; the original
  package metadata says “LGPL with modification”. Individual copyright notices
  and consumed author/license metadata are preserved with their material.
- **Evidence/notices:** source headers; `COPYING.FPC` from NexusFPC
  `packages/COPYING.FPC`; `COPYING.txt` from NexusFPC `rtl/COPYING.txt`.
  Original package authorship/license/dependency metadata is recoverable at
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-xml/fpmake.pp`.
  Retired make/fpmake machinery is not restored.

### FCL DB

- **Credit:** Michael Van Canneyt, Joost van der Sluis and the Free Pascal
  development team; Pascal Ganaye, Micha Nelissen and TDbf contributors for DBF;
  Reinier Olislagers for XML/XSD export. Original per-file credits remain intact.
  The DBF expression parser also credits Egbert van Nes, John Bultena, Ralf
  Junker, Renate Schaaf, Alin Flaider and Stefan Hoffmeister.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-db`. Last visible upstream package change before Nexus edits:
  `d7b753592eb2c1548e1d0e9b67f55c7052a08b7e` (2026-07-27, SQLDB delegation).
  This is lineage evidence, not a claim of an unmodified upstream tree.
- **Fork/import date:** original FPC fork date unknown. Relocated on
  **2026-10-16** from NexusFPC `ca6b3976bf5417fd73251dcb9f39d9edcf48ea07`.
  All 199 original files were copied and hash-verified before corrections.
  The package's `review/baseline-source.tar.gz` and `baseline-hashes.json`
  preserve the untouched tree; working evidence is in `output/fcl-db-tests`.
- **Our location/status:** Packages `db/fcl-db`; maintained nxpackage descriptor,
  66-unit runtime recipe, console retained-suite recipe, nxtest regressions and
  saved code review. The former NexusFPC path is historical and has been removed.
  Source, includes, namespace wrappers, original programs, translations, notices
  and useful tests are retained. Two obsolete IDE registration units and six
  alternative translations with duplicate ordinary unit names are historical
  material and are excluded from the runtime recipe. External SQLDB drivers
  had already been removed before this relocation and are not restored.
- **SPDX:** runtime units use `LGPL-2.1-only WITH Independent-modules-exception`
  under the FPC package notice (old metadata: “LGPL with modification”).
  `fpxmlxsdexport.pas` additionally offers Reinier Olislagers' MIT notice as an
  alternative to FPC/FCL licensing; that exact notice remains with the file.
  The retained historical `dbf_reg.pas` notice names LGPL without specifying a
  version and includes authorship conditions; no more precise SPDX expression
  is inferred for that historical notice. New Nexus infrastructure/tests use
  `MPL-2.0-no-copyleft-exception`.
- **Additional lineage:** TDbf's retained header points to
  [tdbf.sf.net](http://tdbf.sf.net/). The expression parser header records
  `http://www.slm.wau.nl/wkao/parseexpr.html` and
  `http://www.datalog.ro/delphi/parser.html`; exact original revisions and
  earlier import dates are unknown. Those URLs are historical header metadata.
- **Evidence/notices:** all original headers; `COPYING.FPC` copied from
  NexusFPC `packages/COPYING.FPC` and `COPYING.txt` from `rtl/COPYING.txt`.
  Original package metadata remains recoverable at
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-db/fpmake.pp`.
  Retired make/fpmake machinery and Lazarus dependencies are not restored.

### PasJPEG

- **Credit:** Jacques Nomssi Nzali (Pascal translation, 1996/1998/1999),
  Thomas G. Lane and the Independent JPEG Group (original codec), and Free
  Pascal contributors. Individual source headers and the original README
  author lists remain with the material.
- **Upstream:** PasJPEG 1.1, 1999-05-29, originally published at
  `http://www.tu-chemnitz.de/~nomssi/pasjpeg.html`, based on IJG release 6b
  (1998-03-27). Imported through Free Pascal `packages/pasjpeg`; relocation
  snapshot is NexusFPC `bfd5d2156b01f1213b3fa16e3b3fde38588c9d5d`.
- **Fork/import date:** original Nexus fork/import date unknown. Surviving FPC
  history includes `b90270401ac81be77c30d580e1bae78ab742191d` (2008-01-24);
  that is upstream possession evidence, not the Nexus import date. Relocated
  on **2026-10-17** under the owner's direct instruction.
- **Our location/status:** Packages `graphics/pasjpeg`, maintained source
  package `NXRP.Graphics.PasJPEG`; former FPC `packages/pasjpeg` removed.
  Canonical examples remain Lab `examples/graphics/jpeg`; no duplicate
  example tree was introduced. FCL Image and fpGUI consume the relocated source.
- **SPDX:** `IJG AND Zlib` for the inherited codec/translation. New Nexus bitmap
  definitions, tests and build infrastructure carry
  `MPL-2.0-no-copyleft-exception`. The compiler distribution's `COPYING.FPC`
  is preserved without relabeling the inherited codec as wholly LGPL.
  Lab colormap helpers retain their separate Jef Poskanzer/PBMPLUS notices.
- **Evidence/notices:** all 119 original files are identified by the package's
  `review/baseline-hashes.json`; an untouched local snapshot stays in ignored
  Nexus output. `readme.txt` retains the Pascal port's Zlib-style legal text.
  `README.IJG` is the unmodified original release 6b README from
  [IJG's original archive](https://www.ijg.org/files/jpegsrc.v6b.tar.gz), archive
  SHA-256 `75c3ec241e9996504fe02a9ed4d12f16b74ade713972f3db9e65ce95cd27e35d`,
  README SHA-256 `4cf9c190f184019b61c36bcc49d4a24ffeb2a838c6f1690d6c4db14cfb2d0478`.
  The saved `CODE_REVIEW.md` records compilation repairs, nil-callback and
  bitmap-offset regression proofs, fixes, native verification and limits.
  The modified convenience unit is plainly marked. Historical platform
  alternatives and the unused unfinished IDCT prototype remain source-only.

### FCL Image

- **Credit:** Michael Van Canneyt and the Free Pascal development team; source
  headers also credit Mazen Neifer, Laurent Jacques, Mattias Gaertner, Giulio
  Bernardi, Massimo Magnano, Felipe Monteiro de Carvalho and other contributors.
  QR generation retains Project Nayuki's MIT notice and Michael Van Canneyt's
  Pascal translation notice. XWD headers retain The Open Group's X11 notice,
  Tony Della Fera and William F. Wyatt credits.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-image`. Last visible upstream package source change before Nexus
  edits: `d1e2ce13231ff2a86c386a034fd6a3c40298410f` (2026-09-04, gamma reading).
  This records lineage and does not claim an unmodified upstream import.
  The QR lineage points to [Project Nayuki](https://www.nayuki.io/page/qr-code-generator-library).
- **Fork/import date:** original FPC fork date unknown. Relocated **2026-10-16**
  from NexusFPC `ca6b3976bf5417fd73251dcb9f39d9edcf48ea07`. All 148 original
  files were copied and hash-verified before corrections. The destination's
  `review/baseline-source.tar.gz` and `review/baseline-hashes.json` preserve the
  complete original package; working evidence is in Nexus `output/fcl-image-tests`.
- **Our location/status:** Packages `graphics/fcl-image`; maintained nxpackage
  with runtime/test recipes, preserved examples, wrappers, assets and barcode
  tests, a saved review and nxtest proofs. The former NexusFPC package path is
  historical after relocation. Local corrections are recorded in the review.
- **SPDX:** principally `LGPL-2.1-only WITH Independent-modules-exception`
  (original package metadata: “LGPL with modification”). JPEG and PCX reader/
  writer headers explicitly specify `LGPL-2.0-or-later`; those notices remain.
  Consumed QR generator metadata specifies `MIT`; XWD headers specify `X11`.
  New Nexus infrastructure/tests use `MPL-2.0-no-copyleft-exception`.
- **Font asset:** unchanged `examples/DejaVuLGCSans.ttf`, DejaVu LGC Sans 2.5,
  contains Bitstream Inc. copyright (2003), the Bitstream Vera permission notice
  (`Bitstream-Vera`) and the statement that DejaVu changes are public domain.
  The embedded name-table license is also preserved as
  `examples/DejaVuLGCSans.LICENSE.txt`. Upstream:
  [DejaVu fonts](https://dejavu-fonts.github.io/); original asset import visible
  in FPC history: `f737521590a0c3f1edfc3f0d1a566f6c5e14953d` (2019-02-16,
  Ondrej Pokorny's alpha-blending example, committed by Michael Van Canneyt).
  Exact earlier font revision/import date is unknown; embedded version and
  SHA-256 inventory identify the retained asset without guessing.
- **Evidence/notices:** unchanged source headers and consumed metadata;
  `COPYING.FPC` from NexusFPC `packages/COPYING.FPC`, `COPYING.txt` from
  `rtl/COPYING.txt`; font's original embedded license and its text extraction.
  Historical package metadata is available at
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-image/fpmake.pp`.
  Retired make/fpmake machinery is not restored.

### FCL Net

- **Credit:** Sebastian Guenther, Michael Van Canneyt and the Free Pascal
  development team; Frederic Kehrein for the 2024 `fpsockets` implementation.
  `cnetdb.pas` preserves the University of California, Berkeley and Digital
  Equipment Corporation notices from its C networking header lineage.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-net`. Exact original upstream import revision/date are unknown.
  The reviewed NexusFPC revision is `86b61cc9dd212d58802a77383f6264bd2de1f9a5`;
  the most recent visible source normalization is
  `6c5bd2eef00b97fe12e5b1e87310ec60313b8c52` (2026-10-14).
- **Fork/import date:** relocated on **2026-10-17**, after the separately
  authorized retirement of unused `fpSock`/`HTTPSvlt` async consumers. All 25
  remaining source/test/documentation files were copied and hash-verified
  before implementation changes. The untouched current tree and SHA-256
  inventory are in Nexus `output/fcl-net-review/baseline` and
  `baseline-hashes.json`; no source archive is added to the repository.
- **Our location/status:** FCL Net was retired on **2026-10-17** after the
  owner authorized consolidation around Synapse. The required Unix resolver
  code now lives in `network/external/synapse/utNXSynapseResolver.pas`, with the
  private libc declarations in `nxresolverlibc.inc`; retained FPC/UC Berkeley/DEC
  notices, `COPYING.FPC` and the full LGPL text in `COPYING.txt` accompany that
  material. Extraction input: Packages commit
  `cd5d3127db14b6acf33a7c83f0c3dcb3d328a2e5`. The live certificate
  classes and data definitions from `sslbase` now live in OpenSSL's
  `src/obNXOpenSSLCertificates.pas` and `src/tpNXOpenSSLTypes.pas`.
  The alternative FCL socket/component layers and unused database query APIs
  were removed, including the FCL OpenSSL socket adapter. Useful TCP/resolver/TLS
  demonstrations in Nexus Lab now use Synapse; redundant or retired-API examples
  and tests were removed. Synapse and OpenSSL own their focused nxtest coverage.
  The earlier intact relocation and its review remain in Git history; current
  consolidation results are in `network/FCL-NET-CONSOLIDATION.md`.
- **SPDX:** principal FPC/FCL units use
  `LGPL-2.1-only WITH Independent-modules-exception`; `resolve.pas` explicitly
  grants `GPL-1.0-or-later`. `cnetdb.pas` retains `BSD-4-Clause` and an additional
  DEC permission/disclaimer notice, whose exact SPDX mapping is not inferred.
  New Nexus infrastructure/tests use `MPL-2.0-no-copyleft-exception`.
- **Evidence/notices:** original per-file headers; `COPYING.FPC` copied from
  NexusFPC `packages/COPYING.FPC`, and `COPYING.txt` from `rtl/COPYING.txt`.
  Historical package metadata is recoverable at
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-net/fpmake.pp`.
  Retired Make/fpmake machinery is not restored.

### LibFFI Pascal binding

- **Credit:** Sven Barth (2017) and the Free Pascal development team, as
  preserved in `ffi.pas` and `ffi.manager.pas`; native libffi credits Anthony
  Green, Red Hat, Inc. and contributors separately below.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  inherited through NexusFPC `83d89d45657c66a5ae4636233cb16961fd00a1ed`,
  `packages/libffi`, Git tree `a386598c08cbe28ad598a09dc2679506af547862`.
- **Fork/import date:** original date unknown, as recorded in the preceding
  Free Pascal entry. Relocated on **2026-10-18**; all nine inherited files are
  identified by `packages/nexus-packages/libffi/review/baseline-hashes.json`.
- **Our location/status:** maintained at `packages/nexus-packages/libffi`.
  The native C library remains external. Lua's RTTI adapter, invocation tests
  and Lab examples consume this package; it is not a bootstrap or RTL build
  input. The old compiler-side provider is removed.
- **SPDX:** Pascal binding: `LGPL-2.1-only WITH Independent-modules-exception`;
  native libffi: `MIT` (external distribution's notices apply).
- **Evidence/notices:** original source headers, `COPYING.FPC`, `COPYING.txt`,
  saved `CODE_REVIEW.md`, namespace wrappers/map and inherited native ABI probes.
  The original source snapshot is preserved by the Git tree and worktree proof.

### FCL Res

- **Credit:** Giulio Bernardi (2008) and the Free Pascal development team;
  FileInfo credits the FPC team (2013). Original source headers remain intact.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  inherited through NexusFPC `809ba610ddd2de4af75d6e7e372ac5a03efb270b`,
  `packages/fcl-res`, Git tree `dfeac8afcaaeccd0e103ad3af93975c52372928f`.
- **Fork/import date:** original date unknown, as recorded in the preceding
  Free Pascal entry. Relocated on **2026-10-18**, evidenced by the destination
  `review/baseline-hashes.json` (all 59 inherited files) and saved code review.
- **Our location/status:** maintained at `packages/nexus-packages/fcl-res`.
  Setup consumes the executable metadata readers; compiler resource-format
  tests resolve this package. Demonstrations remain in
  `../nexus-lab/examples/system/resources`. The original compiler-side provider
  and unused release-tool staging were removed; bootstrap stages are unchanged.
- **SPDX:** `LGPL-2.1-only WITH Independent-modules-exception`;
  original FPC license and exception texts accompany the package.
- **Evidence/notices:** source headers, `COPYING.FPC`, `COPYING.txt`,
  `CODE_REVIEW.md` and the baseline hash inventory at the package destination.

### FCL Registry

- **Credit:** Michael van Canneyt and the Free Pascal development team,
  including the contributors named in the retained source headers (1999–2022).
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-registry`. Exact original upstream import revision/date are
  unknown. Reviewed NexusFPC revision:
  `86b61cc9dd212d58802a77383f6264bd2de1f9a5`; latest visible source normalization
  `6c5bd2eef00b97fe12e5b1e87310ec60313b8c52` (2026-10-14).
- **Fork/import date:** relocated on **2026-10-17**. All 15 original runtime,
  wrapper and test files were copied and SHA-256 checked before implementation
  changes. An untouched local snapshot and hash inventory are in Nexus
  `output/fcl-registry-review/baseline` and `baseline-hashes.json`; the saved
  package review records the individual hashes and before/after results.
- **Our location/status:** Packages `fcl-registry`; native Windows registry
  backend and portable XML emulation retained. Former NexusFPC package path
  is historical. Demonstrations remain in Nexus Lab; compiler test fixtures
  remain with compiler tests. Production consumers include Windows COM support,
  Abbrevia ZIP associations and Synapse serial-port integration.
- **SPDX:** `LGPL-2.1-only WITH Independent-modules-exception` for the FPC/FCL
  runtime; new Nexus infrastructure and direct nxtest regressions use
  `MPL-2.0-no-copyleft-exception`.
- **Evidence/notices:** original source headers, `COPYING.FPC` from NexusFPC
  `packages/COPYING.FPC`, and `COPYING.txt` from `rtl/COPYING.txt` are retained.
  Historical package author/dependency/license metadata is available at
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-registry/fpmake.pp`.
  Retired Make/fpmake machinery is not restored.

### Retired FCL Async

- **Credit:** Areca Systems GmbH / Sebastian Guenther (2001–2005), with
  Michaël Van Canneyt and other Free Pascal contributors recorded in source history.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-async`. The most recent upstream package commit visible before
  Nexus changes is `2784c71b220de16a7d36bff7d1bd94c44013086a`
  (2026-01-01; comment corrections). This is lineage evidence.
- **Fork/import date:** original fork date unknown. Relocated on **2026-10-17**
  from NexusFPC `86b61cc9dd212d58802a77383f6264bd2de1f9a5`. All seven original
  files were copied and hash-verified before implementation changes. Retired
  later the same day after verifying that no production Nexus code used it.
- **Our location/status:** former NexusFPC `packages/fcl-async` and Nexus
  `packages/nexus-packages/fcl-async` removed, including package registrations,
  build recipes and dedicated tests. The unused FCL Net `fpSock` and `HTTPSvlt`
  units, their namespace wrappers, and their dependent Lab demonstrations and
  RPC helpers were also removed. No source or verification archive is retained;
  the original package remains recoverable from the NexusFPC revision above.
- **SPDX:** `LGPL-2.1-only WITH Independent-modules-exception`.
- **Evidence/notices:** original source headers in that revision, with the
  NexusFPC package notice `packages/COPYING.FPC` and LGPL text `rtl/COPYING.txt`.
  Historical authorship, license and Unix platform metadata are available at
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-async/fpmake.pp`.
  Retired Make/fpmake files are not restored.

### FCL Process

- **Credit:** Michael van Canneyt and the Free Pascal development team, as
  recorded by the original package metadata and retained source headers.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-process`; exact original import revision unknown. The reviewed
  relocation snapshot is NexusFPC revision
  `b7361861c09b1bcc0d3ca293639539fda644c594`; its last package change is
  `6c5bd2eef00b97fe12e5b1e87310ec60313b8c52` (2026-10-14).
- **Fork/import date:** original FPC fork date unknown. Relocated from FPC
  `packages/fcl-process` on **2026-10-15**, preserving all 53 original files
  byte for byte. The completed static review was saved with the package before
  the move. Subsequent nxtest cases reproduced and corrected eleven findings
  on Linux; three Windows findings remain open pending execution there.
- **Our location/status:** Packages `fcl-process`; maintained external-process,
  pipe, IPC and Windows service source with namespace wrappers, examples,
  assets and upstream tests retained. The former FPC location is historical.
  NexusForge, nxbuild and BotHost use the relocated process/pipe source.
- **SPDX:** `LGPL-2.1-only WITH Independent-modules-exception`; original package
  metadata says “LGPL with modification”.
- **Evidence/notices:** retained headers, `COPYING.FPC` copied from FPC
  `packages/COPYING.FPC`, and `COPYING.txt` copied from FPC `rtl/COPYING.txt`.
  Original author/license metadata is recoverable in FPC revision
  `781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-process/fpmake.pp`;
  those retired build files are not restored.

### FPCToolkit and Nexus Pascal

- **Credit:** coolchyni and FPCToolkit contributors; Microsoft copyright in the
  upstream license and inherited sample code.
- **Upstream:** [coolchyni/fpctoolkit](https://github.com/coolchyni/fpctoolkit).
- **Fork/import date:** unknown; earliest surviving Pascal baseline **2026-06-04**,
  `9e06538`, already identifies the Nexus extension.
- **Our location/status:** Pascal repository; maintained hard fork. FPCToolkit supplied
  the starting editor, extension packaging, and VS Code integration; Nexus now has
  its own architecture and direction.
- **SPDX:** upstream `MIT`, verified in upstream
  [LICENSE.txt](https://github.com/coolchyni/fpctoolkit/blob/master/LICENSE.txt).
  This is the upstream indicator, separate from the current Nexus package's license.
- **Related inherited lineage:** upstream also credits
  [ST-Pascal](https://github.com/maresmar/ST-Pascal) for syntax highlighting,
  [jcf-cli](https://github.com/git-bee/jcf-cli) for formatting, and the
  [genericptr](https://github.com/genericptr/pascal-language-server) and
  [arjanadriaanse](https://github.com/arjanadriaanse/pascal-language-server) language
  servers. Exact inherited revisions and their individual SPDX mappings are
  `NOASSERTION`; these are recorded as lineage, not assertions that all remain active.
  Their fork dates are unknown; our location is Pascal's inherited syntax/editor
  history and Nexus's language-server history.

### Microsoft VS Code extension sample

- **Credit:** Microsoft Corporation and contributors.
- **Upstream:** [code-actions sample](https://github.com/microsoft/vscode-extension-samples/blob/main/code-actions-sample/src/extension.ts).
- **Fork/import date:** unknown; present in Pascal baseline **2026-06-04**, `9e06538`.
- **Our location/status:** Pascal `src/languageServer/codeaction.ts`; retained adapted
  code identifies the upstream sample in its header.
- **SPDX:** `MIT`; [upstream license](https://github.com/microsoft/vscode-extension-samples/blob/main/LICENSE).

### Lazarus and Pascal language-server ecosystem

- **Credit:** Lazarus contributors and the Pascal language-server projects named above.
- **Upstream:** [Lazarus](https://gitlab.com/freepascal.org/lazarus/lazarus),
  [coolchyni/pascal-language-server](https://github.com/coolchyni/pascal-language-server).
- **Fork/import date:** no single fork; exact first use unknown. Nexus's original
  attribution page records these foundations by **2026-05-29**, `a1309026`.
- **Our location/status:** Nexus project/build conventions, external Lazarus tools and
  units, and historical NexusLS editor behavior. NexusLS has its own service, cache,
  and test structure. Historical influence is not a compatibility promise.
- **SPDX:** `NOASSERTION` for this mixed external-tool/reference entry; consult the
  installed Lazarus component's notices rather than applying one license to the IDE,
  CodeTools, LazUtils, and all referenced servers.

### External development and documentation tools

All rows refer to external tools, not new Nexus forks. First adoption is unknown
unless evidence is specified. Our repository is Nexus unless another key is given.

| Project / credited authors | Upstream location | Fork/import evidence | Our location / status | Upstream SPDX |
| --- | --- | --- | --- | --- |
| Visual Studio Code / Microsoft and contributors | [microsoft/vscode](https://github.com/microsoft/vscode) | No fork; credited by `a1309026`, 2026-05-29 | Pascal extension API; Nexus `projects/nexuscode`; external editor | `MIT` for Code OSS source; Microsoft's distributed product has separate terms |
| MkDocs / Tom Christie and contributors | [mkdocs/mkdocs](https://github.com/mkdocs/mkdocs) | No fork; Nexus docs scaffold `86537efd`, 2026-05-17 | `mkdocs.yml`, `docs/`; documentation build tool | `BSD-2-Clause` |
| Material for MkDocs / Martin Donath and contributors | [squidfunk/mkdocs-material](https://github.com/squidfunk/mkdocs-material) | No fork; Nexus docs scaffold `86537efd`, 2026-05-17 | `mkdocs.yml`; installed documentation theme | `MIT` |
| LLVM / LLVM contributors | [llvm/llvm-project](https://github.com/llvm/llvm-project) | No fork; first use unknown | Nexus build tooling; External Abbrevia C-codec builds; external compiler/linker | `Apache-2.0 WITH LLVM-exception` for current LLVM; component notices retained by installation |
| libffi / Anthony Green, Red Hat, Inc., and contributors | [libffi/libffi](https://github.com/libffi/libffi) | No fork; first use unknown | Nexus `packages/nexus-packages/libffi`; external native runtime, Pascal binding terms are recorded above | `MIT` for native libffi |

Delphi, VCL, Lazarus/LCL, and longstanding Pascal ownership, event, control, form,
and IDE conventions are conceptual influences. Their original locations are
[Embarcadero Delphi](https://www.embarcadero.com/products/delphi) and Lazarus above;
our locations are NexusUI and the developer tools. **Fork date: not applicable**;
**SPDX: not applicable to conceptual influence**. This entry asserts no imported
proprietary source and no Kylix support.

## GUI foundations

### fpGUI

- **Credit:** Graeme Geldenhuys, Sebastian Guenther, Viktor Nagy, Milan Marusinec
  (Milano), and the contributors in the retained `AUTHORS.txt`: Alexsander Rosa,
  Andrew Haines, Antonio Sanguigni, David Laurence Emerson, Felipe Monteiro de
  Carvalho, Giuliano Colla, Horacio Jamilis, Jean-Marc Levecque, Jean-Pierre Anghel,
  Michael van Canneyt, and Vladimir Zhirov.
- **Upstream:** [graemeg/fpgui](https://github.com/graemeg/fpgui).
- **Fork/import date:** original fork unknown; current collective-repository import
  **2026-10-08**, Packages `09d5f97`.
- **Our location/status:** Packages `gui/external/fpgui`; maintained foundation of
  the native NexusUI controls in `gui/src`.
- **Retired applications (2026-10-17):** the owner directed complete removal of
  Maximus (`ide/`), including its source, assets, templates, debugger integration
  and dedicated tests. The owner separately approved removing its dependent
  Nanoedit demonstration from Lab `examples/gui/fpgui/apps/nanoedit`. Graeme
  Geldenhuys and the original contributors retain historical credit; Maximus's
  individual modified-LGPL notices and Nanoedit's `BSD-2-Clause` notices remain
  recoverable in Git at Packages `fe5d770b66c89ed737648ea7c93d8120668f93ea` and
  Lab `0f3f79de6602d0b2fab30a9c6f350cb4bf6e2cd2`. The fpGUI framework, shared
  licenses and author records remain in place; no copy of either retired
  application is maintained elsewhere.
- **Linux runtime library correction (2026-10-17):** the X11/Xft imports now use
  the supported ABI names shared with the X11 package (now Nexus `graphics/x11`). The inherited
  AggPas FreeType binding now names `libfreetype.so.6` on Linux. Existing fpGUI
  and AggPas authorship/license notices remain intact. Two direct font-binding
  nxtest cases live beside the framework tests; validation is recorded in
  Nexus `docs/reviews/linux-shared-libraries.md`.
- **SPDX:** framework/UIDesigner LGPL 2.1 text with linking permission:
  `LGPL-2.1-only WITH Independent-modules-exception`; individual file headers may
  grant later versions. DocView/examples have GPL 2.0 notices; bundled extras vary.
  No single expression is asserted for the complete fpGUI tree.
- **Evidence/notices:** `AUTHORS.txt`, `LICENSE.txt`, `license.LGPL2.txt`,
  `license.ModifiedLGPL.txt`, and the original per-file notices.

The following material is inherited through fpGUI. **Fork date is unknown; current
Packages import is 2026-10-08, `09d5f97`, for every row.** Our paths are under Packages
`gui/external/fpgui`. These are retained upstream components, not claims of active use.

| Component / credit | Original location | Our location / evidence | Upstream SPDX |
| --- | --- | --- | --- |
| AggPas / Milan Marusinec; Anti-Grain Geometry / Maxim Shemanarev | [AggPas](https://aggpas.sourceforge.net/), [AGG](https://www.antigrain.com/) | `extras/aggpas`, `framework/src/main/pascal/corelib/render/software/agg_basics.pas`; version 2.4 RM3 header | `LicenseRef-AGG-2.4` for the supplied permissive notice |
| PasExpat / Milan Marusinec; Expat / Thai Open Source Software Center, Clark Cooper, Expat maintainers | `http://www.pasports.org/pasexpat`; [Expat](https://libexpat.github.io/) | `extras/aggpas/expat-pas/readme.txt` and source notices | `NOASSERTION` for Pascal port; upstream C Expat `MIT` |
| General Polygon Clipper 2.31 / Alan Murta, University of Manchester Advanced Interfaces Group | `http://www.cs.man.ac.uk/aig/staff/alan/software/` | `extras/aggpas/gpc/copying.txt` | `LicenseRef-GPC-Noncommercial`; retained extra, commercial permission is not established |
| NiceGrid / original contributors named in source | [fpGUI vendored source](https://github.com/graemeg/fpgui/tree/master/extras/contributed) | `extras/contributed`; fpGUI `LICENSE.txt` identifies MPL but omits the version | `NOASSERTION` pending exact MPL version |
| FreeType, Jedi Code Format, and other bundled extras / their original contributors | [fpGUI extras](https://github.com/graemeg/fpgui/tree/master/extras) | `extras/freetype_windows`, `extras/jedi_code_format`, remaining extras; original notices | `NOASSERTION` for the mixed collection |

### Virtual TreeView

- **Credit:** Mike Lischke, original copyright digital publishing AG; Lazarus fork
  by Luiz Americo Pereira Camara and contributors. Detailed contributor, tester,
  documentation, and indirect-contribution credits remain in `VirtualTrees.pas`.
- **Upstream:** [blikblum/VirtualTreeView-Lazarus](https://github.com/blikblum/VirtualTreeView-Lazarus),
  branch `lazarus-master`, version 6.0.0, revision
  `a42d55f18ec293bae853a34ee05c65009b1d2b94`.
- **Fork/import date:** documented import **2026-10-05**; current Packages import
  **2026-10-08**, `09d5f97`.
- **Our location/status:** Packages `gui/external/vtv` preserves upstream `Source`,
  `Resources`, README, installation notes, and change log. Native adaptations are in
  `gui/src/vtv`; the Nexus control is `gui/src/obNXVirtualTreeView.pas`.
  The upstream LCL widget is reference material, not compiled into fpGUI applications.
- **SPDX:** `MPL-1.1 OR LGPL-2.1-or-later` for adapted upstream files; see their headers.
  Independent Nexus drawing/input code has its own Nexus notices.
- **Adapted work:** node model, linked lists, lazy initialization, traversal, subtree
  metrics, and stable merge sorting.

### SimpleGUI and the earlier SDL UI

- **Credit:** Matthias J. Molski; earlier LK GUI by Lachlan Kingford.
- **Upstream:** [SimpleGUI](https://github.com/Free-Pascal-meets-SDL-Website/SimpleGUI),
  [LK GUI](https://sourceforge.net/projects/lkgui/).
- **Fork/import date:** unknown. Existing NexusUI attribution, preserved by Packages
  `09d5f97` on **2026-10-08**, records its use as the initial scaffold.
- **Our location/status:** historical NexusUI scaffold, now Packages `gui` history.
  SDL windows, rectangles, input, primitive rendering, and retained-control structure
  informed the early work. Current NexusUI uses fpGUI.
- **SPDX:** SimpleGUI `MIT`, from its
  [upstream README](https://github.com/Free-Pascal-meets-SDL-Website/SimpleGUI#license).
  Exact LK GUI license/revision inherited by that upstream is `NOASSERTION`.

### SDL and Pascal headers

- **Credit:** Sam Lantinga and SDL contributors; PascalGameDevelopment and the Pascal
  SDL header contributors; ev1313 for the earlier header repository.
- **Upstream:** [SDL](https://github.com/libsdl-org/SDL),
  [SDL_image](https://github.com/libsdl-org/SDL_image),
  [SDL_ttf](https://github.com/libsdl-org/SDL_ttf),
  [SDL2-for-Pascal](https://github.com/PascalGameDevelopment/SDL2-for-Pascal),
  [Pascal-SDL-2-Headers](https://github.com/ev1313/Pascal-SDL-2-Headers).
- **Fork/import date:** original acquisition unknown; Lab retained dependencies
  recorded **2026-06-06**, `4050dc2`; earlier NexusUI use recorded by `a1309026`,
  **2026-05-29**.
- **Our location/status:** Lab `rogue/common/sdl` and `rogue/common/sdl_ext`; historical
  NexusUI backend; retained Engine copies have their own versions/notices below.
- **SPDX:** SDL2/image/ttf native projects `Zlib`; Pascal headers retain
  `MPL-1.1` and `Zlib` license texts, with file-specific grants controlling their
  relationship (`NOASSERTION` for a package-wide expression). Image codecs have
  separate JPEG, PNG, TIFF, WebP, and zlib notices in `sdl_ext`.

## Reusable packages

### Abbrevia

- **Credit:** TurboPower Software, TurboPack maintainers, and contributors including
  Craig Peterson and Pierre le Riche; individual unit credits remain intact.
- **Upstream:** [TurboPack/Abbrevia](https://github.com/TurboPack/Abbrevia), revision
  `805915396d0cc597e7c55df9fbb36057e65748df` dated 2026-09-23.
- **Fork/import date:** original fork unknown; collective import **2026-10-09**,
  External `bc4775a`; former fork absorbed as ordinary tracked files **2026-10-10**,
  `a1879d0`. September 23 is the upstream revision date, not the Nexus fork date.
- **Our location/status:** External `compression/abbrevia/external/abbrevia`;
  maintained directly here, formerly a separate NexusAbbrevia fork.
- **SPDX:** Abbrevia core `MPL-1.1`; bundled codecs have the separate terms below.
- **Preserved work:** the original import contained 627 files. Retained material
  includes original notices, the NexusFPC runtime corrections, codec sources,
  nonvisual regression cases, and archive fixtures.
  Corrections cover compiler directives/units, streams and byte buffers, archive
  metadata, paths, TAR processing, CRT helpers, and WavPack helpers.
  The Win64 PPMd binding's C record alignment, 32-bit internal references, and
  packed helper records were corrected on **2026-10-12**, with successful
  extraction of the bundled PPMd corpus.
  Cabinet API record alignment and C enum sizes were corrected on **2026-10-13**,
  with SDK layout and CAB round-trip checks passing on Win32 and Win64.
  CAB stream additions and concatenated gzip extraction were corrected on
  **2026-10-13**; the original disabled cases are active nxtest regressions.
  The existing i386 deflate assembler blocks now explicitly select Intel syntax.
  ZIP legacy filename decoding on UTF-8 hosts, Unicode Path checksums over stored
  bytes, and Windows NT filename precedence over OEM guessing were corrected on
  **2026-10-14**, with regression checks passing on Win32, Win64, and Linux.
  LZMA stream wrappers gained common Windows/Linux synchronization, a bounded
  input queue, and reliable explicit completion/error handling on **2026-10-14**;
  twelve shared nxtest regressions pass on Win32, Win64, and Linux.
  Unit names use the two-part `Abbrevia.Name` form; descriptive class and exception
  names retain `TAb` and `EAb` prefixes. Source, package, test, and resource
  references were updated together on **2026-10-12**.
  Delphi/C++Builder package projects, VCL/CLX/FireMonkey controls and editors,
  Delphi COM automation wrappers, IDE resources, GUI test runners, and Borland
  OMF/ELF codec objects were retired on **2026-10-12**. Runtime components and
  compound-file storage remain; only the latter's VCL tree-view methods were
  removed. Compiler-specific branches now use NexusFPC and its RTL bindings.
  Borland-only C header branches were removed; LLVM still builds the codec
  sources through the package's Forge recipe.
  The reproducible LLVM recipe is `compression/abbrevia/Package.nxscript`;
  the former `scripts/Build-AbbreviaLLVM.ps1` recovery recipe was retired after
  migration to direct Forge operations on **2026-10-12**.
  operational build/validation details remain in that package's README.

Every codec below came through the same Abbrevia revision and import dates above.
Our repository is External; paths are under `compression/abbrevia/external/abbrevia`.

| Codec / credit | Original location | Our location / evidence | Upstream SPDX |
| --- | --- | --- | --- |
| bzip2 1.0.8 / Julian R. Seward | [sourceware.org/bzip2](https://sourceware.org/bzip2/) | `thirdparty/bzip2/LICENSE`, `readme.txt`, C files | `bzip2-1.0.6` (SPDX license name; code version is 1.0.8) |
| LZMA SDK 26.00 / Igor Pavlov | [7-Zip LZMA SDK](https://7-zip.org/sdk.html); `https://7-zip.org/a/lzma2600.7z` | `thirdparty/lzma`; public-domain source headers | `LicenseRef-LZMA-SDK-Public-Domain` |
| PPMd from 7-Zip SDK 26.0 / Igor Pavlov, PPMd authors credited in source | [7-Zip](https://7-zip.org/) | `thirdparty/ppmd/readme.txt` and source headers | `LicenseRef-LZMA-SDK-Public-Domain` |
| WavPack 5.90.0 / David Bryant | [dbry/WavPack](https://github.com/dbry/WavPack) | `thirdparty/wavpack`; BSD statement in `wavpack.h`; [upstream license](https://github.com/dbry/WavPack/blob/master/license.txt) | `BSD-3-Clause`; local header references `license.txt`, which is absent from this imported directory |

The DCL Implode decoder was added separately on **2026-10-13**:

- **Credit:** Mark Adler; original blast copyright 2003, 2012, 2013.
- **Original location/revision:** [blast 1.3 in zlib v1.3.1](https://github.com/madler/zlib/blob/v1.3.1/contrib/blast/blast.c),
  `contrib/blast/blast.c` and `blast.h`; algorithm and fixed Huffman tables.
- **Our location/status:** External repository,
  `compression/abbrevia/external/abbrevia/source/Abbrevia.DCL.pas`; active Pascal
  adaptation for ZIP compression method 10. The altered-source declaration and
  complete original license remain in the unit. This adds no C runtime dependency.
- **Fork/import date:** **2026-10-13**, the dated local adaptation and nxtest
  addition; this component was not part of the earlier Abbrevia import.
- **Upstream SPDX:** `Zlib`.
- **Verification provenance:** blast's eight-byte reference vector is retained in
  `test/tsAbDecompressionTests.pas`. The additional all-256-coded-literals vector
  was independently decoded and compared with upstream blast for dictionary
  headers 4, 5, and 6 before being embedded in the same test unit.

### PasZLib

- **Credit:** Jacques Nomssi Nzali; Free Pascal contributors to TZipper and other units.
- **Upstream:** `http://www.tu-chemnitz.de/~nomssi/paszlib.html`; Free Pascal
  `packages/paszlib`, imported through FPC revision
  `a7782c0f1291c1a7d6c90280a296a28e723b19f5`.
- **Fork/import date:** collective import **2026-10-09**, External `bc4775a`.
  Original FPC adoption predates this import; its date is unknown here.
- **Our location/status:** NexusFPC `rtl/objpas/paszlib.pas` and
  `paszlibio.pas` are the authoritative runtime source as of **2026-10-18**, by
  explicit owner direction; tests/legal history remain in `packages/paszlib`. The duplicate External
  `compression/paszlib/external/paszlib` tree and its separate catalog entries
  were removed after comparison and native verification. Initially, seventeen of twenty
  runtime source/include files were byte-identical; the remaining differences
  supported DOS/DPMI, WebAssembly/NOGOTO and OS/2, outside the current target
  matrix. NexusFPC's normalized `.pas` filenames and supported-target code were
  retained. Subsequent checked tests proved unsigned match-position underflow
  on window slides and a level-zero zlib-header range error; Nexus fixed both
  in the original `zdeflate.pas` with five direct nxtest regressions, retained
  in the consolidated source. The former package owns the reconciliation record
  and tests. The 2026-10-18 consolidation also retains regressions for the
  owner-approved gzip initialization/file-ownership cleanup correction. CRC32 now lives in `rtl/objpas/crc32.pas`, inherited from
  ZStream/private utNXPasZLibCRC32 with Daniel Mantione/FPC notices, and is shared
  with the compiler instead of its separate table. No hashing package is required.
  Lab demonstrations are consolidated under `examples/data/compression/paszlib`;
  the redundant `paszlib-external` folder was removed.
- **SPDX:** PasZLib core `Zlib`; FPC additions carry their individual FPC notices,
  with the LGPL text and `Independent-modules-exception` as applicable.
- **Evidence/notices:** official `packages/paszlib/readme.txt` legal section, the consolidated
  `rtl/objpas/paszlib*.pas` headers,
  NexusFPC `packages/COPYING.FPC` and `rtl/COPYING.txt`. The removed external
  `COPYING.FPC` was byte-identical to the official notice. Runtime comparison,
  baseline hashes and test/build results are recorded in
  NexusFPC `packages/paszlib/CONSOLIDATION.md` and
  `rtl/objpas/paszlib-consolidation.md`; isolated validation outputs are in the
  development worktree. Prior external import history remains in Git.

### HashLib4Pascal

- **Credit:** Ugochukwu Mmaduekwe and contributors.
- **Upstream:** [HashLib4Pascal](https://github.com/Xor-el/HashLib4Pascal), revision
  `1687d81fd0c8a08f3f04e7fed507a19131fbc0b1`.
- **Fork/import date:** **2026-10-17**, by the approved
  `work/plans/hashlib4pascal-package-and-hash-consumer-audit.md`. The selected
  runtime/include files were byte-checked against that revision's source archive;
  `hashlib4pascal/review/import-hashes.json` records each imported file digest.
- **Our location/status:** Packages `hashlib4pascal/external/hashlib4pascal`,
  moved from External Packages on **2026-10-17** by direct owner instruction,
  maintained as `NXRP.HashLib4Pascal`; all 144 runtime units and 135 includes,
  original README and license retained. Useful upstream inline known-answer/API
  tests are adapted directly to nxtest, with their source attribution retained.
  This revision has no `HashLib.Tests/Data` directory or raw-data fixture tree.
- **SPDX:** `MIT`. Full original `LICENSE` and source notices remain with the
  import. Nexus build recipes/tests keep their own notices. Any FPC support units
  incorporated into a provider retain the FPC notices recorded above; HashLib's
  MIT license does not relabel them.
- **Integration:** ordinary digest/HMAC/CRC/KDF library and tool dependency.
  It is not a compiler-bootstrap, package-metadata or PasZLib dependency.
  Source review, verification results and target limits are in the package's
  `CODE_REVIEW.md`; examples remain in Nexus Lab.

### DMustache and Synopse include

- **Credit:** Arnaud Bouchez, Synopse Informatique, shura1990, and contributors named
  in the retained Synopse source headers.
- **Upstream:** [synopse/dmustache](https://github.com/synopse/dmustache);
  `SynDoubleToText.inc` came from [synopse/SynPDF](https://github.com/synopse/SynPDF).
- **Fork/import date:** original Nexus fork unknown; collective submodule recorded
  **2026-10-08**, External `7110906`; absorbed as ordinary tracked files
  **2026-10-10**, `604e0a7`.
- **Our location/status:** External `mustache/external/dmustache`; maintained directly
  here, formerly [nxrp-dev/dmustache](https://github.com/nxrp-dev/dmustache).
  Consumers use `SynMustache` directly, including NexusForge and NexusScript.
- **SPDX:** `MPL-1.1 OR GPL-2.0-or-later OR LGPL-2.1-or-later`, matching the source
  headers' alternatives. Upstream README additionally describes later MPL versions;
  preserve the actual file grants when assessing a particular file.
- **Preserved revisions:** upstream head `3360c79`; Nexus `f416f11` supplies
  `SynDoubleToText.inc` with its original license header, because `SynCommons.pas`
  enables the `DOUBLETOSHORT_USEGRISU` include for the FPC/Win64 path but upstream
  DMustache did not supply that file. Nexus
  `a178d4475657f1c6f5cae1a986740305c54d543d` corrects `SynCommons.pas` and `Synopse.inc`
  for NexusFPC 3.3. All source/include bytes survived the ownership conversion.
  The former 13-file tree and full history are backed up at
  `C:\backup\DMustacheOwnership-20261010`; `NEXUS_PATCHES.md` prose now lives here.
- **Mustache specification:** [mustache/mustache](https://github.com/mustache/mustache)
  is the template-language reference, not a separate imported renderer. Fork date
  not applicable; SPDX not applicable to that conceptual reference.

### TRegExpr

- **Credit:** Andrey Sorokin and contributors; original authors remain in the unit header.
- **Upstream:** [andgineer/TRegExpr](https://github.com/andgineer/TRegExpr), revision
  `19389caeb6823cddfb110ed284f57d1088dd8ac2`.
- **Fork/import date:** collective package import **2026-10-10**, External `b8fb14e`;
  earlier use elsewhere is not established by this date. Converted to ordinary
  source on **2026-10-15**, preserving the pinned revision `19389ca` (TRegExpr 1.194).
- **Our location/status:** External `regexpr/external/tregexpr`; source maintained
  directly in the package repository and consumed directly by fpGUI. The former
  upstream submodule is retired; original source bytes and file modes are retained.
- **SPDX:** `MIT` in `LICENSE.txt`; `src/regexpr.pas` retains additional alternative
  license notices. The MIT identifier does not remove those alternatives.

### Synapse

- **Credit:** Lukas Gebauer and contributors; `blcksock.pas` thanks Gregor Ibic and
  Intelicom for SSL inspiration.
- **Upstream:** [geby/synapse](https://github.com/geby/synapse), imported revision
  `18bf82e1cebd9eb22732c4e7882898802fc1560e`.
- **Fork/import date:** original adoption unknown; collective import **2026-10-08**,
  Packages `8e95ff2`. Converted to ordinary source on **2026-10-15** using the
  original working copy's commit `9ae4133905f55d4a019caa0a0635e9e1e98c8135`,
  based on upstream `18bf82e`.
- **Our location/status:** Packages `network/external/synapse`; source imported
  directly into the package repository. The former upstream submodule is retired.
- **Nexus correction:** recovered commit `9ae4133`, "Guard the Delphi imported-data
  directive under FPC," adds an FPC guard around `{$IFOPT G+}` in `jedi.inc`.
  Packages `fc24ff5` selected this local commit while its submodule URL still
  pointed at upstream, where that commit was unavailable. Recovery source:
  `/media/kcollins/D430AF4530AF2E04/gitdev/nexus/packages/nexus-packages/network/external/synapse`.
- **Nexus extension (2026-10-17):** Kevin Collins / Nexus added ALPN configuration
  and negotiated-protocol access to Synapse's TLS interface. The Nexus OpenSSL
  adapter uses the existing shared ALPN implementation; XMPP direct TLS offers
  `xmpp-client`. Original Synapse notices and source line endings are preserved.
- **SPDX:** original Synapse uses `BSD-3-Clause`, retained in headers including
  `blcksock.pas`. The resolver support extracted from FCL has the separate
  FPC/UC Berkeley/DEC terms recorded under [FCL Net](#fcl-net).

### OpenSSL and FPC bindings

- **Credit:** OpenSSL Project and contributors; Free Pascal binding authors;
  Nexus-owned adapters and helpers by Kevin Collins.
- **Upstream:** [OpenSSL](https://github.com/openssl/openssl); Free Pascal bindings
  imported through FPC commit `af042760`.
- **Fork/import date:** first native runtime adoption unknown; collective binding
  import recorded **2026-10-08**, Packages `b65a2ae`.
- **Our location/status:** Packages `network/openssl`; dynamic native OpenSSL 3
  dependency, not bundled in that package. Engine has separate inherited OpenSSL
  records and a newer local dependency build.
- **SPDX:** native OpenSSL 3 `Apache-2.0`; inherited Pascal units retain FPC terms
  including `Independent-modules-exception` in `network/openssl/COPYING.FPC`.
  Binding notices are distinct from the native library license.

### SQLite

- **Credit:** D. Richard Hipp and SQLite contributors.
- **Upstream:** [SQLite](https://sqlite.org/), [public-domain declaration](https://sqlite.org/copyright.html).
- **Fork/import date:** original acquisition unknown; current Packages binding
  location recorded **2026-10-08**, `58f36a5`.
- **Our location/status:** Packages `db/sqlite`, including `reference/sqlite3.h` and
  `runtime/win64/sqlite3.dll`; database support and symbol-cache consumers.
- **SPDX:** `blessing` for the retained SQLite header's public-domain blessing;
  Nexus binding/wrapper code has its own notices. This does not assign SQLite's
  public-domain status to independently authored Nexus code.

### Lua

- **Credit:** Lua.org, PUC-Rio, and Lua contributors.
- **Upstream:** [Lua](https://www.lua.org/); version 5.5.1 reference headers and the
  separate 5.1 ABI used by the Engine/plugin bridge.
- **Fork/import date:** original acquisition unknown; collective reference-header
  import recorded **2026-10-08**, Packages `8e95ff2`.
- **Retained Linux toolchain runtime:** unmodified Lua **5.1.5**, acquired on
  **2026-10-15** from [the official source archive](https://www.lua.org/ftp/lua-5.1.5.tar.gz).
  Archive SHA-256 `2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333`
  matches the [upstream download index](https://www.lua.org/ftp/). Built with
  Clang for `x86_64-linux` in the workspace's shared `toolchain` directory,
  installed at `toolchain/lua/5.1.5/x86_64-linux` for NexusTest UI and the
  Lua 5.1 plugin bridge. The downloaded source, original `COPYRIGHT`, build
  commands, and `build-identity.json` remain with the toolchain installation.
- **Our location/status:** Packages `lua/reference`, bindings under `lua`, and Engine
  Lua runtime sources. Native version and ABI must be read from the actual consumer.
- **SPDX:** native Lua and reference headers `MIT`; independently authored bindings
  retain their own notices.

## Engine lineage and inherited components

### Corona SDK, Solar2D, and Nexus2D

- **Credit:** Corona Labs, Solar2D maintainers and contributors, and the component
  authors below. Root license copyright is Solar2D, 2020–2021.
- **Upstream:** [coronalabs/corona](https://github.com/coronalabs/corona), the
  Corona SDK project subsequently known as Solar2D.
- **Fork/import date:** unknown; first visible Nexus work **2026-09-30**, Engine
  `1113ae2b`, after visible upstream baseline `848e5dd4` dated 2026-09-22.
- **Our location/status:** Engine repository, local `C:\gitdev\Nexus2D`; maintained
  fork. Packages `solar2d` contains Nexus bindings/plugin integration; local
  `C:\gitdev\tools\solar2d-win64` holds a built engine, not another original project.
- **SPDX:** engine core `MIT` from `LICENSE.md`; bundled components vary.
- **Evidence/notices:** root `LICENSE.md`, source headers, `.gitmodules`, and
  `sdk/dmg/Corona3rdPartyLicenses*.txt`. These inherited distribution payloads remain
  intact; they explicitly describe possible platform dependencies, not one universal
  runtime dependency set.

The following inventory consolidates the inherited attribution sources. **For every
row below, exact upstream adoption and Nexus fork dates are unknown; the surviving
Nexus baseline is 2026-09-30, `1113ae2b`. Our repository is Engine.** Paths are relative
to Engine. A “notice only” location means that the inherited license payload records
the component; this does not assert that its source is still present or built.

In the table, **Corona vendor tree** means the original import location
[coronalabs/corona](https://github.com/coronalabs/corona), at the corresponding path.
Where a more original URL has not been recovered, this identifies the verifiable
supplier instead of guessing a repository. “General notices” means
`sdk/dmg/Corona3rdPartyLicenses.txt`; platform notices are the adjacent
`Corona3rdPartyLicensesFor*.txt` files.

| Component / credited authors | Upstream location | Our location / retained evidence | Upstream SPDX / qualification |
| --- | --- | --- | --- |
| Lua / Lua.org, PUC-Rio | [lua.org](https://www.lua.org/) | `external/lua-5.1.3`, general notices | `MIT` |
| LPeg / Lua.org, PUC-Rio | [LPeg](https://www.inf.puc-rio.br/~roberto/lpeg/) | `external/lpeg`, general notices | `MIT` |
| LuaSocket / Diego Nehab | [Corona LuaSocket import](https://github.com/coronalabs/submodule-luasocket) | `external/luasocket`, general notices | `MIT` |
| LuaFileSystem / Kepler Project | [Corona LFS import](https://github.com/coronalabs/submodule-lfs) | `external/luafilesystem`, general notices | `MIT` |
| RemDebug / Kepler Project | Corona vendor tree | `external/remdebug-1.0`, general notices | `MIT` |
| LuaSQLite3 / Tiago Dionizio, Doug Currie | Corona vendor tree | `external/lsqlite3-7`, general notices | `MIT` for binding; SQLite engine has separate public-domain terms |
| dkjson / David Heiko Kolf | Corona vendor tree | `modules/json/external/dkjson.lua`, `platform/resources/dkjson.lua` | `MIT` |
| LowLatencyAudio / project contributors | `http://code.google.com/p/lowlatencyaudio` | General and Android notices; notice only | `MIT` |
| dirent.h / Toni Ronkko | Corona vendor tree | `external/winutil/dirent.h`, general notices | `MIT` |
| Box2D / Erin Catto | [Corona Box2D import](https://github.com/coronalabs/submodule-box2d) | `external/Box2D`, general notices | `Zlib` for inherited version |
| SDL 1.3 / Sam Lantinga | [libsdl.org](https://www.libsdl.org/) | General notices | `Zlib` |
| SDL 1.2 / Sam Lantinga | [libsdl.org](https://www.libsdl.org/) | General and platform notices | `LGPL-2.1-only` text; consult source for later-version grants |
| SDL_sound / Ryan C. Gordon | [icculus.org](https://icculus.org/SDL_sound/) | General and platform notices; ALmixer-related retained material | `LGPL-2.1-only` text; consult individual files |
| HMAC / Olivier Gay | Corona vendor tree | `external/hmac`, general notices | `BSD-3-Clause` |
| Ogg, Vorbis / Xiph.org Foundation | [Xiph](https://xiph.org/) | `external/ogg/libogg`, `external/ogg/libvorbis`, COPYING files and general notices | `BSD-3-Clause` |
| Tremor / Xiph.org Foundation | [Xiph Tremor](https://xiph.org/vorbis/) | `external/tremor/Tremor/COPYING`, general notices | `BSD-3-Clause` |
| DDG Reachability / Donoho Design Group | Corona vendor tree | `external/Reachability_2.0.4ddg`, general notices | `BSD-3-Clause` |
| YRKSpinningProgressIndicatorLayer / Kelan Champagne | `http://yeahrightkeller.com` | `external/kelan-yrk-spinning-progress-indicator-layer`, general notices | `BSD-3-Clause` |
| Apache Ant / Apache Software Foundation | [ant.apache.org](https://ant.apache.org/) | `external/apache-ant-1.8.1`, general and platform notices | `Apache-2.0`; bundled additional W3C notices remain separate |
| Facebook API / Facebook | Corona vendor tree | General and platform notices | `Apache-2.0` for the recorded version |
| Android Asynchronous HTTP Client / James Smith | [loopj.com](https://loopj.com/android-async-http/) | General notices | `Apache-2.0` |
| OpenAL Soft / Chris Robinson | [Corona OpenAL fork](https://github.com/coronalabs/openal-soft) | `external/openal-soft`, `external/openal-soft-1.12.854/COPYING`, general notices | `LGPL-2.1-only` text; individual source grants control |
| OpenAL Soft Apportable / Apportable Inc. | [Corona Apportable import](https://github.com/coronalabs/submodule-openal-soft_apportable) | `external/openal-soft_apportable`, general notices | `LGPL-3.0-only` text; separate from the older OpenAL copy |
| mpg123 / Michael Hipp and contributors | [mpg123.org](https://www.mpg123.org/) | `external/mpg123-1.13.1/AUTHORS`, `COPYING`, general notices | `NOASSERTION` for the complete imported tree; general notice supplies LGPL 2.1 |
| TimXmlRpc / Dr. Tim Cooper | Corona vendor tree | General notices; notice only | `LGPL-2.1-only` text; exact source version not established |
| MD4 / RSA Data Security, Inc. | Corona vendor tree | General and platform notices, MD4 block | `RSA-MD`; derived work must retain the MD4 identification |
| OpenSSL historical version / OpenSSL Project, Eric Young and contributors | [openssl.org](https://www.openssl.org/) | General notices, OpenSSL and SSLeay block | `OpenSSL`; historical notice, distinct from current OpenSSL 3 `Apache-2.0` |
| Apple source examples / Apple Inc. | Corona vendor tree | General and platform notices, Apple Source Examples block | `LicenseRef-Apple-Sample-Code` |
| Simple-NSAlert-with-Blocks / loghound; Omni Group | [loghound/Simple-NSAlert-with-Blocks](https://github.com/loghound/Simple-NSAlert-with-Blocks) | `external/Simple-NSAlert-with-Blocks`, general notices | `LicenseRef-Omni-Source` |
| Sundown / vmg and contributors | [vmg/sundown](https://github.com/vmg/sundown) | `external/sundown/Project`, general notices | `ISC` |
| Exo 2 fonts / Natanael Gama | `http://www.ndiscovered.com/` | General notices; reserved names Exo2-Regular, Exo2-Bold | `OFL-1.1` |
| Noun Project icons / Mourad Mokrane, Kidiladon, icon 54, Gregor Cresnar, Shmidt Sergey, Justin Blake, Arun Dadhwal | [Noun Project](https://thenounproject.com/) | General notices; inherited icon attribution | `CC-BY-3.0` |
| libpng / PNG contributing authors, Group 42 | [libpng.org](http://www.libpng.org/pub/png/libpng.html) | `external/libpng1243b01/LICENSE`, `external/lpng1256/LICENSE`, platform notices | `Libpng` for retained notices; bundled extras have their own COPYING files |
| libjpeg / Thomas G. Lane, Independent JPEG Group | [ijg.org](https://www.ijg.org/) | `external/libjpeg`, Android/platform notices | `IJG` |
| rcedit / atom contributors | [atom/rcedit](https://github.com/atom/rcedit) | `external/rcedit/Project/LICENSE`, Windows notices | `MIT` |
| Cocoa XML-RPC / Eric Czarny | Corona vendor tree | Mac Simulator notices | `MIT` |
| ALmixer / Eric Wing, PlayControl Software LLC | Corona vendor tree | `external/ALmixer/LICENSE.txt`, `CORONA_LICENSE_NOTES.txt` | `LGPL-2.1-only` text; a separate Corona Labs contractual license is mentioned, applicability to Nexus is unverified |
| ANGLE / ANGLE Project authors, TransGaming, Google, 3DLabs | Corona vendor tree | `external/Angle/Project/LICENSE`, `AUTHORS`, nested notices | `BSD-3-Clause` for core; nested compiler/MurmurHash/Windows emulation licenses differ |
| JNLua / Andre Naef | Corona vendor tree | `external/JNLua/LICENSE.txt` | `MIT` |
| GLEW / GLEW, Mesa, Khronos contributors | Corona vendor tree | `external/glew/Project/LICENSE.txt`, retained credits.html and generated header notices | `NOASSERTION` for combined GLEW/Mesa/Khronos terms |
| ios-sim / Landon Fuller, Plausible Labs Cooperative | Corona vendor tree | `external/ios-sim/LICENSE` | `MIT` |
| LOOP / Tecgraf, PUC-Rio | Corona vendor tree | `external/loop-2.3-beta/LICENSE` | `MIT` |
| LuaCrypto / Keith Howe | Corona vendor tree | `external/luacrypto-0.2.0/doc/us/license.html` | `MIT` |
| LuaProfiler / Kepler Project team | Corona vendor tree | `external/luaprofiler-2.0.2/doc/us/license.html` | `MIT` |
| LuaXMLRPC / Kepler Project; Roberto Ierusalimschy, Andre Carregal, Tomas Guisasola | Corona vendor tree | `external/luaxmlrpc-1.0b/license.html` | `MIT` |
| pthreads-win32 / Ross P. Johnson and contributors | Corona vendor tree | `external/pthreads-w32-2-8-0-release/COPYING`, `COPYING.LIB` | `LGPL-2.1-only` |
| SmoothPolygon / zx9597446 | Corona vendor tree | `external/smoothpolygon/LICENSE` | `MIT` |
| zlib / Jean-loup Gailly, Mark Adler; DotZLib contributors | Corona vendor tree | `external/zlib123`, nested `contrib/dotzlib/LICENSE_1_0.txt` | Core `Zlib`; DotZLib `BSL-1.0` |
| Dear ImGui / Omar Cornut | [ocornut/imgui](https://github.com/ocornut/imgui) | `platform/linux/src/imgui/LICENSE.txt` | `MIT` |
| ImGui file browser / Zhuang Guan | [AirGuanZ/imgui-filebrowser](https://github.com/AirGuanZ/imgui-filebrowser) | `platform/linux/src/imgui/LICENSE-imfilebrowser.txt` | `MIT` |
| create-dmg / Andrey Tarantsov and contributors | Corona vendor tree | `bin/mac/create-dmg/LICENSE` | `MIT` |
| Crypto++ / original contributors | [Corona CryptoPP import](https://github.com/coronalabs/submodule-CryptoPP) | `external/CryptoPP` gitlink | `NOASSERTION` for pinned contents |
| FreeType / FreeType contributors | [Corona FreeType import](https://github.com/coronalabs/submodule-freetype) | `external/freetype-2.9` gitlink | `NOASSERTION` for pinned license alternatives |
| MetalANGLE / original contributors | [coronalabs/metalangle](https://github.com/coronalabs/metalangle), branch `Solar2D-Changes-Reverted` | `external/MetalANGLE` gitlink | `NOASSERTION` for pinned mixed contents |
| Live libraries / Corona Labs contributors | [coronalabs/submodule-live-libs](https://github.com/coronalabs/submodule-live-libs) | `external/live-libs` gitlink | `NOASSERTION` |
| Plugin build support / Corona Labs contributors | [submodule-plugins-build](https://github.com/coronalabs/submodule-plugins-build), [submodule-plugins-build-core](https://github.com/coronalabs/submodule-plugins-build-core) | `plugins/build`, `plugins/build-core` gitlinks | `NOASSERTION` for individual submodules |
| Game network, licensing, network plugins / Corona Labs contributors | [submodule-plugins-gameNetwork](https://github.com/coronalabs/submodule-plugins-gameNetwork), [submodule-plugins-licensing](https://github.com/coronalabs/submodule-plugins-licensing), [submodule-plugins-network](https://github.com/coronalabs/submodule-plugins-network) | `plugins/gameNetwork`, `plugins/licensing`, `plugins/network` gitlinks | `NOASSERTION` for individual submodules |
| Welcome screen and native integration / Corona Labs contributors | [submodule-welcomescreen](https://github.com/coronalabs/submodule-welcomescreen), [submodule-native](https://github.com/coronalabs/submodule-native) | `simulator-extensions/welcomescreen`, `subrepos/enterprise` gitlinks | `NOASSERTION` for individual submodules |
| Lua framework modules / Corona Labs contributors | [framework-easing](https://github.com/coronalabs/framework-easing), [framework-transition](https://github.com/coronalabs/framework-transition), [framework-widget](https://github.com/coronalabs/framework-widget), [framework-timer](https://github.com/coronalabs/framework-timer), [framework-composer](https://github.com/coronalabs/framework-composer) | `subrepos/easing`, `transition`, `widget`, `timer`, `composer` | `NOASSERTION` for individual submodules |

### Local engine dependency builds

- **Upstream:** each dependency's retained source at
  `C:\gitdev\tools\solar2d-win64-deps`; original project URLs and revisions are
  recorded by those source checkouts/build inputs where available.
- **Fork/import date:** unknown; these are dependency workspaces, not an established
  additional Nexus fork. The engine's September 30 Win64 work is not evidence of
  every dependency's acquisition date.
- **Our location/status:** Engine's local Win64 build support, outside its repository,
  including `openssl-3.5.9`, `libevent-2.1.13`, `mDNSResponder-1557`, `shaderc`, and
  `vcpkg`; built artifacts under `C:\gitdev\tools\solar2d-win64`.
- **Credit/SPDX:** contributors named in each retained LICENSE; OpenSSL 3 is
  `Apache-2.0`. `NOASSERTION` for a combined dependency-workspace expression.
  Shaderc's bundled glslang/SPIRV-Tools and other nested dependencies have separate
  notices; downloaded tools are not relicensed by the engine's MIT license.

## Lab projects and assets

### StarExplorer

- **Credit:** Kevin Collins for the game and Nexus plugin integration; external asset
  contributors below retain their own credit.
- **Original location:** `C:\newdev\StarExplorer`, with the recovered Nexus2D plugin
  proof from **2026-10-02**. This is Nexus-authored work, not an upstream engine fork.
- **Fork/import date:** imported into Lab **2026-10-10**, `8ad0695`.
- **Our location/status:** Lab `StarExplorer`; maintained example project, with reusable
  plugin support in Packages `solar2d` and Engine. The full recovered proof archive
  is `C:\backup\Nexus2DPluginProof-20261010.zip`.
- **SPDX:** no single license asserted for the combined source and assets. Nexus
  source and each external asset retain separate terms.

Every StarExplorer asset row below has **unknown original acquisition date** and
**Lab import 2026-10-10, `8ad0695`**. Paths are relative to Lab `StarExplorer`.

| Material / credit | Original location | Our location / status | Upstream SPDX |
| --- | --- | --- | --- |
| Corona skybox / Ulukai (Jonathan Denil) | Origin URL not recorded; original `graphics/backgrounds/readme.txt` | `graphics/backgrounds`; retained skybox and author notice | `CC-BY-SA-3.0` |
| Red Eclipse skybox / Ulukai; eclipse photo by Luc Viatour, modified by Dratz-C | [Solar eclipse photograph](https://en.wikipedia.org/wiki/File:Solar_eclips_1999_4.jpg); background readme | Historical asset credited in retained readme; Red Eclipse images were excluded from cleaned sample | `CC-BY-SA-3.0` as recorded in supplied notice |
| Spacescape / Alex Peterson | [Spacescape](https://www.alexcpeterson.com/spacescape/), version 0.3 named in skybox readme | External authoring tool used by upstream skybox artist, no Nexus source import | `MIT` for tool, not the generated skybox's license |
| Hologram pack / author not identified in supplied readme | Original download URL unknown | `graphics/hologram/Readme.txt` and assets; retained | `NOASSERTION` |
| Elianto font / author not established from retained files | Original download URL unknown | `fonts/Elianto`; retained | `NOASSERTION` |
| Music and sound effects / contributors not established from retained notices | Original download URLs unknown | `audio`, including `80s-Space-Game_Looping.wav`, `leonell-cassio-the-sapphire-city-10450.mp3`, `fire.wav`, `ScifiTactics`; filenames alone do not establish credit or permission | `NOASSERTION` |
| Remaining art / contributors not established from retained notices | Original download URLs unknown | `graphics/background`, `Buttons`, `Ship_Parts`, `Ship_Shop`, `spaceobjects`, standalone JPEGs; retained | `NOASSERTION` |

### Rogue asset collections

Both collections below have **unknown original acquisition/fork dates**; their
current Lab paths are recorded by **2026-06-06**, `4050dc2`.

| Collection | Original location | Our repository/location | Credit and upstream SPDX |
| --- | --- | --- | --- |
| SRPG Studio Community Asset Project 1.3 | SSCAP Discord project; specific repository/download URL absent from supplied readme | Lab `rogue/graphics/sscap`; retained `readme.html` | `CC-BY-3.0`; detailed contributors below |
| Time Fantasy first Original Character Contest winner pack | [Time Fantasy](http://www.rpgmakerweb.com/a/rpg-maker-vxace-character/time-fantasy), [contest winners](https://forums.rpgmakerweb.com/index.php?threads/original-character-contest-winners.94745/) | Lab `rogue/graphics/time-fantasy-1st-occ-winner-pack`; retained `README.txt` | Jason Perry and the original contest character designers; `NOASSERTION` because the supplied promotional readme does not state license terms |

SSCAP **artists:** Briver, Soviet, General Ciraxis, Kennedy, Yeedley / CardCafe
(concept art), Deluka. **Sponsors:** MarkyJoe, Von Ithipathachai, Soviet, Kennedy,
PurpleManDown, Jedicars. **Special thanks:** Repeat, Dustyeg, SavageAran, Seityr,
Avraxas, 2chang, Alistiel / Viteri, AmBrosiac, Eclogia, Expa, Fencer, Hex, Robinco.

### DejaVu fonts in SwarmNX

- **Credit:** Bitstream, Inc.; DejaVu contributors; Tavmjong Bah for Arev glyphs.
- **Upstream:** [DejaVu fonts](https://dejavu-fonts.github.io/), derived from Bitstream
  Vera with Arev contributions as stated in the supplied license.
- **Fork/import date:** original acquisition unknown; Lab record **2026-06-17**, `ea2eac4`.
- **Our location/status:** Lab `SwarmNX/resources`; retained fonts and `LICENSE`.
- **SPDX:** `Bitstream-Vera AND LicenseRef-Arev-Fonts` for the supplied notices;
  DejaVu changes are stated to be public domain in the same file. See the complete
  notice for font naming and redistribution terms.

## Custom license references and unresolved records

These references point to the actual retained declarations; they do not create new
permissions or substitute a familiar SPDX license for a different grant.

| Local identifier | Definition / retained text |
| --- | --- |
| `LicenseRef-AGG-2.4` | Permission to copy, use, modify, sell, and distribute with the copyright notice, plus an as-is disclaimer, in Packages `gui/external/fpgui/framework/src/main/pascal/corelib/render/software/agg_basics.pas`; Maxim Shemanarev and Milan Marusinec, AGG/AggPas 2.4 RM3. |
| `LicenseRef-GPC-Noncommercial` | Packages `gui/external/fpgui/extras/aggpas/gpc/copying.txt`: General Polygon Clipper 2.31, Alan Murta / University of Manchester, 1997–1999; noncommercial permission with a separate-consent condition for commercial use. |
| `LicenseRef-LZMA-SDK-Public-Domain` | Public-domain declarations in External `compression/abbrevia/external/abbrevia/thirdparty/lzma` source headers and `thirdparty/ppmd/readme.txt`; Igor Pavlov / 7-Zip SDK. This is not automatically `CC0-1.0` or `Unlicense`. |
| `LicenseRef-Apple-Sample-Code` | Apple Source Examples block in Engine `sdk/dmg/Corona3rdPartyLicenses.txt`; preserve that supplied grant and disclaimer. |
| `LicenseRef-Omni-Source` | Omni Source License block in the same Engine notice payload, associated with Simple-NSAlert-with-Blocks. |
| `LicenseRef-Arev-Fonts` | Arev Fonts Copyright section of Lab `SwarmNX/resources/LICENSE`, copyright 2006 Tavmjong Bah. |

Open provenance work is deliberately visible: unknown original fork/acquisition dates;
individual fpGUI extras and Engine submodule license mappings; exact inherited editor
component revisions; undocumented StarExplorer assets and Time Fantasy terms; missing
local WavPack `license.txt` referenced by its header. The skybox readme also references
`cc-by-sa.txt`, absent from the cleaned asset directory. Its stated license is recorded
above, and the original readme is preserved. No missing text has been silently replaced
with guessed terms, and no undocumented asset is labeled as Nexus-owned material.

## Consolidated records

On 2026-10-10, the following Nexus-maintained prose was consolidated here. Original
source, licenses, author lists, upstream READMEs, and asset notices were not edited.

| Former record | Canonical section / treatment |
| --- | --- |
| Nexus `docs/attribution.md` | The documentation site includes this root file; it keeps no separate attribution prose. |
| Packages `gui/doc/ATTRIBUTION.md` | GUI foundations, historical SimpleGUI/SDL use, and Nexus authorship above; duplicate removed. |
| Packages `gui/external/vtv/NEXUS-UPSTREAM.md` | Virtual TreeView revision, date, provenance, and adaptation details above; duplicate removed. |
| External `mustache/external/dmustache/NEXUS_PATCHES.md` | DMustache/SynPDF provenance and missing-include correction above; duplicate removed. |
| Nexus-authored Abbrevia, PasZLib, DMustache, TRegExpr, OpenSSL, and VTV README provenance paragraphs | Replaced by links here; usage, build, and validation documentation stays with each package. |

Pre-consolidation documentation and the verification manifest are retained locally at
`C:\backup\Attributions-20261010`. Git history remains the durable record of the edits.


## Centralized Nexus examples

On **2026-10-16**, 1,926 existing example files were relocated to Lab
`examples/`, organized by Nexus capability. Another 15 production Forge
templates/shared build modules moved within Nexus to `projects/forge/templates`.
Every original file was SHA-256 checked after copying and before its old copy
was removed. This is a relocation, not a new upstream fork or a license change.
Test-only fixtures remain with their tests. Original import dates and historical
paths in the preceding entries remain part of the record.

The source revisions below identify the local material at relocation. The
preceding component entries supply original upstream URLs, credited authors,
original import evidence and individual license expressions. The imported
source headers, asset notices and consumed metadata remain with the material;
ancestor license, copyright, author and notice files were also copied into the
destination collections' `notices/` directories.

| Supplier / credited authors | Verified source revision | Original source / current Lab location | SPDX / attribution context |
| --- | --- | --- | --- |
| [Nexus](https://github.com/nxrp-dev/nexus) / Kevin Collins | `f158194650bb` | Tool `projects/*/examples`, example BotHost configurations and `tools/workspace-index/example` → `examples/{build,packages,deployment,automation,data,workspace}` | `MPL-2.0-no-copyleft-exception`, retained file headers |
| [Nexus Packages](https://github.com/nxrp-dev/nexus-packages) / Nexus, FPC, fpGUI and AggPas authors credited above | `4ac014d0d126` | JSON/XML/database/image/process, NexusUI, fpGUI/AggPas, OpenSSL/XMPP and Solar2D examples → `examples/{data,graphics,system,gui,network,mobile}` | Mixed collection; preceding FPC, fpGUI, AggPas, OpenSSL and Lua entries and per-file notices apply |
| [Nexus External Packages](https://github.com/nxrp-dev/nexus-packages-ext) / TRegExpr and Pascal zlib contributors credited above | `ebb7f0dc8e88` | `regexpr/external/tregexpr/examples` → `examples/text/regular-expressions`; `compression/paszlib/external/paszlib/examples` → `examples/data/compression/paszlib-external` (retired duplicate; canonical examples now in `examples/data/compression/paszlib`) | Existing TRegExpr and Pascal zlib attribution and retained notices apply |
| [NexusFPC](https://github.com/nxrp-dev/nexus-fpc) / Free Pascal contributors and Nexus package-example authors | `2400de82f87d` | `examples/dynamic-packages` → `examples/packages/runtime-loading`; package examples → `examples/{runtime,data,graphics,text,system,network}` | FPC's component-specific `GPL-2.0-or-later` / LGPL with independent-module exception terms and Pascal JPEG notices remain authoritative; no single expression asserted for all examples |
| [Nexus Mobile](https://github.com/nxrp-dev/nexus-mobile) / Corona, Solar2D and the inherited component authors above | `3f303e61d4b6` | Android/iOS native samples and vendored MPG123, Sundown, ALmixer, Vorbis, earlier OpenAL, LuaSQLite3, zlib, ANGLE and YRK progress demos → `examples/{mobile,audio,text,data,graphics,gui}` | Mixed inherited collection; Engine component table, source/asset notices and copied distribution licenses apply |
| [Corona native samples](https://github.com/coronalabs/submodule-native) / Corona Labs, Solar2D and contributors | `8c668a18404e` | Engine `subrepos/enterprise/contents/Samples` → `examples/mobile/native` | `MIT` / individual source and asset notices; original adoption unknown, existing submodule revision is relocation evidence |
| [OpenAL Soft](https://github.com/coronalabs/openal-soft) / Chris Robinson and contributors | `89a62f015362` | Engine `external/openal-soft/examples` → `examples/audio/openal` | Existing OpenAL entry and source-specific notices, including example terms, apply |
| [MetalANGLE](https://github.com/coronalabs/metalangle) / ANGLE, MetalANGLE and Chromium contributors | `acb3ae751239` | Engine `external/MetalANGLE/samples` and iOS samples (including `ios/xcode/MGLPaint`) → `examples/graphics/{metalangle,metalangle-ios}` | `BSD-3-Clause` foundation with retained individual notices; inherited Engine component attribution applies |
| [SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross) / Khronos and SPIRV-Cross contributors | `f38cbeb814c7` | MetalANGLE `third_party/spirv-cross/src/samples` → `examples/graphics/spirv` | `Apache-2.0`, copied `LICENSE` and source headers; original adoption unknown, nested repository revision is relocation evidence |
| [LuaSocket](https://github.com/coronalabs/submodule-luasocket) / Diego Nehab and contributors | `c7566c83d0ef` | Engine `external/luasocket/samples` → `examples/network/lua-sockets` | `MIT`, existing LuaSocket attribution and copied notices |

In particular, the unchanged DejaVu LGC Sans example font and its license now
live at Lab `examples/graphics/images/DejaVuLGCSans.ttf` and
`examples/graphics/images/DejaVuLGCSans.LICENSE.txt`; the earlier image-package
entry records their original provenance. The runtime packages and compiler
remain in their owning repositories and are consumed from the examples.


## RTL-extra reduction and retained test fixtures

On **2026-10-17**, NexusFPC `rtl-extra` was reduced from the source at
`bfd5d2156b01f1213b3fa16e3b3fde38588c9d5d`. The inherited material comes from
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source); the original
fork date remains unknown. Networking and locale sources retain their original
headers and component-specific license terms. No new blanket license is asserted.

`SortAlgs`, credited to the Free Pascal development team (1999-2019), and its
namespace wrapper moved byte for byte into `packages/rtl-objpas`. The Borland /
Free Vision / FPC Objects implementation and its complete credit header remain
as the private `LegacyObjects` compiler-test fixture. The complex-operator
regression retains a small self-contained adaptation credited to Pierre Muller
and the Free Pascal development team (1999-2000), under its original
`COPYING.FPC` terms. The retired APIs remain attributable through the Git source
revision and untouched snapshot with SHA-256 hashes in
`/media/kcollins/dev/worktree/rtl-extra-cleanup-20261017-cil14_no`.

The Lab `rdjpgcom` example retains Thomas G. Lane's 1994-1995 copyright notice;
its old Objects stream use was replaced with Classes. Existing Pascal JPEG
notices and licenses remain authoritative. The reader now reports a missing
input file as an open failure instead of misidentifying it as non-JPEG data.

The unfinished Lab `wrjpgcom` writer example was retired with owner approval.
Thomas G. Lane's 1994-1997 credit and the complete original source remain
in `baseline/wrjpgcom.pas` within the same worktree snapshot (SHA-256
`7dea1bdaeedd37ffb188c05f42e7e4dc83103a00ed6eab423ce1c7baa156559f`).
The existing Pascal JPEG notices and licenses remain in place.

## Compiler dead-path reduction

On **2026-10-17**, unused compiler and RTL paths were reduced from NexusFPC
revision `00fb95dfe417ed7b7819f8414af9fb30c3735e61`. The inherited material comes from
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source); its original
fork date remains unknown. The removed `compiler/syscinfo.pas` credits Karoly
Balogh (2016) and declares `GPL-2.0-or-later`. The retired
`compiler/utils/fixnasm.pas` credits Peter Vreman (1998-2002) and refers to its
original `COPYING.FPC` terms; no replacement license is asserted. Both complete
original files, together with all other affected source headers, are preserved
under `/media/kcollins/dev/worktree/dead-code-cleanup-20261017-iu_ybf4h/baseline`,
with SHA-256 hashes and the source revision in `baseline.json`. Existing
compiler and RTL licenses remain authoritative for the surviving material.

The subsequent HeapTrc debug-dump repair updates a stale iterator reference
left by Free Pascal commit `3e473b45193dfbf812a8df16b887a0eb1e1ea916`,
credited to Rika Ichinose (2026-05-29). The original source header and RTL
license terms are retained. The exact source before this repair is preserved
in `/media/kcollins/dev/worktree/heaptrc-repair-20261017-oac2p6b2/heaptrc-before-repair.pas`.

On **2026-10-17**, the owner separately approved removal of parked `DUMMY`
compiler experiments from `compiler/optdfa.pas`, `compiler/x86/nx86add.pas`,
and `compiler/aarch64/cgcpu.pas`, based on revision `00fb95dfe417ed7b7819f8414af9fb30c3735e61`
plus the existing authorized working changes. These Free Pascal units retain
Florian Klaempfl's and Jonas Maebe's original credits and
`GPL-2.0-or-later` notices. Complete source snapshots and SHA-256 hashes before
this removal are preserved under
`/media/kcollins/dev/worktree/compiler-dummy-removal-20261017-7hdkueui/baseline`
and in its parent `baseline.json`. RTL compatibility guards and parser-test
uses of the same symbol were outside this removal.


On **2026-10-17**, the owner approved retiring the `DEBUG_PPU` diagnostic
logging in NexusFPC `compiler/entfile.pas` and `compiler/ppu.pas`, based on
revision `781383f296b0cf32954dcfeaca65b28560cbc09e`. The retained files preserve
the Free Pascal development team's (1998-2013) and Florian Klaempfl's
(1998-2002) original credits and `GPL-2.0-or-later` notices. Their inherited
source is covered by the preceding Free Pascal provenance entry; the original
fork date remains unknown. Complete originals, source revision and SHA-256
hashes are preserved under
`/media/kcollins/dev/worktree/debug-ppu-removal-20261017-sgwcbl4w/baseline`
and its parent `baseline.json`. This retires logging only; the serialized
unit/package formats and checksum logic remain in place.


On **2026-10-17**, the owner approved retiring NexusFPC's `SUPPORT_MMX`
array-arithmetic extension, its directives, helpers and dependent copy
optimization. The baseline is revision `781383f296b0cf32954dcfeaca65b28560cbc09e`
plus the previously validated `DEBUG_PPU` removal. The inherited implementation
comes from [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
with the Free Pascal development team and individual authors credited in the
25 affected source files. Their original copyright headers and component
`GPL-2.0-or-later` / `COPYING.FPC` notices remain with the retained files; no new
blanket license is asserted. The original fork/import date remains unknown.
Complete pre-removal files, SHA-256 hashes, exact patches and baseline compiler
identity are preserved under
`/media/kcollins/dev/worktree/support-mmx-retirement-20261017-enydd5t3`.
The separate RTL MMX implementation and assembler instruction definitions
remain active and retain their existing provenance.


## Nexus Mobile dependency vendoring

On **2026-10-17**, the owner approved converting all **21 direct and four nested
submodules** into ordinary files tracked by Nexus Mobile, based on parent
revision `50a17bdc3549d4c2cb1e260127b3afb8c73ccdbd`. This changes repository ownership of
file tracking, not the inherited source licenses. The earlier Mobile engine
component table's gitlink descriptions are historical after this conversion.
Original upstream adoption/fork dates remain unknown.

The import preserves current local edits, 351 existing deletions, file modes,
symlinks, source headers, license texts and distribution notices. Complete Git
metadata and working contents before conversion are backed up at
`/media/kcollins/dev/worktree/nexus-mobile-vendoring-20261017-wh7lio2b`,
with file hashes, source/index manifests, pending patches and exact revisions.
Git content for all retained source files is unchanged except the dependency
helper described below. Upstream Git histories are preserved in that backup;
the parent repository's existing history is retained without rewriting it.

Authors and license expressions remain as recorded in the Mobile engine table
above and in each retained source file. No blanket expression is asserted for
these mixed source trees. In particular, MetalANGLE's nested glslang sources
credit Google, 3Dlabs and other contributors under the multiple terms retained
in `third_party/glslang/src/LICENSE.txt` (`NOASSERTION` for the combined tree).
The JsonCpp wrapper and source retain Baptiste Lepilleur's / The JsonCpp Authors'
credits, MIT terms and public-domain disclaimers in their `LICENSE` files;
the source also retains `AUTHORS`. SPIRV-Cross retains its `Apache-2.0` license
and Khronos / individual contributor credits. All nested paths below are
relative to `nexus-mobile/`.

| Vendored path | Original upstream repository | Pinned upstream revision |
| --- | --- | --- |
| `external/Box2D` | [submodule-box2d](https://github.com/coronalabs/submodule-box2d.git) | `96859f3a163ce78ccdbee2d17be9a00138c59fb5` |
| `external/CryptoPP` | [submodule-CryptoPP](https://github.com/coronalabs/submodule-CryptoPP.git) | `ca58f8e45df015bd0d5315e477f96389e80a3262` |
| `external/MetalANGLE` | [metalangle](https://github.com/coronalabs/metalangle.git) | `acb3ae751239f170c1ab596a37679fdfedeeaea7` |
| `external/MetalANGLE/third_party/glslang/src` | [external-metalangle-glslang](https://github.com/coronalabs/external-metalangle-glslang.git) | `7d65f09b83112c1ec9e29313cb9913ed2b850aa0` |
| `external/MetalANGLE/third_party/jsoncpp` | [external-metalangle-jsoncpp](https://github.com/coronalabs/external-metalangle-jsoncpp.git) | `2bb815de3c287b654a7d4743e9ad7b654221657b` |
| `external/MetalANGLE/third_party/jsoncpp/source` | [external-metalangle-jsoncpp-source](https://github.com/coronalabs/external-metalangle-jsoncpp-source.git) | `645250b6690785be60ab6780ce4b58698d884d11` |
| `external/MetalANGLE/third_party/spirv-cross/src` | [external-metalangle-SPIRV-Cross](https://github.com/coronalabs/external-metalangle-SPIRV-Cross.git) | `f38cbeb814c73510b85697adbe5e894f9eac978f` |
| `external/freetype-2.9` | [submodule-freetype](https://github.com/coronalabs/submodule-freetype.git) | `6585cb0203dfe53f7aad7eda3aff4117e7483921` |
| `external/live-libs` | [submodule-live-libs](https://github.com/coronalabs/submodule-live-libs.git) | `4ba6208930c44f1e80738bc37b1d1c5fff05f2eb` |
| `external/luafilesystem` | [submodule-lfs](https://github.com/coronalabs/submodule-lfs.git) | `e7661591ca3a355f763ddd842da1ffa3d810f27c` |
| `external/luasocket` | [submodule-luasocket](https://github.com/coronalabs/submodule-luasocket.git) | `c7566c83d0ef097283d37334d71f6b58b764750f` |
| `external/openal-soft` | [openal-soft](https://github.com/coronalabs/openal-soft.git) | `89a62f0153623ac0fbf74edad66b0fed72d3dc5a` |
| `external/openal-soft_apportable` | [submodule-openal-soft_apportable](https://github.com/coronalabs/submodule-openal-soft_apportable.git) | `3550b1f2f9f6de0b2915b77452ea9e4955efba2b` |
| `plugins/build` | [submodule-plugins-build](https://github.com/coronalabs/submodule-plugins-build.git) | `cf10f7da90754ce84d2d09256ba37e989401b889` |
| `plugins/build-core` | [submodule-plugins-build-core](https://github.com/coronalabs/submodule-plugins-build-core.git) | `75f8814b8bc7960fc23df3a14690e6d247413339` |
| `plugins/gameNetwork` | [submodule-plugins-gameNetwork](https://github.com/coronalabs/submodule-plugins-gameNetwork.git) | `8686798c99e3ab69971307367864771c48824fc4` |
| `plugins/licensing` | [submodule-plugins-licensing](https://github.com/coronalabs/submodule-plugins-licensing) | `50fb7815e9beeed2d637340db9f65f4c0e43021a` |
| `plugins/network` | [submodule-plugins-network](https://github.com/coronalabs/submodule-plugins-network) | `5ee2e55e5fb4f5adaf9ed99b8102adeb545d72f5` |
| `simulator-extensions/welcomescreen` | [submodule-welcomescreen](https://github.com/coronalabs/submodule-welcomescreen.git) | `9c02f00d1d9bcdf1b83950d3452ef813ee1c02d1` |
| `subrepos/composer` | [framework-composer](https://github.com/coronalabs/framework-composer.git) | `aef2ec0fc3471d179a5b3c8d8b18599d380522fa` |
| `subrepos/easing` | [framework-easing](https://github.com/coronalabs/framework-easing.git) | `f44f1c1f5736f8892ab1cb610560bf5e130cea13` |
| `subrepos/enterprise` | [submodule-native](https://github.com/coronalabs/submodule-native.git) | `8c668a18404e6071de73c88bac5b7b9360967694` |
| `subrepos/timer` | [framework-timer](https://github.com/coronalabs/framework-timer.git) | `7572d05d54484f802023758ff5374aa225f461bf` |
| `subrepos/transition` | [framework-transition](https://github.com/coronalabs/framework-transition.git) | `a58163b2b7e8ffdc06112db6d89f4b65d79262f0` |
| `subrepos/widget` | [framework-widget](https://github.com/coronalabs/framework-widget.git) | `d425ae72f47b29a3da5880eebcb1111f2cdf6cd2` |

The owner-authorized integration change replaces MetalANGLE's destructive
`ios/xcode/fetchDependencies.sh` download/reclone behavior with checks for these
checked-in sources. Its ANGLE Project Authors copyright and BSD notice remain;
the new work is also credited to Kevin Collins (2026). Attribute boundaries in
the JsonCpp wrapper and SPIRV-Cross source preserve their original byte-oriented
Git defaults instead of inheriting MetalANGLE's text normalization. Clone
instructions now point to the Nexus repository without submodule initialization.


## NexusFPC FPUSOFT cleanup

On **2026-10-17**, the owner approved removing the unreachable `FPUSOFT`
checks, commented x86 software-FPU entries, and the unused software-FPU entry
in the generic utility CPU descriptor. The baseline is NexusFPC revision
`9dec5243be` (the full revision and original file hashes are saved in
`baseline.json` below). The inherited code comes from
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source); upstream
authors and original GPL / RTL `COPYING.FPC` notices remain with the retained
files. Original fork/import dates remain unknown; the preceding Free Pascal
provenance records continue to apply. The 11 original files, exact patch,
validation commands and artifact comparisons are preserved under
`/media/kcollins/dev/worktree/fpusoft-cleanup-20261017-7f5k1mzo`.
`FPUNONE` support and the separate softfloat calling conventions remain active.


## NexusFPC FPUNONE retirement and Currency reader correction

On **2026-10-17**, the owner approved retiring the selectable no-floating-point
configuration and its `FPUNONE` / `FPU_NONE` branches in NexusFPC. This follows
the earlier FPUSOFT cleanup; that entry's statement retaining FPUNONE is now
historical. The baseline is revision
`9dec5243bef0552d346f22005e3ac3e06ad8185e` plus the preserved FPUSOFT cleanup.
The inherited code comes from
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source), with the Free
Pascal development team and individual authors credited in the retained files.
Their original `GPL-2.0-or-later` compiler notices and RTL/package
`COPYING.FPC` library-license/linking-exception notices remain unchanged. No
new blanket license is asserted. Original upstream fork/import dates remain
unknown; preceding Free Pascal provenance entries continue to apply.

The owner separately approved correcting `TBinaryObjectReader.ReadCurrency`
to assign its raw 64-bit payload to the QWord overlay field. The unchanged
baseline reproduces the extra Currency scaling; the isolated correction and
zero, signed-fraction and storage-boundary regressions are preserved. New
regressions are Copyright (c) 2026 Kevin Collins,
`MPL-2.0-no-copyleft-exception`. Original files and hashes, branch decisions,
patches, bootstrap identities, test logs and artifact analysis are under
`/media/kcollins/dev/worktree/fpunone-retirement-20261017-_pulziuj`. The internal
`fpu_none` sentinel remains for generic utilities and empty controller
descriptors; supported FPU ordinals and softfloat calling conventions remain
unchanged.


## NexusFPC XML node-dump retirement

On **2026-10-17**, the owner approved removing the compiler's optional
`DEBUG_NODE_XML` exporter, including its node/type/procedure serialization,
XML escaping and module file state. The XML-only x86 and ARM assembler-node
subclasses and their registrations were also retired; the shared code-generation
node and ordinary `-vp` text diagnostics remain. The baseline is NexusFPC
revision `11990ef801c3de7022f7394f075f9566b31914a8`.

The inherited sources originate in
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source), under
`GPL-2.0-or-later`. Original file credits include Florian Klaempfl, Daniel
Mantione, Pierre Muller, Peter Vreman, Jonas Maebe, Blaise.ru, and J. Gareth
"Kit" Moreton; Moreton's 2024 notices accompany the two retired assembler-node
units in the preserved originals and Git history. All retained copyright and
license headers are unchanged. Original upstream fork/import dates remain
unknown; preceding Free Pascal provenance records continue to apply.

The 26 original compiler files and their SHA-256 hashes, removal patch,
bootstrap identity, validation commands and before/after artifact comparisons
are preserved under
`/media/kcollins/dev/worktree/node-xml-removal-20261017-380hxyup`.


## NexusFPC retired compiler scaffolding cleanup

On **2026-10-17**, the owner approved removing four inherited compiler features:
the abandoned `state_tracking` pass, the `USE_FAKE_SYSUTILS` / `FKSysUtl` fallback,
bare-metal controller tables and settings, and the unsupported Amiga syscall
procedure convention with its explicit parameter-location machinery. The baseline
is NexusFPC revision `187e411902eab39c79b6265c6272cd20a3372c34`.

The inherited implementation and message catalogs originate in
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source), under their
existing `GPL-2.0-or-later` compiler notices and the applicable original
`COPYING.FPC` notice for generic CPU metadata. Credits to the Free Pascal
development team and individual authors remain in every retained source header;
all catalog encodings and license/distribution notices are preserved. Original
fork/import dates remain unknown; preceding Free Pascal provenance records
continue to apply. No new blanket license is asserted.

NXU long compatibility revision 46 identifies the changed tokens, procedure
option sets and generic settings. Retained public RTTI calling-convention values
and native CPU syscall instructions are unchanged. The existing owner-copyrighted
SYSCALL regression now checks ordinary unknown-directive handling.

The untouched compiler/build/test source archive, SHA-256 records, changed-file
originals, exact patch, bootstrap identities, validation commands, logs and
artifact comparisons are preserved under
`/media/kcollins/dev/worktree/compiler-four-cleanups-20261017-lfa346e2`.


## NexusFPC dormant compiler modes and maintenance-tool retirement

On **2026-10-17**, the owner approved removing the dormant `gpc_mode`,
`PREPROCWRITE` and `DEBUG_GENERATE_INTERFACE_PPU` features, the unused
`Unix2AmigaPath` shim, MPW enum entries, the `USEEXCEPT` define and obsolete LLVM
conditionals, and the four maintenance utilities `fixlog`, `fixtab`, `fixmsg`
and `dummyas` from sibling `nexus-fpc/compiler`. The baseline is NexusFPC
revision `4ea76abb78d001de8a5fd94f94c0aa76ae94350f`.

The inherited sources and message catalogs originate in
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source). Retained
compiler headers preserve their existing `GPL-2.0-or-later` notices and credits
to Florian Klaempfl, Pierre Muller, Peter Vreman, Jonas Maebe and the Free Pascal
development team. The retired `fixlog` credits Peter Vreman (1998–2002),
`fixtab` credits Peter Vreman (1999–2002), and `dummyas` credits Pierre Muller
(2007). The `fixlog` and `dummyas` sources refer to `COPYING.FPC`; those exact
notices and the distribution license files are preserved in the source archive.
`fixmsg` has no individual author/license header. No new blanket license is
asserted for these historical helpers. Original fork/import dates remain
unknown; preceding Free Pascal provenance records continue to apply.

The lowercase `-m` no-op is retired with preprocessing output. Ordinary
language modes, macro processing, unit CRC tracking and NXU tools remain;
NXU compatibility revision 46 is unchanged. Original catalog encodings and all
retained copyright/license headers remain unchanged.

The untouched source archive, original files and SHA-256 hashes, removal patch,
bootstrap identities, validation commands, logs and artifact comparisons are
preserved under
`/media/kcollins/dev/worktree/compiler-five-cleanups-20261017-lz31ef87`.


## NexusFPC orphaned Mach-O units and unsupported metadata retirement

On **2026-10-17**, the owner approved removing the orphaned sibling
`nexus-fpc/compiler/macho.pas` and `machoutils.pas` units, the ineffective
`-XV` VLink selector, 27 unsupported ABI descriptors and their PowerPC/EABI
branches, nine unregistered assembler modes, and orphaned target/compiler
switches and application kinds. The baseline is NexusFPC revision
`0f60ce9c1bfd30e56fd6d5246a8ed46077f9990a`.

The inherited sources originate in
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source).
`compiler/macho.pas` preserves the Apple Inc. 1999–2008 notice under
`APSL-2.0`, including its full original license header, and credits Dmitry
Boyarintsev for the 2009 Pascal conversion. `compiler/machoutils.pas` credits
Dmitry Boyarintsev (2009–2010) under `GPL-2.0-or-later`. The other retained
compiler source headers preserve their existing `GPL-2.0-or-later` notices and
credits to the Free Pascal development team and individual authors. Original
fork/import dates remain unknown; preceding Free Pascal provenance records
continue to apply. No license or original notice has been rewritten.

Retained serialized switch and assembler-mode ordinals and set widths are
preserved; NXU compatibility revision 46 is unchanged. The remaining ABI and
application enums are internal compiler metadata. Existing catalog encodings
are preserved. The unrelated X11 working-tree removals predate this cleanup.

The untouched source archive, original files with exact Apple/GPL notices,
SHA-256 hashes, enum-value records, removal patch, bootstrap identities,
validation scripts, logs and before/after artifact analysis are preserved under
`/media/kcollins/dev/worktree/obsolete-compiler-metadata-20261017-1zsteua6`.


## NexusFPC legacy GDB build-wrapper retirement

On **2026-10-17**, the owner approved removing the standalone
`nexus-fpc/compiler/utils/gppc386.pas` program (`fpc_with_gdb`) and its exclusive
support: the wrapper README entry/cross-reference, generated-command-file and
executable ignore entries, and its breakpoint rationale in the compiler status
comment. No separate wrapper-only compiler or RTL implementation was found.
Shared error counting and runtime-error handling remain in use.

The 246-line utility credits **Pierre Muller (2000–2002)** and originates in
[Free Pascal source](https://gitlab.com/freepascal.org/fpc/source), under
`GPL-2.0-or-later`. The retained NexusFPC source reference before this retirement
is `0f60ce9c1bfd30e56fd6d5246a8ed46077f9990a`. Original upstream fork/import dates remain unknown;
preceding Free Pascal provenance records continue to apply. The exact original
source, copyright/license header and distribution license files are preserved
under `/media/kcollins/dev/worktree/gdb-wrapper-retirement-20261017-pa1fkjjs`, together with hashes, the patch and reference audit.

### Unix users

- **Credit:** Michael van Canneyt, Marco van de Voort and the Free Pascal development team, as credited by the restored package metadata.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source).
  Original fork/import date is unknown; the general Free Pascal record above
  identifies the earliest locally available history.
- **Relocation date/evidence:** **2026-10-18**, NexusFPC
  `4f78c6c072c538cb2514a0a8226d53bca982cdf0:packages/users`, Git tree
  `82f01255f9d6e3d32da06dc6c63c6dfb5c310cb1`. Original file SHA-256 values are recorded
  in Packages `users/review/baseline-hashes.json`; untouched source remains in
  Git and the external relocation worktree.
- **Our location/status:** maintained Nexus Packages `users`; the former
  compiler-side package directory is removed. Account/group lookup and Linux shadow-record bindings; the optional crypth binding uses the target system crypt library.
- **License:** `LGPL-2.1-only WITH Independent-modules-exception`. Original source notices and the inherited
  `COPYING.FPC` linking exception and LGPL `COPYING.txt` accompany the package.
  Nexus-authored build integration and direct nxtest tests identify their own
  `MPL-2.0-no-copyleft-exception` notices. The saved package review records
  baseline proofs, fixes, consumer validation and platform limits.

### Unix iconvenc

- **Credit:** Marco van de Voort (2000; inherited Lab demonstration 2008) and the Free Pascal development team.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source).
  Original fork/import date is unknown; the general Free Pascal record above
  identifies the earliest locally available history.
- **Relocation date/evidence:** **2026-10-18**, NexusFPC
  `4f78c6c072c538cb2514a0a8226d53bca982cdf0:packages/iconvenc`, Git tree
  `58e855095d9727570086c1ac78507cf55953f405`. Original file SHA-256 values are recorded
  in Packages `iconvenc/review/baseline-hashes.json`; untouched source remains in
  Git and the external relocation worktree.
- **Our location/status:** maintained Nexus Packages `iconvenc`; the former
  compiler-side package directory is removed. Native iconv declarations and conversion helpers; the original demonstration remains in Nexus Lab examples/text/encoding.
- **License:** `LGPL-2.1-only WITH Independent-modules-exception`. Original source notices and the inherited
  `COPYING.FPC` linking exception and LGPL `COPYING.txt` accompany the package.
  Nexus-authored build integration and direct nxtest tests identify their own
  `MPL-2.0-no-copyleft-exception` notices. The saved package review records
  baseline proofs, fixes, consumer validation and platform limits.

### Unix pthreads

- **Credit:** Michael Van Canneyt (1999-2000), Marco van de Voort (BSD port, 2000), Benjamin Rosseaux (Android modifications, 2017), and the Free Pascal development team. The preserved BSD header translation also credits Chris Provenzano (1993-1994) and John Birrell (1995-1998).
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source).
  Original fork/import date is unknown; the general Free Pascal record above
  identifies the earliest locally available history.
- **Relocation date/evidence:** **2026-10-18**, NexusFPC
  `4f78c6c072c538cb2514a0a8226d53bca982cdf0:packages/pthreads`, Git tree
  `3c3cf80eb217998e6238612af731d7bef81fc843`. Original file SHA-256 values are recorded
  in Packages `pthreads/review/baseline-hashes.json`; untouched source remains in
  Git and the external relocation worktree.
- **Our location/status:** maintained Nexus Packages `pthreads`; the former
  compiler-side package directory is removed. POSIX thread/synchronization bindings with Linux, Android and BSD platform selection. The embedded BSD notice retains its advertising and non-endorsement clauses; the dormant AIX include remains preserved without a support claim.
- **License:** `LGPL-2.1-only WITH Independent-modules-exception AND BSD-4-Clause`. Original source notices and the inherited
  `COPYING.FPC` linking exception and LGPL `COPYING.txt` accompany the package.
  Nexus-authored build integration and direct nxtest tests identify their own
  `MPL-2.0-no-copyleft-exception` notices. The saved package review records
  baseline proofs, fixes, consumer validation and platform limits.


### FCL Base

- **Credit:** Michael Van Canneyt, Sebastian Guenther, Florian Klaempfl and the
  Free Pascal development team; Vladimir Zhirov and the CSV contributors named
  in those headers; Ondrej Pokorny (IPC/single-instance support); José Mejuto
  (buffered file streams); Danny Milosavljevic (original ASCII85 code), and the
  other authors credited in the preserved unit headers. RTTI utilities retain
  their Delphi VCL Extensions/RX author notices. ASCII85 retains its references
  to Jeff Atwood's C# implementation and the original C implementation.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  `packages/fcl-base`. The local source baseline is NexusFPC
  `4f78c6c072c538cb2514a0a8226d53bca982cdf0`, with the current native nxtest
  migration and expression Boolean-text correction included. The exact upstream
  import revision and original fork date are not established by local history.
- **Fork/import evidence:** relocated **2026-10-18**, with all 133 inherited
  working-source files recorded in the destination's `review/baseline-hashes.json`.
  The untouched snapshot and before/after regression logs are outside the source
  tree under `/media/kcollins/dev/worktree/fcl-base-relocation`. The initial
  review was saved before implementation fixes.
- **Our location/status:** maintained at Nexus
  `packages/nexus-packages/fcl-base`, package `NXRP.FCLBase`; the former NexusFPC
  directory is removed. Existing examples remain centralized in Nexus Lab
  `examples/runtime/base`. Platform includes, namespace wrappers/map, text
  documentation and direct nxtest coverage remain with their owners. Contnrs
  is retained. Compiler bootstrap stages and general SysUtils Boolean conversion
  are unchanged.
- **SPDX:** the FPC library notice and supplied LGPL 2.1 text are recorded as
  `LGPL-2.1-only WITH Independent-modules-exception`; the explicit CSV headers
  additionally grant `LGPL-2.0-or-later WITH Independent-modules-exception`.
  ASCII85 preserves Danny Milosavljevic's explicit public-domain declaration
  (`LicenseRef-Ascii85-Public-Domain`) and its subsequent FPC library notices.
  Broader grants in individual headers are preserved. New Nexus integration and
  regression files use `MPL-2.0-no-copyleft-exception`.
- **Evidence/notices:** destination `COPYING.FPC`, `COPYING.txt`, original source
  headers, `CODE_REVIEW.md`, and `review/baseline-hashes.json`. Package docs link
  here instead of duplicating provenance.
