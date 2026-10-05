# NexusPackageManager

NexusPackageManager is an fpGUI workbench for developing the Package,
PackageIndex, and Project NexusScript dialects. These are provisional entity
definitions, not Forge tasks or a package manager.

Build with `lazbuild projects/PackageManager/NexusPackageManager.lpi`. Open the
application and choose a file from `projects/PackageManager/examples/`, or pass
an example filename on the command line. Edit the source, select Validate to
inspect the compiled definition/property tree and diagnostics, then Save or
Reload as needed. Validation uses the unsaved editor text.

The structure pane uses the native fpGUI `TNXVirtualTreeView`. It retains the
definition/property/array hierarchy and expands all branches after validation.
Its node captions are owned snapshots, so revalidation or releasing the compiled
document cannot leave the displayed tree pointing at old compiler objects.

The Package example has an opaque textual identity and a declared dependency.
No dependency is located or executed. The PackageIndex and Project examples
deliberately contain no catalog or relationship policy yet.
