from sqlalchemy import Column, Integer, ForeignKey
from sqlalchemy.orm import relationship
from app.database.base import Base


class GroupMember(Base):
    """Junction table connecting images to groups."""
    __tablename__ = "group_members"

    id = Column(Integer, primary_key=True, autoincrement=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False)
    image_id = Column(Integer, ForeignKey("images.id", ondelete="CASCADE"), nullable=False)

    # Relationships
    group = relationship("Group", back_populates="members")
    image = relationship("Image", back_populates="group_memberships")

    def __repr__(self) -> str:
        return f"<GroupMember(group_id={self.group_id}, image_id={self.image_id})>"
