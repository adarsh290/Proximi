from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database.base import Base

class TrashRecord(Base):
    """Represents a file that has been moved to the app-managed trash."""
    __tablename__ = "trash_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    original_path = Column(String, nullable=False)
    trash_path = Column(String, nullable=False, unique=True)
    deleted_at = Column(DateTime, default=func.now())
    restored_at = Column(DateTime, nullable=True)
    
    # Relationships to existing entities
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="SET NULL"), nullable=True)
    scan_session_id = Column(Integer, ForeignKey("scan_sessions.id", ondelete="CASCADE"), nullable=False)
    image_id = Column(Integer, ForeignKey("images.id", ondelete="SET NULL"), nullable=True)
    
    # Used for batch undo operations (e.g. undoing a "clean group" action that moved 3 files)
    batch_id = Column(String, nullable=False, index=True)

    # Relationships
    group = relationship("Group")
    scan_session = relationship("ScanSession")
    image = relationship("Image")

    def __repr__(self) -> str:
        return f"<TrashRecord(id={self.id}, original='{self.original_path}', batch='{self.batch_id}')>"
