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
| FPC | [nxrp-dev/nexus-fpc](https://github.com/nxrp-dev/nexus-fpc) | `C:\gitdev\tools\nexus-fpc` |
| Pascal | [nxrp-dev/nexus-pascal](https://github.com/nxrp-dev/nexus-pascal) | `C:\gitdev\tools\nexus-pascal` |
| Engine | [nxrp-dev/nexus-mobile](https://github.com/nxrp-dev/nexus-mobile) | `C:\gitdev\Nexus2D` |
| Lab | [nxrp-dev/Rogue](https://github.com/nxrp-dev/Rogue) | `C:\gitdev\nexus-lab` |

The Engine and Lab repository names above are their verified current Git remotes;
their checkout names differ. This record does not rename them. Temporary compiler
validation checkouts and generated outputs inherit the provenance of their source
repository rather than constituting additional forks.

## Compiler, editor, and development foundations

### Free Pascal and NexusFPC

- **Credit:** Free Pascal development team and the contributors named in the retained
  compiler, RTL, package headers, and documentation.
- **Upstream:** [Free Pascal source](https://gitlab.com/freepascal.org/fpc/source),
  [project](https://www.freepascal.org/).
- **Fork/import date:** unknown. The locally available shallow history includes
  Nexus work on **2026-09-17**, `2a3622f8`; it cannot establish the original fork date.
- **Our location/status:** FPC repository; maintained compiler, runtime, and packages.
- **SPDX:** compiler `GPL-2.0-or-later`; RTL's LGPL 2.1 text and linking permission are
  recorded as `LGPL-2.1-only WITH Independent-modules-exception`, with any broader
  version grants in individual headers preserved. Packages have individual licenses;
  no blanket compiler license is applied to them.
- **Evidence/notices:** `compiler/COPYING.txt`, `rtl/COPYING.txt`, `rtl/COPYING.FPC`,
  `packages/COPYING.FPC`, individual source headers. SPDX explicitly identifies the
  [Independent Module Linking exception](https://spdx.org/licenses/Independent-modules-exception.html)
  with FPC's `COPYING.FPC`; do not invent an `FPC-exception` identifier.

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
| libffi / Anthony Green, Red Hat, Inc., and contributors | [libffi/libffi](https://github.com/libffi/libffi) | No fork; first use unknown | FPC `packages/libffi`; external native runtime, FPC binding has separate inherited terms | `MIT` for native libffi |

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
- **Preserved work:** all 627 imported files, original notices and Delphi material,
  NexusFPC corrections to 15 Pascal files, codec sources and bundled objects.
  Corrections cover compiler directives/units, streams and byte buffers, archive
  metadata, paths, TAR processing, CRT helpers, and WavPack helpers.
  The reproducible LLVM recipe is `compression/abbrevia/scripts/Build-AbbreviaLLVM.ps1`;
  operational build/validation details remain in that package's README.

Every codec below came through the same Abbrevia revision and import dates above.
Our repository is External; paths are under `compression/abbrevia/external/abbrevia`.

| Codec / credit | Original location | Our location / evidence | Upstream SPDX |
| --- | --- | --- | --- |
| bzip2 1.0.8 / Julian R. Seward | [sourceware.org/bzip2](https://sourceware.org/bzip2/) | `thirdparty/bzip2/LICENSE`, `readme.txt`, C files | `bzip2-1.0.6` (SPDX license name; code version is 1.0.8) |
| LZMA SDK 26.00 / Igor Pavlov | [7-Zip LZMA SDK](https://7-zip.org/sdk.html); `https://7-zip.org/a/lzma2600.7z` | `thirdparty/lzma`; public-domain source headers | `LicenseRef-LZMA-SDK-Public-Domain` |
| PPMd from 7-Zip SDK 26.0 / Igor Pavlov, PPMd authors credited in source | [7-Zip](https://7-zip.org/) | `thirdparty/ppmd/readme.txt` and source headers | `LicenseRef-LZMA-SDK-Public-Domain` |
| WavPack 5.90.0 / David Bryant | [dbry/WavPack](https://github.com/dbry/WavPack) | `thirdparty/wavpack`; BSD statement in `wavpack.h`; [upstream license](https://github.com/dbry/WavPack/blob/master/license.txt) | `BSD-3-Clause`; local header references `license.txt`, which is absent from this imported directory |

### PasZLib

- **Credit:** Jacques Nomssi Nzali; Free Pascal contributors to TZipper and other units.
- **Upstream:** `http://www.tu-chemnitz.de/~nomssi/paszlib.html`; Free Pascal
  `packages/paszlib`, imported through FPC revision
  `a7782c0f1291c1a7d6c90280a296a28e723b19f5`.
- **Fork/import date:** collective import **2026-10-09**, External `bc4775a`.
  Original FPC adoption predates this import; its date is unknown here.
- **Our location/status:** External `compression/paszlib/external/paszlib`;
  FPC also retains `packages/paszlib` for its own bootstrap/package work.
- **SPDX:** PasZLib core `Zlib`; FPC additions carry their individual FPC notices,
  with the LGPL text and `Independent-modules-exception` as applicable.
- **Evidence/notices:** upstream `readme.txt` legal section, `src/zipper.pp`,
  `COPYING.FPC`. Source, metadata, examples and fixtures were retained; package usage
  instructions remain in `compression/paszlib/README.md`.

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
  earlier use elsewhere is not established by this date.
- **Our location/status:** External `regexpr/external/tregexpr`; pinned upstream
  submodule, consumed directly by fpGUI.
- **SPDX:** `MIT` in `LICENSE.txt`; `src/regexpr.pas` retains additional alternative
  license notices. The MIT identifier does not remove those alternatives.

### Synapse

- **Credit:** Lukas Gebauer and contributors; `blcksock.pas` thanks Gregor Ibic and
  Intelicom for SSL inspiration.
- **Upstream:** [geby/synapse](https://github.com/geby/synapse).
- **Fork/import date:** original adoption unknown; collective import **2026-10-08**,
  Packages `8e95ff2`.
- **Our location/status:** Packages `network/external/synapse`; upstream submodule.
- **SPDX:** `BSD-3-Clause`, retained in source headers including `blcksock.pas`.

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

