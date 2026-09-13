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
