import os
import uuid
import numpy as np
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import threading

from app.utils.logger import logger


class FaceService:
    """Service to handle facial detection and embedding extraction using InsightFace."""
    
    BATCH_SIZE = 8
    
    def __init__(self, cache_dir: str = "data/faces"):
        self.cache_dir = Path(cache_dir).resolve()
        self._app = None
        self._is_initialized = False
        self._lock = threading.Lock()
        
    def _init_model(self):
        """Lazy initialization of the ML models to prevent startup lag and handle missing dependencies."""
        if self._is_initialized:
            return self._app is not None
            
        with self._lock:
            if self._is_initialized:
                return self._app is not None

            self.cache_dir.mkdir(parents=True, exist_ok=True)
            try:
                import insightface
                from insightface.app import FaceAnalysis
                
                # Initialize model. Tries CUDA first, falls back to CPU.
                self._app = FaceAnalysis(name='buffalo_l', providers=['CUDAExecutionProvider', 'CPUExecutionProvider'])
                self._app.prepare(ctx_id=0, det_size=(640, 640))
                self._is_initialized = True
                logger.info("InsightFace model initialized successfully.")
                return True
            except ImportError:
                self._is_initialized = True
                logger.error("ML dependencies (insightface/onnxruntime) are not installed.")
                return False
            except Exception as e:
                self._is_initialized = True
                import traceback
                logger.error(f"Failed to initialize insightface:\n{traceback.format_exc()}")
                return False

    def detect_and_extract_faces(self, image_path: str) -> List[Dict]:
        """Detect faces, extract embeddings, crop the face, and save to cache.
        
        Returns:
            A list of dicts: {'bbox': (l, t, r, b), 'embedding': bytes, 'crop_path': str}
        """
        if not self._init_model():
            return []
            
        import cv2
        
        try:
            img = cv2.imread(image_path)
            if img is None:
                logger.warning(f"Failed to read image for face detection: {image_path}")
                return []
            return self.detect_faces_from_array(img, image_path)
        except Exception as e:
            logger.error(f"Error extracting faces from {image_path}: {e}")
            return []

    def detect_faces_from_array(self, img: np.ndarray, image_path: str) -> List[Dict]:
        """Detect faces from a pre-loaded OpenCV image array.
        
        This method separates GPU inference from disk I/O, enabling the caller
        to pre-load images on a background thread while the GPU processes the
        current one (pipeline parallelism).
        
        Args:
            img: A BGR numpy array (as returned by cv2.imread).
            image_path: Original path, used only for logging.
            
        Returns:
            A list of dicts: {'bbox': (l, t, r, b), 'embedding': bytes, 'crop_path': str}
        """
        if not self._init_model():
            return []

        import cv2

        try:
            faces = self._app.get(img)
            results = []
            
            for face in faces:
                bbox = face.bbox.astype(int)
                embedding = face.normed_embedding  # 512-d normalized float32 array
                
                # Crop face with some padding (20%)
                l, t, r, b = bbox
                h, w = img.shape[:2]
                pad_w = int((r - l) * 0.2)
                pad_h = int((b - t) * 0.2)
                
                # Ensure bounds are within image
                l_pad = max(0, l - pad_w)
                t_pad = max(0, t - pad_h)
                r_pad = min(w, r + pad_w)
                b_pad = min(h, b + pad_h)
                
                crop = img[t_pad:b_pad, l_pad:r_pad]
                
                if crop.size == 0:
                    continue
                    
                # Save crop as thumbnail for UI
                crop_filename = f"{uuid.uuid4().hex}.jpg"
                crop_path = self.cache_dir / crop_filename
                cv2.imwrite(str(crop_path), crop)
                
                results.append({
                    'bbox': (int(l), int(t), int(r), int(b)),
                    'embedding': embedding.tobytes(),
                    'crop_path': str(crop_path)
                })
                
            return results
        except Exception as e:
            logger.error(f"Error extracting faces from {image_path}: {e}")
            return []

    def detect_faces_batch(self, image_items: List[Tuple[np.ndarray, str]]) -> List[List[Dict]]:
        """Process a batch of images concurrently to maximize GPU utilization.
        
        Uses ThreadPoolExecutor because InsightFace's Python API handles concurrent 
        ONNXRuntime requests efficiently, effectively batching them on the GPU
        without requiring manual 4D tensor stacking and custom preprocessing.
        """
        if not self._init_model():
            return [[] for _ in image_items]
            
        results = [[] for _ in image_items]
        
        from concurrent.futures import ThreadPoolExecutor
        
        def _process_one(idx, img, path):
            try:
                if img is None:
                    return idx, []
                return idx, self.detect_faces_from_array(img, path)
            except Exception as e:
                logger.error(f"Error processing batch item {path}: {e}")
                return idx, []
                
        with ThreadPoolExecutor(max_workers=self.BATCH_SIZE) as executor:
            futures = [executor.submit(_process_one, i, item[0], item[1]) for i, item in enumerate(image_items)]
            for future in futures:
                idx, res = future.result()
                results[idx] = res
                
        return results

