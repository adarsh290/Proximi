import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Rectangle {
    color: Theme.bgSidebar

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceM
        spacing: Theme.spaceS

        // Section header
        Text {
            text: "GROUP REVIEW"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            font.bold: true
            font.letterSpacing: 1.2
            Layout.bottomMargin: Theme.spaceXS
        }

        // Group info card
        Rectangle {
            Layout.fillWidth: true
            color: Theme.bgPanel
            radius: Theme.radiusM
            border.color: Theme.border
            border.width: 1
            Layout.preferredHeight: groupInfoColumn.implicitHeight + Theme.spaceM * 2
            clip: true // to keep accent strip inside corners

            // Accent strip
            Rectangle {
                width: 3
                height: parent.height
                anchors.left: parent.left
                color: Theme.accent
            }

            ColumnLayout {
                id: groupInfoColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceM
                spacing: Theme.spaceS

                // Row 1: Group number + Progress Ring
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceM
                    
                    // Circular progress ring
                    Item {
                        width: 48
                        height: 48
                        
                        Canvas {
                            id: progressCanvas
                            anchors.fill: parent
                            property real progress: {
                                if (typeof similarityController === "undefined" || similarityController.groupCount <= 1) return 1.0
                                return (similarityController.currentGroupIndex + 1) / similarityController.groupCount
                            }
                            
                            onProgressChanged: requestPaint()
                            
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                
                                var cx = width / 2
                                var cy = height / 2
                                var r = width / 2 - 4
                                
                                // Background ring
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                ctx.lineWidth = 4
                                ctx.strokeStyle = Theme.border
                                ctx.stroke()
                                
                                // Progress ring
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress)
                                ctx.lineWidth = 4
                                ctx.strokeStyle = Theme.accent
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }
                            
                            Behavior on progress {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: typeof similarityController !== "undefined" ? (similarityController.currentGroupIndex + 1) : "1"
                            color: Theme.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Group"
                            color: Theme.textPrimary
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Text {
                            text: {
                                if (typeof similarityController === "undefined") return ""
                                return "of " + similarityController.groupCount
                            }
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                    Layout.topMargin: Theme.spaceXS
                    Layout.bottomMargin: Theme.spaceXS
                }

                // Row 2: Image count
                RowLayout {
                    spacing: Theme.spaceS
                    Text {
                        text: "🖼"
                        font.pixelSize: Theme.fontBody
                    }
                    Text {
                        property var grp: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})
                        text: {
                            if (grp && grp.count) return grp.count + " images"
                            return "..."
                        }
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontBody
                    }
                }

                // Row 3: Type badge + Score
                RowLayout {
                    spacing: Theme.spaceS

                    Rectangle {
                        property var grp: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})
                        property bool isBurst: grp && grp.type === "burst"
                        color: isBurst ? "#4A3300" : "#1A2E35"
                        radius: 4
                        Layout.preferredWidth: badgeText.implicitWidth + 16
                        Layout.preferredHeight: badgeText.implicitHeight + 8

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: {
                                var g = typeof similarityController !== "undefined" ? similarityController.currentGroupData : null
                                if (g && g.type) return g.type.toUpperCase()
                                return "..."
                            }
                            color: parent.isBurst ? "#FFB000" : "#00C3FF"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Text {
                        property var grp: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})
                        text: {
                            if (grp && grp.score !== undefined) return Math.round(grp.score * 100) + "%"
                            return ""
                        }
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSmall
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // ── Cleanup Stats ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: Theme.radiusS
            color: Theme.bgCard
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                
                Text {
                    text: "Cleaned Images"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontCaption
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: typeof cleanupController !== "undefined" ? cleanupController.totalDeleted : "0"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Spacer to push navigation buttons to the bottom
        Item {
            Layout.fillHeight: true
        }

        // ── Navigation Buttons (stacked vertically) ──────────────────
        Button {
            id: prevBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            text: "◀  Previous"
            enabled: typeof similarityController !== "undefined" && similarityController.currentGroupIndex > 0

            onClicked: {
                if (typeof similarityController !== "undefined")
                    similarityController.previousGroup()
            }

            background: Rectangle {
                color: prevBtn.enabled ? (prevBtn.hovered ? Theme.bgHover : "transparent") : "transparent"
                radius: Theme.radiusXL
                border.color: prevBtn.enabled ? (prevBtn.hovered ? Theme.accentGlow : Theme.border) : "transparent"
                border.width: 1
                opacity: prevBtn.enabled ? 1.0 : 0.4
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }
            contentItem: Text {
                text: prevBtn.text
                color: prevBtn.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSmall
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Button {
            id: nextBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            text: "Next  ▶"
            enabled: typeof similarityController !== "undefined"
                     && similarityController.currentGroupIndex < similarityController.groupCount - 1

            onClicked: {
                if (typeof similarityController !== "undefined")
                    similarityController.nextGroup()
            }

            background: Rectangle {
                radius: Theme.radiusXL
                gradient: Gradient {
                    GradientStop { position: 0.0; color: nextBtn.enabled ? (nextBtn.hovered ? Theme.accentHover : Theme.accent) : Theme.accentDisabled }
                    GradientStop { position: 1.0; color: nextBtn.enabled ? (nextBtn.hovered ? Theme.accent : Theme.accentSubtle) : Theme.accentDisabled }
                }
            }
            contentItem: Text {
                text: nextBtn.text
                color: nextBtn.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSmall
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Spacer
        Item {
            Layout.fillHeight: true
        }
    }
}
