<#
  Copyright (c) 2014 Kevin Collins, Metaphor Systems, Inc.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
#>


function Build-CSharp {
    <#
        .SYNOPSIS
            Invokes devenv.com to compile CSharp solution according to
            specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for CSharp project to build.
        [System.Xml.XmlNode]
        $ATask
    )

    # Set executable for compilation and verify its existence.
    [string]$lDevenv = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
    if (!(Test-Path -Path "$lDevenv")) {
        [string]$errorMessage = "devenv.com path not found."
        throw "Build-CSharp Exception: $errorMessage"
    }

    # Read CSharp solution file and verify its existence.
    [string]$lSolutionFileName = $ATask.SolutionFile
    if (!(Test-Path -Path "$lSolutionFileName")) {
        [string]$errorMessage = "Solution file not found."
        throw "Build-CSharp Exception: $errorMessage"
    }

    $lCompilationArguments = New-Object System.Collections.Generic.List[System.String]
    $lCompilationArguments.Add($lSolutionFileName)

    $lCompilationArguments.Add("/rebuild")
    $lCompilationArguments.Add("Release")

    # Read file path for output.
    [string]$lOutputFile = $ATask.Output
    if (!([string]::IsNullOrEmpty($lOutputFile))) {
        # Remove previous file if it exists.
        Remove-Item "$lOutputFile" -ErrorAction Ignore

        $lCompilationArguments.Add("/out")
        $lCompilationArguments.Add($lOutputFile)
    }

    try {
        [string]$lResult = &"$lDevenv" $lCompilationArguments

        if (!$?) {
            [string]$errorMessage = $lResult
            throw "Build-CSharp Exception: $errorMessage"
        }
    } catch {
        [string]$errorMessage = $_.Exception.Message
        throw "Build-CSharp Exception: $errorMessage"
    }
}

function Build-Solution {
    <#
        .SYNOPSIS
            Builds a solution file.
    #>
    [CmdletBinding()]
    param (
        # Specifications for project assembly and version information.
        [System.Xml.XmlNode]$ATask
    )
    # Set executable for compilation and verify its existence.   
    [string]$lMSBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"

    # if (!(Test-Path -Path "$lMSBuild")) {
    #     [string]$errorMessage = "MSBuild.exe path not found."
    #     throw "Build-Sln-CSharp Exception: $errorMessage"
    # }

    # Read CSharp solution file and verify its existence.
    [string]$lSolutionFileName = $ATask.SolutionFile
    if (!(Test-Path -Path "$lSolutionFileName")) {
        [string]$errorMessage = "Solution file not found."
        throw "Build-Solution Exception: $errorMessage"
    }

    [string]$lProjectName = "/t:"+$ATask.ProjectName

    $lProperties = New-Object System.Collections.Generic.List[System.String]

    foreach($property in $ATask.Properties.Property) {
        $lProperties.Add("/p:"+$property)
    }

    try {       
        [string]$lResult = &"$lMSBuild" $lSolutionFileName $lProjectName $lProperties
        
        if (!$?) {
            [string]$errorMessage = $lResult
            throw "Build-Solution Exception: $errorMessage"
        }
    } catch {
        [string]$errorMessage = $_.Exception.Message
        throw "Build-Solution Exception: $errorMessage"
    }
}

function Build-Project {
    <#
        .SYNOPSIS
            Builds a project file.
    #>
    [CmdletBinding()]
    param (
        # Specifications for project assembly and version information.
        [System.Xml.XmlNode]$ATask
    )
    # Set executable for compilation and verify its existence.
    [string]$lMSBuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    # if (!(Test-Path -Path "$lMSBuild")) {
    #     [string]$errorMessage = "MSBuild.exe path not found."
    #     throw "Build-Sln-CSharp Exception: $errorMessage"
    # }

    # Read CSharp project file and verify its existence.
    if (!(Test-Path -Path $ATask.ProjectFile)) {
        [string]$errorMessage = "Project file not found."
        throw "Build-Project Exception: $errorMessage"
    }
    [string]$lProjectFile = $ATask.ProjectFile

    $lProperties = New-Object System.Collections.Generic.List[System.String]

    foreach($property in $ATask.Properties.Property) {
        $lProperties.Add("/p:"+$property)
    }

    try {
        [string]$lResult = &"$lMSBuild" $lProjectFile $lProperties
        
        if (!$?) {
            [string]$errorMessage = $lResult
            throw "Build-Project Exception: $errorMessage"
        }
    } catch {
        [string]$errorMessage = $_.Exception.Message
        throw "Build-Project Exception: $errorMessage"
    }
}

function Build-Wix {
    <#
        .SYNOPSIS
            Build Wix project.
    #>
    [CmdletBinding()]
    param (
        # Specifications for CSharp project assembly and version information.
        [System.Xml.XmlNode]$ATask
    )    
}

function Update-Assemblies {
    <#
        .SYNOPSIS
            Updates Assembly values.
    #>
    [CmdletBinding()]
    param (
        # Specifications for CSharp project assembly and version information.
        [System.Xml.XmlNode]$ATask
    )

    [string]$lTitle = $ATask.AssemblyInfo.Title
    [string]$lDescription = $ATask.AssemblyInfo.Description
    [string]$lConfiguration = $ATask.AssemblyInfo.Configuration
    [string]$lCompany = $ATask.AssemblyInfo.Company
    [string]$lProduct = $ATask.AssemblyInfo.Product
    [string]$lCopyright = $ATask.AssemblyInfo.Copyright
    [string]$lTrademark = $ATask.AssemblyInfo.Trademark
    [string]$lCulture = $ATask.AssemblyInfo.Culture

    [string]$lVersion = Get-VersionNumber($ATask)

    foreach ($lFileName in $ATask.Files.File)
    {
      [string]$lAssemblyInfoFile = $lFileName;

      if (!(Test-Path -Path "$lAssemblyInfoFile")) {
          [string]$errorMessage = "AssemblyInfo file not found."
          throw "Update-Assemblies Exception: $errorMessage"
      }

      [string]$lAssemblyInfo = Get-Content -Raw -Path $lAssemblyInfoFile

      [string]$lReplacement = ""
      [string]$lUpdatedAssemblyInfo = $lAssemblyInfo

      $lReplacement = '$1' + """$lTitle""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyTitle\()(".*")(\)\])', $lReplacement
      $lReplacement = '$1' + """$lDescription""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyDescription\()(".*")(\)\])', $lReplacement
      $lReplacement = '$1' + """$lConfiguration""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyConfiguration\()(".*")(\)\])', $lReplacement
      $lReplacement = '$1' + """$lCompany""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyCompany\()(".*")(\)\])', $lReplacement
      $lReplacement = '$1' + """$lProduct""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyProduct\()(".*")(\)\])', $lReplacement
      $lReplacement = '$1' + """$lCopyright""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyCopyright\()(".*")(\)\])', $lReplacement
      $lReplacement = '$1' + """$lTrademark""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyTrademark\()(".*")(\)\])', $lReplacement
      $lReplacement = '$1' + """$lCulture""" + '$3'
      $lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyCulture\()(".*")(\)\])', $lReplacement

      $lReplacement = '$1' + """$lVersion""" + '$3'
      [string]$lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyVersion\()("\d+\.\d+\.\d+\.\d+")(\)\])', $lReplacement
      [string]$lUpdatedAssemblyInfo = $lUpdatedAssemblyInfo -replace '(\[assembly: AssemblyFileVersion\()(".*")(\)\])', $lReplacement

      try {
          Set-Content -Path $lAssemblyInfoFile -Value $lUpdatedAssemblyInfo.trim()
      } catch {
          [string]$errorMessage = $_.Exception.Message
          throw "Update-Assemblies Exception: $errorMessage"
      }
    }
}

function Update-CSharpProjectFile {
    <#
        .SYNOPSIS
            Updates .csproj file version information for ClickOnce
            functionality per specifications in ATask.
    #>
    param(
        # Specifications for CSharp project updates.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lVersion = Get-VersionNumber($ATask)
    [string]$lRevision = (Get-VersionNumberParts($lVersion)).Revision

    [string]$lFileName = $ATask.file

    [System.Xml.XmlDocument]$lProjectFile = Get-Content $lFileName

    $ns = New-Object System.Xml.XmlNamespaceManager($lProjectFile.NameTable)
    $ns.AddNamespace("ns", $lProjectFile.DocumentElement.NamespaceURI)

    [System.Xml.XmlNode]$lApplicationRevisionNode = $lProjectFile.SelectSingleNode("//ns:ApplicationRevision", $ns)
    $lApplicationRevisionNode.InnerText = $lRevision

    [System.Xml.XmlNode]$lApplicationVersionNode = $lProjectFile.SelectSingleNode("//ns:ApplicationVersion", $ns)
    $lApplicationVersionNode.InnerText = $lVersion

    [string]$lInstallUrl = $ATask.InstallURL

    if ($lInstallUrl) {
        [System.Xml.XmlNode]$lInstallUrlNode = $lProjectFile.SelectSingleNode("//ns:InstallUrl", $ns)
        if ($lInstallUrlNode) {
            $lInstallUrlNode.InnerText = $lInstallUrl
        }
    }

    try {
        $lProjectFile.Save("$lFileName")
    } catch {
        [string]$errorMessage = $_.Exception.Message
        throw "Update-CSharpProjectFile Exception: $errorMessage"
    }
}

function Update-CSharpConnectionString {
    <#
        .SYNOPSIS
            Updates CSharp connection string per specifications in ATask.
    #>
    param(
        # Specifications for CSharp connection string updates.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lFileName = $ATask.File

    [System.Xml.XmlDocument]$lFile = New-Object System.Xml.XmlDocument
    $lFile.PreserveWhitespace = $true
    $lFile.Load($lFileName)

    [string]$lNewConnectionString = $ATask.ConnectionString

    $ns = New-Object System.Xml.XmlNamespaceManager($lFile.NameTable)
    $ns.AddNamespace("ns", $lFile.DocumentElement.NamespaceURI)

    [string]$lNodePath = $ATask.ConnectionString_Node_Path

    [System.Xml.XmlNode]$lConnectionStringNode = $lFile.SelectSingleNode("//ns:$lNodePath", $ns)
    $lConnectionStringNode."#text" = $lNewConnectionString

    $lFile.Save("$lFileName")
}

function Update-DatabaseConnectionString {
    <#
        .SYNOPSIS
            Updates database connection string per specifications in ATask.
    #>
    param(
        # Specifications for database connection string updates.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lFileName = $ATask.File

    [System.Xml.XmlDocument]$lFile = New-Object System.Xml.XmlDocument
    $lFile.PreserveWhitespace = $true
    $lFile.Load($lFileName)

    [string]$lNewConnectionString = $ATask.ConnectionString

    $ns = New-Object System.Xml.XmlNamespaceManager($lFile.NameTable)
    $ns.AddNamespace("ns", $lFile.DocumentElement.NamespaceURI)

    [string]$lNodePath = $ATask.ConnectionString_Node_Path

    [System.Xml.XmlNode]$lConnectionStringNode = $lFile.SelectSingleNode("//ns:$lNodePath", $ns)
    $lConnectionStringNode."#text" = $lNewConnectionString

    $lFile.Save("$lFileName")
}
