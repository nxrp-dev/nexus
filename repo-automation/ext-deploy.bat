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