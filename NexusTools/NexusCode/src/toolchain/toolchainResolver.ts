import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

export interface PascalToolchainResolution {
    compilerPath?: string;
    fpcDirectory?: string;
    lazarusDirectory?: string;
}

export type ToolchainEnvironment = Record<string, string | undefined>;

export interface StoredToolchainConfiguration {
    enabled?: boolean;
    compilerPath?: string;
    fpcDirectory?: string;
    lazarusDirectory?: string;
}

export type StoredToolchainMap = Record<string, StoredToolchainConfiguration | undefined>;

export function resolvePascalToolchain(): PascalToolchainResolution {
    const configuredToolchains = getGlobalToolchains();
    const lazarusToolchain = configuredToolchains.lazarus || {};
    const fpcToolchain = configuredToolchains.freepascal || {};
    const compilerPath = existingFile(cleanPath(fpcToolchain.compilerPath));
    const fpcDirectory = existingDirectory(cleanPath(fpcToolchain.fpcDirectory));
    const lazarusDirectory = lazarusToolchain.enabled === false
        ? undefined
        : existingDirectory(cleanPath(lazarusToolchain.lazarusDirectory));

    return {
        compilerPath,
        fpcDirectory,
        lazarusDirectory,
    };
}

export function createToolchainEnvironment(
    toolchain: PascalToolchainResolution = resolvePascalToolchain()
): ToolchainEnvironment {
    const environment: ToolchainEnvironment = {};

    if (toolchain.compilerPath) {
        environment.PP = toolchain.compilerPath;
    }
    if (toolchain.lazarusDirectory) {
        environment.LAZARUSDIR = toolchain.lazarusDirectory;
        environment.LAZARUSSRC = toolchain.lazarusDirectory;
    }
    if (toolchain.fpcDirectory) {
        environment.FPCDIR = toolchain.fpcDirectory;
    }

    return environment;
}

export function getGlobalToolchains(): StoredToolchainMap {
    return vscode.workspace
        .getConfiguration('nexusPascal')
        .inspect<StoredToolchainMap>('toolchains')
        ?.globalValue || {};
}

function cleanPath(value: string | undefined): string | undefined {
    const result = value?.trim();
    return result ? result : undefined;
}

function existingDirectory(value: string | undefined): string | undefined {
    if (!value) {
        return undefined;
    }

    return fs.existsSync(value) && fs.lstatSync(value).isDirectory()
        ? path.resolve(value)
        : undefined;
}

function existingFile(value: string | undefined): string | undefined {
    if (!value) {
        return undefined;
    }

    return fs.existsSync(value) && fs.lstatSync(value).isFile()
        ? path.resolve(value)
        : undefined;
}

