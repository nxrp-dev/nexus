/*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import * as vscode from 'vscode';
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
}
