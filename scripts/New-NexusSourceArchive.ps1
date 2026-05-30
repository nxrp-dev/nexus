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
$ArchiveFileNamePattern = '^nexus-source-chatgpt-\d{8}-\d{6}\.zip$'

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

function Remove-OldArchives {
  param(
    [System.IO.FileInfo]$CurrentArchive
  )

  $OldArchives = Get-ChildItem -LiteralPath $OutputDirectory -File | Where-Object {
    ($_.Name -match $ArchiveFileNamePattern) -and
      ($_.FullName -ne $CurrentArchive.FullName)
  }

  $DeletedCount = 0
  foreach ($OldArchive in $OldArchives) {
    Remove-Item -LiteralPath $OldArchive.FullName -Force
    $DeletedCount++
  }

  return $DeletedCount
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
$OldArchiveCount = Remove-OldArchives -CurrentArchive $Archive

Write-Host ('Created: {0}' -f $Archive.FullName)
Write-Host ('Size: {0} bytes' -f $Archive.Length)
Write-Host ('Files: {0}' -f $FileCount)
Write-Host ('Old archives removed: {0}' -f $OldArchiveCount)
