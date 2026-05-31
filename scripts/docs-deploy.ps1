param(
  [string]$MkDocsPath = "C:\devtools\venvs\mkdocs\Scripts\mkdocs.exe"
)

$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")
$SitePath = Join-Path $RepoRoot "site"
$DeployRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("nexus-docs-deploy-" + [System.Guid]::NewGuid().ToString("N"))

function Invoke-Checked {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    & $FilePath @Arguments
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }

  if ($exitCode -ne 0) {
    throw "$FilePath failed with exit code $exitCode."
  }
}

try {
  Set-Location $RepoRoot

  if (!(Test-Path -LiteralPath (Join-Path $RepoRoot "mkdocs.yml"))) {
    throw "mkdocs.yml not found."
  }

  if (!(Test-Path -LiteralPath $MkDocsPath)) {
    throw "MkDocs executable not found: $MkDocsPath"
  }

  $remoteUrl = (& git config --get remote.origin.url)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteUrl)) {
    throw "Git remote origin URL was not found."
  }

  $sourceCommit = (& git rev-parse --short HEAD)
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read current git commit."
  }

  Write-Host "Building MkDocs site..."
  Invoke-Checked $MkDocsPath @("build", "--clean") $RepoRoot

  New-Item -ItemType Directory -Force -Path $DeployRoot | Out-Null

  Write-Host "Preparing gh-pages publish tree..."
  Get-ChildItem -LiteralPath $SitePath -Force |
    Copy-Item -Destination $DeployRoot -Recurse -Force
  New-Item -ItemType File -Force -Path (Join-Path $DeployRoot ".nojekyll") | Out-Null

  Invoke-Checked "git" @("init") $DeployRoot
  Invoke-Checked "git" @("checkout", "-b", "gh-pages") $DeployRoot
  Invoke-Checked "git" @("remote", "add", "origin", $remoteUrl.Trim()) $DeployRoot
  Invoke-Checked "git" @("add", "--all") $DeployRoot
  Invoke-Checked "git" @(
    "-c", "user.name=Nexus Docs Deploy",
    "-c", "user.email=docs-deploy@nexus.local",
    "commit",
    "-m", "Deploy docs from $sourceCommit"
  ) $DeployRoot

  Write-Host "Pushing gh-pages..."
  Invoke-Checked "git" @("push", "origin", "HEAD:gh-pages", "--force") $DeployRoot

  Write-Host ""
  Write-Host "Documentation deployed successfully."
}
finally {
  if (Test-Path -LiteralPath $DeployRoot) {
    Remove-Item -LiteralPath $DeployRoot -Recurse -Force
  }
}
