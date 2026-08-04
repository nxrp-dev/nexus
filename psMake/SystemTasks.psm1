<#
.SYNOPSIS
    Includes wrappers for system-level cmdlets.
.DESCRIPTION
    A collection of system-level cmdlets.
#>

function Invoke-Executable {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  [string]$actionExecutable = $taskNode.executable;
  [string]$workingDirectory = $taskNode.working_directory;

  if (($workingDirectory -ne $null) -and ($workingDirectory -ne "")) {
    Push-Location $workingDirectory;
  }
  try {
	$options = @();
	foreach ($argumentNode in $taskNode.arguments.argument) {
	  [string]$argument = $argumentNode;
	  $options += , $argument;
    }

    [string]$result = &"$actionExecutable" $options
    if (!$?) {
      $errorMessage = $result
      throw "Invoke-Executable Exception: $errorMessage";
    }
  }
  finally {
    if (($null -ne $workingDirectory) -and ($workingDirectory -ne "")) {
      Pop-Location;
    }
  }
}

function Copy-Files {
  param (
	  [System.Xml.XmlNode] $taskNode
	)

  foreach ($fileNode in $taskNode.Files.File) {
	  [string]$source = $fileNode.Source;
	  [string]$target = $fileNode.Target;   

    if (Test-Path $source)
    {
      if (-Not (Test-Path $target))
      {
        md -path $target
      }

      Copy-Item -Path $source -Destination $target -Recurse -Force
    }
	}
}

function Remove-Folders {
  param (
	  [System.Xml.XmlNode] $taskNode
	)

  foreach ($lFileNode in $taskNode.Folders.Folder) {
	  [string]$lFolder = $lFileNode;

    if (Test-Path $lFolder) {
      Remove-Item -Recurse -Force $lFolder;
    }
  }
}

function Set-Variables {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  foreach ($variableNode in $taskNode.variables.variable) {
	  [string]$varName = $variableNode.name;
	  [string]$varValue = $variableNode.value;
    try {
      Set-Item -Path "$varName" -Value $varValue
    } catch {
      $errorMessage = $_.Exception.Message;
      throw "Set-Variable Failed - Name: $varName Value: $varValue \r\n [$errorMessage]";
    }
  }
}

function ServiceExists {
  param (
    [string] $serviceName
  )

  $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

  $service -ne $null
}

function Stop-Services {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  foreach ($serviceNode in $taskNode.services.service) {
    [string]$serviceName = $serviceNode.name;

    if (ServiceExists $serviceName) {
      try {
        Stop-Service -Name "$serviceName"
      } catch {
        $errorMessage = $_.Exception.Message;
        throw "Stop-Services Failed - Name: $serviceName \r\n [$errorMessage]";
      }
    }
  }
}

function Start-Services {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  foreach ($serviceNode in $taskNode.services.service) {
    [string]$serviceName = $serviceNode.name;

    if (ServiceExists $serviceName) {
      try {
        Start-Service -Name "$serviceName"
      } catch {
        $errorMessage = $_.Exception.Message;
        throw "Start-Services Failed - Name: $serviceName \r\n [$errorMessage]";
      }
    }
  }
}

function Install-Services {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  foreach ($serviceNode in $taskNode.services.service) {
    [string]$serviceName = $serviceNode.name;
    [string]$servicePath = $serviceNode.exepath;

    try {
      New-Service -Name "$serviceName" -BinaryPathName "$servicePath"
    } catch {
      $errorMessage = $_.Exception.Message;
      throw "Install-Services Failed - Name: $serviceName \r\n [$errorMessage]";
    }
  }
}

function Uninstall-Services {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  foreach ($serviceNode in $taskNode.services.service) {
    [string]$serviceName = $serviceNode.name;

    if (ServiceExists $serviceName) {
      try {
        ## Remove-Service -Name "$serviceName" ## Remove-Service requires
        ## PowerShell 6, wich is PowerShell Core. We do not support that yet.
        (Get-WmiObject Win32_Service -filter "name='$serviceName'").Delete()
      } catch {
        $errorMessage = $_.Exception.Message;
        throw "Uninstall-Services Failed - Name: $serviceName \r\n [$errorMessage]";
      }
    }
  }
}

function Compress-Files {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  foreach ($fileNode in $taskNode.files.file) {
    [string]$source = $fileNode.Source
    [string]$target = $fileNode.Target

    Compress-Archive -Path $source -DestinationPath $target -Force
  }
}

function Expand-Files {
  param (
    [System.Xml.XmlNode] $taskNode
  )

  foreach ($fileNode in $taskNode.files.file) {
    [string]$source = $fileNode.Source
    [string]$target = $fileNode.Target

    Expand-Archive -Path $source -DestinationPath $target -Force
  }
}
