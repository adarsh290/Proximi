# Architecture Review: Milestone 3 (Similarity Engine & Grouping System)

## Objective
To implement a robust, local-first similarity detection and grouping system for Proximi without relying on deep learning, external APIs, or GPU acceleration.

## Core Architecture Decisions

### 1. Phased Similarity Pipeline
We implemented a multi-stage approach to balance accuracy and performance:
1. **Hashing Phase:** Computes `pHash` and `dHash` using Pillow and ImageHash. Thumbnails are prioritized over original images to minimize I/O and processing time.
2. **Candidate Filtering Phase (Stage 1):** O(N²) comparison using pHash Hamming Distance. We reduced the default threshold to `7` to act as a strict pre-filter and prevent unrelated images from advancing.
3. **Refinement Phase (Stage 2):** SSIM (Structural Similarity Index) via `scikit-image` is applied only to ambiguous matches (Hamming distance 5-7). Exact/near-exact matches (0-4) bypass SSIM entirely for performance.

### 2. Graph-Based Clustering
Instead of simple pairwise linking, we treat similarity pairs as edges in an undirected graph using `networkx`. 
- **Connected Components:** Clusters are identified by extracting connected components.
- **Singletons:** Subgraphs with fewer than 2 nodes are discarded (as per Milestone 3 constraints).
- **Representative Node:** We select the node with the highest degree/centrality within the cluster (highest sum of similarity weights) to serve as the stable thumbnail/representative image for the group.

### 3. Database Schema Evolution
- Implemented a lightweight, startup-safe `ALTER TABLE` migration system in `migration.py` to add `phash`, `dhash`, and `hash_computed_at` columns without wiping user data.
- Created `groups` and `group_members` tables.
- Added `version` tracking to groups to allow future algorithmic invalidation.

### 4. Background Processing (QRunnable)
- Extended the `QThreadPool` pattern used in scanning to the similarity engine via `SimilarityWorker`.
- Ensures the UI remains entirely responsive during the O(N²) comparison phase.
- Signals provide real-time updates (phase, progress) to the `SimilarityProcessingView`.

### 5. View-Model Separation
- Raw SQLAlchemy objects are isolated from the QML presentation layer.
- `SimilarityController` transforms SQLAlchemy objects into standard Python dictionaries containing formatted `ImageViewModel` properties before exposing them to the `GroupReviewView`.

## Future Considerations
- Optimization of the O(N²) Hamming distance loop using Vantage Point (VP) Trees or BK-Trees as the repository grows.
- Integration of timestamp data to better classify clusters into "bursts" vs. "visually similar".
- Deduplication resolution workflows.
