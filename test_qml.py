import sys
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
import os

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()

def print_warn(warnings):
    for w in warnings:
        print('QML WARN:', w.toString())

engine.warnings.connect(print_warn)
engine.addImportPath(str(Path('app/ui/qml').absolute()))
engine.load(str(Path('app/ui/qml/Main.qml').absolute()))
print("Loaded. Root objects:", len(engine.rootObjects()))
