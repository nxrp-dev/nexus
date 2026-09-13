import * as vscode from 'vscode';
import { StoredToolchainMap } from './toolchainResolver';
import { findInstalledNexus } from './nexusInstall';

export async function seedInstalledNexusToolchain(
    logger: vscode.OutputChannel
): Promise<void> {
    const install = findInstalledNexus();

    if (!install) {
        logger.appendLine('No installed Nexus toolchain found from NexusRoot.');
        return;
    }

    const configuration = vscode.workspace.getConfiguration('nexusPascal');
    const toolchains = {
        ...(configuration
            .inspect<StoredToolchainMap>('toolchains')
            ?.globalValue || {})
    };
    let changed = false;

    const lazarus = { ...(toolchains.lazarus || {}) };
    if (!lazarus.lazarusDirectory) {
        lazarus.enabled = true;
        lazarus.lazarusDirectory = install.lazarusDirectory;
        toolchains.lazarus = lazarus;
        changed = true;
    }

    const freePascal = { ...(toolchains.freepascal || {}) };
    if (!freePascal.fpcDirectory && !freePascal.compilerPath) {
        freePascal.enabled = true;
        freePascal.fpcDirectory = install.fpcDirectory;
        freePascal.compilerPath = install.compilerPath;
        toolchains.freepascal = freePascal;
        changed = true;
    }

    if (!changed) {
        logger.appendLine('Installed Nexus toolchain is available; existing user toolchain settings were kept.');
        return;
    }

    await configuration.update('toolchains', toolchains, vscode.ConfigurationTarget.Global);
    logger.appendLine('Seeded Nexus Pascal toolchain settings from installed Nexus.');
}
