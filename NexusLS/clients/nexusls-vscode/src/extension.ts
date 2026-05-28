import * as vscode from 'vscode';
import {
  Executable,
  LanguageClient,
  LanguageClientOptions,
  ServerOptions
} from 'vscode-languageclient/node';

const ServerCommandCompleteCode = 'pasls.completeCode';
const ServerCommandInvertAssignment = 'pasls.invertAssignment';
const ServerCommandRemoveEmptyMethods = 'pasls.removeEmptyMethods';
const ServerCommandRemoveUnusedUnits = 'pasls.removeUnusedUnits';

let client: LanguageClient | undefined;

function configuration(): vscode.WorkspaceConfiguration {
  return vscode.workspace.getConfiguration('nexusLS');
}

function initializationOptions(): unknown {
  return configuration().get('initializationOptions') ?? {};
}

function serverEnvironment(): NodeJS.ProcessEnv {
  const result: NodeJS.ProcessEnv = { ...process.env };
  const envConfig = vscode.workspace.getConfiguration('nexusLS.env');
  const keys = ['PP', 'FPCDIR', 'LAZARUSDIR', 'FPCTARGET', 'FPCTARGETCPU'];

  for (const key of keys) {
    const value = envConfig.get<string>(key);
    if (value && value.length > 0) {
      result[key] = value;
    }
  }

  return result;
}

function activePascalEditor(): vscode.TextEditor | undefined {
  const editor = vscode.window.activeTextEditor;
  if (!editor) {
    vscode.window.showErrorMessage('No active editor.');
    return undefined;
  }

  if (editor.document.languageId !== 'pascal') {
    vscode.window.showErrorMessage('The active editor is not a Pascal document.');
    return undefined;
  }

  return editor;
}

function activeDocumentUri(editor: vscode.TextEditor): string | undefined {
  if (editor.document.uri.scheme !== 'file') {
    vscode.window.showErrorMessage('The document must be saved to a file first.');
    return undefined;
  }

  return editor.document.uri.with({ scheme: 'file' }).toString();
}

async function executeServerCommand(command: string, ...args: unknown[]): Promise<void> {
  if (!client) {
    vscode.window.showErrorMessage('NexusLS is not running.');
    return;
  }

  await vscode.commands.executeCommand(command, ...args);
}

async function invokeCompleteCode(): Promise<void> {
  const editor = activePascalEditor();
  if (!editor) {
    return;
  }

  const uri = activeDocumentUri(editor);
  if (!uri) {
    return;
  }

  await executeServerCommand(ServerCommandCompleteCode, uri, editor.selection.active);
}

async function invokeInvertAssignment(): Promise<void> {
  const editor = activePascalEditor();
  if (!editor) {
    return;
  }

  const uri = activeDocumentUri(editor);
  if (!uri) {
    return;
  }

  await executeServerCommand(
    ServerCommandInvertAssignment,
    uri,
    editor.selection.start,
    editor.selection.end
  );
}

async function invokeRemoveEmptyMethods(): Promise<void> {
  const editor = activePascalEditor();
  if (!editor) {
    return;
  }

  const uri = activeDocumentUri(editor);
  if (!uri) {
    return;
  }

  await executeServerCommand(ServerCommandRemoveEmptyMethods, uri, editor.selection.active);
}

async function invokeRemoveUnusedUnits(): Promise<void> {
  const editor = activePascalEditor();
  if (!editor) {
    return;
  }

  const uri = activeDocumentUri(editor);
  if (!uri) {
    return;
  }

  await executeServerCommand(ServerCommandRemoveUnusedUnits, uri, editor.selection.active);
}

export function activate(context: vscode.ExtensionContext): void {
  const executable = configuration().get<string>('executable');
  if (!executable) {
    vscode.window.showErrorMessage('NexusLS executable path is not configured.');
    return;
  }

  const run: Executable = {
    command: executable,
    options: {
      env: serverEnvironment()
    }
  };

  const serverOptions: ServerOptions = {
    run,
    debug: run
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [
      { scheme: 'file', language: 'pascal' },
      { scheme: 'untitled', language: 'pascal' }
    ],
    initializationOptions: initializationOptions()
  };

  client = new LanguageClient('nexusLS', 'NexusLS', serverOptions, clientOptions);
  context.subscriptions.push(client.start());

  context.subscriptions.push(
    vscode.commands.registerCommand('nexusPascal.completeCode', invokeCompleteCode),
    vscode.commands.registerCommand('nexusPascal.invertAssignment', invokeInvertAssignment),
    vscode.commands.registerCommand('nexusPascal.removeEmptyMethods', invokeRemoveEmptyMethods),
    vscode.commands.registerCommand('nexusPascal.removeUnusedUnits', invokeRemoveUnusedUnits)
  );
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }

  return client.stop();
}
