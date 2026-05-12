import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Rectangle {
    color: Theme.bgPanel

    // Derived state helpers
    property bool hasFolder: typeof scanController !== "undefined" && scanController.currentFolder !== ""
    property bool isScanning: typeof scanController !== "undefined" && scanController.scanState === "scanning"
    property bool isLoaded: typeof scanController !== "undefined" && scanController.scanState === "loaded"
    property bool hasScanned: typeof scanController !== "undefined" && scanController.hasScannedCurrentFolder

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceM

        // App title
        Text {
            text: "Proximi"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontTitle
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }

        // Separator (always visible)
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 24
            Layout.leftMargin: Theme.spaceM
            Layout.rightMargin: Theme.spaceS
            color: Theme.border
        }

        // Folder path — shown once a folder has been scanned
        Text {
            id: folderPathText
            property string fullPath: typeof scanController !== "undefined" ? scanController.currentFolder : ""
            visible: hasScanned || isScanning
            text: {
                if (!fullPath || fullPath === "") return ""
                var parts = fullPath.replace(/\\/g, "/").split("/")
                if (parts.length > 2) {
                    return "📂 .../" + parts.slice(-2).join("/")
                }
                return "📂 " + fullPath
            }
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        // Spacer when folder path is hidden
        Item {
            visible: !hasScanned && !isScanning
            Layout.fillWidth: true
        }

        // ── Action buttons (only visible after scan is complete or during scan) ──

        // Change Folder button
        Button {
            id: changeFolderBtn
            text: "Change Folder"
            visible: hasScanned && !isScanning
            onClicked: {
                if (typeof scanController !== "undefined") {
                    scanController.selectFolder()
                }
            }
            background: Rectangle {
                color: changeFolderBtn.hovered ? Theme.bgHover : "transparent"
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: changeFolderBtn.text
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Rescan button
        Button {
            id: rescanButton
            visible: hasScanned || isScanning
            text: isScanning ? "Scanning... " + scanController.scanProgress + "%" : "Rescan"
            enabled: !isScanning && (typeof similarityController === "undefined" || similarityController.similarityState !== "processing")
            onClicked: {
                if (typeof scanController !== "undefined") {
                    if (typeof similarityController !== "undefined") {
                        similarityController.resetState()
                    }
                    scanController.startScan()
                }
            }
            background: Rectangle {
                color: {
                    if (!rescanButton.enabled) return Theme.accentDisabled
                    return rescanButton.hovered ? Theme.accentHover : Theme.accentSubtle
                }
                radius: Theme.radiusS
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: rescanButton.text
                color: rescanButton.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSmall
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Find Similar button
        Button {
            id: similarButton
            text: "Find Similar"
            visible: isLoaded
            enabled: typeof similarityController !== "undefined" && similarityController.similarityState !== "processing"

            onClicked: {
                if (typeof similarityController !== "undefined") {
                    similarityController.startSimilarityProcessing()
                }
            }

            background: Rectangle {
                color: {
                    if (!similarButton.enabled) return Theme.accentDisabled
                    return similarButton.hovered ? "#00E5FF" : "#00C3FF"
                }
                radius: Theme.radiusS
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: similarButton.text
                color: similarButton.enabled ? "#000000" : Theme.textDisabled
                font.pixelSize: Theme.fontSmall
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item {
            Layout.preferredWidth: Theme.spaceS
        }

        // Settings icon placeholder
        Text {
            text: "⚙"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontTitle
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
