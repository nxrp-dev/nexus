# PasBuild translation example

This is the counterpart of lib/pasbuild/project.xml used in the
[executed gap review](../../../../../NexusTools/Forge/docs/pasbuild-comparison.md).

Run scripts/Compare-ForgePasBuild.ps1 from the repository root to stage independent
source copies and run both tools. It copies these Forge definitions into the
staged package root. This directory itself intentionally contains no copied
PasBuild sources or generated artifacts.

Shared.nxscript contains target-selected environment values and partial FPC
configurations for application and test builds. The package composes
CompileApplication; TestBuild composes CompileTests. Each inherits its Template.
The package artifact Path combines the selected directory and executable suffix;
its FPC Output references that same Path.

Forge prepares selected artifact directories. UnitOutput explicitly references
BuildPaths.Directory so compiler units share the selected directory. The
clean attempt demonstrates the missing-resource gap. After explicit resource
preparation, the project templates compile all three application variants.
TestBuild compiles tests only. Fixture copying and test execution remain external
comparison steps, not hidden Forge functionality.
