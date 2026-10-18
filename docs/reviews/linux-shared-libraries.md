# Linux shared-library linking correction

Internal maintainer verification, 2026-10-17.

NexusFPC now preserves explicit Linux shared-library filenames. The live fpGUI
X11 and FreeType bindings use their supported runtime ABI names, so these
consumers build without unversioned development-library symlinks.

## Proven failures and corrections

The untouched NexusFPC source at
`6bca029dba0aebb0389c514d1574af4923af06f4` reproduced seven failures in ten
direct nxtest cases. The common linker removed the `lib` prefix, and the Linux
response writer then discarded `.so` and its version. A declaration such as
`external 'libX11.so.6'` consequently became `-lX11`.

This also allowed a request for an absent ABI to link successfully against an
unversioned library with a different ABI. The negative regression provides
`libnxmissing.so` with SONAME `libnxmissing.so.43`, requests
`libnxmissing.so.42`, and requires the exact missing-library diagnostic.

The correction preserves versioned `.so.*`, explicit `:filename`, and `.nxpl`
references before name normalization. Linux emits `-l:filename` for exact
searches and a quoted filename for explicit paths. Ordinary bare names retain
shared-library search and static-archive fallback. An unversioned exact filename
can be requested with `:filename`; the compiler does not guess the highest
installed ABI.

The affected bindings now request:

| Library | Linux ABI name |
| --- | --- |
| X11 | `libX11.so.6` |
| Xext | `libXext.so.6` |
| Xft | `libXft.so.2` |
| Xrender | `libXrender.so.1` |
| FreeType | `libfreetype.so.6` |

`packages/nexus-packages/graphics/x11/src/tpX11Libraries.pas` in Nexus owns the shared X11 constants,
with an `Api.X11.Libraries` namespaced wrapper. The used X11 bindings import
that definition directly. fpGUI's previously unnamed external functions now
identify their owning library. Redundant bare X11/Xext/Xft directives were
removed from this path. Both FCL Image's linked FreeType binding and fpGUI's
AGG binding now use the Linux runtime ABI name; FCL Image's dynamic binding
already used that name.

Original source notices remain intact. Provenance and the licenses of the
Nexus-authored additions are recorded in [ATTRIBUTIONS.md](../../ATTRIBUTIONS.md).

## Verification

| Check | Result |
| --- | --- |
| Untouched current compiler, matching RTL | 3 passed, 7 failed |
| Corrected final compiler, matching RTL | 10 passed, no failures, errors or skips |
| Linked FCL Image and AGG FreeType probes before binding corrections | Link failure requesting `-lfreetype` |
| Linked FreeType probes after correction | 2 passed; both initialize and release the real installed library |
| Native compiler generations 2 and 3 | Identical compiler SHA-256; all 90 RTL object files identical |
| fpGUI framework and IDE test programs | Both build with the installed corrected compiler/RTL |
| Both fpGUI ELF dependencies | All five ABI names above recorded in `DT_NEEDED` |
| Both fpGUI loader checks (`ldd -r`) | No missing libraries or undefined symbols |
| Removed internal-linker switch controls | Passed |
| Normal default-toolchain fpGUI framework recipe | Builds; ELF dependency and loader checks pass |
| Normal default-toolchain linker and font test recipes | 10 linker and 2 font tests pass |
| FCL Image package build and regression suite | Builds; 18 tests pass |
| PasJPEG regression suite | Builds; 13 tests pass |

The ten linker cases cover external declarations, linklib directives, a cached
NXU with its source hidden, explicit filename lookup, a filename without a
`lib` prefix, an explicit path containing spaces, bare names, static-archive
fallback, refusal to substitute another ABI, and an NXPL filename control.
Every positive executable is run and its ELF dependencies inspected. Versioned
fixtures provide no unversioned alias. The NXPL control checks filename handling;
it does not test runtime-package metadata.

Retained test sources and build recipes:

- NexusFPC: `tests/linker/NXSharedLibraryTests.nxproject` and its direct nxtest
  runner. Instructions are in `tests/linker/README.md`.
- fpGUI: `framework/src/test/pascal/NXLinuxFontLinkTests.nxproject` and its
  two direct nxtest cases.

## Installed toolchain

The native compiler was rebuilt through Forge in an isolated checkout, using
the existing NexusFPC compiler project and Forge operations. Compiler and RTL
generations were built together and checked before installation.

- Frozen source identity:
  `6bca029dba0aebb0389c514d1574af4923af06f4-work-a8da0e9ff4`.
- Source snapshot SHA-256:
  `a8da0e9ff4cf0a07786ae5d62db9d67137878d8b6856f0401797ac463bfe8c93`.
- Compiler SHA-256:
  `3fa47969de3a001467f3954a78b18d68f6daead0c88155549a613e0a209bcba0`.
- Installation:
  `/media/kcollins/dev/toolchain/nexus-fpc/x86_64-linux/6bca029dba-work-a8da0e9ff4`.

The Linux `current` symlink now selects this installation. The previous
`778927a6be-work-95622f1b76` installation remains available. The new installation
includes the matching native RTL and users units, plus `build-identity.json`.
The existing nxbuild environment continues to use its normal `current` paths.

The source checkout already used NXU format 45 while the previous installed
compiler used 44. Updating the default therefore requires rebuilding cached
units against the matching RTL; this linker correction itself adds no new NXU
format. Affected validation outputs were rebuilt from empty output directories.

## Evidence and limits

Local build logs, the untouched compiler and before-source copies, generated
probes, source identity, generation hashes, ELF inspection, and loader results
are under ignored `output/soname-fix`. Final compiler comparisons are in
`baseline-final-results.log` and `final-results.log`. Installed consumer checks
use the `final-` logs; ordinary default-toolchain recipe checks use `default-`.

Verification targets native x86_64 Linux with Clang/LLD. No development-library
symlinks or development packages were installed. Full GUI suites were not
executed; their validation stops at builds and loader resolution. Cross targets
and the release SDK matrix were not rebuilt. The compiler behavior change is restricted to the
Linux linker path; other platform binding names retain their previous values.
This work covers the active fpGUI dependency path, rather than an audit of every
optional or unused X11 binding in the repository.
