# Models package — SQLAlchemy ORM models
# All models must be imported here so Base.metadata.create_all() discovers them.
from .image import Image
from .scan_session import ScanSession
from .group import Group
from .group_member import GroupMember
from .trash_record import TrashRecord
from .person import Person
from .face import Face
