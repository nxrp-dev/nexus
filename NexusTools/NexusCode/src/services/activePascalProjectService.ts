import * as path from 'path';
import * as vscode from 'vscode';
import { PascalProject } from '../model/pascalProject';
import { PascalProjectModelService } from './pascalProjectModelService';
import { LanguageClientHandle } from './languageClientHandle';
import { PascalProjectWorkspaceService } from './pascalProjectWorkspaceService';

const activeProjectSetting = 'activeProject';

interface ProjectPickItem extends vscode.QuickPickItem {
    projectFile: string;
}

export class ActivePascalProjectService implements vscode.Disposable {
    private readonly disposables: vscode.Disposable[] = [];
    private readonly statusBar: vscode.StatusBarItem;

    public constructor(
        private readonly workspaceRoot: string,
        private readonly projectModelService: PascalProjectModelService,
        private readonly projectWorkspace: PascalProjectWorkspaceService,
        private readonly languageClient: LanguageClientHandle,
        private readonly logger: vscode.OutputChannel
    ) {
        this.statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 75);
        this.statusBar.command = 'nexusPascal.project.selectActiveProject';
        this.disposables.push(this.statusBar);
    }

    public register(context: vscode.ExtensionContext): void {
        context.subscriptions.push(
            vscode.commands.registerCommand('nexusPascal.project.selectActiveProject', () => this.selectActiveProject()),
            vscode.commands.registerCommand('nexusPascal.project.rescanProjects', () => this.rescanProjects()),
            vscode.commands.registerCommand('nexusPascal.project.showActiveProject', () => this.showActiveProject()),
            vscode.commands.registerCommand('nexusPascal.project.setActiveProject', (resource?: vscode.Uri) => this.setActiveProjectFromResource(resource)),
            vscode.commands.registerCommand('nexusPascal.project.selectProjectFromFolder', (resource?: vscode.Uri) => this.selectProjectFromFolder(resource))
        );

        this.disposables.push(
            this.projectWorkspace.onDidChangeProjects(() => this.updateStatusBar()),
            vscode.workspace.onDidChangeConfiguration(event => {
                if (event.affectsConfiguration('nexusPascal.activeProject')) {
                    this.updateStatusBar();
                }
            })
        );

        this.updateStatusBar();
        this.statusBar.show();
        this.logDiscovery();
    }

    public dispose(): void {
        this.disposables.splice(0).forEach(disposable => disposable.dispose());
    }

    public updateStatusBar(): void {
        const activeProject = this.getActiveProjectFile();
        const projects = this.getLpiProjects();

        if (activeProject) {
            this.statusBar.text = `Nexus Pascal: ${path.basename(activeProject)}`;
            this.statusBar.tooltip = `Active Nexus Pascal Project: ${activeProject}`;
        } else if (projects.length === 1) {
            this.statusBar.text = 'Nexus Pascal: Auto';
            this.statusBar.tooltip = `Auto project: ${projects[0].file}`;
        } else {
            this.statusBar.text = 'Nexus Pascal: No active project';
            this.statusBar.tooltip = 'Click to select an Active Nexus Pascal Project.';
        }
    }

    private async selectActiveProject(projects: PascalProject[] = this.getLpiProjects()): Promise<void> {
        if (projects.length === 0) {
            vscode.window.showInformationMessage('No Lazarus .lpi project files were found in this workspace.');
            this.logger.appendLine('No Pascal project candidates found.');
            this.updateStatusBar();
            return;
        }

        const selected = await vscode.window.showQuickPick(
            projects.map(project => this.createProjectPickItem(project)),
            {
                title: 'Select Active Nexus Pascal Project',
                placeHolder: 'Choose the .lpi file to use for project-level Nexus Pascal commands'
            }
        );

        if (!selected) {
            return;
        }

        await this.setActiveProject(selected.projectFile);
    }

    private async rescanProjects(): Promise<void> {
        const projects = this.getLpiProjects();
        this.logger.appendLine(`Project rescan complete. Discovered ${projects.length} Pascal project candidates.`);
        this.updateStatusBar();

        if (projects.length === 0) {
            vscode.window.showInformationMessage('No Lazarus .lpi project files were found in this workspace.');
        } else {
            vscode.window.showInformationMessage(`Discovered ${projects.length} Nexus Pascal project candidate(s).`);
        }
    }

    private async showActiveProject(): Promise<void> {
        const activeProject = this.getActiveProjectFile();
        const projects = this.getLpiProjects();

        if (activeProject) {
            vscode.window.showInformationMessage(`Active Nexus Pascal Project: ${activeProject}`);
            return;
        }

        if (projects.length === 1) {
            vscode.window.showInformationMessage(`Active Nexus Pascal Project: Auto (${projects[0].file})`);
            return;
        }

        vscode.window.showInformationMessage('No Active Nexus Pascal Project is selected.');
    }

    private async setActiveProjectFromResource(resource?: vscode.Uri): Promise<void> {
        const fileName = resource?.fsPath;
        if (!fileName || path.extname(fileName).toLowerCase() !== '.lpi') {
            vscode.window.showInformationMessage('Select a Lazarus .lpi project file.');
            return;
        }

        await this.setActiveProject(fileName);
    }

    private async selectProjectFromFolder(resource?: vscode.Uri): Promise<void> {
        const folder = resource?.fsPath;
        if (!folder) {
            vscode.window.showInformationMessage('Select a folder that contains a Lazarus .lpi project file.');
            return;
        }

        const projects = this.getLpiProjects().filter(project => this.isUnderFolder(project.file, folder));
        if (projects.length === 0) {
            vscode.window.showInformationMessage('No Lazarus .lpi project file was found in the selected folder.');
            this.logger.appendLine(`No Pascal project found in selected folder: ${folder}`);
            return;
        }

        if (projects.length === 1) {
            await this.setActiveProject(projects[0].file);
            return;
        }

        await this.selectActiveProject(projects);
    }

    private async setActiveProject(projectFile: string): Promise<void> {
        const relativePath = this.toWorkspaceRelativePath(projectFile);
        await vscode.workspace.getConfiguration('nexusPascal').update(
            activeProjectSetting,
            relativePath,
            vscode.ConfigurationTarget.Workspace
        );
        this.logger.appendLine(`Active project set to ${projectFile}`);
        this.updateStatusBar();
        await this.languageClient.restart();
    }

    private getActiveProjectFile(): string | undefined {
        const configured = vscode.workspace.getConfiguration('nexusPascal').get<string>(activeProjectSetting, '').trim();
        if (!configured) {
            return undefined;
        }

        const resolved = path.isAbsolute(configured)
            ? configured
            : path.join(this.workspaceRoot, configured);

        return this.getLpiProjects().some(project => this.samePath(project.file, resolved))
            ? resolved
            : undefined;
    }

    private getLpiProjects(): PascalProject[] {
        return this.projectModelService.loadProjects()
            .filter(project => project.kind === 'lazarus')
            .filter(project => path.extname(project.file).toLowerCase() === '.lpi');
    }

    private createProjectPickItem(project: PascalProject): ProjectPickItem {
        return {
            label: project.label,
            description: this.toWorkspaceRelativePath(project.file),
            projectFile: project.file
        };
    }

    private logDiscovery(): void {
        const projects = this.getLpiProjects();
        this.logger.appendLine(`Discovered ${projects.length} Pascal project candidates.`);
    }

    private toWorkspaceRelativePath(fileName: string): string {
        const relativePath = path.relative(this.workspaceRoot, fileName);
        return relativePath && !relativePath.startsWith('..') && !path.isAbsolute(relativePath)
            ? relativePath.replace(/\\/g, '/')
            : fileName;
    }

    private isUnderFolder(fileName: string, folder: string): boolean {
        const relativePath = path.relative(folder, fileName);
        return relativePath !== '' && !relativePath.startsWith('..') && !path.isAbsolute(relativePath);
    }

    private samePath(left: string, right: string): boolean {
        return path.resolve(left).toLowerCase() === path.resolve(right).toLowerCase();
    }
}
