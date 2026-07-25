# PDF Redactor

A cross-platform desktop application (Windows / Ubuntu) for permanently
redacting visible personal identifiers — employee IDs, timestamps,
footer text, etc. — from PDF files before sharing them.

**What it does:** places opaque, flattened rectangles over
user-selected regions and physically removes the underlying text/image
content in those regions, then saves a new PDF.

**What it deliberately does NOT do:**
- It does not attempt to reconstruct or infer hidden/covered content.
- It does not strip, bypass, or alter embedded security features,
  digital signatures, or encryption beyond what's required to open a
  file the user already has legitimate access to.
<img width="1366" height="736" alt="image" src="https://github.com/user-attachments/assets/7838c252-0cf5-4d39-9c60-a49264815a9f" />

---

## 1. Requirements

- Python 3.12+
- pip

## 2. Installation (from source)

Use the provided installer script — it checks your Python version,
creates a virtual environment, and installs dependencies:

**Ubuntu/Linux:**
```bash
chmod +x install.sh
./install.sh
```

**Windows (Command Prompt):** double-click `install.bat`, or run it:
```
install.bat
```

**Windows (PowerShell):**
```powershell
.\install.ps1
```
If PowerShell blocks the script (execution policy), either right-click
`install.ps1` → *Run with PowerShell*, or run:
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```
`install.ps1` does everything `install.bat` does, plus: if no Python
3.12+ is found on PATH at all, it will try to install it automatically
via `winget` (Windows Package Manager) before continuing, and it
verifies at the end that PySide6/PyMuPDF/Pillow/pytest all actually
import correctly in the new environment. Pass `-SkipPythonAutoInstall`
if you'd rather install Python yourself and just have the script set
up the venv and dependencies.

If auto-detection can't find a Python install you know you have
(common cause: `python`/`python3` on PATH resolve to the Microsoft
Store's "App execution alias" placeholder instead of a real install —
the script detects and reports this specifically), point the script
straight at your `python.exe` and skip detection entirely:
```powershell
.\install.ps1 -PythonPath "C:\Users\you\AppData\Local\Programs\Python\Python312\python.exe"
```

Or manually:
```bash
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

> **Ubuntu system dependency**: PySide6's Qt6 backend needs
> `libxcb-cursor0` (and, for TIFF image support, `libtiff6` or
> `libtiff5` depending on your release) to display a window. If the
> app fails to launch with an `xcb` platform plugin error:
> ```bash
> sudo apt install libxcb-cursor0
> ```

## 3. Running

```bash
python main.py
```

## 4. Running the tests

The core PDF/profile/batch logic (everything under `core/`) is
covered by unit tests that don't require a display or PySide6 to be
importable at test-collection time:

```bash
pytest tests/ -v
```

36 tests total: 27 for rectangle redaction/profiles/batching plus 9 for
the watermark remover, including end-to-end checks that redacted/
cleaned text is genuinely removed from the saved PDF (not just
covered) and that unrelated real content stays byte-for-byte
identical.

GUI code (`gui/`) is intentionally kept thin and free of business
logic so it doesn't need its own test suite with a virtual display —
all coordinate math, redaction, batching, and profile logic lives in
`core/` and is fully unit-tested there.

## 5. Usage walkthrough

There are now **two separate tools** in the app, for two different jobs:

| Tool | Use it for | How it works |
|---|---|---|
| **Run Batch Redaction** | Permanently blacking out a fixed region (an ID box, a footer line, a signature block) | Draws an opaque rectangle over the area and deletes everything under it |
| **Remove Text Watermark…** | Portal/download "stamp" watermarks - a translucent user-ID + date/time overlay repeated on every page | Surgically deletes the watermark's own drawing instructions from the PDF; never touches real content |

**Use the right tool for the watermark type.** A diagonal download-stamp
watermark is drawn *on top of* body text that shares the same page
coordinates - a rectangle big enough to cover it will also blank out
real paragraphs underneath, which is what "black boxes eating my
document" means. Watermark removal instead deletes only the
watermark's paint instruction at the PDF-structure level, so the real
text is untouched byte-for-byte. See `core/watermark_remover.py` for
the full explanation and both detection strategies it uses.

### Rectangle redaction

1. **Add files** — drag & drop PDFs/folders onto the window, or use
   *File → Add Files…* (`Ctrl+O`) / the "Add Folder…" button.
2. **Select a page** in the queue to preview it.
3. **Draw rectangles** directly on the preview over the areas to
   redact. Drag the bottom-right corner to resize, drag the body to
   move, select + `Delete` to remove one, or "Clear All Rectangles."
4. **Configure a profile** via "Manage Profiles…": page selection
   (all/first/last/odd/even/range/custom), fill color, opacity,
   margin. Save it by name for reuse (e.g. "Portal A").
5. **Choose an output folder** and rename mode (suffix / overwrite /
   custom suffix) via Preferences.
6. **Run Batch Redaction** (`Ctrl+S` or the button) — runs on a
   background thread with a live progress bar; folder structure is
   preserved under the output root.

### Text watermark removal

1. **Add files** (same as above).
2. Click **"Remove Text Watermark…"**.
3. Enter the text that identifies the watermark — e.g. the portal's
   name, like `SAKSHAM` for a PNB SAKSHAM-stamped document. Leave it
   blank to match purely on the built-in date/time-stamp pattern
   (`DD-MM-YYYY HH:MM`).
4. The tool reports, per file, how many pages were cleaned and lists
   any pages where it found no match (those are left completely
   unchanged, never guessed at).

You can pass a custom `WatermarkSignature` (literal substrings and/or
regex patterns) directly if you're scripting against `core/` rather
than using the GUI — see the docstring in `core/watermark_remover.py`.

### Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+O` | Add files |
| `Ctrl+S` | Run batch redaction |
| `Ctrl+Shift+S` | Save profile as |
| `Delete` | Delete selected rectangle |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo rectangle edits |
| `Ctrl+MouseWheel` | Zoom in/out |
| `Space` + drag | Pan the preview |

## 6. Profiles

Profiles are plain JSON files stored under `~/.pdf_redactor/profiles/`.
Rectangle coordinates are stored **normalized** (0.0–1.0 fractions of
page width/height), so one profile applies correctly across documents
and page sizes. See `resources/profiles/Portal A.json` for a sample:

```json
{
  "name": "Portal A",
  "regions": [
    {"x": 0.05, "y": 0.92, "width": 0.35, "height": 0.05},
    {"x": 0.70, "y": 0.02, "width": 0.25, "height": 0.04}
  ],
  "page_selection": "all",
  "page_spec": "",
  "color": [0.0, 0.0, 0.0],
  "opacity": 1.0,
  "margin": 0.005,
  "schema_version": 1
}
```

## 7. Error handling

The redaction engine (`core/redactor.py`) distinguishes and reports:

- **Encrypted PDFs** — prompts are wired for a password; if
  authentication fails, the file is skipped with a clear error and the
  batch continues.
- **Corrupted / unsupported PDFs** — caught via PyMuPDF's
  `FileDataError` and reported per-file without crashing the batch.
- **Permission errors** — caught per-file (e.g. read-only output
  location).
- **Invalid page specs** — validated before processing starts.

Every outcome — success or failure — is captured in a `RedactionResult`
and logged to `~/.pdf_redactor/logs/pdf_redactor.log` (rotating, 5 MB
× 5 backups).

## 8. Building standalone executables (PyInstaller)

Use the provided build scripts (they activate the venv from step 2
and run PyInstaller for you):

```bash
./build.sh          # Ubuntu/Linux
build.bat           # Windows
```

Both scripts were tested end-to-end in development: the Linux build
produces a working `dist/PDFRedactor` binary that launches, initializes
logging/config, and reaches "Ready" in the status bar.

Or manually, from the project root with the venv active:

**Windows:**
```bash
pyinstaller --noconfirm --onefile --windowed ^
  --name "PDFRedactor" ^
  --add-data "resources;resources" ^
  main.py
```

**Ubuntu/Linux:**
```bash
pyinstaller --noconfirm --onefile --windowed \
  --name "PDFRedactor" \
  --add-data "resources:resources" \
  main.py
```

The executable is written to `dist/PDFRedactor` (or `dist/PDFRedactor.exe`
on Windows). Distribute that single file — Python/PySide6/PyMuPDF are
bundled in.

> **Note:** build on the target OS (build Windows `.exe` on Windows,
> build the Linux binary on Ubuntu) — PyInstaller does not cross-compile.

## 9. Project structure

```
pdf_redactor/
├── main.py                    # Entry point
├── install.sh / install.bat / install.ps1   # Installers (Linux / Windows CMD / Windows PowerShell)
├── build.sh / build.bat                     # PyInstaller packaging scripts
├── gui/
│   ├── mainwindow.py           # Main window, menus, shortcuts, batch threading
│   ├── preview.py              # Page rendering, rectangle draw/edit, zoom/pan, undo/redo
│   └── dialogs.py              # Preferences, profile management dialogs
├── core/
│   ├── pdf_processor.py        # File discovery, batching, output paths, preview rendering
│   ├── profile_manager.py      # RedactionRegion / RedactionProfile models + JSON persistence
│   ├── redactor.py             # Page-selection resolution + the actual PyMuPDF redaction engine
│   └── watermark_remover.py    # Surgical text-watermark removal (separate-stream + inline-block strategies)
├── utils/
│   ├── config.py                # AppConfig (preferences) load/save
│   └── logger.py                # Rotating file + console logging setup
├── resources/
│   ├── icons/
│   ├── themes/
│   └── profiles/
│       └── Portal A.json        # Sample profile
├── tests/
│   ├── test_core.py             # 27 unit tests for rectangle redaction (no GUI dependency)
│   └── test_watermark_remover.py  # 9 unit tests for watermark removal (no GUI dependency)
├── requirements.txt
└── README.md
```

## 10. Known limitations / honest notes

- **Split before/after preview** (item 9 in the spec) is architected
  for (the `PreviewScene`/`PreviewView` split cleanly from redaction
  logic so a second synchronized view is a small addition) but the
  dual-pane wiring itself is not included in this pass — flag it if
  you want it built out next.
- Page thumbnails beyond page 1 in the live preview panel currently
  require clicking through pages programmatically; a page-navigation
  spinner is a natural next addition.
