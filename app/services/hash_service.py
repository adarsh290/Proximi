import time
from pathlib import Path
from PIL import Image as PILImage
import imagehash
from typing import Callable

from app.database.image_repository import ImageRepository
from app.utils.logger import logger
from app.services.debug_service import DebugService

class HashService:
    """Computes and persists perceptual hashes for images."""
    
    def __init__(self, image_repository: ImageRepository, debug_service: DebugService = None):
        self._image_repository = image_repository
        self._debug_service = debug_service

    def compute_hashes_for_all(self, on_progress: Callable[[int, int], None] = None, is_cancelled: Callable[[], bool] = None) -> int:
        """Process all unhashed images. Returns count processed."""
        images_to_hash = self._image_repository.get_images_without_hashes()
        total = len(images_to_hash)
        
        if total == 0:
            logger.info("No unhashed images found. Skipping hash computation.")
            return 0
            
        logger.info(f"Computing hashes for {total} images...")
        processed = 0
        
        for i, img in enumerate(images_to_hash):
            if is_cancelled and is_cancelled():
                break
                
            try:
                # Use thumbnail for hashing if available (faster), otherwise original
                source_path = img.thumbnail_path if img.thumbnail_path and Path(img.thumbnail_path).exists() else img.original_path
                
                with PILImage.open(source_path) as pil_img:
                    # Convert to RGB (required for some hash algorithms if image has alpha channel)
                    if pil_img.mode != 'RGB':
                        pil_img = pil_img.convert('RGB')
                        
                    # Compute hashes
                    phash = str(imagehash.phash(pil_img))
                    dhash = str(imagehash.dhash(pil_img))
                    
                self._image_repository.update_hashes(img.id, phash, dhash)
                processed += 1
                
                if self._debug_service:
                    self._debug_service.similarity_hash_computed()
                    
            except Exception as e:
                logger.error(f"Failed to compute hash for image {img.id} ({img.original_path}): {e}")
                
            if on_progress:
                on_progress(i + 1, total)
                
        return processed
