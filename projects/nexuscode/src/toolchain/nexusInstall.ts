import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

export interface NexusInstall {
    root: string;
    binDirectory: string;
    nexusLSPath: string;
    nexusScriptLSPath: string;
    nexusBuildPath: string;
    lazarusDirectory: string;
    lazbuildPath: string;
    fpcDirectory: string;
    compilerPath: string;
    sdkDirectory: string;
}

export function findInstalledNexus(): NexusInstall | undefined {
    if (process.platform !== 'win32') {
        return undefined;
    }

    const root = readNexusRoot();
    if (!root || !directoryExists(root)) {
        return undefined;
    }

    const binDirectory = path.join(root, 'bin');
    const lazarusDirectory = path.join(root, 'toolchain', 'lazarus');
    const fpcDirectory = path.join(lazarusDirectory, 'fpc', '3.2.2');

    const install: NexusInstall = {
        root,
        binDirectory,
        nexusLSPath: path.join(binDirectory, 'nexusls.exe'),
        nexusScriptLSPath: path.join(binDirectory, 'nexusscriptls.exe'),
        nexusBuildPath: path.join(binDirectory, 'nexusbuild.exe'),
        lazarusDirectory,
        lazbuildPath: path.join(lazarusDirectory, 'lazbuild.exe'),
        fpcDirectory,
        compilerPath: path.join(fpcDirectory, 'bin', 'x86_64-win64', 'fpc.exe'),
        sdkDirectory: path.join(root, 'sdk')
    };

    if (!fileExists(install.nexusLSPath) ||
        !directoryExists(install.lazarusDirectory) ||
        !directoryExists(install.fpcDirectory) ||
        !fileExists(install.compilerPath)) {
        return undefined;
    }

    return install;
}

function readNexusRoot(): string | undefined {
    try {
        const output = cp.execFileSync(
            'reg.exe',
            ['query', 'HKLM\\Software\\NexusRP\\Nexus', '/v', 'NexusRoot'],
            { encoding: 'utf8', windowsHide: true }
        );
        const match = output.match(/NexusRoot\s+REG_SZ\s+(.+)/);
        return match?.[1]?.trim();
    } catch {
        return undefined;
    }
}

function directoryExists(value: string): boolean {
    return fs.existsSync(value) && fs.lstatSync(value).isDirectory();
}

function fileExists(value: string): boolean {
    return fs.existsSync(value) && fs.lstatSync(value).isFile();
}
