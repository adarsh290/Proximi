import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: emptyRoot

    // Bound from ContentArea
    property string currentFolder: typeof scanController !== "undefined" ? scanController.currentFolder : ""
    property bool folderSelected: currentFolder !== ""

    // Floating particles
    Repeater {
        model: 3
        Rectangle {
            width: 4 + index * 3
            height: width
            radius: width / 2
            color: Theme.accent
            opacity: 0.15 + index * 0.1
            x: emptyRoot.width / 2 + (index === 0 ? -160 : index === 1 ? 140 : -100)
            y: emptyRoot.height / 2 + (index === 0 ? -120 : index === 1 ? -90 : 130)
            
            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation { from: parent.y; to: parent.y - 30; duration: 3000 + index * 800; easing.type: Easing.InOutSine }
                NumberAnimation { from: parent.y - 30; to: parent.y; duration: 3000 + index * 800; easing.type: Easing.InOutSine }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spaceL
        width: Math.min(parent.width * 0.6, 400)

        // ── Icon ──────────────────────────────────────────────────
        Item {
            width: 120
            height: 120
            Layout.alignment: Qt.AlignHCenter
            
            Rectangle {
                anchors.centerIn: parent
                width: 100; height: 100; radius: 50
                color: Theme.accent
                opacity: 0.15
                
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.4; duration: 2500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.4; to: 1.0; duration: 2500; easing.type: Easing.InOutSine }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 80; height: 80; radius: 40
                color: Theme.accent
                opacity: 0.25
            }
            
            Text {
                anchors.centerIn: parent
                text: folderSelected ? "🔍" : "📂"
                font.pixelSize: 56
                opacity: 0.9
            }
        }

        // ── Title ─────────────────────────────────────────────────
        Text {
            text: folderSelected ? "Ready to scan" : "No photos loaded"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontDisplay
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        // ── Description ───────────────────────────────────────────
        Text {
            text: {
                if (folderSelected) {
                    var parts = emptyRoot.currentFolder.replace(/\\/g, "/").split("/")
                    return "We will analyze photos in this folder.\n" + (parts.length > 2 ? ".../" + parts.slice(-2).join("/") : emptyRoot.currentFolder)
                }
                return "Drop a folder here or browse your files.\nWe'll find similar photos and help you declutter."
            }
            color: Theme.textSecondary
            font.pixelSize: Theme.fontHeader
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.6
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // ── Primary Action Button ─────────────────────────────────
        Button {
            id: primaryBtn
            text: folderSelected ? "Start Scan" : "Browse Folder"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 220
            Layout.preferredHeight: 52
            
            scale: primaryBtn.hovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            background: Rectangle {
                radius: Theme.radiusXL
                gradient: Gradient {
                    GradientStop { position: 0.0; color: folderSelected ? (primaryBtn.hovered ? "#4ADE80" : "#22C55E") : (primaryBtn.hovered ? Theme.accentHover : Theme.accent) }
                    GradientStop { position: 1.0; color: folderSelected ? (primaryBtn.hovered ? "#22C55E" : "#16A34A") : (primaryBtn.hovered ? Theme.accent : Theme.accentSubtle) }
                }
            }

            contentItem: Text {
                text: primaryBtn.text
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                if (typeof scanController !== "undefined") {
                    if (folderSelected) {
                        if (typeof similarityController !== "undefined") {
                            similarityController.resetState()
                        }
                        scanController.startScan()
                    } else {
                        scanController.selectFolder()
                    }
                }
            }
        }

        // ── Secondary "Change Folder" link (only when folder is already selected) ──
        Text {
            visible: folderSelected
            text: "Change folder..."
            color: Theme.accent
            font.pixelSize: Theme.fontSmall
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            opacity: mouseArea.containsMouse ? 1.0 : 0.7

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof scanController !== "undefined") {
                        scanController.selectFolder()
                    }
                }
            }
        }
    }
}
