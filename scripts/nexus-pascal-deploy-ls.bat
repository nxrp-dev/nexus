@echo off
setlocal

REM Build and promote NexusLS into the local Nexus Pascal VS Code extension bin.
REM This script does not stop running language-server processes. If nexusls.exe
REM is locked, close/reload VS Code and run this again.

set "NexusRoot=C:\gitdev\nexus"
set "ExtensionRoot=C:\gitdev\tools\nexus-pascal"
set "TargetTriple=x86_64-win64"

set "SourceDir=%NexusRoot%\output\NexusLS\%TargetTriple%"
set "TargetDir=%ExtensionRoot%\bin\%TargetTriple%"

if not exist "%NexusRoot%\NexusLS\nexusls.lpi" (
    echo ERROR: NexusLS project not found at "%NexusRoot%\NexusLS\nexusls.lpi".
    goto DoneFail
)

where lazbuild >nul 2>nul
if errorlevel 1 (
    echo ERROR: lazbuild was not found on PATH.
    goto DoneFail
)

echo Building NexusLS...
pushd "%NexusRoot%"
if errorlevel 1 goto DoneFail
lazbuild NexusLS\nexusls.lpi
if errorlevel 1 goto Fail
popd

if not exist "%SourceDir%\nexusls.exe" (
    echo ERROR: Built nexusls.exe was not found at "%SourceDir%\nexusls.exe".
    goto DoneFail
)

if not exist "%TargetDir%" (
    mkdir "%TargetDir%"
    if errorlevel 1 goto DoneFail
)

echo Promoting NexusLS executable...
copy /Y "%SourceDir%\nexusls.exe" "%TargetDir%\nexusls.exe" >nul
if errorlevel 1 (
    echo ERROR: Could not copy nexusls.exe. It may be locked by a running VS Code language server.
    echo Close or reload VS Code, then run this script again.
    goto DoneFail
)

if exist "%SourceDir%\sqlite3.dll" (
    copy /Y "%SourceDir%\sqlite3.dll" "%TargetDir%\sqlite3.dll" >nul
    if errorlevel 1 goto DoneFail
)

if exist "%SourceDir%\nexuspas-search-paths.json" (
    copy /Y "%SourceDir%\nexuspas-search-paths.json" "%TargetDir%\nexuspas-search-paths.json" >nul
    if errorlevel 1 goto DoneFail
)

echo.
echo NexusLS deployed to:
echo   %TargetDir%
echo Restart VS Code or run "Developer: Reload Window" to use the update.
goto DoneSuccess

:DoneSuccess
echo.
pause
exit /b 0

:Fail
echo.
echo NexusLS deploy failed.
popd

:DoneFail
echo.
pause
exit /b 1
