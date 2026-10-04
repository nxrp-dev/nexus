@REM Copyright (c) 2026 Kevin Collins.
@REM
@REM This Source Code Form is subject to the terms of the Mozilla Public
@REM License, v. 2.0. If a copy of the MPL was not distributed with this
@REM file, You can obtain one at https://mozilla.org/MPL/2.0/.
@REM
@REM This Source Code Form is "Incompatible With Secondary Licenses",
@REM as defined by the Mozilla Public License, v. 2.0.
@REM
@REM SPDX-License-Identifier: MPL-2.0-no-copyleft-exception

@echo off
setlocal

REM Serve MkDocs site locally for testing.
REM Run from the repository root.

cd /d "%~dp0.."

if not exist "mkdocs.yml" (
    echo ERROR: mkdocs.yml not found.
    echo Run this script from inside the repo-automation folder, or fix the cd path.
    exit /b 1
)

echo Starting MkDocs dev server...
echo Open: http://127.0.0.1:8000/
echo.
C:\devtools\venvs\mkdocs\Scripts\mkdocs serve

exit /b %ERRORLEVEL%