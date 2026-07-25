"""
main.py

Application entry point for PDF Redactor.

Usage:
    python main.py

Responsibilities kept intentionally thin: configure logging, load
persisted preferences, construct the Qt application and main window,
and hand off control to the Qt event loop. All real logic lives in
core/ (PDF processing) and gui/ (presentation).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtWidgets import QApplication

from gui.mainwindow import MainWindow
from utils.config import AppConfig, DEFAULT_CONFIG_FILE
from utils.logger import configure_logging, get_logger

PROFILES_DIR = Path.home() / ".pdf_redactor" / "profiles"


def main() -> int:
    configure_logging()
    logger = get_logger(__name__)
    logger.info("Starting PDF Redactor")

    app = QApplication(sys.argv)
    app.setApplicationName("PDF Redactor")
    app.setOrganizationName("PDFRedactor")

    config = AppConfig.load(DEFAULT_CONFIG_FILE)

    window = MainWindow(config, PROFILES_DIR)
    window.show()

    exit_code = app.exec()
    logger.info("PDF Redactor exiting with code %d", exit_code)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
