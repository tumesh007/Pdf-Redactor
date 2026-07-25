# PDF Redactor

![License](https://img.shields.io/badge/license-MIT-blue)
![Python](https://img.shields.io/badge/python-3.8+-blue)
![Status](https://img.shields.io/badge/status-Beta-yellow)

## Overview

**PDF Redactor** is a cross-platform desktop application for permanently redacting visible personal identifiers from PDF files before sharing them.

Securely remove employee IDs, timestamps, footer text, and other sensitive information from documents.

## Features

- 🔒 **Secure Redaction** - Permanently remove sensitive content
- 👀 **Live Preview** - See changes before saving
- 🖼️ **Batch Processing** - Redact multiple files at once
- 🎨 **Custom Patterns** - Define your own redaction rules
- 🖥️ **Cross-Platform** - Windows and Linux
- 📝 **Metadata Removal** - Strip document metadata
- ⚙️ **Configurable** - Customize redaction patterns

## Quick Start

### Requirements
- Python 3.8+
- 200 MB disk space
- 1 GB RAM

### Installation

#### Windows
```batch
REM Download and extract the repository
cd Pdf-Redactor
scripts\install.bat
```

#### Linux
```bash
# Download and extract the repository
cd Pdf-Redactor
sudo bash scripts/install.sh
```

#### Run Without Installation
```bash
# Linux
bash scripts/run.sh

# Windows
scripts\run.bat
```

## Usage

### Basic Workflow

1. **Launch** the application
   ```bash
   bash scripts/run.sh           # Linux
   # or
   scripts\run.bat               # Windows
   ```

2. **Select** PDF file(s) to redact
   - Single file or batch mode
   - Drag-and-drop supported

3. **Configure** redaction settings
   - Choose preset patterns
   - Or define custom patterns

4. **Preview** the redaction
   - See exactly what will be redacted
   - Adjust settings if needed

5. **Redact & Save**
   - Click "Redact" to process
   - Choose output location
   - File is saved permanently

### Redaction Patterns

#### Built-in Patterns
- `employee_id` - Redact employee numbers
- `timestamp` - Redact date/time stamps
- `footer` - Redact footer text
- `header` - Redact header text
- `email` - Redact email addresses
- `phone` - Redact phone numbers

#### Custom Patterns
Define your own using:
- Regular expressions
- Text matching
- Coordinate-based redaction

## Configuration

Edit `config/settings.ini` to customize:

```ini
[Redaction]
# Default redaction patterns
default_pattern=employee_id,timestamp,footer

# Preserve document formatting
preserve_formatting=true

# Output quality (high/medium/low)
output_quality=high

[Processing]
# Maximum files per batch
max_batch_files=10

# Maximum file size (MB)
max_file_size=100
```

## Building Executables

### Windows
```batch
scripts\build.bat
```
Output: `dist\PDFRedactor.exe`

### Linux
```bash
bash scripts/build.sh
```
Output: `dist/PDFRedactor`

## Project Structure

```
Pdf-Redactor/
├── src/                    # Source code
│   ├── main.py            # Entry point
│   ├── gui.py             # GUI components
│   ├── redactor.py        # Redaction engine
│   ├── detector.py        # Pattern detection
│   └── config.py          # Settings
├── config/                # Configuration files
├── scripts/               # Build/installation scripts
├── docs/                  # Documentation
├── requirements.txt       # Dependencies
└── README.md              # This file
```

## Dependencies

Core libraries:
- **PyQt5** - GUI framework
- **PyPDF2** - PDF manipulation
- **Pillow** - Image processing
- **reportlab** - PDF generation

See `requirements.txt` for complete list.

## Security Considerations

- ⚠️ Redaction is **permanent** - cannot be undone
- ✅ Metadata is removed from output
- ✅ Original file is not modified (new file created)
- ✅ Application runs locally - no cloud upload

## Troubleshooting

### Application won't start
```bash
# Verify Python installation
python3 --version

# Verify dependencies
pip list | grep PyQt5

# Reinstall if needed
pip install -r requirements.txt
```

### GUI appears but buttons don't respond
- Ensure you have write permissions in the output directory
- Try running with administrator/sudo privileges
- Check available disk space

### PDF redaction fails
- Verify PDF file is not corrupted
- Try with a different PDF
- Check file permissions
- Ensure sufficient disk space

### Performance issues
- Reduce batch size
- Process smaller PDFs first
- Close other applications
- Check available RAM

## Limitations

- Works on visible text and simple graphics only
- Scanned PDFs (image-based) may not fully redact text
- Password-protected PDFs require password input
- File size limit: 100 MB (configurable)

## Supported Platforms

| OS | Version | Status |
|----|---------|--------|
| Windows | 10, 11 | ✅ Supported |
| Ubuntu | 20.04+ | ✅ Supported |
| Debian | 11+ | ✅ Supported |
| macOS | 10.13+ | ⚠️ Limited support |

## License

MIT License - See LICENSE file for details

## Author

**Tumesh007** - [GitHub](https://github.com/tumesh007)

## Support & Issues

- 📖 [Documentation](docs/)
- 🐛 [Report Issues](https://github.com/tumesh007/Pdf-Redactor/issues)
- 💬 [GitHub Discussions](https://github.com/tumesh007/Pdf-Redactor/discussions)

## Roadmap

- [ ] macOS full support
- [ ] OCR for scanned PDFs
- [ ] Undo/redo functionality
- [ ] Advanced pattern engine
- [ ] Batch scheduling
- [ ] Command-line interface

---

**Current Version**: 1.0.0 (Beta)  
**Last Updated**: July 2026  
**Status**: Under Active Development
