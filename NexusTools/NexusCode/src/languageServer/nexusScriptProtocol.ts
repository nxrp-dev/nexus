import { Range, WorkspaceEdit } from 'vscode-languageclient';

export interface NexusScriptNode {
    id: string;
    nodeType: string;
    kind?: string;
    name?: string;
    value?: string;
    range: Range;
    selectionRange: Range;
    children?: NexusScriptNode[];
    sourceUri?: string;
    local?: boolean;
    effectiveValue?: string;
    allowedOperations?: string[];
}

export interface NexusScriptDialectPropertyRule {
    name: string;
    required: boolean;
    scalarKind: 'none' | 'text' | 'integer' | 'boolean';
    allowedValues: string[];
    sourceForms: string[];
    referenceKinds: string[];
    arrayValues: string[];
    arrayDefinitionKinds: string[];
}

export interface NexusScriptDialectChildRule {
    name: string;
    kinds: string[];
    minimum: number;
    maximum: number;
}

export interface NexusScriptDocumentModel {
    uri: string;
    version: number;
    revision: number;
    succeeded: boolean;
    nodes: NexusScriptNode[];
}

export interface NexusScriptDialectRule {
    kind: string;
    root: boolean;
    properties: string[];
    children: string[];
    propertyRules: NexusScriptDialectPropertyRule[];
    childRules: NexusScriptDialectChildRule[];
}

export interface NexusScriptDialectModel {
    revision: number;
    rules: NexusScriptDialectRule[];
}

export interface NexusScriptTarget {
    kind: string;
    value: string;
}

export interface NexusScriptSemanticEditParams {
    textDocument: { uri: string };
    version: number;
    revision: number;
    nodeId: string;
    operation: 'addChild' | 'removeChild' | 'setProperty' |
        'removeProperty' | 'setReference' | 'rename' |
        'createOverride' | 'resetOverride';
    kind?: string;
    name?: string;
    value?: string;
}

export type NexusScriptSemanticEdit = WorkspaceEdit;
