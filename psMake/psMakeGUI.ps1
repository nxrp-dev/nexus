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

&"$PSScriptRoot/psMake.ps1" $makeFile $target $queue | Out-GridView -Title "Build Makefile: $makeFile Target: $target"
