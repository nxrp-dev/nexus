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
import type { PascalLanguageClientService } from '../languageServer/client';

export class EditorIntegrationService implements vscode.Disposable {
    private readonly disposables: vscode.Disposable[] = [];

    public constructor(
        private readonly getClient: () => PascalLanguageClientService | undefined,
        private readonly logger: vscode.OutputChannel
    ) {}

    public register(): void {
        this.disposables.push(
            vscode.window.onDidChangeVisibleTextEditors(editors => this.onDidChangeVisibleTextEditors(editors))
        );
    }

    public dispose(): void {
        this.disposables.splice(0).forEach(disposable => disposable.dispose());
    }

    private onDidChangeVisibleTextEditors(editors: readonly vscode.TextEditor[]): void {
        for (const editor of editors) {
            if (!this.isPascalEditor(editor)) {
                continue;
            }

            this.logger.appendLine(`Visible Pascal editor: ${editor.document.languageId} ${editor.document.uri.fsPath}`);
            this.getClient()?.onDidChangeVisibleTextEditor(editor);
        }
    }

    private isPascalEditor(editor: vscode.TextEditor): boolean {
        return editor.document.uri.scheme === 'file'
            && (editor.document.languageId === 'objectpascal' || editor.document.languageId === 'pascal');
    }
}
