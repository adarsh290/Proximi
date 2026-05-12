from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.database.connection import db
from app.models.image import Image
from app.models.scan_session import ScanSession
from app.utils.logger import logger


class ImageRepository:
    """Handles all database operations for images and scan sessions."""

    # ── Scan Session Operations ───────────────────────────────────────

    def create_scan_session(self, folder_path: str) -> int:
        """Creates a new scan session and returns its ID."""
        session: Session = db.SessionLocal()
        try:
            scan_session = ScanSession(folder_path=folder_path)
            session.add(scan_session)
            session.commit()
            session_id = scan_session.id
            logger.info(f"Created scan session {session_id} for '{folder_path}'")
            return session_id
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to create scan session: {e}")
            raise
        finally:
            session.close()

    def complete_scan_session(self, session_id: int, images_found: int) -> None:
        """Marks a scan session as completed."""
        session: Session = db.SessionLocal()
        try:
            scan_session = session.query(ScanSession).filter_by(id=session_id).first()
            if scan_session:
                scan_session.completed_at = datetime.now()
                scan_session.images_found = images_found
                scan_session.status = "completed"
                session.commit()
                logger.info(f"Completed scan session {session_id}: {images_found} images")
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to complete scan session {session_id}: {e}")
        finally:
            session.close()

    def fail_scan_session(self, session_id: int, error_msg: str) -> None:
        """Marks a scan session as failed."""
        session: Session = db.SessionLocal()
        try:
            scan_session = session.query(ScanSession).filter_by(id=session_id).first()
            if scan_session:
                scan_session.completed_at = datetime.now()
                scan_session.status = "failed"
                session.commit()
                logger.error(f"Scan session {session_id} failed: {error_msg}")
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to update scan session {session_id}: {e}")
        finally:
            session.close()

    # ── Image Operations ──────────────────────────────────────────────

    def upsert_image(self, image_data: dict) -> Optional[Image]:
        """Insert a new image or update if the path already exists.
        
        Args:
            image_data: Dict with keys matching Image model columns.
                        Must include 'original_path'.
        
        Returns:
            The Image instance, or None on failure.
        """
        session: Session = db.SessionLocal()
        try:
            original_path = image_data["original_path"]
            existing = session.query(Image).filter_by(original_path=original_path).first()

            if existing:
                # Update mutable fields
                for key in ("file_size", "modified_at", "thumbnail_path",
                            "width", "height", "scan_session_id"):
                    if key in image_data:
                        setattr(existing, key, image_data[key])
                session.commit()
                session.refresh(existing)
                return existing
            else:
                image = Image(**image_data)
                session.add(image)
                session.commit()
                session.refresh(image)
                return image
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to upsert image '{image_data.get('original_path')}': {e}")
            return None
        finally:
            session.close()

    def get_image_by_path(self, path: str) -> Optional[Image]:
        """Retrieves a single image record by its original path."""
        session: Session = db.SessionLocal()
        try:
            return session.query(Image).filter_by(original_path=path).first()
        finally:
            session.close()

    def get_all_images(self) -> list:
        """Retrieves all image records ordered by creation time."""
        session: Session = db.SessionLocal()
        try:
            images = session.query(Image).order_by(Image.created_at.desc()).all()
            # Detach from session so they can be used outside
            session.expunge_all()
            return images
        finally:
            session.close()

    def get_image_count(self) -> int:
        """Returns the total number of images in the database."""
        session: Session = db.SessionLocal()
        try:
            return session.query(Image).count()
        finally:
            session.close()

    # ── Similarity / Hash Operations ──────────────────────────────────

    def get_images_without_hashes(self) -> list[Image]:
        """Returns images that do not have perceptual hashes computed yet."""
        session: Session = db.SessionLocal()
        try:
            images = session.query(Image).filter(Image.phash.is_(None)).all()
            session.expunge_all()
            return images
        finally:
            session.close()

    def get_all_hashed_images(self) -> list[Image]:
        """Returns all images that have perceptual hashes."""
        session: Session = db.SessionLocal()
        try:
            images = session.query(Image).filter(Image.phash.is_not(None)).all()
            session.expunge_all()
            return images
        finally:
            session.close()

    def update_hashes(self, image_id: int, phash: str, dhash: str) -> None:
        """Updates the perceptual hashes for a specific image."""
        session: Session = db.SessionLocal()
        try:
            image = session.query(Image).filter_by(id=image_id).first()
            if image:
                image.phash = phash
                image.dhash = dhash
                image.hash_computed_at = datetime.now()
                session.commit()
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to update hashes for image {image_id}: {e}")
        finally:
            session.close()
