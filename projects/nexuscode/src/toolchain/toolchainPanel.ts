import * as vscode from 'vscode';
import { LanguageClientHandle } from '../services/languageClientHandle';
import { WizardField, WizardPlan, WizardRequest } from '../wizard/wizardTypes';

const commandConfigureWizard = 'nexusls.toolchain.configureWizard';
const commandListSupported = 'nexusls.toolchain.listSupported';
const commandPlanConfigure = 'nexusls.toolchain.planConfigure';

type ToolchainSettingsScope = 'workspace' | 'user';

interface ToolchainRequest extends WizardRequest {
    androidNdkDirectory: string;
    androidSdkDirectory: string;
    compilerPath: string;
    enabled: boolean;
    fpcDirectory: string;
    javaHome: string;
    kind: string;
    lazarusDirectory: string;
    scope: ToolchainSettingsScope;
}

interface ToolchainDescriptor {
    kind: string;
    label: string;
    description?: string;
}

interface ToolchainListSupportedResult {
    toolchains?: ToolchainDescriptor[];
}

interface ToolchainWizardSeed {
    title?: string;
    request?: Partial<ToolchainRequest>;
    fields?: WizardField[];
}

interface ToolchainPlan extends WizardPlan {
    fields?: WizardField[];
    normalizedAndroidNdkDirectory?: string;
    normalizedAndroidSdkDirectory?: string;
    normalizedCompilerPath?: string;
    normalizedFpcDirectory?: string;
    normalizedJavaHome?: string;
    normalizedLazarusDirectory?: string;
}

interface StoredToolchainConfiguration {
    androidNdkDirectory?: string;
    androidSdkDirectory?: string;
    compilerPath?: string;
    enabled?: boolean;
    fpcDirectory?: string;
    javaHome?: string;
    lazarusDirectory?: string;
}

type StoredToolchainMap = Record<string, StoredToolchainConfiguration | undefined>;

interface ToolchainPanelState {
    type: 'state';
    title: string;
    toolchains: ToolchainDescriptor[];
    selectedKind: string;
    request: ToolchainRequest;
    fields: WizardField[];
    plan: ToolchainPlan;
}

interface ToolchainPanelError {
    type: 'error';
    message: string;
}

interface ToolchainPanelValueSelected {
    type: 'valueSelected';
    fieldId: string;
    value: string;
}

type OutgoingToolchainMessage = ToolchainPanelState | ToolchainPanelError | ToolchainPanelValueSelected;

export class ToolchainPanel {
    private static currentPanel: ToolchainPanel | undefined;

    private readonly disposables: vscode.Disposable[] = [];
    private readonly seedByKind = new Map<string, ToolchainWizardSeed>();
    private readonly requestsByKind = new Map<string, ToolchainRequest>();
    private panel: vscode.WebviewPanel | undefined;
    private supportedToolchains: ToolchainDescriptor[] = [];
    private selectedKind = 'lazarus';

    public static async show(
        extensionUri: vscode.Uri,
        languageClient: LanguageClientHandle
    ): Promise<void> {
        if (ToolchainPanel.currentPanel) {
            ToolchainPanel.currentPanel.panel?.reveal(vscode.ViewColumn.One);
            await ToolchainPanel.currentPanel.postState();
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'nexusToolchainSetup',
            'Configure Toolchains',
            vscode.ViewColumn.One,
            {
                enableScripts: true,
                localResourceRoots: [extensionUri]
            }
        );

        ToolchainPanel.currentPanel = new ToolchainPanel(panel, languageClient);
    }

    private constructor(
        panel: vscode.WebviewPanel,
        private readonly languageClient: LanguageClientHandle
    ) {
        this.panel = panel;
        this.panel.webview.html = this.getHtml(this.panel.webview);

        this.panel.onDidDispose(() => this.dispose(), undefined, this.disposables);
        this.panel.webview.onDidReceiveMessage(message => this.handleMessage(message), undefined, this.disposables);
    }

    private dispose(): void {
        ToolchainPanel.currentPanel = undefined;
        this.panel = undefined;
        this.disposables.splice(0).forEach(disposable => disposable.dispose());
    }

    private async handleMessage(message: any): Promise<void> {
        try {
            switch (message?.type) {
                case 'ready':
                    await this.postState();
                    break;
                case 'select':
                    await this.selectToolchain(message.kind, message.request as ToolchainRequest | undefined);
                    break;
                case 'plan':
                    await this.updatePlan(message.request as ToolchainRequest);
                    break;
                case 'browse':
                    await this.browseField(message.fieldId, message.currentValue);
                    break;
                case 'openExternal':
                    await this.openExternal(message.url);
                    break;
                case 'save':
                    await this.save(message.request as ToolchainRequest);
                    break;
            }
        } catch (error) {
            await this.postMessage({
                type: 'error',
                message: error instanceof Error ? error.message : String(error)
            });
        }
    }

    private async openExternal(url: string | undefined): Promise<void> {
        if (!url) {
            return;
        }

        await vscode.env.openExternal(vscode.Uri.parse(url));
    }

    private async selectToolchain(kind: string, currentRequest?: ToolchainRequest): Promise<void> {
        if (currentRequest?.kind) {
            this.requestsByKind.set(currentRequest.kind, currentRequest);
        }

        this.selectedKind = kind || this.selectedKind;
        await this.postState();
    }

    private async updatePlan(request: ToolchainRequest): Promise<void> {
        const nextRequest = this.normalizeRequest(request);
        this.requestsByKind.set(nextRequest.kind, nextRequest);
        this.selectedKind = nextRequest.kind;
        await this.postState();
    }

    private async postState(): Promise<void> {
        const toolchains = await this.getSupportedToolchains();
        if (!toolchains.some(toolchain => toolchain.kind === this.selectedKind)) {
            this.selectedKind = toolchains[0]?.kind || 'lazarus';
        }

        const request = await this.getRequest(this.selectedKind);
        const plan = await this.createPlan(request);
        const fields = this.visibleFields(plan.fields || (await this.getSeed(this.selectedKind)).fields || []);
        await this.postMessage({
            type: 'state',
            title: 'Configure Toolchains',
            toolchains,
            selectedKind: this.selectedKind,
            request,
            fields,
            plan
        });
    }

    private async browseField(fieldId: string, currentValue?: string): Promise<void> {
        const request = await this.getRequest(this.selectedKind);
        const plan = await this.createPlan(request);
        const field = this.visibleFields(plan.fields || []).find(item => item.id === fieldId);
        if (!field) {
            return;
        }

        const selectedUris = await vscode.window.showOpenDialog({
            canSelectFiles: field.type === 'file',
            canSelectFolders: field.type === 'folder',
            canSelectMany: false,
            defaultUri: currentValue ? vscode.Uri.file(currentValue) : undefined,
            filters: field.filters,
            openLabel: field.browseLabel || 'Select'
        });

        const selectedValue = selectedUris?.[0]?.fsPath;
        if (selectedValue) {
            await this.postMessage({
                type: 'valueSelected',
                fieldId,
                value: selectedValue
            });
        }
    }

    private async save(request: ToolchainRequest): Promise<void> {
        const cleanRequest = this.normalizeRequest(request);
        const plan = await this.createPlan(cleanRequest);

        const toolchains = this.currentToolchains();
        toolchains[cleanRequest.kind] = this.toStoredConfiguration(cleanRequest, plan);

        await vscode.workspace
            .getConfiguration('nexusPascal')
            .update('toolchains', toolchains, vscode.ConfigurationTarget.Global);
        this.requestsByKind.set(cleanRequest.kind, cleanRequest);
        const hasWarnings = (plan.messages || []).some(message => message.severity === 'warning' || message.severity === 'error');
        vscode.window.showInformationMessage(hasWarnings ? 'Toolchain settings saved with validation warnings.' : 'Toolchain settings saved.');
        await this.postState();
    }

    private async getSupportedToolchains(): Promise<ToolchainDescriptor[]> {
        if (this.supportedToolchains.length === 0) {
            const result = await this.languageClient.sendCustomRequest<ToolchainListSupportedResult>(
                commandListSupported,
                {}
            );
            const toolchains = result.toolchains;
            if (!Array.isArray(toolchains) || toolchains.length === 0) {
                throw new Error('Language server returned no supported toolchains.');
            }

            this.supportedToolchains = toolchains;
        }

        return this.supportedToolchains;
    }

    private async getRequest(kind: string): Promise<ToolchainRequest> {
        const cached = this.requestsByKind.get(kind);
        if (cached) {
            return cached;
        }

        const seed = await this.getSeed(kind);
        const stored = this.currentToolchainConfiguration(kind);
        const request = this.normalizeRequest({
            androidNdkDirectory: stored.androidNdkDirectory || seed.request?.androidNdkDirectory || '',
            androidSdkDirectory: stored.androidSdkDirectory || seed.request?.androidSdkDirectory || '',
            compilerPath: stored.compilerPath || seed.request?.compilerPath || '',
            enabled: stored.enabled,
            fpcDirectory: stored.fpcDirectory || seed.request?.fpcDirectory || '',
            javaHome: stored.javaHome || seed.request?.javaHome || '',
            kind,
            lazarusDirectory: stored.lazarusDirectory || seed.request?.lazarusDirectory || '',
            scope: 'user'
        });
        this.requestsByKind.set(kind, request);
        return request;
    }

    private async getSeed(kind: string): Promise<ToolchainWizardSeed> {
        const cleanKind = kind || 'lazarus';
        let seed = this.seedByKind.get(cleanKind);
        if (!seed) {
            const stored = this.currentToolchainConfiguration(cleanKind);
            seed = await this.languageClient.sendCustomRequest<ToolchainWizardSeed>(
                commandConfigureWizard,
                {
                    androidNdkDirectory: stored.androidNdkDirectory,
                    androidSdkDirectory: stored.androidSdkDirectory,
                    compilerPath: stored.compilerPath,
                    enabled: stored.enabled,
                    fpcDirectory: stored.fpcDirectory,
                    javaHome: stored.javaHome,
                    kind: cleanKind,
                    lazarusDirectory: stored.lazarusDirectory || ''
                }
            );
            this.seedByKind.set(cleanKind, seed);
        }

        return seed;
    }

    private async createPlan(request: ToolchainRequest): Promise<ToolchainPlan> {
        const plan = await this.languageClient.sendCustomRequest<ToolchainPlan>(
            commandPlanConfigure,
            {
                androidNdkDirectory: request.androidNdkDirectory || '',
                androidSdkDirectory: request.androidSdkDirectory || '',
                compilerPath: request.compilerPath || '',
                enabled: request.enabled,
                fpcDirectory: request.fpcDirectory || '',
                javaHome: request.javaHome || '',
                kind: request.kind || 'lazarus',
                lazarusDirectory: request.lazarusDirectory || ''
            }
        );
        return {
            ...plan,
            details: plan.details || [],
            messages: plan.messages || [],
            outputs: plan.outputs || []
        };
    }

    private visibleFields(fields: WizardField[]): WizardField[] {
        return fields.filter(field => field.id !== 'kind');
    }

    private normalizeRequest(request: ToolchainRequest): ToolchainRequest {
        return {
            androidNdkDirectory: request.androidNdkDirectory || '',
            androidSdkDirectory: request.androidSdkDirectory || '',
            compilerPath: request.compilerPath || '',
            enabled: this.toBoolean(request.enabled),
            fpcDirectory: request.fpcDirectory || '',
            javaHome: request.javaHome || '',
            kind: request.kind || this.selectedKind || 'lazarus',
            lazarusDirectory: request.lazarusDirectory || '',
            scope: 'user'
        };
    }

    private currentToolchainConfiguration(kind: string): Required<StoredToolchainConfiguration> {
        const stored = this.currentToolchains()[kind] || {};
        return {
            androidNdkDirectory: stored.androidNdkDirectory || '',
            androidSdkDirectory: stored.androidSdkDirectory || '',
            compilerPath: stored.compilerPath || '',
            enabled: stored.enabled !== false,
            fpcDirectory: stored.fpcDirectory || '',
            javaHome: stored.javaHome || '',
            lazarusDirectory: stored.lazarusDirectory || ''
        };
    }

    private toStoredConfiguration(
        request: ToolchainRequest,
        plan: ToolchainPlan
    ): StoredToolchainConfiguration {
        if (request.kind === 'freepascal') {
            return {
                compilerPath: plan.normalizedCompilerPath || request.compilerPath || undefined,
                enabled: request.enabled,
                fpcDirectory: plan.normalizedFpcDirectory || request.fpcDirectory || undefined
            };
        }

        if (request.kind === 'android') {
            return {
                androidNdkDirectory: plan.normalizedAndroidNdkDirectory || request.androidNdkDirectory || undefined,
                androidSdkDirectory: plan.normalizedAndroidSdkDirectory || request.androidSdkDirectory || undefined,
                enabled: request.enabled,
                javaHome: plan.normalizedJavaHome || request.javaHome || undefined
            };
        }

        return {
            enabled: request.enabled,
            lazarusDirectory: plan.normalizedLazarusDirectory || request.lazarusDirectory || undefined
        };
    }

    private currentToolchains(): StoredToolchainMap {
        return {
            ...(vscode.workspace
                .getConfiguration('nexusPascal')
                .inspect<StoredToolchainMap>('toolchains')
                ?.globalValue || {})
        };
    }

    private toBoolean(value: unknown): boolean {
        if (typeof value === 'boolean') {
            return value;
        }

        if (typeof value === 'string') {
            return value.toLowerCase() === 'true';
        }

        return Boolean(value);
    }

    private async postMessage(message: OutgoingToolchainMessage): Promise<void> {
        await this.panel?.webview.postMessage(message);
    }

    private getHtml(webview: vscode.Webview): string {
        const nonce = this.getNonce();
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource} 'unsafe-inline'; script-src 'nonce-${nonce}';">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Configure Toolchains</title>
    <style>
        body {
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            font-family: var(--vscode-font-family);
            font-size: var(--vscode-font-size);
            margin: 0;
        }
        .shell {
            display: grid;
            grid-template-columns: 260px minmax(420px, 1fr);
            min-height: 100vh;
        }
        .toolchains {
            border-right: 1px solid var(--vscode-panel-border);
            padding: 16px 0;
        }
        .toolchains h1 {
            font-size: 13px;
            font-weight: 600;
            margin: 0 16px 10px;
            text-transform: uppercase;
            color: var(--vscode-descriptionForeground);
        }
        .toolchain {
            display: block;
            width: 100%;
            text-align: left;
            color: var(--vscode-foreground);
            background: transparent;
            border: 0;
            border-left: 3px solid transparent;
            padding: 10px 13px;
            cursor: pointer;
        }
        .toolchain:hover {
            background: var(--vscode-list-hoverBackground);
        }
        .toolchain.selected {
            background: var(--vscode-list-activeSelectionBackground);
            color: var(--vscode-list-activeSelectionForeground);
            border-left-color: var(--vscode-focusBorder);
        }
        .toolchain-label {
            font-weight: 600;
        }
        .toolchain-description {
            color: var(--vscode-descriptionForeground);
            font-size: 12px;
            line-height: 1.35;
            margin-top: 4px;
        }
        .content {
            padding: 24px;
            max-width: 980px;
        }
        h2 {
            font-size: 22px;
            margin: 0 0 4px;
        }
        .selected-description {
            color: var(--vscode-descriptionForeground);
            margin-bottom: 22px;
        }
        .grid {
            display: grid;
            grid-template-columns: minmax(320px, 440px) minmax(320px, 1fr);
            gap: 24px;
        }
        .field {
            margin-bottom: 16px;
        }
        label {
            display: block;
            margin-bottom: 6px;
            font-weight: 600;
        }
        input, select {
            box-sizing: border-box;
            width: 100%;
            color: var(--vscode-input-foreground);
            background: var(--vscode-input-background);
            border: 1px solid var(--vscode-input-border);
            padding: 6px 8px;
            font-family: var(--vscode-font-family);
        }
        input[type="checkbox"] {
            width: auto;
            margin-right: 8px;
        }
        .check-row {
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .browse-row {
            display: grid;
            grid-template-columns: 1fr auto;
            gap: 8px;
        }
        .description, .summary {
            color: var(--vscode-descriptionForeground);
            line-height: 1.35;
        }
        .field-message {
            margin-top: 6px;
            line-height: 1.35;
        }
        .suggestions {
            display: grid;
            gap: 6px;
            margin-top: 8px;
        }
        .suggestion {
            display: grid;
            gap: 2px;
        }
        .suggestion button {
            justify-self: start;
        }
        .suggestion-reason {
            color: var(--vscode-descriptionForeground);
            font-size: 12px;
            line-height: 1.35;
        }
        button {
            color: var(--vscode-button-foreground);
            background: var(--vscode-button-background);
            border: 0;
            padding: 7px 12px;
            cursor: pointer;
        }
        button:hover {
            background: var(--vscode-button-hoverBackground);
        }
        button.secondary {
            color: var(--vscode-button-secondaryForeground);
            background: var(--vscode-button-secondaryBackground);
        }
        button:disabled {
            opacity: 0.55;
            cursor: default;
        }
        .actions {
            display: flex;
            justify-content: flex-end;
            margin-top: 20px;
        }
        .preview {
            border: 1px solid var(--vscode-panel-border);
            padding: 14px;
            min-height: 320px;
        }
        .preview h3 {
            font-size: 15px;
            margin: 0 0 10px;
        }
        .section {
            margin-bottom: 18px;
        }
        .message {
            margin: 8px 0;
        }
        .info {
            color: var(--vscode-descriptionForeground);
        }
        .warning {
            color: var(--vscode-editorWarning-foreground);
        }
        .error {
            color: var(--vscode-errorForeground);
        }
        .details {
            display: grid;
            grid-template-columns: minmax(120px, auto) 1fr;
            gap: 6px 12px;
        }
        .detail-label {
            color: var(--vscode-descriptionForeground);
        }
        .detail-value {
            word-break: break-word;
        }
    </style>
</head>
<body>
    <div class="shell">
        <aside class="toolchains">
            <h1>Toolchains</h1>
            <div id="toolchainList"></div>
        </aside>
        <main class="content">
            <h2 id="toolchainTitle"></h2>
            <div id="toolchainDescription" class="selected-description"></div>
            <div class="grid">
                <section id="fields"></section>
                <section class="preview">
                    <div class="section">
                        <h3>Plan</h3>
                        <div id="summary" class="summary"></div>
                        <div id="messages"></div>
                    </div>
                    <div class="section">
                        <h3>Details</h3>
                        <div id="details" class="details"></div>
                    </div>
                </section>
            </div>
        </main>
    </div>
    <script nonce="${nonce}">
        const vscode = acquireVsCodeApi();
        let toolchains = [];
        let selectedKind = '';
        let fields = [];
        let planTimer;

        const toolchainListNode = document.getElementById('toolchainList');
        const toolchainTitleNode = document.getElementById('toolchainTitle');
        const toolchainDescriptionNode = document.getElementById('toolchainDescription');
        const fieldsNode = document.getElementById('fields');
        const summaryNode = document.getElementById('summary');
        const messagesNode = document.getElementById('messages');
        const detailsNode = document.getElementById('details');

        window.addEventListener('message', event => {
            const message = event.data;
            if (message.type === 'state') {
                toolchains = message.toolchains || [];
                selectedKind = message.selectedKind || '';
                fields = message.fields || [];
                renderToolchains();
                renderHeader();
                renderFields(message.request || {});
                renderPlan(message.plan || {});
            } else if (message.type === 'valueSelected') {
                const input = document.querySelector('[data-field-id="' + cssEscape(message.fieldId) + '"]');
                if (input) {
                    input.value = message.value;
                    requestPlan();
                }
            } else if (message.type === 'error') {
                renderError(message.message);
            }
        });

        function renderToolchains() {
            toolchainListNode.innerHTML = '';
            for (const toolchain of toolchains) {
                const button = document.createElement('button');
                button.className = 'toolchain' + (toolchain.kind === selectedKind ? ' selected' : '');
                button.addEventListener('click', () => vscode.postMessage({
                    type: 'select',
                    kind: toolchain.kind,
                    request: getRequest()
                }));

                const label = document.createElement('div');
                label.className = 'toolchain-label';
                label.textContent = toolchain.label || toolchain.kind;
                button.appendChild(label);

                if (toolchain.description) {
                    const description = document.createElement('div');
                    description.className = 'toolchain-description';
                    description.textContent = toolchain.description;
                    button.appendChild(description);
                }
                toolchainListNode.appendChild(button);
            }
        }

        function renderHeader() {
            const selected = toolchains.find(toolchain => toolchain.kind === selectedKind) || {};
            toolchainTitleNode.textContent = selected.label || selectedKind || 'Toolchain';
            toolchainDescriptionNode.textContent = selected.description || '';
        }

        function renderFields(request) {
            fieldsNode.innerHTML = '';
            for (const field of fields) {
                if (field.hidden) {
                    continue;
                }
                fieldsNode.appendChild(renderField(field, request[field.id]));
            }

            const actions = document.createElement('div');
            actions.className = 'actions';
            const saveButton = document.createElement('button');
            saveButton.id = 'saveButton';
            saveButton.textContent = 'Save';
            saveButton.addEventListener('click', () => vscode.postMessage({
                type: 'save',
                request: getRequest()
            }));
            actions.appendChild(saveButton);
            fieldsNode.appendChild(actions);
        }

        function renderField(field, requestValue) {
            const container = document.createElement('div');
            container.className = 'field';

            if (field.type === 'checkbox') {
                const row = document.createElement('div');
                row.className = 'check-row';
                const input = document.createElement('input');
                input.type = 'checkbox';
                input.checked = toBoolean(requestValue ?? field.value);
                input.disabled = Boolean(field.disabled);
                input.dataset.fieldId = field.id;
                input.addEventListener('change', requestPlan);
                const label = document.createElement('label');
                label.textContent = field.label;
                label.style.marginBottom = '0';
                row.appendChild(input);
                row.appendChild(label);
                container.appendChild(row);
            } else {
                const label = document.createElement('label');
                label.textContent = field.label;
                container.appendChild(label);

                if (field.type === 'select') {
                    const select = document.createElement('select');
                    select.dataset.fieldId = field.id;
                    select.disabled = Boolean(field.disabled);
                    for (const option of field.options || []) {
                        const optionNode = document.createElement('option');
                        optionNode.value = option.value;
                        optionNode.textContent = option.label;
                        select.appendChild(optionNode);
                    }
                    select.value = String(requestValue ?? field.value ?? '');
                    select.addEventListener('change', requestPlan);
                    container.appendChild(select);
                } else if (field.type === 'file' || field.type === 'folder') {
                    const row = document.createElement('div');
                    row.className = 'browse-row';
                    const input = createTextInput(field, requestValue);
                    const button = document.createElement('button');
                    button.className = 'secondary';
                    button.textContent = 'Browse';
                    button.disabled = Boolean(field.disabled);
                    button.addEventListener('click', () => vscode.postMessage({
                        type: 'browse',
                        fieldId: field.id,
                        currentValue: input.value
                    }));
                    row.appendChild(input);
                    row.appendChild(button);
                    container.appendChild(row);
                } else {
                    container.appendChild(createTextInput(field, requestValue));
                }
            }

            if (field.description) {
                const description = document.createElement('div');
                description.className = 'description';
                description.textContent = field.description;
                container.appendChild(description);
            }

            if (field.message) {
                const fieldMessage = document.createElement('div');
                fieldMessage.className = 'field-message ' + (field.severity || (field.valid === false ? 'error' : 'info'));
                fieldMessage.textContent = field.message;
                container.appendChild(fieldMessage);
            }

            if (Array.isArray(field.suggestions) && field.suggestions.length > 0) {
                container.appendChild(renderSuggestions(field));
            }

            return container;
        }

        function renderSuggestions(field) {
            const suggestions = document.createElement('div');
            suggestions.className = 'suggestions';

            for (const suggestion of field.suggestions || []) {
                const row = document.createElement('div');
                row.className = 'suggestion';

                const button = document.createElement('button');
                button.className = 'secondary';
                button.textContent = suggestion.label || suggestion.value;
                button.addEventListener('click', () => {
                    if (suggestion.kind === 'url') {
                        vscode.postMessage({
                            type: 'openExternal',
                            url: suggestion.value
                        });
                        return;
                    }

                    const input = document.querySelector('[data-field-id="' + cssEscape(field.id) + '"]');
                    if (input) {
                        input.value = suggestion.value || '';
                        requestPlan();
                    }
                });
                row.appendChild(button);

                if (suggestion.reason) {
                    const reason = document.createElement('div');
                    reason.className = 'suggestion-reason';
                    reason.textContent = suggestion.reason;
                    row.appendChild(reason);
                }

                suggestions.appendChild(row);
            }

            return suggestions;
        }

        function createTextInput(field, requestValue) {
            const input = document.createElement('input');
            input.dataset.fieldId = field.id;
            input.value = String(requestValue ?? field.value ?? '');
            input.placeholder = field.placeholder || '';
            input.disabled = Boolean(field.disabled);
            input.readOnly = field.type === 'readonly';
            input.addEventListener('input', requestPlan);
            return input;
        }

        function requestPlan() {
            clearTimeout(planTimer);
            planTimer = setTimeout(() => vscode.postMessage({
                type: 'plan',
                request: getRequest()
            }), 120);
        }

        function getRequest() {
            const request = { kind: selectedKind };
            for (const field of fields) {
                if (field.hidden) {
                    continue;
                }
                const input = document.querySelector('[data-field-id="' + cssEscape(field.id) + '"]');
                if (!input) {
                    continue;
                }
                request[field.id] = field.type === 'checkbox'
                    ? input.checked
                    : input.value;
            }
            return request;
        }

        function renderPlan(plan) {
            const saveButton = document.getElementById('saveButton');
            if (saveButton) {
                saveButton.disabled = !plan.canExecute;
            }

            summaryNode.textContent = plan.summary || '';
            messagesNode.innerHTML = '';
            for (const message of plan.messages || []) {
                const node = document.createElement('div');
                node.className = 'message ' + message.severity;
                node.textContent = message.text;
                messagesNode.appendChild(node);
            }

            detailsNode.innerHTML = '';
            for (const detail of plan.details || []) {
                const label = document.createElement('div');
                label.className = 'detail-label';
                label.textContent = detail.label;
                const value = document.createElement('div');
                value.className = 'detail-value';
                value.textContent = detail.value;
                detailsNode.appendChild(label);
                detailsNode.appendChild(value);
            }
        }

        function renderError(message) {
            messagesNode.innerHTML = '';
            const node = document.createElement('div');
            node.className = 'message error';
            node.textContent = message;
            messagesNode.appendChild(node);
        }

        function cssEscape(value) {
            return value.replace(/["\\\\]/g, '\\\\$&');
        }

        function toBoolean(value) {
            if (typeof value === 'boolean') {
                return value;
            }
            if (typeof value === 'string') {
                return value.toLowerCase() === 'true';
            }
            return Boolean(value);
        }

        vscode.postMessage({ type: 'ready' });
    </script>
</body>
</html>`;
    }

    private getNonce(): string {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        let nonce = '';
        for (let index = 0; index < 32; index++) {
            nonce += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return nonce;
    }
}
