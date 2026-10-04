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
import * as path from 'path';
import { NexusProjectRemoteWizardDefinition } from '../projectCreation/nexusProjectRemoteWizardDefinition';
import { LanguageClientHandle } from '../services/languageClientHandle';
import { WizardPanel } from '../wizard/wizardPanel';

export class ProjectCommandHandler {
    private extensionUri: vscode.Uri | undefined;

    public constructor(
        private readonly workspaceRoot: string,
        private readonly languageClient: LanguageClientHandle
    ) {
    }

    public register(context: vscode.ExtensionContext): void {
        this.extensionUri = context.extensionUri;
        context.subscriptions.push(vscode.commands.registerCommand(
            'nexusPascal.project.newNexusProject',
            () => this.showNexusProjectWizard()
        ));
        context.subscriptions.push(vscode.commands.registerCommand(
            'nexusPascal.project.importLazarusProject',
            (resource?: vscode.Uri) => this.showLazarusImportWizard(resource)
        ));
    }

    private showNexusProjectWizard = async (): Promise<void> => {
        try {
            await WizardPanel.show(
                this.extensionUri || vscode.Uri.file(this.workspaceRoot),
                new NexusProjectRemoteWizardDefinition(this.languageClient, this.workspaceRoot)
            );
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to create project: ${error}`);
        }
    };

    private showLazarusImportWizard = async (resource?: vscode.Uri): Promise<void> => {
        try {
            const lpiFile = await this.resolveLazarusProjectFile(resource);
            if (!lpiFile) {
                return;
            }

            await WizardPanel.show(
                this.extensionUri || vscode.Uri.file(this.workspaceRoot),
                new NexusProjectRemoteWizardDefinition(
                    this.languageClient,
                    this.workspaceRoot,
                    {
                        kind: 'lazarus',
                        lpiFile,
                        projectName: path.basename(lpiFile, path.extname(lpiFile)),
                        targetDir: path.dirname(lpiFile)
                    }
                )
            );
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to import Lazarus project: ${error}`);
        }
    };

    private async resolveLazarusProjectFile(resource?: vscode.Uri): Promise<string | undefined> {
        if (resource?.fsPath && path.extname(resource.fsPath).toLowerCase() === '.lpi') {
            return resource.fsPath;
        }

        const selected = await vscode.window.showOpenDialog({
            title: 'Select Lazarus Project',
            defaultUri: vscode.Uri.file(this.workspaceRoot),
            canSelectFiles: true,
            canSelectFolders: false,
            canSelectMany: false,
            filters: {
                'Lazarus project files': ['lpi']
            }
        });

        return selected?.[0]?.fsPath;
    }
}
