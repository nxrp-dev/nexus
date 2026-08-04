function Connect-WebDAV {
    <#
        .SYNOPSIS
            Connects to remote server via WebDAV according to specifications in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifications for connecting to remote server.
        [System.Xml.XmlNode]
        $ATask
    )

    [string]$lWebDAVShare = $ATask.webdavshare
    [string]$lDriveName = $ATask.drivename
    [string]$lUserName = $ATask.username

    [string]$lEncryptedPassword = $ATask.encryptedpassword
    [string]$lPlaintextPassword = $ATask.plaintextpassword
    [Security.SecureString]$lSecureStringPassword = GetSecureStringPassword $lEncryptedPassword $lPlaintextPassword

    $lCredential = GetCredential $lUserName $lSecureStringPassword

    New-PSDrive -Name $lDriveName -PSProvider FileSystem -Root $lWebDAVShare -Credential $lCredential
}

function Disconnect-WebDAV {
    <#
        .SYNOPSIS
            Disconnects the mapped drive specified in ATask.
    #>
    [CmdletBinding()]
    param (
        # Specifation for the drive to disconnect.
        [System.Xml.XmlNode]
        $Atask
    )

    [string]$lDriveName = $ATask.drivename

    Get-PSDrive $lDriveName | Remove-PSDrive -Force
}

function GetCredential {
    <#
        .SYNOPSIS
            Returns a PSCredential object.
    #>
    param (
        # Username.
        [string]
        $AUserName,

        # SecureString Password.
        [Security.SecureString]
        $ASecureStringPassword
    )

    New-Object System.Management.Automation.PSCredential ($lUserName, $ASecureStringPassword)

    # May replace later with Get-Credential cmdlet if credentials are stored in environment.
}

function GetSecureStringPassword {
    <#
        .SYNOPSIS
            Returns either the password that is already encrypted, and therefore already a
            SecureString, or a SecureString version of the plaintext password.
    #>
    param (
        # Encrypted Password.
        [string]
        $AEncryptedPassword,

        # Plaintext Password.
        [string]
        $APlaintextPassword
    )

    if ($AEncryptedPassword) {
        $AEncryptedPassword
    } elseif ($APlaintextPassword) {
        ConvertTo-SecureString $APlaintextPassword -AsPlainText -Force
    } else {
        [string]$errorMessage = "Password not provided for WebDAV server connection."
        throw "GetSecureStringPassword Exception: $errorMessage"
    }
}
