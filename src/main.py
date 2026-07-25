#!/usr/bin/env python3
"""Main entry point for PDF Redactor application."""

if __name__ == "__main__":
    from gui import PDFRedactorGUI
    import sys
    
    app = PDFRedactorGUI()
    app.run()
