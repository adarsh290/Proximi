from app.database.connection import db
db.initialize_database()

from app.database.group_repository import GroupRepository
from app.database.image_repository import ImageRepository
from app.services.similarity_service import SimilarityService
from app.services.grouping_service import GroupingService
import logging

logging.basicConfig(level=logging.DEBUG)

image_repo = ImageRepository()
group_repo = GroupRepository()

sim_service = SimilarityService(image_repo)
group_service = GroupingService(group_repo)

print("Clearing groups...")
group_repo.clear_groups()

print("Finding pairs...")
pairs = sim_service.find_similar_pairs(candidate_threshold=7)

print("Generating groups...")
count = group_service.generate_groups(pairs, session_id=1)

print(f"Total pairs found: {len(pairs)}")
print(f"Total groups created: {count}")
