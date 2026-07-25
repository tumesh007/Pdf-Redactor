@echo off
REM Run PDF Redactor application

cd /d "%~dp0.."

REM Check Python installation
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python not found. Please install Python 3.8 or higher.
    pause
    exit /b 1
)

REM Install dependencies if needed
python -c "import PyQt5" >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies...
    pip install -r requirements.txt
)

REM Run application
echo Launching PDF Redactor...
python src/main.py
pause
