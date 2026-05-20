@echo off
setlocal

REM Serve MkDocs site locally for testing.
REM Run from the repository root.

cd /d "%~dp0.."

if not exist "mkdocs.yml" (
    echo ERROR: mkdocs.yml not found.
    echo Run this script from inside the repo scripts/tools folder, or fix the cd path.
    exit /b 1
)

echo Starting MkDocs dev server...
echo Open: http://127.0.0.1:8000/
echo.
C:\devtools\venvs\mkdocs\Scripts\mkdocs serve

exit /b %ERRORLEVEL%