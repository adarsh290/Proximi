from PySide6.QtCore import QObject, Signal, Slot, QRunnable, QThreadPool
from pathlib import Path
from app.utils.logger import logger
from app.database.connection import db
from app.models.image import Image
from app.models.face import Face
from app.services.face_service import FaceService
from app.services.clustering_service import ClusteringService

class FaceScanWorker(QRunnable):
    """Background worker to extract faces and cluster them without freezing the UI."""
    
    class Signals(QObject):
        progress = Signal(int, int)  # current, total
        finished = Signal()
        error = Signal(str)
        statusText = Signal(str)

    def __init__(self, image_ids: list[int]):
        super().__init__()
        self.image_ids = image_ids
        self.signals = self.Signals()
        self.face_service = FaceService()
        self.clustering_service = ClusteringService()

    def run(self):
        try:
            self.signals.statusText.emit("Initializing ML Models...")
            # Init early to fail fast if missing deps
            if not self.face_service._init_model():
                self.signals.error.emit("ML dependencies not found. Run pip install insightface onnxruntime-gpu")
                return

            session = db.SessionLocal()
            total = len(self.image_ids)
            
            try:
                for i, img_id in enumerate(self.image_ids):
                    self.signals.progress.emit(i, total)
                    self.signals.statusText.emit(f"Scanning face {i}/{total}")
                    
                    # Check if already scanned (we could track this in DB, but for MVP we just delete old faces for this image)
                    img = session.query(Image).filter(Image.id == img_id).first()
                    if not img or not img.original_path:
                        continue
                        
                    # Delete existing faces for this image to prevent duplicates on rescan
                    session.query(Face).filter(Face.image_id == img.id).delete()
                    
                    # Detect faces
                    results = self.face_service.detect_and_extract_faces(img.original_path)
                    
                    for res in results:
                        l, t, r, b = res['bbox']
                        face = Face(
                            image_id=img.id,
                            bbox_left=l,
                            bbox_top=t,
                            bbox_right=r,
                            bbox_bottom=b,
                            embedding=res['embedding'],
                            face_crop_path=res['crop_path']
                        )
                        session.add(face)
                        
                    session.commit()
                    
                self.signals.statusText.emit("Clustering faces...")
                self.clustering_service.cluster_faces()
                
                self.signals.finished.emit()
            finally:
                session.close()
                
        except Exception as e:
            logger.error(f"Face scan worker error: {e}")
            self.signals.error.emit(str(e))


class FaceController(QObject):
    """QML interface for face detection and clustering operations."""
    
    scanStarted = Signal()
    scanProgressChanged = Signal()
    scanFinished = Signal()
    scanError = Signal(str)
    statusTextChanged = Signal()

    def __init__(self):
        super().__init__()
        self._thread_pool = QThreadPool.globalInstance()
        self._is_scanning = False
        self._progress_current = 0
        self._progress_total = 0
        self._status_text = ""

    # ── Properties ────────────────────────────────────────────────────────

    @property
    def isScanning(self) -> bool:
        return self._is_scanning

    @property
    def progressCurrent(self) -> int:
        return self._progress_current

    @property
    def progressTotal(self) -> int:
        return self._progress_total

    @property
    def statusText(self) -> str:
        return self._status_text

    def _set_is_scanning(self, val: bool):
        if self._is_scanning != val:
            self._is_scanning = val
            self.scanStarted.emit() if val else self.scanFinished.emit()

    def _set_status(self, text: str):
        if self._status_text != text:
            self._status_text = text
            self.statusTextChanged.emit()

    # ── Slots ─────────────────────────────────────────────────────────────

    @Slot()
    def startFaceScan(self):
        """Starts the background face scan on all available images."""
        if self._is_scanning:
            return
            
        session = db.SessionLocal()
        try:
            # For MVP, just rescan all images. In prod, filter by a 'faces_scanned' flag
            images = session.query(Image.id).all()
            image_ids = [img.id for img in images]
        finally:
            session.close()
            
        if not image_ids:
            self.scanError.emit("No images to scan.")
            return

        self._set_is_scanning(True)
        self._progress_current = 0
        self._progress_total = len(image_ids)
        self._set_status("Starting face scan...")
        self.scanProgressChanged.emit()
        
        worker = FaceScanWorker(image_ids)
        worker.signals.progress.connect(self._on_progress)
        worker.signals.statusText.connect(self._set_status)
        worker.signals.finished.connect(self._on_finished)
        worker.signals.error.connect(self._on_error)
        
        self._thread_pool.start(worker)

    def _on_progress(self, current: int, total: int):
        self._progress_current = current
        self._progress_total = total
        self.scanProgressChanged.emit()

    def _on_finished(self):
        self._set_is_scanning(False)
        self._set_status("Scan complete.")

    def _on_error(self, err_msg: str):
        self._set_is_scanning(False)
        self._set_status(f"Error: {err_msg}")
        self.scanError.emit(err_msg)

    @Slot(result="QVariantList")
    def getPeople(self):
        """Returns a list of clustered people with their profile pictures."""
        session = db.SessionLocal()
        try:
            from app.models.person import Person
            from app.models.face import Face
            
            people = session.query(Person).all()
            results = []
            for p in people:
                pfp_path = ""
                if p.profile_face_id:
                    face = session.query(Face).filter(Face.id == p.profile_face_id).first()
                    if face and face.face_crop_path:
                        pfp_path = Path(face.face_crop_path).resolve().as_uri()
                        
                # Also count how many faces belong to this person
                face_count = session.query(Face).filter(Face.person_id == p.id).count()
                
                results.append({
                    "personId": p.id,
                    "name": p.name,
                    "profilePath": pfp_path,
                    "faceCount": face_count
                })
            
            # Sort by face count descending
            results.sort(key=lambda x: x["faceCount"], reverse=True)
            return results
        except Exception as e:
            logger.error(f"Failed to fetch people: {e}")
            return []
        finally:
            session.close()
