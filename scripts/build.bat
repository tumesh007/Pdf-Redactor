@echo off
REM Build PDF Redactor for Windows

echo Building PDF Redactor...
cd /d "%~dp0.."

REM Install dependencies
pip install -r requirements.txt
pip install pyinstaller

REM Build executable
echo Creating executable...
pyinstaller --onefile --windowed --icon=assets/icon.ico --name PDFRedactor src/main.py

echo Build complete!
echo Output: dist\PDFRedactor.exe
pause
