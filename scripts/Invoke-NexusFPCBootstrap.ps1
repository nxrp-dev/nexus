<#
.SYNOPSIS
Clean native Windows x86-64 NexusFPC bootstrap using FPC 3.2.2.
.DESCRIPTION
Uses GNU make explicitly and follows the Free Pascal source tree's documented
clean/all bootstrap flow. Use -RegenerateMakefiles after changing build definitions
or pruning targets so FPC's generated package/utility registration and Makefiles are
refreshed from the current source tree before bootstrapping.
RTL generation includes Makefile.rtl; Makefile.pkg generation uses -s.
Existing target scopes are retained, excluding targets removed from the generator.
.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-NexusFPCBootstrap.ps1 -RegenerateMakefiles
#>
[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$BootstrapBin = 'C:\lazarus\fpc\3.2.2\bin\x86_64-win64',
    [string]$LogRoot,
    [switch]$RegenerateMakefiles,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..\..\tools\nexus-fpc' }
if (-not $LogRoot) { $LogRoot = Join-Path $PSScriptRoot '..\output\NexusFPCBootstrap' }
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$BootstrapBin = (Resolve-Path -LiteralPath $BootstrapBin).Path
$compiler = Join-Path $BootstrapBin 'ppcx64.exe'
$make = Join-Path $BootstrapBin 'make.exe'
$data2inc = Join-Path $BootstrapBin 'data2inc.exe'
$bootstrapUnits = Join-Path $BootstrapBin '..\..\units\x86_64-win64'
foreach ($path in @($compiler, $make, $data2inc, $bootstrapUnits,
    "$SourceRoot\Makefile.fpc", "$SourceRoot\compiler\pp.pas",
    "$SourceRoot\rtl\inc\Makefile.rtl", "$SourceRoot\packages\fpmake.pp",
    "$SourceRoot\utils\fpmake.pp")) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required bootstrap input missing: $path" }
}
if ((& $compiler -iV) -ne '3.2.2' -or $LASTEXITCODE -ne 0) {
    throw 'Bootstrap compiler must be FPC 3.2.2.'
}
if ((& $compiler -iTP) -ne 'x86_64' -or (& $compiler -iTO) -ne 'win64') {
    throw 'This helper requires the native x86_64-win64 bootstrap compiler.'
}
$makeVersion = & $make --version
if ($LASTEXITCODE -ne 0 -or ($makeVersion -join "`n") -notmatch '^GNU Make') {
    throw "Not GNU make: $make"
}
Write-Host "Source: $SourceRoot"
Write-Host "Bootstrap: $compiler"
Write-Host "Make: $make"
if ($CheckOnly) { Write-Host 'Preflight passed. No files changed.'; return }

$runRoot = Join-Path ([IO.Path]::GetFullPath($LogRoot)) ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$steps = [Collections.Generic.List[object]]::new()
$oldPath = $env:PATH
$lock = $null
$started = Get-Date

function Invoke-BootstrapStep([string]$Name, [string]$Directory, [string]$Executable, [string[]]$Arguments, [switch]$Quiet) {
    $log = Join-Path $runRoot ($Name + '.log')
    if (-not $Quiet) { Write-Host "Starting $Name. Log: $log" }
    Push-Location -LiteralPath $Directory
    try {
        # Windows PowerShell wraps native stderr as ErrorRecords. Always check
        # the executable's exit code instead of treating stderr alone as failure.
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments *> $log
        $code = $LASTEXITCODE
    } finally { Pop-Location }
    $steps.Add([pscustomobject]@{ Step = $Name; ExitCode = $code; Log = $log })
    $steps.ToArray() | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath "$runRoot\steps.json" -Encoding UTF8
    if ($code -ne 0) {
        Get-Content -LiteralPath $log -Tail 15 | Write-Host
        throw "$Name failed with exit $code. See $log"
    }
    if (-not $Quiet) { Write-Host "$Name passed." }
}

function Get-GitBash {
    $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $gitCommand) { throw 'Git for Windows is required to run the FPC-provided fpmake aggregate generator.' }
    $gitDirectory = Split-Path -Parent $gitCommand.Source
    $gitRoot = Split-Path -Parent $gitDirectory
    foreach ($candidate in @(
        (Join-Path $gitRoot 'bin\bash.exe'),
        (Join-Path $gitRoot 'usr\bin\bash.exe')
    )) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    throw "Unable to locate Git Bash from $($gitCommand.Source)."
}

function Update-FpmakeAggregates {
    $bash = Get-GitBash
    $generators = @(
        [pscustomobject]@{
            Name = 'packages'
            Command = @'
rm fpmake_proc.inc fpmake_add.inc ; /bin/ls -1 */fpmake.pp| while read file; do dir=`dirname $file` ; cleanedname=`echo $dir | sed -e 's+-+_+g'` ; if ! `grep -i "^procedure add_$cleanedname" $file >/dev/null` ; then printf 'procedure add_%s(const ADirectory: string);\nbegin\n  with Installer do\n{$include %s}\nend;\n\n' $cleanedname $file >> fpmake_proc.inc; else printf '{$include %s}\n\n' $file >> fpmake_proc.inc; fi; echo "  add_$cleanedname(ADirectory+IncludeTrailingPathDelimiter('$dir'));" >> fpmake_add.inc; done
'@
        },
        [pscustomobject]@{
            Name = 'utils'
            Command = @'
rm fpmake_proc.inc fpmake_add.inc ; /bin/ls -1 */fpmake.pp| while read file; do cleanedname=`dirname $file | sed -e 's+-+_+g'` ; if ! `grep -i "^procedure add_$cleanedname" $file >/dev/null` ; then printf 'procedure add_%s(const ADirectory: string);\nbegin\n  with Installer do\n{$include %s}\nend;\n\n' $cleanedname $file >> fpmake_proc.inc; else printf '{$include %s}\n\n' $file >> fpmake_proc.inc; fi; echo "  add_$cleanedname(ADirectory+IncludeTrailingPathDelimiter('$cleanedname'));" >> fpmake_add.inc; done
'@
        }
    )
    foreach ($generator in $generators) {
        $directory = Join-Path $SourceRoot $generator.Name
        $backupDirectory = Join-Path "$runRoot\aggregates-before" $generator.Name
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
        foreach ($name in @('fpmake_proc.inc', 'fpmake_add.inc')) {
            Copy-Item -LiteralPath (Join-Path $directory $name) -Destination (Join-Path $backupDirectory $name)
        }
        $script = Join-Path $runRoot ("regenerate-fpmake-{0}.sh" -f $generator.Name)
        [IO.File]::WriteAllText($script, $generator.Command, [Text.UTF8Encoding]::new($false))
        Invoke-BootstrapStep ("aggregate-{0}" -f $generator.Name) $directory $bash @(($script -replace '\\', '/'))
    }
}

function Get-GeneratedTargets([string]$Path) {
    $line = [IO.File]::ReadLines($Path) | Where-Object { $_ -like 'MAKEFILETARGETS=*' } | Select-Object -First 1
    if (-not $line) { throw "Missing MAKEFILETARGETS: $Path" }
    return ($line.Substring('MAKEFILETARGETS='.Length) -split ' ' | Where-Object { $_ })
}

function Update-BootstrapMakefiles {
    $generatorDir = Join-Path $runRoot 'generator'
    New-Item -ItemType Directory -Path $generatorDir | Out-Null
    Get-ChildItem -LiteralPath "$SourceRoot\utils\fpcm" -File | Where-Object {
        $_.Extension -in @('.pp', '.inc', '.ini')
    } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $generatorDir }
    Invoke-BootstrapStep 'generator-include' $generatorDir $data2inc @('-b', '-s', 'fpcmake.ini', 'fpcmake.inc', 'fpcmakeini')
    Invoke-BootstrapStep 'generator-build' $generatorDir $compiler ($unitArgs + @("-Fu$generatorDir", "-Fi$generatorDir", "-FE$generatorDir", "-FU$generatorDir", 'fpcmake.pp'))
    $generator = Join-Path $generatorDir 'fpcmake.exe'
    $generated = Join-Path $runRoot 'generated'
    $items = [Collections.Generic.List[object]]::new()
    $sequence = 0
    $supported = @()
    Write-Host 'Regenerating makefiles (detailed output is in the run logs).'
    # Root first establishes the currently supported targets. Only regenerate
    # existing generated Makefiles, not the hand-written fpmake wrapper files.
    $files = @((Get-Item -LiteralPath "$SourceRoot\Makefile"))
    $files += @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Filter 'Makefile*' | Where-Object {
        $_.FullName -ne "$SourceRoot\Makefile" -and $_.Name -in @('Makefile', 'Makefile.pkg')
    } | Sort-Object FullName)
    foreach ($file in $files) {
        $content = [IO.File]::ReadAllText($file.FullName)
        if (-not $content.Contains("Don't edit, this file is generated by FPCMake")) { continue }
        $relative = $file.FullName.Substring($SourceRoot.Length + 1)
        $source = Join-Path $file.DirectoryName 'Makefile.fpc'
        if (-not (Test-Path -LiteralPath $source)) { throw "No source for generated makefile: $relative" }
        $arguments = @('-q', '-w')
        if ($relative -eq 'Makefile') { $arguments += '-Tall' } else {
            $targets = @(Get-GeneratedTargets $file.FullName | Where-Object { $_ -in $supported })
            if (-not $targets.Count) { throw "No surviving targets for $relative; review its removal separately." }
            $arguments += '-T' + ($targets -join ',')
        }
        if ($relative -like 'rtl\*\Makefile') { $arguments += @('-x', "$SourceRoot\rtl\inc\Makefile.rtl") }
        if ($file.Name -eq 'Makefile.pkg') { $arguments += '-s' }
        # fpcmake prepends its source directory to -o, even for absolute paths.
        # A short sibling filename also avoids legacy Windows path-length limits.
        $temporaryName = 'Makefile.bootstrap-tmp'
        $temporary = Join-Path $file.DirectoryName $temporaryName
        if (Test-Path -LiteralPath $temporary) { throw "Temporary output already exists: $temporary" }
        $destination = Join-Path $generated $relative
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        $sequence++
        Invoke-BootstrapStep ("generate-{0:D3}" -f $sequence) $file.DirectoryName $generator ($arguments + @("-o$temporaryName", 'Makefile.fpc')) -Quiet
        Move-Item -LiteralPath $temporary -Destination $destination
        if ($relative -eq 'Makefile') { $supported = @(Get-GeneratedTargets $destination) }
        if ($relative -like 'rtl\*\Makefile' -and [IO.File]::ReadAllText($destination) -notmatch '(?m)^SYSTEMUNIT=system\r?$') {
            throw "RTL unit definitions missing from $relative"
        }
        $items.Add([pscustomobject]@{ Relative = $relative; Source = $destination; Destination = $file.FullName })
    }
    foreach ($item in $items) {
        $backup = Join-Path "$runRoot\makefiles-before" $item.Relative
        New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
        Copy-Item -LiteralPath $item.Destination -Destination $backup
        Copy-Item -LiteralPath $item.Source -Destination $item.Destination
    }
    Copy-Item -LiteralPath "$SourceRoot\utils\fpcm\fpcmake.inc" -Destination "$runRoot\fpcmake.inc.before"
    Copy-Item -LiteralPath "$generatorDir\fpcmake.inc" -Destination "$SourceRoot\utils\fpcm\fpcmake.inc"
    Write-Host "Regenerated $($items.Count) makefiles using their current sources."
}

try {
    # An exclusive file handle prevents two invocations of this helper from
    # cleaning/building the same source tree simultaneously.
    $lockPath = Join-Path $env:TEMP ('nexus-bootstrap-' + ($SourceRoot.ToLowerInvariant() -replace '[^a-z0-9]', '_') + '.lock')
    $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    $env:PATH = "$BootstrapBin;$oldPath"
    Write-Host "Logs: $runRoot"
    $unitArgs = @('-n')
    $unitArgs += @(Get-ChildItem -LiteralPath $bootstrapUnits -Directory | ForEach-Object { "-Fu$($_.FullName)" })
    if ($RegenerateMakefiles) {
        Update-FpmakeAggregates
        Update-BootstrapMakefiles
    }

    # The FPC top-level clean target has an explicit old-style fallback when no
    # fpmake cleanup executable is present. Remove generated cleanup drivers so
    # a pruned package graph cannot be cleaned by a stale executable.
    foreach ($driver in @("$SourceRoot\packages\fpmake.exe", "$SourceRoot\utils\fpmake.exe")) {
        if (Test-Path -LiteralPath $driver) { Remove-Item -LiteralPath $driver -Force }
    }

    # Follow the documented FPC bootstrap path. The top-level all target performs
    # the compiler cycle, cleans RTL/packages/utils with the newly built compiler,
    # and then rebuilds the complete retained tree.
    $makeArguments = @("FPC=$compiler", 'CPU_TARGET=x86_64', 'OS_TARGET=win64')
    Invoke-BootstrapStep 'clean' $SourceRoot $make (@('clean') + $makeArguments)
    foreach ($stamp in @('build-stamp.x86_64-win64', 'base.build-stamp.x86_64-win64')) {
        if (Test-Path -LiteralPath "$SourceRoot\$stamp") { throw "Clean left a stale build stamp: $stamp" }
    }
    Invoke-BootstrapStep 'bootstrap' $SourceRoot $make (@('all') + $makeArguments)
    foreach ($artifact in @('compiler\ppcx64.exe', 'build-stamp.x86_64-win64', 'base.build-stamp.x86_64-win64')) {
        $file = Get-Item -LiteralPath "$SourceRoot\$artifact"
        if ($file.LastWriteTime -lt $started) { throw "Bootstrap did not refresh $artifact" }
    }
    $buildLog = [IO.File]::ReadAllText("$runRoot\bootstrap.log")
    if ($buildLog -match '(?m)^.*(Fatal:|\*\*\* .*Error)') {
        throw 'Bootstrap log contains a fatal build error. Inspect bootstrap.log.'
    }
    Invoke-BootstrapStep 'compiler-version' $SourceRoot "$SourceRoot\compiler\ppcx64.exe" @('-iV')
    $warnings = @([IO.File]::ReadLines("$runRoot\bootstrap.log") | Where-Object { $_ -match '(?i)warning:' })
    $warnings | Set-Content -LiteralPath "$runRoot\warnings.txt" -Encoding UTF8
    Write-Host "Bootstrap passed. Compiler and build stamps were refreshed. Warning lines: $($warnings.Count)."
    Write-Host "Logs: $runRoot"
} finally {
    $env:PATH = $oldPath
    if ($lock) { $lock.Dispose() }
}
