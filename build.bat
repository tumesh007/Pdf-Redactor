@echo off
REM build.bat - builds a standalone Windows executable with PyInstaller.
REM
REM Must be run on Windows (PyInstaller does not cross-compile); build
REM the Linux binary on Ubuntu using build.sh instead.
REM
REM Usage:
REM   install.bat      (first, if you haven't already)
REM   build.bat

setlocal enabledelayedexpansion

set "PROJECT_ROOT=%~dp0"
cd /d "%PROJECT_ROOT%"

if not exist "venv\Scripts\activate.bat" (
    echo ERROR: venv not found. Run install.bat first.
    exit /b 1
)

call venv\Scripts\activate.bat

python -c "import PyInstaller" >nul 2>nul
if !errorlevel! neq 0 (
    echo PyInstaller not found in venv; installing...
    pip install pyinstaller
)

echo Building standalone executable...
pyinstaller --noconfirm --onefile --windowed ^
    --name "PDFRedactor" ^
    --add-data "resources;resources" ^
    main.py

if !errorlevel! neq 0 (
    echo ERROR: Build failed.
    exit /b 1
)

echo.
echo == Build complete ==
echo Executable: %PROJECT_ROOT%dist\PDFRedactor.exe
