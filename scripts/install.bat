@echo off
REM Install PDF Redactor on Windows

echo Installing PDF Redactor...
cd /d "%~dp0.."

REM Check if running as admin
net session >nul 2>&1
if errorlevel 1 (
    echo Please run as Administrator
    pause
    exit /b 1
)

REM Install Python dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Create installation directory
set INSTALL_DIR=%ProgramFiles%\PDFRedactor
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Copy files
echo Copying files...
xcopy src \%INSTALL_DIR%\src /E /I /Y
xcopy config \%INSTALL_DIR%\config /E /I /Y

REM Create Start Menu shortcut
echo Creating shortcuts...
set SHORTCUT_PATH=%ProgramData%\Microsoft\Windows\Start Menu\Programs\PDF Redactor.lnk
python3 -c "import sys; sys.path.insert(0, 'scripts'); from create_shortcut import create_shortcut; create_shortcut('%INSTALL_DIR%', '%SHORTCUT_PATH%')"

echo Installation complete!
echo Launch from Start Menu or run: python -m src.main
pause
