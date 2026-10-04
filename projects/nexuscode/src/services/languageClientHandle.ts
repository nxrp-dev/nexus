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
import { PascalLanguageClientService } from '../languageServer/client';

export class LanguageClientHandle {
    private client?: PascalLanguageClientService;

    public get current(): PascalLanguageClientService | undefined {
        return this.client;
    }

    public set(client: PascalLanguageClientService | undefined): void {
        this.client = client;
    }

    public async restart(): Promise<void> {
        await this.client?.restart();
    }

    public async completeCode(editor: vscode.TextEditor): Promise<void> {
        await this.client?.doCodeComplete(editor);
    }

    public async executeCommand<T = unknown>(command: string, args: unknown[] = []): Promise<T> {
        if (!this.client) {
            throw new Error('Language server is not available.');
        }

        return this.client.executeCommand<T>(command, args);
    }

    public async sendCustomRequest<T = unknown>(method: string, params?: unknown): Promise<T> {
        if (!this.client) {
            throw new Error('Language server is not available.');
        }

        return this.client.sendCustomRequest<T>(method, params);
    }
}
