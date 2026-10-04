# Copyright (c) 2026 Kevin Collins.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses",
# as defined by the Mozilla Public License, v. 2.0.
#
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception

param(
  [string]$LuaDllPath = (Join-Path $PSScriptRoot '..\..\Nexus2D\platform\windows\Lua.Library\Release\x64\Lua.Library.Win32\lua.dll')
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectPath = Join-Path $repositoryRoot 'projects\nxtest\ui\src\NexusTestUI.lpi'
$definitionPath = Join-Path $repositoryRoot 'projects\nxtest\ui\src\lua51.def'
$scriptPath = Join-Path $repositoryRoot 'projects\nxtest\ui\src\ControlFrame.lua'
$outputDirectory = Join-Path $repositoryRoot 'output\NexusTestUI\x86_64-win64'
$dllTool = Get-Command llvm-dlltool.exe -ErrorAction Stop
$lazbuild = Get-Command lazbuild.exe -ErrorAction Stop

if (-not (Test-Path -LiteralPath $LuaDllPath -PathType Leaf)) {
  throw "Lua 5.1 DLL not found: $LuaDllPath"
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
& $dllTool.Source -d $definitionPath -l (Join-Path $outputDirectory 'liblua.a') -m i386:x86-64
if ($LASTEXITCODE -ne 0) {
  throw 'Could not generate the FPC Lua import library.'
}

Copy-Item -LiteralPath $LuaDllPath -Destination (Join-Path $outputDirectory 'lua.dll') -Force
Copy-Item -LiteralPath $scriptPath -Destination (Join-Path $outputDirectory 'ControlFrame.lua') -Force
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'projects\nxtest\ui\src\PanelFrame.lua') `
  -Destination (Join-Path $outputDirectory 'PanelFrame.lua') -Force
& $lazbuild.Source $projectPath
if ($LASTEXITCODE -ne 0) {
  throw 'NexusTestUI build failed.'
}

$testProcess = Start-Process -FilePath (Join-Path $outputDirectory 'NexusTestUI.exe') `
  -ArgumentList '--skin-smoke' -WorkingDirectory $outputDirectory `
  -WindowStyle Hidden -Wait -PassThru
if ($testProcess.ExitCode -ne 0) {
  throw "Lua skin drawing smoke test failed. See $outputDirectory\NexusTestUI.error.log"
}

$renderReport = Join-Path $outputDirectory 'render-smoke.txt'
$testProcess = Start-Process -FilePath (Join-Path $outputDirectory 'NexusTestUI.exe') `
  -ArgumentList @('--render-smoke', ('"' + $renderReport + '"')) `
  -WorkingDirectory $outputDirectory -WindowStyle Hidden -Wait -PassThru
if ($testProcess.ExitCode -ne 0) {
  throw "Render subscription smoke test failed. See $outputDirectory\NexusTestUI.error.log"
}
Get-Content -LiteralPath $renderReport
