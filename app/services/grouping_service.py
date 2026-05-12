import networkx as nx
from typing import List, Tuple, Callable

from app.database.group_repository import GroupRepository
from app.utils.logger import logger
from app.services.debug_service import DebugService

class GroupingService:
    """Graph-based clustering for similar images."""
    
    def __init__(self, group_repository: GroupRepository, debug_service: DebugService = None):
        self._group_repository = group_repository
        self._debug_service = debug_service

    def generate_groups(self, 
                        similar_pairs: List[Tuple[int, int, float]], 
                        session_id: int, 
                        on_progress: Callable[[int, int], None] = None,
                        is_cancelled: Callable[[], bool] = None) -> int:
        """
        Creates connected components from pairs and persists them as Groups.
        Returns the number of groups created.
        """
        if not similar_pairs:
            logger.info("No similar pairs found to group.")
            return 0
            
        logger.info(f"Building similarity graph from {len(similar_pairs)} pairs...")
        
        # Build adjacency graph
        G = nx.Graph()
        for img_a, img_b, score in similar_pairs:
            G.add_edge(img_a, img_b, weight=score)
            
        # Find connected components (each component is a cluster/group)
        components = list(nx.connected_components(G))
        total_components = len(components)
        groups_created = 0
        
        logger.info(f"Found {total_components} potential groups.")
        
        for i, comp in enumerate(components):
            if is_cancelled and is_cancelled():
                break
                
            # Filter singletons (Milestone 3 constraint)
            if len(comp) < 2:
                continue
                
            # Calculate average similarity score for the group
            subgraph = G.subgraph(comp)
            edges = subgraph.edges(data=True)
            avg_score = sum(d['weight'] for u, v, d in edges) / max(1, len(edges))
            
            # Simple heuristic for burst vs similar
            # (Could be expanded later with timestamps/dimensions)
            group_type = "burst" if avg_score > 0.9 else "similar"
            
            # Create group and add members
            # Milestone 3 Constraint: Deterministic representative (node with highest degree/centrality, or just first sorted)
            # We'll use the node with the highest sum of weights (most central to the cluster)
            representative_id = max(comp, key=lambda n: sum(d['weight'] for u, v, d in G.edges(n, data=True)))
            
            try:
                # Using similarity version 1
                group = self._group_repository.create_group(
                    group_type=group_type, 
                    similarity_score=avg_score, 
                    session_id=session_id,
                    version=1 
                )
                
                self._group_repository.add_members_and_set_representative(
                    group_id=group.id, 
                    image_ids=list(comp),
                    representative_id=representative_id
                )
                
                groups_created += 1
                if self._debug_service:
                    self._debug_service.similarity_group_created()
                    
            except Exception as e:
                logger.error(f"Failed to persist group for component {comp}: {e}")
                
            if on_progress:
                on_progress(i + 1, total_components)
                
        logger.info(f"Grouping complete: created {groups_created} valid groups.")
        return groups_created
