from typing import List
from app.database.connection import db
from app.models.group import Group
from app.models.group_member import GroupMember
from app.models.image import Image
from app.utils.logger import logger

class GroupRepository:
    """Handles persistence of similarity groups."""

    def create_group(self, group_type: str, similarity_score: float, session_id: int, version: int = 1) -> Group:
        session = db.SessionLocal()
        try:
            group = Group(
                group_type=group_type,
                similarity_score=similarity_score,
                scan_session_id=session_id,
                version=version
            )
            session.add(group)
            session.commit()
            session.refresh(group)
            return group
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to create group: {e}")
            raise
        finally:
            session.close()

    def add_members_and_set_representative(self, group_id: int, image_ids: List[int], representative_id: int) -> None:
        session = db.SessionLocal()
        try:
            # Add members
            for img_id in image_ids:
                member = GroupMember(group_id=group_id, image_id=img_id)
                session.add(member)
                
            # Set representative
            group = session.query(Group).filter(Group.id == group_id).first()
            if group:
                group.representative_image_id = representative_id
                
            session.commit()
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to add members to group {group_id}: {e}")
            raise
        finally:
            session.close()

    def get_all_groups(self) -> List[Group]:
        """Returns all groups eager-loaded with their members and representative image."""
        session = db.SessionLocal()
        try:
            from sqlalchemy.orm import joinedload
            groups = session.query(Group)\
                .options(joinedload(Group.members).joinedload(GroupMember.image))\
                .options(joinedload(Group.representative_image))\
                .all()
            return groups
        finally:
            session.expunge_all()
            session.close()

    def get_group_count(self) -> int:
        session = db.SessionLocal()
        try:
            return session.query(Group).count()
        finally:
            session.close()

    def clear_groups(self) -> None:
        """Clear all existing groups before re-evaluating similarity."""
        session = db.SessionLocal()
        try:
            session.query(Group).delete()
            session.query(GroupMember).delete()
            session.commit()
        except Exception as e:
            session.rollback()
            logger.error(f"Failed to clear groups: {e}")
        finally:
            session.close()
