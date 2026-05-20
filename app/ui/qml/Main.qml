import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import themes 1.0
import "components"

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    title: qsTr("Proximi")

    color: Theme.bgApp

    // ── Application State ────────────────────────────────────────────
    property string currentView: "photos" // "photos" or "people"

    // ── Image data model ─────────────────────────────────────────────
    ListModel {
        id: imageListModel
    }

    // ── Connect to ScanController signals ────────────────────────────
    Connections {
        target: typeof scanController !== "undefined" ? scanController : null

        function onScanStarted() {
            imageListModel.clear()
        }

        function onImageReady(imageId, originalPath, thumbnailPath, fileName) {
            imageListModel.append({
                "imageId": imageId,
                "originalPath": originalPath,
                "thumbnailPath": thumbnailPath,
                "fileName": fileName
            })
        }

        function onScanFinished(totalProcessed) {
            console.log("Scan finished: " + totalProcessed + " images")
        }

        function onDuplicateRemovalFinished(removedPaths) {
            console.log("Duplicate removal finished, removed " + removedPaths.length + " exact duplicates.")
            if (removedPaths.length > 0) {
                // Reload the model to reflect the removed images
                imageListModel.clear()
                var images = scanController.getStoredImages()
                for (var i = 0; i < images.length; i++) {
                    imageListModel.append(images[i])
                }
            }
        }
    }

    // ── Startup initialization ───────────────────────────────────────
    Component.onCompleted: {
        // App launches into a clean empty state on startup
        // We do not load stored images automatically
    }

    // ── Keyboard shortcut: Ctrl+Shift+D → toggle debug panel ────────
    Shortcut {
        sequence: "Ctrl+Shift+D"
        onActivated: {
            if (typeof debugController !== "undefined")
                debugController.toggle()
        }
    }

    // ── Global Escape → close fullscreen preview ─────────────────────
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (globalPreviewModal.visible)
                globalPreviewModal.closePreview()
        }
    }

    // ── Layout ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            currentView: root.currentView
            onViewToggled: {
                root.currentView = (root.currentView === "photos") ? "people" : "photos"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Derived state for sidebar visibility
            property bool inGroupReview: typeof similarityController !== "undefined"
                                         && similarityController.similarityState === "ready"

            Sidebar {
                visible: parent.inGroupReview
                Layout.preferredWidth: parent.inGroupReview ? 200 : 0
                Layout.fillHeight: true
            }

            Rectangle {
                visible: parent.inGroupReview
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Theme.border
            }

            // Content + Debug panel overlay container
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ContentArea {
                    anchors.fill: parent
                    visible: root.currentView === "photos"
                    scanState: typeof scanController !== "undefined" ? scanController.scanState : "empty"
                    imageModel: imageListModel
                    scanProgress: typeof scanController !== "undefined" ? scanController.scanProgress : 0
                    scannedCount: typeof scanController !== "undefined" ? scanController.scannedCount : 0
                    totalImages: typeof scanController !== "undefined" ? scanController.totalImages : 0
                }

                PeopleView {
                    anchors.fill: parent
                    visible: root.currentView === "people"
                }

                // Debug panel overlays on right edge of content area
                DebugPanel {
                    panelVisible: typeof debugController !== "undefined" ? debugController.visible : false
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        Footer {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
        }
    }

    // Settings panel overlay — renders on top of everything
    SettingsPanel {
        anchors.fill: parent
    }

    // ── Global fullscreen preview modal — accessible from all views ──
    ImagePreviewModal {
        id: globalPreviewModal
        anchors.fill: parent
        z: 9999
    }
}
