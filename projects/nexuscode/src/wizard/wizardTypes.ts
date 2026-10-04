/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

export type WizardFieldType = 'text' | 'select' | 'checkbox' | 'file' | 'folder' | 'readonly';
export type WizardMessageSeverity = 'info' | 'warning' | 'error';
export type WizardFieldSuggestionKind = 'path' | 'url';

export type WizardRequestValue = string | boolean | undefined;

export interface WizardRequest {
    [key: string]: WizardRequestValue;
}

export interface WizardFieldOption {
    value: string;
    label: string;
}

export interface WizardFieldSuggestion {
    kind: WizardFieldSuggestionKind;
    label: string;
    value: string;
    reason?: string;
}

export interface WizardField {
    id: string;
    label: string;
    type: WizardFieldType;
    value?: WizardRequestValue;
    options?: WizardFieldOption[];
    suggestions?: WizardFieldSuggestion[];
    description?: string;
    placeholder?: string;
    required?: boolean;
    valid?: boolean;
    severity?: WizardMessageSeverity;
    message?: string;
    disabled?: boolean;
    hidden?: boolean;
    browseTitle?: string;
    browseLabel?: string;
    filters?: Record<string, string[]>;
}

export interface WizardMessage {
    severity: WizardMessageSeverity;
    text: string;
}

export interface WizardConflict {
    source: 'client' | 'server';
    severity: WizardMessageSeverity;
    code: string;
    text: string;
    path?: string;
}

export interface WizardOutput {
    label: string;
    path: string;
}

export interface WizardDetail {
    label: string;
    value: string;
}

export interface WizardPlan {
    title: string;
    summary: string;
    canExecute: boolean;
    messages: WizardMessage[];
    conflicts?: WizardConflict[];
    outputs: WizardOutput[];
    details: WizardDetail[];
}

export interface WizardDefinition<TRequest extends WizardRequest, TPlan extends WizardPlan> {
    id: string;
    title: string;
    executeLabel?: string;
    getInitialRequest(): Promise<TRequest>;
    getFields(request: TRequest): Promise<WizardField[]> | WizardField[];
    createPlan(request: TRequest): Promise<TPlan>;
    execute(request: TRequest, plan: TPlan): Promise<void>;
}
