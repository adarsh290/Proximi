import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0
import "."

Item {
    id: contentRoot

    // External properties bound from Main.qml
    property string scanState: "empty"
    property var imageModel: null
    property int scanProgress: 0
    property int scannedCount: 0
    property int totalImages: 0

    // Similarity properties
    property string similarityState: typeof similarityController !== "undefined" ? similarityController.similarityState : "idle"
    property string similarityPhase: typeof similarityController !== "undefined" ? similarityController.currentPhase : ""
    property int similarityProgress: typeof similarityController !== "undefined" ? similarityController.progress : 0

    // Empty State — visible when no images are loaded and not in scanning/similarity mode
    EmptyState {
        anchors.fill: parent
        visible: (!contentRoot.imageModel || contentRoot.imageModel.count === 0)
                 && contentRoot.scanState !== "scanning"
                 && contentRoot.similarityState === "idle"
    }

    // Image Grid (visible during scanning and after loaded, hidden during similarity review)
    GridView {
        id: imageGrid
        anchors.fill: parent
        anchors.margins: Theme.gridSpacing
        clip: true
        visible: contentRoot.imageModel && contentRoot.imageModel.count > 0 && contentRoot.similarityState === "idle"

        cellWidth: Theme.thumbnailSize + Theme.gridSpacing
        cellHeight: Theme.thumbnailSize + Theme.gridSpacing
        model: contentRoot.imageModel
        cacheBuffer: 2000  // Pre-render ~10 rows outside viewport for smooth scrolling

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

        delegate: ImageCard {
            width: imageGrid.cellWidth - Theme.gridSpacing
            height: imageGrid.cellHeight - Theme.gridSpacing
            thumbnailSource: model.thumbnailPath || ""
            fileName: model.fileName || ""
            imageId: model.imageId || -1
            isFlicking: imageGrid.flicking  // Disable smooth filter during fast scroll

            onRequestPreview: {
                if (typeof globalPreviewModal !== "undefined") {
                    globalPreviewModal.openPreview(model.originalPath)
                }
            }
        }

        // Smooth scrolling tuning
        flickDeceleration: 3000
        maximumFlickVelocity: 4000
    }

    // Loading overlay (shown during scan, overlaid on top of growing grid)
    LoadingView {
        anchors.fill: parent
        visible: contentRoot.scanState === "scanning" && (!contentRoot.imageModel || contentRoot.imageModel.count === 0)
        currentCount: contentRoot.scannedCount
        totalCount: contentRoot.totalImages
        progressPercent: contentRoot.scanProgress
    }

    // Compact progress bar at top when scanning with grid visible
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 3
        color: "transparent"
        visible: contentRoot.scanState === "scanning" && contentRoot.imageModel && contentRoot.imageModel.count > 0

        Rectangle {
            width: parent.width * (contentRoot.scanProgress / 100)
            height: parent.height
            color: Theme.accent

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }

    // Similarity Processing Overlay
    SimilarityProcessingView {
        anchors.fill: parent
        visible: contentRoot.similarityState === "processing"
        phase: contentRoot.similarityPhase
        progressPercent: contentRoot.similarityProgress
    }

    // Group Review View
    GroupReviewView {
        anchors.fill: parent
        visible: contentRoot.similarityState === "ready"
        currentIndex: typeof similarityController !== "undefined" ? similarityController.currentGroupIndex : 0
        totalGroups: typeof similarityController !== "undefined" ? similarityController.groupCount : 0
        currentGroup: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})
    }
}
