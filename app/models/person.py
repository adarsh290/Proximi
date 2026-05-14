from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from app.database.base import Base


class Person(Base):
    """Represents a unique identified person grouped via facial clustering."""
    __tablename__ = "people"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, default="Unknown", nullable=False)
    profile_face_id = Column(Integer, ForeignKey("faces.id", use_alter=True, name="fk_person_profile_face"), nullable=True)

    # Relationships
    faces = relationship("Face", back_populates="person", primaryjoin="Person.id == Face.person_id")
    profile_face = relationship("Face", foreign_keys=[profile_face_id], post_update=True)

    def __repr__(self) -> str:
        return f"<Person(id={self.id}, name='{self.name}')>"
