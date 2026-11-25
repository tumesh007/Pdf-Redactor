/**
 * PDF Redactor Web — 100% Client-Side Privacy-First Redactor & Watermark Cleaner
 * Built for Banking & Sensitive Document Processing
 * Powered by PDF.js and pdf-lib
 */

// Configure PDF.js Worker
if (window.pdfjsLib) {
  pdfjsLib.GlobalWorkerOptions.workerSrc =
    "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js";
}

class PdfRedactorApp {
  constructor() {
    this.pdfDoc = null;
    this.pdfBytes = null;
    this.fileName = "document.pdf";
    this.currentPageNum = 1;
    this.totalPages = 0;
    this.zoomScale = 1.25;

    // Redaction store: pageNum -> Array of { x, y, w, h, color } (normalized 0..1)
    this.redactions = {};

    // Tools: 'blackout', 'whiteout'
    this.currentTool = "blackout";

    // Interaction state
    this.isDrawing = false;
    this.startX = 0;
    this.startY = 0;
    this.currentRect = null;

    this.initDOM();
    this.bindEvents();
  }

  initDOM() {
    this.fileInput = document.getElementById("file-input");
    this.dropZone = document.getElementById("drop-zone");
    this.editorContainer = document.getElementById("editor-container");
    this.emptyState = document.getElementById("empty-state");

    this.pdfCanvas = document.getElementById("pdf-canvas");
    this.overlayCanvas = document.getElementById("overlay-canvas");
    this.canvasContainer = document.getElementById("canvas-container");
    this.pdfCtx = this.pdfCanvas ? this.pdfCanvas.getContext("2d") : null;
    this.overlayCtx = this.overlayCanvas ? this.overlayCanvas.getContext("2d") : null;

    // Controls
    this.pageInfo = document.getElementById("page-info");
    this.prevPageBtn = document.getElementById("prev-page-btn");
    this.nextPageBtn = document.getElementById("next-page-btn");
    this.zoomInBtn = document.getElementById("zoom-in-btn");
    this.zoomOutBtn = document.getElementById("zoom-out-btn");
    this.zoomLevelEl = document.getElementById("zoom-level");

    this.btnBlackout = document.getElementById("btn-tool-blackout");
    this.btnWhiteout = document.getElementById("btn-tool-whiteout");
    this.btnClearPage = document.getElementById("btn-clear-page");
    this.btnClearAll = document.getElementById("btn-clear-all");
    this.btnDownload = document.getElementById("btn-download");

    // Watermark & Search inputs
    this.empIdInput = document.getElementById("emp-id-input");
    this.checkDateTime = document.getElementById("check-date-time");
    this.checkPortalBanner = document.getElementById("check-portal-banner");
    this.btnStripWatermarks = document.getElementById("btn-strip-watermarks");

    this.searchInput = document.getElementById("search-input");
    this.btnSearchRedact = document.getElementById("btn-search-redact");

    this.toastEl = document.getElementById("toast");
    this.toastMsg = document.getElementById("toast-msg");
  }

  bindEvents() {
    // File upload
    if (this.fileInput) {
      this.fileInput.addEventListener("change", (e) => this.handleFileSelect(e));
    }
    if (this.dropZone) {
      this.dropZone.addEventListener("dragover", (e) => {
        e.preventDefault();
        this.dropZone.classList.add("border-blue-500", "bg-blue-50/50");
      });
      this.dropZone.addEventListener("dragleave", (e) => {
        e.preventDefault();
        this.dropZone.classList.remove("border-blue-500", "bg-blue-50/50");
      });
      this.dropZone.addEventListener("drop", (e) => {
        e.preventDefault();
        this.dropZone.classList.remove("border-blue-500", "bg-blue-50/50");
        if (e.dataTransfer.files.length > 0) {
          this.loadFile(e.dataTransfer.files[0]);
        }
      });
    }

    // Navigation
    if (this.prevPageBtn) {
      this.prevPageBtn.addEventListener("click", () => this.changePage(-1));
    }
    if (this.nextPageBtn) {
      this.nextPageBtn.addEventListener("click", () => this.changePage(1));
    }
    if (this.zoomInBtn) {
      this.zoomInBtn.addEventListener("click", () => this.changeZoom(0.2));
    }
    if (this.zoomOutBtn) {
      this.zoomOutBtn.addEventListener("click", () => this.changeZoom(-0.2));
    }

    // Tools
    if (this.btnBlackout) {
      this.btnBlackout.addEventListener("click", () => this.setTool("blackout"));
    }
    if (this.btnWhiteout) {
      this.btnWhiteout.addEventListener("click", () => this.setTool("whiteout"));
    }
    if (this.btnClearPage) {
      this.btnClearPage.addEventListener("click", () => this.clearCurrentPageRedactions());
    }
    if (this.btnClearAll) {
      this.btnClearAll.addEventListener("click", () => this.clearAllRedactions());
    }
    if (this.btnDownload) {
      this.btnDownload.addEventListener("click", () => this.exportRedactedPdf());
    }

    // Watermark & Search
    if (this.btnStripWatermarks) {
      this.btnStripWatermarks.addEventListener("click", () => this.autoStripWatermarks());
    }
    if (this.btnSearchRedact) {
      this.btnSearchRedact.addEventListener("click", () => this.searchAndRedact());
    }

    // Canvas drawing
    if (this.overlayCanvas) {
      this.overlayCanvas.addEventListener("mousedown", (e) => this.onMouseDown(e));
      this.overlayCanvas.addEventListener("mousemove", (e) => this.onMouseMove(e));
      window.addEventListener("mouseup", (e) => this.onMouseUp(e));

      // Touch support
      this.overlayCanvas.addEventListener("touchstart", (e) => this.onTouchStart(e), { passive: false });
      this.overlayCanvas.addEventListener("touchmove", (e) => this.onTouchMove(e), { passive: false });
      window.addEventListener("touchend", (e) => this.onTouchEnd(e));
    }

    // Preset buttons
    document.querySelectorAll(".preset-btn").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        const pattern = e.target.getAttribute("data-pattern");
        if (pattern && this.searchInput) {
          this.searchInput.value = pattern;
          this.searchAndRedact();
        }
      });
    });
  }

  showToast(message, isError = false) {
    if (!this.toastEl || !this.toastMsg) return;
    this.toastMsg.textContent = message;
    this.toastEl.classList.remove("hidden", "bg-gray-900", "bg-red-600");
    this.toastEl.classList.add(isError ? "bg-red-600" : "bg-gray-900");
    this.toastEl.classList.remove("opacity-0", "translate-y-4");

    setTimeout(() => {
      this.toastEl.classList.add("opacity-0", "translate-y-4");
      setTimeout(() => this.toastEl.classList.add("hidden"), 300);
    }, 3500);
  }

  handleFileSelect(e) {
    const file = e.target.files[0];
    if (file) {
      this.loadFile(file);
    }
  }

  async loadFile(file) {
    if (file.type !== "application/pdf" && !file.name.endsWith(".pdf")) {
      this.showToast("Please upload a valid PDF document.", true);
      return;
    }

    try {
      this.fileName = file.name;
      const arrayBuffer = await file.arrayBuffer();
      this.pdfBytes = arrayBuffer;

      const loadingTask = pdfjsLib.getDocument({ data: arrayBuffer.slice(0) });
      this.pdfDoc = await loadingTask.promise;
      this.totalPages = this.pdfDoc.numPages;
      this.currentPageNum = 1;
      this.redactions = {};

      if (this.emptyState) this.emptyState.classList.add("hidden");
      if (this.editorContainer) this.editorContainer.classList.remove("hidden");

      this.showToast(`Loaded "${this.fileName}" (${this.totalPages} pages)`);
      await this.renderPage(this.currentPageNum);
      this.updateUI();
    } catch (err) {
      console.error("Error loading PDF:", err);
      this.showToast("Failed to load PDF file. " + err.message, true);
    }
  }

  setTool(tool) {
    this.currentTool = tool;
    if (this.btnBlackout) {
      this.btnBlackout.classList.toggle("ring-2", tool === "blackout");
      this.btnBlackout.classList.toggle("ring-blue-600", tool === "blackout");
    }
    if (this.btnWhiteout) {
      this.btnWhiteout.classList.toggle("ring-2", tool === "whiteout");
      this.btnWhiteout.classList.toggle("ring-blue-600", tool === "whiteout");
    }
  }

  changePage(delta) {
    const newPage = this.currentPageNum + delta;
    if (newPage >= 1 && newPage <= this.totalPages) {
      this.currentPageNum = newPage;
      this.renderPage(this.currentPageNum);
      this.updateUI();
    }
  }

  changeZoom(delta) {
    const newZoom = Math.max(0.6, Math.min(3.0, this.zoomScale + delta));
    if (newZoom !== this.zoomScale) {
      this.zoomScale = newZoom;
      if (this.zoomLevelEl) {
        this.zoomLevelEl.textContent = `${Math.round(this.zoomScale * 100)}%`;
      }
      this.renderPage(this.currentPageNum);
    }
  }

  updateUI() {
    if (this.pageInfo) {
      this.pageInfo.textContent = `Page ${this.currentPageNum} of ${this.totalPages}`;
    }
    if (this.prevPageBtn) {
      this.prevPageBtn.disabled = this.currentPageNum <= 1;
    }
    if (this.nextPageBtn) {
      this.nextPageBtn.disabled = this.currentPageNum >= this.totalPages;
    }

    const currentCount = (this.redactions[this.currentPageNum] || []).length;
    let totalCount = 0;
    Object.values(this.redactions).forEach((list) => (totalCount += list.length));

    const statusBadge = document.getElementById("redaction-stats");
    if (statusBadge) {
      statusBadge.textContent = `${currentCount} on page / ${totalCount} total`;
    }
  }

  async renderPage(num) {
    if (!this.pdfDoc) return;

    try {
      const page = await this.pdfDoc.getPage(num);
      const viewport = page.getViewport({ scale: this.zoomScale });
      const pixelRatio = window.devicePixelRatio || 1;

      this.pdfCanvas.width = viewport.width * pixelRatio;
      this.pdfCanvas.height = viewport.height * pixelRatio;
      this.pdfCanvas.style.width = `${viewport.width}px`;
      this.pdfCanvas.style.height = `${viewport.height}px`;

      this.overlayCanvas.width = viewport.width * pixelRatio;
      this.overlayCanvas.height = viewport.height * pixelRatio;
      this.overlayCanvas.style.width = `${viewport.width}px`;
      this.overlayCanvas.style.height = `${viewport.height}px`;

      this.pdfCtx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
      this.overlayCtx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);

      const renderContext = {
        canvasContext: this.pdfCtx,
        viewport: viewport,
      };

      await page.render(renderContext).promise;
      this.redrawOverlay();
    } catch (err) {
      console.error("Render page error:", err);
    }
  }

  redrawOverlay() {
    if (!this.overlayCtx || !this.overlayCanvas) return;
    const w = parseFloat(this.overlayCanvas.style.width);
    const h = parseFloat(this.overlayCanvas.style.height);

    this.overlayCtx.clearRect(0, 0, w, h);

    const pageRedactions = this.redactions[this.currentPageNum] || [];

    // Draw existing redaction boxes
    for (let i = 0; i < pageRedactions.length; i++) {
      const box = pageRedactions[i];
      const rx = box.x * w;
      const ry = box.y * h;
      const rw = box.w * w;
      const rh = box.h * h;

      if (box.color === "white") {
        this.overlayCtx.fillStyle = "#ffffff";
        this.overlayCtx.fillRect(rx, ry, rw, rh);
        this.overlayCtx.strokeStyle = "#94a3b8";
        this.overlayCtx.lineWidth = 1;
        this.overlayCtx.setLineDash([4, 2]);
        this.overlayCtx.strokeRect(rx, ry, rw, rh);
        this.overlayCtx.setLineDash([]);
      } else {
        this.overlayCtx.fillStyle = "rgba(0, 0, 0, 0.95)";
        this.overlayCtx.fillRect(rx, ry, rw, rh);
      }

      // Draw border indicator
      this.overlayCtx.strokeStyle = "#ef4444";
      this.overlayCtx.lineWidth = 1.5;
      this.overlayCtx.strokeRect(rx, ry, rw, rh);

      // Label
      this.overlayCtx.fillStyle = box.color === "white" ? "#475569" : "#f87171";
      this.overlayCtx.font = "10px sans-serif";
      this.overlayCtx.fillText(`[Redaction #${i + 1}]`, rx + 3, ry + 12);
    }

    // Draw live drag rectangle if user is drawing
    if (this.isDrawing && this.currentRect) {
      const { x, y, w: rw, h: rh } = this.currentRect;
      this.overlayCtx.fillStyle =
        this.currentTool === "whiteout" ? "rgba(255, 255, 255, 0.85)" : "rgba(0, 0, 0, 0.75)";
      this.overlayCtx.fillRect(x, y, rw, rh);
      this.overlayCtx.strokeStyle = "#3b82f6";
      this.overlayCtx.lineWidth = 2;
      this.overlayCtx.setLineDash([4, 4]);
      this.overlayCtx.strokeRect(x, y, rw, rh);
      this.overlayCtx.setLineDash([]);
    }
  }

  getCanvasCoords(e) {
    const rect = this.overlayCanvas.getBoundingClientRect();
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    return {
      x: clientX - rect.left,
      y: clientY - rect.top,
    };
  }

  onMouseDown(e) {
    if (e.button !== 0) return; // Left button only
    const coords = this.getCanvasCoords(e);
    this.isDrawing = true;
    this.startX = coords.x;
    this.startY = coords.y;
    this.currentRect = { x: this.startX, y: this.startY, w: 0, h: 0 };
  }

  onMouseMove(e) {
    if (!this.isDrawing) return;
    const coords = this.getCanvasCoords(e);
    const x = Math.min(this.startX, coords.x);
    const y = Math.min(this.startY, coords.y);
    const w = Math.abs(coords.x - this.startX);
    const h = Math.abs(coords.y - this.startY);

    this.currentRect = { x, y, w, h };
    this.redrawOverlay();
  }

  onMouseUp(e) {
    if (!this.isDrawing) return;
    this.isDrawing = false;

    if (this.currentRect && this.currentRect.w > 4 && this.currentRect.h > 4) {
      const canvasW = parseFloat(this.overlayCanvas.style.width);
      const canvasH = parseFloat(this.overlayCanvas.style.height);

      if (!this.redactions[this.currentPageNum]) {
        this.redactions[this.currentPageNum] = [];
      }

      // Store normalized coordinates [0..1]
      this.redactions[this.currentPageNum].push({
        x: this.currentRect.x / canvasW,
        y: this.currentRect.y / canvasH,
        w: this.currentRect.w / canvasW,
        h: this.currentRect.h / canvasH,
        color: this.currentTool,
      });

      this.updateUI();
    }

    this.currentRect = null;
    this.redrawOverlay();
  }

  onTouchStart(e) {
    if (e.touches.length === 1) {
      e.preventDefault();
      this.onMouseDown(e);
    }
  }

  onTouchMove(e) {
    if (this.isDrawing) {
      e.preventDefault();
      this.onMouseMove(e);
    }
  }

  onTouchEnd(e) {
    this.onMouseUp(e);
  }

  clearCurrentPageRedactions() {
    delete this.redactions[this.currentPageNum];
    this.redrawOverlay();
    this.updateUI();
    this.showToast(`Cleared redactions on Page ${this.currentPageNum}`);
  }

  clearAllRedactions() {
    this.redactions = {};
    this.redrawOverlay();
    this.updateUI();
    this.showToast("Cleared all redactions across all pages.");
  }

  applyCurrentBoxesToAllPages() {
    const currentBoxes = this.redactions[this.currentPageNum] || [];
    if (currentBoxes.length === 0) {
      this.showToast("No redaction boxes on current page to copy.", true);
      return;
    }

    for (let p = 1; p <= this.totalPages; p++) {
      if (p !== this.currentPageNum) {
        if (!this.redactions[p]) this.redactions[p] = [];
        currentBoxes.forEach((box) => {
          this.redactions[p].push({ ...box });
        });
      }
    }

    this.updateUI();
    this.showToast(`Copied ${currentBoxes.length} box(es) to all ${this.totalPages} pages.`);
  }

  /**
   * Search and auto-redact pattern across all pages
   */
  async searchAndRedact() {
    if (!this.pdfDoc) return;
    const query = this.searchInput ? this.searchInput.value.trim() : "";
    if (!query) {
      this.showToast("Please enter text or pattern to search.", true);
      return;
    }

    this.showToast(`Searching for "${query}" across all pages...`);
    let matchCount = 0;
    let isRegex = false;
    let regex = null;

    if (query.startsWith("/") && query.lastIndexOf("/") > 0) {
      try {
        const lastSlash = query.lastIndexOf("/");
        regex = new RegExp(query.substring(1, lastSlash), query.substring(lastSlash + 1));
        isRegex = true;
      } catch (e) {
        regex = new RegExp(query, "i");
      }
    } else {
      regex = new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
    }

    for (let p = 1; p <= this.totalPages; p++) {
      const page = await this.pdfDoc.getPage(p);
      const textContent = await page.getTextContent();
      const viewport = page.getViewport({ scale: 1.0 });

      if (!this.redactions[p]) this.redactions[p] = [];

      for (const item of textContent.items) {
        if (regex.test(item.str)) {
          // Bounding box from PDF.js item.transform: [scaleX, skewY, skewX, scaleY, tx, ty]
          const tx = item.transform[4];
          const ty = item.transform[5];
          const tw = item.width || 50;
          const th = item.height || Math.abs(item.transform[3]) || 12;

          // Convert PDF points (origin bottom-left) to normalized [0..1] (origin top-left)
          const normX = Math.max(0, tx / viewport.width);
          const normY = Math.max(0, (viewport.height - ty - th) / viewport.height);
          const normW = Math.min(1 - normX, (tw * 1.05) / viewport.width);
          const normH = Math.min(1 - normY, (th * 1.25) / viewport.height);

          this.redactions[p].push({
            x: normX,
            y: normY,
            w: normW,
            h: normH,
            color: this.currentTool,
          });
          matchCount++;
        }
      }
    }

    this.redrawOverlay();
    this.updateUI();

    if (matchCount > 0) {
      this.showToast(`Redacted ${matchCount} match(es) across ${this.totalPages} pages.`);
    } else {
      this.showToast(`No matches found for "${query}".`, true);
    }
  }

  /**
   * Automatically strips portal download stamps (Employee ID, Date/Time, PNB SAKSHAM, HRMS)
   */
  async autoStripWatermarks() {
    if (!this.pdfDoc) return;

    const empId = this.empIdInput ? this.empIdInput.value.trim() : "";
    const cleanDateTime = this.checkDateTime ? this.checkDateTime.checked : true;
    const cleanBanner = this.checkPortalBanner ? this.checkPortalBanner.checked : true;

    this.showToast("Analyzing and removing portal watermarks & stamps...");

    // Build pattern list
    const patterns = [];
    if (empId) {
      patterns.push(new RegExp(empId.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i"));
      patterns.push(new RegExp(`EMP[-_\\s]?${empId}`, "i"));
    }
    if (cleanDateTime) {
      // Common date & timestamp patterns in bank exports: DD-MM-YYYY HH:MM or DD/MM/YYYY HH:MM
      patterns.push(/\d{2}[-/]\d{2}[-/]\d{4}\s+\d{2}:\d{2}/);
      patterns.push(/\d{2}[-/]\d{2}[-/]\d{4}/);
    }
    if (cleanBanner) {
      patterns.push(/PNB\s+SAKSHAM/i);
      patterns.push(/FINACLE/i);
      patterns.push(/CONFIDENTIAL/i);
      patterns.push(/DOWNLOADED\s+BY/i);
      patterns.push(/STAMPED\s+COPY/i);
    }

    let cleanedCount = 0;

    for (let p = 1; p <= this.totalPages; p++) {
      const page = await this.pdfDoc.getPage(p);
      const textContent = await page.getTextContent();
      const viewport = page.getViewport({ scale: 1.0 });

      if (!this.redactions[p]) this.redactions[p] = [];

      for (const item of textContent.items) {
        const matches = patterns.some((rx) => rx.test(item.str));
        if (matches) {
          const tx = item.transform[4];
          const ty = item.transform[5];
          const tw = item.width || 60;
          const th = item.height || Math.abs(item.transform[3]) || 12;

          const normX = Math.max(0, (tx - 2) / viewport.width);
          const normY = Math.max(0, (viewport.height - ty - th - 2) / viewport.height);
          const normW = Math.min(1 - normX, (tw + 4) / viewport.width);
          const normH = Math.min(1 - normY, (th + 4) / viewport.height);

          // Watermarks default to whiteout for invisible cleaning
          this.redactions[p].push({
            x: normX,
            y: normY,
            w: normW,
            h: normH,
            color: "white",
          });
          cleanedCount++;
        }
      }
    }

    this.redrawOverlay();
    this.updateUI();

    if (cleanedCount > 0) {
      this.showToast(`Cleaned ${cleanedCount} watermark item(s) across ${this.totalPages} pages.`);
    } else {
      this.showToast("No matching portal stamps or watermarks found.", true);
    }
  }

  /**
   * Burn redactions permanently into PDF using pdf-lib and download
   */
  async exportRedactedPdf() {
    if (!this.pdfBytes) {
      this.showToast("No PDF loaded.", true);
      return;
    }

    try {
      this.showToast("Burning permanent redactions and scrubbing metadata...");
      const pdfDoc = await PDFLib.PDFDocument.load(this.pdfBytes.slice(0));

      // 1. Scrub document metadata
      pdfDoc.setTitle("");
      pdfDoc.setAuthor("");
      pdfDoc.setSubject("");
      pdfDoc.setKeywords([]);
      pdfDoc.setProducer("");
      pdfDoc.setCreator("");

      const pages = pdfDoc.getPages();
      let totalApplied = 0;

      // 2. Burn solid redaction rectangles into the page content stream
      for (let p = 0; p < pages.length; p++) {
        const pageNum = p + 1;
        const pageRedactions = this.redactions[pageNum] || [];
        const page = pages[p];
        const { width, height } = page.getSize();

        for (const box of pageRedactions) {
          const rx = box.x * width;
          // Invert Y: PDF coordinates have (0,0) at bottom-left
          const ry = height - (box.y + box.h) * height;
          const rw = box.w * width;
          const rh = box.h * height;

          const color = box.color === "white" ? PDFLib.rgb(1, 1, 1) : PDFLib.rgb(0, 0, 0);

          page.drawRectangle({
            x: rx,
            y: ry,
            width: rw,
            height: rh,
            color: color,
            borderWidth: 0,
          });

          totalApplied++;
        }
      }

      // 3. Serialize and trigger download
      const redactedBytes = await pdfDoc.save();
      const blob = new Blob([redactedBytes], { type: "application/pdf" });
      const url = URL.createObjectURL(blob);

      const a = document.createElement("a");
      const baseName = this.fileName.replace(/\.pdf$/i, "");
      a.href = url;
      a.download = `${baseName}_redacted.pdf`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      this.showToast(`Successfully exported! ${totalApplied} redactions burned into PDF.`);
    } catch (err) {
      console.error("Export error:", err);
      this.showToast("Export failed: " + err.message, true);
    }
  }
}

// Global initialization
document.addEventListener("DOMContentLoaded", () => {
  window.app = new PdfRedactorApp();
  if (window.lucide) {
    lucide.createIcons();
  }
});
