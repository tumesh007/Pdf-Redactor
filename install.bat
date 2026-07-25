@echo off
REM install.bat - sets up PDF Redactor on Windows.
REM
REM What it does:
REM   1. Verifies a usable Python (3.12+) is on PATH.
REM   2. Creates a virtual environment in .\venv (skips if it exists).
REM   3. Installs requirements.txt into that venv.
REM   4. Prints how to run the app.
REM
REM Usage: double-click install.bat, or run it from a Command Prompt:
REM   install.bat

setlocal enabledelayedexpansion

set "PROJECT_ROOT=%~dp0"
cd /d "%PROJECT_ROOT%"

echo == PDF Redactor installer ==
echo Project root: %PROJECT_ROOT%

REM --- 1. Find a usable Python interpreter ---------------------------------

set "PYTHON_BIN="

for %%P in (py python python3) do (
    if not defined PYTHON_BIN (
        where %%P >nul 2>nul
        if !errorlevel! equ 0 (
            set "CANDIDATE=%%P"
            call :check_version "!CANDIDATE!"
            if !VERSION_OK! equ 1 (
                set "PYTHON_BIN=!CANDIDATE!"
            )
        )
    )
)

if not defined PYTHON_BIN (
    echo ERROR: Python 3.12+ was not found on PATH.
    echo Install it from https://www.python.org/downloads/ and ensure
    echo "Add python.exe to PATH" is checked during setup, then re-run this script.
    exit /b 1
)

for /f "delims=" %%V in ('%PYTHON_BIN% --version') do set "PY_VERSION_STRING=%%V"
echo Using interpreter: %PY_VERSION_STRING% (%PYTHON_BIN%)

REM --- 2. Create virtual environment ---------------------------------------

if exist "venv\Scripts\activate.bat" (
    echo Virtual environment 'venv' already exists - reusing it.
) else (
    echo Creating virtual environment in .\venv ...
    %PYTHON_BIN% -m venv venv
    if !errorlevel! neq 0 (
        echo ERROR: Failed to create virtual environment.
        exit /b 1
    )
)

REM --- 3. Install dependencies ----------------------------------------------

echo Installing dependencies from requirements.txt ...
call venv\Scripts\activate.bat
python -m pip install --upgrade pip >nul
pip install -r requirements.txt
if !errorlevel! neq 0 (
    echo ERROR: Dependency installation failed.
    exit /b 1
)

echo.
echo == Installation complete ==
echo.
echo To run PDF Redactor:
echo   venv\Scripts\activate.bat
echo   python main.py
echo.
echo To run the unit tests:
echo   venv\Scripts\activate.bat
echo   pytest tests\ -v
echo.
echo To build a standalone executable, see build.bat.

exit /b 0

REM --------------------------------------------------------------------------
REM :check_version <python_command>
REM Sets VERSION_OK=1 if the given Python command is version 3.12+, else 0.
REM --------------------------------------------------------------------------
:check_version
set "VERSION_OK=0"
for /f "delims=" %%O in ('%~1 -c "import sys; print(1 if sys.version_info[:2] >= (3, 12) else 0)" 2^>nul') do set "VERSION_OK=%%O"
if not defined VERSION_OK set "VERSION_OK=0"
exit /b 0
