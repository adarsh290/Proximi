from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database.base import Base


class Group(Base):
    """Represents a cluster of similar images."""
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True, autoincrement=True)
    group_type = Column(String, nullable=False) # e.g., "similar", "burst"
    similarity_score = Column(Float, nullable=False, default=0.0)
    created_at = Column(DateTime, default=func.now())
    scan_session_id = Column(Integer, ForeignKey("scan_sessions.id"))
    
    # Milestone 3 constraint: stable group preview thumbnail
    representative_image_id = Column(Integer, ForeignKey("images.id"), nullable=True)
    
    # Milestone 3 constraint: similarity algorithm version metadata
    version = Column(Integer, nullable=False, default=1)

    # Relationships
    members = relationship("GroupMember", back_populates="group", cascade="all, delete")
    scan_session = relationship("ScanSession")
    representative_image = relationship("Image", foreign_keys=[representative_image_id])

    def __repr__(self) -> str:
        return f"<Group(id={self.id}, type='{self.group_type}', score={self.similarity_score})>"
