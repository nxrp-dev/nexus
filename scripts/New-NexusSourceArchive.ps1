param(
  [string]$OutputDirectory,
  [string]$ArchiveName
)

$ErrorActionPreference = 'Stop'

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepositoryRoot = Split-Path -Parent $ScriptDirectory

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = $RepositoryRoot
}

if ([string]::IsNullOrWhiteSpace($ArchiveName)) {
  $ArchiveName = 'nexus-source-chatgpt-{0}.zip' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
}

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$OutputPath = Join-Path $OutputDirectory $ArchiveName
$StagePath = Join-Path $env:TEMP ('nexus-source-chatgpt-{0}' -f ([guid]::NewGuid().ToString('N')))

$SourceDirectories = @(
  'NexusLib',
  'NexusUI',
  'NexusTest',
  'NexusLS'
)

$SourceExtensions = @(
  '.pas',
  '.pp',
  '.inc',
  '.lpr',
  '.lpi',
  '.lfm',
  '.json',
  '.md',
  '.txt',
  '.yml',
  '.yaml',
  '.xml',
  '.ts',
  '.js',
  '.css'
)

function Copy-SourceFile {
  param(
    [System.IO.FileInfo]$SourceFile
  )

  $RelativePath = $SourceFile.FullName.Substring($RepositoryRoot.Length + 1)
  $DestinationPath = Join-Path $StagePath $RelativePath
  $DestinationDirectory = Split-Path -Parent $DestinationPath

  New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
  Copy-Item -LiteralPath $SourceFile.FullName -Destination $DestinationPath -Force
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

if (Test-Path -LiteralPath $StagePath) {
  Remove-Item -LiteralPath $StagePath -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $StagePath | Out-Null

$FileCount = 0

try {
  foreach ($SourceDirectory in $SourceDirectories) {
    $SourceRoot = Join-Path $RepositoryRoot $SourceDirectory

    if (-not (Test-Path -LiteralPath $SourceRoot)) {
      throw "Missing source directory: $SourceRoot"
    }

    Get-ChildItem -LiteralPath $SourceRoot -Recurse -File | Where-Object {
      $SourceExtensions -contains $_.Extension.ToLowerInvariant()
    } | ForEach-Object {
      Copy-SourceFile -SourceFile $_
      $script:FileCount++
    }
  }

  if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
  }

  Compress-Archive -Path (Join-Path $StagePath '*') -DestinationPath $OutputPath -CompressionLevel Optimal
}
finally {
  if (Test-Path -LiteralPath $StagePath) {
    Remove-Item -LiteralPath $StagePath -Recurse -Force
  }
}

$Archive = Get-Item -LiteralPath $OutputPath

Write-Host ('Created: {0}' -f $Archive.FullName)
Write-Host ('Size: {0} bytes' -f $Archive.Length)
Write-Host ('Files: {0}' -f $FileCount)
