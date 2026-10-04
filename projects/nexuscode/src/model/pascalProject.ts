/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import { FpcTaskDefinition, LazarusTaskDefinition } from '../providers/taskDefinitions';

export type PascalProjectKind = 'fpc' | 'lazarus' | 'nexus';

export type PascalProject = FpcProjectModel | LazarusProjectModel | NexusProjectModel;
export type PascalBuildTarget = FpcBuildTarget | LazarusBuildTarget | NexusBuildTarget;

export interface BasePascalProject {
    id: string;
    kind: PascalProjectKind;
    label: string;
    file: string;
    fileExists: boolean;
    isDefault: boolean;
    targets: PascalBuildTarget[];
}

export interface FpcProjectModel extends BasePascalProject {
    kind: 'fpc';
    targets: FpcBuildTarget[];
}

export interface LazarusProjectModel extends BasePascalProject {
    kind: 'lazarus';
    targets: LazarusBuildTarget[];
}

export interface NexusProjectModel extends BasePascalProject {
    kind: 'nexus';
    descriptorFile: string;
    targets: NexusBuildTarget[];
}

export interface BasePascalBuildTarget {
    id: string;
    kind: PascalProjectKind;
    label: string;
    projectId: string;
    projectFile: string;
    isDefault: boolean;
    isInProjectFile: boolean;
    canBuild: boolean;
}

export interface FpcBuildTarget extends BasePascalBuildTarget {
    kind: 'fpc';
    canBuild: true;
    taskDefinition: FpcTaskDefinition;
}

export interface LazarusBuildTarget extends BasePascalBuildTarget {
    kind: 'lazarus';
    canBuild: true;
    buildMode?: string;
    cwd: string;
    taskDefinition?: LazarusTaskDefinition;
}

export interface NexusBuildTarget extends BasePascalBuildTarget {
    kind: 'nexus';
    canBuild: true;
    descriptorFile: string;
}
