/*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import type { PascalProjectKind } from '../model/pascalProject';
export type { PascalProjectKind } from '../model/pascalProject';

export interface LanguageServerProjectContext {
    kind: PascalProjectKind;
    label: string;
    projectFile: string;
    workingDirectory: string;
    buildMode?: string;
    fpcOptions: string[];
    allowFpcGlobalUnitPaths: boolean;
}
