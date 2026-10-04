/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

export type CompilerKind = 'fpc' | 'lazbuild' | 'nexusbuild';

export interface BuildCommand {
    executable: string;
    args: string[];
    cwd: string;
    compilerKind: CompilerKind;
    env?: Record<string, string | undefined>;
}

export function formatBuildCommand(command: BuildCommand): string {
    return [command.executable, ...command.args]
        .map(argument => argument.includes(' ') ? `"${argument}"` : argument)
        .join(' ');
}
