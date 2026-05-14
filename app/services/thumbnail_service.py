import hashlib
from pathlib import Path
from typing import Optional

from PIL import Image as PILImage, ImageOps

# Register HEIC/HEIF format support with Pillow
try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
except ImportError:
    pass  # HEIC support unavailable — .heic files will fail gracefully

from app.utils.logger import logger

# Maximum thumbnail dimension (width or height)
THUMBNAIL_MAX_SIZE = 256
THUMBNAIL_QUALITY = 85


class ThumbnailService:
    """Handles thumbnail generation and cache management."""

    def __init__(self, cache_dir: str = "data/thumbnails", debug_service=None):
        self.cache_dir = Path(cache_dir).resolve()  # Always absolute
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self._debug_service = debug_service

    def _build_cache_key(self, source_path: str, modified_timestamp: float) -> str:
        """Generates a deterministic, collision-safe filename from path + mtime.
        
        Uses SHA256 hash of the normalized path combined with the file's
        modification timestamp to ensure cache invalidation when files change.
        """
        raw = f"{source_path}|{modified_timestamp}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    def _get_cache_path(self, cache_key: str) -> Path:
        """Returns the full path for a cached thumbnail."""
        return self.cache_dir / f"{cache_key}.webp"

    def get_cached_thumbnail(self, source_path: str, modified_timestamp: float) -> Optional[str]:
        """Check if a valid cached thumbnail exists.
        
        Returns:
            Path to cached thumbnail as string, or None if not cached.
        """
        cache_key = self._build_cache_key(source_path, modified_timestamp)
        cache_path = self._get_cache_path(cache_key)

        if cache_path.exists():
            logger.debug(f"Cache HIT: {Path(source_path).name}")
            return str(cache_path)  # Already absolute via resolved cache_dir

        return None

    def generate_thumbnail(self, source_path: str, modified_timestamp: float) -> Optional[str]:
        """Generate a thumbnail for an image file.
        
        Checks cache first. If cached version exists, returns it.
        Otherwise generates a new thumbnail.
        
        Args:
            source_path: Absolute path to the source image.
            modified_timestamp: File modification time (used for cache key).
            
        Returns:
            Path to the thumbnail as string, or None on failure.
        """
        # Check cache first
        cached = self.get_cached_thumbnail(source_path, modified_timestamp)
        if cached:
            if self._debug_service:
                self._debug_service.thumbnail_cache_hit()
            return cached

        cache_key = self._build_cache_key(source_path, modified_timestamp)
        cache_path = self._get_cache_path(cache_key)

        try:
            with PILImage.open(source_path) as img:
                # Apply EXIF rotation automatically
                img = ImageOps.exif_transpose(img)

                # Convert to RGB if necessary (handles RGBA, P, etc.)
                if img.mode not in ("RGB", "L"):
                    img = img.convert("RGB")

                # Resize preserving aspect ratio
                img.thumbnail((THUMBNAIL_MAX_SIZE, THUMBNAIL_MAX_SIZE), PILImage.LANCZOS)

                # Save as WEBP — optimized format with better compression
                img.save(str(cache_path), "WEBP", quality=THUMBNAIL_QUALITY, method=4)

            logger.debug(f"Cache MISS — generated: {Path(source_path).name}")
            if self._debug_service:
                self._debug_service.thumbnail_cache_miss()
            return str(cache_path)

        except Exception as e:
            logger.warning(f"Failed to generate thumbnail for '{source_path}': {e}")
            if self._debug_service:
                self._debug_service.thumbnail_failed()
            # Clean up partial file if it was created
            if cache_path.exists():
                cache_path.unlink(missing_ok=True)
            return None

    def get_image_dimensions(self, source_path: str) -> tuple[Optional[int], Optional[int]]:
        """Read image dimensions without loading full image data.
        
        Returns:
            Tuple of (width, height), or (None, None) on failure.
        """
        try:
            with PILImage.open(source_path) as img:
                # Apply EXIF rotation to get correct visual dimensions
                img = ImageOps.exif_transpose(img)
                return img.size  # (width, height)
        except Exception as e:
            logger.warning(f"Failed to read dimensions for '{source_path}': {e}")
            return None, None
