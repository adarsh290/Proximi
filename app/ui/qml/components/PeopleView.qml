import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: root
    
    property var peopleData: []
    
    // Refresh people list when scan finishes or when view becomes visible
    Connections {
        target: typeof faceController !== "undefined" ? faceController : null
        function onScanFinished() {
            refreshData()
        }
    }
    
    onVisibleChanged: {
        if (visible) refreshData()
    }
    
    function refreshData() {
        if (typeof faceController !== "undefined") {
            peopleData = faceController.getPeople()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgMain

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceL
            spacing: Theme.spaceL

            // ── Header ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "👥 People"
                    color: Theme.textPrimary
                    font.pixelSize: 28
                    font.bold: true
                    Layout.fillWidth: true
                }
                
                Button {
                    text: "Refresh"
                    onClicked: refreshData()
                    visible: !faceController.isScanning
                }
            }
            
            // ── Scanning State Overlay ───────────────────────────────────
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: typeof faceController !== "undefined" && faceController.isScanning
                spacing: Theme.spaceS
                
                Text {
                    text: "Facial Recognition is running..."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontMedium
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: faceController.statusText
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    Layout.alignment: Qt.AlignHCenter
                }

                ProgressBar {
                    Layout.preferredWidth: 300
                    Layout.alignment: Qt.AlignHCenter
                    from: 0
                    to: faceController.progressTotal
                    value: faceController.progressCurrent
                }
            }

            // ── Grid of People ───────────────────────────────────────────
            GridView {
                id: peopleGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !faceController.isScanning && peopleData.length > 0
                
                cellWidth: 160
                cellHeight: 200
                clip: true
                
                model: root.peopleData
                
                delegate: Item {
                    width: peopleGrid.cellWidth - Theme.spaceM
                    height: peopleGrid.cellHeight - Theme.spaceM
                    
                    Rectangle {
                        anchors.fill: parent
                        color: hoverArea.containsMouse ? Theme.bgHover : "transparent"
                        radius: Theme.radiusM
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spaceS
                            spacing: Theme.spaceS
                            
                            // Circular Profile Picture
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 100
                                height: 100
                                radius: 50
                                color: Theme.bgCard
                                clip: true
                                border.width: 2
                                border.color: Theme.border
                                
                                Image {
                                    anchors.fill: parent
                                    source: modelData.profilePath || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }
                            }
                            
                            Text {
                                text: modelData.name
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontMedium
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            Text {
                                text: modelData.faceCount + " photos"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        
                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("Clicked person:", modelData.personId)
                                // Next step: Open PersonGalleryView
                            }
                        }
                    }
                }
            }
            
            // Empty state
            Text {
                text: "No people found yet.\nClick 'Scan Faces' to start facial recognition."
                color: Theme.textMuted
                font.pixelSize: Theme.fontMedium
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignCenter
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !faceController.isScanning && peopleData.length === 0
            }
        }
    }
}
