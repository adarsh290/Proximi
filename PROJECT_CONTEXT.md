# Proximi Project Context

## Current Milestone
**Milestone 3 — Similarity Engine & Grouping System**
Focus: CPU-bound classical CV pipeline (pHash/dHash), SSIM refinement, NetworkX connected-components grouping, similarity background worker, and GroupReview UI.

## Architecture Overview
- **UI:** Qt Quick / QML
- **Backend Bridge:** PySide6
- **Database:** SQLite
- **ORM:** SQLAlchemy
- **Thumbnail Engine:** Pillow
- **Async Pattern:** QThreadPool + QRunnable
- **Pattern:** Layered architecture (UI -> Controllers -> Services -> Database/Repository)

- Python 3
- PySide6
- SQLAlchemy
- QML
- Pillow
- imagehash
- scikit-image
- networkx
- scipy & numpy

## Folder Structure
- `app/ui/qml/`: QML UI components and themes
- `app/ui/qml/components/`: Reusable QML components (TopBar, Sidebar, ContentArea, Footer, ImageCard, EmptyState, LoadingView)
- `app/ui/qml/themes/`: Theme singleton (colors, spacing, typography, grid tokens)
- `app/controllers/`: QObject bridges between QML and Python services
- `app/services/`: Business logic — scanning, thumbnails, settings
- `app/database/`: SQLite connection, repository layer
- `app/models/`: SQLAlchemy ORM models (Image, ScanSession)
- `app/utils/`: Utilities (logging)
- `data/`: Local storage (thumbnails, trash, cache, logs, db)

## Coding Standards
- Python: Type hints, meaningful naming, composition over inheritance, isolated logic.
- QML: Presentation logic only, reusable components, clean layouts.
- Architecture: No global state, QML talks to Python via QObject/Signals/Slots.
- Controllers: Modular — ScanController handles scan lifecycle, AppController stays lightweight.

## Agent Rules
- QML files must contain presentation/UI logic ONLY.
- Python backend handles state, logic, and db operations.
- Do not overengineer (no DI frameworks, plugin systems, Redux-like systems).
- Evolve incrementally.
- Do not create directories/modules until they are needed by the current milestone.

## Database Tables

### images
| Column | Type | Notes |
|--------|------|-------|
| id | Integer | PK, autoincrement |
| original_path | String | unique, indexed |
| file_name | String | |
| extension | String | |
| width | Integer | nullable |
| height | Integer | nullable |
| file_size | Integer | |
| created_at | DateTime | auto |
| modified_at | DateTime | file mtime |
| thumbnail_path | String | nullable |
| scan_session_id | Integer | FK → scan_sessions |
| phash | String | nullable, imagehash |
| dhash | String | nullable, imagehash |
| hash_computed_at | DateTime | nullable |

### groups
| Column | Type | Notes |
|--------|------|-------|
| id | Integer | PK, autoincrement |
| group_type | String | 'similar' or 'burst' |
| similarity_score | Float | |
| created_at | DateTime | |
| scan_session_id | Integer | FK → scan_sessions |
| version | Integer | Default 1 |
| representative_image_id | Integer | FK → images |

### group_members
| Column | Type | Notes |
|--------|------|-------|
| id | Integer | PK, autoincrement |
| group_id | Integer | FK → groups |
| image_id | Integer | FK → images |
| added_at | DateTime | |

### scan_sessions
| Column | Type | Notes |
|--------|------|-------|
| id | Integer | PK, autoincrement |
| folder_path | String | |
| started_at | DateTime | auto |
| completed_at | DateTime | nullable |
| images_found | Integer | default 0 |
| status | String | in_progress/completed/failed |

## Services

### ScanService
- Recursive image discovery (.jpg, .jpeg, .png, .webp)
- Pipeline order: discovery → metadata → DB persist → thumbnail gen → UI update
- Progress reporting via callbacks
- Cancellation-aware loop (checks is_cancelled before each image)

### ThumbnailService
- Pillow-based thumbnail generation (max 256px, LANCZOS)
- Deterministic cache keys: SHA256(normalized_path + mtime)
- Cached to `data/thumbnails/` as WEBP (optimized format)
- Cache validation via path + mtime hash

### HashService
- Computes perceptual hashes (pHash, dHash) using `imagehash`.
- Processes incrementally (only unhashed images).

### SimilarityService
- Candidate filtering using pHash Hamming distance (threshold <= 7).
- Refinement scoring using SSIM via `scikit-image`.

### GroupingService
- Builds an adjacency graph of candidates using `networkx`.
- Clusters via connected components and persists groups (min size 2).
- Assigns group representative node based on cluster centrality.

### ScanWorker & SimilarityWorker (QRunnable)
- Run async logic on QThreadPool.
- Emit signals for progress tracking and UI updates.
- Support cancellation patterns.

## Controllers

### ScanController
- Folder selection (native QFileDialog)
- Scan lifecycle management
- ImageViewModel transformation layer (path → URI conversion)
- Properties: currentFolder, scanState, scanProgress, scannedCount, totalImages
- Signals: imageReady, scanFinished

### SimilarityController
- Exposes `similarityState`, `currentPhase`, `progress`, `groupCount`, `currentGroupIndex`.
- UI bridge for launching the similarity pipeline.
- Exposes formatted group and image view-models to `GroupReviewView`.

### DebugController
- Toggle visibility (Ctrl+Shift+D)
- Exposes pre-computed metric snapshot to QML
- No raw DB models leak into QML

### AppController
- General app status (lightweight)

### SettingsController
- Theme management

## Debug Panel
- **Toggle:** `Ctrl+Shift+D`
- **Location:** Docked overlay on right edge of content area
- **Refresh:** 1.5s Timer, only when visible
- **Metrics Exposed:**
  - Scan: status, folder, scanned/total/skipped/failed, duration, throughput, session ID
  - Thumbnails: generated, cache hits, cache misses, failures
  - Workers: active count, cancellation state
  - Database: total images, sessions, cached thumbnails
  - Runtime: RAM usage (via psutil)

## Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+D | Toggle debug panel |

## Completed Features
- Project structure creation
- SQLite initialization setup
- QML application shell (Main, Sidebar, TopBar, Footer, ContentArea)
- Folder preparation routines
- Basic controller and service layer
- Native folder selection dialog
- Recursive image scanning (async via QThreadPool)
- Thumbnail generation and caching (Pillow, WEBP, SHA256)
- SQLite metadata persistence (images + scan_sessions tables)
- Progressive thumbnail grid (GridView with clip)
- Empty/Loading/Loaded UI states
- ImageViewModel layer (filesystem path → file URI conversion)
- Internal debug panel with runtime metrics
- Migration script structure to update DB schema (ALTER TABLE).
- Group and Hash database schema expansions.
- Classical CV Similarity Pipeline (pHash, dHash, SSIM refinement).
- Graph-based clustering (connected components via NetworkX).
- UI Integration (SimilarityProcessingView, GroupReviewView).

## Pending Features
- Milestone 4: TBD (Likely image manipulation/deduplication actions, UI cleanup)

## Known Issues
- None yet.

## Next Planned Milestone
- TBD (Actions/Deduplication)
