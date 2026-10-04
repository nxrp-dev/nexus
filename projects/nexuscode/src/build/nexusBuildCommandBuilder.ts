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
import { BuildCommand } from './buildCommand';
import { NexusTaskDefinition } from '../providers/taskDefinitions';
import { ExtensionPaths } from '../services/extensionPaths';
import { createToolchainEnvironment, resolvePascalToolchain } from '../toolchain/toolchainResolver';

export class NexusBuildCommandBuilder {
    public constructor(private readonly extensionPaths: ExtensionPaths) {
    }

    public createCommand(cwd: string, taskDefinition: NexusTaskDefinition): BuildCommand {
        return {
            executable: this.resolveExecutable(),
            args: ['/action=build', `/project=${taskDefinition.project}`],
            cwd,
            compilerKind: 'nexusbuild',
            env: createToolchainEnvironment(resolvePascalToolchain())
        };
    }

    private resolveExecutable(): string {
        const platform = process.platform;
        const arch = process.arch;
        const targetCPU = arch === 'x64'
            ? 'x86_64'
            : arch === 'arm64'
                ? platform === 'win32' ? 'x86_64' : 'aarch64'
                : arch;
        const targetOS = platform === 'win32'
            ? 'win64'
            : platform;
        const executableName = platform === 'win32' ? 'nexusbuild.exe' : 'nexusbuild';

        return path.resolve(
            this.extensionPaths.getFilePath('bin'),
            `${targetCPU}-${targetOS}`,
            executableName
        );
    }
}
