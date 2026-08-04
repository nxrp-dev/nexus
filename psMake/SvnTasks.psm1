function Invoke-SVN {
    <#
        .SYNOPSIS
            Invokes SVN to perform action against repository specified in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for performing SVN task.
        [System.Xml.XmlNode]
        $ATask
    )

    $lOptions = New-Object System.Collections.Generic.List[System.String]

    [string]$lRepository = $ATask.Repository

    [string]$lUserName = $ATask.Username
    [string]$lPassword = $ATask.Password
    [string]$lCommand = $ATask.Command

    [bool]$lIsSecure = -not ([string]::IsNullOrEmpty($lUserName) -or [string]::IsNullOrEmpty($lPassword))

    [string]$lResult = ""

    try {
      switch ($lCommand) {
          "checkout" {
              [string]$lPath = $ATask.Path
              [string]$lVersion = Get-VersionNumber $ATask
              if ($lIsSecure) {
                $lResult = &svn $lCommand "$lRepository/tags/$lVersion" "$lPath" --username $lUserName --password $lPassword 2>&1
              } else {
                $lResult = &svn $lCommand "$lRepository/tags/$lVersion" "$lPath" 2>&1
              }
          }
          "commit" {
              if ($lIsSecure) {
                $lResult = &svn $lCommand "$lRepository" --no-auth-cache --depth infinity --non-interactive --message "Automated build check-in." --username $lUserName --password $lPassword 2>&1
              } else {
                $lResult = &svn $lCommand "$lRepository" --no-auth-cache --depth infinity --non-interactive --message "Automated build check-in." 2>&1
              }
          }
          "copy" {
              [string]$lVersion = Get-VersionNumber $ATask

              if ($lIsSecure) {
                $lResult = &svn $lCommand "$lRepository/trunk" "$lRepository/tags/$lVersion" -m "Tagged the $lVersion release." --username $lUserName --password $lPassword 2>&1
              } else {
                $lResult = &svn $lCommand "$lRepository/trunk" "$lRepository/tags/$lVersion" -m "Tagged the $lVersion release." 2>&1
              }
          }
          "revert" {
              [string]$lPath = $ATask.Path

              if ($lPath) {
                  [string]$lFullPath = [System.IO.Path]::Combine($lRepository, $lPath)

                  if ($lIsSecure) {
                    $lResult = &svn $lCommand "$lFullPath" --non-interactive --username $lUserName --password $lPassword 2>&1
                  } else {
                    $lResult = &svn $lCommand "$lFullPath" --non-interactive 2>&1
                  }
              } else {
                  if ($lIsSecure) {
                    $lResult = &svn $lCommand "$lRepository" --depth infinity --non-interactive --username $lUserName --password $lPassword 2>&1
                  } else {
                    $lResult = &svn $lCommand "$lRepository" --depth infinity --non-interactive 2>&1
                  }
              }
          }
          "update" {
              if ($lIsSecure) {
                $lResult = &svn $lCommand "$lRepository" --depth infinity --non-interactive --force --username $lUserName --password $lPassword 2>&1
              } else {
                $lResult = &svn $lCommand "$lRepository" --depth infinity --non-interactive --force 2>&1
              }
          }
          default {
              $lResult = "Unhandled SVN command: $lCommand"
          }
      }
    } catch {
      [string]$errorMessage = $_.Exception.Message
      throw "$lCommand Exception: $lResult $errorMessage"
    }
}

function Create-Changelog {
    <#
        .SYNOPSIS
            Finds revisions for current tag and previous tag, then invokes SVN
            to request log from the one revision to the other.
    #>
    [CmdletBinding()]
    param (
        # Specifications for performing SVN task.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lRepository = $ATask.repository
    [string]$lPreviousTag = $ATask.currenttag
    [string]$lNewTag = Get-VersionNumber $ATask
    [string]$lChangelogPath = $ATask.ChangeLogFile
    [string]$lAppend = $ATask.append
    [string]$lUserName = $ATask.Username
    [string]$lPassword = $ATask.Password

    try {
      [string]$lRevisionStart = Find-RevisionForTag $lRepository $lPreviousTag $lUserName $lPassword
      [string]$lRevisionEnd = Find-RevisionForTag $lRepository $lNewTag $lUserName $lPassword

      [bool]$lIsSecure = -not ([string]::IsNullOrEmpty($lUserName) -or [string]::IsNullOrEmpty($lPassword))

      [string]$lChangelog = ""

      if ($lIsSecure) {
        $lChangelog = &svn log -r $lRevisionStart`:$lRevisionEnd $lRepository --username $lUserName --password $lPassword | Out-String
      } else {
        $lChangelog = &svn log -r $lRevisionStart`:$lRevisionEnd $lRepository | Out-String
      }

      if ($lAppend) {
        Add-Content -Path $lChangelogPath -Value $lChangelog
      } else {
        Set-Content -Path $lChangelogPath -Value $lChangelog
      }
    } catch {
      [string]$errorMessage = $_.Exception.Message
      throw "Create-Changelog Exception: $errorMessage"
    }
}

function Find-RevisionForTag {
    <#
        .SYNOPSIS
            Returns SVN revision number for $ATag on $ARepository.
    #>
    param (
        # SVN repository.
        [string]
        $ARepository,
        # SVN tag.
        [string]
        $ATag,
        # SVN User Name.
        [string]
        $AUserName,
        # SVN Password.
        [string]
        $APassword
    )
    [bool]$lIsSecure = -not ([string]::IsNullOrEmpty($AUserName) -or [string]::IsNullOrEmpty($APassword))

    [string]$lTagRevisionPattern = "\nr(\d+)\s\|\s\w+"

    [string]$lRevision = ""
    [string]$lTagResult = ""

    if ($lIsSecure) {
      $lTagResult = &svn log --stop-on-copy $lRepository/tags/$ATag --username $AUserName --password $APassword | Out-String
    } else {
      $lTagResult = &svn log --stop-on-copy $lRepository/tags/$ATag | Out-String
    }

    [bool]$lFound = $lTagResult -match $lTagRevisionPattern
    if ($lFound) {
        $lRevision = $matches[1]
    }

    $lRevision
}

function Set-VersionToLatestTag {
    <#
        .SYNOPSIS
            Sets environment variables to version indicated by latest tag per
            specifications in $ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for performing SVN task.
        [System.Xml.XmlNode]
        $ATask
    )

    ## N.b. If this cmdlet becomes useful again, we need to add support for
    ## SVN user name and passwords as with the other SVN cmdlets in this module.

    [string]$lLatestTag = Find-LatestTag $ATask.repository

    [array]$lLatestVersionParts = Get-VersionNumberParts $lLatestTag

    if ($lLatestVersionParts.Count -eq 4) {
        [string]$lMajorVariableName = $ATask.versionvariables.major
        [string]$lMinorVariableName = $ATask.versionvariables.minor
        [string]$lRevisionVariableName = $ATask.versionvariables.revision
        [string]$lBuildVariableName = $ATask.versionvariables.build

        Set-Item -Force -Path "$lMajorVariableName" -Value $lLatestVersionParts.Major
        Set-Item -Force -Path "$lMinorVariableName" -Value $lLatestVersionParts.Minor
        Set-Item -Force -Path "$lRevisionVariableName" -Value $lLatestVersionParts.Revision
        Set-Item -Force -Path "$lBuildVariableName" -Value $lLatestVersionParts.Build
    } else {
        [string]$errorMessage = "Failed to parse valid version values from latest SVN tag '$lLatestTag'."
        throw "Set-VersionToLatestTag Exception: $errorMessage"
    }
}

function Find-LatestTag {
    <#
        .SYNOPSIS
            Returns the latest tag on $ARepository.
    #>
    param (
        # SVN repository.
        [string]
        $ARepository
    )

    ## N.b. If this cmdlet becomes useful again, we need to add support for
    ## SVN user name and passwords as with the other SVN cmdlets in this module.

    [string]$lSvnInfo = &svn info --xml $ARepository/tags --depth=immediates | Out-String

    # Because PowerShell won't use XPath 2.0, we can't use this gnarly XPath.
    # We want the value of the path attribute of the entry node with the maximum
    # revision attribute value on a commit node where the path attribute is not
    # "tags".
    #[string]$lXPath = "//entry[commit/@revision=max(//entry/commit/@revision)][@path!='tags']/@path"

    # Instead, we have to find the max ourselves and query for it.
    $lRevisionNodes = Select-Xml -Content $lSvnInfo -XPath "//entry/commit/@revision" | % { [int][string]$_ }
    $lRevisionMeasurments = $lRevisionNodes | Measure-Object -Maximum
    $lRevisionsMax = $lRevisionMeasurments.Maximum
    [string]$lXPath = "//entry[commit/@revision=$lRevisionsMax][@path!='tags']/@path"

    [string]$lTag = Select-Xml -Content $lSvnInfo -XPath $lXPath

    $lTag
}
