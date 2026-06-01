param(
  [string]$OutputDirectory,
  [string]$ArchiveName,
  [string[]]$IncludeFolders
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
$ExternalNexusPascalRoot = 'C:\gitdev\tools\nexus-pascal'

$DefaultSourceRoots = @(
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'NexusLib'); ArchivePath = 'NexusLib' },
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'NexusUI'); ArchivePath = 'NexusUI' },
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'NexusTest'); ArchivePath = 'NexusTest' },
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'NexusLS'); ArchivePath = 'NexusLS' },
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'NexusSchema'); ArchivePath = 'NexusSchema' },
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot '.ai'); ArchivePath = '.ai' },
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'work'); ArchivePath = 'work' },
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'scripts'); ArchivePath = 'scripts' },
  [pscustomobject]@{ SourcePath = $ExternalNexusPascalRoot; ArchivePath = 'tools\nexus-pascal' }
)

$DefaultSourceFiles = @(
  [pscustomobject]@{ SourcePath = (Join-Path $RepositoryRoot 'AGENTS.md'); ArchivePath = 'AGENTS.md' }
)

$SourceExtensions = @(
  '.bat',
  '.cmd',
  '.csv',
  '.css',
  '.gif',
  '.inc',
  '.js',
  '.json',
  '.lfm',
  '.lpi',
  '.lpr',
  '.md',
  '.mustache',
  '.nxs',
  '.pas',
  '.pp',
  '.ps1',
  '.png',
  '.svg',
  '.txt',
  '.tmlanguage',
  '.ts',
  '.xml',
  '.yml',
  '.yaml'
)

$SourceFileNames = @(
  '.gitignore',
  '.vscodeignore',
  'AGENTS.md'
)

$ExcludedDirectoryNames = @(
  '.git',
  'bin',
  'dist',
  'node_modules',
  'out',
  'output',
  'output_compare'
)

$TestArtifactFolderName = 'test-artifacts'
$TestArtifactArchiveRoot = 'test\artifacts'

function Copy-ArchiveFile {
  param(
    [System.IO.FileInfo]$SourceFile,
    [string]$ArchiveRelativePath
  )

  $DestinationPath = Join-Path $StagePath $ArchiveRelativePath
  $DestinationDirectory = Split-Path -Parent $DestinationPath

  New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
  Copy-Item -LiteralPath $SourceFile.FullName -Destination $DestinationPath -Force
}

function Get-RelativePath {
  param(
    [string]$BasePath,
    [string]$ChildPath
  )

  $lBasePath = [System.IO.Path]::GetFullPath($BasePath)
  $lChildPath = [System.IO.Path]::GetFullPath($ChildPath)

  return $lChildPath.Substring($lBasePath.Length).TrimStart(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
}

function Test-SourceFileIncluded {
  param(
    [System.IO.FileInfo]$SourceFile
  )

  return ($SourceExtensions -contains $SourceFile.Extension.ToLowerInvariant()) -or
    ($SourceFileNames -contains $SourceFile.Name)
}

function Test-PathWithinDirectory {
  param(
    [string]$BasePath,
    [string]$ChildPath
  )

  $lBasePath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  ) + [System.IO.Path]::DirectorySeparatorChar
  $lChildPath = [System.IO.Path]::GetFullPath($ChildPath)

  return $lChildPath.StartsWith($lBasePath, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-SelectedSourceRoots {
  param(
    [string[]]$Folders
  )

  if (($null -eq $Folders) -or ($Folders.Count -eq 0)) {
    return $DefaultSourceRoots
  }

  $lSourceRoots = @()
  foreach ($Folder in $Folders) {
    if ([string]::IsNullOrWhiteSpace($Folder)) {
      continue
    }

    $lFolder = $Folder.Trim()
    if ([System.IO.Path]::IsPathRooted($lFolder)) {
      $lSourcePath = [System.IO.Path]::GetFullPath($lFolder)
    }
    else {
      $lSourcePath = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $lFolder))
    }

    $lSelectedRoot = $DefaultSourceRoots | Where-Object {
      ($_.ArchivePath -ieq $lFolder) -or
        ([System.IO.Path]::GetFullPath($_.SourcePath) -ieq $lSourcePath)
    } | Select-Object -First 1

    if ($null -ne $lSelectedRoot) {
      $lSourceRoots += $lSelectedRoot
      continue
    }

    if (Test-PathWithinDirectory -BasePath $RepositoryRoot -ChildPath $lSourcePath) {
      $lArchivePath = Get-RelativePath -BasePath $RepositoryRoot -ChildPath $lSourcePath
    }
    else {
      $lArchivePath = Split-Path -Leaf $lSourcePath
    }

    $lSourceRoots += [pscustomobject]@{ SourcePath = $lSourcePath; ArchivePath = $lArchivePath }
  }

  return $lSourceRoots
}

function Test-SourceFileExcluded {
  param(
    [System.IO.FileInfo]$SourceFile,
    [string]$SourceRoot
  )

  $lRelativePath = Get-RelativePath -BasePath $SourceRoot -ChildPath $SourceFile.FullName
  $lParentPath = Split-Path -Parent $lRelativePath

  if ([string]::IsNullOrWhiteSpace($lParentPath)) {
    return $False
  }

  $lDirectoryNames = $lParentPath -split '[\\/]'
  foreach ($lDirectoryName in $lDirectoryNames) {
    if ($ExcludedDirectoryNames -contains $lDirectoryName.ToLowerInvariant()) {
      return $True
    }
  }

  return $False
}

function Copy-SourceFile {
  param(
    [System.IO.FileInfo]$SourceFile,
    [string]$SourceRoot,
    [string]$ArchiveRoot
  )

  $lRelativePath = Get-RelativePath -BasePath $SourceRoot -ChildPath $SourceFile.FullName
  $lArchiveRelativePath = Join-Path $ArchiveRoot $lRelativePath

  Copy-ArchiveFile -SourceFile $SourceFile -ArchiveRelativePath $lArchiveRelativePath
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

function Get-FlattenedTestArtifactName {
  param(
    [string]$OutputRoot,
    [System.IO.FileInfo]$SourceFile
  )

  $lRelativePath = Get-RelativePath -BasePath $OutputRoot -ChildPath $SourceFile.FullName
  $lPathParts = $lRelativePath -split '[\\/]'
  $lFlattenedParts = $lPathParts | Where-Object { $_ -ine $TestArtifactFolderName }

  return $lFlattenedParts -join '__'
}

function Copy-TestArtifacts {
  $lOutputRoot = Join-Path $RepositoryRoot 'output'
  if (-not (Test-Path -LiteralPath $lOutputRoot -PathType Container)) {
    return 0
  }

  $lCopiedCount = 0
  Get-ChildItem -LiteralPath $lOutputRoot -Directory -Recurse | Where-Object {
    $_.Name -ieq $TestArtifactFolderName
  } | ForEach-Object {
    $lArtifactRoot = $_.FullName
    Get-ChildItem -LiteralPath $lArtifactRoot -File -Recurse | ForEach-Object {
      $lArchiveFileName = Get-FlattenedTestArtifactName -OutputRoot $lOutputRoot -SourceFile $_
      $lArchivePath = Join-Path $TestArtifactArchiveRoot $lArchiveFileName

      Copy-ArchiveFile -SourceFile $_ -ArchiveRelativePath $lArchivePath
      $lCopiedCount++
    }
  }

  return $lCopiedCount
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

if (Test-Path -LiteralPath $StagePath) {
  Remove-Item -LiteralPath $StagePath -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $StagePath | Out-Null

$FileCount = 0
$SourceRoots = Get-SelectedSourceRoots -Folders $IncludeFolders
$SourceFiles = @()

if (($null -eq $IncludeFolders) -or ($IncludeFolders.Count -eq 0)) {
  $SourceFiles = $DefaultSourceFiles
}

try {
  foreach ($SourceRoot in $SourceRoots) {
    $SourceRootPath = [System.IO.Path]::GetFullPath($SourceRoot.SourcePath)

    if (-not (Test-Path -LiteralPath $SourceRootPath -PathType Container)) {
      throw "Missing source directory: $SourceRootPath"
    }

    Get-ChildItem -LiteralPath $SourceRootPath -Recurse -File | Where-Object {
      (Test-SourceFileIncluded -SourceFile $_) -and
        (-not (Test-SourceFileExcluded -SourceFile $_ -SourceRoot $SourceRootPath))
    } | ForEach-Object {
      Copy-SourceFile -SourceFile $_ -SourceRoot $SourceRootPath -ArchiveRoot $SourceRoot.ArchivePath
      $script:FileCount++
    }
  }

  foreach ($SourceFile in $SourceFiles) {
    $SourceFilePath = [System.IO.Path]::GetFullPath($SourceFile.SourcePath)

    if (-not (Test-Path -LiteralPath $SourceFilePath -PathType Leaf)) {
      throw "Missing source file: $SourceFilePath"
    }

    Copy-ArchiveFile -SourceFile (Get-Item -LiteralPath $SourceFilePath) -ArchiveRelativePath $SourceFile.ArchivePath
    $script:FileCount++
  }

  $TestArtifactCount = Copy-TestArtifacts
  $FileCount += $TestArtifactCount

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
Write-Host ('Test artifacts: {0}' -f $TestArtifactCount)
Write-Host ('Old archives removed: {0}' -f $OldArchiveCount)
