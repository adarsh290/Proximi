import imagehash
from typing import Callable, List, Tuple
from pathlib import Path
from PIL import Image as PILImage
from skimage.metrics import structural_similarity as ssim
import numpy as np
from concurrent.futures import ThreadPoolExecutor, as_completed

from app.database.image_repository import ImageRepository
from app.utils.logger import logger
from app.services.debug_service import DebugService


class SimilarityService:
    """Multi-stage pipeline: fast hash filtering + refined SSIM/Histogram scoring.
    
    Optimized with:
    - Vectorized numpy pHash Hamming distance (Phase 1)
    - Numpy histogram intersection (Phase 2)
    - Parallel I/O via ThreadPoolExecutor (Phase 2)
    """

    # Number of parallel workers for Phase 2 image I/O
    _REFINEMENT_WORKERS = 4

    def __init__(self, image_repository: ImageRepository, debug_service: DebugService = None):
        self._image_repository = image_repository
        self._debug_service = debug_service

    @staticmethod
    def _popcount_uint64(arr: np.ndarray) -> np.ndarray:
        """Vectorized population count (Hamming weight) for uint64 arrays.
        
        Uses the standard parallel bit-count algorithm, fully vectorized
        with numpy. Orders of magnitude faster than Python-level loops.
        """
        arr = arr.astype(np.uint64)
        arr = arr - ((arr >> np.uint64(1)) & np.uint64(0x5555555555555555))
        arr = (arr & np.uint64(0x3333333333333333)) + ((arr >> np.uint64(2)) & np.uint64(0x3333333333333333))
        arr = (arr + (arr >> np.uint64(4))) & np.uint64(0x0F0F0F0F0F0F0F0F)
        return ((arr * np.uint64(0x0101010101010101)) >> np.uint64(56)).astype(np.int32)

    def find_similar_pairs(self, 
                           candidate_threshold: int = 12,
                           ssim_threshold: float = 0.55,
                           dhash_threshold: int = 18,
                           histogram_threshold: float = 0.30,
                           on_progress: Callable[[int, int], None] = None, 
                           is_cancelled: Callable[[], bool] = None) -> List[Tuple[int, int, float]]:
        """
        Returns list of (image_id_a, image_id_b, final_score) pairs.
        candidate_threshold: Max pHash Hamming distance for Phase 1.
        ssim_threshold: Min composite SSIM score for Phase 2 acceptance.
        dhash_threshold: Max dHash Hamming distance before rejection.
        histogram_threshold: Min histogram intersection before rejection.
        """
        images = self._image_repository.get_all_hashed_images()
        total_images = len(images)
        
        if total_images < 2:
            return []

        logger.info(f"Starting similarity filtering for {total_images} images...")
        
        # Pre-parse: convert hex hash strings to uint64 integers for vectorized ops
        valid_images = []
        phash_ints = []
        dhash_ints = []
        dhash_present = []

        for img in images:
            try:
                if img.phash:
                    phash_ints.append(int(img.phash, 16))
                    dhash_ints.append(int(img.dhash, 16) if img.dhash else 0)
                    dhash_present.append(img.dhash is not None)
                    valid_images.append(img)
            except Exception as e:
                logger.error(f"Failed to parse hash for image {img.id}: {e}")

        n = len(valid_images)
        if n < 2:
            return []

        phash_arr = np.array(phash_ints, dtype=np.uint64)
        dhash_arr = np.array(dhash_ints, dtype=np.uint64)
        dhash_valid = np.array(dhash_present, dtype=bool)

        # ── Stage 1: Vectorized pHash candidate filtering ──
        # For each image i, numpy-broadcast XOR + popcount against all j > i.
        # This replaces the pure-Python nested loop with vectorized numpy ops.
        candidates = []
        total_pairs = (n * (n - 1)) // 2
        comparisons_done = 0

        for i in range(n - 1):
            if is_cancelled and is_cancelled():
                return []

            # Vectorized: XOR image i's hash with all subsequent hashes
            xor_result = phash_arr[i] ^ phash_arr[i + 1:]
            distances = self._popcount_uint64(xor_result)

            # Boolean mask for matches within threshold
            match_mask = distances <= candidate_threshold
            
            # Dual-hash vectorized pre-filter
            if dhash_valid[i]:
                dh_xor = dhash_arr[i] ^ dhash_arr[i + 1:]
                dh_dist = self._popcount_uint64(dh_xor)
                
                # Reject if BOTH have valid dHash AND distance > threshold
                valid_both = dhash_valid[i + 1:]
                reject_mask = valid_both & (dh_dist > dhash_threshold)
                match_mask = match_mask & (~reject_mask)

            match_indices = np.where(match_mask)[0] + (i + 1)
            match_distances = distances[match_mask]

            for idx, dist in zip(match_indices, match_distances):
                candidates.append((i, int(idx), int(dist)))
                if self._debug_service:
                    self._debug_service.similarity_candidate_found()

            comparisons_done += (n - i - 1)

            if on_progress and (i % max(1, n // 20) == 0):
                progress_pct = int((comparisons_done / max(1, total_pairs)) * 50)
                on_progress(progress_pct, 100)

        logger.info(f"Phase 1 complete: found {len(candidates)} candidate pairs "
                     f"out of {total_pairs} total comparisons.")

        # ── Stage 2: Parallel refined scoring ──
        total_candidates = len(candidates)

        if total_candidates == 0:
            if on_progress:
                on_progress(100, 100)
            return []

        def _refine_single_pair(candidate_tuple):
            """Process a single candidate pair. Returns (id_a, id_b, score) or None."""
            i, j, ph_distance = candidate_tuple
            img_a = valid_images[i]
            img_b = valid_images[j]

            try:
                # 1. Aspect Ratio Hard Rejection
                if img_a.width and img_a.height and img_b.width and img_b.height:
                    ar_a = img_a.width / img_a.height
                    ar_b = img_b.width / img_b.height
                    if abs(ar_a - ar_b) / min(ar_a, ar_b) > 0.3:
                        return None

                # 2. dHash check (inline popcount for single value)
                dh_distance = None
                if dhash_valid[i] and dhash_valid[j]:
                    dh_distance = int(self._popcount_uint64(np.array([dhash_arr[i] ^ dhash_arr[j]], dtype=np.uint64))[0])
                    if dh_distance > dhash_threshold:
                        return None

                # 3. Histogram Similarity (numpy-optimized)
                hist_score = self._compute_histogram_similarity(img_a, img_b)
                if hist_score < histogram_threshold:
                    return None

                # 4. SSIM
                raw_ssim = self._compute_ssim(img_a, img_b)
                if self._debug_service:
                    self._debug_service.similarity_refinement_computed()

                # Composite Scoring & Threshold
                composite_score = raw_ssim
                if ph_distance > 4:
                    composite_score -= 0.05
                if hist_score < 0.6:
                    composite_score -= 0.05

                if composite_score >= ssim_threshold:
                    logger.debug(f"ACCEPTED PAIR: A={img_a.id}, B={img_b.id} | "
                                 f"pHash={ph_distance}, dHash={dh_distance}, "
                                 f"Hist={hist_score:.3f}, SSIM={raw_ssim:.3f}, "
                                 f"Final={composite_score:.3f}")
                    return (img_a.id, img_b.id, composite_score)

            except Exception as e:
                logger.error(f"Failed to refine similarity for pair ({img_a.id}, {img_b.id}): {e}")

            return None

        final_pairs = []
        completed = 0

        with ThreadPoolExecutor(max_workers=self._REFINEMENT_WORKERS) as executor:
            futures = {executor.submit(_refine_single_pair, c): c for c in candidates}

            for future in as_completed(futures):
                if is_cancelled and is_cancelled():
                    executor.shutdown(wait=False, cancel_futures=True)
                    return []

                result = future.result()
                if result is not None:
                    final_pairs.append(result)

                completed += 1
                if on_progress and (completed % max(1, total_candidates // 20) == 0):
                    progress_pct = 50 + int((completed / max(1, total_candidates)) * 50)
                    on_progress(progress_pct, 100)

        if on_progress:
            on_progress(100, 100)

        logger.info(f"Phase 2 complete: {len(final_pairs)} pairs passed refinement.")
        return final_pairs

    def _compute_histogram_similarity(self, img_a, img_b) -> float:
        """Compute histogram intersection score (0.0 to 1.0). Numpy-optimized."""
        path_a = img_a.thumbnail_path if img_a.thumbnail_path and Path(img_a.thumbnail_path).exists() else img_a.original_path
        path_b = img_b.thumbnail_path if img_b.thumbnail_path and Path(img_b.thumbnail_path).exists() else img_b.original_path
        try:
            with PILImage.open(path_a) as pil_a, PILImage.open(path_b) as pil_b:
                # Numpy arrays instead of Python lists — 10-50x faster intersection
                hist_a = np.array(pil_a.convert('RGB').histogram(), dtype=np.float64)
                hist_b = np.array(pil_b.convert('RGB').histogram(), dtype=np.float64)

                sum_a = hist_a.sum()
                sum_b = hist_b.sum()
                if sum_a == 0 or sum_b == 0:
                    return 0.0

                hist_a /= sum_a
                hist_b /= sum_b

                return float(np.minimum(hist_a, hist_b).sum())
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
                
                # Optimization: Resize to a small fixed size to make SSIM extremely fast.
                # SSIM on large images across thousands of pairs is a huge bottleneck.
                target_size = (64, 64)
                gray_a = gray_a.resize(target_size, PILImage.Resampling.BILINEAR)
                gray_b = gray_b.resize(target_size, PILImage.Resampling.BILINEAR)
                
                np_a = np.array(gray_a)
                np_b = np.array(gray_b)
                
                # data_range=255 is important for 8-bit grayscale arrays
                score, _ = ssim(np_a, np_b, full=True, data_range=255)
                # Return RAW score (no normalization)
                return float(score)
                
        except Exception as e:
            logger.error(f"SSIM computation failed: {e}")
            return -1.0
