/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import * as vscode from 'vscode';
import { PascalBuildTarget } from '../model/pascalProject';
import { PascalProjectAdapterRegistry } from '../projectTypes/pascalProjectAdapter';
import { BuildMode, FpcTask, LazarusTask } from '../vscode/vscodeTask';

export class PascalTaskFactory {
    public constructor(private readonly adapters: PascalProjectAdapterRegistry) {
    }

    public createTask(target: PascalBuildTarget, taskName?: string, buildMode: BuildMode = BuildMode.normal): vscode.Task | undefined {
        if (!target.canBuild) {
            return undefined;
        }

        const task = this.adapters.get(target.kind).createTask(target, taskName);
        if (task instanceof FpcTask || task instanceof LazarusTask) {
            task.BuildMode = buildMode;
        }

        return task;
    }
}
