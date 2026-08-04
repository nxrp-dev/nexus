<#
  Copyright (c) 2014 Kevin Collins, Metaphor Systems, Inc.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
#>

function Restart-IIS {
  Start-Process -FilePath "iisreset.exe" -NoNewWindow -Wait -ErrorVariable errorMessage

  if ($errorMessage) {
    throw "Restart-IIS Exception: $errorMessage"
  }
}
