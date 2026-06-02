# Recent Work Summary

## Model-Owned Unit Resolver

- Added `obNXPasUnitResolver.pas`.
  - `TNXPasUnitResolver` defines the unit-location interface.
  - `TNXPasSearchPathUnitResolver` resolves through:
    1. index-local source directories learned from opened/indexed files
    2. the current model-owned `TNXPasSearchPathContext.UnitPaths`
- Updated `TNXLSLSPModel` to create the resolver immediately after
  `FPascalSearchPaths` and before service construction.
- Updated model teardown so services are freed before the resolver, and the
  resolver is freed before `FPascalSearchPaths`.
- Exposed `PascalUnitResolver` on `TNXLSLSPContext`.

## Workspace Index Ownership Cleanup

- Removed copied canonical search-path ownership from `TNXPasWorkspaceIndex`.
  - Removed `FSearchPaths`.
  - Removed `SetSearchPaths`.
  - Removed the `SearchPaths` property.
- Added `FLocalSourceDirs`, which stays strictly local to directories learned
  from indexed/opened source files.
- `EnsureUsesUnitIndexed` now asks `UnitResolver` to locate unit files instead
  of searching a copied path list.
- Service `RebuildWorkspaceIndex` methods now only clear and reindex documents.
  They no longer copy `Model.PascalSearchPathContext.UnitPaths`.
- `ReindexDocument` remains document indexing only; no search-path refresh was
  added.

## Tests

- Updated `NexusPas.Parser.WorkspaceIndexResolvesUsesViaSearchPath` to use a
  resolver-backed search path context instead of the removed `SearchPaths`
  property.
- Updated `NexusLS.NexusPasNavigation.DefinitionFindsUnopenedUsesUnitName` so it
  no longer requires `Navigation.RebuildWorkspaceIndex` after adding a path.
- Added
  `NexusLS.NexusPasNavigation.DefinitionFindsSystemUnitAfterInitializeAndDidOpen`.
  - It creates a minimal fake FPC install root.
  - It sends `BeginInitialize` with `fpcDir`.
  - It opens a consumer unit with `uses SysUtils;`.
  - It verifies definition on `SysUtils` resolves to
    `fpc\source\rtl\win\SysUtils.pp` without
    `workspace/didChangeWorkspaceFolders` or an explicit rebuild.

## Verification

- `lazbuild NexusLS\nexusls.lpi` passed.
- `lazbuild NexusLS\NexusLSTestModule\NexusLSTestModule.lpi` passed.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-suite NexusLS.NexusPasNavigation`
  - 32 run, 32 passed, 0 failed, 0 skipped.
- `output\NexusTestHost\nxtest_host.exe output\NexusLSTestModule\x86_64-win64\NexusLSTestModule.dll run-suite NexusPas.Parser`
  - 37 run, 37 passed, 0 failed, 0 skipped.

## Notes

- No CodeTools, passrc, FPCUnit, fallback, switch, adapter, or compatibility
  bridge was introduced.
- No deployment to the VS Code extension folder was performed.
- No commit was made.
