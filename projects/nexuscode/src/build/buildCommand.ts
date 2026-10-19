/*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

export type CompilerKind = 'fpc' | 'lazbuild' | 'nxbuild';

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
