#!/usr/bin/env bash
#
# build.sh — builds a standalone Linux executable with PyInstaller.
#
# Must be run on Ubuntu/Linux (PyInstaller does not cross-compile);
# build the Windows .exe on Windows using build.bat instead.
#
# Usage:
#   ./install.sh        # first, if you haven't already
#   ./build.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

if [ ! -d "venv" ]; then
    echo "ERROR: venv not found. Run ./install.sh first." >&2
    exit 1
fi

# shellcheck disable=SC1091
source venv/bin/activate

if ! python -c "import PyInstaller" >/dev/null 2>&1; then
    echo "PyInstaller not found in venv; installing..."
    pip install pyinstaller
fi

echo "Building standalone executable..."
pyinstaller --noconfirm --onefile --windowed \
    --name "PDFRedactor" \
    --add-data "resources:resources" \
    main.py

echo ""
echo "== Build complete =="
echo "Executable: $PROJECT_ROOT/dist/PDFRedactor"
