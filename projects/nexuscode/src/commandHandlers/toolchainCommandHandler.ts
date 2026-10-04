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
import { LanguageClientHandle } from '../services/languageClientHandle';
import { ToolchainPanel } from '../toolchain/toolchainPanel';

export class ToolchainCommandHandler {
    private extensionUri: vscode.Uri | undefined;

    public constructor(
        private readonly workspaceRoot: string,
        private readonly languageClient: LanguageClientHandle
    ) {
    }

    public register(context: vscode.ExtensionContext): void {
        this.extensionUri = context.extensionUri;
        context.subscriptions.push(vscode.commands.registerCommand(
            'nexusPascal.toolchain.configure',
            () => this.showToolchainWizard()
        ));
    }

    private showToolchainWizard = async (): Promise<void> => {
        try {
            await ToolchainPanel.show(
                this.extensionUri || vscode.Uri.file(this.workspaceRoot),
                this.languageClient
            );
        } catch (error) {
            vscode.window.showErrorMessage(`Failed to configure toolchains: ${error}`);
        }
    };
}
