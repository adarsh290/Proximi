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

    // ── Full-size Image Grid ─────────────────────────────────────────
    GridView {
        id: groupGrid
        anchors.fill: parent
        anchors.margins: Theme.gridSpacing
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
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: Theme.textDisabled
                opacity: 0.5
            }
        }

        // Smooth scrolling
        flickDeceleration: 3000
        maximumFlickVelocity: 4000
    }
}
