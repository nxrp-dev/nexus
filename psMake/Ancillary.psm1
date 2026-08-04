function Update-Tag {
    <#
        .SYNOPSIS
            Updates currenttag node in config.xml according to specifications
            in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for config.xml.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lFilePath = $ATask.File
    [string]$lVersion = Get-VersionNumber $ATask

    [string]$lNodeName = $ATask.CurrentTagNodeName
    [System.Xml.XmlDocument]$lConfig = New-Object System.Xml.XmlDocument
    $lConfig.PreserveWhitespace = $true
    $lConfig.Load($lFilePath)

    [System.Xml.XmlNode]$lCurrentTag = $lConfig.SelectSingleNode($lNodeName)
    $lCurrentTag."#text" = $lVersion

    $lConfig.Save("$lFilePath")
}

function Increment-RevisionNumber {
    <#
        .SYNOPSIS
            OBSOLETE: Use Increment-VersionNumber instead.
            Increments the revision number of the version number based on
            $ATask.
    #>
    param (
        # Task specifications.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lFilePath = $ATask.File;
    [string]$lNodeName = $ATask.NodeName;

    [System.Xml.XmlDocument]$lFile = New-Object System.Xml.XmlDocument;
    $lFile.PreserveWhitespace = $true;
    $lFile.Load($lFilePath);

    [System.Xml.XmlNode]$lRevisionNode = $lFile.SelectSingleNode($lNodeName);
    [int]$lRevisionNumber = $lRevisionNode.InnerText;
    [int]$lNewRevisionNumber = $lRevisionNumber + 1;
    $lRevisionNode.InnerText = "$lNewRevisionNumber";

    $lFile.Save("$lFilePath");
}

function Increment-VersionNumber {
    <#
        .SYNOPSIS
            Increments part of the version number specified by $ATask.NodeName
            based on $ATask.
    #>
    param (
        # Task specifications.
        [System.Xml.XmlNode]
        $ATask
    )


    [string]$lFilePath = $ATask.File;
    [string]$lNodeName = $ATask.NodeName;

    [System.Xml.XmlDocument]$lFile = New-Object System.Xml.XmlDocument;
    $lFile.PreserveWhitespace = $true;
    $lFile.Load($lFilePath);

    [System.Xml.XmlNode]$lNumberNode = $lFile.SelectSingleNode($lNodeName);
    [int]$lNumber = $lNumberNode.InnerText;
    [int]$lNewNumber = $lNumber + 1;
    $lNumberNode.InnerText = "$lNewNumber";

    $lFile.Save("$lFilePath");
}

function Get-VersionNumber {
    <#
        .SYNOPSIS
            Returns the full version number from $ATask.
    #>
    param (
        # Task specifications.
        [System.Xml.XmlNode]
        $ATask
    )
    [string]$lMajor = $ATask.Version.Major;
    [string]$lMinor = $ATask.Version.Minor;
    [string]$lBuild = $ATask.Version.Build;
    [string]$lRevision = $ATask.Version.Revision;

    return "$lMajor.$lMinor.$lRevision.$lBuild";
}

function Get-VersionNumberParts {
    <#
        .SYNOPSIS
            Returns an object representing the parts of $AVersionNumber
    #>
    param (
        # Full version number.
        [string]
        $AVersionNumber
    )

    $lParts = $AVersionNumber.Split(".")
    @{
        Major    = $lParts[0];
        Minor    = $lParts[1];
        Revision = $lParts[2];
        Build    = $lParts[3];
    }
}

function Create-Wix-Variables {
    param (
        [System.Xml.XmlNode]
        $ATask
    )
   
<#    $filePath = Join-Path $ATask.Directory "Variables"

    if (Test-Path $filePath) {
        Remove-Item $filePath
    }

    $xml = New-Object System.Xml.XmlDocument
    $xml.AppendChild($xml.CreateXmlDeclaration("1.0", "UTF-8", $null))
    $root = $xml.CreateElement("Include")
    $xml.AppendChild($root)
    
    $productNameNode = $xml.CreateNode("processinginstruction", "define", "")
    $productNameNode.SetAttribute("ProductName", $ATask.ProductName)
    $root.AppendChild($productNameNode)
    
    $productVersionNode = $xml.CreateNode("processinginstruction", "define", "")
    $productVersionNode.SetAttribute("ProductVersion", 1.0.0.0)
    $root.AppendChild($productVersionNode)

    $productManufacturerNode = $xml.CreateNode("processinginstruction", "define", "")
    $productManufacturerNode.SetAttribute("ProductManufacturer", $ATask.ProductManufacturer)
    $root.AppendChild($productManufacturerNode)

    $productDescriptionNode = $xml.CreateNode("processinginstruction", "define", "")
    $productDescriptionNode.SetAttribute("ProductDescription", $ATask.ProductDescription)
    $root.AppendChild($productDescriptionNode)

    $xml.Save($filePath + ".wxi")   #>
}


function Send-Email {
    <#
        .SYNOPSIS
            Sends email per specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for email to send.
        [System.Xml.XmlNode]
        $ATask
    )
    $lTo = $ATask.to.Split(",")
    [string]$lFrom = $ATask.from
    [string]$lSubject = $ATask.subject
    [string]$lBody = $ATask.body

    [string]$lSmtpUser = $ATask.SmtpUser
    [string]$lSmtpPassword = $ATask.SmtpPassword
    [string]$lSmtpServer = $ATask.SmtpServer

    $lFiles = @()

    $lCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $lSmtpUser, $($lSmtpPassword | ConvertTo-SecureString -AsPlainText -Force)

    foreach ($AttachmentNode in $ATask.Attachments.Attachment) {
        [string]$lFilename = $AttachmentNode
        $lFiles += $lFilename
    }


    if ($lFiles.count -gt 0) {
        Send-MailMessage -To $lTo -from "$lFrom" -Subject $lSubject -Body "$lBody" -SmtpServer $lSmtpServer -Port 587 -BodyAsHtml -UseSsl -Credential $lCredentials -Attachments $lFiles
    }
    else {
        Send-MailMessage -To $lTo -from "$lFrom" -Subject $lSubject -Body "$lBody" -SmtpServer $lSmtpServer -Port 587 -BodyAsHtml -UseSsl -Credential $lCredentials
    }
}

function Send-psMakeMail {
    <#
        .SYNOPSIS
            Sends email per specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for email to send.
        [System.Xml.XmlNode]
        $ATask
    )


    # Set executable for email and verify its existence.
    [string]$lExe = "C:\svndev\IndigoLibrary\psMake\psMakeMail\psMakeMail\bin\Debug\psMakeMail.exe"
    if (!(Test-Path -Path "$lExe")) {
        [string]$errorMessage = "psMakeMail.exe not found."
        throw "Send-psMakeMail Exception: $errorMessage"
    }

    [string]$lTo = $ATask.to
    [string]$lSubject = $ATask.subject
    [string]$lBody = $ATask.body
    [string]$lAttachment = $ATask.attachment

    $lEmailArguments = New-Object System.Collections.Generic.List[System.String]
    $lEmailArguments.Add("-to")
    $lEmailArguments.Add("$lTo")
    $lEmailArguments.Add("-subject")
    $lEmailArguments.Add("""$lSubject""")
    $lEmailArguments.Add("-body")
    $lEmailArguments.Add("""$lBody""")
    $lEmailArguments.Add("-attachment")
    $lEmailArguments.Add("""$lAttachment""")

    try {
        [string]$lResult = Start-Process -NoNewWindow -FilePath "$lExe" -ArgumentList $lEmailArguments

        if (!$?) {
            [string]$errorMessage = $lResult
            throw "Send-psMakeMail Exception: $errorMessage"
        }
    }
    catch {
        [string]$errorMessage = $_.Exception.Message
        throw "Send-psMakeMail Exception: $errorMessage"
    }
}

function Update-OnyxSettings {
    <#
        .SYNOPSIS
            Updates a single OnyxSettings.xml per specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for updates to make.
        [System.Xml.XmlNode]
        $ATask
    )

    Set-Alias exists Test-Path -Option "Constant, AllScope"

    [string]$onyxSettingsFile = $ATask.OnyxSettingsFile
    [string]$serverUrl = $ATask.ServerURL

    if (exists $onyxSettingsFile) {
        [xml]$content = Get-Content $onyxSettingsFile
        $content.settings.serverurl = $serverUrl
        $content.Save($onyxSettingsFile)
    }
    else {
        [string]$errorMessage = "'$onyxSettingsFile' does not exist."
        throw "Update-OnyxSettings Exception: $errorMessage"
    }
}

function Update-OnyxSettingsFiles {
    <#
        .SYNOPSIS
            Updates multiple OnyxSettings.xml files per specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for updates to make.
        [System.Xml.XmlNode]
        $ATask
    )

    Set-Alias exists Test-Path -Option "Constant, AllScope"

    [string]$serverUrl = $ATask.ServerURL

    foreach ($lFileName in $ATask.Files.File) {
        if (exists $lFileName) {
            [xml]$content = Get-Content $lFileName
            $content.settings.appSettings.serverurl = $serverUrl
            $content.Save($lFileName)
        }
        else {
            [string]$errorMessage = "'$lFileName' does not exist."
            throw "Update-OnyxSettingsFiles Exception: $errorMessage"
        }
    }
}
