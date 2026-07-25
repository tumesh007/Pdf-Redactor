#!/bin/bash
# Install PDF Redactor on Linux systems

set -e

echo "Installing PDF Redactor..."

cd "$(dirname "$0")/.."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo for system-wide installation"
    exit 1
fi

# Install Python dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Create application directory
INSTALL_DIR="/opt/pdfredactor"
mkdir -p $INSTALL_DIR

# Copy files
echo "Installing application files..."
cp -r src/ $INSTALL_DIR/
cp -r config/ $INSTALL_DIR/

# Create executable wrapper
echo "Creating executable..."
cat > /usr/local/bin/pdfredactor << 'EOF'
#!/bin/bash
cd /opt/pdfredactor
python3 src/main.py "$@"
EOF
chmod +x /usr/local/bin/pdfredactor

echo "Installation complete!"
echo "Run with: pdfredactor"
