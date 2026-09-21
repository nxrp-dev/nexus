import * as vscode from 'vscode';
import { LazarusProjectCommandHandler } from './commandHandlers/lazarusProjectCommandHandler';
import { LanguageServerCommandHandler } from './commandHandlers/languageServerCommandHandler';
import { LazarusTestModuleCommandHandler } from './commandHandlers/lazarusTestModuleCommandHandler';
import { ProjectCommandHandler } from './commandHandlers/projectCommandHandler';
import { ToolchainCommandHandler } from './commandHandlers/toolchainCommandHandler';
import { LanguageClientHandle } from './services/languageClientHandle';

export class FpcCommandManager {
    private readonly projectCommands: ProjectCommandHandler;
    private readonly languageServerCommands: LanguageServerCommandHandler;
    private readonly lazarusTestModuleCommands: LazarusTestModuleCommandHandler;
    private readonly lazarusProjectCommands: LazarusProjectCommandHandler;
    private readonly toolchainCommands: ToolchainCommandHandler;

    public constructor(
        workspaceRoot: string,
        languageClient: LanguageClientHandle
    ) {
        this.projectCommands = new ProjectCommandHandler(workspaceRoot, languageClient);
        this.languageServerCommands = new LanguageServerCommandHandler(languageClient);
        this.lazarusTestModuleCommands = new LazarusTestModuleCommandHandler(workspaceRoot);
        this.lazarusProjectCommands = new LazarusProjectCommandHandler();
        this.toolchainCommands = new ToolchainCommandHandler(workspaceRoot, languageClient);
    }

    public registerAll(context: vscode.ExtensionContext): void {
        this.projectCommands.register(context);
        this.languageServerCommands.register(context);
        this.lazarusTestModuleCommands.register(context);
        this.lazarusProjectCommands.register(context);
        this.toolchainCommands.register(context);
    }
}
