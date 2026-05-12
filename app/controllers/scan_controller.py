from PySide6.QtCore import QObject, Slot, Signal, Property, QThreadPool
from PySide6.QtWidgets import QFileDialog

from pathlib import Path

from app.services.scan_service import ScanService
from app.services.scan_worker import ScanWorker
from app.services.debug_service import DebugService
from app.database.image_repository import ImageRepository
from app.utils.logger import logger


class ImageViewModel:
    """Lightweight view-model transformation layer for QML-facing image data.
    
    Responsibilities:
    - Filesystem path to URI conversion (prevents QML file:/// hacks)
    - Formatting raw data for QML consumption
    """
    
    @staticmethod
    def from_raw(original_path: str, thumbnail_path: str, file_name: str) -> dict:
        return {
            "originalPath": Path(original_path).resolve().as_uri() if original_path else "",
            "thumbnailPath": Path(thumbnail_path).resolve().as_uri() if thumbnail_path else "",
            "fileName": file_name,
        }


class ScanController(QObject):
    """QObject bridge for folder selection and scan operations.
    
    Manages the scan lifecycle: folder selection → scan execution → progress reporting.
    All heavy work runs on QThreadPool via ScanWorker.
    """

    # ── Signals ───────────────────────────────────────────────────────
    currentFolderChanged = Signal()
    scanStateChanged = Signal()
    scanProgressChanged = Signal()
    scannedCountChanged = Signal()
    totalImagesChanged = Signal()
    hasScannedCurrentFolderChanged = Signal()
    scanStarted = Signal()
    imageReady = Signal(str, str, str)  # original_path, thumbnail_path, file_name
    scanFinished = Signal(int)          # total processed

    def __init__(self, scan_service: ScanService, image_repository: ImageRepository, debug_service: DebugService = None, parent=None):
        super().__init__(parent)
        self._scan_service = scan_service
        self._image_repository = image_repository
        self._debug_service = debug_service
        self._current_folder = ""
        self._scan_state = "empty"     # empty | scanning | loaded
        self._scan_progress = 0        # 0-100
        self._scanned_count = 0
        self._total_images = 0
        self._has_scanned_current_folder = False
        self._worker = None

    # ── Properties (exposed to QML) ───────────────────────────────────

    @Property(str, notify=currentFolderChanged)
    def currentFolder(self) -> str:
        return self._current_folder

    @Property(str, notify=scanStateChanged)
    def scanState(self) -> str:
        return self._scan_state

    @Property(int, notify=scanProgressChanged)
    def scanProgress(self) -> int:
        return self._scan_progress

    @Property(int, notify=scannedCountChanged)
    def scannedCount(self) -> int:
        return self._scanned_count

    @Property(int, notify=totalImagesChanged)
    def totalImages(self) -> int:
        return self._total_images

    @Property(bool, notify=hasScannedCurrentFolderChanged)
    def hasScannedCurrentFolder(self) -> bool:
        return self._has_scanned_current_folder

    # ── Slots (callable from QML) ─────────────────────────────────────

    @Slot()
    def selectFolder(self):
        """Open native folder picker and update currentFolder."""
        folder = QFileDialog.getExistingDirectory(
            None,
            "Select Image Folder",
            "",
        )
        if folder:
            if self._current_folder != folder:
                self._current_folder = folder
                self._has_scanned_current_folder = False
                self.hasScannedCurrentFolderChanged.emit()
            self.currentFolderChanged.emit()
            logger.info(f"Folder selected: {folder}")

    @Slot()
    def startScan(self):
        """Launch an async scan of the currently selected folder."""
        if not self._current_folder:
            logger.warning("No folder selected — cannot start scan.")
            return

        if self._scan_state == "scanning":
            logger.warning("Scan already in progress.")
            return

        # Reset progress state
        self._scan_state = "scanning"
        self._scan_progress = 0
        self._scanned_count = 0
        self._total_images = 0
        self.scanStateChanged.emit()
        self.scanProgressChanged.emit()
        self.scannedCountChanged.emit()
        self.totalImagesChanged.emit()
        self.scanStarted.emit()

        # Create worker and connect signals
        self._worker = ScanWorker(self._scan_service, self._current_folder)
        self._worker.signals.image_ready.connect(self._on_image_ready)
        self._worker.signals.progress.connect(self._on_progress)
        self._worker.signals.finished.connect(self._on_finished)
        self._worker.signals.error.connect(self._on_error)

        # Submit to thread pool
        QThreadPool.globalInstance().start(self._worker)
        logger.info(f"Scan started for '{self._current_folder}'")

    @Slot(result=int)
    def getStoredImageCount(self):
        """Return total images stored in database (for startup)."""
        return self._image_repository.get_image_count()

    @Slot(result=list)
    def getStoredImages(self):
        """Return all stored images as list of dicts (for startup loading)."""
        images = self._image_repository.get_all_images()
        result = []
        for img in images:
            if img.thumbnail_path:
                vm = ImageViewModel.from_raw(
                    original_path=img.original_path,
                    thumbnail_path=img.thumbnail_path,
                    file_name=img.file_name
                )
                result.append(vm)
        return result

    # ── Internal Signal Handlers ──────────────────────────────────────

    def _on_image_ready(self, original_path: str, thumbnail_path: str, file_name: str):
        """Relay image_ready from worker to QML via view-model transformation."""
        self._scanned_count += 1
        self.scannedCountChanged.emit()
        
        vm = ImageViewModel.from_raw(original_path, thumbnail_path, file_name)
        self.imageReady.emit(vm["originalPath"], vm["thumbnailPath"], vm["fileName"])

    def _on_progress(self, current: int, total: int):
        """Update progress properties."""
        self._total_images = total
        self._scan_progress = int((current / total) * 100) if total > 0 else 0
        self.totalImagesChanged.emit()
        self.scanProgressChanged.emit()

    def _on_finished(self, total_processed: int):
        """Handle scan completion."""
        self._scan_state = "loaded"
        self._scan_progress = 100
        self._has_scanned_current_folder = True
        self._worker = None
        if self._debug_service:
            self._debug_service.scan_completed()
        self.hasScannedCurrentFolderChanged.emit()
        self.scanStateChanged.emit()
        self.scanProgressChanged.emit()
        self.scanFinished.emit(total_processed)
        logger.info(f"Scan finished: {total_processed} images processed.")

    def _on_error(self, error_msg: str):
        """Handle scan failure."""
        self._scan_state = "loaded"  # Go to loaded state (may have partial results)
        self._worker = None
        if self._debug_service:
            self._debug_service.scan_completed()
        self.scanStateChanged.emit()
        logger.error(f"Scan error: {error_msg}")
