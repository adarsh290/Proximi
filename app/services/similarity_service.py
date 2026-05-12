import imagehash
from typing import Callable, List, Tuple
from pathlib import Path
from PIL import Image as PILImage
from skimage.metrics import structural_similarity as ssim
import numpy as np

from app.database.image_repository import ImageRepository
from app.utils.logger import logger
from app.services.debug_service import DebugService

class SimilarityService:
    """Multi-stage pipeline: fast hash filtering + refined SSIM/Histogram scoring."""
    
    def __init__(self, image_repository: ImageRepository, debug_service: DebugService = None):
        self._image_repository = image_repository
        self._debug_service = debug_service

    def find_similar_pairs(self, 
                           candidate_threshold: int = 7, 
                           on_progress: Callable[[int, int], None] = None, 
                           is_cancelled: Callable[[], bool] = None) -> List[Tuple[int, int, float]]:
        """
        Returns list of (image_id_a, image_id_b, final_score) pairs.
        candidate_threshold: Max pHash Hamming distance for Phase 1.
        """
        images = self._image_repository.get_all_hashed_images()
        total_images = len(images)
        
        if total_images < 2:
            return []

        logger.info(f"Starting similarity filtering for {total_images} images...")
        
        # Pre-parse hashes
        parsed_data = []
        for img in images:
            try:
                ph = imagehash.hex_to_hash(img.phash) if img.phash else None
                dh = imagehash.hex_to_hash(img.dhash) if img.dhash else None
                if ph:
                    parsed_data.append((img, ph, dh))
            except Exception as e:
                logger.error(f"Failed to parse hash for image {img.id}: {e}")
                
        candidates = []
        comparisons = 0
        total_pairs = (len(parsed_data) * (len(parsed_data) - 1)) // 2
        
        # Stage 1: Candidate Filtering (pHash Hamming Distance)
        for i in range(len(parsed_data)):
            if is_cancelled and is_cancelled():
                return []
                
            img_a, ph_a, dh_a = parsed_data[i]
            
            for j in range(i + 1, len(parsed_data)):
                img_b, ph_b, dh_b = parsed_data[j]
                
                distance = ph_a - ph_b
                
                if distance <= candidate_threshold:
                    candidates.append((img_a, img_b, distance, dh_a, dh_b))
                    if self._debug_service:
                        self._debug_service.similarity_candidate_found()
                        
                comparisons += 1
                
            if on_progress and (i % max(1, len(parsed_data) // 20) == 0):
                progress_pct = int((comparisons / max(1, total_pairs)) * 50)
                on_progress(progress_pct, 100)
                
        logger.info(f"Phase 1 complete: found {len(candidates)} candidate pairs out of {total_pairs} total comparisons.")
        
        # Stage 2: Refined Scoring
        final_pairs = []
        total_candidates = len(candidates)
        
        for i, (img_a, img_b, ph_distance, dh_a, dh_b) in enumerate(candidates):
            if is_cancelled and is_cancelled():
                return []
                
            try:
                # 1. Aspect Ratio Hard Rejection
                if img_a.width and img_a.height and img_b.width and img_b.height:
                    ar_a = img_a.width / img_a.height
                    ar_b = img_b.width / img_b.height
                    if abs(ar_a - ar_b) / min(ar_a, ar_b) > 0.2:
                        continue  # Aspect ratios differ by >20%
                
                # 2. dHash check
                dh_distance = dh_a - dh_b if dh_a and dh_b else None
                if dh_distance is not None and dh_distance > 12:
                    continue  # dHash differs significantly
                
                # 3. Histogram Similarity
                hist_score = self._compute_histogram_similarity(img_a, img_b)
                if hist_score < 0.4:
                    continue  # Very low color distribution match
                
                # 4. SSIM
                raw_ssim = self._compute_ssim(img_a, img_b)
                if self._debug_service:
                    self._debug_service.similarity_refinement_computed()
                
                # Composite Scoring & Threshold
                # Base composite on raw_ssim, with penalties for hash differences
                composite_score = raw_ssim
                if ph_distance > 4:
                    composite_score -= 0.05
                if hist_score < 0.6:
                    composite_score -= 0.05
                    
                # Strict SSIM threshold: > 0.85 raw is highly similar
                if composite_score >= 0.82:
                    final_pairs.append((img_a.id, img_b.id, composite_score))
                    logger.debug(f"ACCEPTED PAIR: A={img_a.id}, B={img_b.id} | "
                                 f"pHash={ph_distance}, dHash={dh_distance}, "
                                 f"Hist={hist_score:.3f}, SSIM={raw_ssim:.3f}, "
                                 f"Final={composite_score:.3f}")
                    
            except Exception as e:
                logger.error(f"Failed to refine similarity for pair ({img_a.id}, {img_b.id}): {e}")
                
            if on_progress:
                progress_pct = 50 + int((i / max(1, total_candidates)) * 50)
                on_progress(progress_pct, 100)
                
        logger.info(f"Phase 2 complete: {len(final_pairs)} pairs passed refinement.")
        return final_pairs

    def _compute_histogram_similarity(self, img_a, img_b) -> float:
        """Compute histogram intersection score (0.0 to 1.0)."""
        path_a = img_a.thumbnail_path if img_a.thumbnail_path and Path(img_a.thumbnail_path).exists() else img_a.original_path
        path_b = img_b.thumbnail_path if img_b.thumbnail_path and Path(img_b.thumbnail_path).exists() else img_b.original_path
        try:
            with PILImage.open(path_a) as pil_a, PILImage.open(path_b) as pil_b:
                hist_a = pil_a.convert('RGB').histogram()
                hist_b = pil_b.convert('RGB').histogram()
                
                sum_a = sum(hist_a)
                sum_b = sum(hist_b)
                if sum_a == 0 or sum_b == 0:
                    return 0.0
                    
                norm_a = [x / sum_a for x in hist_a]
                norm_b = [x / sum_b for x in hist_b]
                
                intersection = sum(min(a, b) for a, b in zip(norm_a, norm_b))
                return float(intersection)
        except Exception as e:
            logger.error(f"Histogram computation failed: {e}")
            return 0.0

    def _compute_ssim(self, img_a, img_b) -> float:
        """Compute RAW structural similarity index (-1.0 to 1.0)."""
        path_a = img_a.thumbnail_path if img_a.thumbnail_path and Path(img_a.thumbnail_path).exists() else img_a.original_path
        path_b = img_b.thumbnail_path if img_b.thumbnail_path and Path(img_b.thumbnail_path).exists() else img_b.original_path
        
        try:
            with PILImage.open(path_a) as pil_a, PILImage.open(path_b) as pil_b:
                gray_a = pil_a.convert('L')
                gray_b = pil_b.convert('L')
                
                if gray_a.size != gray_b.size:
                    gray_b = gray_b.resize(gray_a.size)
                    
                np_a = np.array(gray_a)
                np_b = np.array(gray_b)
                
                score, _ = ssim(np_a, np_b, full=True)
                # Return RAW score (no normalization)
                return float(score)
                
        except Exception as e:
            logger.error(f"SSIM computation failed: {e}")
            return -1.0
