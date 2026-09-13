import * as fs from 'fs';
import * as path from 'path';
import { readLazarusBuildModes } from '../providers/lazarus';
import { LazarusTaskDefinition } from '../providers/taskDefinitions';
import {
    createToolchainEnvironment,
    PascalToolchainResolution,
    resolvePascalToolchain
} from '../toolchain/toolchainResolver';
import { BuildMode } from '../vscode/vscodeTaskTypes';
import { BuildCommand } from './buildCommand';
import { resolveWorkspacePath } from './taskVariableResolver';

export class LazarusCommandBuilder {
    public async createCommand(
        cwd: string,
        name: string,
        taskDefinition: LazarusTaskDefinition,
        buildMode: BuildMode
    ): Promise<BuildCommand> {
        const toolchain = resolvePascalToolchain();
        const lazbuildPath = this.resolveLazbuildPath(toolchain);
        if (!lazbuildPath) {
            throw new Error('lazbuild not found. Configure and enable the Lazarus toolchain.');
        }

        const projectFile = taskDefinition.project
            ? this.resolveProjectFile(cwd, taskDefinition.project)
            : '';
        const selectedBuildMode = this.getValidBuildMode(projectFile, taskDefinition.buildMode || name);
        const forceRebuild = taskDefinition.forceRebuild === true || buildMode === BuildMode.rebuild;
        const args: string[] = [];

        if (selectedBuildMode && selectedBuildMode !== 'Default') {
            args.push(`--build-mode=${selectedBuildMode}`);
        }
        if (forceRebuild) {
            args.push('--build-all');
        }

        args.push('--quiet');

        if (projectFile) {
            args.push(projectFile);
        }

        return {
            executable: lazbuildPath,
            args,
            cwd,
            compilerKind: 'lazbuild',
            env: createToolchainEnvironment(toolchain)
        };
    }

    private resolveLazbuildPath(toolchain: PascalToolchainResolution): string | undefined {
        return this.findLazbuildPath(toolchain);
    }

    private findLazbuildPath(toolchain: PascalToolchainResolution): string | undefined {
        for (const candidate of this.getCandidatePaths(toolchain)) {
            if (fs.existsSync(candidate) && fs.lstatSync(candidate).isFile()) {
                return candidate;
            }
        }

        return undefined;
    }

    private getCandidatePaths(toolchain: PascalToolchainResolution): string[] {
        const lazarusDir = toolchain.lazarusDirectory;
        const executableName = process.platform === 'win32' ? 'lazbuild.exe' : 'lazbuild';
        const candidates: string[] = [];

        if (lazarusDir) {
            candidates.push(path.join(lazarusDir, executableName));
        }

        return candidates;
    }

    private resolveProjectFile(cwd: string, projectFile: string): string {
        return resolveWorkspacePath(cwd, projectFile) || '';
    }

    private getValidBuildMode(projectFile: string, requestedBuildMode: string | undefined): string | undefined {
        const buildMode = requestedBuildMode?.trim();
        if (!buildMode || buildMode === 'Default' || !projectFile) {
            return buildMode;
        }

        const modes = readLazarusBuildModes(projectFile);
        if (modes.length === 0) {
            return undefined;
        }

        return modes.some(mode => mode.name.toLowerCase() === buildMode.toLowerCase())
            ? buildMode
            : undefined;
    }
}
