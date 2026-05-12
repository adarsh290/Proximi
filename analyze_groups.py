from app.database.connection import db
from app.database.group_repository import GroupRepository
from app.models.group import Group

db.initialize_database()
session = db.SessionLocal()
groups = session.query(Group).all()

total_groups = len(groups)
sizes = [len(g.members) for g in groups]
avg_size = sum(sizes) / total_groups if total_groups > 0 else 0
max_size = max(sizes) if sizes else 0

print(f"Total groups: {total_groups}")
print(f"Average group size: {avg_size:.2f}")
print(f"Max group size: {max_size}")

# Check burst vs similar
burst_count = sum(1 for g in groups if g.group_type == "burst")
similar_count = sum(1 for g in groups if g.group_type == "similar")
print(f"Burst groups: {burst_count}")
print(f"Similar groups: {similar_count}")

# Print a few random groups with sizes
for i in range(min(5, total_groups)):
    g = groups[i]
    print(f"Group {g.id}: size {len(g.members)}, score {g.similarity_score:.3f}, type {g.group_type}")
