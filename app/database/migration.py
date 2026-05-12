import sqlite3
from pathlib import Path
from app.utils.logger import logger

def run_migrations(db_path_str: str = "data/proximi.db"):
    """
    Lightweight startup migration script.
    Checks schema and applies ALTER TABLE statements if columns are missing.
    """
    db_path = Path(db_path_str)
    if not db_path.exists():
        # Database hasn't been created yet, SQLAlchemy will create it with the full schema.
        return

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if 'phash' exists in 'images' table
        cursor.execute("PRAGMA table_info(images)")
        columns = [row[1] for row in cursor.fetchall()]

        if "phash" not in columns:
            logger.info("Running DB migration: Adding 'phash', 'dhash', 'hash_computed_at' to 'images' table.")
            cursor.execute("ALTER TABLE images ADD COLUMN phash VARCHAR")
            cursor.execute("ALTER TABLE images ADD COLUMN dhash VARCHAR")
            cursor.execute("ALTER TABLE images ADD COLUMN hash_computed_at DATETIME")
            
            # Create indexes for the new columns
            cursor.execute("CREATE INDEX ix_images_phash ON images (phash)")
            cursor.execute("CREATE INDEX ix_images_dhash ON images (dhash)")
            
            conn.commit()
            logger.info("DB migration completed successfully.")
        
    except Exception as e:
        logger.error(f"Failed to run migrations: {e}")
    finally:
        if 'conn' in locals() and conn:
            conn.close()
