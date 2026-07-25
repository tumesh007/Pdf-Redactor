#!/bin/bash
# Run PDF Redactor application

set -e

cd "$(dirname "$0")/.."

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "Python version: $PYTHON_VERSION"

if (( $(echo "$PYTHON_VERSION < 3.8" | bc -l) )); then
    echo "Error: Python 3.8+ required"
    exit 1
fi

# Install dependencies if needed
if ! python3 -c "import PyQt5" 2>/dev/null; then
    echo "Installing dependencies..."
    pip install -r requirements.txt
fi

# Run application
echo "Launching PDF Redactor..."
python3 src/main.py
