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
package renders version.inc from its own Version and build-date.inc from the
source document's UTC `_nx.CompiledAt` before FPC compiles each variant. Both
use the existing Render operation, just like SQL generation. The build-date
string contains the full ISO 8601 timestamp rather than a date alone.
TestBuild compiles tests only. Fixture copying and test execution remain external
comparison steps, not hidden Forge functionality.
