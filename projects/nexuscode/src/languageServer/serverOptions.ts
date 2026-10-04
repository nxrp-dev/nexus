/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import {
    ErrorHandler,
    Executable,
    LanguageClientOptions,
    ServerOptions
} from 'vscode-languageclient/node';
import * as vscode from 'vscode';
import { InitializationOptions } from './options';
import { ServerEnvironment } from './serverEnvironment';

export function createServerOptions(executable: string, envVars: ServerEnvironment,
    args: string[] = []): ServerOptions {
    const run: Executable = {
        command: executable,
        args,
        options: {
            env: {
                ...process.env,
                ...envVars
            }
        }
    };

    return {
        run,
        debug: run
    };
}

export function createLanguageClientOptions(
    initializationOptions: InitializationOptions,
    errorHandler: ErrorHandler,
    outputChannel: vscode.OutputChannel,
    traceOutputChannel: vscode.OutputChannel
): LanguageClientOptions {
    return {
        initializationOptions,
        errorHandler,
        outputChannel,
        traceOutputChannel,
        documentSelector: [
            { scheme: 'file', language: 'objectpascal' },
            { scheme: 'untitled', language: 'objectpascal' },
            { scheme: 'file', language: 'pascal' },
            { scheme: 'untitled', language: 'pascal' }
        ]
    };
}
