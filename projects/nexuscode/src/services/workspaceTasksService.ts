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
import * as vscode from 'vscode';
import {
    isFpcTaskDefinition,
    isLazarusTaskDefinition,
    NexusTaskDefinition
} from '../providers/taskDefinitions';

export class WorkspaceTasksService {
    public constructor(private readonly workspaceRoot: string) {
    }

    public getAllTasks(resource?: vscode.Uri): any[] {
        return vscode.workspace
            .getConfiguration('tasks', resource ?? vscode.Uri.file(this.workspaceRoot))
            .get<any[]>('tasks', []);
    }

    public getTasks(): NexusTaskDefinition[] {
        return this.getAllTasks().filter((task): task is NexusTaskDefinition => this.isNexusPascalTask(task));
    }

    public getTaskLabel(task: any): string | undefined {
        const label = task?.label ?? task?.taskName;
        return typeof label === 'string' ? label : undefined;
    }

    public getDefaultBuildTask(tasks: any[] = this.getAllTasks()): any | undefined {
        return tasks.find(task => this.isDefaultBuildTask(task));
    }

    public isDefaultBuildTask(task: any): boolean {
        return typeof task?.group === 'object'
            && task.group.kind === 'build'
            && task.group.isDefault === true;
    }

    public hasDefaultBuildTask(tasks: any[]): boolean {
        return tasks.some(task => this.isDefaultBuildTask(task));
    }

    public isNexusPascalTask(task: any): task is NexusTaskDefinition {
        return isFpcTaskDefinition(task) || isLazarusTaskDefinition(task);
    }

    public resolveWorkspacePath(value: string | undefined, basePath: string = this.workspaceRoot): string {
        if (!value) {
            return basePath;
        }

        const resolved = value.replace(/\$\{workspaceFolder\}/g, this.workspaceRoot);
        if (path.isAbsolute(resolved)) {
            return resolved;
        }

        return path.resolve(basePath, resolved);
    }

}
