/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

import * as fs from 'fs';
import * as path from 'path';
import { XMLParser } from 'fast-xml-parser';

export interface LazarusBuildModeInfo {
    name: string;
    isDefault: boolean;
}

export function readLazarusBuildModes(file: string): LazarusBuildModeInfo[] {
    if (!fs.existsSync(file) || path.extname(file).toLowerCase() !== '.lpi') {
        return [];
    }

    const parser = new XMLParser({
        ignoreAttributes: false,
        attributeNamePrefix: ''
    });

    const content = fs.readFileSync(file, 'utf8');
    const document = parser.parse(content);
    const items = getBuildModeItems(document?.CONFIG?.ProjectOptions?.BuildModes);

    return items
        .map((item: any) => readBuildMode(item))
        .filter((mode: LazarusBuildModeInfo | undefined): mode is LazarusBuildModeInfo => mode !== undefined);
}

function getBuildModeItems(buildModes: any): any[] {
    if (!buildModes || typeof buildModes !== 'object') {
        return [];
    }

    const items: any[] = [];
    for (const [key, value] of Object.entries(buildModes)) {
        if (key === 'Item' || /^Item\d+$/i.test(key)) {
            items.push(...asArray(value));
        }
    }

    return items;
}

function readBuildMode(item: any): LazarusBuildModeInfo | undefined {
    const name = typeof item?.Name === 'string' ? item.Name.trim() : '';
    if (!name) {
        return undefined;
    }

    return {
        name,
        isDefault: String(item.Default || '').toLowerCase() === 'true'
    };
}

function asArray(value: any): any[] {
    if (value === undefined || value === null) {
        return [];
    }

    return Array.isArray(value) ? value : [value];
}
