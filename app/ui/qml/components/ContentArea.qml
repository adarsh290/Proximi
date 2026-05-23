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

    // ── Derived visibility states ─────────────────────────────────────
    property bool showEmpty: (!contentRoot.imageModel || contentRoot.imageModel.count === 0)
                             && contentRoot.scanState !== "scanning"
                             && contentRoot.similarityState === "idle"

    property bool showGrid: contentRoot.imageModel && contentRoot.imageModel.count > 0
                            && contentRoot.similarityState === "idle"

    property bool showLoading: contentRoot.scanState === "scanning"
                               && (!contentRoot.imageModel || contentRoot.imageModel.count === 0)

    property bool showSimilarity: contentRoot.similarityState === "processing"

    property bool showGroupReview: contentRoot.similarityState === "ready"

    // ── Empty State ── (fade transition) ──────────────────────────────
    EmptyState {
        anchors.fill: parent
        opacity: contentRoot.showEmpty ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.animPage; easing.type: Easing.OutCubic } }
    }

    // ── Image Grid ── (fade transition) ───────────────────────────────
    GridView {
        id: imageGrid
        anchors.fill: parent
        anchors.margins: Theme.gridSpacing
        clip: true
        opacity: contentRoot.showGrid ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.animPage; easing.type: Easing.OutCubic } }

        // Increased spacing for a less cramped look
        cellWidth: Theme.thumbnailSize + 12
        cellHeight: Theme.thumbnailSize + 12
        model: contentRoot.imageModel
        cacheBuffer: 4000  // Pre-render ~20 rows outside viewport for smooth 10k+ image scrolling

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

    // ── Loading overlay ── (skeleton view, fade transition) ───────────
    LoadingView {
        anchors.fill: parent
        opacity: contentRoot.showLoading ? 1.0 : 0.0
        visible: opacity > 0
        currentCount: contentRoot.scannedCount
        totalCount: contentRoot.totalImages
        progressPercent: contentRoot.scanProgress

        Behavior on opacity { NumberAnimation { duration: Theme.animPage; easing.type: Easing.OutCubic } }
    }

    // ── Compact progress bar at top (during scan with grid visible) ───
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
            radius: 1
            color: Theme.accent

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic }
            }

            // Glowing leading edge
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: parent.height + 4
                radius: 2
                visible: contentRoot.scanProgress > 0 && contentRoot.scanProgress < 100
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.glowAccent }
                }
            }
        }
    }

    // ── Similarity Processing Overlay ── (fade transition) ───────────
    SimilarityProcessingView {
        anchors.fill: parent
        opacity: contentRoot.showSimilarity ? 1.0 : 0.0
        visible: opacity > 0
        phase: contentRoot.similarityPhase
        progressPercent: contentRoot.similarityProgress

        Behavior on opacity { NumberAnimation { duration: Theme.animPage; easing.type: Easing.OutCubic } }
    }

    // ── Group Review View ── (fade transition) ───────────────────────
    GroupReviewView {
        anchors.fill: parent
        opacity: contentRoot.showGroupReview ? 1.0 : 0.0
        visible: opacity > 0
        currentIndex: typeof similarityController !== "undefined" ? similarityController.currentGroupIndex : 0
        totalGroups: typeof similarityController !== "undefined" ? similarityController.groupCount : 0
        currentGroup: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})

        Behavior on opacity { NumberAnimation { duration: Theme.animPage; easing.type: Easing.OutCubic } }
    }
}
