import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import {
    CloseAction,
    CloseHandlerResult,
    ErrorAction,
    ErrorHandler,
    ErrorHandlerResult,
    LanguageClient,
    Message,
    State
} from 'vscode-languageclient/node';
import { ExtensionPaths } from '../services/extensionPaths';
import { prepareServerExecutable, ServerExecutableResolver } from './serverExecutable';
import { createServerOptions } from './serverOptions';
import {
    NexusScriptDialectModel,
    NexusScriptDocumentModel,
    NexusScriptSemanticEdit,
    NexusScriptSemanticEditParams,
    NexusScriptTarget
} from './nexusScriptProtocol';

export class NexusScriptLanguageClientService implements ErrorHandler, vscode.Disposable {
    private client?: LanguageClient;
    private readonly resolver: ServerExecutableResolver;
    private readonly extensionPaths: ExtensionPaths;

    public constructor(
        extensionPaths: ExtensionPaths,
        private readonly logger: vscode.OutputChannel
    ) {
        this.extensionPaths = extensionPaths;
        this.resolver = new ServerExecutableResolver(extensionPaths, 'nexusscriptls');
    }

    public error(error: Error, _message: Message | undefined,
        _count: number | undefined): ErrorHandlerResult {
        this.logger.appendLine(`NexusScriptLS: ${error.message}`);
        return { action: ErrorAction.Continue } as ErrorHandlerResult;
    }

    public closed(): CloseHandlerResult {
        this.logger.appendLine('NexusScriptLS closed.');
        return { action: CloseAction.Restart } as CloseHandlerResult;
    }

    public async start(): Promise<void> {
        const executable = this.resolver.resolve().executable;
        if (!prepareServerExecutable(executable, this.logger)) {
            return;
        }
        const installedDialectRoot = path.resolve(path.dirname(executable),
            '..', 'sdk', 'NexusLib', 'script', 'dialects');
        const bundledDialectRoot = this.extensionPaths.getFilePath('dialects');
        const dialectRoot = fs.existsSync(installedDialectRoot)
            ? installedDialectRoot
            : bundledDialectRoot;
        this.client = new LanguageClient(
            'nexusPascal.nexusScriptLanguageServer',
            'NexusScript Language Server',
            createServerOptions(executable, {}, [`/dialect-root=${dialectRoot}`]),
            {
                documentSelector: [
                    { scheme: 'file', language: 'nexusscript' },
                    { scheme: 'untitled', language: 'nexusscript' }
                ],
                errorHandler: this,
                outputChannel: this.logger
            }
        );
        await this.client.start();
        await this.applyTargetConfiguration();
        this.logger.appendLine('NexusScript language server initialized successfully');
    }

    public async stop(): Promise<void> {
        if (this.client?.state === State.Running) {
            await this.client.stop(10000);
        }
        this.client?.dispose();
        this.client = undefined;
    }

    public documentModel(uri: string): Promise<NexusScriptDocumentModel> {
        if (!this.client) {
            return Promise.reject(new Error('NexusScriptLS is not running.'));
        }
        return this.client.sendRequest('nexusscript/documentModel', {
            textDocument: { uri }
        });
    }

    public dialectModel(uri: string): Promise<NexusScriptDialectModel> {
        if (!this.client) {
            return Promise.reject(new Error('NexusScriptLS is not running.'));
        }
        return this.client.sendRequest('nexusscript/dialectModel', {
            textDocument: { uri }
        });
    }

    public async setTargets(targets: NexusScriptTarget[]): Promise<void> {
        if (!this.client) {
            throw new Error('NexusScriptLS is not running.');
        }
        await this.client.sendRequest('nexusscript/setTargets', { targets });
    }

    public async applyTargetConfiguration(): Promise<void> {
        const targets = vscode.workspace
            .getConfiguration('nexusPascal.nexusScript')
            .get<NexusScriptTarget[]>('targets', []);
        await this.setTargets(targets);
    }

    public semanticEdit(params: NexusScriptSemanticEditParams):
        Promise<NexusScriptSemanticEdit> {
        if (!this.client) {
            return Promise.reject(new Error('NexusScriptLS is not running.'));
        }
        return this.client.sendRequest('nexusscript/semanticEdit', params);
    }

    public dispose(): void {
        void this.stop();
    }
}
