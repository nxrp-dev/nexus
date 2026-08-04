<#
  Copyright (c) 2014 Kevin Collins

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception

  XML files written for use with psMake are not subject to any license
  terms unless you as the author choose to do so.
#>

Param (
  [Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$true)]  [string]$makeFile = "make.xml",
  [Parameter(Position=1, Mandatory=$false, ValueFromPipeline=$false)] [string]$target = "dev", 
  [Parameter(Position=2, Mandatory=$false, ValueFromPipeline=$false)] [switch]$queue  
)

<# TODO: Figure out how to properly load sub modules into global session space.  But for now,
         to keep moving forward, I will hack it.
#>
function Register-Module {
  param (   
	  [System.Xml.XmlNode] $taskNode
	)
   
	foreach ($moduleNode in $taskNode.modules.module) {
	  [string]$moduleName = $moduleNode;
    Import-Module -Name $moduleName -Force -Global;
	}
}
<# End Of Hack#>

function Put-OutputLog() {
  param (
    [System.Xml.XmlNode]$task,
    [string]$status,
    [string]$message,
    [datetime]$starttime
  )
	$Timespan = New-TimeSpan -Start ($starttime) -End (Get-Date)
  
  $logItem = New-Object PSObject
  $logItem | Add-Member -Name "Task" -Value $task.name -MemberType NoteProperty
  $logItem | Add-Member -Name "Action" -Value $task.action -MemberType NoteProperty
  $logItem | Add-Member -Name "Status[Duration]" -Value "$status[$Timespan]" -MemberType NoteProperty
  $logItem | Add-Member -Name "Message" -Value "$message" -MemberType NoteProperty   
  #$logItem | Add-Member -Name "Duration" -Value "$Timespan" -MemberType NoteProperty   
 
  $Global:outputLog += ,$logItem

	switch ($status)
	{
		"missing" {$host.ui.RawUI.ForegroundColor = "Yellow"}
		"error" {$host.ui.RawUI.ForegroundColor = "Red"}
		"success" {$host.ui.RawUI.ForegroundColor =  "Green"}
		default {$host.ui.RawUI.ForegroundColor = "Gray"}
	}

  return $logItem;
}

function Resolve-References{
  Param (
    [System.Xml.XmlNode] $node
  )

  [int]$lIndex = $node.ChildNodes.Count-1;
  for ($lIndex; $lIndex -ge 0; $lIndex--) {
    [System.Xml.XmlNode]$workNode = $node.ChildNodes.Item($lIndex);
    if ($workNode.NodeType -eq "Element") {
      switch ($workNode.Name) {
        "Reference" {
          $nodeResults = Select-ZPath -ZPath $workNode."#text";
          foreach ($foundNode in $nodeResults) 
          {
            [System.Xml.XmlNode] $cloneNode = $foundNode.CloneNode($true); 
            [System.Xml.XmlNode] $importedNode = $node.OwnerDocument.ImportNode($cloneNode, $true);
            Resolve-XML $importedNode;
            $workNode.ParentNode.AppendChild($importedNode) | Out-Null
          }
          $workNode.ParentNode.RemoveChild($workNode) | Out-Null
        }
        "Task" {}
        default {Resolve-XML -node $workNode}
      }
    }
  }
}

function Resolve-Variables{
  Param (
    [System.Xml.XmlNode] $node
  )
  foreach ($workNode in $node.ChildNodes) {
    if ($workNode.NodeType -eq "Text") {     
      [string]$workValue = $workNode.Value;
      while ($workValue -match "(?<=[\[][$]).+?(?=[$][\]])") {
        [string]$lMatch = $matches[0];
        [string]$lReplaceValue = Get-Variable -Name $lMatch -ValueOnly;

        [string]$lToken = "[`$$lMatch`$]";
        [string]$lNewValue = $workValue.Replace($lToken, $lReplaceValue);
        $workNode.Value = $lNewValue;
        $workValue = $lNewValue;
      }
    }
  }
}

function Resolve-TextReplacement{
  Param (
    [System.Xml.XmlNode] $node
  )

  foreach ($workNode in $node.ChildNodes) {
    if ($workNode.NodeType -eq "Text") {
      
      [string]$workValue = $workNode.Value;
      while ($workValue -match "(?<=[\[][%]).+?(?=[%][\]])") {
        [string]$lMatch = $matches[0];
        [string]$lToken = "[%$lMatch%]";

        [string]$lReplaceValue = Get-XMLValue -ZPath $lMatch;
        [string]$lNewValue = $workValue.Replace($lToken, $lReplaceValue);
        $workNode.Value = $lNewValue;
        $workValue = $lNewValue;
      }
    }
  }
}

function Resolve-XML {
  Param (
    [System.Xml.XmlNode] $node
  )
  Resolve-References $node
  Resolve-TextReplacement $node
  Resolve-Variables $node
}

function Get-XMLFile {
  param (
    [string] $ZPath
  )
  if ($ZPath -match ".*(?=[|][|])") {
    [string]$xmlFile = $matches[0];

    if ($ZPath -match "(?<=[|][|]).*") {
      [string]$xPathQuery = $matches[0]
    }
  } else {
    [string]$xmlFile = $makeFile;
    [string]$xPathQuery = $ZPath
  }
  [xml]$xml = Cache-XMLFile -fileName $xmlFile
  #Resolve-Embedded -node $xml.DocumentElement

  [xml]$xml
  [string]$xPathQuery
}

function Select-ZPath {
  Param (
    [string] $ZPath
  )
  $result = Get-XMLFile -ZPath $ZPath
  try {
    [string]$xpath = $result[1];
    return $result[0].SelectNodes($xpath);
  } catch {
    [string]$errorMessage = $_.$errorMessage;
    throw "[$xpath] $errorMessage"
  }
}

function Get-XMLValue {
  param(
    [string]$ZPath
  )
  try {
    $result = Get-XMLFile -ZPath $ZPath
    return $result[0].SelectSingleNode($result[1])."#text";
  } catch {
    [string]$errorMessage = $_.Exception.Message;
    throw "Unable to locate the single node at: $ZPath $errorMessage";
  }
}

function Make-Task {
  param (
    [System.Xml.XmlNode] $taskNode
  )

	[DateTime]$startTime = Get-Date;
  
  if (($null -eq $taskNode.exception.ExceptionAction) -or ($taskNode.exception.ExceptionAction -eq '')) {
    [string]$lExceptionAction = "Throw";
  } else {
    [string]$lExceptionAction = $taskNode.exception.ExceptionAction;
  };
  
  try {
    Resolve-XML -node $taskNode;
    [string]$action = $taskNode.action;
    
    #New-Variable -Name "CurrentTask" -Value $taskNode.Name -Scope Global -Force;
    if ($taskNode.type -eq "System") {

      $lParamHash = @{};
      foreach ($param in $taskNode.parameters.parameter) {
        $lParamHash.Add($param.parameter_name, $param.parameter_value);
      }
      
      [string]$lOutput = &"$action" @lParamHash;
    } else {
      &"$action" $taskNode
    }

    Make-Children -taskList $taskNode
    Put-OutputLog -task $taskNode -item $taskNode.name -status "success" -message "Completed." -starttime $startTime
  } catch {

    [System.Xml.XmlNode]$exceptionNode = $taskNode.SelectSingleNode("Exception");
    if ($taskNode.exception) {
      Make-Children -taskList $exceptionNode;
    }

    switch ($lExceptionAction) {
      "Throw" {
        Put-OutputLog -task $taskNode -status "error" -message $_.Exception.Message -starttime $startTime
        throw;
      }
      "Terminate" {
        Put-OutputLog -task $taskNode -status "error" -message $_.Exception.Message -starttime $startTime
        exit;
      }
      "Ignore" {}
    }
  }   
}

function Make-Children {
  param (
    [System.Xml.XmlNode] $taskList
  )
  foreach ($taskNode in $taskList.Tasks.Task) {
    if ($null -ne $taskNode) {
      [boolean]$lDoProcess = $false;
      if ($null -ne $taskNode.Targets) {
        foreach ($targetNode in $taskNode.Targets.Target) {
          if ($targetNode -eq $target) {
            $lDoProcess = $true;
          }
        }
      } else {
        $lDoProcess = $true;
      }
   
      if ($lDoProcess) {
        Make-Task -taskNode $taskNode
      }
    }
  }
}

function Cache-XMLFile {
  param (
    [string]$fileName
  )
  if (!($fileName -match '.*\.xml$')) {
    $fileName = "$fileName.xml"
  }
  if ($Global:xmlFiles.ContainsKey($fileName)) {
    [xml]$result = $Global:xmlFiles.Get_Item($fileName);
  } else {
    Push-Location $Global:startLocation
    [System.IO.Directory]::SetCurrentDirectory($Global:startLocation);
    [string]$LiteralName = [IO.Path]::GetFullPath($fileName);
    Pop-Location
    [System.IO.Directory]::SetCurrentDirectory(((Get-Location -PSProvider FileSystem).ProviderPath));

    if ($Global:xmlFiles.ContainsKey($LiteralName)) {
      [xml]$result = $Global:xmlFiles.Get_Item($LiteralName)
    } else {
      [xml]$result = Get-Content $LiteralName;  
      $Global:xmlFiles.Add($LiteralName, $result);
    }
  }
  return $result;
}

function Get-SafeName () {
  param (
    [string]$value
  )
  [string]$result = [IO.Path]::GetFullPath($value);
  $result = $result -replace '[.\\/:]', '_';
  
  return $result
}

function Lock-File {
  try {   
    $oFile = New-Object System.IO.FileInfo $Global:lock;
    $oStream = $oFile.Open([System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
    if ($oStream) {
      $oStream.Close();
      Remove-Item $Global:lock;
      Out-File -FilePath $Global:lock -InputObject "User: $env:username`nDomain: $env:userdomain`nComputerName: $env:computername`n";
      $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
      if ($oStream) {
        return $oStream;
      }
	  }
  } catch {}
	return $false;  
}

function Queue-Build {
  Out-File -Append -FilePath $Global:queuelog -InputObject "User: $env:username`nDomain: $env:userdomain`nComputerName: $env:computername`n------------------`n";
}

function Write-OutputLog {
  if (Test-Path "./$makeFile.log" -PathType Leaf) {
    Remove-Item "./$makeFile.log"
  }
  Add-Content -path "./$makeFile.log" $outputLog;
}

function Write-CompiledXml {
  if (Test-Path "./$makeFile.compiled.xml" -PathType Leaf) {
    Remove-Item "./$makeFile.compiled.xml"
  }
  $xml.Save("./$makeFile.compiled.xml");
}

function Make-All {
  if (Test-Path -Path "$makeFile") {
    $testLock = Lock-File -file $lock;
    if ($testLock) {
      try {
        $color = $host.ui.RawUI.ForegroundColor;  
        try {
          Make-Children -taskList $xml.make         
        } finally {
          Write-CompiledXml
          Write-OutputLog;
          $host.ui.RawUI.ForegroundColor = $color;
        }
      } finally {
        $testLock.Close();
      }
    } else {
      Write-Host "The $makeFile build is already locked/running:";
      Get-Content -Path $Global:lock | Write-Host
      if ($queue) {
        Write-Host "---"
        Write-Host "You're queue request has been logged and a fresh build will begin as soon as this one is complete."
        Queue-Build;
      }
      Exit;
    }
  } else {
    Write-Host "$makeFile not found."
  }
}

<#- Prerequisites -#>
Import-Module -Name "$PSScriptRoot\SystemTasks.psm1"
<#- Main -#>
Write-Host $target

$Global:xmlFiles = @{};
$Global:outputLog = @();
$Global:makePath = $pwd.Path;

[string]$originalForegroundColor = $host.ui.RawUI.ForegroundColor;
try {
  [string]$Global:startLocation = ((Get-Location -PSProvider FileSystem).ProviderPath);
  [string]$Global:lockName = Get-SafeName -value $makeFile;
  [string]$Global:lock = "$env:TEMP\psMake.$lockName.lock"
  [string]$Global:queuelog = "$env:TEMP\psMake.$lockName.queue"

  [xml]$xml = Cache-XMLFile -fileName $makeFile
  $Global:xmlFiles.Add("",  [xml]$xml);
  $Global:xmlFiles.Add("make.xml", [xml]$xml);
  $Global:xmlFiles.Add("make", [xml]$xml);

  Clear-Host;
  Make-All;
  
  while (Test-Path -Path $Global:queuelog) {
    Write-Host "============================"
    Write-Host "Building for the following queued requests:"
    Get-Content $Global:queuelog | Write-Host
    Write-Host "============================"
    Remove-Item $Global:queuelog
    Make-All;
  }
}
finally {
  $host.ui.RawUI.ForegroundColor = $originalForegroundColor;
}
