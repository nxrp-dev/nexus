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

type LspPosition = {
    line: number;
    character: number;
};

type LspRange = {
    start: LspPosition;
    end: LspPosition;
};

type LspLocation = {
    uri: string;
    range: LspRange;
};

export class LanguageServerCommandHandler {
    public constructor(private readonly languageClient: LanguageClientHandle) {
    }

    public register(context: vscode.ExtensionContext): void {
        context.subscriptions.push(
            vscode.commands.registerTextEditorCommand('nexusPascal.code.complete', this.codeComplete),
            vscode.commands.registerTextEditorCommand('nexusPascal.routine.gotoImplementation', this.gotoRoutineImplementation),
            vscode.commands.registerTextEditorCommand('nexusPascal.routine.gotoDeclaration', this.gotoRoutineDeclaration)
        );
    }

    private codeComplete = (textEditor: vscode.TextEditor): void => {
        this.languageClient.completeCode(textEditor);
    };

    private gotoRoutineImplementation = async (textEditor: vscode.TextEditor): Promise<void> => {
        await this.gotoRoutinePair(textEditor, 'nexusls.routine.gotoImplementation');
    };

    private gotoRoutineDeclaration = async (textEditor: vscode.TextEditor): Promise<void> => {
        await this.gotoRoutinePair(textEditor, 'nexusls.routine.gotoDeclaration');
    };

    private async gotoRoutinePair(textEditor: vscode.TextEditor, method: string): Promise<void> {
        const position = textEditor.selection.active;
        const location = await this.languageClient.sendCustomRequest<LspLocation | null>(method, {
            textDocument: {
                uri: textEditor.document.uri.toString()
            },
            position: {
                line: position.line,
                character: position.character
            }
        });

        if (!location) {
            return;
        }

        await this.revealLocation(location);
    }

    private async revealLocation(location: LspLocation): Promise<void> {
        const uri = vscode.Uri.parse(location.uri);
        const range = new vscode.Range(
            new vscode.Position(location.range.start.line, location.range.start.character),
            new vscode.Position(location.range.end.line, location.range.end.character)
        );
        const editor = await vscode.window.showTextDocument(uri, { selection: range });
        editor.revealRange(range, vscode.TextEditorRevealType.InCenterIfOutsideViewport);
    }
}
