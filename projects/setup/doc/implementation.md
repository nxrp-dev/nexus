# Implementation and limits

## Ownership and boundaries

`obNXSetupModel` contains the native declared intent. The document centrally
owns features, locations, dependencies, product metadata, Live provenance, and
the source context. Each feature owns its files/shortcuts; parent/child and
requirement links borrow. `tpNXSetup` owns pure enums and acquisition/installer
records. Neither is an execution recipe.

`obNXSetupLoader` uses the common analysis/session and dialect validation, then
Live. A successful model build transfers snapshot/context ownership; failure
leaves those inputs caller-owned. Entity allocation precedes link wiring.
No JSON is read and no reference path is reparsed by the product model.

`obNXSetupSourceContext` captures the exact source text returned to compilation,
not a later reread or compiled serialization. It also records file-selection
results and target selection. Freeze stops filesystem reads and detaches a
borrowed transient provider. Replaying is another common compilation, not a
reverse loader. The stream snapshot retains source text, source-name lookup
identities, targets and wildcard membership. Frozen names are virtual: no
captured source is extracted to its original path. File/tree binaries are kept
separately in the bundle; this class does not retain payload binaries.

`obNXSetupSelection` owns mutable explicit seeds, selected closure and reachable
dependencies while borrowing the declaration document. The caller supplies
applicability. Root Required features are always selected; nested Required
features activate inside selected parents. Selected children imply ancestors,
including across required branches. Clearing a parent clears explicit seeds
throughout its subtree, or is rejected when other requirements keep it selected.
Initial defaults apply within selected branches. Selecting a parent later does
not implicitly select all optional children. Exclusive conflicts have no
arbitrary winner. Invalid candidates leave prior state intact. Traversal order
is not execution order.

`obNXSetupLocations` accepts resolved platform/scenario bindings. It does not
guess Known Folders, scope or environment variables. A derived-location cycle
is legal syntax but cannot resolve without a concrete base. Relative paths
remain within their logical location; explicit absolute-destination semantics
are still unspecified. Resolved source paths refer to the declaring file, so
included payload declarations do not accidentally use the entry file's folder.

`obNXSetupPlan` collects resolved selected-owner file/tree and shortcut intent,
dependency membership, explicit seeds and concrete location bindings. It remains
intent, not evidence of success. It does not mutate the destination filesystem.

The fpGUI frontend is a compact installer wizard with Welcome, folder,
components, review, installation and completion pages. A dark identity sidebar,
white content area, clear headings and a stable Back/Next/Cancel footer replace
the former inspection screen. The visual reference is
[Inno Setup's modern white-content style](https://jrsoftware.org/ishelp/topic_setup_wizardstyle.htm).
Raw scripts and compiler/graph inspection are not normal installer content.
The folder page uses fpGUI's `TfpgDirectoryEdit` with its integrated folder
chooser button; the existing wizard font, spacing and layout are retained.

The component page uses the same selection model and expands owned hierarchy
only, so cyclic/shared requirements never become duplicate tree subtrees.
Rejected checks are restored from resolved selection. Reload clears borrowed
widget data before freeing the old model. Failed compilation/selection leaves
the old document displayed. `obNXSetupSession` owns the document, selection,
bindings and optional bundle extraction. The form owns that session and executes
file operations synchronously on the calling GUI thread. A local busy flag
guards execution, and `finally` restores the controls on success or failure.
There is no worker thread, completion timer, polling or asynchronous lifetime.
Navigation validates the destination and presents a review without writing
files. The final Install action invokes the existing engine; failure restores
the previous page and displays an inline error. Completion is shown only after
success. Repair and Uninstall remain available on review when the chosen folder
contains this product's installed evidence. No new installation-location policy,
progress estimates or animation machinery were added.

## File execution and evidence

`obNXSetupFileInstaller` expands selected directory trees, including empty
directories, and checks missing files, overlapping destinations, reserved
`.nx/setup/` state and unsupported selected operations before payload writes.
It refuses symbolic links/reparse points rather than silently copying outside
the declared tree. Physical roots/bindings must be absolute, not drive-relative.

Replacement follows [Inno's ordinary file policy](https://jrsoftware.org/ishelp/topic_filessection.htm):
unversioned destinations and older versions may be replaced; same/newer versions
are skipped. Unversioned payload does not displace a versioned destination.
`IgnoreVersion` explicitly overrides that rule. `PreserveExisting` takes
precedence, including repair. Repair can restore missing/same-version payload,
but does not downgrade a newer file without explicit override. Files are streamed,
with timestamps and POSIX ordinary executable permissions preserved.

`obNXSetupState` records actual installed paths and retention flags, created
directories, explicit feature choices, location bindings, product identity,
version and root. State is local to
`<root>/.nx/setup/<SHA1-of-product-id>/`, consistently across desktop platforms.
The digest is a directory key, not an integrity/security assertion. Ordinary
filesystem permissions determine access; elevation and machine registration are
not inferred. The saved product/root are checked against the state location.
The original source snapshot is `source`; bundled installs retain `payload.zip`.

Skipped preexisting files are not adopted. Existing ownership survives upgrades;
retention policy is updated for already-owned skipped files. Upgrade does not
sweep obsolete files. Uninstall removes recorded non-retained files and then
installer-created directories only when empty. Unrelated/preexisting content is
not recursively deleted. Ordinary owned files, including local modifications,
are removed unless explicitly kept. Source/payload evidence is retired after
successful removal; uninstallation does not need the original installer.

One OS file lock protects each installation's transaction. Each replacement
backs up the old file and journals intent before publishing a sibling staged
file by rename. Deletion is likewise backed up. Failure restores prior files
and removes recorded newly created directories; committed evidence is written
last. Interrupted journals require explicit `--recover`, then may be retried.
Recovery validates owned temporary/backup names and is repeatable. These are
file-operation guarantees, not rollback claims for arbitrary external installers
or proof against power loss/filesystem corruption. Initial state-directory
preparation may leave empty private directories when installation fails.

`obNXSetupSession.Repair` recompiles retained source with retained targets,
checks cached identity/version against installed evidence, restores explicit
choices/bindings, and maps sources to retained payload. It never silently
reselects today's default features.

## Distribution artifact

`NexusSetupBuilder <script> <runtime> <output> [Target=Value ...]` constructs
a new artifact; it never overwrites the runtime input. All declared feature
file/tree sources, including unselected optional payload, are packaged.

The output is runtime bytes, ZIP bytes, then a 32-byte reverse footer:
little-endian UInt64 format version (1), archive offset, archive length, and
eight ASCII bytes `NXSTAIL1`. The runtime verifies exact bounds before reading
the archive. Extraction occurs in one owned temporary directory; traversal,
absolute names, links, duplicate names and unexpected archive members are
rejected before extraction. Original source metadata is loaded through the
frozen common source-provider interface, never rewritten or executed as code.

The unbundled runtime supports explicit repair/uninstall/recovery against state.
The bundled runtime also supports `--install <root>` and its normal fpGUI UI.
`--log <file>` records an operation result; nonzero process exit means failure.

## Deliberately deferred

Actual Nexus inventory, Nexus2D's folder layout, registry/Known Folder bindings,
elevation, platform installer registration, shortcut execution, detection,
downloads, Exe/MSI/VSIX providers and VS Code integration remain undecided or
secondary. A selected dependency/shortcut is rejected before payload writes;
declarations are not presented as executed providers. No scripting or
conditional-expression language was added. Forge remains unchanged.

## Current verification

The real bundled Win64 executable installed files with matching hashes in an
isolated folder containing spaces. The unbundled runtime repaired a missing file
from installed payload/cache and uninstalled from evidence. Native tests cover
upgrade/preservation, repair choices/bindings, empty directories, interrupted
journals, locked-file rollback, version rules and malicious archive names.
UI tests exercise synchronous real file installation/removal, error cleanup,
selection and model ownership, wizard navigation, folder validation, review
without writes, actual installation through the Install button, and return to
review after a rejected operation.

Windows x64 is verified. Linux/macOS conditional code has not been built or run;
desktop packaging/state layout is shared, but that is not platform verification.
There is no claim of owner interactive acceptance or power-loss testing.

The common file source provider normalizes line endings through
`TStringList.Text` before Setup captures them. At the owner's direction, the
portable-source test compares replayed text with the initially captured compiler
text, not raw disk bytes. Snapshot byte-comparison and replay of absolute imports
remain checked. Production source-reading and capture behavior are unchanged.

The retention-policy assertion exposed a lookup issue:
`TNXSetupState.FindFile` compares raw path strings using `SameFileName`, which
does not normalize Windows separators. A valid mixed-separator path therefore
returned nil; dereferencing it caused the new test's access violation. The owner
approved normalization in the state lookup. That fix passed the unchanged test.

After the wizard redesign, the runtime, builder and GUI/native test runners
compiled. All 5 GUI cases passed twice, including synchronous completion and
failure cleanup, with zero unfreed heap blocks. The rendered Welcome page was
checked from the live bundled executable. Other page behavior is covered by the
GUI tests; owner interactive acceptance remains separate. Source checks
found no Setup worker, timer, thread initialization or polling wait remaining.
With the source-text assertion corrected, the native runner passed all 24 cases;
all heap blocks were freed. The prior unchanged NexusScript regression runner
passed 75 cases and Forge passed 22, also leak-free. Neither NexusScript nor
Forge was modified by the thread/timer removal.

## Earlier implementation verification record

Native Setup tests cover model identity/lifetime and metadata, cyclic feature
closure, explicit/implied selection, dependency cycles/deduplication, mandatory
and exclusive behavior, supplied applicability, source/pattern replay, location
errors, failed construction/validation cleanup and plan inspection against real
Nexus file/tree sources. UI tests exercise finite owned tree expansion,
checkbox rejection/restoration, exclusivity, reload and failed-load preservation.

Initial implementation results on Windows x64, before the SQLite restoration:

| Runner | Passed |
| --- | ---: |
| NexusScript, including Live and the subsequently removed SQLite additions | 74 |
| Setup native model/selection | 12 |
| Setup UI | 2 |
| NexusScript language server | 12 |
| Forge (unchanged regression suite) | 22 |
| PackageManager | 25 |
| NexusScript editor and popup regression cases | 23 |
| **Total** | **170** |

All executed cases passed; every runner reported zero unfreed heap blocks.
The NexusScript test DLL also compiled, but was not run through the DLL host.
The Setup application compiled, loaded the example into its titled Nexus window,
and accepted normal close. This is automated smoke verification, not an owner
interactive acceptance test or evidence of installation behavior. Linux/macOS
builds and provider behavior were not tested.

Source checks found no compulsory reference-projection cloning or `NXS5004`
object-cycle rejection in the common compiler. Scalar `NXS5002` guards remain.
Setup domain construction uses Live; its loading/source-context boundary uses
the common compiler and source-provider API, not JSON or compiler field mapping.

Forge source, tests, project files, dialects, templates, examples and documentation
are unchanged. No Forge migration analysis was started. The owner-paused earlier
PackageManager dependency fixture remains paused. No unrelated fpGUI changes,
Task/PasBuild code, package acquisition or general project redesign were made.

## SQLite restoration

The owner's correction removed the added generic node/link SQLite representation,
its implementation unit, fixtures, and representation-specific tests. The SQLite
emitter was restored to its authored table, field, array and owner-relationship
projection. The subsequent focused fix persists definition-valued properties
using the existing authored relationship columns; it does not add generic graph
tables. Historical work plans remain unchanged.

An isolated build of the original compiler reproduced `NXS5004` for the original
self/mutual-definition reference fixtures, before any SQLite emission. The
restriction belonged to shared compilation, not SQLite's table layout. That
compiler correction and the Live/Setup work remain in place. General reference
persistence was not added to SQLite as a replacement.

After restoration, all 73 NexusScript cases and all 14 Setup native/UI cases
passed with zero unfreed heap blocks. The focused `SQLiteReferenceCycles` case
checks both file and stream output against the existing authored relational
shape. The NexusScript CLI and test DLL compiled; the CLI build used temporary
unit-path options for its existing stale JSON search paths, without changing
its project file.
