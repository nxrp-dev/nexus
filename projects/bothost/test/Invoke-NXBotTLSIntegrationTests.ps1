# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
param(
  [string]$NexusFPCRoot = 'C:\gitdev\tools\nexus-fpc',
  [string]$OpenSSLBin = 'C:\Program Files\OpenSSL-Win64\bin',
  [string]$LazarusRoot = 'C:\lazarus'
)
$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest
$nexusRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$packagePool = Join-Path $nexusRoot 'packages\nexus-packages'
$compiler = Join-Path $NexusFPCRoot 'compiler\ppcx64.exe'
$lazbuild = Join-Path $LazarusRoot 'lazbuild.exe'
foreach ($tool in @($compiler, $lazbuild)) {
  if (!(Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Required tool missing: $tool" }
}
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('nx-bot-tls-tests-' + [guid]::NewGuid().ToString('N'))
$moduleUnits = Join-Path $runRoot 'module-units'
$hostUnits = Join-Path $runRoot 'host-units'
New-Item -ItemType Directory -Path $moduleUnits, $hostUnits | Out-Null
$unitArguments = @(('-Fu' + (Join-Path $NexusFPCRoot 'rtl\units\x86_64-win64')))
foreach ($directory in (Get-ChildItem -Directory (Join-Path $NexusFPCRoot 'packages\*\units\x86_64-win64'))) {
  $unitArguments += '-Fu' + $directory.FullName
}
$env:PATH = $OpenSSLBin + ';' + $env:PATH
# Rebuild the registered test DLL; do not create a separate BotHost test runner.
$moduleOptions = '-n -gl ' + ($unitArguments -join ' ') + ' -FU"' + $moduleUnits + '" -FE"' + $runRoot + '"'
& $lazbuild -B --no-write-project ('--compiler=' + $compiler) ('--opt=' + $moduleOptions) `
  (Join-Path $PSScriptRoot 'NexusBotHostTestModule.lpi') > (Join-Path $runRoot 'module-build.log') 2>&1
if ($LASTEXITCODE -ne 0) { throw "BotHost test DLL build failed; see $runRoot\module-build.log" }
$hostArguments = @('-n', '-B', '-Mobjfpc', '-Sh', '-Scgi', '-gl', '-vewn') + $unitArguments
foreach ($source in @('nxtest\src', 'serialization\src', 'serialization\json\src', 'network\json-rpc\src', 'core\src')) {
  $hostArguments += '-Fu' + (Join-Path $packagePool $source)
}
$hostArguments += @(('-FU' + $hostUnits), ('-FE' + $runRoot),
  (Join-Path $nexusRoot 'projects\nxtest\host\src\nxtest_host.lpr'))
& $compiler @hostArguments > (Join-Path $runRoot 'host-build.log') 2>&1
if ($LASTEXITCODE -ne 0) { throw "NexusTest host build failed; see $runRoot\host-build.log" }
$env:NEXUS_TEST_ARTIFACT_DIR = Join-Path $runRoot 'artifacts'
$testExit = 0
Push-Location $nexusRoot
try {
  # Deterministic registered suites only. No live-service suite is invoked.
  foreach ($suite in @('NexusBotHost.FileExchange', 'NexusBotHost.OpenAI')) {
    $resultLog = Join-Path $runRoot ($suite + '.json')
    & (Join-Path $runRoot 'nxtest_host.exe') (Join-Path $runRoot 'NexusBotHostTestModule.dll') `
      run-suite $suite > $resultLog 2>&1
    if ($LASTEXITCODE -ne 0) { throw "NexusTest host failed; see $resultLog" }
    $response = Get-Content -LiteralPath $resultLog -Raw | ConvertFrom-Json
    $results = @($response.result.results)
    if ($results.Count -eq 0) { throw "No tests returned for $suite" }
    $failures = @($results | Where-Object { $_.status -ne 'passed' })
    Write-Output "$suite : $($results.Count - $failures.Count) passed; $($failures.Count) failed/errors/skipped"
    if ($failures.Count -gt 0) {
      $failures | Select-Object id, status, message | Format-List
      $testExit = 1
    }
  }
} finally { Pop-Location }
Write-Output "Verification files: $runRoot"
exit $testExit
