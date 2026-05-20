import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: reviewRoot

    property int currentIndex: 0
    property int totalGroups: 0
    property var currentGroup: ({})

    // Helper property to check if data is valid
    property bool hasData: currentGroup && currentGroup.images && currentGroup.images.length > 0

    onCurrentGroupChanged: {
        if (typeof groupGrid !== "undefined") {
            groupGrid.updateModel()
        }
    }

    // Fix: refresh when view becomes visible (Group 1 wasn't rendering
    // because data arrived while the view was still hidden)
    onVisibleChanged: {
        if (visible && typeof groupGrid !== "undefined") {
            groupGrid.updateModel()
        }
    }

    // FIX 2: Timer-based retry for first group data population.
    // When similarity processing finishes, the view may become visible
    // before group data is fully loaded. This timer retries loading.
    Timer {
        id: retryTimer
        interval: 100
        repeat: true
        running: reviewRoot.visible && !reviewRoot.hasData && reviewRoot.totalGroups > 0
        property int attempts: 0

        onTriggered: {
            attempts++
            // Re-read group data from the controller
            if (typeof similarityController !== "undefined") {
                reviewRoot.currentGroup = similarityController.currentGroupData
            }
            if (reviewRoot.hasData || attempts >= 10) {
                retryTimer.stop()
                attempts = 0
            }
        }

        onRunningChanged: {
            if (running) attempts = 0
        }
    }

    // ── Main Layout ─────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        GridView {
            id: groupGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Theme.gridSpacing
            clip: true

            cellWidth: Theme.thumbnailSize + Theme.gridSpacing
            cellHeight: Theme.thumbnailSize + Theme.gridSpacing

            // Convert plain JS array to ListModel
            model: ListModel { id: dynamicModel }

            Component.onCompleted: updateModel()

            function updateModel() {
                dynamicModel.clear()
                if (hasData) {
                    var imgs = reviewRoot.currentGroup.images
                    for (var i = 0; i < imgs.length; i++) {
                        dynamicModel.append(imgs[i])
                    }
                }
            }

            delegate: ImageCard {
                width: groupGrid.cellWidth - Theme.gridSpacing
                height: groupGrid.cellHeight - Theme.gridSpacing
                thumbnailSource: model.thumbnailPath || ""
                fileName: model.fileName || ""
                imageId: model.imageId || -1
                displayRotation: model.displayRotation || 0
                
                onRequestPreview: {
                    if (typeof globalPreviewModal !== "undefined" && reviewRoot.currentGroup && reviewRoot.currentGroup.images) {
                        var list = []
                        for (var i = 0; i < reviewRoot.currentGroup.images.length; i++) {
                            list.push({
                                source: reviewRoot.currentGroup.images[i].originalPath,
                                fileName: reviewRoot.currentGroup.images[i].fileName || ""
                            })
                        }
                        globalPreviewModal.openPreviewList(list, index)
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: ScrollBar.AsNeeded
                hoverEnabled: true
                
                background: Item {}
                
                contentItem: Rectangle {
                    implicitWidth: vbar.pressed || vbar.hovered ? 8 : 2
                    radius: width / 2
                    color: Theme.textDisabled
                    opacity: vbar.pressed || vbar.hovered ? 0.8 : 0.4
                    
                    Behavior on implicitWidth { NumberAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
            
            // Smooth scrolling
            flickDeceleration: 3000
            maximumFlickVelocity: 4000
        }

        // Action Bar for cleanup operations
        ActionBar {
            Layout.fillWidth: true
            visible: !(typeof similarityController !== "undefined" && similarityController.reviewComplete)
        }
    }
    
    // Complete State Overlay
    ReviewCompleteState {
        anchors.fill: parent
        visible: typeof similarityController !== "undefined" && similarityController.reviewComplete
        z: 50
    }
    


    // Keyboard Shortcuts at the view level (robust against focus stealing)
    Shortcut {
        sequence: "Right"
        onActivated: {
            if (typeof similarityController !== "undefined") similarityController.nextGroup()
        }
    }
    Shortcut {
        sequence: "D"
        onActivated: {
            if (typeof similarityController !== "undefined") similarityController.nextGroup()
        }
    }
    Shortcut {
        sequence: "Left"
        onActivated: {
            if (typeof similarityController !== "undefined") similarityController.previousGroup()
        }
    }
    Shortcut {
        sequence: "A"
        onActivated: {
            if (typeof similarityController !== "undefined") similarityController.previousGroup()
        }
    }
    Shortcut {
        sequence: "Ctrl+Z"
        onActivated: {
            if (typeof cleanupController !== "undefined") cleanupController.undoLastCleanup()
        }
    }
    Shortcut {
        sequence: "Ctrl+Enter"
        onActivated: {
            if (typeof cleanupController !== "undefined") cleanupController.executeCleanup()
        }
    }
    Shortcut {
        sequence: "Ctrl+Return"
        onActivated: {
            if (typeof cleanupController !== "undefined") cleanupController.executeCleanup()
        }
    }
}
