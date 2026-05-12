import sys
import os
from pathlib import Path

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication  # Needed for QFileDialog

from app.utils.logger import logger
from app.services.folder_service import FolderService
from app.services.settings_service import SettingsService
from app.services.thumbnail_service import ThumbnailService
from app.services.scan_service import ScanService
from app.services.debug_service import DebugService
from app.database.connection import db
from app.database.image_repository import ImageRepository
from app.controllers.app_controller import AppController
from app.controllers.settings_controller import SettingsController
from app.controllers.scan_controller import ScanController
from app.controllers.debug_controller import DebugController
from app.controllers.similarity_controller import SimilarityController
from app.services.hash_service import HashService
from app.services.similarity_service import SimilarityService
from app.services.grouping_service import GroupingService
from app.database.group_repository import GroupRepository

def main():
    # 1. Initialize environment and folders
    folder_service = FolderService()
    folder_service.ensure_data_directories()
    
    # 2. Initialize Database
    from app.database.migration import run_migrations
    run_migrations()
    db.initialize_database()
    
    # 3. Setup Application
    # Using QApplication (not QGuiApplication) to support QFileDialog
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # Add themes directory to import paths for the pragma Singleton
    ui_dir = Path(__file__).parent / "app" / "ui" / "qml"
    engine.addImportPath(str(ui_dir))

    # 4. Initialize Services
    settings_service = SettingsService()
    image_repository = ImageRepository()
    group_repository = GroupRepository()
    debug_service = DebugService(image_repository)
    thumbnail_service = ThumbnailService(debug_service=debug_service)
    scan_service = ScanService(image_repository, thumbnail_service, debug_service=debug_service)
    
    hash_service = HashService(image_repository, debug_service)
    sim_service = SimilarityService(image_repository, debug_service)
    grouping_service = GroupingService(group_repository, debug_service)
    
    # 5. Initialize Controllers
    app_controller = AppController()
    settings_controller = SettingsController(settings_service)
    scan_controller = ScanController(scan_service, image_repository, debug_service)
    debug_controller = DebugController(debug_service)
    similarity_controller = SimilarityController(
        hash_service, 
        sim_service, 
        grouping_service, 
        group_repository, 
        debug_service
    )
    
    # 6. Register context properties (Python -> QML bridge)
    context = engine.rootContext()
    context.setContextProperty("appController", app_controller)
    context.setContextProperty("settingsController", settings_controller)
    context.setContextProperty("scanController", scan_controller)
    context.setContextProperty("debugController", debug_controller)
    context.setContextProperty("similarityController", similarity_controller)
    
    # 7. Load QML
    main_qml = ui_dir / "Main.qml"
    engine.load(os.fspath(main_qml))
    
    if not engine.rootObjects():
        logger.error("Failed to load QML.")
        sys.exit(-1)
        
    logger.info("Proximi started successfully.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
