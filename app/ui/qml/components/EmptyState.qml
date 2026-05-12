import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: emptyRoot

    // Bound from ContentArea
    property string currentFolder: typeof scanController !== "undefined" ? scanController.currentFolder : ""
    property bool folderSelected: currentFolder !== ""

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spaceL
        width: Math.min(parent.width * 0.6, 400)

        // ── Icon ──────────────────────────────────────────────────
        Text {
            text: folderSelected ? "🔍" : "📂"
            font.pixelSize: 64
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.7
        }

        // ── Title ─────────────────────────────────────────────────
        Text {
            text: folderSelected ? "Ready to scan" : "No images yet"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontTitle
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        // ── Description ───────────────────────────────────────────
        Text {
            text: {
                if (folderSelected) {
                    // Truncate path for readability
                    var parts = emptyRoot.currentFolder.replace(/\\/g, "/").split("/")
                    var short = parts.length > 2 ? ".../" + parts.slice(-2).join("/") : emptyRoot.currentFolder
                    return short
                }
                return "Select a folder containing your photos\nto get started with Proximi."
            }
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.5
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // ── Primary Action Button ─────────────────────────────────
        Button {
            id: primaryBtn
            text: folderSelected ? "Start Scan" : "Browse Folder"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 48

            background: Rectangle {
                radius: Theme.radiusM
                color: {
                    if (folderSelected) {
                        return primaryBtn.hovered ? "#22C55E" : "#16A34A"
                    }
                    return primaryBtn.hovered ? Theme.accentHover : Theme.accent
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
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
