export type CompilerKind = 'fpc' | 'lazbuild' | 'nexusbuild';

export interface BuildCommand {
    executable: string;
    args: string[];
    cwd: string;
    compilerKind: CompilerKind;
    env?: Record<string, string | undefined>;
}

export function formatBuildCommand(command: BuildCommand): string {
    return [command.executable, ...command.args]
        .map(argument => argument.includes(' ') ? `"${argument}"` : argument)
        .join(' ');
}
