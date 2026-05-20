import uuid
from PySide6.QtCore import QObject, Slot, Signal, Property
from app.services.trash_service import TrashService
from app.controllers.similarity_controller import SimilarityController
from app.services.debug_service import DebugService
from app.utils.logger import logger
from urllib.request import url2pathname
from urllib.parse import urlparse

class CleanupController(QObject):
    """QObject bridge for executing cleanup and managing selection states."""

    selectionStateChanged = Signal()
    keeperCountChanged = Signal()
    rejectedCountChanged = Signal()
    canUndoChanged = Signal()
    lastActionChanged = Signal()
    totalDeletedChanged = Signal()
    stagedCountChanged = Signal()
    displayRotationChanged = Signal(int, int)  # imageId, newRotation
    
    # Emitted when an action is completed, carrying a status message for the UI
    actionCompleted = Signal(str)

    def __init__(self, 
                 trash_service: TrashService, 
                 similarity_controller: SimilarityController,
                 image_repository=None, # Injected in main.py
                 debug_service: DebugService = None,
                 scan_controller=None,   # Injected in main.py for count updates
                 parent=None):
        super().__init__(parent)
        self._trash_service = trash_service
        self._similarity_controller = similarity_controller
        self._image_repository = image_repository
        self._debug_service = debug_service
        self._scan_controller = scan_controller
        
        self._selection_state = {}  # {imageId: "keeper" | "rejected" | "unselected"}
        self._group_states = {}     # {group_index: selection_state_dict} — per-group persistence
        self._current_group_idx = -1
        self._last_batch_id = None
        self._last_batch_metadata = []  # Store image metadata for undo re-insertion
        self._last_action_msg = ""
        self._total_deleted = 0
        self._staged_count = 0      # BUG 4: Cached staged count
        
        # When similarity controller changes group, auto-select a keeper
        self._similarity_controller.currentGroupIndexChanged.connect(self._on_group_changed)

    # ── Properties ────────────────────────────────────────────────────

    @Property(int, notify=stagedCountChanged)
    def stagedCount(self) -> int:
        """Returns cached staged count (updated on staging changes)."""
        return self._staged_count

    @Property(dict, notify=selectionStateChanged)
    def selectionState(self) -> dict:
        return self._selection_state

    @Property(int, notify=keeperCountChanged)
    def keeperCount(self) -> int:
        return sum(1 for state in self._selection_state.values() if state == "keeper")

    @Property(int, notify=rejectedCountChanged)
    def rejectedCount(self) -> int:
        return sum(1 for state in self._selection_state.values() if state == "rejected")

    @Property(bool, notify=canUndoChanged)
    def canUndo(self) -> bool:
        return self._last_batch_id is not None

    @Property(str, notify=lastActionChanged)
    def lastAction(self) -> str:
        return self._last_action_msg

    @Property(int, notify=totalDeletedChanged)
    def totalDeleted(self) -> int:
        return self._total_deleted

    # ── Slots ─────────────────────────────────────────────────────────

    @Slot(int)
    def toggleSelection(self, image_id: int):
        """Toggle image between unselected <-> rejected. Keepers can also be toggled back."""
        img_id_str = str(image_id)
        current_state = self._selection_state.get(img_id_str, "unselected")
        if current_state == "rejected":
            self._selection_state[img_id_str] = "unselected"
        elif current_state == "keeper":
            # Allow un-keepering via toggle (sets back to unselected)
            self._selection_state[img_id_str] = "rejected"
        else:
            self._selection_state[img_id_str] = "rejected"
        self._selection_state = self._selection_state.copy()
        self._emit_selection_changes()

    @Slot(int)
    def setKeeper(self, image_id: int):
        """Toggle keeper state on this image. Multiple keepers are allowed per group."""
        img_id_str = str(image_id)
        current_state = self._selection_state.get(img_id_str, "unselected")
        
        if current_state == "keeper":
            # Toggle off: un-keeper this image
            self._selection_state[img_id_str] = "unselected"
        else:
            # Toggle on: mark as keeper
            self._selection_state[img_id_str] = "keeper"
                
        self._selection_state = self._selection_state.copy()
        self._emit_selection_changes()

    @Slot()
    def selectAllExceptKeeper(self):
        """Mark all non-keepers as rejected."""
        group_data = self._similarity_controller.getCurrentGroupData()
        if not group_data or "images" not in group_data:
            return
            
        for img in group_data["images"]:
            current_id_str = str(img["imageId"])
            if self._selection_state.get(current_id_str) != "keeper":
                self._selection_state[current_id_str] = "rejected"
                
        self._selection_state = self._selection_state.copy()
        self._emit_selection_changes()

    @Slot()
    def clearSelection(self):
        """Reset all selections."""
        self._selection_state.clear()
        self._selection_state = self._selection_state.copy()
        self._emit_selection_changes()

    @Slot()
    def executeCleanup(self):
        """Stages all rejected files for deletion and auto-advances."""
        group_data = self._similarity_controller.getCurrentGroupData()
        if not group_data or "images" not in group_data:
            return
            
        rejected_ids = []
        
        for img in group_data["images"]:
            img_id = img["imageId"]
            state = self._selection_state.get(str(img_id), "unselected")
            
            if state == "rejected":
                rejected_ids.append(img_id)
                
        if not rejected_ids:
            logger.info("Execute cleanup called but no images are rejected.")
            self.actionCompleted.emit("No images selected for cleanup.")
            return
            
        try:
            if self._image_repository:
                self._image_repository.stage_images_for_trash(rejected_ids)
                
            count = len(rejected_ids)
            msg = f"Staged {count} image{'s' if count > 1 else ''} for deletion."
            self._last_action_msg = msg
            logger.info(msg)
            
            self._refresh_staged_count()
            self.actionCompleted.emit(msg)
            
            # Save cleaned state for this group before auto-advancing
            current_idx = self._similarity_controller.currentGroupIndex
            self._group_states[current_idx] = self._selection_state.copy()
            
            # Auto-advance (Rule 1)
            self._similarity_controller.nextGroup()
                
        except Exception as e:
            logger.error(f"Staging execution failed: {e}")
            self.actionCompleted.emit("Failed to stage images.")

    @Slot()
    def commitStagedChanges(self):
        """Moves all staged files to the trash in one batch."""
        if not self._image_repository:
            return
            
        staged_images = self._image_repository.get_staged_images()
        if not staged_images:
            self.actionCompleted.emit("No staged changes to commit.")
            return
            
        files_to_trash = []
        staged_ids = []
        # BUG 3 fix: Store metadata for potential undo re-insertion
        batch_metadata = []
        
        for img in staged_images:
            files_to_trash.append({
                "original_path": img.original_path,
                "group_id": None,
                "scan_session_id": img.scan_session_id,
                "image_id": img.id
            })
            staged_ids.append(img.id)
            # Save all fields needed to recreate the record on undo
            batch_metadata.append({
                "id": img.id,
                "original_path": img.original_path,
                "file_name": img.file_name,
                "extension": img.extension,
                "width": img.width,
                "height": img.height,
                "file_size": img.file_size,
                "created_at": img.created_at,
                "modified_at": img.modified_at,
                "thumbnail_path": img.thumbnail_path,
                "scan_session_id": img.scan_session_id,
                "phash": img.phash,
                "dhash": img.dhash,
                "hash_computed_at": img.hash_computed_at,
            })
            
        batch_id = uuid.uuid4().hex
        
        try:
            moved_count, freed_bytes = self._trash_service.move_to_trash(files_to_trash, batch_id)
            
            if moved_count > 0:
                # BUG 1 fix: Delete DB records (files are now in trash, records are stale)
                self._image_repository.delete_images(staged_ids)
                
                self._last_batch_id = batch_id
                self._last_batch_metadata = batch_metadata  # Save for undo
                mb_freed = freed_bytes / (1024 * 1024)
                msg = f"Successfully cleaned {moved_count} image{'s' if moved_count > 1 else ''}. Freed {mb_freed:.1f} MB."
                self._last_action_msg = msg
                logger.info(msg)
                
                self.canUndoChanged.emit()
                self.lastActionChanged.emit()
                self._refresh_staged_count()
                self.actionCompleted.emit(msg)
                
                self._total_deleted += moved_count
                self.totalDeletedChanged.emit()
                
                # BUG 6 fix: Update scan controller image counts
                self._refresh_scan_counts()
                
                if self._debug_service:
                    self._debug_service.cleanup_executed(moved_count)
            else:
                self.actionCompleted.emit("Failed to move files to trash.")
                
        except Exception as e:
            logger.error(f"Commit failed: {e}")
            self.actionCompleted.emit("Commit failed due to an error.")

    @Slot()
    def clearStagedChanges(self):
        """Reverts all staged deletion marks."""
        if not self._image_repository:
            return
            
        try:
            self._image_repository.unstage_images_for_trash()
            msg = "Discarded all staged changes."
            self._last_action_msg = msg
            logger.info(msg)
            
            self._refresh_staged_count()
            self.actionCompleted.emit(msg)
            
            # Reset group states cache so they can be re-reviewed if needed
            self._group_states.clear()
            
        except Exception as e:
            logger.error(f"Clear staging failed: {e}")
            self.actionCompleted.emit("Failed to clear staged changes.")

    @Slot()
    def undoLastCleanup(self):
        """Restores the last cleanup batch."""
        if not self._last_batch_id:
            return
            
        try:
            restored_count = self._trash_service.restore_batch(self._last_batch_id)
            
            # BUG 3 fix: Re-insert DB records for restored images
            if restored_count > 0 and self._last_batch_metadata and self._image_repository:
                for meta in self._last_batch_metadata:
                    self._image_repository.insert_image_with_id({
                        "id": meta["id"],
                        "original_path": meta["original_path"],
                        "file_name": meta["file_name"],
                        "extension": meta["extension"],
                        "width": meta["width"],
                        "height": meta["height"],
                        "file_size": meta["file_size"],
                        "modified_at": meta["modified_at"],
                        "thumbnail_path": meta["thumbnail_path"],
                        "scan_session_id": meta["scan_session_id"],
                        "phash": meta["phash"],
                        "dhash": meta["dhash"],
                        "hash_computed_at": meta.get("hash_computed_at")
                    })
            
            msg = f"Undid cleanup. Restored {restored_count} image{'s' if restored_count > 1 else ''}."
            self._last_action_msg = msg
            logger.info(msg)
            
            self._last_batch_id = None
            self._last_batch_metadata = []
            
            # Update deleted count
            self._total_deleted = max(0, self._total_deleted - restored_count)
            self.totalDeletedChanged.emit()
            
            self.canUndoChanged.emit()
            self.lastActionChanged.emit()
            self.actionCompleted.emit(msg)
            
            # BUG 6 fix: Refresh scan counts after undo
            self._refresh_scan_counts()
            
            if self._debug_service:
                self._debug_service.undo_executed(restored_count)
                
            # Navigate back to the previous group
            self._similarity_controller.previousGroup()
            
        except Exception as e:
            logger.error(f"Undo failed: {e}")
            self.actionCompleted.emit("Undo failed due to an error.")

    # ── Internal ──────────────────────────────────────────────────────
    
    def _refresh_staged_count(self):
        """Update the cached staged count from DB and emit signal."""
        if self._image_repository:
            self._staged_count = self._image_repository.get_staged_count()
        else:
            self._staged_count = 0
        self.stagedCountChanged.emit()
    
    def _refresh_scan_counts(self):
        """BUG 6 fix: Update scan controller's image counts to reflect DB changes."""
        if self._scan_controller and self._image_repository:
            remaining = self._image_repository.get_image_count()
            self._scan_controller._total_images = remaining
            self._scan_controller._scanned_count = remaining
            self._scan_controller.totalImagesChanged.emit()
            self._scan_controller.scannedCountChanged.emit()
    
    def _on_group_changed(self):
        """When navigating to a new group, save current state and restore/create state for new group."""
        new_idx = self._similarity_controller.currentGroupIndex
        
        # Save current group's state before switching
        if self._current_group_idx >= 0:
            self._group_states[self._current_group_idx] = self._selection_state.copy()
        
        self._current_group_idx = new_idx
        
        # Restore if revisiting a previously visited group
        if new_idx in self._group_states:
            self._selection_state = self._group_states[new_idx].copy()
            self._emit_selection_changes()
            return
        
        # Fresh group — auto-select best image as keeper
        self._selection_state = {}
        
        group_data = self._similarity_controller.getCurrentGroupData()
        if not group_data or "images" not in group_data:
            self._emit_selection_changes()
            return
            
        # Heuristic: largest resolution, tiebreaker file size, tiebreaker earliest modified
        best_img = None
        best_score = (-1, -1, float('inf'))
        
        for img in group_data["images"]:
            res = img.get("width", 0) * img.get("height", 0)
            size = img.get("fileSize", 0)
            modified = img.get("modifiedAt", 0)
            
            score = (res, size, modified)
            
            if best_img is None:
                best_img = img
                best_score = score
            else:
                if score[0] > best_score[0]:
                    best_img = img
                    best_score = score
                elif score[0] == best_score[0]:
                    if score[1] > best_score[1]:
                        best_img = img
                        best_score = score
                    elif score[1] == best_score[1]:
                        if score[2] < best_score[2]:
                            best_img = img
                            best_score = score
                            
        if best_img:
            self._selection_state[str(best_img["imageId"])] = "keeper"
            
        self._selection_state = self._selection_state.copy()
        self._emit_selection_changes()

    def _emit_selection_changes(self):
        self.selectionStateChanged.emit()
        self.keeperCountChanged.emit()
        self.rejectedCountChanged.emit()

    # ── Display Rotation ──────────────────────────────────────────────

    @Slot(int)
    def rotateImage(self, image_id: int):
        """Rotate an image 90° counter-clockwise (display only, does not touch original file).
        
        Cycles through: 0 → 270 → 180 → 90 → 0 (CCW rotation steps).
        """
        if not self._image_repository:
            return
        
        # Get current rotation from DB
        from app.database.connection import db
        from app.models.image import Image
        session = db.SessionLocal()
        try:
            img = session.query(Image).filter(Image.id == image_id).first()
            if img:
                current = img.display_rotation or 0
                new_rotation = (current + 270) % 360  # +270 = -90 = 90° CCW
                self._image_repository.set_display_rotation(image_id, new_rotation)
                self.displayRotationChanged.emit(image_id, new_rotation)
                logger.debug(f"Rotated image {image_id}: {current}° → {new_rotation}° CCW")
        finally:
            session.close()
