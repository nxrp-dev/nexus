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

REM Build Nexus Pascal and ensure the local VS Code extension junction points here.

for %%I in ("%~dp0..") do set "NexusRoot=%%~fI"
set "RepoRoot=%NexusRoot%\projects\nexuscode"
set "ExtensionDir=%USERPROFILE%\.vscode\extensions"
set "TargetTriple=x86_64-win64"

if not exist "%RepoRoot%\package.json" (
    echo ERROR: package.json not found at "%RepoRoot%".
    exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo ERROR: npm was not found on PATH.
    exit /b 1
)

where node >nul 2>nul
if errorlevel 1 (
    echo ERROR: node was not found on PATH.
    exit /b 1
)

if not exist "%ExtensionDir%" (
    mkdir "%ExtensionDir%"
    if errorlevel 1 (
        echo ERROR: Could not create "%ExtensionDir%".
        exit /b 1
    )
)

pushd "%RepoRoot%" || exit /b 1

for /f "delims=" %%I in ('node -p "const p=require('./package.json'); p.publisher+'.'+p.name+'-'+p.version"') do set "ExtensionFolder=%%I"
if "%ExtensionFolder%"=="" (
    echo ERROR: Could not read extension identity from package.json.
    goto Fail
)

set "ExtensionLink=%ExtensionDir%\%ExtensionFolder%"

if not exist node_modules (
    echo Installing dependencies from package-lock.json...
    call npm.cmd ci
    if errorlevel 1 goto Fail
) else (
    echo Synchronizing dependencies...
    call npm.cmd install
    if errorlevel 1 goto Fail
)

echo Building Nexus Pascal...
call npm.cmd run esbuild
if errorlevel 1 goto Fail

if exist "%NexusRoot%\output\NexusBuild\%TargetTriple%\nexusbuild.exe" (
    if not exist "%RepoRoot%\bin\%TargetTriple%" mkdir "%RepoRoot%\bin\%TargetTriple%"
    echo Promoting NexusBuild executable...
    copy /Y "%NexusRoot%\output\NexusBuild\%TargetTriple%\nexusbuild.exe" "%RepoRoot%\bin\%TargetTriple%\nexusbuild.exe" >nul
    if errorlevel 1 goto Fail
) else (
    echo WARNING: NexusBuild executable was not found. Build NexusTools\Build\nexusbuild.lpi before using Nexus project tasks.
)

if exist "%ExtensionLink%" (
    fsutil reparsepoint query "%ExtensionLink%" >nul 2>nul
    if errorlevel 1 (
        echo ERROR: "%ExtensionLink%" exists and is not a junction.
        goto Fail
    )

    echo Replacing local extension junction...
    rmdir "%ExtensionLink%"
    if errorlevel 1 goto Fail
)

echo Creating local extension junction...
mklink /J "%ExtensionLink%" "%RepoRoot%"
if errorlevel 1 goto Fail

echo.
echo Nexus Pascal built and locally deployed.
echo Restart VS Code or run "Developer: Reload Window" to load the update.

popd
exit /b 0

:Fail
echo.
echo Nexus Pascal deploy failed.
popd
exit /b 1
