@echo off
setlocal

REM Build and deploy MkDocs site to GitHub Pages using gh-pages.
REM Run from the repository root.

cd /d "%~dp0.."

if not exist "mkdocs.yml" (
    echo ERROR: mkdocs.yml not found.
    echo Run this script from inside the repo scripts/tools folder, or fix the cd path.
    exit /b 1
)

where git >nul 2>nul
if errorlevel 1 (
    echo ERROR: git was not found on PATH.
    exit /b 1
)

echo Building MkDocs site...
C:\devtools\venvs\mkdocs\Scripts\mkdocs build
if errorlevel 1 (
    echo ERROR: MkDocs build failed.
    exit /b 1
)

echo Deploying MkDocs site to gh-pages...
C:\devtools\venvs\mkdocs\Scripts\mkdocs gh-deploy --force
if errorlevel 1 (
    echo ERROR: MkDocs deploy failed.
    exit /b 1
)

echo.
echo Documentation deployed successfully.
exit /b 0