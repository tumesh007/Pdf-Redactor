#!/usr/bin/env bash
#
# install.sh — sets up PDF Redactor on Ubuntu/Linux.
#
# What it does:
#   1. Verifies Python 3.12+ is available.
#   2. Creates a virtual environment in ./venv (skips if it already exists).
#   3. Installs requirements.txt into that venv.
#   4. Prints how to run the app.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

REQUIRED_MAJOR=3
REQUIRED_MINOR=12

echo "== PDF Redactor installer =="
echo "Project root: $PROJECT_ROOT"

# --- 1. Find a usable Python interpreter --------------------------------

PYTHON_BIN=""
for candidate in python3.12 python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
        version_output="$("$candidate" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "0.0")"
        major="${version_output%%.*}"
        minor="${version_output##*.}"
        if [ "$major" -gt "$REQUIRED_MAJOR" ] || { [ "$major" -eq "$REQUIRED_MAJOR" ] && [ "$minor" -ge "$REQUIRED_MINOR" ]; }; then
            PYTHON_BIN="$candidate"
            break
        fi
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo "ERROR: Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR}+ was not found on this system." >&2
    echo "Install it first, e.g.:" >&2
    echo "  sudo apt update && sudo apt install python3.12 python3.12-venv" >&2
    exit 1
fi

echo "Using interpreter: $($PYTHON_BIN --version) ($PYTHON_BIN)"

# --- 2. Create virtual environment ---------------------------------------

if [ -d "venv" ]; then
    echo "Virtual environment 'venv' already exists — reusing it."
else
    echo "Creating virtual environment in ./venv ..."
    "$PYTHON_BIN" -m venv venv
fi

# --- 3. Install dependencies ----------------------------------------------

echo "Installing dependencies from requirements.txt ..."
# shellcheck disable=SC1091
source venv/bin/activate
pip install --upgrade pip >/dev/null
pip install -r requirements.txt

echo ""
echo "== Installation complete =="
echo ""
echo "To run PDF Redactor:"
echo "  source venv/bin/activate"
echo "  python main.py"
echo ""
echo "To run the unit tests:"
echo "  source venv/bin/activate"
echo "  pytest tests/ -v"
echo ""
echo "To build a standalone executable, see build.sh."
