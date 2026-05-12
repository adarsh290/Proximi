from PySide6.QtCore import QObject, QRunnable, Signal, Slot
import time

from app.services.hash_service import HashService
from app.services.similarity_service import SimilarityService
from app.services.grouping_service import GroupingService
from app.database.group_repository import GroupRepository
from app.utils.logger import logger

class SimilarityWorkerSignals(QObject):
    phase_changed = Signal(str)         # "hashing" | "comparing" | "grouping" | "done"
    progress = Signal(int, int)         # current, total
    finished = Signal(int)              # total groups created
    error = Signal(str)

class SimilarityWorker(QRunnable):
    """Background worker for similarity pipeline."""

    def __init__(self, 
                 hash_service: HashService, 
                 similarity_service: SimilarityService, 
                 grouping_service: GroupingService,
                 group_repository: GroupRepository,
                 session_id: int):
        super().__init__()
        self.hash_service = hash_service
        self.similarity_service = similarity_service
        self.grouping_service = grouping_service
        self.group_repository = group_repository
        self.session_id = session_id
        self.signals = SimilarityWorkerSignals()
        self._cancelled = False
        self.setAutoDelete(True)

    def cancel(self):
        self._cancelled = True
        logger.info("Similarity processing cancellation requested.")

    def _is_cancelled(self) -> bool:
        return self._cancelled

    @Slot()
    def run(self):
        try:
            logger.info("SimilarityWorker started.")
            start_time = time.time()
            
            # Clear old groups
            self.group_repository.clear_groups()

            # Phase 1: Hashing
            if self._cancelled: return
            self.signals.phase_changed.emit("hashing")
            self.hash_service.compute_hashes_for_all(
                on_progress=lambda c, t: self.signals.progress.emit(c, t),
                is_cancelled=self._is_cancelled
            )

            # Phase 2: Comparing
            if self._cancelled: return
            self.signals.phase_changed.emit("comparing")
            # Milestone 3 Constraint: default threshold = 7
            similar_pairs = self.similarity_service.find_similar_pairs(
                candidate_threshold=7,
                on_progress=lambda c, t: self.signals.progress.emit(c, t),
                is_cancelled=self._is_cancelled
            )

            # Phase 3: Grouping
            if self._cancelled: return
            self.signals.phase_changed.emit("grouping")
            groups_created = self.grouping_service.generate_groups(
                similar_pairs=similar_pairs,
                session_id=self.session_id,
                on_progress=lambda c, t: self.signals.progress.emit(c, t),
                is_cancelled=self._is_cancelled
            )

            if self._cancelled:
                logger.info("SimilarityWorker cancelled.")
            else:
                duration = round(time.time() - start_time, 2)
                logger.info(f"SimilarityWorker finished in {duration}s: {groups_created} groups created.")
                
            self.signals.phase_changed.emit("done")
            self.signals.finished.emit(groups_created)

        except Exception as e:
            error_msg = f"Similarity processing failed: {e}"
            logger.error(error_msg)
            self.signals.error.emit(error_msg)
