/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { CompileOption } from '../languageServer/options';
import { LanguageServerProjectContext } from '../languageServer/projectContext';
import { NexusProjectModel, PascalBuildTarget, PascalProject } from '../model/pascalProject';
import { NexusTaskProvider } from '../vscode/vscodeTaskProvider';
import { PascalProjectAdapter, ProjectCollection } from './pascalProjectAdapter';

export class NexusProjectAdapter implements PascalProjectAdapter {
    public readonly kind = 'nexus' as const;

    public constructor(
        private readonly workspaceRoot: string,
        private readonly taskProvider: NexusTaskProvider
    ) {
    }

    public collectProjects(collection: ProjectCollection): void {
        for (const descriptorFile of this.findDescriptorFiles(this.workspaceRoot)) {
            const project = this.createProject(descriptorFile);
            collection.projectsByFile.set(project.id, project);
        }
    }

    public createTask(target: PascalBuildTarget, taskName?: string): vscode.Task | undefined {
        if (target.kind !== this.kind) {
            return undefined;
        }

        return this.taskProvider.getTask(taskName || target.label, {
            type: 'nexus',
            project: target.projectFile,
            cwd: this.getProjectRoot(target.projectFile)
        });
    }

    public createCompileOption(_target: PascalBuildTarget | undefined): CompileOption {
        return new CompileOption();
    }

    public createLanguageServerContext(target: PascalBuildTarget | undefined): LanguageServerProjectContext {
        return {
            kind: this.kind,
            label: target?.label || '',
            projectFile: '',
            workingDirectory: target ? this.getProjectRoot(target.projectFile) : this.workspaceRoot,
            fpcOptions: [],
            allowFpcGlobalUnitPaths: true
        };
    }

    public getProjectContextValue(_project: PascalProject): string {
        return 'nexusproject';
    }

    public getTargetContextValue(_target: PascalBuildTarget): string {
        return 'nexustarget';
    }

    private createProject(descriptorFile: string): NexusProjectModel {
        const projectRoot = this.getProjectRoot(descriptorFile);
        const label = path.basename(descriptorFile) === 'project.nxp'
            ? path.basename(projectRoot)
            : path.basename(descriptorFile, path.extname(descriptorFile));

        return {
            id: descriptorFile,
            kind: this.kind,
            label,
            file: descriptorFile,
            descriptorFile,
            fileExists: fs.existsSync(descriptorFile),
            isDefault: false,
            targets: [
                {
                    id: `${descriptorFile}::Project`,
                    kind: this.kind,
                    label: 'Project',
                    projectId: descriptorFile,
                    projectFile: descriptorFile,
                    descriptorFile,
                    isDefault: false,
                    isInProjectFile: true,
                    canBuild: true
                }
            ]
        };
    }

    private getProjectRoot(descriptorFile: string): string {
        return path.dirname(descriptorFile);
    }

    private findDescriptorFiles(root: string): string[] {
        const results: string[] = [];
        this.walkDirectories(root, directory => {
            const baseName = path.basename(directory).toLowerCase();
            if (baseName === '.nexus') {
                const descriptorFile = path.join(directory, 'project.nxp');
                if (fs.existsSync(descriptorFile)) {
                    results.push(descriptorFile);
                }
                return;
            }

            for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
                if (entry.isFile() && path.extname(entry.name).toLowerCase() === '.nxp') {
                    results.push(path.join(directory, entry.name));
                }
            }
        });
        return results;
    }

    private walkDirectories(root: string, callback: (directory: string) => void): void {
        if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
            return;
        }

        callback(root);
        for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
            if (!entry.isDirectory() || this.shouldSkipDirectory(entry.name)) {
                continue;
            }

            this.walkDirectories(path.join(root, entry.name), callback);
        }
    }

    private shouldSkipDirectory(name: string): boolean {
        return ['.git', '.svn', '.hg', 'node_modules', 'out', 'output', 'dist'].includes(name.toLowerCase());
    }
}
