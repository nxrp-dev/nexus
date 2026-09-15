# Diagnostic comparison, not a Forge build implementation.
# Resource preparation below exposes work absent from the translated package.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'lib/pasbuild'
$exampleRoot = Join-Path $repoRoot 'NexusTools/Forge/examples/pasbuild-comparison'
$runRoot = Join-Path $repoRoot ('output/ForgePasBuildComparison/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (Test-Path -LiteralPath $runRoot) { throw 'Comparison directory already exists' }
New-Item -ItemType Directory -Path $runRoot | Out-Null
$logRoot = Join-Path $runRoot 'logs'
New-Item -ItemType Directory -Path $logRoot | Out-Null
$results = [Collections.Generic.List[object]]::new()
$forgeExe = Join-Path $repoRoot 'output/NexusForge/x86_64-win64/nxforge.exe'

function Copy-Project([string]$Name) {
    $destination = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Path $destination | Out-Null
    foreach ($entry in @('src', 'docs', 'project.xml', 'LICENSE', 'README.adoc', 'BOOTSTRAP.txt')) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $entry) -Destination $destination -Recurse
    }
    return $destination
}

function Invoke-Logged([string]$Name, [string]$Directory, [string]$Executable, [string[]]$Arguments) {
    $logPath = Join-Path $logRoot ($Name + '.txt')
    Push-Location -LiteralPath $Directory
    try {
        # Windows PowerShell wraps native stderr as ErrorRecords; the native exit
        # code, not stderr alone, determines this comparison's result.
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments *> $logPath
        $code = $LASTEXITCODE
    } finally { Pop-Location }
    $results.Add([pscustomobject]@{ Step=$Name; ExitCode=$code; Directory=$Directory; Log=$logPath })
    ConvertTo-Json -InputObject $results.ToArray() -Depth 3 | Set-Content (Join-Path $runRoot 'results.json')
    Write-Host "$Name : exit $code"
    return $code
}

function Prepare-Resources([string]$ProjectRoot, [string]$OutputRelative) {
    $outputRoot = Join-Path $ProjectRoot $OutputRelative
    New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
    [xml]$project = Get-Content -LiteralPath (Join-Path $ProjectRoot 'project.xml') -Raw
    foreach ($name in @('version.inc', 'build-date.inc')) {
        $text = [IO.File]::ReadAllText((Join-Path $ProjectRoot ('src/main/resources/' + $name)))
        $text = $text.Replace('${project.version}', [string]$project.project.version)
        $text = $text.Replace('${build.date}', (Get-Date -Format 'yyyy-MM-dd'))
        [IO.File]::WriteAllText((Join-Path $outputRoot $name), $text)
    }
}

function Invoke-ForgePackage([string]$Step, [string]$Mode) {
    return Invoke-Logged $Step $forgeRoot $forgeExe @(
        '/input=PasBuild.ForgePackage.nxscript', '/package=PasBuild',
        ('/targets=TargetCPU:x64,TargetOS:Windows,BuildMode:' + $Mode))
}

$bootstrapRoot = Copy-Project 'bootstrap'
$baselineRoot = Copy-Project 'baseline'
$forgeRoot = Copy-Project 'forge'
Get-ChildItem -LiteralPath $exampleRoot -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $forgeRoot
}
$sourceHash = (Get-FileHash -LiteralPath (Join-Path $sourceRoot 'project.xml') -Algorithm SHA256).Hash
"Input: lib/pasbuild/project.xml`r`nSHA256: $sourceHash" | Set-Content (Join-Path $runRoot 'input.txt')

# Build the baseline tool from current source, not the old vendored executable.
Prepare-Resources $bootstrapRoot 'target'
New-Item -ItemType Directory -Force -Path (Join-Path $bootstrapRoot 'target/units') | Out-Null
$code = Invoke-Logged 'bootstrap-current-pasbuild' $bootstrapRoot 'fpc' @(
    '-Mobjfpc', '-O1', '-FEtarget', '-FUtarget/units', '-Fitarget',
    '-Fusrc/main/pascal', 'src/main/pascal/PasBuild.pas')
if ($code -ne 0) { throw "Baseline bootstrap failed; see $logRoot" }
$pasbuildExe = Join-Path $bootstrapRoot 'target/PasBuild.exe'
$null = Invoke-Logged 'baseline-version' $baselineRoot $pasbuildExe @('--version')
foreach ($mode in @('default', 'debug', 'release')) {
    $arguments = @('compile', '-v')
    if ($mode -ne 'default') { $arguments += @('-p', $mode) }
    $null = Invoke-Logged ('baseline-compile-' + $mode) $baselineRoot $pasbuildExe $arguments
}
$null = Invoke-Logged 'baseline-test' $baselineRoot $pasbuildExe @('test', '-v')
# These operate only on the fresh baseline copy's target directory.
$null = Invoke-Logged 'baseline-package' $baselineRoot $pasbuildExe @('package', '-p', 'release', '-v')
$null = Invoke-Logged 'baseline-source-package' $baselineRoot $pasbuildExe @('source-package')

$null = Invoke-ForgePackage 'forge-clean-missing-resources' 'default'
foreach ($mode in @('default', 'debug', 'release')) {
    Prepare-Resources $forgeRoot ('target/' + $mode)
    $null = Invoke-ForgePackage ('forge-custom-' + $mode) $mode
}
$null = Invoke-ForgePackage 'forge-reuse-default' 'default'
$null = Invoke-Logged 'forge-built-version' $forgeRoot (Join-Path $forgeRoot 'target/default/pasbuild.exe') @('--version')

# Test fixtures and test invocation remain explicit harness
# steps. Only compilation here is performed by Forge.
$testOutput = Join-Path $forgeRoot 'target/default'
Get-ChildItem -LiteralPath (Join-Path $forgeRoot 'src/test/resources') | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $testOutput -Recurse
}
$code = Invoke-Logged 'forge-test-compile' $forgeRoot $forgeExe @(
    '/input=TestBuild.nxscript',
    '/targets=TargetCPU:x64,TargetOS:Windows,BuildMode:default')
if ($code -eq 0) {
    $null = Invoke-Logged 'forge-tests-external-run' $testOutput (Join-Path $testOutput 'TestRunner.exe') @('--all', '--format=plain')
}

$probePath = Join-Path $forgeRoot 'UnsupportedOptions.nxscript'
$probe = [IO.File]::ReadAllText((Join-Path $forgeRoot 'TestBuild.nxscript'))
$probe = $probe.Replace('FPC Test (CompileTests) {', 'FPC Test (CompileTests) { CompilerOptions: ["-O1"];')
[IO.File]::WriteAllText($probePath, $probe)
$null = Invoke-Logged 'forge-options-contract-probe' $forgeRoot $forgeExe @(
    '/input=UnsupportedOptions.nxscript', '/targets=TargetCPU:x64,TargetOS:Windows,BuildMode:default')

# Demonstrate the deliberately different freshness contract using only copies.
foreach ($side in @('baseline', 'forge')) {
    $projectRoot = Join-Path $runRoot $side
    $sourcePath = Join-Path $projectRoot 'src/main/pascal/PasBuild.pas'
    $originalBytes = [IO.File]::ReadAllBytes($sourcePath)
    try {
        $text = [IO.File]::ReadAllText($sourcePath)
        [IO.File]::WriteAllText($sourcePath, 'deliberately invalid Pascal;' + [Environment]::NewLine + $text)
        if ($side -eq 'baseline') {
            $null = Invoke-Logged 'baseline-changed-source' $baselineRoot $pasbuildExe @('compile', '-v')
        } else {
            $null = Invoke-ForgePackage 'forge-changed-source' 'default'
        }
    } finally { [IO.File]::WriteAllBytes($sourcePath, $originalBytes) }
}

$baselineFailures = @(Select-String -LiteralPath (Join-Path $logRoot 'baseline-test.txt') -Pattern '^\s+Message:' | ForEach-Object { $_.Line.Trim() })
$forgeFailures = @(Select-String -LiteralPath (Join-Path $logRoot 'forge-tests-external-run.txt') -Pattern '^\s+Message:' | ForEach-Object { $_.Line.Trim() })
[pscustomobject]@{
    BaselineFailureCount = $baselineFailures.Count
    ForgeFailureCount = $forgeFailures.Count
    SameFailureMessages = (@(Compare-Object $baselineFailures $forgeFailures).Count -eq 0)
} | ConvertTo-Json | Set-Content (Join-Path $runRoot 'test-comparison.json')

Write-Host "Comparison saved: $runRoot"
