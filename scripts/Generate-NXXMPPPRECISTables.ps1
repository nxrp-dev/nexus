param(
  [string]$SourceUri = 'https://www.iana.org/assignments/precis-tables-6.3.0/precis-tables-6.3.0.csv',
  [string]$OutputPath = 'NexusLib/net/src/xmpp/tpNXXMPPPRECISTableData.inc'
)

$ErrorActionPreference = 'Stop'

$lRows = Invoke-RestMethod -Uri $SourceUri
if ($lRows -is [string]) {
  $lRows = $lRows | ConvertFrom-Csv
}

$lValues = @{
  'PVALID' = 'nppProtocolValid'
  'CONTEXTJ' = 'nppContextJ'
  'CONTEXTO' = 'nppContextO'
  'DISALLOWED' = 'nppDisallowed'
  'UNASSIGNED' = 'nppUnassigned'
  'ID_DIS or FREE_PVAL' = 'nppIdentifierDisallowedFreeformValid'
}

$lLines = [System.Collections.Generic.List[string]]::new()
$lLines.Add('{ Generated from the IANA PRECIS Derived Property Value registry. }')
$lLines.Add('{ Source: ' + $SourceUri + ' }')
$lLines.Add('{ Unicode version: 6.3.0; generated file, do not edit by hand. }')
$lLines.Add('const')
$lLines.Add('  cNXXMPPPRECISRanges: array[0..' + ($lRows.Count - 1) + '] of TNXXMPPPRECISRange = (')

for ($lIndex = 0; $lIndex -lt $lRows.Count; $lIndex++) {
  $lRow = $lRows[$lIndex]
  $lParts = $lRow.Codepoint -split '-'
  $lFirst = $lParts[0]
  $lLast = if ($lParts.Count -eq 2) { $lParts[1] } else { $lFirst }
  $lProperty = $lValues[$lRow.Property]
  if (-not $lProperty) {
    throw "Unknown PRECIS property '$($lRow.Property)' at $($lRow.Codepoint)."
  }
  $lSuffix = if ($lIndex -eq $lRows.Count - 1) { '' } else { ',' }
  $lLines.Add(('    (FirstCodePoint: ${0}; LastCodePoint: ${1}; PropertyValue: {2}){3}' -f
    $lFirst, $lLast, $lProperty, $lSuffix))
}

$lLines.Add('  );')
$lOutputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $lOutputDirectory)) {
  New-Item -ItemType Directory -Path $lOutputDirectory -Force | Out-Null
}
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) $OutputPath), $lLines,
  [System.Text.UTF8Encoding]::new($false))
