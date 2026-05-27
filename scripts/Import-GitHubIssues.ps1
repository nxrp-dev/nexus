param(
    [Parameter(Mandatory = $true)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [string] $IssuesFile = ".\issues.json",

    [Parameter(Mandatory = $false)]
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CommandName
    )

    $lCommand = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $lCommand
}

function ConvertTo-StringArray {
    param(
        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array]) {
        return @($Value | ForEach-Object { [string] $_ } | Where-Object { $_.Trim().Length -gt 0 })
    }

    $lText = [string] $Value

    if ($lText.Trim().Length -eq 0) {
        return @()
    }

    return @($lText)
}

function Get-RequiredText {
    param(
        [Parameter(Mandatory = $true)]
        $Object,

        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        throw "Issue is missing required field '$Name'."
    }

    $lValue = [string] $Object.$Name

    if ($lValue.Trim().Length -eq 0) {
        throw "Issue field '$Name' cannot be empty."
    }

    return $lValue
}

if (-not (Test-CommandExists "gh")) {
    throw "GitHub CLI 'gh' was not found in PATH. Install it and run 'gh auth login' first."
}

if (-not (Test-Path -LiteralPath $IssuesFile)) {
    throw "Issues file not found: $IssuesFile"
}

$lAuthStatus = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
}

$lJsonText = Get-Content -LiteralPath $IssuesFile -Raw
$lIssues = $lJsonText | ConvertFrom-Json

if ($null -eq $lIssues) {
    throw "No issues found in $IssuesFile"
}

if ($lIssues -isnot [System.Array]) {
    $lIssues = @($lIssues)
}

$lTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("github-issue-import-" + [System.Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Path $lTempRoot | Out-Null

try {
    $lIndex = 0

    foreach ($lIssue in $lIssues) {
        $lIndex++

        $lTitle = Get-RequiredText -Object $lIssue -Name "title"

        $lBody = ""
        if ($lIssue.PSObject.Properties.Name -contains "body" -and $null -ne $lIssue.body) {
            $lBody = [string] $lIssue.body
        }

        $lLabels = @()
        if ($lIssue.PSObject.Properties.Name -contains "labels") {
            $lLabels = ConvertTo-StringArray $lIssue.labels
        }

        $lAssignees = @()
        if ($lIssue.PSObject.Properties.Name -contains "assignees") {
            $lAssignees = ConvertTo-StringArray $lIssue.assignees
        }

        $lMilestone = $null
        if ($lIssue.PSObject.Properties.Name -contains "milestone" -and $null -ne $lIssue.milestone) {
            $lMilestone = [string] $lIssue.milestone
        }

        $lBodyFile = Join-Path $lTempRoot ("issue-" + $lIndex.ToString("0000") + ".md")
        Set-Content -LiteralPath $lBodyFile -Value $lBody -Encoding UTF8

        $lArgs = @(
            "issue", "create",
            "--repo", $Repo,
            "--title", $lTitle,
            "--body-file", $lBodyFile
        )

        foreach ($lLabel in $lLabels) {
            $lArgs += @("--label", $lLabel)
        }

        foreach ($lAssignee in $lAssignees) {
            $lArgs += @("--assignee", $lAssignee)
        }

        if ($null -ne $lMilestone -and $lMilestone.Trim().Length -gt 0) {
            $lArgs += @("--milestone", $lMilestone)
        }

        Write-Host ""
        Write-Host "[$lIndex/$($lIssues.Count)] $lTitle"

        if ($DryRun) {
            Write-Host "DRY RUN: gh $($lArgs -join ' ')"
        }
        else {
            & gh @lArgs

            if ($LASTEXITCODE -ne 0) {
                throw "Failed creating issue: $lTitle"
            }
        }
    }

    Write-Host ""
    Write-Host "Complete. Processed $($lIssues.Count) issue(s)."
}
finally {
    if (Test-Path -LiteralPath $lTempRoot) {
        Remove-Item -LiteralPath $lTempRoot -Recurse -Force
    }
}


#[
#  {
#    "title": "JSON-RPC: add notification detection and no-response execution path",
#    "body": "Deferred JSON-RPC 2.0 enhancement.\n\nJSON-RPC notifications are requests without an id.",
#    "labels": ["enhancement", "json-rpc", "deferred"],
#    "assignees": [],
#    "milestone": null
#  }
#]