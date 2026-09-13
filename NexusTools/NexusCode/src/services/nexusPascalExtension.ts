import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { FpcCommandManager } from '../commands';
import * as MyCodeAction from '../languageServer/codeaction';
import { PascalLanguageClientService } from '../languageServer/client';
import { NexusScriptLanguageClientService } from '../languageServer/nexusScriptClient';
import { PascalBuildTarget, PascalProject, PascalProjectKind } from '../model/pascalProject';
import { createPascalProjectAdapterRegistry } from '../projectTypes/createPascalProjectAdapterRegistry';
import { BuildMode } from '../vscode/vscodeTask';
import { FpcTaskProvider, LazarusTaskProvider, NexusTaskProvider } from '../vscode/vscodeTaskProvider';
import { ActivePascalProjectService } from './activePascalProjectService';
import { DebugBuildService } from './debugBuildService';
import { EditorIntegrationService } from './editorIntegrationService';
import { ExtensionPaths } from './extensionPaths';
import { LanguageClientHandle } from './languageClientHandle';
import { PascalBuildTargetContextFactory } from './pascalBuildTargetContextFactory';
import { PascalProjectModelService } from './pascalProjectModelService';
import { PascalProjectWorkspaceService } from './pascalProjectWorkspaceService';
import { PascalTaskFactory } from './pascalTaskFactory';
import { WorkspaceTasksService } from './workspaceTasksService';
import { seedInstalledNexusToolchain } from '../toolchain/bundledToolchain';

export class NexusPascalExtension implements vscode.Disposable {
    private readonly disposables: vscode.Disposable[] = [];
    private client?: PascalLanguageClientService;
    private nexusScriptClient?: NexusScriptLanguageClientService;

    private constructor(
        private readonly context: vscode.ExtensionContext,
        private readonly workspaceRoot: string,
        private readonly logger: vscode.OutputChannel,
        private readonly languageClient: LanguageClientHandle,
        private readonly projectWorkspace: PascalProjectWorkspaceService,
        private readonly commandManager: FpcCommandManager,
        private readonly taskProvider: FpcTaskProvider,
        private readonly lazarusTaskProvider: LazarusTaskProvider,
        private readonly nexusTaskProvider: NexusTaskProvider,
        private readonly extensionPaths: ExtensionPaths,
        private readonly activeProjectService: ActivePascalProjectService,
        private readonly editorIntegrationService: EditorIntegrationService,
        private readonly debugBuildService: DebugBuildService
    ) {}

    public static async create(context: vscode.ExtensionContext): Promise<NexusPascalExtension | undefined> {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        if (!workspaceRoot) {
            return undefined;
        }

        const logger = vscode.window.createOutputChannel('Nexus Pascal');
        logger.appendLine('Nexus Pascal extension activating...');

        const extensionPaths = new ExtensionPaths(context);
        const languageClient = new LanguageClientHandle();
        const workspaceTasks = new WorkspaceTasksService(workspaceRoot);
        const taskProvider = new FpcTaskProvider(workspaceRoot, () => languageClient.restart());
        const lazarusTaskProvider = new LazarusTaskProvider(workspaceRoot);
        const nexusTaskProvider = new NexusTaskProvider(workspaceRoot, extensionPaths);
        const projectAdapters = createPascalProjectAdapterRegistry(
            workspaceRoot,
            workspaceTasks,
            taskProvider,
            lazarusTaskProvider,
            nexusTaskProvider
        );
        const projectModelService = new PascalProjectModelService(projectAdapters, workspaceRoot);
        const buildTargetContextFactory = new PascalBuildTargetContextFactory(projectAdapters);
        const taskFactory = new PascalTaskFactory(projectAdapters);
        taskProvider.setTaskSource(() => createProvidedTasks(projectModelService, taskFactory, 'fpc'));
        lazarusTaskProvider.setTaskSource(() => createProvidedTasks(projectModelService, taskFactory, 'lazarus'));
        nexusTaskProvider.setTaskSource(() => createProvidedTasks(projectModelService, taskFactory, 'nexus'));
        const projectWorkspace = new PascalProjectWorkspaceService(
            workspaceRoot,
            taskProvider,
            projectModelService,
            buildTargetContextFactory
        );
        const commandManager = new FpcCommandManager(
            workspaceRoot,
            languageClient
        );
        const editorIntegrationService = new EditorIntegrationService(() => languageClient.current, logger);
        const debugBuildService = new DebugBuildService(projectWorkspace, logger, taskFactory, workspaceTasks);
        const activeProjectService = new ActivePascalProjectService(
            workspaceRoot,
            projectModelService,
            projectWorkspace,
            languageClient,
            logger
        );

        const app = new NexusPascalExtension(
            context,
            workspaceRoot,
            logger,
            languageClient,
            projectWorkspace,
            commandManager,
            taskProvider,
            lazarusTaskProvider,
            nexusTaskProvider,
            extensionPaths,
            activeProjectService,
            editorIntegrationService,
            debugBuildService
        );

        await app.activate();
        return app;
    }

    public dispose(): void {
        this.disposables.splice(0).forEach(disposable => disposable.dispose());
        this.client?.stop();
        this.client?.dispose();
        void this.nexusScriptClient?.stop();
        this.languageClient.set(undefined);
        this.projectWorkspace.dispose();
        this.logger.dispose();
    }

    private async activate(): Promise<void> {
        await seedInstalledNexusToolchain(this.logger);

        this.commandManager.registerAll(this.context);

        this.disposables.push(
            vscode.tasks.registerTaskProvider(FpcTaskProvider.FpcTaskType, this.taskProvider),
            vscode.tasks.registerTaskProvider(LazarusTaskProvider.LazarusTaskType, this.lazarusTaskProvider),
            vscode.tasks.registerTaskProvider(NexusTaskProvider.NexusTaskType, this.nexusTaskProvider),
            this.activeProjectService,
            this.editorIntegrationService,
            this.debugBuildService
        );

        this.disposables.push(vscode.workspace.onDidChangeConfiguration(event => {
            if (event.affectsConfiguration('nexusPascal.languageServer.trace.server')) {
                this.client?.applyTraceSetting().catch(error => {
                    this.logger.appendLine(`Failed to apply language server trace setting: ${error}`);
                });
            }
            if (event.affectsConfiguration('nexusPascal.nexusScript.targets')) {
                this.nexusScriptClient?.applyTargetConfiguration().catch(error => {
                    this.logger.appendLine(`Failed to apply NexusScript Targets: ${error}`);
                });
            }
        }));

        this.activeProjectService.register(this.context);
        this.editorIntegrationService.register();
        this.debugBuildService.register();

        this.logger.appendLine('Core components initialized, extension activated');

        this.startLanguageServices();
    }

    private startLanguageServices(): void {
        this.initializeLanguageServices().catch(error => {
            this.logger.appendLine(`Language services failed outside activation: ${error}`);
            console.error('Language services failed outside activation:', error);
        });
    }

    private async initializeLanguageServices(): Promise<void> {
        try {
            const serverStoragePath = path.join(this.context.globalStorageUri.fsPath, 'nexusls');
            fs.mkdirSync(serverStoragePath, { recursive: true });
            this.client = new PascalLanguageClientService(
                this.projectWorkspace,
                this.extensionPaths,
                this.logger,
                serverStoragePath
            );
            this.languageClient.set(this.client);
            await this.client.doInit();
            await this.client.start();
            this.logger.appendLine('Language server initialized successfully');
        } catch (error) {
            this.logger.appendLine(`Language server initialization failed: ${error}`);
            console.error('Language server error:', error);
        }

        try {
            this.nexusScriptClient = new NexusScriptLanguageClientService(
                this.extensionPaths,
                this.logger
            );
            await this.nexusScriptClient.start();
        } catch (error) {
            this.logger.appendLine(`NexusScript language server initialization failed: ${error}`);
            console.error('NexusScript language server error:', error);
        }

        try {
            MyCodeAction.activate(this.context, this.languageClient);
            this.logger.appendLine('CodeAction provider registered successfully');
        } catch (error) {
            this.logger.appendLine(`CodeAction registration failed: ${error}`);
            console.error('CodeAction error:', error);
        }
    }
}

function createProvidedTasks(
    projectModelService: PascalProjectModelService,
    taskFactory: PascalTaskFactory,
    kind: PascalProjectKind
): vscode.Task[] {
    const tasks: vscode.Task[] = [];

    for (const project of projectModelService.loadProjects()) {
        for (const target of project.targets) {
            if (target.kind !== kind || !target.canBuild || !target.isInProjectFile) {
                continue;
            }

            const buildTask = taskFactory.createTask(
                target,
                createTaskName(project, target, 'Build'),
                BuildMode.normal
            );
            if (buildTask) {
                tasks.push(buildTask);
            }

        }
    }

    return tasks;
}

function createTaskName(project: PascalProject, target: PascalBuildTarget, verb: 'Build'): string {
    const kindName = project.kind === 'lazarus'
        ? 'Lazarus'
        : project.kind === 'fpc'
            ? 'Free Pascal'
            : 'Nexus';
    const targetPart = target.label && target.label !== project.label
        ? ` ${target.label}`
        : '';

    return `${verb} ${project.label} (${kindName}${targetPart})`;
}
