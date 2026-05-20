import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: root
    visible: false
    opacity: 0

    // ── Public API ────────────────────────────────────────────────────
    property string imageSource: ""
    property string imageFileName: ""

    // Optional list-based navigation
    // Pass an array of { source, fileName } objects and a start index
    property var imageList: []
    property int currentIndex: 0

    // ── Open / Close ──────────────────────────────────────────────────
    function openPreview(src, fileName) {
        imageSource = src || ""
        imageFileName = fileName || extractFileName(src)
        imageList = []      // Single-image mode
        currentIndex = 0
        _show()
    }

    function openPreviewList(list, startIndex) {
        imageList = list || []
        currentIndex = Math.max(0, Math.min(startIndex || 0, list.length - 1))
        if (list.length > 0) {
            imageSource = list[currentIndex].source || ""
            imageFileName = list[currentIndex].fileName || extractFileName(imageSource)
        }
        _show()
    }

    function closePreview() {
        imageContainer.imageScale = 0.92
        root.opacity = 0
    }

    function _show() {
        root.visible = true
        root.opacity = 1
        imageContainer.imageScale = 1.0
        focusItem.forceActiveFocus()
    }

    function extractFileName(path) {
        if (!path) return ""
        var parts = path.replace(/\\/g, "/").split("/")
        return parts[parts.length - 1]
    }

    function _navigateTo(index) {
        if (imageList.length === 0) return
        currentIndex = (index + imageList.length) % imageList.length
        
        // Manual crossfade logic
        previewImage.opacity = 0.5
        imageSource = imageList[currentIndex].source || ""
        imageFileName = imageList[currentIndex].fileName || extractFileName(imageSource)
        previewImage.opacity = 1.0
    }

    // ── Animation ─────────────────────────────────────────────────────
    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && root.opacity === 0) {
                    root.visible = false
                }
            }
        }
    }

    // ── Dim Background ────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#EE000000"   // 93% black

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePreview()
        }
    }

    // ── Image Container with scale animation ──────────────────────────
    Item {
        id: imageContainer
        anchors.fill: parent
        anchors.topMargin: 56     // space for top bar
        anchors.bottomMargin: 64  // space for info bar
        anchors.leftMargin: imageList.length > 1 ? 64 : 16
        anchors.rightMargin: imageList.length > 1 ? 64 : 16

        property real imageScale: 1.0

        Behavior on imageScale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Image {
            id: previewImage
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: root.imageSource
            fillMode: Image.PreserveAspectFit
            autoTransform: true
            asynchronous: true
            smooth: true
            mipmap: true
            scale: imageContainer.imageScale
            sourceSize.width: imageContainer.width
            sourceSize.height: imageContainer.height

            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            
            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        // Loading spinner
        Item {
            anchors.centerIn: parent
            visible: previewImage.status === Image.Loading
            width: 56
            height: 56

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#33FFFFFF"
            }

            Text {
                anchors.centerIn: parent
                text: "⏳"
                font.pixelSize: 24
            }

            RotationAnimation on rotation {
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 1200
            }
        }
    }

    // ── Prev Button ───────────────────────────────────────────────────
    Item {
        id: prevBtn
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 56
        height: 56
        visible: imageList.length > 1
        opacity: prevMouse.containsMouse ? 1.0 : 0.6

        Behavior on opacity { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: prevMouse.containsMouse ? "#55FFFFFF" : "#33FFFFFF"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            anchors.centerIn: parent
            text: "‹"
            color: "white"
            font.pixelSize: 28
            font.bold: true
        }

        MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._navigateTo(root.currentIndex - 1)
        }
    }

    // ── Next Button ───────────────────────────────────────────────────
    Item {
        id: nextBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 56
        height: 56
        visible: imageList.length > 1
        opacity: nextMouse.containsMouse ? 1.0 : 0.6

        Behavior on opacity { NumberAnimation { duration: 120 } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: nextMouse.containsMouse ? "#55FFFFFF" : "#33FFFFFF"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            anchors.centerIn: parent
            text: "›"
            color: "white"
            font.pixelSize: 28
            font.bold: true
        }

        MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._navigateTo(root.currentIndex + 1)
        }
    }

    // ── Top Bar: Close button ─────────────────────────────────────────
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: "transparent"

        // Close button
        Item {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 16
            width: 40
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: closeMouse.containsMouse ? "#44FFFFFF" : "#22FFFFFF"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closePreview()
            }
        }

        // Keyboard hint
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20
            text: imageList.length > 1
                  ? "ESC or F to close  ·  ← → to navigate"
                  : "ESC or F to close"
            color: "#88FFFFFF"
            font.pixelSize: 12
        }
    }

    // ── Bottom Info Bar ───────────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 64
        color: "#CC000000"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 12

            // Filename
            Text {
                text: root.imageFileName
                color: "white"
                font.pixelSize: 14
                elide: Text.ElideMiddle
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Image dimensions when loaded
            Text {
                text: (previewImage.sourceSize.width > 0 && previewImage.sourceSize.height > 0)
                      ? previewImage.sourceSize.width + " × " + previewImage.sourceSize.height
                      : ""
                color: "#88FFFFFF"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }

            // Counter when in list mode
            Text {
                visible: imageList.length > 1
                text: (root.currentIndex + 1) + " / " + imageList.length
                color: "#88FFFFFF"
                font.pixelSize: 13
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ── Keyboard Capture ──────────────────────────────────────────────
    Item {
        id: focusItem
        focus: root.visible
        Keys.onPressed: (event) => {
            switch (event.key) {
                case Qt.Key_Escape:
                case Qt.Key_F:
                    root.closePreview()
                    event.accepted = true
                    break
                case Qt.Key_Left:
                    root._navigateTo(root.currentIndex - 1)
                    event.accepted = true
                    break
                case Qt.Key_Right:
                    root._navigateTo(root.currentIndex + 1)
                    event.accepted = true
                    break
            }
        }
    }
}
