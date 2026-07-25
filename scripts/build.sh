#!/bin/bash
# Build PDF Redactor for Linux

set -e

echo "Building PDF Redactor..."

cd "$(dirname "$0")/.."

# Install dependencies
pip install -r requirements.txt
pip install pyinstaller

# Build executable
echo "Creating executable..."
pyinstaller --onefile --windowed --name PDFRedactor src/main.py

echo "Build complete!"
echo "Output: dist/PDFRedactor"
