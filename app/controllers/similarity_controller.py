from PySide6.QtCore import QObject, Slot, Signal, Property, QThreadPool
from typing import Optional

from app.services.similarity_worker import SimilarityWorker
from app.services.hash_service import HashService
from app.services.similarity_service import SimilarityService
from app.services.grouping_service import GroupingService
from app.database.group_repository import GroupRepository
from app.controllers.scan_controller import ImageViewModel
from app.services.debug_service import DebugService
from app.utils.logger import logger

class SimilarityController(QObject):
    """QObject bridge for similarity operations and group review UI."""

    similarityStateChanged = Signal()
    currentPhaseChanged = Signal()
    progressChanged = Signal()
    groupCountChanged = Signal()
    currentGroupIndexChanged = Signal()
    currentGroupDataChanged = Signal()
    reviewCompleteChanged = Signal()

    def __init__(self, 
                 hash_service: HashService, 
                 similarity_service: SimilarityService, 
                 grouping_service: GroupingService,
                 group_repository: GroupRepository,
                 debug_service: DebugService = None,
                 settings_controller = None,
                 parent=None):
        super().__init__(parent)
        self._hash_service = hash_service
        self._similarity_service = similarity_service
        self._grouping_service = grouping_service
        self._group_repository = group_repository
        self._settings_controller = settings_controller
        self._debug_service = debug_service
        
        self._similarity_state = "idle"  # idle | processing | ready
        self._current_phase = ""         # hashing | comparing | grouping
        self._progress = 0
        self._group_count = 0
        self._current_group_index = 0
        self._groups_cache = []          # Loaded groups for review
        self._review_complete = False
        self._worker = None

    # ── Properties ────────────────────────────────────────────────────

    @Property(bool, notify=reviewCompleteChanged)
    def reviewComplete(self) -> bool:
        return self._review_complete

    @Property(str, notify=similarityStateChanged)
    def similarityState(self) -> str:
        return self._similarity_state

    @Property(str, notify=currentPhaseChanged)
    def currentPhase(self) -> str:
        return self._current_phase

    @Property(int, notify=progressChanged)
    def progress(self) -> int:
        return self._progress

    @Property(int, notify=groupCountChanged)
    def groupCount(self) -> int:
        return self._group_count

    @Property(int, notify=currentGroupIndexChanged)
    def currentGroupIndex(self) -> int:
        return self._current_group_index

    @Property(dict, notify=currentGroupDataChanged)
    def currentGroupData(self) -> dict:
        return self.getCurrentGroupData()

    # ── Slots ─────────────────────────────────────────────────────────

    @Slot()
    def startSimilarityProcessing(self):
        if self._similarity_state == "processing":
            return
            
        self._similarity_state = "processing"
        self._current_phase = "starting"
        self._progress = 0
        self._group_count = 0
        self._groups_cache = []
        self._current_group_index = 0
        
        self.similarityStateChanged.emit()
        self.currentPhaseChanged.emit()
        self.progressChanged.emit()
        
        if self._debug_service:
            self._debug_service.similarity_started()

        # Assuming latest scan session ID is 1 for now (could be fetched from ScanController)
        session_id = 1 
        
        # Read thresholds from settings controller
        phash_t = 12
        ssim_t = 0.55
        dhash_t = 18
        hist_t = 0.30
        if self._settings_controller:
            phash_t = self._settings_controller.phashThreshold
            ssim_t = self._settings_controller.ssimThreshold
            dhash_t = self._settings_controller.dhashThreshold
            hist_t = self._settings_controller.histogramThreshold

        self._worker = SimilarityWorker(
            self._hash_service,
            self._similarity_service,
            self._grouping_service,
            self._group_repository,
            session_id,
            phash_threshold=phash_t,
            ssim_threshold=ssim_t,
            dhash_threshold=dhash_t,
            histogram_threshold=hist_t
        )
        self._worker.signals.phase_changed.connect(self._on_phase_changed)
        self._worker.signals.progress.connect(self._on_progress)
        self._worker.signals.finished.connect(self._on_finished)
        self._worker.signals.error.connect(self._on_error)

        QThreadPool.globalInstance().start(self._worker)
        logger.info("Similarity processing started.")

    @Slot()
    def loadGroups(self):
        """Loads groups from DB for review."""
        self._groups_cache = self._group_repository.get_all_groups()
        self._group_count = len(self._groups_cache)
        self._current_group_index = 0
        self._review_complete = False
        
        self.groupCountChanged.emit()
        self.currentGroupIndexChanged.emit()
        self.currentGroupDataChanged.emit()
        self.reviewCompleteChanged.emit()

    @Slot()
    def nextGroup(self):
        if self._current_group_index < self._group_count - 1:
            self._current_group_index += 1
            self.currentGroupIndexChanged.emit()
            self.currentGroupDataChanged.emit()
        else:
            self._review_complete = True
            self.reviewCompleteChanged.emit()

    @Slot()
    def previousGroup(self):
        if self._review_complete:
            self._review_complete = False
            self.reviewCompleteChanged.emit()
            
        if self._current_group_index > 0:
            self._current_group_index -= 1
            self.currentGroupIndexChanged.emit()
            self.currentGroupDataChanged.emit()

    @Slot()
    def resetState(self):
        """Reset similarity state to idle (e.g. when a new scan starts)."""
        self._similarity_state = "idle"
        self._current_phase = ""
        self._progress = 0
        self._group_count = 0
        self._current_group_index = 0
        self._groups_cache = []
        self.similarityStateChanged.emit()
        self.currentPhaseChanged.emit()
        self.progressChanged.emit()
        self.groupCountChanged.emit()
        self.currentGroupIndexChanged.emit()
        self.currentGroupDataChanged.emit()

    @Slot()
    def skipGroup(self):
        """Skip current group without performing cleanup."""
        if self._current_group_index < self._group_count - 1:
            self.nextGroup()

    @Slot(result=dict)
    def getCurrentGroupData(self) -> dict:
        """Returns the current group's data including formatted image view-models.
        
        Filters out images that have been staged for trash so they
        don't appear in group review after the user stages them.
        """
        if not self._groups_cache or self._current_group_index >= len(self._groups_cache):
            return {}
            
        group = self._groups_cache[self._current_group_index]
        
        # Format images for QML, filtering out staged images (BUG 5)
        images_data = []
        for member in group.members:
            img = member.image
            if not img:
                logger.error(f"GroupMember {member.id} has no associated image loaded!")
                continue
            # Skip images that have been staged for deletion
            if getattr(img, 'is_staged_for_trash', 0) == 1:
                continue
            vm = ImageViewModel.from_image(img)
            images_data.append(vm)
            
        payload = {
            "score": round(group.similarity_score, 2),
            "type": group.group_type,
            "images": images_data,
            "count": len(images_data)
        }
        
        logger.debug(f"getCurrentGroupData: Group {group.id} with {len(images_data)} images. Payload: {payload}")
        return payload

    # ── Callbacks ─────────────────────────────────────────────────────

    def _on_phase_changed(self, phase: str):
        self._current_phase = phase
        self._progress = 0
        self.currentPhaseChanged.emit()
        self.progressChanged.emit()

    def _on_progress(self, current: int, total: int):
        self._progress = int((current / total) * 100) if total > 0 else 0
        self.progressChanged.emit()

    def _on_finished(self, groups_created: int):
        self._similarity_state = "ready"
        self._worker = None
        self.similarityStateChanged.emit()
        
        if self._debug_service:
            self._debug_service.similarity_completed()
            
        self.loadGroups()

    def _on_error(self, error_msg: str):
        self._similarity_state = "idle"
        self._worker = None
        self.similarityStateChanged.emit()
        
        if self._debug_service:
            self._debug_service.similarity_completed()
