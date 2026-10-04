/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import * as path from 'path';

export function resolveWorkspacePath(cwd: string, value: string | undefined): string | undefined {
    if (!value) {
        return value;
    }

    const resolved = value.replace(/\$\{workspaceFolder\}/g, cwd);
    return path.isAbsolute(resolved) ? resolved : path.join(cwd, resolved);
}

export function resolveWorkspaceValue(cwd: string, value: string | undefined): string | undefined {
    return value?.replace(/\$\{workspaceFolder\}/g, cwd);
}
