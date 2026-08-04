<#
  Copyright (c) 2014 Kevin Collins

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
#>

function CreateDelphiResourceFile() {
	Param(
		[string]$fileName,
    [string]$major,
    [string]$minor,
    [string]$patch,
    [string]$build
	)

  [string]$lFolder = Split-Path $fileName; 
  [string]$lOriginalFilename = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

  [string]$lIconFilename = "$lFolder\$lOriginalFilename.ico"
  [string]$lResourceFilename = "$lFolder\$lOriginalFilename.rc"

  if (!(Test-Path -Path $lIconFilename)) {
    $lIconFilename = "";
  };

  [string]$lResource = "";
  
  $lResource += "MAINICON ICON `"$lIconFilename`"`n";
  $lResource += "VS_VERSION_INFO VERSIONINFO";
  $lResource += "FILEVERSION $major,$minor,$patch,$build`n";
  $lResource += "PRODUCTVERSION $major,$minor,$patch,$build`n";
  $lResource += "FILEFLAGSMASK VS_FFI_FILEFLAGSMASK`n";
  $lResource += "FILEFLAGS 0`n";
  $lResource += "FILEOS VFT_APP`n";
  $lResource += "FILESUBTYPE VFT2_UNKNOWN`n";
  $lResource += "BEGIN`n";
  $lResource += "  BLOCK `"VerFileInfo`"`n";
  $lResource += "  BEGIN`n";
  $lResource += "    Value `"TRANSLATION`", 0x0409, 1252`n";
  $lResource += "  END`n";
  $lResource += "  BLOCK `"STRINGFILEINFO`"`n";
  $lResource += "  BEGIN`n";
  $lResource += "    BLOCK `"040904E4`"`n";
  $lResource += "    BEGIN`n";  
  $lResource += "      VALUE `"CompanyName`", `"\0`"`n";
  $lResource += "      VALUE `"FileDescription`", `"\0`"`n";
  $lResource += "      VALUE `"FileVersion`", `"$major.$minor.$patch.$build\0`"`n";
  $lResource += "      VALUE `"InternalName`", `"\0`"`n";
  $lResource += "      VALUE `"LegalCopyright`", `"\0`"`n";
  $lResource += "      VALUE `"LegalTrademarks`", `"\0`"`n";
  $lResource += "      VALUE `"OriginalFileName`", `"$lOriginalFilename\0`"`n";
  $lResource += "      VALUE `"ProductName`", `"\0`"`n";
  $lResource += "      VALUE `"ProductVersion`", `"$major.$minor.$patch.$build\0`"`n";
  $lResource += "      VALUE `"Comments`", `"\0`"`n";
  $lResource += "    END`n";
  $lResource += "  END`n";
  $lResource += "END`n";

  $lResource | out-file -encoding ASCII -Force "$lResourceFilename"
}

function CreateDelphiConfigFile() {
  param (
    [string]$fileName,
    [System.Xml.XmlNode] $taskNode
  )
  [string]$lConfig = "";
 
  foreach ($libNode in $taskNode.library.path) {   
    [string] $lNodeValue = $libNode;
    $lConfig += "-U`""+$lNodeValue+"`"`n";
    $lConfig += "-O`""+$lNodeValue+"`"`n";
    $lConfig += "-I`""+$lNodeValue+"`"`n";
    $lConfig += "-R`""+$lNodeValue+"`"`n";
  }

  foreach ($flagNode in $taskNode.flags.flag) {   
    [string] $flagValue = $flagNode;
    $lConfig += "$flagValue`n";
  }

  [string] $lBinaryOutput = $taskNode.target_output_path;
  [string] $lWorkOutput = $taskNode.work_output_path;

  $lConfig += "-E`""+$lBinaryOutput+"`"`n";
  $lConfig += "-LE`""+$lBinaryOutput+"`"`n";
  $lConfig += "-N`""+$lWorkOutput+"`"`n";   
  
  [string]$lFolder = Split-Path $fileName; 
  [string]$lOriginalFilename = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

  [string]$lConfigFilename = "$lFolder\$lOriginalFilename.cfg"
  $lConfig | out-file -encoding ASCII -Force "$lConfigFilename"
}

function Invoke-Delphi {
 	param (   
   	[System.Xml.XmlNode] $taskNode
 	)
  
  [string]$actionExecutable = $configurationNode.action_executable;
 
	foreach ($fileNode in $taskNode.files.file) {
	  [string] $fileName = $fileNode;

    $targetFiles = Get-ChildItem -Path $fileName
    foreach ($targetFile in $targetFiles) 
    {
      [string]$fileName = $targetFile;
    
      CreateDelphiResourceFile -fileName $targetFile -major "10" -minor "1" -patch "1" -build "1"
      CreateDelphiConfigFile -fileName $targetFile -taskNode $taskNode

    	if (Test-Path -Path "$fileName") {
        [string]$lFolder = Split-Path $fileName; 
        Push-Location $lFolder;
        try {
          	[string]$result = &"dcc32.exe" "-b" "$fileName"

        	if (!$?) 
      		{
           		throw $result;
    		}
        } finally {
          Pop-Location;
        }
      } else {
        throw "Project not found."
      }      
    }
  }
}