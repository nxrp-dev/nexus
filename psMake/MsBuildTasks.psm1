function Publish-CSharp {
    <#
        .SYNOPSIS
            Invokes msbuild to publish CSharp project or solution according to
            specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for CSharp project to publish.
        [System.Xml.XmlNode]
        $ATask
    )

    # Set executable for msbuild and verify its existence.
    [string]$lMsBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\msBuild.exe"
    if (!(Test-Path -Path "$lMsBuild")) {
        [string]$errorMessage = "msbuild.exe path not found."
        throw "Publish-CSharp Exception: $errorMessage"
    }

    # Read CSharp project or solution file and verify its existence.
    [string]$lFileName = $ATask.ControlFile
    if (!(Test-Path -Path "$lFileName")) {
        [string]$errorMessage = "Solution or Project file not found."
        throw "Publish-CSharp Exception: $errorMessage"
    }

    $lPublishArguments = New-Object System.Collections.Generic.List[System.String]
    $lPublishArguments.Add($lFileName)

    foreach ($lArgumentNode in $ATask.Arguments.Argument) {
        [string]$lArgument = $lArgumentNode
        $lPublishArguments.Add($lArgument)
    }

    try {
        [string]$lResult = &"$lMsBuild" $lPublishArguments

        if (!$?) {
            [string]$errorMessage = $lResult
            throw "Publish-CSharp Exception: $errorMessage"
        }
    } catch {
        [string]$errorMessage = $_.Exception.Message
        throw "Publish-CSharp Exception: $errorMessage"
    }
}

function Move-ResidualItem {
    <#
        .SYNOPSIS
            Makes resulting file set match results from publishing from the
            Visual Studio IDE according to specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for files to move.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lVersion = (Get-VersionNumber($ATask)).Replace(".", "_")
    [string]$lPublishTo = $ATask.PublishTo
    [string]$lApplicationName = $ATask.AppName

    try {
        [string]$lFileToRemove = $ATask.FileToRemove
        [string]$lPath = [System.IO.Path]::Combine($lPublishTo, $lFileToRemove)

        Remove-Item -LiteralPath $lPath -Force

        [string]$lFileToCopy = $ATask.FileToCopy
        [string]$lPath = [System.IO.Path]::Combine($lPublishTo, $lFileToCopy)
        [string]$lDestination = [System.IO.Path]::Combine($lPublishTo, "Application Files", $lApplicationName + "_" + $lVersion)

        Copy-Item -LiteralPath $lPath -Destination $lDestination -Force
    } catch {
        [string]$errorMessage = $_.Exception.Message
        throw "Move-ResidualItem Exception: $errorMessage"
    }
}
