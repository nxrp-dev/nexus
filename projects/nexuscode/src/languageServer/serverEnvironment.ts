import * as cp from 'child_process';
import * as path from 'path';
import { env } from 'process';
import {
    createToolchainEnvironment,
    PascalToolchainResolution,
    resolvePascalToolchain
} from '../toolchain/toolchainResolver';

export interface ServerEnvironment {
    [key: string]: string | undefined;
}

export function getServerEnvironment(
    serverStoragePath?: string,
    toolchain: PascalToolchainResolution = resolvePascalToolchain()
): ServerEnvironment {
    const userEnvironmentVariables: ServerEnvironment = createToolchainEnvironment(toolchain);

    if (serverStoragePath) {
        userEnvironmentVariables['NEXUSLS_CACHE_DIR'] = serverStoragePath;
    }

    if (userEnvironmentVariables['PP']) {
        env['PP'] = userEnvironmentVariables['PP'];
    }
    if (userEnvironmentVariables['LAZARUSDIR']) {
        env['LAZARUSDIR'] = userEnvironmentVariables['LAZARUSDIR'];
    }
    if (userEnvironmentVariables['LAZARUSSRC']) {
        env['LAZARUSSRC'] = userEnvironmentVariables['LAZARUSSRC'];
    }
    if (userEnvironmentVariables['FPCDIR']) {
        env['FPCDIR'] = userEnvironmentVariables['FPCDIR'];
    }

    return userEnvironmentVariables;
}

export async function getGlobalUnitPaths(ppPath: string, targetOS?: string, targetCPU?: string, cwd?: string): Promise<string[]> {
    return new Promise((resolve) => {
        const dummyFile = 'be19131e-4503-4c54-9549-9f79c6d338e9.pas';
        const args = ['-vt', dummyFile];
        if (targetOS) {
            args.push(`-T${targetOS}`);
        }
        if (targetCPU) {
            args.push(`-P${targetCPU}`);
        }

        cp.exec(`"${ppPath}" ${args.join(' ')}`, { cwd }, (_error, stdout, stderr) => {
            const unitPaths: string[] = [];
            const lines = (stdout + stderr).split('\n');
            const unitPathRegex = /Using unit path:\s*(.*)/;

            for (const line of lines) {
                const match = line.match(unitPathRegex);
                if (match?.[1]) {
                    const unitPath = path.resolve(match[1].trim());
                    if (unitPath && !unitPaths.includes(unitPath)) {
                        unitPaths.push(unitPath);
                    }
                }
            }
            resolve(unitPaths);
        });
    });
}

