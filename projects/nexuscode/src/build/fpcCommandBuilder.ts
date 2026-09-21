import { FpcTaskDefinition } from '../providers/taskDefinitions';
import { BuildMode } from '../vscode/vscodeTaskTypes';
import { BuildCommand } from './buildCommand';
import { createBuildOptionArguments } from './buildOptionArguments';
import { resolveWorkspacePath } from './taskVariableResolver';
import { createToolchainEnvironment, resolvePascalToolchain } from '../toolchain/toolchainResolver';

export class FpcCommandBuilder {
    public createCommand(cwd: string, file: string, taskDefinition: FpcTaskDefinition, buildMode: BuildMode): BuildCommand {
        const toolchain = resolvePascalToolchain();
        const compilerPath = toolchain.compilerPath;
        if (!compilerPath) {
            throw new Error('Free Pascal compiler not configured. Configure and enable a Lazarus or Free Pascal toolchain.');
        }

        const args = this.createArgs(cwd, file, taskDefinition, buildMode);

        return {
            executable: compilerPath,
            args,
            cwd,
            compilerKind: 'fpc',
            env: createToolchainEnvironment(toolchain)
        };
    }

    private createArgs(cwd: string, file: string, taskDefinition: FpcTaskDefinition, buildMode: BuildMode): string[] {
        const args: string[] = [];
        const mainFile = resolveWorkspacePath(cwd, taskDefinition.file || file);

        if (mainFile) {
            args.push(mainFile);
        }

        args.push(...createBuildOptionArguments(cwd, taskDefinition.buildOption));
        args.push('-vq');

        if (buildMode === BuildMode.rebuild) {
            args.push('-B');
        }

        return args;
    }
}
