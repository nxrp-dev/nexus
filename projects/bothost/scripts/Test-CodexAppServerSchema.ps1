param(
    [Parameter(Mandatory = $true)]
    [string]$CodexExecutable,
    [string]$ExpectedHash = 'D3EACE08BE5DCA386BFD1F1E8DF650058B4113F1E10870A284D775D75517576A'
)

$schemaDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('nexus-bothost-schema-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $schemaDirectory | Out-Null
try {
    & $CodexExecutable app-server generate-json-schema --out $schemaDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Codex schema generation failed with exit code $LASTEXITCODE."
    }
    $schemaFile = Join-Path $schemaDirectory 'codex_app_server_protocol.v2.schemas.json'
    if (-not (Test-Path -LiteralPath $schemaFile)) {
        throw "Generated v2 schema was not found at $schemaFile."
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $schemaFile).Hash
    if ($actualHash -ne $ExpectedHash) {
        throw "Codex App Server schema drifted. Expected $ExpectedHash; actual $actualHash."
    }
    Write-Output "Codex App Server schema matches $actualHash."
}
finally {
    if (Test-Path -LiteralPath $schemaDirectory) {
        Remove-Item -LiteralPath $schemaDirectory -Recurse -Force
    }
}
