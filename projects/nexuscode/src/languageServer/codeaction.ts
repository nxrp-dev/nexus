/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/
// sample
// https://github.com/microsoft/vscode-extension-samples/blob/main/code-actions-sample/src/extension.ts

import * as vscode from 'vscode';
import { buildDiagnostics } from '../services/diagnosticsService';
import { LanguageClientHandle } from '../services/languageClientHandle';

const COMMAND_UNUSED = 'nexusPascal.code-actions.remove_unused_variable';
const COMMAND_COMPLETE_CODE = 'nexusls.completeCode';
const COMMAND_REMOVE_EMPTY_METHODS = 'nexusls.removeEmptyMethods';
const COMMAND_REMOVE_UNUSED_UNITS = 'nexusls.removeUnusedUnits';
const COMMAND_INVERT_ASSIGNMENT = 'nexusls.invertAssignment';

export function activate(context: vscode.ExtensionContext, languageClient: LanguageClientHandle) {

	context.subscriptions.push(
		vscode.languages.registerCodeActionsProvider('objectpascal', new FpcCodeAction(), {
			providedCodeActionKinds: FpcCodeAction.providedCodeActionKinds
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand(COMMAND_UNUSED, (document:vscode.TextDocument,diag:vscode.Diagnostic,variable:string) => {
            let edit=new vscode.WorkspaceEdit();
            let line=document.lineAt(diag.range.start.line);
            let linetext=line.text.trim();
            var has_var=false;
            if(linetext.substring(0,4).toLocaleLowerCase()=='var ')
            {
                linetext=linetext.substring(4,linetext.length)
                has_var=true;
            }
            let isdelete=false;
            let ret=linetext.split(/,|:/);
            if(ret.length<=2){
                if(has_var){
                    edit.replace(document.uri,line.range,"var");
                }else{
                    edit.delete(document.uri,line.rangeIncludingLineBreak);
                    isdelete=true;
                }
            }else{
                ret=ret.map(v=>v.trim()).filter(v=>v!=variable);
                linetext=has_var?'var ':'  '+ret.slice(0,-1).join(', ')+': '+ret[ret.length-1];
                edit.replace(document.uri,line.range,linetext);
            }

            let diags= buildDiagnostics.get(document.uri);
            if(!diags){
                vscode.workspace.applyEdit(edit);
                return;
            }
            if(!isdelete){
                //delete fixed diag

                var newdiags=[];
                for (const item of diags) {
                    if(item===diag)
                    {
                        continue;
                    }

                    newdiags.push(item)
                }
                buildDiagnostics.set(document.uri, newdiags);
            }


            vscode.workspace.applyEdit(edit);

        })
	);

    context.subscriptions.push(
        vscode.commands.registerCommand(COMMAND_COMPLETE_CODE, async (uri: string, position: vscode.Position) => {
            await languageClient.sendCustomRequest(COMMAND_COMPLETE_CODE, {
                uri,
                position: toProtocolPosition(position)
            });
        }),
        vscode.commands.registerCommand(COMMAND_REMOVE_EMPTY_METHODS, async (uri: string, position: vscode.Position) => {
            await languageClient.sendCustomRequest(COMMAND_REMOVE_EMPTY_METHODS, {
                uri,
                position: toProtocolPosition(position)
            });
        }),
        vscode.commands.registerCommand(COMMAND_REMOVE_UNUSED_UNITS, async (uri: string) => {
            await languageClient.sendCustomRequest(COMMAND_REMOVE_UNUSED_UNITS, { uri });
        }),
        vscode.commands.registerCommand(
            COMMAND_INVERT_ASSIGNMENT,
            async (uri: string, start: vscode.Position, end: vscode.Position) => {
                await languageClient.sendCustomRequest(COMMAND_INVERT_ASSIGNMENT, {
                    uri,
                    start: toProtocolPosition(start),
                    end: toProtocolPosition(end)
                });
            }
        )
    );
}



/**
 * Provides code actions corresponding to diagnostic problems.
 */
export class FpcCodeAction implements vscode.CodeActionProvider {

	public static readonly providedCodeActionKinds = [
		vscode.CodeActionKind.QuickFix,
        vscode.CodeActionKind.Source,
        vscode.CodeActionKind.Refactor
	];

	provideCodeActions(document: vscode.TextDocument, range: vscode.Range | vscode.Selection, context: vscode.CodeActionContext, token: vscode.CancellationToken): vscode.CodeAction[] {
		// for each diagnostic entry that has the matching `code`, create a code action command
	    let actions = context.diagnostics
			.filter(diagnostic =>{
                return diagnostic.code === 5025;
            } )
			.map(diagnostic => this.createCommandCodeAction(document,diagnostic));

        if(context.triggerKind===vscode.CodeActionTriggerKind.Invoke){
            // CodeComplete
            const action = new vscode.CodeAction(
                "Complete Code",
                vscode.CodeActionKind.Source
            );

            action.command = {
                title: "Complete Code",
                command: COMMAND_COMPLETE_CODE,
                arguments: [document.uri.toString(), range.start]
            };
            actions.push(action);

            const action_removeEmptyMethods = new vscode.CodeAction(
                "Remove Empty Methods",
                vscode.CodeActionKind.Refactor
            );
            action_removeEmptyMethods.command = {
                title: "Remove Empty Methods",
                command: COMMAND_REMOVE_EMPTY_METHODS,
                arguments: [document.uri.toString(), range.start]
            };
            actions.push(action_removeEmptyMethods);

            const action_removeUnusedUnits = new vscode.CodeAction(
                "Remove Unused Units",
                vscode.CodeActionKind.Refactor
            );
            action_removeUnusedUnits.command = {
                title: "Remove Unused Units",
                command: COMMAND_REMOVE_UNUSED_UNITS,
                arguments: [document.uri.toString(), range.start]
            };
            actions.push(action_removeUnusedUnits);

            let nrange = new vscode.Range(range.start.line, 0, range.end.line, 9999);
            let s = document.getText(nrange);
            if(s.indexOf(':=')>0){
                const action_invertAssign = new vscode.CodeAction(
                    "Invert Assignment",
                    vscode.CodeActionKind.Refactor
                );
                action_invertAssign.command = {
                    title: "Invert Assignment",
                    command: COMMAND_INVERT_ASSIGNMENT,
                    arguments: [document.uri.toString(), nrange.start,nrange.end]
                };
                actions.push(action_invertAssign);
            }
        }
        return actions;
	}

	private createCommandCodeAction(document: vscode.TextDocument,diagnostic: vscode.Diagnostic): vscode.CodeAction {
        let matchs=diagnostic.message.match(/Local variable "(.*?)".*?not used/)!;

        let variable=matchs[1];

		const fix = new vscode.CodeAction('Remove variable `'+variable+'`', vscode.CodeActionKind.QuickFix);
		fix.command = { command: COMMAND_UNUSED, title: 'Remove unused variable.', tooltip: 'Remove unused variable.' };
        fix.command.arguments=[document, diagnostic,variable];
		fix.diagnostics = [diagnostic];
		//fix.isPreferred = true;
		return fix;
	}
}

function toProtocolPosition(position: vscode.Position): { line: number; character: number } {
    return {
        line: position.line,
        character: position.character
    };
}
