/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import { WorkspaceTasksService } from '../services/workspaceTasksService';
import { FpcTaskProvider, LazarusTaskProvider, NexusTaskProvider } from '../vscode/vscodeTaskProvider';
import { FpcProjectAdapter } from './fpcProjectAdapter';
import { LazarusProjectAdapter } from './lazarusProjectAdapter';
import { NexusProjectAdapter } from './nexusProjectAdapter';
import { PascalProjectAdapterRegistry } from './pascalProjectAdapter';

export function createPascalProjectAdapterRegistry(
    workspaceRoot: string,
    workspaceTasks: WorkspaceTasksService,
    fpcTaskProvider: FpcTaskProvider,
    lazarusTaskProvider: LazarusTaskProvider,
    nexusTaskProvider: NexusTaskProvider
): PascalProjectAdapterRegistry {
    const registry = new PascalProjectAdapterRegistry();
    registry.register(new NexusProjectAdapter(workspaceRoot, nexusTaskProvider));
    registry.register(new FpcProjectAdapter(workspaceRoot, workspaceTasks, fpcTaskProvider));
    registry.register(new LazarusProjectAdapter(workspaceRoot, workspaceTasks, lazarusTaskProvider));
    return registry;
}
