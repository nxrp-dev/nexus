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
import { CompileOption } from '../languageServer/options';
import { LanguageServerProjectContext } from '../languageServer/projectContext';
import { PascalBuildTarget, PascalProject, PascalProjectKind } from '../model/pascalProject';

export interface ProjectCollection {
    projectsByFile: Map<string, PascalProject>;
}

export interface PascalProjectAdapter {
    readonly kind: PascalProjectKind;

    collectProjects(collection: ProjectCollection): void;
    createTask(target: PascalBuildTarget, taskName?: string): vscode.Task | undefined;
    createCompileOption(target: PascalBuildTarget | undefined): CompileOption;
    createLanguageServerContext(target: PascalBuildTarget | undefined): LanguageServerProjectContext;

    getProjectContextValue(project: PascalProject): string;
    getTargetContextValue(target: PascalBuildTarget): string;
}

export class PascalProjectAdapterRegistry {
    private readonly adapters = new Map<PascalProjectKind, PascalProjectAdapter>();

    public register(adapter: PascalProjectAdapter): void {
        this.adapters.set(adapter.kind, adapter);
    }

    public all(): PascalProjectAdapter[] {
        return Array.from(this.adapters.values());
    }

    public get(kind: PascalProjectKind): PascalProjectAdapter {
        const adapter = this.adapters.get(kind);
        if (!adapter) {
            throw new Error(`Unsupported Pascal project kind: ${kind}`);
        }

        return adapter;
    }

    public tryGet(kind: PascalProjectKind | undefined): PascalProjectAdapter | undefined {
        return kind ? this.adapters.get(kind) : undefined;
    }
}
