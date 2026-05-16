from datetime import datetime
from pathlib import Path
from typing import Callable, Optional

from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed

from app.database.image_repository import ImageRepository
from app.services.thumbnail_service import ThumbnailService
from app.utils.logger import logger

# Supported image extensions
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic"}

# Parallelism tuning
_THUMBNAIL_WORKERS = 6       # Parallel thumbnail generation threads
_DB_BATCH_SIZE = 50           # Batch DB writes every N images


class ScanService:
    """Orchestrates folder scanning, thumbnail generation, and DB persistence.
    
    Pipeline (optimized):
        1. Recursive discovery
        2. Parallel processing via ThreadPoolExecutor:
           - Metadata extraction (stat + dimensions)
           - Thumbnail generation (Pillow → WEBP cache)
        3. Batched DB persistence (every _DB_BATCH_SIZE images)
        4. Progressive UI updates (via callback)
    """

    def __init__(self, image_repository: ImageRepository, thumbnail_service: ThumbnailService, debug_service=None):
        self.image_repository = image_repository
        self.thumbnail_service = thumbnail_service
        self._debug_service = debug_service

    def discover_images(self, folder_path: str) -> list[Path]:
        """Recursively discover supported image files in a folder.
        
        Returns:
            Sorted list of resolved Path objects for supported images.
        """
        folder = Path(folder_path)
        if not folder.is_dir():
            logger.error(f"Folder does not exist: {folder_path}")
            return []

        discovered = []
        skipped_extensions: Counter = Counter()
        total_files = 0

        for item in folder.rglob("*"):
            if not item.is_file():
                continue
            total_files += 1
            ext = item.suffix.lower()
            if ext in SUPPORTED_EXTENSIONS:
                discovered.append(item.resolve())
            else:
                skipped_extensions[ext] += 1

        # Sort for deterministic processing order
        discovered.sort()

        # Log results
        skipped_count = total_files - len(discovered)
        logger.info(f"Discovered {len(discovered)} supported images in '{folder_path}' "
                     f"(total files: {total_files}, skipped: {skipped_count})")
        if skipped_extensions:
            for ext, count in skipped_extensions.most_common():
                logger.info(f"  Skipped {count} files with extension '{ext}'")

        return discovered

    def _process_single_image_io(self, image_path: Path) -> Optional[dict]:
        """Pure I/O work for a single image: stat, dimensions, thumbnail.
        
        This method does NO database work — it's safe to run from any thread.
        Returns a dict with all the data needed for DB persistence, or None.
        """
        try:
            original_path = str(image_path)

            # ── Step 1: Metadata extraction ───────────────────────────
            stat = image_path.stat()
            file_size = stat.st_size
            modified_timestamp = stat.st_mtime
            modified_at = datetime.fromtimestamp(modified_timestamp)

            # Read dimensions
            width, height = self.thumbnail_service.get_image_dimensions(original_path)

            # ── Step 2: Thumbnail generation ──────────────────────────
            thumbnail_path = self.thumbnail_service.generate_thumbnail(
                original_path, modified_timestamp
            )

            return {
                "original_path": original_path,
                "file_name": image_path.name,
                "extension": image_path.suffix.lower(),
                "width": width,
                "height": height,
                "file_size": file_size,
                "modified_at": modified_at,
                "thumbnail_path": thumbnail_path,
                "modified_timestamp": modified_timestamp,
            }

        except PermissionError:
            logger.warning(f"Permission denied: '{image_path}'")
            return None
        except OSError as e:
            logger.warning(f"OS error processing '{image_path}': {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error processing '{image_path}': {e}")
            return None

    def process_single_image(
        self,
        image_path: Path,
        scan_session_id: int
    ) -> Optional[dict]:
        """Process a single image following the ordered pipeline:
        
        1. Metadata extraction (stat + dimensions)
        2. DB persistence (upsert)
        3. Thumbnail generation
        4. Update DB with thumbnail path
        
        Returns:
            Dict with keys (original_path, thumbnail_path, file_name) on success,
            or None on failure.
        """
        try:
            original_path = str(image_path)
            
            # ── Step 1: Metadata extraction ───────────────────────────
            stat = image_path.stat()
            file_size = stat.st_size
            modified_timestamp = stat.st_mtime
            modified_at = datetime.fromtimestamp(modified_timestamp)

            # Check if image already exists with same mtime (skip if unchanged)
            existing = self.image_repository.get_image_by_path(original_path)
            if existing and existing.modified_at == modified_at and existing.thumbnail_path:
                return {
                    "original_path": existing.original_path,
                    "thumbnail_path": existing.thumbnail_path,
                    "file_name": existing.file_name,
                    "skipped": True,
                }

            # Read dimensions (Pillow — opens file briefly, does not load full raster)
            width, height = self.thumbnail_service.get_image_dimensions(original_path)

            # ── Step 2: DB persistence (metadata first, thumbnail later) ──
            image_data = {
                "original_path": original_path,
                "file_name": image_path.name,
                "extension": image_path.suffix.lower(),
                "width": width,
                "height": height,
                "file_size": file_size,
                "modified_at": modified_at,
                "thumbnail_path": None,  # Set after thumbnail generation
                "scan_session_id": scan_session_id,
            }
            self.image_repository.upsert_image(image_data)

            # ── Step 3: Thumbnail generation ──────────────────────────
            thumbnail_path = self.thumbnail_service.generate_thumbnail(
                original_path, modified_timestamp
            )

            # ── Step 4: Update DB with thumbnail path ─────────────────
            if thumbnail_path:
                update_data = {
                    "original_path": original_path,
                    "thumbnail_path": thumbnail_path,
                }
                self.image_repository.upsert_image(update_data)

            return {
                "original_path": original_path,
                "thumbnail_path": thumbnail_path or "",
                "file_name": image_path.name,
                "skipped": False,
            }

        except PermissionError:
            logger.warning(f"Permission denied: '{image_path}'")
            return None
        except OSError as e:
            logger.warning(f"OS error processing '{image_path}': {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error processing '{image_path}': {e}")
            return None

    def scan_folder(
        self,
        folder_path: str,
        on_image_ready: Optional[Callable] = None,
        on_progress: Optional[Callable] = None,
        is_cancelled: Optional[Callable] = None,
    ) -> int:
        """Full scan pipeline: discover → parallel process → batched persist.
        
        Optimizations over the original sequential pipeline:
        - Thumbnail generation (the heaviest I/O) runs on a ThreadPoolExecutor
        - DB writes are batched every _DB_BATCH_SIZE images instead of 2 writes/image
        - Skip-detection still works for unchanged images
        
        Args:
            folder_path: Path to the folder to scan.
            on_image_ready: Callback(original_path, thumbnail_path, file_name)
            on_progress: Callback(current_index, total_count)
            is_cancelled: Callable returning True if scan should abort.
            
        Returns:
            Total number of successfully processed images.
        """
        # Create scan session
        session_id = self.image_repository.create_scan_session(folder_path)

        # Discover images
        image_paths = self.discover_images(folder_path)
        total = len(image_paths)

        if total == 0:
            self.image_repository.complete_scan_session(session_id, 0)
            logger.info("No images found in folder.")
            return 0

        # Report scan start to debug service
        if self._debug_service:
            self._debug_service.scan_started(folder_path, total, session_id)

        # ── Phase 1: Quick skip-check for unchanged images ────────────
        # Separate images into "needs processing" vs "already cached"
        to_process = []
        skipped_results = []

        for image_path in image_paths:
            if is_cancelled and is_cancelled():
                break
            original_path = str(image_path)
            try:
                stat = image_path.stat()
                modified_at = datetime.fromtimestamp(stat.st_mtime)
                existing = self.image_repository.get_image_by_path(original_path)
                if existing and existing.modified_at == modified_at and existing.thumbnail_path:
                    skipped_results.append({
                        "original_path": existing.original_path,
                        "thumbnail_path": existing.thumbnail_path,
                        "file_name": existing.file_name,
                        "skipped": True,
                    })
                    continue
            except Exception:
                pass  # Fall through to processing
            to_process.append(image_path)

        logger.info(f"Skip-check complete: {len(skipped_results)} cached, {len(to_process)} to process.")

        # Emit skipped images immediately to the UI
        processed_count = 0
        for result in skipped_results:
            processed_count += 1
            if self._debug_service:
                self._debug_service.scan_image_processed(skipped=True)
            if on_image_ready and result.get("thumbnail_path"):
                on_image_ready(result["original_path"], result["thumbnail_path"], result["file_name"])

        if on_progress:
            on_progress(processed_count, total)

        # ── Phase 2: Parallel I/O for new images ──────────────────────
        # Thumbnail generation is I/O-bound (decode + resize + encode).
        # We parallelize this across multiple threads.
        if to_process and not (is_cancelled and is_cancelled()):
            pending_batch = []

            with ThreadPoolExecutor(max_workers=_THUMBNAIL_WORKERS) as executor:
                future_to_path = {
                    executor.submit(self._process_single_image_io, path): path
                    for path in to_process
                }

                for future in as_completed(future_to_path):
                    if is_cancelled and is_cancelled():
                        executor.shutdown(wait=False, cancel_futures=True)
                        break

                    io_result = future.result()

                    if io_result:
                        # Prepare data for batched DB write
                        pending_batch.append({
                            "image_data": {
                                "original_path": io_result["original_path"],
                                "file_name": io_result["file_name"],
                                "extension": io_result["extension"],
                                "width": io_result["width"],
                                "height": io_result["height"],
                                "file_size": io_result["file_size"],
                                "modified_at": io_result["modified_at"],
                                "thumbnail_path": io_result["thumbnail_path"],
                                "scan_session_id": session_id,
                            },
                            "callback_data": {
                                "original_path": io_result["original_path"],
                                "thumbnail_path": io_result["thumbnail_path"] or "",
                                "file_name": io_result["file_name"],
                            }
                        })
                    else:
                        if self._debug_service:
                            self._debug_service.scan_image_failed()

                    # Flush batch to DB when it reaches _DB_BATCH_SIZE
                    if len(pending_batch) >= _DB_BATCH_SIZE:
                        self._flush_batch(pending_batch, on_image_ready)
                        processed_count += len(pending_batch)
                        pending_batch = []

                    if on_progress:
                        on_progress(processed_count + len(pending_batch), total)

                # Flush remaining
                if pending_batch:
                    self._flush_batch(pending_batch, on_image_ready)
                    processed_count += len(pending_batch)

        if on_progress:
            on_progress(total, total)

        # Complete session
        self.image_repository.complete_scan_session(session_id, processed_count)
        logger.info(f"Scan complete: {processed_count}/{total} images processed")
        return processed_count

    def _flush_batch(self, batch: list[dict], on_image_ready: Optional[Callable] = None):
        """Persist a batch of processed images to the DB and notify the UI."""
        for item in batch:
            try:
                self.image_repository.upsert_image(item["image_data"])

                if self._debug_service:
                    self._debug_service.scan_image_processed(skipped=False)

                cb = item["callback_data"]
                if on_image_ready and cb["thumbnail_path"]:
                    on_image_ready(cb["original_path"], cb["thumbnail_path"], cb["file_name"])
            except Exception as e:
                logger.error(f"Failed to persist image: {e}")
