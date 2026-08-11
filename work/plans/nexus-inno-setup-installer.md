# Work Plan: Nexus Inno Setup Installer

## Inputs

- Source request: attached request for a Windows x64 Inno Setup installer work plan.
- Correction: keep this simple. No `NexusBootstrap.exe`. The installer should write only one registry value, `NexusRoot`.
- Existing constraints:
  - Work plan only; do not implement yet.
  - Windows x64 only.
  - Nexus owns the bundled Lazarus/FPC distro.
  - The VS Code extension remains separate and discovers the installed Nexus root.
  - Avoid installer-framework thinking.

## Summary

Add a conventional Inno Setup installer for Nexus. The build should create one clean staged install tree, then Inno should package that tree.

The intended flow is:

```text
build Nexus tools
stage dist\nexus-win64
compile NexusSetup-x64-<version>.exe
install to C:\Program Files\Nexus
write NexusRoot registry value
extension reads NexusRoot and derives the rest
```

No special bootstrap executable is needed for the first implementation. Any required path-specific files should be generated during staging if the installed path is fixed, or generated directly by the Inno script if they need `{app}`.

## Verified Findings

- There is no current Inno Setup script in the repository.
- Current tool binaries build under `output\...`:
  - `output\NexusLS\x86_64-win64\nexusls.exe`
  - `output\NexusBuild\x86_64-win64\nexusbuild.exe`
  - `output\NexusSchema\x86_64-win64\NexusSchema.exe`
  - `output\NexusTask\x86_64-win64\NexusTask.exe`
  - `output\NexusTestHost\nxtest_host.exe`
- Current framework source is under `NexusLib\core`, `NexusLib\ui`, and `NexusLib\net`.
- Current framework tools are under `NexusTools`.
- Current VSIX build script still stages a full Lazarus/FPC payload into the extension. The installer should replace that as the primary distro mechanism.
- The existing pruned Lazarus tree at `C:\nexusdeployment\pruned\lazarus` has usable `lazbuild.exe`, `fpc.exe`, and `fpc.cfg`.
- That pruned tree still contains absolute local paths in files such as `lazarus.cfg`, `environmentoptions.xml`, and `fpcdefines.xml`.
- `NexusTools\LS\nexusls.lpi` and `NexusTools\Build\nexusbuild.lpi` still reference `C:\lazarus\components\lazutils`.
- No canonical Nexus product version source was found.

## Architecture Problem

The current packaging direction is using the VSIX as the large deployment vehicle. That is the wrong boundary. Nexus itself should install the Nexus tools and curated Pascal toolchain. The VS Code extension should stay small and locate Nexus.

The main technical cleanup is not elaborate configuration infrastructure. It is producing a clean install image with no developer-machine paths and giving external tools one stable place to find it.

## Target Contract

- Owner: Nexus installer build owns the staged install tree and Inno package.
- Responsibilities:
  - NexusTask scripts build tools and create `dist\nexus-win64`.
  - Inno copies that staged tree to `{app}`.
  - Inno writes one discovery value: `NexusRoot`.
  - NexusLS and the VS Code extension derive known subpaths from `NexusRoot`.
- State flow:
  - Source/build outputs and pruned Lazarus are inputs.
  - `dist\nexus-win64` is the exact installer payload.
  - `{app}` is the installed Nexus root.
  - `NexusRoot` points to `{app}`.
- Rendering/input/persistence behavior: not applicable.

## Recommended Installed Directory Layout

Use a boring install layout:

```text
C:\Program Files\Nexus\
  bin\
    nexusls.exe
    nexusbuild.exe
    NexusTask.exe
    NexusSchema.exe
    nxtest_host.exe
  sdk\
    NexusLib\
      core\src\
      ui\src\
      net\src\
    NexusTools\
      Test\src\
    thirdparty\
      synapse\
      dmustache\
      fcl-passrc\
  toolchain\
    lazarus\
      lazbuild.exe
      lazarus.exe
      components\
      lcl\
      packager\
      fpc\
        3.2.2\
```

Do not add a separate `config` tree unless a concrete file needs it. For the first installer, prefer keeping the Lazarus/FPC layout close to the pruned Lazarus tree and fix only the files proven to contain bad paths.

## Installer/Toolchain Boundary

Inno should do only this:

- install files from `dist\nexus-win64`
- write Add/Remove Programs metadata
- write `NexusRoot`
- uninstall Nexus-owned files
- produce a normal setup executable

NexusLS and the extension should do this:

- read `NexusRoot`
- derive:
  - `bin\nexusls.exe`
  - `bin\nexusbuild.exe`
  - `toolchain\lazarus`
  - `toolchain\lazarus\lazbuild.exe`
  - `toolchain\lazarus\fpc\3.2.2`
  - `toolchain\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe`
  - `sdk\NexusLib`

Do not add multiple registry values for things that can be derived from `NexusRoot`.

## Files And Components To Ship

Ship:

- NexusLS
- NexusBuild
- NexusTask
- NexusSchema
- NexusTest host
- `NexusLib\core\src`
- `NexusLib\ui\src`
- `NexusLib\net\src`
- `NexusTools\Test\src`
- `lib\synapse`
- `lib\dmustache`
- `lib\fcl-passrc` if still needed by NexusLS/build use
- curated/pruned Lazarus/FPC under `toolchain\lazarus`
- `LICENSE` and `LICENSE-NOTICE.md`
- third-party notices required by shipped third-party code

Do not ship:

- `.git` folders
- `.o`, `.ppu`, `.obj`
- `node_modules`
- lab projects
- work plans/requests
- temporary build folders
- Lazarus `unins000.*`
- copied Lazarus files containing developer-machine paths unless rewritten

## FPC/Lazarus Configuration Strategy

Keep this minimal.

The installer should target one default install shape:

```text
{app}\toolchain\lazarus
{app}\toolchain\lazarus\fpc\3.2.2
```

During staging or Inno install:

- rewrite `lazarus.cfg` so the primary config path points inside the installed Lazarus/toolchain area or remove the override if it is not needed
- remove or regenerate `environmentoptions.xml` if it contains developer paths
- remove or regenerate `fpcdefines.xml` if it contains developer paths
- verify `fpc.cfg` works from the installed location

Do not add Lazarus or FPC to global PATH.

The path problem in `NexusTools\LS\nexusls.lpi` and `NexusTools\Build\nexusbuild.lpi` should be fixed as part of making the build/stage process reproducible, but this is a build correctness task, not an installer feature.

## Nexus Discovery

Use one registry value.

Recommended key:

```text
HKLM\Software\NexusRP\Nexus
```

Recommended value:

```text
NexusRoot REG_SZ C:\Program Files\Nexus
```

The VS Code extension should read `NexusRoot` and derive paths. If later we add user settings for an override, that is fine, but the installer should not create a pile of registry entries.

## Build/Staging/Package Pipeline

Create:

- `NexusTools\Task\scripts\stage-nexus-win64.nxtask`
- `NexusTools\Task\scripts\package-nexus-win64-inno.nxtask`

Optional wrapper:

- `NexusTools\Task\scripts\build-nexus-installer-win64.nxtask`

Stage script responsibilities:

- clean `dist\nexus-win64`
- build required Nexus tools
- copy tools to `dist\nexus-win64\bin`
- copy SDK files to `dist\nexus-win64\sdk`
- copy pruned Lazarus/FPC to `dist\nexus-win64\toolchain\lazarus`
- remove VCS files and build artifacts
- remove or rewrite known bad Lazarus/FPC path files
- run a smoke build against the staged toolchain

Package script responsibilities:

- run Inno Setup compiler against a checked-in `.iss`
- pass version and staging root as defines
- emit `dist\installers\NexusSetup-x64-<version>.exe`

If NexusTask does not yet have a dedicated Inno action, use the simplest available process/npm-style task action first or add one small `InnoSetup` action. Do not build a general packaging framework.

## Inno Setup Script Design

Create:

```text
NexusTools\Installer\win64\NexusSetup.iss
```

Use simple Inno sections:

- `[Setup]`
  - app name, publisher, version, stable `AppId`, x64 mode, default dir, output name
- `[Files]`
  - copy `dist\nexus-win64\*` to `{app}`
- `[Registry]`
  - write only `NexusRoot`
- `[UninstallDelete]`
  - remove Nexus-owned files not automatically tracked, only if needed

Avoid `[Code]` unless a specific Inno-only need is proven.

## Upgrade And Uninstall

Upgrade:

- stable `AppId`
- install over the previous version
- replace Nexus-owned files under `{app}`
- clean stale toolchain files by staging/installing a clean payload
- preserve user projects because they should not be under `{app}`

Uninstall:

- remove installed Nexus files
- remove `NexusRoot`
- do not remove VS Code settings
- do not remove user projects

## Privilege Model

Use per-machine install under:

```text
C:\Program Files\Nexus
```

That means elevation is expected. It is acceptable for the initial Windows installer and gives the extension a stable HKLM discovery point.

## Scope

Expected new files:

- `NexusTools\Installer\AGENTS.md`
- `NexusTools\Installer\win64\NexusSetup.iss`
- `NexusTools\Task\scripts\stage-nexus-win64.nxtask`
- `NexusTools\Task\scripts\package-nexus-win64-inno.nxtask`
- optional `NexusTools\Task\scripts\build-nexus-installer-win64.nxtask`
- a simple version source file if approved

Expected modified files:

- `NexusTools\LS\nexusls.lpi`
- `NexusTools\Build\nexusbuild.lpi`
- Nexus Pascal extension discovery code outside this repository, so it reads `NexusRoot`

## Out Of Scope

- `NexusBootstrap.exe`
- multiple registry values
- install manifest unless later proven necessary
- cross-platform installer abstraction
- automatic updater
- package manager
- writing lots of installer Pascal code
- bundling the full Nexus environment into the VSIX

## Staged Implementation Plan

1. Create `NexusTools\Installer` and the Inno script location.
2. Add a simple Nexus version source or accept a build-provided version parameter.
3. Fix hard-coded `C:\lazarus` project paths that block reproducible staged builds.
4. Add `stage-nexus-win64.nxtask`.
5. Stage the required tools, SDK source, and pruned Lazarus/FPC.
6. Remove `.git`, `.o`, `.ppu`, `.obj`, `unins000.*`, and known bad config/profile files from the stage.
7. Add or update the minimal Lazarus/FPC config files needed for staged/installed builds.
8. Add `NexusSetup.iss`.
9. Add `package-nexus-win64-inno.nxtask`.
10. Update the VS Code extension to read `NexusRoot` and derive paths.
11. Run clean staged smoke tests.
12. Run installer test on a clean Windows machine or VM.

## Sub-Agent Delegation

Delegation is optional. If used, one worker should own installer packaging and staging:

- role: `InstallerPackagingWorker`
- folders: `NexusTools\Installer`, installer scripts, staging/package task scripts

Main Codex should keep final review and validation. The extension update should be separate because it is in another repository.

## Verification Plan

Repository/stage checks:

- confirm no `.iss` existed before the new one
- confirm staged tree contains expected `bin`, `sdk`, and `toolchain`
- `rg "C:\\\\Users|C:/Users|C:\\\\nexusdeployment|C:/nexusdeployment|C:\\\\lazarus|C:/lazarus" dist\nexus-win64`
- `rg --files dist\nexus-win64 | rg "\\.git|\\.o$|\\.ppu$|\\.obj$|unins000"`

Build checks:

- build NexusLS
- build NexusBuild
- build NexusTask
- build NexusSchema
- build NexusTest host
- run a representative FPC console compile using staged FPC
- run a representative Lazarus/LCL smoke build using staged `lazbuild`

Installer checks:

- package `NexusSetup-x64-<version>.exe`
- install on clean Windows x64
- confirm `HKLM\Software\NexusRP\Nexus\NexusRoot` exists
- confirm installed `bin\nexusls.exe` starts
- confirm installed `lazbuild.exe` and `fpc.exe` work
- confirm the VS Code extension can find Nexus from `NexusRoot`
- reinstall over existing install
- uninstall and confirm Nexus-owned files and `NexusRoot` are removed

## Risks And Questions

- Choose the product version source before implementation.
- Generate and preserve a stable Inno `AppId`.
- Decide whether FPC stays nested under Lazarus. Recommendation: yes for now, because that matches the current pruned tree.
- Confirm exactly which Lazarus config files are required after removing developer-path XML.
- Confirm whether `lib\fcl-passrc` is needed in the SDK payload or already covered by bundled FPC source.

## Approval Gate

This is a planning artifact only. No installer implementation begins until the human owner explicitly authorizes it.
