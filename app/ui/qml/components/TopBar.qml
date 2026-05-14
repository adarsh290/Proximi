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

        // ── "All Photos" pill — shown after scan ─────────────────────
        Rectangle {
            visible: (hasScanned || isScanning) && !isInGroupReview
            Layout.preferredHeight: 28
            Layout.preferredWidth: allPhotosRow.width + 20
            radius: 14
            color: Theme.accent

            property bool isInGroupReview: typeof similarityController !== "undefined"
                                           && similarityController.similarityState === "ready"

            Row {
                id: allPhotosRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "🖼"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "All Photos"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    visible: typeof scanController !== "undefined" && scanController.scannedCount > 0
                    width: pillCountText.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: Theme.accentHover
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: pillCountText
                        anchors.centerIn: parent
                        text: typeof scanController !== "undefined" ? scanController.scannedCount : "0"
                        color: Theme.textPrimary
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }

        // ── Folder path chip — styled breadcrumb ─────────────────────
        Rectangle {
            id: folderChip
            visible: hasScanned || isScanning
            Layout.preferredHeight: 28
            Layout.preferredWidth: folderChipRow.width + 16
            radius: 14
            color: Theme.bgHover

            property string fullPath: typeof scanController !== "undefined" ? scanController.currentFolder : ""

            Row {
                id: folderChipRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "📂"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: {
                        if (!folderChip.fullPath || folderChip.fullPath === "") return ""
                        var parts = folderChip.fullPath.replace(/\\/g, "/").split("/")
                        if (parts.length > 2) {
                            // Show last 2 segments as breadcrumb
                            return parts[parts.length - 2] + " › " + parts[parts.length - 1]
                        }
                        return parts[parts.length - 1]
                    }
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ToolTip {
                visible: folderChipMouse.containsMouse
                text: folderChip.fullPath
                delay: 400
            }

            MouseArea {
                id: folderChipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Spacer
        Item {
            Layout.fillWidth: true
        }

        // ── View Toggle ──────────────────────────────────────────────
        Button {
            id: viewToggleBtn
            text: root.currentView === "photos" ? "👥 Switch to People" : "🖼 Switch to Photos"
            visible: hasScanned
            onClicked: {
                root.currentView = (root.currentView === "photos") ? "people" : "photos"
            }
            background: Rectangle {
                color: viewToggleBtn.hovered ? Theme.bgHover : "transparent"
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: viewToggleBtn.text
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        // ── Action buttons ───────────────────────────────────────────

        // Scan Faces button
        Button {
            id: scanFacesBtn
            text: "Scan Faces"
            visible: hasScanned && !isScanning
            enabled: typeof faceController !== "undefined" && !faceController.isScanning
            onClicked: {
                if (typeof faceController !== "undefined") {
                    faceController.startFaceScan()
                }
            }
            background: Rectangle {
                color: scanFacesBtn.hovered ? Theme.bgHover : "transparent"
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: typeof faceController !== "undefined" && faceController.isScanning 
                      ? "Scanning Faces..." 
                      : scanFacesBtn.text
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Change Folder button
        Button {
            id: changeFolderBtn
            text: "Change Folder"
            visible: hasScanned && !isScanning
            onClicked: {
                if (typeof similarityController !== "undefined") {
                    similarityController.resetState()
                }
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

        // Clean Duplicates button
        Button {
            id: cleanDuplicatesBtn
            property bool isRemoving: typeof scanController !== "undefined" && scanController.isRemovingDuplicates
            property int progress: typeof scanController !== "undefined" ? scanController.duplicateProgress : 0
            
            text: isRemoving ? "Cleaning... " + progress + "%" : "Clean Duplicates"
            visible: isLoaded
            enabled: !isRemoving && (typeof similarityController === "undefined" || similarityController.similarityState !== "processing")

            onClicked: {
                if (typeof scanController !== "undefined") {
                    scanController.removeExactDuplicates()
                }
            }

            background: Rectangle {
                color: {
                    if (!cleanDuplicatesBtn.enabled) return Theme.bgApp
                    return cleanDuplicatesBtn.hovered ? Theme.bgHover : "transparent"
                }
                border.color: Theme.border
                border.width: 1
                radius: Theme.radiusS
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: "🧹 " + cleanDuplicatesBtn.text
                color: cleanDuplicatesBtn.enabled ? Theme.textPrimary : Theme.textDisabled
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

        // ── Staged Commit Controls ───────────────────────────────────
        RowLayout {
            visible: typeof cleanupController !== "undefined" && cleanupController.stagedCount > 0
            spacing: Theme.spaceS
            Layout.leftMargin: Theme.spaceM
            
            Rectangle {
                Layout.preferredWidth: stagedLabel.implicitWidth + 24
                Layout.preferredHeight: 32
                radius: 16
                color: "#F59E0B" // Amber background

                Row {
                    id: stagedLabel
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "⏳"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: (typeof cleanupController !== "undefined" ? cleanupController.stagedCount : 0) + " Staged"
                        color: "white"
                        font.bold: true
                        font.pixelSize: Theme.fontSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Button {
                id: commitBtn
                text: "Apply Changes"
                onClicked: cleanupController.commitStagedChanges()
                background: Rectangle {
                    color: commitBtn.hovered ? "#059669" : "#10B981" // Green
                    radius: Theme.radiusS
                }
                contentItem: Text {
                    text: commitBtn.text
                    color: "white"
                    font.bold: true
                    font.pixelSize: Theme.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 12
                    rightPadding: 12
                }
            }

            Button {
                id: discardBtn
                text: "Discard"
                onClicked: cleanupController.clearStagedChanges()
                background: Rectangle {
                    color: discardBtn.hovered ? Theme.bgHover : "transparent"
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radiusS
                }
                contentItem: Text {
                    text: discardBtn.text
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 12
                    rightPadding: 12
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: Theme.border
                Layout.leftMargin: Theme.spaceS
                Layout.rightMargin: Theme.spaceS
            }
        }

        Item {
            Layout.preferredWidth: Theme.spaceS
        }

        // Settings icon button
        Rectangle {
            width: 32; height: 32; radius: 16
            color: settingsIconMouse.containsMouse ? Theme.bgHover : "transparent"
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "⚙"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontTitle
            }

            MouseArea {
                id: settingsIconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof settingsController !== "undefined")
                        settingsController.toggleSettingsPanel()
                }
            }
        }
    }
}
