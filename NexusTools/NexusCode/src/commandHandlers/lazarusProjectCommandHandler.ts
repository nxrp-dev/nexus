import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { XMLParser } from 'fast-xml-parser';
import { LazarusTaskDefinition } from '../providers/taskDefinitions';
import { LazarusTask } from '../vscode/vscodeTask';

export class LazarusProjectCommandHandler {
    public register(context: vscode.ExtensionContext): void {
        context.subscriptions.push(
            vscode.commands.registerCommand(
                'nexusPascal.project.buildLazarusProject',
                (resource?: vscode.Uri) => this.buildProject(resource)
            ),
            vscode.commands.registerCommand(
                'nexusPascal.project.runLazarusProject',
                (resource?: vscode.Uri) => this.runProject(resource)
            )
        );
    }

    private async buildProject(resource?: vscode.Uri): Promise<number | undefined> {
        const projectFile = this.resolveProjectFile(resource);
        if (!projectFile) {
            vscode.window.showErrorMessage('Select a Lazarus .lpi project file.');
            return undefined;
        }

        const task = this.createBuildTask(projectFile);
        const execution = await vscode.tasks.executeTask(task);
        return this.waitForTask(execution);
    }

    private async runProject(resource?: vscode.Uri): Promise<void> {
        const projectFile = this.resolveProjectFile(resource);
        if (!projectFile) {
            vscode.window.showErrorMessage('Select a Lazarus .lpi project file.');
            return;
        }

        const exitCode = await this.buildProject(resource);
        if (exitCode !== 0) {
            vscode.window.showErrorMessage(`Build failed with exit code ${exitCode}.`);
            return;
        }

        const executable = this.resolveExecutable(projectFile);
        if (!executable || !fs.existsSync(executable)) {
            vscode.window.showErrorMessage(`Build completed, but the target executable was not found for ${path.basename(projectFile)}.`);
            return;
        }

        const terminal = vscode.window.createTerminal({
            name: `Run ${path.basename(executable)}`,
            cwd: path.dirname(executable),
            shellPath: executable
        });
        terminal.show();
    }

    private createBuildTask(projectFile: string): vscode.Task {
        const definition = new LazarusTaskDefinition();
        definition.project = projectFile;
        definition.cwd = path.dirname(projectFile);
        definition.buildMode = 'Default';

        return new LazarusTask(
            path.dirname(projectFile),
            `Build ${path.basename(projectFile)}`,
            definition
        );
    }

    private resolveProjectFile(resource?: vscode.Uri): string | undefined {
        const candidate = resource?.fsPath
            || vscode.window.activeTextEditor?.document.uri.fsPath;

        if (!candidate || path.extname(candidate).toLowerCase() !== '.lpi') {
            return undefined;
        }

        return candidate;
    }

    private resolveExecutable(projectFile: string): string | undefined {
        const targetFileName = this.readTargetFileName(projectFile)
            || path.basename(projectFile, path.extname(projectFile));
        const withExtension = this.ensureExecutableExtension(targetFileName);

        return path.isAbsolute(withExtension)
            ? withExtension
            : path.join(path.dirname(projectFile), withExtension);
    }

    private readTargetFileName(projectFile: string): string | undefined {
        if (!fs.existsSync(projectFile)) {
            return undefined;
        }

        try {
            const parser = new XMLParser({
                ignoreAttributes: false,
                attributeNamePrefix: ''
            });
            const document = parser.parse(fs.readFileSync(projectFile, 'utf8'));
            const value = document?.CONFIG?.CompilerOptions?.Target?.Filename?.Value;
            return typeof value === 'string' && value.trim()
                ? value.trim()
                : undefined;
        } catch {
            return undefined;
        }
    }

    private ensureExecutableExtension(fileName: string): string {
        if (process.platform !== 'win32' || path.extname(fileName)) {
            return fileName;
        }

        return `${fileName}.exe`;
    }

    private async waitForTask(execution: vscode.TaskExecution): Promise<number | undefined> {
        return new Promise<number | undefined>((resolve) => {
            let completed = false;

            const finish = (exitCode: number | undefined) => {
                if (completed) {
                    return;
                }

                completed = true;
                processDisposable.dispose();
                taskDisposable.dispose();
                resolve(exitCode);
            };

            const processDisposable = vscode.tasks.onDidEndTaskProcess(event => {
                if (event.execution === execution) {
                    finish(event.exitCode);
                }
            });

            const taskDisposable = vscode.tasks.onDidEndTask(event => {
                if (event.execution === execution) {
                    finish(undefined);
                }
            });
        });
    }
}
