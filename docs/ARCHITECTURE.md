# PDF Redactor Architecture

## Overview

PDF Redactor is a Python-based desktop application for secure PDF redaction.

## Module Structure

```
src/
├── main.py          # Entry point
├── gui.py           # PyQt5 GUI
├── redactor.py      # Core redaction engine
├── detector.py      # Pattern detection
├── utils.py         # Utilities
└── config.py        # Settings
```

## Processing Pipeline

1. User selects PDF file via GUI
2. File is loaded and analyzed
3. Patterns are detected
4. Preview is generated
5. User confirms redaction
6. PDF is processed
7. Output file is saved

## Redaction Methods

- Text-based redaction (solid boxes)
- Pattern matching
- Custom coordinate redaction
- Metadata removal

## Dependencies

- PyQt5 - GUI
- PyPDF2 - PDF manipulation
- Pillow - Image processing
- Python 3.8+
