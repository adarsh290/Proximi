"""Lightweight debug metrics collector for internal diagnostics.

Aggregates runtime metrics from scan, thumbnail, worker, and DB subsystems.
All data remains local — no network activity, no telemetry.
"""

import os
import time
import threading
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from app.database.image_repository import ImageRepository
from app.utils.logger import logger


@dataclass
class ScanMetrics:
    """Accumulated scan metrics for the current/last scan."""
    status: str = "idle"              # idle | scanning | completed | cancelled
    folder_path: str = ""
    images_scanned: int = 0
    images_skipped: int = 0           # unchanged files that were skipped
    images_failed: int = 0
    total_discovered: int = 0
    scan_session_id: Optional[int] = None
    scan_start_time: Optional[float] = None
    scan_end_time: Optional[float] = None

    @property
    def scan_duration_secs(self) -> float:
        if self.scan_start_time is None:
            return 0.0
        end = self.scan_end_time or time.time()
        return round(end - self.scan_start_time, 2)

    @property
    def throughput(self) -> float:
        """Images processed per second."""
        dur = self.scan_duration_secs
        if dur <= 0:
            return 0.0
        return round(self.images_scanned / dur, 1)


@dataclass
class ThumbnailMetrics:
    """Thumbnail cache performance counters."""
    generated: int = 0
    cache_hits: int = 0
    cache_misses: int = 0
    failures: int = 0

    @property
    def total_requests(self) -> int:
        return self.cache_hits + self.cache_misses + self.failures


@dataclass
class WorkerMetrics:
    """Thread pool worker status."""
    active_workers: int = 0
    is_cancelled: bool = False

@dataclass
class SimilarityMetrics:
    hashes_computed: int = 0
    candidate_pairs: int = 0
    refined_comparisons: int = 0
    groups_created: int = 0
    start_time: Optional[float] = None
    end_time: Optional[float] = None

    @property
    def duration_secs(self) -> float:
        if self.start_time is None:
            return 0.0
        end = self.end_time or time.time()
        return round(end - self.start_time, 2)


class DebugService:
    """Centralized metrics aggregation for internal debug panel.
    
    Thread-safe via a lock. Services report metrics here,
    and DebugController reads them for QML exposure.
    """

    def __init__(self, image_repository: ImageRepository):
        self._lock = threading.Lock()
        self._image_repository = image_repository
        self._scan = ScanMetrics()
        self._thumbnail = ThumbnailMetrics()
        self._worker = WorkerMetrics()
        self._similarity = SimilarityMetrics()

    # ── Scan Metrics ──────────────────────────────────────────────────

    def scan_started(self, folder_path: str, total_discovered: int, session_id: int) -> None:
        with self._lock:
            self._scan = ScanMetrics(
                status="scanning",
                folder_path=folder_path,
                total_discovered=total_discovered,
                scan_session_id=session_id,
                scan_start_time=time.time(),
            )
            self._thumbnail = ThumbnailMetrics()  # Reset per scan
            self._worker.active_workers = 1
            self._worker.is_cancelled = False

    def scan_image_processed(self, skipped: bool = False) -> None:
        with self._lock:
            if skipped:
                self._scan.images_skipped += 1
            self._scan.images_scanned += 1

    def scan_image_failed(self) -> None:
        with self._lock:
            self._scan.images_failed += 1

    def scan_completed(self) -> None:
        with self._lock:
            self._scan.status = "completed"
            self._scan.scan_end_time = time.time()
            self._worker.active_workers = 0

    def scan_cancelled(self) -> None:
        with self._lock:
            self._scan.status = "cancelled"
            self._scan.scan_end_time = time.time()
            self._worker.active_workers = 0
            self._worker.is_cancelled = True

    # ── Thumbnail Metrics ─────────────────────────────────────────────

    def thumbnail_cache_hit(self) -> None:
        with self._lock:
            self._thumbnail.cache_hits += 1

    def thumbnail_cache_miss(self) -> None:
        with self._lock:
            self._thumbnail.cache_misses += 1
            self._thumbnail.generated += 1

    def thumbnail_failed(self) -> None:
        with self._lock:
            self._thumbnail.failures += 1

    # ── Similarity Metrics ────────────────────────────────────────────

    def similarity_started(self) -> None:
        with self._lock:
            self._similarity = SimilarityMetrics(start_time=time.time())
            self._worker.active_workers = 1

    def similarity_hash_computed(self) -> None:
        with self._lock:
            self._similarity.hashes_computed += 1

    def similarity_candidate_found(self) -> None:
        with self._lock:
            self._similarity.candidate_pairs += 1

    def similarity_refinement_computed(self) -> None:
        with self._lock:
            self._similarity.refined_comparisons += 1

    def similarity_group_created(self) -> None:
        with self._lock:
            self._similarity.groups_created += 1

    def similarity_completed(self) -> None:
        with self._lock:
            self._similarity.end_time = time.time()
            self._worker.active_workers = 0

    # ── Snapshot (thread-safe read) ───────────────────────────────────

    def get_snapshot(self) -> dict:
        """Returns a complete metrics snapshot for the controller layer.
        
        All computation happens here — QML only renders values.
        """
        with self._lock:
            # DB stats (lightweight queries)
            try:
                db_image_count = self._image_repository.get_image_count()
                db_session_count = self._get_session_count()
            except Exception:
                db_image_count = -1
                db_session_count = -1

            # Thumbnail cache files on disk
            thumb_dir = Path("data/thumbnails")
            try:
                cached_files = len(list(thumb_dir.glob("*.webp"))) if thumb_dir.exists() else 0
            except Exception:
                cached_files = 0

            # Approximate RAM usage (process RSS)
            try:
                import psutil
                process = psutil.Process(os.getpid())
                ram_mb = round(process.memory_info().rss / (1024 * 1024), 1)
            except ImportError:
                # Fallback: no psutil available
                ram_mb = -1.0

            return {
                # Scan
                "scanStatus": self._scan.status,
                "scanFolder": self._scan.folder_path,
                "imagesScanned": self._scan.images_scanned,
                "imagesSkipped": self._scan.images_skipped,
                "imagesFailed": self._scan.images_failed,
                "totalDiscovered": self._scan.total_discovered,
                "scanSessionId": self._scan.scan_session_id or 0,
                "scanDuration": self._scan.scan_duration_secs,
                "scanThroughput": self._scan.throughput,
                # Thumbnail
                "thumbGenerated": self._thumbnail.generated,
                "thumbCacheHits": self._thumbnail.cache_hits,
                "thumbCacheMisses": self._thumbnail.cache_misses,
                "thumbFailures": self._thumbnail.failures,
                # Similarity
                "simHashes": self._similarity.hashes_computed,
                "simCandidates": self._similarity.candidate_pairs,
                "simRefined": self._similarity.refined_comparisons,
                "simGroups": self._similarity.groups_created,
                "simDuration": self._similarity.duration_secs,
                # Worker
                "activeWorkers": self._worker.active_workers,
                "workerCancelled": self._worker.is_cancelled,
                # Database
                "dbImageCount": db_image_count,
                "dbSessionCount": db_session_count,
                "dbCachedThumbnails": cached_files,
                # Runtime
                "ramUsageMb": ram_mb,
            }

    def _get_session_count(self) -> int:
        """Count scan sessions via repository."""
        from app.models.scan_session import ScanSession
        from app.database.connection import db as database
        session = database.SessionLocal()
        try:
            return session.query(ScanSession).count()
        finally:
            session.close()
