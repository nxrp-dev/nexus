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

set ScriptDir=%~dp0
set RepoRoot=%ScriptDir%..

pushd "%RepoRoot%" || exit /b 1

if not exist package.json (
    echo package.json not found in "%RepoRoot%"
    popd
    exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo npm not found.
    popd
    exit /b 1
)

where code >nul 2>nul
if errorlevel 1 (
    echo VS Code command line tool "code" not found.
    popd
    exit /b 1
)

if not exist node_modules (
    call npm install
    if errorlevel 1 goto Fail
)

call npm run compile
if errorlevel 1 goto Fail

call npx @vscode/vsce package
if errorlevel 1 goto Fail

for /f "delims=" %%F in ('dir /b /o-d *.vsix 2^>nul') do (
    set VsixFile=%%F
    goto InstallVsix
)

echo No VSIX file found.
goto Fail

:InstallVsix
echo Installing %VsixFile%
call code --install-extension "%VsixFile%" --force
if errorlevel 1 goto Fail

echo Done.
echo Reload VS Code to activate the updated extension.

popd
exit /b 0

:Fail
echo Failed.
popd
exit /b 1