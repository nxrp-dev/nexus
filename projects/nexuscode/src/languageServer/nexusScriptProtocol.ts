/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

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
    applicable?: boolean;
    overrides?: boolean;
    effectiveValue?: string;
    effectiveSourceUri?: string;
    effectiveRange?: Range;
    contributors?: NexusScriptProvenance[];
    allowedOperations?: string[];
}

export interface NexusScriptProvenance {
    sourceUri: string;
    range: Range;
    winner: boolean;
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
