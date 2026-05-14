from sqlalchemy import Column, Integer, String, LargeBinary, ForeignKey, Float
from sqlalchemy.orm import relationship
from app.database.base import Base


class Face(Base):
    """Represents a specific face crop extracted from an image, along with its ML embedding vector."""
    __tablename__ = "faces"

    id = Column(Integer, primary_key=True, autoincrement=True)
    image_id = Column(Integer, ForeignKey("images.id", ondelete="CASCADE"), nullable=False, index=True)
    person_id = Column(Integer, ForeignKey("people.id", ondelete="SET NULL"), nullable=True, index=True)
    
    # Coordinates of the face in the original image: (left, top, right, bottom)
    bbox_left = Column(Float, nullable=False)
    bbox_top = Column(Float, nullable=False)
    bbox_right = Column(Float, nullable=False)
    bbox_bottom = Column(Float, nullable=False)
    
    # 512-d float32 vector serialized to binary
    embedding = Column(LargeBinary, nullable=False)
    
    # Path to the actual cropped face image (used for QML profiles)
    face_crop_path = Column(String, nullable=False)

    # Relationships
    image = relationship("Image")
    person = relationship("Person", back_populates="faces", primaryjoin="Face.person_id == Person.id")

    def __repr__(self) -> str:
        return f"<Face(id={self.id}, image_id={self.image_id}, person_id={self.person_id})>"
