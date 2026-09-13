# FPC Win64-to-Win32 Cross-Compilation Notes

## Purpose

This document records the complete investigation and successful construction of
a Free Pascal Win32 cross compiler on a Win64 host. The artifact was secondary;
the purpose was to identify the exact inputs, operations, and reproducible
procedure.

## Final conclusion

For Win64-to-Win32, the process is fundamentally:

1. Obtain the complete FPC source matching the bootstrap compiler version.
2. Have a working host FPC installation.
3. Supply the host, target, binutils, and destination parameters to one
   make crossinstall invocation.

Conceptually:

    FPC source
    + existing host FPC compiler
    + target-capable assembler and linker
    + make crossinstall parameters
    = installed cross compiler

Other targets may require target-specific binutils, system libraries, SDKs, or
runtime files. Win64-to-Win32 is especially simple because the GNU binutils
supplied with the existing FPC Windows installation already support both
64-bit and 32-bit Windows PE output.

## Why a compiler needs a compiler

FPC is written in Pascal. An existing FPC compiler must bootstrap the new
compiler:

    Existing Win64 ppcx64
            |
            v
    Build Win64-hosted ppcross386
            |
            v
    ppcross386 builds Win32 RTL, packages, and applications

The bootstrap compiler must be a supported version. In this experiment, both
the source and bootstrap compiler were FPC 3.2.2.

## Dependency roles

| Dependency | Responsibility |
| --- | --- |
| Existing FPC compiler | Bootstraps the new Pascal compiler. Here it was ppcx64.exe. |
| GNU Make | Orchestrates compiler passes, dependency order, RTL and package construction, and installation. |
| GNU binutils | Assemble and link generated target code. The principal programs are as and ld. |
| GDB | Debugs generated programs. It is not involved in constructing the cross compiler. |
| GCC | Does not bootstrap FPC. It may be needed by packages containing C code or targets requiring a C runtime/toolchain. |

### Origin of GNU binutils

GNU binutils originate from the upstream GNU Binutils project, not from FPC.
FPC distributes suitable compiled copies with its Windows installation. They
are the actual GNU command-line programs, not Pascal wrappers. FPC launches
them as external processes.

    as.exe       GNU assembler
    ld.exe       GNU linker
    ar.exe       static-library archive manager
    objdump.exe  object and executable inspector
    strip.exe    symbol stripping
    windres.exe  Windows resource compiler

The local programs reported GNU Binutils 2.28. The installed ld.exe supported
both i386pep and i386pe, allowing it to link both Win64 and Win32 PE formats.

Upstream reference: <https://sourceware.org/binutils/>

Using binutils does not impose its license on programs compiled with it. If
Nexus later redistributes its own binutils bundle, it must retain the applicable
license and notices and provide corresponding upstream source and local
changes. That is packaging work, not a restriction on Nexus programs.

License reference:
<https://www.gnu.org/licenses/gpl-faq.html#CanIUseGPLToolsForNF>

## FPC Makefile structure

FPC uses two related file forms:

    Makefile.fpc     maintained FPC build definition
          |
          | fpcmake
          v
    Makefile         generated GNU Make input

fpcmake does not generate Pascal source. With -r, it recursively reads existing
Makefile.fpc definitions and writes corresponding Makefile files.

The official FPC 3.2.2 source archive already contains 443 Makefile.fpc files
and 450 generated Makefile files. Running fpcmake after extracting an
unmodified official archive is therefore normally unnecessary. It is needed
when a Makefile.fpc has changed, generated Makefiles are missing, or a required
target is absent from the supplied Makefiles.

## What GNU Make and FPC each do

    GNU Make
      controls bootstrap passes, ordering, paths, and targets
            |
            v
    ppcx64 and ppcross386
      compile individual Pascal programs and units

This concerns construction of FPC itself. Ordinary Pascal applications may
invoke fpc directly, use Lazarus/lazbuild, or use PasBuild.

## Build versus install

crossall builds the cross compiler, target RTL, and target packages inside the
FPC source tree:

    source/compiler/ppcross386.exe
    source/rtl/units/i386-win32/...
    source/packages/fcl-base/units/i386-win32/...
    source/packages/rtl-objpas/units/i386-win32/...

crossinstall ensures those products are built and then copies them into a
coherent installation:

    install/
      bin/x86_64-win64/ppcross386.exe
      units/i386-win32/rtl/...
      units/i386-win32/fcl-base/...
      units/i386-win32/rtl-objpas/...

Installation is not another compiler pass. It consolidates scattered build
products into a stable toolchain directory. Using the build tree directly
would couple the toolchain to the complete source tree and require consumers to
understand FPC's internal build layout.

## Why only crossinstall is needed

The FPC 3.2.2 Makefiles define crossall as a recursive make all with
CROSSINSTALL=1, and crossinstall as a recursive make install with
CROSSINSTALL=1.

The install target depends on the appropriate build stamp. If the compiler,
RTL, and packages have not been built, Make builds them before installing.
Command-line variables propagate through FPC's recursive Make invocations.

Therefore:

    fpcmake
    make crossall
    make crossinstall

normally reduces to:

    make crossinstall

crossall remains useful when a build without installation is specifically
wanted. An outer Nexus Makefile would currently wrap one Make invocation and
provide no real value.

## Exact successful experiment

All paths and times below are from September 12, 2026.

### Existing host tools

    Bootstrap compiler:
      C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe

    Tool directory:
      C:\lazarus\fpc\3.2.2\bin\x86_64-win64

The bootstrap compiler reported version 3.2.2, CPU x86_64, and OS win64.
The directory supplied GNU Make 3.80, fpcmake.exe, GNU Binutils 2.28, as.exe,
ld.exe, ar.exe, strip.exe, and objdump.exe.

### Official source

Source URL:
<https://downloads.freepascal.org/fpc/dist/3.2.2/source/fpc-3.2.2.source.zip>

Official source page:
<https://www.freepascal.org/down/source/sources-hungary.html>

    Local path:
      C:\gitdev\nexus\.tmp\fpc-win32-cross\fpc-3.2.2.source.zip

    Size:
      60,434,021 bytes

    Created:
      2026-09-12 14:53:59.739 PDT

    Modified:
      2026-09-12 14:55:38.885 PDT

    SHA-256:
      8418E9DC983DE4321250F8273840831B52C7B92FE365A93B59D0DC6DE2E8D720

Download:

    $lRoot = 'C:\gitdev\nexus\.tmp\fpc-win32-cross'
    New-Item -ItemType Directory -Force -Path $lRoot | Out-Null
    Invoke-WebRequest -Uri 'https://downloads.freepascal.org/fpc/dist/3.2.2/source/fpc-3.2.2.source.zip' -OutFile (Join-Path $lRoot 'fpc-3.2.2.source.zip')

Extraction:

    $lArchive = 'C:\gitdev\nexus\.tmp\fpc-win32-cross\fpc-3.2.2.source.zip'
    $lSourceRoot = 'C:\gitdev\nexus\.tmp\fpc-win32-cross\source'
    Expand-Archive -LiteralPath $lArchive -DestinationPath $lSourceRoot

Extracted source:

    C:\gitdev\nexus\.tmp\fpc-win32-cross\source\fpc-3.2.2

The archive and extracted tree both contained 18,956 files.

### Makefile generation performed during the experiment

Before it was established that the archive already contained generated
Makefiles, this was run from the extracted source root:

    C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpcmake.exe -Tall -r -w

It regenerated Makefiles recursively. This is not needed for the normal
reproduction procedure using the official, unmodified source archive.

One premature invocation occurred while extraction was incomplete and reported:

    Error: Directory "utils" not found

No build occurred from that attempt. Makefile generation completed normally
after extraction completed.

### First cross-build attempt and observed failure

Working directory:

    C:\gitdev\nexus\.tmp\fpc-win32-cross\source\fpc-3.2.2

Command:

    C:\lazarus\fpc\3.2.2\bin\x86_64-win64\make.exe crossall OS_TARGET=win32 CPU_TARGET=i386 PP=C:/lazarus/fpc/3.2.2/bin/x86_64-win64/ppcx64.exe CROSSBINDIR=C:/lazarus/fpc/3.2.2/bin/x86_64-win64 BINUTILSPREFIX=

Failure:

    Cross-compiling from systems without support for an 80 bit extended
    floating point type to i386 is not yet supported at this time

The Win64 bootstrap compiler does not expose the native 80-bit Extended
representation expected by i386. FPC already contains a software implementation
for this condition, enabled by FPC_SOFT_FPUX80. No source patch was needed.

### Successful build

    C:\lazarus\fpc\3.2.2\bin\x86_64-win64\make.exe crossall OS_TARGET=win32 CPU_TARGET=i386 PP=C:/lazarus/fpc/3.2.2/bin/x86_64-win64/ppcx64.exe CROSSBINDIR=C:/lazarus/fpc/3.2.2/bin/x86_64-win64 BINUTILSPREFIX= OPT=-dFPC_SOFT_FPUX80

Exit code: 0.

The build:

1. Ran the native compiler bootstrap cycle.
2. Built compiler/ppcross386.exe.
3. Invoked it with -Twin32 -Pi386.
4. Built the Win32 RTL.
5. Built the standard Win32 packages.
6. Wrote the i386-win32 build stamps.

There were non-fatal FPC source warnings, package circular-dependency warnings,
and notices about an undetermined libgcc path for packages that can bind
external C libraries.

### Isolated installation

    C:\lazarus\fpc\3.2.2\bin\x86_64-win64\make.exe crossinstall OS_TARGET=win32 CPU_TARGET=i386 PP=C:/lazarus/fpc/3.2.2/bin/x86_64-win64/ppcx64.exe CROSSBINDIR=C:/lazarus/fpc/3.2.2/bin/x86_64-win64 BINUTILSPREFIX= OPT=-dFPC_SOFT_FPUX80 INSTALL_PREFIX=C:/gitdev/nexus/.tmp/fpc-win32-cross/install

This installed 3,171 files beneath:

    C:\gitdev\nexus\.tmp\fpc-win32-cross\install

Important locations:

    install\bin\x86_64-win64\ppcross386.exe
    install\units\i386-win32\rtl\system.ppu
    install\units\i386-win32\...

Installed compiler:

    Size:      21,718,685 bytes
    Created:   2026-09-12 15:08:34.986 PDT
    Modified:  2026-09-12 15:06:05.000 PDT
    SHA-256:   7BEDE41C7C494584A44C2C3C75656073565B3281D7218F875E66F7233EEC3A6C
    Host PE:   pei-x86-64

Target query:

    ppcross386.exe -iV
    3.2.2

    ppcross386.exe -Twin32 -iTP
    i386

    ppcross386.exe -Twin32 -iTO
    win32

Without -Twin32, this CPU cross compiler defaults to Linux. The -Twin32 switch
is therefore an essential invocation input.

### End-to-end Win32 verification

Input:

    program Hello32;

    begin
      WriteLn('Win32 cross compiler works');
    end.

Compilation:

    $lCompiler = 'C:\gitdev\nexus\.tmp\fpc-win32-cross\install\bin\x86_64-win64\ppcross386.exe'
    $lUnits = 'C:\gitdev\nexus\.tmp\fpc-win32-cross\install\units\i386-win32\rtl'
    $lBinUtils = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64'
    $lVerify = 'C:\gitdev\nexus\.tmp\fpc-win32-cross\verify'
    & $lCompiler -n -Twin32 -Pi386 "-Fu$lUnits" "-FD$lBinUtils" "-FE$lVerify" "-FU$lVerify" (Join-Path $lVerify 'hello32.pas')

Argument meanings:

| Argument | Meaning |
| --- | --- |
| -n | Do not load an ambient fpc.cfg. |
| -Twin32 | Select the Win32 operating-system target. |
| -Pi386 | Select the i386 CPU target. |
| -Fu | Use the isolated Win32 RTL. |
| -FD | Find the assembler and linker in the existing FPC bin directory. |
| -FE | Place the executable in the verification directory. |
| -FU | Place generated units and objects in the verification directory. |

objdump reported:

    file format pei-i386
    architecture: i386

Running the executable printed:

    Win32 cross compiler works

    Size:      327,477 bytes
    Created:   2026-09-12 15:19:26.396 PDT
    SHA-256:   A8022B648EAAE407644543ADE9D2A4352C1F56D99189F6B3D0A3E66E3588FA99

## Minimal reproduction command

Given an extracted official FPC 3.2.2 source tree:

    C:\lazarus\fpc\3.2.2\bin\x86_64-win64\make.exe -C C:\path\to\fpc-3.2.2 crossinstall OS_TARGET=win32 CPU_TARGET=i386 PP=C:/lazarus/fpc/3.2.2/bin/x86_64-win64/ppcx64.exe CROSSBINDIR=C:/lazarus/fpc/3.2.2/bin/x86_64-win64 BINUTILSPREFIX= OPT=-dFPC_SOFT_FPUX80 INSTALL_PREFIX=C:/path/to/final/toolchain

| Parameter | Meaning |
| --- | --- |
| -C | Select the extracted FPC source directory. |
| crossinstall | Build missing target artifacts and install a coherent toolchain. |
| OS_TARGET=win32 | Target Windows rather than the compiler's default OS. |
| CPU_TARGET=i386 | Build an Intel 32-bit target compiler and units. |
| PP | Select the existing Win64 FPC bootstrap compiler. |
| CROSSBINDIR | Select the directory containing target-capable assembler and linker programs. |
| BINUTILSPREFIX= | Use the unprefixed as.exe and ld.exe names. |
| OPT=-dFPC_SOFT_FPUX80 | Enable FPC's existing software 80-bit floating-point support required for this host-to-i386 build. |
| INSTALL_PREFIX | Select the final isolated toolchain directory. |

## What was not changed

- No installed FPC or Lazarus files were modified.
- No FPC source patches were introduced.
- No new general build abstraction was created.
- The experiment remained beneath
  C:\gitdev\nexus\.tmp\fpc-win32-cross.

## Architectural implication

Nexus does not need to describe how to compile an FPC compiler internally.
FPC's Makefiles already own that knowledge. Nexus only needs to provide:

- FPC source location and version.
- Existing bootstrap compiler.
- Target operating system and CPU.
- Target-capable assembler/linker location and naming convention.
- Required FPC build options, such as FPC_SOFT_FPUX80.
- Final installation directory.

The execution mechanism can invoke FPC's existing crossinstall target with
those resolved values.
