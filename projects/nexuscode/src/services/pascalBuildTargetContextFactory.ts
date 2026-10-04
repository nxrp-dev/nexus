/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import { CompileOption } from '../languageServer/options';
import { LanguageServerProjectContext } from '../languageServer/projectContext';
import { PascalBuildTarget } from '../model/pascalProject';
import { PascalProjectAdapterRegistry } from '../projectTypes/pascalProjectAdapter';

export class PascalBuildTargetContextFactory {
    public constructor(private readonly adapters: PascalProjectAdapterRegistry) {
    }

    public createCompileOption(target: PascalBuildTarget | undefined): CompileOption {
        if (!target) {
            return new CompileOption();
        }

        return this.adapters.get(target.kind).createCompileOption(target);
    }

    public createLanguageServerContext(target: PascalBuildTarget | undefined): LanguageServerProjectContext {
        if (!target) {
            return this.createLanguageServerContextFromCompileOption(new CompileOption());
        }

        return this.adapters.get(target.kind).createLanguageServerContext(target);
    }

    private createLanguageServerContextFromCompileOption(option: CompileOption): LanguageServerProjectContext {
        const fpcOptions = option.toOptionArray()
            .filter(value => value.length > 0 && !value.startsWith('-v'));

        return {
            kind: 'fpc',
            label: option.label,
            projectFile: option.file,
            workingDirectory: option.cwd,
            fpcOptions,
            allowFpcGlobalUnitPaths: true
        };
    }
}
