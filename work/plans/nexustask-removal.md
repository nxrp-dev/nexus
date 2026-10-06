# Work Plan: Remove NexusTask

Date: 2026-10-06
Status: plan only; source inspected, no implementation changes, builds, or test runs.

## Inputs

- The owner's removal-only work-plan request in this conversation: NexusTask is superseded by Forge; delete its implementation, language, recipes, and product-specific support without migration or replacement.
- The explicit warning that NexusCode's VS Code task terminology is not evidence of a NexusTask dependency.
- Current repository source, project files, recipes, documentation, workspace index, archive script, and generated-artifact inventory.
- Repository architecture and work-plan protocols. This plan has no stages, gates, or approval scaffolding. Implementation remains local; no sub-agent use is authorized.

## Summary

Delete NexusTask and every `.nxtask` file in the checkout. Remove the documentation, catalog entries, and support references that describe or depend on the deleted product. Leave Forge, NexusBuild, NexusTest, NexusScript, NexusCode's VS Code tasks, and other unrelated systems intact.

This deliberately discards the old recipes and their automation. It does not transfer their behavior to Forge or require replacement recipes before removal.

## Verified Findings

- `NexusTools/Task/` contains 41 tracked source/support files: the executable and test-module projects, ten implementation units, seven test units, seventeen `.nxtask` samples, two Lazarus smoke-fixture files, and its local AGENTS.md. Ignored compiler output also exists inside this directory.
- The implementation consists of `tpNXTask.pas`, `obNXTaskModel.pas`, `obNXTaskParser.pas`, `obNXTaskValidation.pas`, `obNXTaskResolver.pas`, `obNXTaskDump.pas`, `obNXTaskTargets.pas`, `obNXTaskActions.pas`, `obNXTaskExecutor.pas`, and `obNXTaskCLI.pas`. The CLI exposes parse, expand, inspect, and execute. These are product infrastructure, not shared NexusScript machinery.
- Task's action registry owns Group, Trace, WriteTextFile, CopyFile, DeletePath, Archive, Git, Npm, Fpc, LazBuild, and InnoSetup actions. Delete this registry and its implementations together. The existence of similarly named independent Forge operations does not make those operations removal targets.
- `tools/task/tasks/` contains six additional tracked recipes. Together with the seventeen samples, the full checkout inventory contains 23 `.nxtask` files; none were found elsewhere outside Git metadata and node_modules.
- The six recipes build/stage language servers and other tools, prepare/test a pruned Lazarus toolchain, and stage/package the Windows installer. `stage-nexus-win64.nxtask` also copies NexusTask.exe into the staged payload. Removing these files removes that old orchestration, including its Git behavior; it does not require deleting the tools they build.
- No production Pascal source outside `NexusTools/Task` was found importing its `obNXTask`, `tpNXTask`, or `tsNXTask` units. Forge's project/test search paths and source do not depend on that directory or the Task parser/action registry.
- NexusCode's `NexusTaskProvider` is a VS Code TaskProvider. Its execution path is `NexusTaskProvider -> NexusBuildTask -> NexusBuildCommandBuilder -> nexusbuild.exe /action=build /project=...`. Its `NexusTaskDefinition` is the union of FPC, Lazarus, and NexusBuild VS Code task definitions. These names are unrelated to the NexusTask executable and `.nxtask` language; preserve them and their consumers unchanged.
- Current product-specific references outside the implementation/recipes are in README.md, three documentation pages, the workspace index, and the archive script's `.nxtask` extension entry. Mixed historical work plans also retain Task-related build, staging, migration, or coexistence instructions.
- During inspection, `projects/setup/win64/NexusSetup.iss` packaged an already staged tree through SourceRoot, without a NexusTask-specific invocation or named binary entry. Before this plan was completed, a separate workspace change deleted that file, VERSION.txt, and the setup AGENTS.md. This removal must neither restore those files nor make additional installer changes; installer source is not a NexusTask removal target.
- Ignored product artifacts exist in `output/NexusTask/`, `output/NexusTaskTestModule/`, and the implementation's own output directories. The shared NexusTestHost artifact folder contains exactly two specifically named Task Execution reports. No NexusTask payload was found under dist during this inspection.

## Target Contract

NexusTask owns no remaining implementation, executable/project, action registry, test module, fixture, sample, recipe, or product documentation in the working tree. There is no `.nxtask` language support left in repository tooling and no `.nxtask` file left in the checkout's source or generated/staged contents.

The generic Forge implementation, dialects, definitions, templates, examples, and tests stay unchanged. Shared libraries and executables used by Task stay with their existing owners. There are no aliases, compatibility wrappers, replacement command handlers, recipe conversions, or new Forge requirements.

Do not use a repository-wide zero-match rule for the text `NexusTask`: the verified NexusCode identifiers remain valid, and this removal plan necessarily names the removed product. Check actual dependencies, file paths, unit imports, language extensions, and executable invocations.

## Removal Scope

### Product and recipe files

Delete the entire `NexusTools/Task/` directory, including both `.lpr`/`.lpi` pairs, all ten implementation units, all seven test units, the Lazarus console fixture, samples, local instructions, and product-owned generated output. Do not move any of these units into Forge or a shared package.

Delete the six files under `tools/task/tasks/`:

- `build-nexus-installer-win64.nxtask`
- `build-nexusls-staged.nxtask`
- `package-nexus-win64-inno.nxtask`
- `prepare-lazarus-toolchain.nxtask`
- `stage-nexus-win64.nxtask`
- `test-pruned-lazarus-toolchain.nxtask`

Remove their now-empty Task-specific folders. Re-inventory `.nxtask` files immediately before implementation and remove any additional obsolete copies under this repository; do not touch other repositories or external installations.

### Repository references and documentation

- Remove NexusTask from the tool lists in `README.md` and `docs/ecosystem.md`, leaving the other entries and their existing descriptions alone.
- Remove the `tools/task/tasks` ownership statement from `docs/architecture/system-boundaries.md` and its maintained-input entry from `docs/nexus-forge/index.md`. Do not replace either with an invented Forge workflow or promise of eventual migration.
- Remove only the `Folder Task [Automation]` subtree from `work/workspace-index-package/Nexus.WorkspaceIndex.nxscript`. Preserve other catalog entries, including unrelated Automation/Task concepts.
- Remove `.nxtask` from `$SourceExtensions` in `repo-automation/New-NexusSourceArchive.ps1`. Keep every other inclusion rule, the script's default archive name and destination, artifact handling, and retention behavior unchanged.
- Delete the dedicated product document `work/plans/nexustask-declarative-build-system.md`.
- Remove Task-specific documentation, obsolete executable/recipe paths, and Task migration/coexistence instructions from these mixed work plans, without revising their unrelated design: `nexus-inno-setup-installer.md`, `nexusscript-build-language.md`, `nexusforge-design-spec-revised.md`, `nexusscript-language-server-restructuring-preparation.md`, `bothost-schema-forge-firebird.md`, `nexus-declarative-language.md`, and `nexusscript-doctype.md`. These historical documents do not authorize implementation of their other proposals. Removing old Task migration requirements must not turn them into new Forge work.

Search for additional Task-specific build/test registrations, command examples, navigation entries, packaging references, and support files during removal. Remove verified obsolete entries only. No separate CI/build registration outside the owned directories was identified by the current inspection.

### Generated artifacts

Remove only the exact product-owned directories `output/NexusTask/` and `output/NexusTaskTestModule/`; internal output under `NexusTools/Task/` disappears with its owner. Do not clean the whole output tree.

Remove these two reports from the shared artifact directory, not the directory itself:

- `output/NexusTestHost/test-artifacts/nxtest-run-suite-NexusTask.Execution-summary.txt`
- `output/NexusTestHost/test-artifacts/nxtest-run-suite-NexusTask.Execution-summary.json`

If a new staged copy appears before implementation, remove the specifically identified NexusTask binary/recipe copy, not the installer payload or installer executable. Do not uninstall external tools, alter C:\gitdev\tools\nexus-fpc, unpack/delete old installer archives, or delete unrelated generated output. Resolve and verify deletion targets before recursive removal.

## Dependencies and Preserved Consumers

The concrete loss is the old build/staging/toolchain-preparation/installer automation expressed in the six recipes. That loss is part of the requested deletion, not a reason to migrate the recipes or add Forge features. The inspected installer source only consumed a staged payload; its separate removal and any replacement workflow are outside this work.

Preserve NexusCode's provider, task definitions, workspace task service, project adapters, extension registration, command builder, and their compiled/bundled output. Do not rename them to make a text search quieter. Preserve the generic NexusTest host/framework, NexusBuild, the Pascal and NexusScript language servers, archive/notification automation, and independent Forge implementations of file/tool operations.

No unrelated source consumer requiring a redesign or migration was identified. If removal-time inspection finds one, report the exact caller and behavior it depends on. Leave that consumer untouched and identify the unresolved dependency; do not invent a replacement or silently broaden the removal.

## Out Of Scope

Any Forge functionality or redesign; porting Git clone/update, inspect, parse, expand, Trace, timing, or other Task behavior; converting recipes; moving Task code; replacement automation; dependency/package/project redesign; compiler/toolchain pruning; generic VS Code tasks; unrelated uses of the word task; compatibility surfaces; external repository/install cleanup; unrelated source or documentation corrections.

Preserve the existing dirty worktree, including GUI, NexusScript, PackageManager work, and the independently made setup-file deletions. This plan-only handoff changes only this plan file; its publication must not include those implementation changes.

## Verification Plan

These are checks for the later removal implementation; no builds or tests were run while preparing this plan.

- Confirm both owned Task directories, the dedicated product plan, and the exact product-generated artifacts are absent.
- Enumerate `.nxtask` files with ignored files included, excluding Git metadata and node_modules. Expect none; inspect source/staging directories rather than assuming ignored files disappeared with tracked deletion.
- Search the retained tree for the removed unit names, paths, `.nxtask` extension support, executable invocations, test-module references, and recipe names. Classify retained NexusCode identifiers and this removal document explicitly; no product build/test/invocation/support reference may remain.
- Review the diff to verify that `projects/forge/`, `projects/nexuscode/`, `packages/nxtest/`, NexusBuild, language-server source, and `projects/setup/` have no changes from this removal. Shared test/artifact directories must still contain their unrelated files.
- Check the documentation/workspace-index edits for broken references and preserved surrounding structure. Keep the archive script's output-path and naming behavior identical.
- Build and run the existing Forge checks to prove its independent implementation remains usable:

```text
lazbuild projects/forge/NexusForge.lpi
lazbuild projects/forge/test/NexusForgeTests.lpi
output/NexusForgeTests/x86_64-win64/NexusForgeTests.exe
```

- Do not execute deleted recipes, run installer staging/packaging, or rebuild unchanged NexusCode and unrelated programs merely because their names contain Task. A verification failure must be reported, not used as permission for unrelated repairs.
- Run `git diff --check` and account for every removal/edit against this scope. After the completed implementation, create the architecture checkpoint with the existing archive script and normal destination; no archive is created for this planning pass.

## Risks and Limits

- Removing the recipes intentionally removes their automation. There is no requirement here to restore feature parity or retain a runnable old installer workflow.
- Generated binaries and reports are ignored by Git, so deleting tracked source alone would leave a usable stale executable/test module and archived Task test reports. Remove the exact identified artifacts as well.
- Name-only searches would incorrectly remove NexusCode's functional NexusBuild integration. Dependency-based inspection is mandatory; its retained identifiers are expected.
- Scope and file counts reflect the current checkout. Recheck new Task-specific files/references before implementation without expanding into generic task cleanup. Git history is not being rewritten.
