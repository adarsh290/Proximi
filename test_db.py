from app.database.connection import db
db.init_db("proximi.db")

from app.database.group_repository import GroupRepository
import logging
logging.basicConfig(level=logging.DEBUG)

repo = GroupRepository()
groups = repo.get_all_groups()
print(f"Total groups: {len(groups)}")
if groups:
    group = groups[0]
    print(f"Group 0 has {len(group.members)} members")
    try:
        for member in group.members:
            print(f"Member: {member}, Image: {member.image}")
    except Exception as e:
        print(f"Error accessing image: {e}")
