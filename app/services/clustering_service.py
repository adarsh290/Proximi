import numpy as np
from sqlalchemy.orm import Session
from app.utils.logger import logger
from app.database.connection import db
from app.models.face import Face
from app.models.person import Person

class ClusteringService:
    """Handles grouping of face embeddings into unique people using ML clustering."""
    
    def __init__(self, eps=1.0, min_samples=2):
        # eps = 1.0 is a good starting point for normalized Euclidean distance
        # on insightface antelopev2 embeddings
        self.eps = eps
        self.min_samples = min_samples
        self._is_initialized = False
        
    def _init_model(self):
        if self._is_initialized:
            return True
            
        try:
            from sklearn.cluster import DBSCAN
            self.DBSCAN = DBSCAN
            self._is_initialized = True
            return True
        except ImportError:
            logger.error("scikit-learn is not installed.")
            return False

    def cluster_faces(self):
        """Run DBSCAN clustering on all faces and recreate Person groupings.
        
        Note: This is a full re-clustering approach. For very large datasets,
        incremental clustering (or Chinese Whispers) would be better, but DBSCAN
        is perfectly fine for a few thousand faces.
        """
        if not self._init_model():
            return
            
        session: Session = db.SessionLocal()
        try:
            faces = session.query(Face).all()
            if len(faces) < 2:
                logger.info("Not enough faces to cluster.")
                return
                
            embeddings = []
            face_ids = []
            for face in faces:
                emb = np.frombuffer(face.embedding, dtype=np.float32)
                embeddings.append(emb)
                face_ids.append(face.id)
                
            X = np.array(embeddings)
            
            logger.info(f"Running DBSCAN clustering on {len(X)} faces...")
            clustering = self.DBSCAN(eps=self.eps, min_samples=self.min_samples, metric='euclidean').fit(X)
            labels = clustering.labels_
            
            unique_labels = set(labels)
            
            # Simple strategy: Clear existing people and rebuild to avoid complex merge logic
            # (In production with user-renamed people, we'd need stable clustering)
            session.query(Person).delete()
            session.query(Face).update({"person_id": None}, synchronize_session=False)
            session.commit()
            
            person_count = 0
            for label in unique_labels:
                if label == -1:
                    continue  # -1 means DBSCAN marked it as noise (no cluster)
                    
                person_count += 1
                person = Person(name=f"Person {person_count}")
                session.add(person)
                session.flush()  # Get person.id
                
                # Assign faces to this person
                person_face_ids = [face_ids[i] for i, l in enumerate(labels) if l == label]
                session.query(Face).filter(Face.id.in_(person_face_ids)).update(
                    {"person_id": person.id}, synchronize_session=False
                )
                
                # Set the first face as the profile picture
                person.profile_face_id = person_face_ids[0]
                
            session.commit()
            logger.info(f"Clustering complete. Grouped {len(faces)} faces into {person_count} people.")
            
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to cluster faces: {e}")
        finally:
            session.close()
